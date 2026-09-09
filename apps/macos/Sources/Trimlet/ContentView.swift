import AppKit
import SwiftUI
import TrimletCore
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var controller = PlayerController()
    @State private var isDropTargeted = false
    @State private var didHandleLaunchArgument = false
    @State private var showsExportOptions = false
    @FocusState private var isClipNameFocused: Bool

    private var acceptsEditingShortcuts: Bool {
        !isClipNameFocused && !controller.isLoading && !controller.isExporting && controller.activeOperation == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        playerArea
                            .frame(minHeight: 220, maxHeight: .infinity)
                            .overlay(alignment: .topLeading) {
                                Text(controller.playbackContextLabel)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(.white)
                                    .background(.black.opacity(0.65), in: Capsule())
                                    .padding(12)
                            }
                        VStack(spacing: 10) {
                            playbackButtons
                            timeline
                        }
                        .padding(12)
                    }
                    .frame(minWidth: 640, maxWidth: .infinity)
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            rangeControls
                            Divider()
                            clipInspector
                        }
                        .padding(14)
                    }
                    .frame(width: 292)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
                .frame(minHeight: 420, maxHeight: .infinity)

                Divider()
                editListControls
                    .frame(height: 205, alignment: .top)
            }
            .frame(maxHeight: .infinity)
            Divider()
            statusBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background {
            WindowCloseGuard {
                confirmClosingWindow()
            }
        }
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
            guard acceptsEditingShortcuts else { return .ignored }
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
            guard acceptsEditingShortcuts else { return .ignored }
            controller.togglePlayback()
            return .handled
        }
        .onKeyPress("i") {
            guard acceptsEditingShortcuts else { return .ignored }
            controller.setInPoint()
            return .handled
        }
        .onKeyPress("o") {
            guard acceptsEditingShortcuts else { return .ignored }
            controller.setOutPoint()
            return .handled
        }
        .onKeyPress("j") {
            guard acceptsEditingShortcuts else { return .ignored }
            controller.adjustShuttle(by: -1)
            return .handled
        }
        .onKeyPress("k") {
            guard acceptsEditingShortcuts else { return .ignored }
            controller.stopShuttle()
            return .handled
        }
        .onKeyPress("l") {
            guard acceptsEditingShortcuts else { return .ignored }
            controller.adjustShuttle(by: 1)
            return .handled
        }
        .onAppear {
            let appDelegate = NSApp.delegate as? TrimletAppDelegate
            appDelegate?.confirmTermination = {
                confirmClosingWindow()
            }
            appDelegate?.fileOpenHandler = { url in
                openExternalURL(url)
            }
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
                if controller.hasMedia {
                    Text(controller.projectDisplayName + (controller.isProjectDirty ? " • 未保存" : ""))
                        .font(.caption2)
                        .foregroundStyle(controller.isProjectDirty ? Color.orange : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button("保存", systemImage: "square.and.arrow.down") {
                _ = saveCurrentProject()
            }
            .disabled(!controller.canSaveProject || !controller.isProjectDirty)
            .help("編集内容をプロジェクトに保存（⌘S）")

            Menu("プロジェクト", systemImage: "doc") {
                Button("プロジェクトを開く…", systemImage: "folder") {
                    presentProjectOpenPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(!controller.canOpenMedia)

                Divider()

                Button("保存", systemImage: "square.and.arrow.down") {
                    _ = saveCurrentProject()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!controller.canSaveProject || !controller.isProjectDirty)

                Button("別名で保存…", systemImage: "doc.on.doc") {
                    _ = presentProjectSavePanel()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!controller.canSaveProject)
            }

            Button("動画を開く…", systemImage: "folder") {
                presentOpenPanel()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(!controller.canOpenMedia)

            Button("書き出し", systemImage: "square.and.arrow.up") {
                showsExportOptions = true
            }
            .buttonStyle(.borderedProminent)
            .popover(isPresented: $showsExportOptions, arrowEdge: .bottom) {
                exportOptions
            }
            .disabled(controller.isExporting || controller.isLoading)
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

    private var statusBar: some View {
            HStack(spacing: 8) {
                if controller.isLoading || controller.isExporting {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(controller.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(controller.statusMessage)
                Spacer()
                Link(destination: URL(string: "https://buymeacoffee.com/jydie5")!) {
                    Label("開発を応援", systemImage: "cup.and.saucer")
                }
                .font(.caption)
                .help("任意のカンパです。機能解放や利用条件の変更はありません。")
                Text("0.4 · Timeline Preview")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private var playbackButtons: some View {
        TransportControls(controller: controller)
    }

    private var timeline: some View {
        SourceTimeline(controller: controller)
    }

    private func shortTime(_ seconds: Double) -> String {
        String(format: "%.3fs", seconds)
    }

    private func clipLabel(_ segment: EditSegment) -> String {
        let name = segment.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "名称未設定" : name
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

            VStack(alignment: .leading, spacing: 10) {
                rangeStep(
                    number: 1,
                    title: "IN点",
                    value: controller.trimRange.inPoint,
                    tint: .green,
                    actionTitle: "INを設定",
                    shortcutKey: "I",
                    action: { controller.setInPoint() },
                    jump: controller.trimRange.inPoint == nil ? nil : { controller.goToInPoint() }
                )

                rangeStep(
                    number: 2,
                    title: "OUT点",
                    value: controller.trimRange.outPoint,
                    tint: .red,
                    actionTitle: "OUTを設定",
                    shortcutKey: "O",
                    action: { controller.setOutPoint() },
                    jump: controller.trimRange.outPoint == nil ? nil : { controller.goToOutPoint() },
                    isActionDisabled: controller.trimRange.inPoint == nil
                )

                if let inPoint = controller.trimRange.inPoint, controller.currentSeconds <= inPoint {
                    Text("上のタイムラインで再生位置をINより後へ動かして、OUTを設定してください。再生する必要はありません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if controller.trimRange.inPoint != nil, controller.trimRange.outPoint == nil {
                    Text("終了位置へ移動して、Oキーまたは「OUTを設定」を押してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                rangeCommitStep
            }
        }
        .disabled(!controller.hasMedia || controller.isExporting)
    }

    private var rangeControlHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(controller.trimmingSegmentID == nil ? "新規サブクリップ" : "クリップをトリム")
                    .font(.headline)
                Text(controller.trimmingSegmentID == nil
                     ? "IN → OUT → シーケンスへ追加"
                     : "適用するまで元の範囲は変わりません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if controller.trimmingSegmentID != nil {
                Button("取消") {
                    controller.cancelTrimming()
                }
            }
        }
    }

    private var rangeCommitStep: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label {
                Text(controller.trimmingSegmentID == nil ? "シーケンスへ追加" : "トリムを確定")
                    .font(.caption.weight(.semibold))
            } icon: {
                Text("3")
                    .font(.caption2.bold())
                    .frame(width: 20, height: 20)
                    .background(Color.accentColor, in: Circle())
                    .foregroundStyle(.white)
            }

            Text(controller.trimRange.isValid ? controller.selectedDurationText : "IN点とOUT点を設定")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(controller.trimRange.isValid ? Color.primary : Color.secondary)

            HStack {
                Button(controller.trimmingSegmentID == nil ? "シーケンスへ追加" : "トリムを適用",
                       systemImage: controller.trimmingSegmentID == nil ? "plus" : "checkmark") {
                    if controller.trimmingSegmentID == nil {
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
        shortcutKey: String,
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
                Button(action: action) {
                    HStack(spacing: 6) {
                        Text(actionTitle)
                        ShortcutKey(shortcutKey)
                    }
                }
                    .disabled(isActionDisabled)
                    .help("\(actionTitle)（\(shortcutKey)キー）")
                if let jump {
                    Button("ここへ移動", action: jump)
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
    }

    private var editListControls: some View {
        SequenceStrip(controller: controller)
    }

    private var clipInspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("クリップ詳細", systemImage: "slider.horizontal.3")
                .font(.headline)
            if let segment = controller.selectedSegment {
                TextField("クリップ名", text: $controller.clipNameDraft)
                    .textFieldStyle(.roundedBorder)
                    .focused($isClipNameFocused)
                    .onSubmit { commitClipName() }
                HStack {
                    Button("名前を適用") { commitClipName() }
                    Button("元に戻す") {
                        controller.clipNameDraft = segment.name ?? ""
                        isClipNameFocused = false
                    }
                }
                .disabled(controller.clipNameDraft == (segment.name ?? ""))
                LabeledContent("IN", value: pointTime(segment.inPoint.seconds))
                LabeledContent("OUT", value: pointTime(segment.outPoint.seconds))
                HStack {
                    Button("クリップを再生", systemImage: "play.rectangle") {
                        controller.previewSelectedSegment()
                    }
                    Button("トリム編集") { controller.beginTrimmingSelectedSegment() }
                        .disabled(controller.trimmingSegmentID != nil)
                }
                Text("並べ替え・削除は、下のシーケンスの矢印・ごみ箱から操作できます。")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("下のクリップを選択すると、名前や範囲を確認・編集できます。")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.callout)
        .disabled(controller.isExporting)
    }

    private func commitClipName() {
        controller.applySelectedClipName()
        isClipNameFocused = false
    }

    private var exportOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("MP4を書き出す", systemImage: "square.and.arrow.up")
                .font(.title3.weight(.semibold))
            Text("\(controller.editList.segments.count)クリップ · 合計 \(controller.totalDurationText)")
                .foregroundStyle(.secondary).monospacedDigit()
            Picker("書き出し方式", selection: $controller.exportMode) {
                ForEach(ExportMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text(controller.exportMode.explanation)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            if controller.usesCompatibilityPreview {
                Label("互換プレビューを使用中です。標準プレーヤーで再生したい場合は「フレーム正確」を選択してください。高速モードは原本の映像コーデックを保持します。", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if controller.audioStreams.count > 1 {
                Picker("音声", selection: $controller.selectedAudioStreamIndex) {
                    ForEach(controller.audioStreams) { stream in
                        Text(stream.displayName).tag(Optional(stream.index))
                    }
                }
            }
            if let reason = controller.exportUnavailableReason {
                Label(reason, systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("保存先を選んで書き出す…", systemImage: "square.and.arrow.up") {
                showsExportOptions = false
                presentSavePanel()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!controller.canExport)
            Text("編集を再開するには、別途プロジェクトを保存してください。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(width: 360)
        .disabled(controller.isExporting)
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = supportedTypes
        panel.message = "Trimletで確認する動画を選んでください"

        if panel.runModal() == .OK, let url = panel.url,
           confirmReplacingCurrentProject() {
            controller.open(url)
        }
    }

    private func presentProjectOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.trimletProject]
        panel.message = "開くTrimletプロジェクトを選んでください"

        if panel.runModal() == .OK, let url = panel.url {
            openProjectDocument(at: url)
        }
    }

    @discardableResult
    private func saveCurrentProject() -> Bool {
        if let projectURL = controller.projectURL {
            do {
                try controller.saveProject(to: projectURL)
                return true
            } catch {
                presentError(title: "プロジェクトを保存できませんでした", error: error)
                return false
            }
        }
        return presentProjectSavePanel()
    }

    @discardableResult
    private func presentProjectSavePanel() -> Bool {
        guard let sourceURL = controller.currentURL else { return false }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.trimletProject]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + ".trimlet"
        panel.message = "元動画を移動する場合は、プロジェクトと一緒に移動すると再リンクしやすくなります"

        guard panel.runModal() == .OK, let destination = panel.url else { return false }
        guard destination.standardizedFileURL != sourceURL.standardizedFileURL else {
            presentError(title: "元動画へは保存できません", error: PlayerProjectSaveError.sourceConflict)
            return false
        }
        do {
            try controller.saveProject(to: destination)
            return true
        } catch {
            presentError(title: "プロジェクトを保存できませんでした", error: error)
            return false
        }
    }

    private func openProjectDocument(at projectURL: URL) {
        do {
            let project = try TrimletProjectCodec.read(from: projectURL)
            let candidateURL = project.source.candidateURL(relativeTo: projectURL)
            if project.source.matches(candidateURL) {
                openResolvedProject(
                    project,
                    projectURL: projectURL,
                    sourceURL: candidateURL,
                    sourceReferenceChanged: false
                )
            } else if FileManager.default.fileExists(atPath: candidateURL.path) {
                let alert = NSAlert()
                alert.messageText = "元動画が保存時から変更されています"
                alert.informativeText = "\(candidateURL.lastPathComponent) のサイズまたは更新日時が一致しません。この動画を使うか、別の元動画を選んでください。"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "この動画を使用")
                alert.addButton(withTitle: "再リンク…")
                alert.addButton(withTitle: "キャンセル")
                switch alert.runModal() {
                case .alertFirstButtonReturn:
                    openResolvedProject(
                        project,
                        projectURL: projectURL,
                        sourceURL: candidateURL,
                        sourceReferenceChanged: true
                    )
                case .alertSecondButtonReturn:
                    presentRelinkPanel(for: project, projectURL: projectURL)
                default:
                    break
                }
            } else {
                presentRelinkPanel(for: project, projectURL: projectURL)
            }
        } catch {
            presentError(title: "プロジェクトを開けませんでした", error: error)
        }
    }

    private func presentRelinkPanel(for project: TrimletProject, projectURL: URL) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = supportedTypes
        panel.message = "元動画「\(project.source.fileName)」を選び直してください"
        panel.prompt = "再リンク"
        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        if !project.source.matches(sourceURL) {
            let alert = NSAlert()
            alert.messageText = "記録された元動画と一致しません"
            alert.informativeText = "範囲や音声トラックが正しく復元されない可能性があります。選択した動画を使用しますか？"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "この動画を使用")
            alert.addButton(withTitle: "キャンセル")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        openResolvedProject(
            project,
            projectURL: projectURL,
            sourceURL: sourceURL,
            sourceReferenceChanged: true
        )
    }

    private func openResolvedProject(
        _ project: TrimletProject,
        projectURL: URL,
        sourceURL: URL,
        sourceReferenceChanged: Bool
    ) {
        guard confirmReplacingCurrentProject() else { return }
        controller.openProject(
            project,
            projectURL: projectURL,
            sourceURL: sourceURL,
            sourceIdentityChanged: sourceReferenceChanged
        )
    }

    private func confirmReplacingCurrentProject() -> Bool {
        confirmUnsavedChanges(markDiscarded: false)
    }

    private func confirmClosingWindow() -> Bool {
        confirmUnsavedChanges(markDiscarded: true)
    }

    private func confirmUnsavedChanges(markDiscarded: Bool) -> Bool {
        guard controller.isProjectDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "変更を保存しますか？"
        alert.informativeText = "保存していない編集内容があります。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "保存しない")
        alert.addButton(withTitle: "キャンセル")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveCurrentProject()
        case .alertSecondButtonReturn:
            if markDiscarded {
                controller.acknowledgeDiscardingProjectChanges()
            }
            return true
        default:
            return false
        }
    }

    private func presentError(title: String, error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = title
        alert.runModal()
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
                    openExternalURL(url)
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
        let url = URL(fileURLWithPath: path)
        openExternalURL(url)
    }

    private func openExternalURL(_ url: URL) {
        if url.pathExtension.lowercased() == "trimlet" {
            openProjectDocument(at: url)
        } else if confirmReplacingCurrentProject() {
            controller.open(url)
        }
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

private enum PlayerProjectSaveError: LocalizedError {
    case sourceConflict

    var errorDescription: String? {
        "プロジェクトには元動画と異なる名前または保存先を選んでください。"
    }
}


private extension UTType {
    static let trimletProject = UTType(exportedAs: "dev.trimlet.project", conformingTo: .json)
}

private struct ShortcutKey: View {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.35), lineWidth: 0.75)
            }
            .accessibilityHidden(true)
    }
}
