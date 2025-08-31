import Metal
import MetalKit
import simd

// --- rotation + discovery config ---
private let SWITCH_SEC: Float = 15.0
private let scenePrefixes = ["scene_", "feedbackFrag"]   // fragments with these prefixes will be picked
private var scenePipelines: [MTLRenderPipelineState] = []  // built once at init

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

// ---------- Uniforms (must match .metal) ----------
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
    private let pipelineBlit: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private weak var view: MTKView?

    private var texA: MTLTexture?
    private var texB: MTLTexture?
    private var useAasPrev = true

    private var startTime: CFTimeInterval = CACurrentMediaTime()
    private var lastDrawableSize: CGSize = .zero
    private let renderScale: CGFloat = 0.7

    // --- NEW: occurrence-based selection state ---
    private var fragNames: [String] = []
    private var sceneCounts: [Int] = []            // occurrences per scene index
    private var currentSceneIndex: Int = 0         // active scene
    private var nextSwitchTime: Float = SWITCH_SEC // wall-clock t when we switch next
    private var lastLoggedIndex: Int = -1          // only for logging

    init(view: MTKView) {
        self.view = view

        guard let dev = view.device else { fatalError("No Metal device.") }
        self.device = dev

        guard let q = dev.makeCommandQueue() else { fatalError("No command queue.") }
        self.queue = q

        // Create library as a LOCAL, then assign; reuse local to build pipelines
        let lib: MTLLibrary
        do { lib = try dev.makeDefaultLibrary(bundle: .main) }
        catch { fatalError("Failed to create default library: \(error)") }
        self.library = lib

        let px = view.colorPixelFormat

        // --- Auto-discover fragment entry points by prefix across all .metal files ---
        let allNames = lib.functionNames
        self.fragNames = allNames.compactMap { name -> String? in
            // keep only names with allowed prefixes
            guard scenePrefixes.first(where: { name.hasPrefix($0) }) != nil else { return nil }
            // verify it's a fragment function
            guard let f = lib.makeFunction(name: name), f.functionType == .fragment else { return nil }
            return name
        }.sorted()

        print("fragNames: \(self.fragNames)")

        scenePipelines = fragNames.map { frag in
            buildPipeline(device: dev, library: lib, pixelFormat: px,
                          vertex: "fullscreenVS", fragment: frag)
        }

        if scenePipelines.isEmpty {
            scenePipelines = [buildPipeline(device: dev, library: lib, pixelFormat: px,
                                            vertex: "fullscreenVS", fragment: "feedbackFragA")]
            self.fragNames = ["feedbackFragA"]
        }

        self.pipelineBlit = buildPipeline(device: dev, library: lib, pixelFormat: px,
                                          vertex: "fullscreenVS", fragment: "blitFrag")
        self.sampler = makeLinearClampSampler(device: dev)

        self.sceneCounts = Array(repeating: 0, count: scenePipelines.count)
        self.currentSceneIndex = 0
        self.nextSwitchTime = SWITCH_SEC

        super.init()

        self.currentSceneIndex = pickNextSceneIndex(excluding: nil)
        self.sceneCounts[currentSceneIndex] += 1
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

    private func pickNextSceneIndex(excluding current: Int?) -> Int {
        let n = scenePipelines.count
        guard n > 0 else { return 0 }

        let minCount = sceneCounts.min() ?? 0

        // Candidate set: all with minimal count
        var candidates: [Int] = []
        candidates.reserveCapacity(n)
        for (i, c) in sceneCounts.enumerated() where c == minCount {
            // Avoid immediate repeat when >1 scene exists
            if let cur = current, n > 1, i == cur { continue }
            candidates.append(i)
        }

        // If we filtered out everything (e.g., only 1 scene), fall back
        if candidates.isEmpty {
            if let cur = current, n > 1 {
                // all minima were the current; pick any other at random
                let others = (0..<n).filter { $0 != cur }
                return others.randomElement() ?? cur
            }
            return current ?? 0
        }

        return candidates.randomElement() ?? 0
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

        // Time
        let t = Float(CACurrentMediaTime() - startTime)

        if t >= nextSwitchTime {
            let prev = currentSceneIndex
            let next = pickNextSceneIndex(excluding: prev)
            currentSceneIndex = next
            sceneCounts[next] += 1
            nextSwitchTime += SWITCH_SEC

            if currentSceneIndex != lastLoggedIndex {
                if currentSceneIndex < self.fragNames.count {
                    print("Switched to scene: \(self.fragNames[currentSceneIndex])")
                } else {
                    print("Switched to scene index \(currentSceneIndex)")
                }
                lastLoggedIndex = currentSceneIndex
            }
        }

        // Uniforms
        var u = Uniforms(
            time: t,
            res: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            bass: 0, mid: 0, high: 0,
            fade: 1 // left as-is; your shaders can choose to use it
        )

        // Ping-pong
        let prevTex = useAasPrev ? texA : texB
        let nextTex = useAasPrev ? texB : texA

        // Pass 1: offscreen feedback → next
        if let rp = offscreenPassDescriptor(target: nextTex),
           let enc = cmd.makeRenderCommandEncoder(descriptor: rp) {
            enc.setRenderPipelineState(scenePipelines[currentSceneIndex]) // ← min-occurrence selected scene
            enc.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
            enc.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
            enc.setFragmentTexture(prevTex, index: 0)            // safe if unused by a scene
            enc.setFragmentSamplerState(sampler, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            enc.endEncoding()
        }

        // Pass 2: blit low-res to screen
        if let rp2 = view.currentRenderPassDescriptor,
           let enc2 = cmd.makeRenderCommandEncoder(descriptor: rp2) {
            enc2.setRenderPipelineState(pipelineBlit)
            enc2.setFragmentTexture(nextTex, index: 0)
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
        rp.colorAttachments[0].loadAction = .load   // keep trails/feedback
        rp.colorAttachments[0].storeAction = .store
        return rp
    }
}
