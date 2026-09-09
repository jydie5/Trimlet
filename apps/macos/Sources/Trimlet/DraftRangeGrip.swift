import SwiftUI

/// Rendering only. SourceTimeline owns the exclusive outward hit regions.
struct DraftRangeGrip: View {
    let isStart: Bool
    var highlighted = false

    var body: some View {
        Text(isStart ? "IN" : "OUT")
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(isStart ? Color.green : Color.red)
            .frame(width: 24, height: 32)
            .background((isStart ? Color.green : Color.red).opacity(highlighted ? 0.2 : 0.08))
            .overlay {
                Path { path in
                    let edge: CGFloat = isStart ? 24 : 0
                    let tip: CGFloat = isStart ? 14 : 10
                    path.move(to: CGPoint(x: tip, y: 2))
                    path.addLine(to: CGPoint(x: edge, y: 2))
                    path.addLine(to: CGPoint(x: edge, y: 30))
                    path.addLine(to: CGPoint(x: tip, y: 30))
                }.stroke(isStart ? Color.green : Color.red, lineWidth: highlighted ? 3 : 2)
            }
    }
}
