import AppKit
import SwiftUI
import TrimletCore
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var controller = PlayerController()
    @State private var isDropTargeted = false
    @State private var didHandleLaunchArgument = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            playerArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            controls
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            if let operation = controller.activeOperation {
                OperationPanel(operation: operation, controller: controller)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .focusable()
        .onKeyPress(phases: .down) { press in
            guard press.key == .leftArrow || press.key == .rightArrow else { return .ignored }
            let direction = press.key == .leftArrow ? -1 : 1
            if press.modifiers.contains(.option) {
                controller.jump(by: Double(direction) * 5)
            } else if press.modifiers.contains(.shift) {
                controller.step(by: direction * 10)
            } else {
                controller.step(by: direction)
            }
            return .handled
        }
        .onKeyPress(.space) {
            controller.togglePlayback()
            return .handled
        }
        .onKeyPress("i") {
            controller.setInPoint()
            return .handled
        }
        .onKeyPress("o") {
            controller.setOutPoint()
            return .handled
        }
        .onAppear {
            openLaunchArgumentIfPresent()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "scissors")
                .font(.title2)
                .foregroundStyle(.tint)

            Text("Trimlet")
                .font(.headline)

            Spacer()

            Button("動画を開く…", systemImage: "folder") {
                presentOpenPanel()
            }
            .keyboardShortcut("o", modifiers: .command)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var playerArea: some View {
        ZStack {
            Color.black

            if controller.hasMedia {
                PlayerView(player: controller.player)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "film.stack")
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                    Text(isDropTargeted ? "ここにドロップ" : "動画をここにドロップ")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white)
                    Text("MP4 / MOV / M2TS / MTS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if controller.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, dash: [10]))
                    .padding(10)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            playbackButtons
            timeline
            rangeControls
            editListControls
            exportControls

            HStack(spacing: 8) {
                if controller.isLoading || controller.isExporting {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(controller.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Link(destination: URL(string: "https://buymeacoffee.com/jydie5")!) {
                    Label("開発を応援", systemImage: "cup.and.saucer")
                }
                .font(.caption)
                .help("任意のカンパです。機能解放や利用条件の変更はありません。")
                Text("0.3 開発版")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(18)
    }

    private var playbackButtons: some View {
        HStack(spacing: 8) {
            Button("5秒戻る", systemImage: "gobackward.5") {
                controller.jump(by: -5)
            }
            .labelStyle(.iconOnly)
            .help("5秒戻る")

            Button("1フレーム戻る", systemImage: "backward.frame") {
                controller.step(by: -1)
            }
            .help("1フレーム戻る（←）")

            Button("10フレーム戻る") {
                controller.step(by: -10)
            }
            .help("10フレーム戻る（Shift＋←）")

            Button(controller.isPlaybackActive ? "一時停止" : "再生", systemImage: controller.isPlaybackActive ? "pause.fill" : "play.fill") {
                controller.togglePlayback()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .help("再生／一時停止（Space）")

            Button("1フレーム進む", systemImage: "forward.frame") {
                controller.step(by: 1)
            }
            .help("1フレーム進む（→）")

            Button("10フレーム進む") {
                controller.step(by: 10)
            }
            .help("10フレーム進む（Shift＋→）")

            Button("5秒進む", systemImage: "goforward.5") {
                controller.jump(by: 5)
            }
            .labelStyle(.iconOnly)
            .help("5秒進む")

            if controller.playbackState == .waiting {
                ProgressView()
                    .controlSize(.small)
                    .help("再生準備中")
            }

            Spacer()

            Text(controller.currentTimecode)
                .font(.system(.body, design: .monospaced).weight(.medium))
            Text("/")
                .foregroundStyle(.tertiary)
            Text(controller.durationTimecode)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .disabled(!controller.hasMedia || controller.isExporting)
    }

    private var timeline: some View {
        VStack(spacing: 6) {
            HStack {
                Label("元動画の時間軸", systemImage: "film")
                    .font(.caption.weight(.semibold))
                Text("青＝出力する区間　緑／赤＝作成中の開始／終了")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            RangeBar(
                duration: controller.durationSeconds,
                current: controller.currentSeconds,
                draftInPoint: controller.trimRange.inPoint,
                draftOutPoint: controller.trimRange.outPoint,
                segments: controller.editList.segments,
                selectedSegmentID: controller.selectedSegmentID,
                keyframes: controller.keyframeIndex?.keyframes ?? [],
                fastCandidates: controller.exportMode == .fast ? controller.fastCandidates : [:]
            )
            .frame(height: 28)

            Slider(
                value: Binding(
                    get: { controller.currentSeconds },
                    set: { controller.seek(to: $0) }
                ),
                in: 0...max(controller.durationSeconds, 0.01)
            )
            .disabled(!controller.hasMedia)

            HStack(spacing: 12) {
                if let index = controller.keyframeIndex {
                    Label("キーフレーム \(index.keyframes.count)個", systemImage: "line.3.horizontal.decrease")
                    if controller.exportMode == .fast, let candidate = controller.fastCandidate {
                        Text("作成中の高速候補 \(shortTime(candidate.start))–\(shortTime(candidate.end))")
                            .foregroundStyle(.orange)
                    } else if controller.exportMode == .fast {
                        Text("この範囲は正確モードを推奨")
                            .foregroundStyle(.orange)
                    }
                } else if controller.hasMedia {
                    Text("キーフレームを解析しています…")
                }
                Spacer()
                Text("←/→ 1f　Shift 10f　Option 5秒")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func shortTime(_ seconds: Double) -> String {
        String(format: "%.3fs", seconds)
    }

    private func pointTime(_ seconds: Double?) -> String {
        guard let seconds else { return "未設定" }
        return TimecodeFormatter.string(
            seconds: seconds,
            framesPerSecond: controller.nominalFrameRate
        )
    }

    private var rangeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            rangeControlHeader

            HStack(alignment: .top, spacing: 8) {
                rangeStep(
                    number: 1,
                    title: "開始点",
                    value: controller.trimRange.inPoint,
                    tint: .green,
                    actionTitle: "現在位置を開始に",
                    action: { controller.setInPoint() },
                    jump: controller.trimRange.inPoint == nil ? nil : { controller.goToInPoint() }
                )

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)

                rangeStep(
                    number: 2,
                    title: "終了点",
                    value: controller.trimRange.outPoint,
                    tint: .red,
                    actionTitle: "現在位置を終了に",
                    action: { controller.setOutPoint() },
                    jump: controller.trimRange.outPoint == nil ? nil : { controller.goToOutPoint() },
                    isActionDisabled: controller.trimRange.inPoint == nil
                )

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)

                rangeCommitStep
            }
        }
        .padding(10)
        .disabled(!controller.hasMedia || controller.isExporting)
    }

    private var rangeControlHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(controller.selectedSegmentID == nil ? "新しい区間を作る" : "選択した区間を編集")
                    .font(.headline)
                Text(controller.selectedSegmentID == nil
                     ? "再生位置を動かし、① → ② → ③の順に操作します"
                     : "開始／終了を変更し、③変更を保存します")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if controller.selectedSegmentID != nil {
                Button("新しい区間に戻る", systemImage: "plus") {
                    controller.startNewSegment()
                }
            }
        }
    }

    private var rangeCommitStep: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label {
                Text(controller.selectedSegmentID == nil ? "出力へ追加" : "変更を確定")
                    .font(.caption.weight(.semibold))
            } icon: {
                Text("3")
                    .font(.caption2.bold())
                    .frame(width: 20, height: 20)
                    .background(Color.accentColor, in: Circle())
                    .foregroundStyle(.white)
            }

            Text(controller.trimRange.isValid ? controller.selectedDurationText : "開始と終了を設定")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(controller.trimRange.isValid ? Color.primary : Color.secondary)

            HStack {
                Button(controller.selectedSegmentID == nil ? "この範囲を残す" : "変更を保存",
                       systemImage: controller.selectedSegmentID == nil ? "plus" : "checkmark") {
                    if controller.selectedSegmentID == nil {
                        controller.addDraftSegment()
                    } else {
                        controller.updateSelectedSegment()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!controller.trimRange.isValid)

                Button("確認", systemImage: "play.fill") {
                    controller.previewSelection()
                }
                .labelStyle(.iconOnly)
                .disabled(!controller.trimRange.isValid)
                .help("この範囲だけ再生")
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
    }

    private func rangeStep(
        number: Int,
        title: String,
        value: Double?,
        tint: Color,
        actionTitle: String,
        action: @escaping () -> Void,
        jump: (() -> Void)?,
        isActionDisabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("\(number)")
                    .font(.caption2.bold())
                    .frame(width: 20, height: 20)
                    .background(tint, in: Circle())
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(pointTime(value))
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(value == nil ? Color.secondary : Color.primary)
            }

            HStack {
                Button(actionTitle, action: action)
                    .disabled(isActionDisabled)
                if let jump {
                    Button("移動", action: jump)
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
    }

    private var editListControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label("出力される区間", systemImage: "list.number")
                    .font(.caption.weight(.semibold))
                Text(controller.editList.isEmpty
                     ? "まだありません"
                     : "左から順に \(controller.editList.segments.count)区間 · 合計 \(controller.totalDurationText)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("出力順に再生", systemImage: "play.fill") {
                    controller.previewAllSegments()
                }
                .disabled(controller.editList.isEmpty)
                Button("取り消す", systemImage: "arrow.uturn.backward") {
                    controller.undoEdit()
                }
                .labelStyle(.iconOnly)
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!controller.canUndoEdit)
                .help("区間編集を取り消す（⌘Z）")
                Button("やり直す", systemImage: "arrow.uturn.forward") {
                    controller.redoEdit()
                }
                .labelStyle(.iconOnly)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!controller.canRedoEdit)
                .help("区間編集をやり直す（⇧⌘Z）")
            }

            if controller.editList.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up")
                    Text("上の①開始点 → ②終了点 → ③この範囲を残す、で追加されます")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(Array(controller.editList.segments.enumerated()), id: \.element.id) { index, segment in
                            Button {
                                controller.selectSegment(segment.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("区間 \(index + 1)")
                                        .font(.caption2.weight(.bold))
                                    Text("\(shortTime(segment.inPoint.seconds))–\(shortTime(segment.outPoint.seconds))")
                                        .font(.system(.caption2, design: .monospaced))
                                    Text(TimecodeFormatter.string(seconds: segment.durationSeconds, framesPerSecond: controller.nominalFrameRate))
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    if controller.exportMode == .fast {
                                        if let candidate = controller.fastCandidates[segment.id] ?? nil {
                                            Text("高速 \(shortTime(candidate.start))–\(shortTime(candidate.end))")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundStyle(.orange)
                                        } else {
                                            Text("高速不可")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    controller.selectedSegmentID == segment.id
                                        ? Color.accentColor.opacity(0.22)
                                        : Color.secondary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 7)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)

                HStack(spacing: 8) {
                    Text(controller.selectedSegmentID == nil ? "区間をクリックすると編集できます" : "選択中の区間を操作")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button("この区間を再生", systemImage: "play.rectangle") {
                        controller.previewSelectedSegment()
                    }
                    Button("前へ移動", systemImage: "arrow.left") {
                        controller.moveSelectedSegment(by: -1)
                    }
                    Button("後へ移動", systemImage: "arrow.right") {
                        controller.moveSelectedSegment(by: 1)
                    }
                    Button("削除", systemImage: "trash", role: .destructive) {
                        controller.removeSelectedSegment()
                    }
                    Spacer()
                }
                .disabled(controller.selectedSegmentID == nil)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        .disabled(controller.isExporting)
    }

    private var exportControls: some View {
        HStack(alignment: .center, spacing: 12) {
            if controller.audioStreams.count > 1 {
                Picker("音声", selection: $controller.selectedAudioStreamIndex) {
                    ForEach(controller.audioStreams) { stream in
                        Text(stream.displayName).tag(Optional(stream.index))
                    }
                }
                .frame(maxWidth: 250)
                .help("書き出しに使用する音声トラック")
            }

            Picker("書き出し", selection: $controller.exportMode) {
                ForEach(ExportMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)

            Text(controller.exportMode.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()

            if controller.isExporting {
                Button("キャンセル", role: .cancel) {
                    controller.cancelExport()
                }
            } else {
                Button("MP4を書き出す…", systemImage: "square.and.arrow.up") {
                    presentSavePanel()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!controller.canExport)
            }
        }
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = supportedTypes
        panel.message = "Trimletで確認する動画を選んでください"

        if panel.runModal() == .OK, let url = panel.url {
            controller.open(url)
        }
    }

    private func presentSavePanel() {
        guard let sourceURL = controller.currentURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "-trimmed.mp4"
        panel.message = "元ファイルとは別の名前で保存してください"

        if panel.runModal() == .OK, let destination = panel.url {
            guard destination.standardizedFileURL != sourceURL.standardizedFileURL else {
                NSSound.beep()
                return
            }
            controller.export(to: destination)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let candidate = item as? URL {
                url = candidate
            } else {
                url = nil
            }

            if let url {
                Task { @MainActor in
                    controller.open(url)
                }
            }
        }
        return true
    }

    private func openLaunchArgumentIfPresent() {
        guard !didHandleLaunchArgument else { return }
        didHandleLaunchArgument = true

        guard let path = CommandLine.arguments.dropFirst().first,
              FileManager.default.fileExists(atPath: path) else {
            return
        }
        controller.open(URL(fileURLWithPath: path))
    }

    private var supportedTypes: [UTType] {
        var types: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie]
        for extensionName in ["m2ts", "mts"] {
            if let type = UTType(filenameExtension: extensionName) {
                types.append(type)
            }
        }
        return types
    }
}

private struct RangeBar: View {
    let duration: Double
    let current: Double
    let draftInPoint: Double?
    let draftOutPoint: Double?
    let segments: [EditSegment]
    let selectedSegmentID: UUID?
    let keyframes: [Double]
    let fastCandidates: [UUID: FastCutCandidate?]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let safeDuration = max(duration, 0.01)
            let playhead = min(max(current / safeDuration, 0), 1)
            let markStride = max(1, keyframes.count / max(1, Int(width / 5)))
            let visibleKeyframes = Array(keyframes.enumerated()).filter { $0.offset % markStride == 0 }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                ForEach(segments) { segment in
                    let start = min(max(segment.inPoint.seconds / safeDuration, 0), 1)
                    let end = min(max(segment.outPoint.seconds / safeDuration, 0), 1)
                    if let candidate = fastCandidates[segment.id] ?? nil {
                        let candidateStart = min(max(candidate.start / safeDuration, 0), 1)
                        let candidateEnd = min(max(candidate.end / safeDuration, 0), 1)
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: width * (candidateEnd - candidateStart), height: 24)
                            .offset(x: width * candidateStart)
                    }
                    if end > start {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                segment.id == selectedSegmentID
                                    ? Color.accentColor.opacity(0.85)
                                    : Color.accentColor.opacity(0.48)
                            )
                            .frame(width: width * (end - start), height: 18)
                            .offset(x: width * start)
                    }
                }

                if let draftInPoint, let draftOutPoint, draftOutPoint > draftInPoint {
                    let draftStart = min(max(draftInPoint / safeDuration, 0), 1)
                    let draftEnd = min(max(draftOutPoint / safeDuration, 0), 1)
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: width * (draftEnd - draftStart), height: 26)
                        .offset(x: width * draftStart)
                }

                if let draftInPoint {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 2, height: 26)
                        .offset(x: width * min(max(draftInPoint / safeDuration, 0), 1))
                }

                if let draftOutPoint {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: 26)
                        .offset(x: width * min(max(draftOutPoint / safeDuration, 0), 1))
                }

                Rectangle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1)
                    .frame(width: 2)
                    .offset(x: max(0, width * playhead - 1))

                ForEach(visibleKeyframes, id: \.offset) { _, time in
                    Rectangle()
                        .fill(Color.orange.opacity(0.8))
                        .frame(width: 1, height: 7)
                        .offset(x: width * min(max(time / safeDuration, 0), 1))
                }
            }
        }
    }
}

private struct OperationPanel: View {
    let operation: OperationStatus
    @ObservedObject var controller: PlayerController

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(.system(size: 30))
                    .foregroundStyle(iconColor)

                Text(operation.title)
                    .font(.headline)

                if operation.result == .running {
                    if let progress = operation.progress {
                        ProgressView(value: progress)
                            .frame(width: 280)
                        Text("\(Int(progress * 100))%")
                            .font(.system(.caption, design: .monospaced))
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text(operation.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                HStack {
                    if operation.canCancel {
                        Button("キャンセル", role: .cancel) {
                            controller.cancelActiveOperation()
                        }
                    } else {
                        if operation.outputURL != nil {
                            Button("Finderで表示") {
                                controller.revealCompletedOutput()
                            }
                        }
                        Button("閉じる") {
                            controller.dismissOperation()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(24)
            .frame(minWidth: 400)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 20)
        }
    }

    private var iconName: String {
        switch operation.result {
        case .running: "gearshape.2"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch operation.result {
        case .running: .accentColor
        case .completed: .green
        case .failed: .red
        case .cancelled: .secondary
        }
    }
}
