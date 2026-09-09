import SwiftUI
import TrimletCore

/// Rendering only: source-time mapping and interaction live in SourceTimeline.
struct RangeBar: View {
    let start: Double
    let span: Double
    let current: Double
    let draftInPoint: Double?
    let draftOutPoint: Double?
    let segments: [EditSegment]
    let selectedSegmentID: UUID?
    let keyframes: [Double]
    let fastCandidates: [UUID: FastCutCandidate?]

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let safeSpan = max(span, 0.001)
            func x(_ time: Double) -> Double { (time - start) / safeSpan * width }
            func band(_ from: Double, _ to: Double, y: Double, height: Double) -> CGRect? {
                let left = max(0, x(from)), right = min(width, x(to))
                guard right > left else { return nil }
                return CGRect(x: left, y: y, width: right - left, height: height)
            }
            context.fill(Path(roundedRect: CGRect(x: 0, y: 40, width: width, height: 32), cornerRadius: 4), with: .color(.secondary.opacity(0.12)))
            for tick in 0...4 {
                let fraction = Double(tick) / 4
                let position = fraction * width
                let label = Text(String(format: "%.2fs", start + fraction * safeSpan)).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                context.draw(label, at: CGPoint(x: position, y: 5), anchor: tick == 0 ? .topLeading : tick == 4 ? .topTrailing : .top)
                var line = Path()
                line.move(to: CGPoint(x: position, y: 20))
                line.addLine(to: CGPoint(x: position, y: 72))
                context.stroke(line, with: .color(.secondary.opacity(0.16)), lineWidth: 1)
            }
            for segment in segments {
                if let rect = band(segment.inPoint.seconds, segment.outPoint.seconds, y: 48, height: 16) {
                    context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.blue.opacity(segment.id == selectedSegmentID ? 0.85 : 0.48)))
                }
                if let candidate = fastCandidates[segment.id] ?? nil,
                   let rect = band(candidate.start, candidate.end, y: 45, height: 22) {
                    context.stroke(Path(roundedRect: rect, cornerRadius: 3), with: .color(.orange), lineWidth: 1)
                }
            }
            if let a = draftInPoint, let b = draftOutPoint,
               let rect = band(a, b, y: 42, height: 28) {
                context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(.purple.opacity(0.5)))
                context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(.purple), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            var lastMark = -Double.infinity
            for (point, color) in [(draftInPoint, Color.green), (draftOutPoint, Color.red)] {
                if let point, point >= start, point <= start + safeSpan {
                    context.fill(Path(CGRect(x: x(point) - 1, y: 42, width: 2, height: 28)), with: .color(color))
                }
            }
            for time in keyframes where time >= start && time <= start + safeSpan {
                let position = x(time)
                guard position - lastMark >= 4 else { continue }
                lastMark = position
                context.fill(Path(CGRect(x: position, y: 31, width: 1, height: 6)), with: .color(.orange))
            }
            if current >= start && current <= start + safeSpan {
                let position = x(current)
                context.fill(Path(CGRect(x: position - 2, y: 26, width: 4, height: 48)), with: .color(.black.opacity(0.65)))
                context.fill(Path(CGRect(x: position - 1, y: 26, width: 2, height: 48)), with: .color(.white))
                var head = Path()
                head.move(to: CGPoint(x: position - 9, y: 19))
                head.addLine(to: CGPoint(x: position + 9, y: 19))
                head.addLine(to: CGPoint(x: position, y: 30))
                head.closeSubpath()
                context.fill(head, with: .color(.white))
                context.stroke(head, with: .color(.black.opacity(0.7)), lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
    }
}
