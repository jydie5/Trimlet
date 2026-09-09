import SwiftUI
import TrimletCore

struct SequenceStrip: View {
    @ObservedObject var controller: PlayerController
    @State private var dropTargetSegmentID: UUID?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label("編集シーケンス", systemImage: "list.number")
                    .font(.caption.weight(.semibold))
                Text(controller.editList.isEmpty
                     ? "まだありません"
                     : "左から順に \(controller.editList.segments.count)クリップ · 合計 \(controller.totalDurationText)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                if let selected = controller.selectedSegment {
                    Button { controller.moveSelectedSegment(by: -1) } label: { Image(systemName: "arrow.left") }
                        .help("選択クリップを前へ移動")
                        .accessibilityLabel("選択クリップを前へ")
                        .disabled(controller.editList.segments.first?.id == selected.id)
                    Button { controller.moveSelectedSegment(by: 1) } label: { Image(systemName: "arrow.right") }
                        .help("選択クリップを後へ移動")
                        .accessibilityLabel("選択クリップを後へ")
                        .disabled(controller.editList.segments.last?.id == selected.id)
                    Button(role: .destructive) { controller.removeSelectedSegment() } label: { Image(systemName: "trash") }
                        .help("選択クリップをシーケンスから削除。元動画は変更しません")
                        .accessibilityLabel("選択クリップを削除")
                    Divider().frame(height: 16)
                }
                Button("シーケンスを再生", systemImage: "play.fill") {
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
                    Text("右のIN → OUTで範囲を決め、シーケンスへ追加します")
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
                                VStack(alignment: .leading, spacing: 4) {
                                    ZStack(alignment: .topTrailing) {
                                        if let thumbnail = controller.clipThumbnails[segment.id] {
                                            Image(nsImage: thumbnail)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            Rectangle()
                                                .fill(Color.black.opacity(0.72))
                                                .overlay {
                                                    Image(systemName: "photo")
                                                        .foregroundStyle(.secondary)
                                                }
                                        }
                                        Image(systemName: "line.3.horizontal")
                                            .font(.caption2.weight(.semibold))
                                            .padding(5)
                                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                                            .padding(4)
                                    }
                                    .frame(width: 156, height: 82)
                                    .clipped()

                                    Text(clipLabel(segment))
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text("\(shortTime(segment.inPoint.seconds))–\(shortTime(segment.outPoint.seconds))")
                                        .font(.system(.caption2, design: .monospaced))
                                    if controller.exportMode == .fast {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bolt.fill")
                                                .font(.caption2)
                                            if let candidate = controller.fastCandidates[segment.id] ?? nil {
                                                Text("\(shortTime(candidate.start))–\(shortTime(candidate.end))")
                                            } else {
                                                Text("高速不可")
                                            }
                                        }
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.orange)
                                    }
                                }
                                .padding(6)
                                .background(
                                    dropTargetSegmentID == segment.id
                                        ? Color.accentColor.opacity(0.38)
                                        : controller.selectedSegmentID == segment.id
                                            ? Color.accentColor.opacity(0.22)
                                            : Color.secondary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 7)
                                )
                            }
                            .buttonStyle(.plain)
                            .draggable(segment.id.uuidString) {
                                Label(clipLabel(segment), systemImage: "line.3.horizontal")
                                    .padding(8)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                            }
                            .dropDestination(for: String.self) { items, _ in
                                guard let rawID = items.first,
                                      let sourceID = UUID(uuidString: rawID),
                                      sourceID != segment.id else {
                                    return false
                                }
                                return controller.moveSegment(sourceID, to: index)
                            } isTargeted: { isTargeted in
                                if isTargeted {
                                    dropTargetSegmentID = segment.id
                                } else if dropTargetSegmentID == segment.id {
                                    dropTargetSegmentID = nil
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.automatic)

            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        .disabled(controller.isExporting)
    }

    private func shortTime(_ seconds: Double) -> String {
        String(format: "%.3fs", seconds)
    }

    private func clipLabel(_ segment: EditSegment) -> String {
        let name = segment.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "名称未設定" : name
    }
}
