import Foundation

public enum FFmpegProgress {
    public static func elapsedSeconds(from text: String) -> Double? {
        var latestMicroseconds: Double?
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2,
                  parts[0] == "out_time_us" || parts[0] == "out_time_ms",
                  let value = Double(parts[1]) else { continue }
            latestMicroseconds = value
        }
        return latestMicroseconds.map { max(0, $0 / 1_000_000) }
    }
}
