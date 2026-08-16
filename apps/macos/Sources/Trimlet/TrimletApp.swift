import SwiftUI

@main
struct TrimletApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 760)
    }
}
