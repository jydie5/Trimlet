import SwiftUI

@main
struct TrimletApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1_000, minHeight: 800)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1_240, height: 860)
    }
}
