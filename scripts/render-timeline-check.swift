import AppKit
import SwiftUI
import TrimletCore

/// Offscreen render of the production drawing components, not a GUI gesture test.
@main struct TimelineRenderCheck {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("trimlet-timeline-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for dark in [false, true] {
            let renderer = ImageRenderer(content: VStack(alignment: .leading, spacing: 18) {
                row("通常の範囲", current: 60, start: 25, end: 70)
                row("短い範囲：再生ヘッドとOUTが同位置", current: 50.01, start: 50, end: 50.01)
                row("INのみ：再生ヘッドとINが同位置", current: 50, start: 50, end: nil)
                row("先頭から末尾：余白に両端を表示", current: 0, start: 0, end: 100)
            }
            .padding(24)
            .background(dark ? Color.black : Color.white)
            .environment(\.colorScheme, dark ? .dark : .light))
            renderer.scale = 2
            guard let cgImage = renderer.cgImage else { fatalError("No rendered image") }
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("No PNG") }
            let output = directory.appendingPathComponent(dark ? "dark.png" : "light.png")
            try png.write(to: output)
            print(output.path)
        }
    }

    @MainActor static func row(_ title: String, current: Double, start: Double, end: Double?) -> some View {
        let layout = TimelineInteractionLayout(width: 640, viewport: .full(duration: 100))
        return VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.primary)
            ZStack(alignment: .topLeading) {
                RangeBar(start: 0, span: 100, current: current, draftInPoint: start, draftOutPoint: end,
                         segments: [], selectedSegmentID: nil, keyframes: [0, 20, 40, 60, 80], fastCandidates: [:])
                    .padding(.horizontal, layout.inset)
                DraftRangeGrip(isStart: true)
                    .offset(x: layout.x(for: start) - 24, y: 40)
                if let end {
                    DraftRangeGrip(isStart: false)
                        .offset(x: layout.x(for: end), y: 40)
                }
            }.frame(width: 640, height: 84)
        }
    }
}
