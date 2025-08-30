import Metal
import MetalKit
import simd

// ---------- File-scope helpers (no `self`) ----------
private func buildPipeline(device: MTLDevice,
                           library: MTLLibrary,
                           pixelFormat: MTLPixelFormat,
                           vertex: String,
                           fragment: String) -> MTLRenderPipelineState {
    let desc = MTLRenderPipelineDescriptor()
    desc.colorAttachments[0].pixelFormat = pixelFormat
    desc.vertexFunction   = library.makeFunction(name: vertex)
    desc.fragmentFunction = library.makeFunction(name: fragment)
    do { return try device.makeRenderPipelineState(descriptor: desc) }
    catch { fatalError("Pipeline(\(fragment)) error: \(error)") }
}

private func makeLinearClampSampler(device: MTLDevice) -> MTLSamplerState {
    let d = MTLSamplerDescriptor()
    d.minFilter = .linear
    d.magFilter = .linear
    d.mipFilter = .notMipmapped
    d.sAddressMode = .clampToEdge
    d.tAddressMode = .clampToEdge
    guard let s = device.makeSamplerState(descriptor: d) else {
        fatalError("Sampler creation failed")
    }
    return s
}

// ---------- Uniforms ----------
struct Uniforms {
    var time: Float
    var res: SIMD2<Float>
    var bass: Float
    var mid: Float
    var high: Float
    var fade: Float
}

// ---------- Renderer ----------
final class Renderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let library: MTLLibrary
    private let pipelineFeedback: MTLRenderPipelineState
    private let pipelineBlit: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private weak var view: MTKView?

    private var texA: MTLTexture?
    private var texB: MTLTexture?
    private var useAasPrev = true

    private var startTime: CFTimeInterval = CACurrentMediaTime()
    private var lastDrawableSize: CGSize = .zero
    private let renderScale: CGFloat = 0.7

    init(view: MTKView) {
        self.view = view

        guard let dev = view.device else { fatalError("No Metal device.") }
        self.device = dev

        guard let q = dev.makeCommandQueue() else { fatalError("No command queue.") }
        self.queue = q

        // Create library as a LOCAL, then assign; also reuse the local to build pipelines
        let lib: MTLLibrary
        do { lib = try dev.makeDefaultLibrary(bundle: .main) }
        catch { fatalError("Failed to create default library: \(error)") }
        self.library = lib

        let px = view.colorPixelFormat
        // Build pipelines via file-scope helper (no `self` involved)
        self.pipelineFeedback = buildPipeline(device: dev, library: lib, pixelFormat: px,
                                              vertex: "fullscreenVS", fragment: "feedbackFrag")
        self.pipelineBlit     = buildPipeline(device: dev, library: lib, pixelFormat: px,
                                              vertex: "fullscreenVS", fragment: "blitFrag")

        // Sampler via helper (no `self`)
        self.sampler = makeLinearClampSampler(device: dev)

        super.init()
    }

    private func ensureOffscreenTextures(for drawableSize: CGSize) {
        guard let view = view else { return }
        if lastDrawableSize == drawableSize, texA != nil, texB != nil { return }
        lastDrawableSize = drawableSize

        let w = max(1, Int(drawableSize.width  * renderScale))
        let h = max(1, Int(drawableSize.height * renderScale))

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: view.colorPixelFormat,
            width: w, height: h, mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead, .shaderWrite]
        desc.storageMode = .private

        texA = device.makeTexture(descriptor: desc)
        texB = device.makeTexture(descriptor: desc)

        // Clear both once
        guard let texA, let texB, let cmd = queue.makeCommandBuffer() else { return }
        func clear(_ tex: MTLTexture) {
            let rp = MTLRenderPassDescriptor()
            rp.colorAttachments[0].texture = tex
            rp.colorAttachments[0].loadAction = .clear
            rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
            rp.colorAttachments[0].storeAction = .store
            if let enc = cmd.makeRenderCommandEncoder(descriptor: rp) { enc.endEncoding() }
        }
        clear(texA); clear(texB)
        cmd.commit()
    }

    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        ensureOffscreenTextures(for: size)
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let cmd = queue.makeCommandBuffer()
        else { return }

        ensureOffscreenTextures(for: view.drawableSize)
        guard let texA = texA, let texB = texB else { return }

        // Uniforms
        let t = Float(CACurrentMediaTime() - startTime)
        var u = Uniforms(
            time: t,
            res: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            bass: 0, mid: 0, high: 0, fade: 1
        )

        // Ping-pong
        let prev = useAasPrev ? texA : texB
        let next = useAasPrev ? texB : texA

        // Pass 1: offscreen feedback → next
        if let rp = offscreenPassDescriptor(target: next),
           let enc = cmd.makeRenderCommandEncoder(descriptor: rp) {
            enc.setRenderPipelineState(pipelineFeedback)
            enc.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
            enc.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
            enc.setFragmentTexture(prev, index: 0)
            enc.setFragmentSamplerState(sampler, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            enc.endEncoding()
        }

        // Pass 2: blit low-res to screen
        if let rp2 = view.currentRenderPassDescriptor,
           let enc2 = cmd.makeRenderCommandEncoder(descriptor: rp2) {
            enc2.setRenderPipelineState(pipelineBlit)
            enc2.setFragmentTexture(next, index: 0)
            enc2.setFragmentSamplerState(sampler, index: 0)
            enc2.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            enc2.endEncoding()
        }

        useAasPrev.toggle()
        cmd.present(drawable)
        cmd.commit()
    }

    private func offscreenPassDescriptor(target: MTLTexture?) -> MTLRenderPassDescriptor? {
        guard let target else { return nil }
        let rp = MTLRenderPassDescriptor()
        rp.colorAttachments[0].texture = target
        rp.colorAttachments[0].loadAction = .load   // keep trails
        rp.colorAttachments[0].storeAction = .store
        return rp
    }
}
