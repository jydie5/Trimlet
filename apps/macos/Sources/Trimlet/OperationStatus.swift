import Foundation

enum PlaybackState: Equatable {
    case paused
    case waiting
    case playing
}

enum KeyframeAnalysisState: Equatable {
    case idle
    case running
    case ready(count: Int)
    case failed
}

enum OperationKind: String, Equatable {
    case export
    case proxy
}

enum OperationResult: Equatable {
    case running
    case completed
    case failed
    case cancelled
}

struct OperationStatus: Identifiable, Equatable {
    let id = UUID()
    let kind: OperationKind
    var title: String
    var detail: String
    var progress: Double?
    var result: OperationResult = .running
    var outputURL: URL?

    var canCancel: Bool { result == .running }
}
