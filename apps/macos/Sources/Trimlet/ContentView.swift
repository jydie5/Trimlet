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

            VStack(alignment: .leading, spacing: 1) {
                Text("Trimlet")
                    .font(.headline)
                Text("必要なところだけ、すばやく正確に。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
                Text("PoC")
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
        .disabled(!controller.hasMedia)
    }

    private var timeline: some View {
        VStack(spacing: 6) {
            RangeBar(
                duration: controller.durationSeconds,
                current: controller.currentSeconds,
                inPoint: controller.trimRange.inPoint,
                outPoint: controller.trimRange.outPoint,
                keyframes: controller.keyframeIndex?.keyframes ?? [],
                fastCandidate: controller.exportMode == .fast ? controller.fastCandidate : nil
            )
            .frame(height: 20)

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
                        Text("高速候補 \(shortTime(candidate.start))–\(shortTime(candidate.end))")
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

    private var rangeControls: some View {
        HStack(spacing: 10) {
            Button("INを設定", systemImage: "inset.filled.leadinghalf.rectangle") {
                controller.setInPoint()
            }
            .help("現在位置をIN点に設定（I）")

            Button("INへ") {
                controller.goToInPoint()
            }

            Spacer()

            VStack(spacing: 2) {
                Text("選択範囲")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(controller.selectedDurationText)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(controller.trimRange.isValid ? Color.primary : Color.red)
            }

            Button("選択範囲を再生", systemImage: "play.rectangle") {
                controller.previewSelection()
            }
            .disabled(!controller.trimRange.isValid)

            Spacer()

            Button("OUTへ") {
                controller.goToOutPoint()
            }

            Button("OUTを設定", systemImage: "inset.filled.trailinghalf.rectangle") {
                controller.setOutPoint()
            }
            .help("現在位置をOUT点に設定（O）")
        }
        .disabled(!controller.hasMedia)
    }

    private var exportControls: some View {
        HStack(alignment: .center, spacing: 12) {
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
    let inPoint: Double?
    let outPoint: Double?
    let keyframes: [Double]
    let fastCandidate: FastCutCandidate?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let safeDuration = max(duration, 0.01)
            let start = min(max((inPoint ?? 0) / safeDuration, 0), 1)
            let end = min(max((outPoint ?? duration) / safeDuration, 0), 1)
            let playhead = min(max(current / safeDuration, 0), 1)
            let candidateStart = min(max((fastCandidate?.start ?? 0) / safeDuration, 0), 1)
            let candidateEnd = min(max((fastCandidate?.end ?? 0) / safeDuration, 0), 1)
            let markStride = max(1, keyframes.count / max(1, Int(width / 5)))
            let visibleKeyframes = Array(keyframes.enumerated()).filter { $0.offset % markStride == 0 }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                if fastCandidate != nil, candidateEnd > candidateStart {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.orange, lineWidth: 2)
                        .frame(width: width * (candidateEnd - candidateStart), height: 18)
                        .offset(x: width * candidateStart)
                }

                if end > start {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.55))
                        .frame(width: width * (end - start))
                        .offset(x: width * start)
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
