@preconcurrency import AVFoundation
import AppKit
import Combine
import CryptoKit
import Foundation
import TrimletCore

@MainActor
final class PlayerController: ObservableObject {
    @Published private(set) var player = AVPlayer()
    @Published private(set) var currentURL: URL?
    @Published private(set) var durationSeconds = 0.0
    @Published private(set) var currentSeconds = 0.0
    @Published private(set) var nominalFrameRate = 30.0
    @Published private(set) var playbackState: PlaybackState = .paused
    @Published private(set) var isLoading = false
    @Published private(set) var isExporting = false
    @Published private(set) var isDropTargeted = false
    @Published private(set) var statusMessage = "動画をドロップするか、「動画を開く」を選んでください。"
    @Published private(set) var keyframeIndex: KeyframeIndex?
    @Published private(set) var activeOperation: OperationStatus?
    @Published var trimRange = TrimRange()
    @Published var exportMode: ExportMode = .fast

    private var progressTask: Task<Void, Never>?
    private var shouldStopAtOutPoint = false
    private var playbackIntent = false
    private var exportProcess: Process?
    private var exportWasCancelled = false
    private var proxyProcess: Process?
    private var proxyWasCancelled = false
    private var analysisProcess: Process?
    private var operationProgressURL: URL?
    private var operationExpectedDuration: Double?
    private var sourceHasAudio = false
    private var exportTemporaryURL: URL?
    private var exportDestinationURL: URL?

    var hasMedia: Bool {
        currentURL != nil && durationSeconds > 0
    }

    var canExport: Bool {
        hasMedia && trimRange.isValid && !isExporting
    }

    var isPlaybackActive: Bool { playbackIntent }

    var fastCandidate: FastCutCandidate? {
        keyframeIndex?.fastCandidate(for: trimRange)
    }

    var currentTimecode: String {
        TimecodeFormatter.string(seconds: currentSeconds, framesPerSecond: nominalFrameRate)
    }

    var durationTimecode: String {
        TimecodeFormatter.string(seconds: durationSeconds, framesPerSecond: nominalFrameRate)
    }

    var selectedDurationText: String {
        guard let selectedDuration = trimRange.duration else { return "--:--:--:--" }
        return TimecodeFormatter.string(seconds: selectedDuration, framesPerSecond: nominalFrameRate)
    }

    init() {
        progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.refreshPlaybackPosition()
                self.refreshOperationProgress()
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
    }

    func setDropTargeted(_ targeted: Bool) {
        isDropTargeted = targeted
    }

    func open(_ url: URL) {
        guard url.isFileURL else {
            statusMessage = "ローカル動画ファイルを選んでください。"
            return
        }

        player.pause()
        playbackIntent = false
        playbackState = .paused
        cancelAnalysis()
        isLoading = true
        statusMessage = "動画を解析しています…"
        trimRange.reset()
        currentSeconds = 0
        durationSeconds = 0
        nominalFrameRate = 30
        sourceHasAudio = false
        keyframeIndex = nil

        let extensionName = url.pathExtension.lowercased()
        if extensionName == "m2ts" || extensionName == "mts" {
            createProxy(for: url)
        } else {
            loadPlayableAsset(at: url, sourceURL: url, usesProxy: false, allowProxyFallback: true)
        }
    }

