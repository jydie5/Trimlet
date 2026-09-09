import AppKit
import SwiftUI

@MainActor
final class TrimletAppDelegate: NSObject, NSApplicationDelegate {
    var confirmTermination: (() -> Bool)?
    var fileOpenHandler: ((URL) -> Void)? {
        didSet {
            if let fileOpenHandler, let first = pendingFileURLs.first {
                pendingFileURLs.removeAll()
                fileOpenHandler(first)
            }
        }
    }
    private var pendingFileURLs: [URL] = []

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        confirmTermination?() == false ? .terminateCancel : .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map(URL.init(fileURLWithPath:))
        if let fileOpenHandler, let first = urls.first {
            fileOpenHandler(first)
        } else {
            pendingFileURLs.append(contentsOf: urls)
        }
        sender.reply(toOpenOrPrint: .success)
    }
}

@main
struct TrimletApp: App {
    @NSApplicationDelegateAdaptor(TrimletAppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Trimlet", id: "main") {
            ContentView()
                .frame(minWidth: 1_000, minHeight: 800)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1_240, height: 860)
    }
}
