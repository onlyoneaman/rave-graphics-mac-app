//
//  MetalView.swift
//  RaveVizs
//
//  Created by Aman Kumar on 31/08/25.
//

import SwiftUI
import MetalKit

/// SwiftUI wrapper around MTKView
struct MetalView: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not supported on this machine.")
        }
        let v = MTKView(frame: .zero, device: device)
        v.colorPixelFormat = .bgra8Unorm
        v.clearColor = MTLClearColorMake(0, 0, 0, 1)
        v.preferredFramesPerSecond = 120
        v.framebufferOnly = false // we render to offscreen textures, so keep this false
        context.coordinator.renderer = Renderer(view: v)
        v.delegate = context.coordinator.renderer
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var renderer: Renderer! }
}