    private func loadPlayableAsset(
        at playbackURL: URL,
        sourceURL: URL,
        usesProxy: Bool,
        allowProxyFallback: Bool
    ) {
        let asset = AVURLAsset(url: playbackURL)

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let duration = try await asset.load(.duration)
                let tracks = try await asset.loadTracks(withMediaType: .video)
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                let seconds = duration.seconds

                guard seconds.isFinite, seconds > 0, !tracks.isEmpty else {
                    throw PlayerError.noPlayableVideo
                }

                var frameRate = 30.0
                if let videoTrack = tracks.first {
                    let loadedFrameRate = try await videoTrack.load(.nominalFrameRate)
                    if loadedFrameRate > 0 {
                        frameRate = Double(loadedFrameRate)
                    }
                }

                self.currentURL = sourceURL
                self.sourceHasAudio = !audioTracks.isEmpty
                self.durationSeconds = seconds
                self.nominalFrameRate = frameRate
                self.trimRange = TrimRange(inPoint: 0, outPoint: seconds)
                self.player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
                self.isLoading = false
                if usesProxy {
                    self.statusMessage = "\(sourceURL.lastPathComponent) — プロキシでプレビュー中（書き出しは原本を使用）"
                } else {
                    self.statusMessage = "\(sourceURL.lastPathComponent) — \(Self.fileSizeText(for: sourceURL))"
                }
                self.analyzeKeyframes(sourceURL: sourceURL)
            } catch {
                if allowProxyFallback {
                    self.createProxy(for: sourceURL)
                } else {
                    self.currentURL = nil
                    self.player.replaceCurrentItem(with: nil)
                    self.isLoading = false
                    self.statusMessage = "動画または生成したプロキシを再生できませんでした。"
                }
            }
        }
    }

    private func createProxy(for sourceURL: URL) {
        guard let ffmpegURL = Self.ffmpegURL(),
              let proxyURL = Self.proxyURL(for: sourceURL) else {
            currentURL = nil
            isLoading = false
            statusMessage = "プロキシ生成に必要なFFmpegまたは保存先を準備できません。"
            return
        }

        if FileManager.default.fileExists(atPath: proxyURL.path) {
            statusMessage = "既存のプロキシを読み込んでいます…"
            loadPlayableAsset(
                at: proxyURL,
                sourceURL: sourceURL,
                usesProxy: true,
                allowProxyFallback: false
            )
            return
        }

        let process = Process()
        process.executableURL = ffmpegURL
        let progressURL = Self.temporaryURL(extension: "progress")
        process.arguments = [
            "-hide_banner",
            "-loglevel", "error",
            "-nostats",
            "-y",
            "-progress", progressURL.path,
            "-stats_period", "0.1",
            "-i", sourceURL.path,
            "-map", "0:v:0",
            "-map", "0:a:0?",
            "-vf", "scale='min(1280,iw)':-2",
            "-c:v", "h264_videotoolbox",
            "-b:v", "4M",
            "-c:a", "aac",
            "-b:a", "128k",
            "-movflags", "+faststart",
            proxyURL.path
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice
        proxyProcess = process
        proxyWasCancelled = false
        isLoading = true
        statusMessage = "プレビュー用プロキシを生成しています…"
        beginOperation(
            kind: .proxy,
            title: "プレビューを準備中",
            detail: sourceURL.lastPathComponent,
            progressURL: progressURL,
            expectedDuration: nil
        )

        process.terminationHandler = { [weak self] completedProcess in
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let details = String(data: errorData, encoding: .utf8) ?? ""
            Task { @MainActor in
                guard let self else { return }
                self.proxyProcess = nil
                if self.proxyWasCancelled {
                    try? FileManager.default.removeItem(at: proxyURL)
                    self.currentURL = nil
                    self.isLoading = false
                    self.statusMessage = "プロキシ生成をキャンセルしました。"
                    self.finishOperation(.cancelled, detail: self.statusMessage)
                    self.proxyWasCancelled = false
                } else if completedProcess.terminationStatus == 0 {
                    self.finishOperation(.completed, detail: "プロキシを作成しました。")
                    self.statusMessage = "プロキシを読み込んでいます…"
                    self.loadPlayableAsset(
                        at: proxyURL,
                        sourceURL: sourceURL,
                        usesProxy: true,
                        allowProxyFallback: false
                    )
                } else {
                    try? FileManager.default.removeItem(at: proxyURL)
                    self.currentURL = nil
                    self.isLoading = false
                    let lastLine = details
                        .split(separator: "\n")
                        .last
                        .map(String.init) ?? "不明なエラー"
                    self.statusMessage = "プロキシ生成に失敗しました：\(lastLine)"
                    self.finishOperation(.failed, detail: self.statusMessage)
                }
            }
        }

        do {
            try process.run()
        } catch {
            proxyProcess = nil
            currentURL = nil
            isLoading = false
            statusMessage = "プロキシ生成を開始できませんでした：\(error.localizedDescription)"
            finishOperation(.failed, detail: statusMessage)
        }
    }

    func togglePlayback() {
        guard hasMedia else { return }

        if playbackIntent {
            player.pause()
            playbackIntent = false
            playbackState = .paused
            shouldStopAtOutPoint = false
        } else {
            if currentSeconds >= durationSeconds - 0.01 {
                seek(to: 0)
            }
            shouldStopAtOutPoint = false
            playbackIntent = true
            playbackState = .waiting
            player.play()
        }
    }

    func step(by count: Int) {
        guard hasMedia, let item = player.currentItem else { return }
        player.pause()
        playbackIntent = false
        playbackState = .paused
        shouldStopAtOutPoint = false
        item.step(byCount: count)
        refreshPlaybackPosition()
    }

    func seek(to seconds: Double) {
        guard hasMedia else { return }
        let clamped = min(max(0, seconds), durationSeconds)
        let time = CMTime(seconds: clamped, preferredTimescale: 60_000)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentSeconds = clamped
    }

    func jump(by seconds: Double) {
        seek(to: currentSeconds + seconds)
    }

    func setInPoint() {
        guard hasMedia else { return }
        trimRange.inPoint = currentSeconds
        trimRange.clamp(to: durationSeconds)
        statusMessage = "IN点を \(currentTimecode) に設定しました。"
    }

    func setOutPoint() {
        guard hasMedia else { return }
        trimRange.outPoint = currentSeconds
        trimRange.clamp(to: durationSeconds)
        statusMessage = "OUT点を \(currentTimecode) に設定しました。"
    }

    func goToInPoint() {
        guard let inPoint = trimRange.inPoint else { return }
        seek(to: inPoint)
    }

    func goToOutPoint() {
        guard let outPoint = trimRange.outPoint else { return }
        seek(to: outPoint)
    }

    func previewSelection() {
        guard let inPoint = trimRange.inPoint,
              let outPoint = trimRange.outPoint,
              outPoint > inPoint else {
            statusMessage = "IN点をOUT点より前に設定してください。"
            return
        }

        seek(to: inPoint)
        shouldStopAtOutPoint = true
        playbackIntent = true
        playbackState = .waiting
        player.play()
        statusMessage = "選択範囲をプレビューしています。"
    }

    func export(to destination: URL) {
        guard let source = currentURL,
              let inPoint = trimRange.inPoint,
              let selectedDuration = trimRange.duration,
              let ffmpegURL = Self.ffmpegURL(),
              let ffprobeURL = Self.ffprobeURL() else {
            statusMessage = "書き出し条件またはFFmpegを確認できません。"
            return
        }

        let temporaryURL = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.deletingPathExtension().lastPathComponent)-trimlet-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        let progressURL = Self.temporaryURL(extension: "progress")
        let expectsAudio = sourceHasAudio
        let process = Process()
        process.executableURL = ffmpegURL
        let plan = FFmpegExportPlan(
            source: source,
            destination: temporaryURL,
            inPoint: inPoint,
            duration: selectedDuration,
            mode: exportMode,
            progressURL: progressURL
        )
        process.arguments = plan.arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        isExporting = true
        exportWasCancelled = false
        statusMessage = "\(exportMode.title)モードで書き出しています…"
        exportProcess = process
        exportTemporaryURL = temporaryURL
        exportDestinationURL = destination
        beginOperation(
            kind: .export,
            title: "MP4を書き出し中",
            detail: "\(exportMode.title) — \(destination.lastPathComponent)",
            progressURL: progressURL,
            expectedDuration: selectedDuration
        )

        process.terminationHandler = { [weak self] completedProcess in
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let details = String(data: errorData, encoding: .utf8) ?? ""
            let validation = completedProcess.terminationStatus == 0
                ? MediaProbe.validateOutput(
                    at: temporaryURL,
                    expectedDuration: selectedDuration,
                    expectsAudio: expectsAudio,
                    ffprobeURL: ffprobeURL
                )
                : nil
            Task { @MainActor in
                guard let self else { return }
                self.exportProcess = nil
                self.isExporting = false
                if self.exportWasCancelled {
                    try? FileManager.default.removeItem(at: temporaryURL)
                    self.statusMessage = "書き出しをキャンセルしました。"
                    self.finishOperation(.cancelled, detail: self.statusMessage)
                    self.exportWasCancelled = false
                } else if let validation, validation.isValid {
                    do {
                        if FileManager.default.fileExists(atPath: destination.path) {
                            try FileManager.default.removeItem(at: destination)
                        }
                        try FileManager.default.moveItem(at: temporaryURL, to: destination)
                        self.statusMessage = "書き出しと検証が完了しました：\(destination.lastPathComponent)"
                        self.finishOperation(.completed, detail: validation.message, outputURL: destination)
                    } catch {
                        try? FileManager.default.removeItem(at: temporaryURL)
                        self.statusMessage = "完成ファイルを保存できませんでした：\(error.localizedDescription)"
                        self.finishOperation(.failed, detail: self.statusMessage)
                    }
                } else if let validation {
                    try? FileManager.default.removeItem(at: temporaryURL)
                    self.statusMessage = "書き出し後の検証に失敗しました：\(validation.message)"
                    self.finishOperation(.failed, detail: self.statusMessage)
                } else {
                    try? FileManager.default.removeItem(at: temporaryURL)
                    let lastLine = details
                        .split(separator: "\n")
                        .last
                        .map(String.init) ?? "不明なエラー"
                    self.statusMessage = "書き出しに失敗しました：\(lastLine)"
                    self.finishOperation(.failed, detail: self.statusMessage)
                }
                self.exportTemporaryURL = nil
                self.exportDestinationURL = nil
            }
        }

        do {
            try process.run()
        } catch {
            exportProcess = nil
            isExporting = false
            try? FileManager.default.removeItem(at: temporaryURL)
            statusMessage = "FFmpegを開始できませんでした：\(error.localizedDescription)"
            finishOperation(.failed, detail: statusMessage)
        }
    }

    func cancelExport() {
        exportWasCancelled = true
        exportProcess?.terminate()
        statusMessage = "書き出しをキャンセルしています…"
    }

    func cancelActiveOperation() {
        switch activeOperation?.kind {
        case .export: cancelExport()
        case .proxy:
            proxyWasCancelled = true
            proxyProcess?.terminate()
            statusMessage = "プロキシ生成をキャンセルしています…"
        case .analysis:
            cancelAnalysis()
            finishOperation(.cancelled, detail: "キーフレーム解析をキャンセルしました。")
        case nil: break
        }
    }

    func dismissOperation() {
        guard activeOperation?.result != .running else { return }
        activeOperation = nil
    }

    func revealCompletedOutput() {
        guard let url = activeOperation?.outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func refreshPlaybackPosition() {
        guard currentURL != nil else { return }
        let seconds = player.currentTime().seconds
        if seconds.isFinite {
            currentSeconds = min(max(0, seconds), durationSeconds)
        }

        if shouldStopAtOutPoint,
           let outPoint = trimRange.outPoint,
           currentSeconds >= outPoint {
            player.pause()
            playbackIntent = false
            playbackState = .paused
            shouldStopAtOutPoint = false
            seek(to: outPoint)
            statusMessage = "選択範囲のプレビューが終了しました。"
        } else {
            switch player.timeControlStatus {
            case .playing:
                playbackState = .playing
            case .waitingToPlayAtSpecifiedRate:
                playbackState = playbackIntent ? .waiting : .paused
            case .paused:
                if currentSeconds >= durationSeconds - max(0.01, 1 / nominalFrameRate) {
                    playbackIntent = false
                }
                playbackState = playbackIntent ? .waiting : .paused
            @unknown default:
                playbackState = playbackIntent ? .waiting : .paused
            }
        }
    }

    private func analyzeKeyframes(sourceURL: URL) {
        guard let ffprobeURL = Self.ffprobeURL() else { return }
        cancelAnalysis()
        let mediaDuration = durationSeconds

        let outputURL = Self.temporaryURL(extension: "json")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        guard let outputHandle = try? FileHandle(forWritingTo: outputURL) else { return }

        let process = Process()
        process.executableURL = ffprobeURL
        process.arguments = [
            "-v", "error",
            "-select_streams", "v:0",
            "-show_packets",
            "-show_entries", "packet=pts_time,flags",
            "-show_entries", "stream=start_time",
            "-of", "json",
            sourceURL.path
        ]
        process.standardOutput = outputHandle
        let errorPipe = Pipe()
        process.standardError = errorPipe
        analysisProcess = process
        beginOperation(
            kind: .analysis,
            title: "キーフレームを解析中",
            detail: sourceURL.lastPathComponent,
            progressURL: nil,
            expectedDuration: nil
        )

        process.terminationHandler = { [weak self] completedProcess in
            try? outputHandle.close()
            let data = (try? Data(contentsOf: outputURL)) ?? Data()
            try? FileManager.default.removeItem(at: outputURL)
            let parsed = try? MediaProbe.keyframeIndex(from: data, duration: mediaDuration)
            Task { @MainActor in
                guard let self, self.analysisProcess === completedProcess else { return }
                self.analysisProcess = nil
                if completedProcess.terminationStatus == 0, let parsed {
                    self.keyframeIndex = parsed
                    self.finishOperation(.completed, detail: "\(parsed.keyframes.count)個のキーフレームを検出しました。", autoDismiss: true)
                } else {
                    self.finishOperation(.failed, detail: "キーフレームを解析できませんでした。")
                }
            }
        }

        do {
            try process.run()
        } catch {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: outputURL)
            analysisProcess = nil
            finishOperation(.failed, detail: "キーフレーム解析を開始できませんでした。")
        }
    }

    private func cancelAnalysis() {
        analysisProcess?.terminate()
        analysisProcess = nil
    }

    private func beginOperation(
        kind: OperationKind,
        title: String,
        detail: String,
        progressURL: URL?,
        expectedDuration: Double?
    ) {
        operationProgressURL = progressURL
        operationExpectedDuration = expectedDuration
        activeOperation = OperationStatus(kind: kind, title: title, detail: detail, progress: nil)
    }

    private func finishOperation(
        _ result: OperationResult,
        detail: String,
        outputURL: URL? = nil,
        autoDismiss: Bool = false
    ) {
        guard var operation = activeOperation else { return }
        operation.result = result
        operation.title = switch result {
        case .running: operation.title
        case .completed: operation.kind == .export ? "書き出し完了" : "処理が完了しました"
        case .failed: "処理に失敗しました"
        case .cancelled: "処理をキャンセルしました"
        }
        operation.detail = detail
        operation.progress = result == .completed ? 1 : operation.progress
        operation.outputURL = outputURL
        activeOperation = operation
        if let progressURL = operationProgressURL {
            try? FileManager.default.removeItem(at: progressURL)
        }
        operationProgressURL = nil
        operationExpectedDuration = nil

        if autoDismiss {
            let operationID = operation.id
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                if self?.activeOperation?.id == operationID {
                    self?.activeOperation = nil
                }
            }
        }
    }

    private func refreshOperationProgress() {
        guard var operation = activeOperation,
              operation.result == .running,
              let progressURL = operationProgressURL,
              let data = try? Data(contentsOf: progressURL),
              let text = String(data: data, encoding: .utf8) else { return }

        guard let seconds = FFmpegProgress.elapsedSeconds(from: text) else { return }
        if let expected = operationExpectedDuration, expected > 0 {
            operation.progress = min(0.99, seconds / expected)
        }
        operation.detail = operationExpectedDuration == nil
            ? String(format: "処理済み %.1f 秒", seconds)
            : String(format: "%.0f%% — %.1f / %.1f 秒", (operation.progress ?? 0) * 100, seconds, operationExpectedDuration ?? 0)
        activeOperation = operation
    }

    private static func ffmpegURL() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg"
        ]
        return candidates
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
            .map(URL.init(fileURLWithPath:))
    }

    private static func ffprobeURL() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/ffprobe",
            "/usr/local/bin/ffprobe"
        ]
        return candidates
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
            .map(URL.init(fileURLWithPath:))
    }

    private static func temporaryURL(extension extensionName: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("trimlet-\(UUID().uuidString)")
            .appendingPathExtension(extensionName)
    }

    private static func proxyURL(for sourceURL: URL) -> URL? {
        do {
            let cacheRoot = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let proxyDirectory = cacheRoot
                .appendingPathComponent("Trimlet", isDirectory: true)
                .appendingPathComponent("Proxies", isDirectory: true)
            try FileManager.default.createDirectory(
                at: proxyDirectory,
                withIntermediateDirectories: true
            )

            let values = try? sourceURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let fingerprint = [
                sourceURL.standardizedFileURL.path,
                String(values?.fileSize ?? 0),
                String(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
            ].joined(separator: "|")
            let digest = SHA256.hash(data: Data(fingerprint.utf8))
            let identifier = digest.map { String(format: "%02x", $0) }.joined()
            return proxyDirectory.appendingPathComponent(identifier).appendingPathExtension("mp4")
        } catch {
            return nil
        }
    }

    private static func fileSizeText(for url: URL) -> String {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else {
            return "サイズ不明"
        }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

private enum PlayerError: Error {
    case noPlayableVideo
}
