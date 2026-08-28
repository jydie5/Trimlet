import Foundation

public struct TrimRange: Equatable, Sendable {
    public var inPoint: Double?
    public var outPoint: Double?

    public init(inPoint: Double? = nil, outPoint: Double? = nil) {
        self.inPoint = inPoint
        self.outPoint = outPoint
    }

    public var duration: Double? {
        guard let inPoint, let outPoint, outPoint > inPoint else {
            return nil
        }
        return outPoint - inPoint
    }

    public var isValid: Bool {
        duration != nil
    }

    public mutating func reset() {
        inPoint = nil
        outPoint = nil
    }

    public mutating func clamp(to mediaDuration: Double) {
        guard mediaDuration.isFinite, mediaDuration >= 0 else {
            reset()
            return
        }

        if let inPoint {
            self.inPoint = min(max(0, inPoint), mediaDuration)
        }
        if let outPoint {
            self.outPoint = min(max(0, outPoint), mediaDuration)
        }
    }
}

public enum ExportMode: String, CaseIterable, Identifiable, Sendable {
    case fast
    case accurate

    public var id: Self { self }

    public var title: String {
        switch self {
        case .fast: "高速"
        case .accurate: "フレーム正確"
        }
    }

    public var explanation: String {
        switch self {
        case .fast:
            "映像を再エンコードせず高速に切り出します。位置はキーフレームに寄り、音声は互換性のため変換する場合があります。"
        case .accurate:
            "指定位置を優先し、Apple Siliconのハードウェア機能でH.264へ変換します。"
        }
    }
}

public enum TimecodeFormatter {
    public static func string(seconds: Double, framesPerSecond: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else {
            return "00:00:00:00"
        }

        let fps = max(1, Int(framesPerSecond.rounded()))
        let wholeSeconds = Int(seconds)
        let hours = wholeSeconds / 3_600
        let minutes = (wholeSeconds % 3_600) / 60
        let secondsPart = wholeSeconds % 60
        let fractional = seconds - Double(wholeSeconds)
        let frame = min(fps - 1, max(0, Int((fractional * Double(fps)).rounded(.down))))

        return String(
            format: "%02d:%02d:%02d:%02d",
            hours,
            minutes,
            secondsPart,
            frame
        )
    }
}
