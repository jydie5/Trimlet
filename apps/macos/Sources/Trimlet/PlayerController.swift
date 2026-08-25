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
    @Published private(set) var editList = EditList()
    @Published private(set) var selectedSegmentID: UUID?
    @Published private(set) var trimmingSegmentID: UUID?
    @Published private(set) var clipThumbnails: [UUID: NSImage] = [:]
    @Published private(set) var audioStreams: [MediaProbe.AudioStreamInfo] = []
    @Published var trimRange = TrimRange()
    @Published var clipNameDraft = ""
    @Published var exportMode: ExportMode = .fast
    @Published var selectedAudioStreamIndex: Int?

    private var progressTask: Task<Void, Never>?
    private var playbackIntent = false
    private var exportProcess: Process?
    private var exportWasCancelled = false
    private var proxyProcess: Process?
    private var proxyWasCancelled = false
    private var analysisProcess: Process?
    private var operationProgressURL: URL?
    private var operationExpectedDuration: Double?
    private var operationStageDetail: String?
    private var sourceHasAudio = false
    private var exportTemporaryURL: URL?
    private var exportDestinationURL: URL?
    private var exportWorkingDirectory: URL?
    private var exportCompletedDuration = 0.0
    private var editUndoStack: [EditList] = []
    private var editRedoStack: [EditList] = []
    private var previewRanges: [TrimRange] = []
    private var previewRangeIndex: Int?
    private var thumbnailGenerators: [UUID: AVAssetImageGenerator] = [:]

    var hasMedia: Bool {
        currentURL != nil && durationSeconds > 0
    }

    var canExport: Bool {
        hasMedia
            && !editList.isEmpty
            && !isExporting
            && (exportMode == .accurate || fastCandidates.values.allSatisfy { $0 != nil })
    }

    var isPlaybackActive: Bool { playbackIntent }

    var fastCandidate: FastCutCandidate? {
        keyframeIndex?.fastCandidate(for: trimRange)
    }

    var fastCandidates: [UUID: FastCutCandidate?] {
        Dictionary(uniqueKeysWithValues: editList.segments.map { segment in
            (segment.id, keyframeIndex?.fastCandidate(for: segment.trimRange))
        })
    }

    var selectedSegment: EditSegment? { editList.segment(id: selectedSegmentID) }
    var canUndoEdit: Bool { !editUndoStack.isEmpty }
    var canRedoEdit: Bool { !editRedoStack.isEmpty }

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

    var totalDurationText: String {
        TimecodeFormatter.string(
            seconds: editList.totalDurationSeconds,
            framesPerSecond: nominalFrameRate
        )
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
        guard !isExporting else {
            statusMessage = "書き出し完了後に別の動画を開いてください。"
            return
        }
        guard url.isFileURL else {
            statusMessage = "ローカル動画ファイルを選んでください。"
            return
        }

        player.pause()
        playbackIntent = false
        playbackState = .paused
        cancelPreviewSequence()
        cancelAnalysis()
        isLoading = true
        statusMessage = "動画を解析しています…"
        trimRange.reset()
        editList = EditList()
        selectedSegmentID = nil
        trimmingSegmentID = nil
        editUndoStack.removeAll()
        editRedoStack.removeAll()
        clipNameDraft = ""
        thumbnailGenerators.values.forEach { $0.cancelAllCGImageGeneration() }
        thumbnailGenerators.removeAll()
        clipThumbnails.removeAll()
        currentSeconds = 0
        durationSeconds = 0
        nominalFrameRate = 30
        sourceHasAudio = false
        audioStreams = []
        selectedAudioStreamIndex = nil
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
                self.durationSeconds = seconds
                self.nominalFrameRate = frameRate
                self.trimRange.reset()
                self.player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
                if let ffprobeURL = Self.ffprobeURL() {
                    let streams = await MediaProbe.audioStreams(at: sourceURL, ffprobeURL: ffprobeURL)
                    self.audioStreams = streams
                    self.selectedAudioStreamIndex = streams.first?.index
                    self.sourceHasAudio = !streams.isEmpty
                } else {
                    self.audioStreams = []
                    self.selectedAudioStreamIndex = nil
                    self.sourceHasAudio = !audioTracks.isEmpty
                }
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
        cancelPreviewSequence()

        if playbackIntent {
            player.pause()
            playbackIntent = false
            playbackState = .paused
        } else {
            if currentSeconds >= durationSeconds - 0.01 {
                seekWithoutCancellingPreview(to: 0)
            }
            playbackIntent = true
            playbackState = .waiting
            player.play()
        }
    }

    func step(by count: Int) {
        guard hasMedia, let item = player.currentItem else { return }
        cancelPreviewSequence()
        player.pause()
        playbackIntent = false
        playbackState = .paused
        item.step(byCount: count)
        refreshPlaybackPosition()
    }

    func seek(to seconds: Double) {
        cancelPreviewSequence()
        seekWithoutCancellingPreview(to: seconds)
    }

    private func seekWithoutCancellingPreview(to seconds: Double) {
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
        if let outPoint = trimRange.outPoint, outPoint <= currentSeconds {
            trimRange.outPoint = nil
        }
        trimRange.clamp(to: durationSeconds)
        statusMessage = "IN点を \(currentTimecode) に設定しました。次にOUT点を決めてください。"
    }

    func setOutPoint() {
        guard hasMedia else { return }
        guard let inPoint = trimRange.inPoint else {
            statusMessage = "先に①IN点を設定してください。"
            return
        }
        guard currentSeconds > inPoint else {
            statusMessage = "OUT点はIN点より後ろに設定してください。"
            return
        }
        trimRange.outPoint = currentSeconds
        trimRange.clamp(to: durationSeconds)
        statusMessage = "OUT点を \(currentTimecode) に設定しました。③シーケンスへ追加できます。"
    }

    func goToInPoint() {
        guard let inPoint = trimRange.inPoint else { return }
        seek(to: inPoint)
    }

    func goToOutPoint() {
        guard let outPoint = trimRange.outPoint else { return }
        seek(to: outPoint)
    }

    func addDraftSegment() {
        do {
            let segment = try EditSegment(
                range: trimRange,
                name: defaultClipName(for: trimRange)
            )
            var next = editList
            try next.append(segment, sourceDuration: MediaTimestamp(seconds: durationSeconds))
            commitEditList(next)
            generateThumbnail(for: segment)
            selectedSegmentID = nil
            trimmingSegmentID = nil
            clipNameDraft = ""
            trimRange.reset()
            statusMessage = "「\(segment.name ?? "クリップ")」を編集シーケンスへ追加しました。次のサブクリップを作成できます。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func updateSelectedSegment() {
        guard let trimmingSegmentID else {
            statusMessage = "先に選択したクリップの「トリム編集」を押してください。"
            return
        }
        guard let existingSegment = editList.segment(id: trimmingSegmentID) else {
            statusMessage = "トリムするクリップが見つかりません。"
            return
        }
        do {
            let segment = try EditSegment(
                id: trimmingSegmentID,
                range: trimRange,
                name: existingSegment.name
            )
            var next = editList
            try next.update(segment, sourceDuration: MediaTimestamp(seconds: durationSeconds))
            commitEditList(next)
            generateThumbnail(for: segment)
            statusMessage = "選択したクリップのトリムを更新しました。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func selectSegment(_ id: UUID) {
        guard let segment = editList.segment(id: id) else { return }
        if let trimmingSegmentID, trimmingSegmentID != id {
            self.trimmingSegmentID = nil
            trimRange.reset()
        }
        selectedSegmentID = id
        clipNameDraft = segment.name ?? ""
        statusMessage = "「\(segment.name ?? "クリップ")」を選択しました。既存範囲を変更するときは「トリム編集」を押します。"
    }

    func beginTrimmingSelectedSegment() {
        guard let selectedSegment else {
            statusMessage = "トリムするクリップを選択してください。"
            return
        }
        trimmingSegmentID = selectedSegment.id
        trimRange = selectedSegment.trimRange
        statusMessage = "クリップをトリム中です。IN／OUTを変更してから「トリムを適用」を押してください。"
    }

    func startNewSegment() {
        selectedSegmentID = nil
        trimmingSegmentID = nil
        clipNameDraft = ""
        trimRange.reset()
        cancelPreviewSequence()
        statusMessage = "新しいサブクリップを作成します。①IN点から設定してください。"
    }

    func removeSelectedSegment() {
        guard let selectedSegmentID else { return }
        do {
            var next = editList
            try next.remove(id: selectedSegmentID)
            commitEditList(next)
            self.selectedSegmentID = nil
            if trimmingSegmentID == selectedSegmentID {
                self.trimmingSegmentID = nil
            }
            clipNameDraft = ""
            trimRange.reset()
            statusMessage = "クリップを編集シーケンスから削除しました。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func moveSelectedSegment(by offset: Int) {
        guard let selectedSegmentID else { return }
        do {
            var next = editList
            try next.move(id: selectedSegmentID, by: offset)
            guard next != editList else { return }
            commitEditList(next)
            statusMessage = "クリップの順序を変更しました。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func applySelectedClipName() {
        guard let selectedSegmentID,
              var segment = editList.segment(id: selectedSegmentID) else {
            statusMessage = "名前を変更するクリップを選択してください。"
            return
        }
        let name = clipNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            statusMessage = "クリップ名を入力してください。"
            return
        }
        guard segment.name != name else { return }
        do {
            segment.name = name
            var next = editList
            try next.update(segment, sourceDuration: MediaTimestamp(seconds: durationSeconds))
            commitEditList(next)
            statusMessage = "クリップ名を「\(name)」へ変更しました。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @discardableResult
    func moveSegment(_ id: UUID, to destinationIndex: Int) -> Bool {
        do {
            var next = editList
            try next.move(id: id, to: destinationIndex)
            guard next != editList else { return false }
            commitEditList(next)
            if let trimmingSegmentID, trimmingSegmentID != id {
                self.trimmingSegmentID = nil
                trimRange.reset()
            }
            selectedSegmentID = id
            clipNameDraft = editList.segment(id: id)?.name ?? ""
            statusMessage = "クリップを編集シーケンス内で移動しました。"
            return true
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }

    func undoEdit() {
        guard let previous = editUndoStack.popLast() else { return }
        editRedoStack.append(editList)
        editList = previous
        reconcileSegmentEditingStateAfterHistoryChange()
        cancelPreviewSequence()
        statusMessage = "区間編集を取り消しました。"
    }

    func redoEdit() {
        guard let next = editRedoStack.popLast() else { return }
        editUndoStack.append(editList)
        editList = next
        reconcileSegmentEditingStateAfterHistoryChange()
        cancelPreviewSequence()
        statusMessage = "区間編集をやり直しました。"
    }

    private func reconcileSegmentEditingStateAfterHistoryChange() {
        if let selectedSegmentID {
            if let segment = editList.segment(id: selectedSegmentID) {
                clipNameDraft = segment.name ?? ""
            } else {
                self.selectedSegmentID = nil
                clipNameDraft = ""
            }
        }

        if let trimmingSegmentID {
            if let segment = editList.segment(id: trimmingSegmentID) {
                trimRange = segment.trimRange
            } else {
                self.trimmingSegmentID = nil
                trimRange.reset()
            }
        }
    }

    private func defaultClipName(for range: TrimRange) -> String {
        let sourceName = currentURL?.deletingPathExtension().lastPathComponent ?? "クリップ"
        let inPoint = range.inPoint ?? 0
        let timecode = TimecodeFormatter.string(
            seconds: inPoint,
            framesPerSecond: nominalFrameRate
        )
        return "\(sourceName) · \(timecode)"
    }

    private func generateThumbnail(for segment: EditSegment) {
        guard let asset = player.currentItem?.asset else { return }

        thumbnailGenerators[segment.id]?.cancelAllCGImageGeneration()
        clipThumbnails[segment.id] = nil

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)
        thumbnailGenerators[segment.id] = generator

        let offset = min(0.1, segment.durationSeconds / 2)
        let requestedTime = CMTime(
            seconds: segment.inPoint.seconds + offset,
            preferredTimescale: 60_000
        )

        Task { @MainActor [weak self, generator] in
            guard let self else { return }
            defer {
                if self.thumbnailGenerators[segment.id] === generator {
                    self.thumbnailGenerators[segment.id] = nil
                }
            }
            do {
                let result = try await generator.image(at: requestedTime)
                guard self.thumbnailGenerators[segment.id] === generator else { return }
                self.clipThumbnails[segment.id] = NSImage(cgImage: result.image, size: .zero)
            } catch {
                // A placeholder remains visible when a frame cannot be generated.
            }
        }
    }

    private func commitEditList(_ next: EditList) {
        editUndoStack.append(editList)
        if editUndoStack.count > 100 { editUndoStack.removeFirst() }
        editRedoStack.removeAll()
        editList = next
        cancelPreviewSequence()
    }

    func previewSelection() {
        guard trimRange.isValid else {
            statusMessage = "IN点をOUT点より前に設定してください。"
            return
        }

        startPreview(ranges: [trimRange], message: "選択範囲をプレビューしています。")
    }

    func previewSelectedSegment() {
        guard let selectedSegment else {
            statusMessage = "プレビューするクリップを選択してください。"
            return
        }
        startPreview(ranges: [selectedSegment.trimRange], message: "クリップをプレビューしています。")
    }

    func previewAllSegments() {
        guard !editList.isEmpty else {
            statusMessage = "プレビューするクリップがありません。"
            return
        }
        startPreview(
            ranges: editList.segments.map(\.trimRange),
            message: "編集シーケンスを連続プレビューしています。"
        )
    }

    private func startPreview(ranges: [TrimRange], message: String) {
        guard let first = ranges.first, let inPoint = first.inPoint else { return }
        player.pause()
        previewRanges = ranges
        previewRangeIndex = 0
        seekWithoutCancellingPreview(to: inPoint)
        playbackIntent = true
        playbackState = .waiting
        player.play()
        statusMessage = message
    }

    private func cancelPreviewSequence() {
        previewRanges.removeAll()
        previewRangeIndex = nil
    }

    func export(to destination: URL) {
        guard let source = currentURL,
              let ffmpegURL = Self.ffmpegURL(),
              let ffprobeURL = Self.ffprobeURL() else {
            statusMessage = "書き出し条件またはFFmpegを確認できません。"
            return
        }

        guard !editList.isEmpty else {
            statusMessage = "書き出すクリップを編集シーケンスへ追加してください。"
            return
        }
        if sourceHasAudio && selectedAudioStreamIndex == nil {
            statusMessage = "音声ストリームを確認できません。動画を開き直してください。"
            return
        }

        let temporaryURL = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.deletingPathExtension().lastPathComponent)-trimlet-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimlet-export-\(UUID().uuidString)", isDirectory: true)

        let plan: MultiRangeExportPlan
        do {
            try FileManager.default.createDirectory(
                at: workingDirectory,
                withIntermediateDirectories: true
            )
            plan = try MultiRangeExportPlan(
                source: source,
                incompleteDestination: temporaryURL,
                workingDirectory: workingDirectory,
                editList: editList,
                mode: exportMode,
                selectedAudioStreamIndex: selectedAudioStreamIndex,
                selectedAudioCodecName: audioStreams.first {
                    $0.index == selectedAudioStreamIndex
                }?.codecName,
                keyframeIndex: keyframeIndex
            )
            try plan.concatListContents.write(
                to: plan.concatListURL,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            try? FileManager.default.removeItem(at: workingDirectory)
            statusMessage = error.localizedDescription
            return
        }

        isExporting = true
        exportWasCancelled = false
        exportCompletedDuration = 0
        statusMessage = "\(exportMode.title)モードで書き出しています…"
        exportTemporaryURL = temporaryURL
        exportDestinationURL = destination
        exportWorkingDirectory = workingDirectory
        beginOperation(
            kind: .export,
            title: "MP4を書き出し中",
            detail: "\(exportMode.title) — \(plan.segmentURLs.count)区間",
            progressURL: plan.stages.first?.progressURL,
            expectedDuration: plan.expectedDuration * 2
        )
        runExportStage(
            at: 0,
            plan: plan,
            ffmpegURL: ffmpegURL,
            ffprobeURL: ffprobeURL,
            destination: destination,
            temporaryURL: temporaryURL,
            workingDirectory: workingDirectory
        )
    }

    private func runExportStage(
        at index: Int,
        plan: MultiRangeExportPlan,
        ffmpegURL: URL,
        ffprobeURL: URL,
        destination: URL,
        temporaryURL: URL,
        workingDirectory: URL
    ) {
        guard plan.stages.indices.contains(index) else { return }
        if exportWasCancelled {
            finishCancelledExport(temporaryURL: temporaryURL, workingDirectory: workingDirectory)
            return
        }

        let stage = plan.stages[index]
        try? FileManager.default.removeItem(at: stage.progressURL)
        operationProgressURL = stage.progressURL
        operationStageDetail = switch stage.kind {
        case .segment(let segmentIndex):
            "区間 \(segmentIndex + 1) / \(plan.segmentURLs.count)"
        case .concatenate:
            "区間を1本に連結中"
        }
        if var operation = activeOperation {
            operation.detail = operationStageDetail ?? operation.detail
            activeOperation = operation
        }

        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = stage.arguments
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice
        exportProcess = process
        let expectsAudio = selectedAudioStreamIndex != nil

        process.terminationHandler = { [weak self] completedProcess in
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let details = String(data: errorData, encoding: .utf8) ?? ""
            let isFinalStage = index == plan.stages.count - 1
            let validation = completedProcess.terminationStatus == 0 && isFinalStage
                ? MediaProbe.validateOutput(
                    at: temporaryURL,
                    expectedDuration: plan.expectedDuration,
                    expectsAudio: expectsAudio,
                    durationTolerance: plan.mode == .accurate
                        ? max(0.25, plan.expectedDuration * 0.01)
                        : max(1, plan.expectedDuration * 0.03),
                    ffprobeURL: ffprobeURL
                )
                : nil
            Task { @MainActor in
                guard let self else { return }
                self.exportProcess = nil
                if self.exportWasCancelled {
                    self.finishCancelledExport(temporaryURL: temporaryURL, workingDirectory: workingDirectory)
                } else if completedProcess.terminationStatus != 0 {
                    let lastLine = details
                        .split(separator: "\n")
                        .last
                        .map(String.init) ?? "不明なエラー"
                    self.finishFailedExport(
                        "書き出しに失敗しました：\(lastLine)",
                        temporaryURL: temporaryURL,
                        workingDirectory: workingDirectory
                    )
                } else if let validation {
                    if validation.isValid {
                        self.finishSuccessfulExport(
                            validation: validation,
                            destination: destination,
                            temporaryURL: temporaryURL,
                            workingDirectory: workingDirectory
                        )
                    } else {
                        self.finishFailedExport(
                            "書き出し後の検証に失敗しました：\(validation.message)",
                            temporaryURL: temporaryURL,
                            workingDirectory: workingDirectory
                        )
                    }
                } else {
                    self.exportCompletedDuration += stage.expectedDuration
                    self.runExportStage(
                        at: index + 1,
                        plan: plan,
                        ffmpegURL: ffmpegURL,
                        ffprobeURL: ffprobeURL,
                        destination: destination,
                        temporaryURL: temporaryURL,
                        workingDirectory: workingDirectory
                    )
                }
            }
        }

        do {
            try process.run()
        } catch {
            exportProcess = nil
            finishFailedExport(
                "FFmpegを開始できませんでした：\(error.localizedDescription)",
                temporaryURL: temporaryURL,
                workingDirectory: workingDirectory
            )
        }
    }

    private func finishSuccessfulExport(
        validation: MediaProbe.OutputValidation,
        destination: URL,
        temporaryURL: URL,
        workingDirectory: URL
    ) {
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
            }
            try? FileManager.default.removeItem(at: workingDirectory)
            isExporting = false
            statusMessage = "\(editList.segments.count)区間の書き出しと検証が完了しました：\(destination.lastPathComponent)"
            finishOperation(.completed, detail: validation.message, outputURL: destination)
            clearExportState()
        } catch {
            finishFailedExport(
                "完成ファイルを保存できませんでした：\(error.localizedDescription)",
                temporaryURL: temporaryURL,
                workingDirectory: workingDirectory
            )
        }
    }

    private func finishFailedExport(_ message: String, temporaryURL: URL, workingDirectory: URL) {
        try? FileManager.default.removeItem(at: temporaryURL)
        try? FileManager.default.removeItem(at: workingDirectory)
        isExporting = false
        statusMessage = message
        finishOperation(.failed, detail: message)
        clearExportState()
    }

    private func finishCancelledExport(temporaryURL: URL, workingDirectory: URL) {
        try? FileManager.default.removeItem(at: temporaryURL)
        try? FileManager.default.removeItem(at: workingDirectory)
        isExporting = false
        exportWasCancelled = false
        statusMessage = "書き出しをキャンセルしました。"
        finishOperation(.cancelled, detail: statusMessage)
        clearExportState()
    }

    private func clearExportState() {
        exportProcess = nil
        exportTemporaryURL = nil
        exportDestinationURL = nil
        exportWorkingDirectory = nil
        exportCompletedDuration = 0
        operationStageDetail = nil
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

        if let previewRangeIndex,
           previewRanges.indices.contains(previewRangeIndex),
           let outPoint = previewRanges[previewRangeIndex].outPoint,
           currentSeconds >= outPoint {
            player.pause()
            let nextIndex = previewRangeIndex + 1
            if previewRanges.indices.contains(nextIndex),
               let nextInPoint = previewRanges[nextIndex].inPoint {
                self.previewRangeIndex = nextIndex
                seekWithoutCancellingPreview(to: nextInPoint)
                playbackIntent = true
                playbackState = .waiting
                player.play()
                statusMessage = "区間 \(nextIndex + 1) / \(previewRanges.count) をプレビューしています。"
            } else {
                playbackIntent = false
                playbackState = .paused
                seekWithoutCancellingPreview(to: outPoint)
                cancelPreviewSequence()
                statusMessage = "区間プレビューが終了しました。"
            }
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
        let processedSeconds = operation.kind == .export
            ? exportCompletedDuration + seconds
            : seconds
        if let expected = operationExpectedDuration, expected > 0 {
            operation.progress = min(0.99, processedSeconds / expected)
        }
        let progressText = operationExpectedDuration == nil
            ? String(format: "処理済み %.1f 秒", processedSeconds)
            : String(
                format: "%.0f%% — %.1f / %.1f 秒",
                (operation.progress ?? 0) * 100,
                processedSeconds,
                operationExpectedDuration ?? 0
            )
        operation.detail = [operationStageDetail, progressText]
            .compactMap { $0 }
            .joined(separator: " — ")
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
