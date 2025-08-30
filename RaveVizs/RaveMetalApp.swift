import SwiftUI

@main
struct RaveMetalApp: App {
    var body: some Scene {
        WindowGroup {
            MetalView()
                .ignoresSafeArea()
        }
        .windowStyle(.hiddenTitleBar)
    }
}


