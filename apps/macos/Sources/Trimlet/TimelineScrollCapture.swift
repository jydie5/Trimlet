import AppKit
import SwiftUI

/// Keeps two-finger seeking on the timeline; zoom and pan remain explicit controls.
struct TimelineScrollCapture: NSViewRepresentable {
    var enabled: Bool
    var onSeek: (Double) -> Void
    var onEnd: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.attach()
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.enabled = enabled
        context.coordinator.onSeek = onSeek
        context.coordinator.onEnd = onEnd
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor final class Coordinator {
        weak var view: NSView?
        var enabled = false
        var onSeek: (Double) -> Void = { _ in }
        var onEnd: () -> Void = {}
        private var monitor: Any?
        private var endTask: Task<Void, Never>?

        func attach() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, self.enabled, let view = self.view,
                      let window = view.window, event.window === window,
                      view.bounds.contains(view.convert(event.locationInWindow, from: nil)) else { return event }
                let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
                    ? event.scrollingDeltaX : event.scrollingDeltaY
                if delta != 0 {
                    self.onSeek(-delta * (event.hasPreciseScrollingDeltas ? 0.02 : 0.15))
                }
                self.endTask?.cancel()
                self.endTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(140))
                    guard !Task.isCancelled else { return }
                    self?.onEnd()
                }
                return nil
            }
        }

        func detach() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            endTask?.cancel()
            onEnd()
        }
    }
}
