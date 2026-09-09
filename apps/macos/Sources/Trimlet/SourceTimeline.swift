import SwiftUI
import TrimletCore

struct SourceTimeline: View {
    @ObservedObject var controller: PlayerController
    @State private var viewport = TimelineViewport.full(duration: 0)
    @State private var dragTarget: TimelineInteractionLayout.Target?
    @State private var dragStartSeconds = 0.0
    @State private var hoverTarget: TimelineInteractionLayout.Target?
    @State private var hoverSeconds = 0.0

    private var enabled: Bool { controller.hasMedia && !controller.isLoading && !controller.isExporting && controller.activeOperation == nil }
    private var minimumSpan: Double { min(controller.durationSeconds, max(0.1, 10 / max(1, controller.nominalFrameRate))) }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Label("ソースタイムライン", systemImage: "film")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 4)
                Button { zoom(0.5) } label: { Image(systemName: "minus.magnifyingglass") }
                    .accessibilityLabel("タイムラインを縮小")
                    .disabled(viewport.span >= viewport.duration)
                Button { zoom(2) } label: { Image(systemName: "plus.magnifyingglass") }
                    .accessibilityLabel("タイムラインを拡大")
                    .disabled(viewport.span <= minimumSpan)
                Button("全体") { viewport = .full(duration: controller.durationSeconds) }
                    .help("元動画全体を表示します。再生位置や編集内容は変わりません")
                Button("範囲に合わせる") { fitDraft() }
                    .disabled(!controller.trimRange.isValid)
                    .help("作成中のIN／OUT範囲を拡大して表示")
            }
            .controlSize(.small)

            GeometryReader { geometry in
                let layout = TimelineInteractionLayout(width: geometry.size.width, viewport: viewport)
                ZStack(alignment: .topLeading) {
                    RangeBar(
                        start: viewport.start, span: viewport.span,
                        current: controller.currentSeconds,
                        draftInPoint: controller.trimRange.inPoint,
                        draftOutPoint: controller.trimRange.outPoint,
                        segments: controller.editList.segments,
                        selectedSegmentID: controller.selectedSegmentID,
                        keyframes: controller.keyframeIndex?.keyframes ?? [],
                        fastCandidates: controller.exportMode == .fast ? controller.fastCandidates : [:]
                    )
                    .padding(.horizontal, layout.inset)
                    .allowsHitTesting(false)
                    if let point = controller.trimRange.inPoint {
                        handle(.start, point: point, layout: layout)
                    }
                    if let point = controller.trimRange.outPoint {
                        handle(.end, point: point, layout: layout)
                    }
                }
                .frame(width: geometry.size.width, height: TimelineInteractionLayout.height)
                .contentShape(Rectangle())
                .coordinateSpace(name: "sourceTimeline")
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("sourceTimeline"))
                    .onChanged { value in updateDrag(value, layout: layout) }
                    .onEnded { value in
                        updateDrag(value, layout: layout)
                        controller.endScrubbing()
                        dragTarget = nil
                    })
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point):
                        hoverTarget = layout.target(x: point.x, y: point.y, inPoint: controller.trimRange.inPoint, outPoint: controller.trimRange.outPoint)
                        hoverSeconds = layout.time(at: point.x)
                    case .ended: hoverTarget = nil
                    }
                }
                .background(TimelineScrollCapture(enabled: enabled, onSeek: { delta in
                    controller.updateScrubbingPosition(to: controller.currentSeconds + delta)
                }, onEnd: { controller.endScrubbing() }))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("ソースタイムライン。クリックまたはドラッグでシーク")
                .accessibilityValue(controller.currentTimecode)
                .accessibilityAdjustableAction { direction in
                    guard enabled else { return }
                    switch direction {
                    case .increment: controller.step(by: 1)
                    case .decrement: controller.step(by: -1)
                    @unknown default: break
                    }
                }
            }
            .frame(height: TimelineInteractionLayout.height)

            HStack(spacing: 6) {
                Text("紫：作成中　青：追加済み")
                Spacer(minLength: 4)
                Button { viewport = viewport.panned(by: -viewport.span * 0.75) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("表示範囲を前へ")
                    .disabled(viewport.start <= 0)
                Text(String(format: "%.2f–%.2fs", viewport.start, viewport.end)).monospacedDigit()
                    .accessibilityLabel("タイムラインの表示範囲")
                Button { viewport = viewport.panned(by: viewport.span * 0.75) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("表示範囲を後へ")
                    .disabled(viewport.end >= viewport.duration)
                Button("再生位置へ") { viewport = viewport.revealing(controller.currentSeconds) }
                    .help("表示範囲だけを移動します。シークはしません")
            }
            .font(.caption2).foregroundStyle(.secondary).controlSize(.mini)
            HStack {
                Text(interactionHint)
                Spacer()
                analysisStatus
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .disabled(!enabled)
        .onAppear { resetViewport() }
        .onChange(of: controller.currentURL) { _, _ in resetViewport() }
        .onChange(of: controller.durationSeconds) { _, _ in resetViewport() }
        .onChange(of: enabled) { _, active in
            if !active { controller.endScrubbing(); dragTarget = nil; hoverTarget = nil }
        }
        .onDisappear {
            controller.endScrubbing()
            dragTarget = nil
            hoverTarget = nil
        }
    }

    @ViewBuilder private var analysisStatus: some View {
        switch controller.keyframeAnalysisState {
        case .running:
            Text("キーフレーム解析中…")
        case .failed:
            Text("解析失敗：正確モードを利用できます").foregroundStyle(.orange)
        case .ready, .idle:
            if controller.exportMode == .fast, controller.trimRange.isValid {
                if let candidate = controller.fastCandidate {
                    Text(String(format: "高速候補 %.2f–%.2fs", candidate.start, candidate.end))
                        .foregroundStyle(.orange)
                } else {
                    Text("この範囲は正確モードを推奨").foregroundStyle(.orange)
                }
            } else if let index = controller.keyframeIndex {
                Text("キーフレーム \(index.keyframes.count)個")
                    .help("橙の短い目盛りはキーフレーム。橙の枠は高速書き出しの候補範囲です")
            }
        }
    }

    @ViewBuilder private func handle(_ boundary: PlayerController.DraftBoundary, point: Double, layout: TimelineInteractionLayout) -> some View {
        if point >= viewport.start && point <= viewport.end {
            let isStart = boundary == .start
            let target: TimelineInteractionLayout.Target = isStart ? .start : .end
            let highlighted = dragTarget == target || hoverTarget == target
            DraftRangeGrip(isStart: isStart, highlighted: highlighted)
                .offset(x: layout.x(for: point) - (isStart ? 24 : 0), y: 40)
                // One parent gesture owns hit testing; visuals cannot steal a seek.
                .allowsHitTesting(false)
                .help("\(isStart ? "IN" : "OUT")端をドラッグして下書きを調整（公称fps刻み）。既存クリップは適用まで変わりません")
                .accessibilityLabel(isStart ? "IN点ハンドル" : "OUT点ハンドル")
                .accessibilityValue(String(format: "%.3f秒", point))
                .accessibilityAdjustableAction { direction in
                    guard enabled else { return }
                    let step = 1 / max(1, controller.nominalFrameRate)
                    switch direction {
                    case .increment: controller.moveDraftBoundary(boundary, to: point + step)
                    case .decrement: controller.moveDraftBoundary(boundary, to: point - step)
                    @unknown default: return
                    }
                    controller.endScrubbing()
                }
        }
    }

    private var interactionHint: String {
        guard let target = dragTarget ?? hoverTarget else {
            return "目盛り・帯：再生位置を移動 · 両端：IN／OUT調整 · 二本指：シーク"
        }
        let label: String
        let seconds: Double
        switch target {
        case .seek:
            label = "再生位置を移動"
            seconds = dragTarget == nil ? hoverSeconds : controller.currentSeconds
        case .start:
            label = "INを調整"
            seconds = controller.trimRange.inPoint ?? controller.currentSeconds
        case .end:
            label = "OUTを調整"
            seconds = controller.trimRange.outPoint ?? controller.currentSeconds
        }
        return "\(label) · \(TimecodeFormatter.string(seconds: seconds, framesPerSecond: controller.nominalFrameRate))"
    }

    private func updateDrag(_ value: DragGesture.Value, layout: TimelineInteractionLayout) {
        guard enabled else { return }
        if dragTarget == nil {
            let target = layout.target(x: value.startLocation.x, y: value.startLocation.y,
                                       inPoint: controller.trimRange.inPoint, outPoint: controller.trimRange.outPoint)
            dragTarget = target
            dragStartSeconds = target == .start ? (controller.trimRange.inPoint ?? controller.currentSeconds)
                : target == .end ? (controller.trimRange.outPoint ?? controller.currentSeconds) : controller.currentSeconds
        }
        switch dragTarget {
        case .start:
            if value.translation.width == 0 {
                controller.updateScrubbingPosition(to: dragStartSeconds)
            } else {
                controller.moveDraftBoundary(.start, to: layout.translatedTime(from: dragStartSeconds, deltaX: value.translation.width))
            }
        case .end:
            if value.translation.width == 0 {
                controller.updateScrubbingPosition(to: dragStartSeconds)
            } else {
                controller.moveDraftBoundary(.end, to: layout.translatedTime(from: dragStartSeconds, deltaX: value.translation.width))
            }
        case .seek:
            controller.updateScrubbingPosition(to: layout.time(at: value.location.x))
        case nil: break
        }
    }
    private func resetViewport() { viewport = .full(duration: controller.durationSeconds) }
    private func zoom(_ factor: Double) {
        viewport = viewport.zoomed(by: factor, anchorTime: controller.currentSeconds, minimumSpan: minimumSpan)
    }
    private func fitDraft() {
        guard let a = controller.trimRange.inPoint, let b = controller.trimRange.outPoint, b > a else { return }
        let span = max(minimumSpan, (b - a) * 1.25)
        viewport = TimelineViewport(duration: controller.durationSeconds, start: a - (span - (b - a)) / 2, span: span)
    }
}
