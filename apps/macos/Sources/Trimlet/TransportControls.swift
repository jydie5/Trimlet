import SwiftUI

/// Transport presentation. The workspace still observes the shared controller.
struct TransportControls: View {
    @ObservedObject var controller: PlayerController

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { controller.jump(by: -5) } label: {
                    Image(systemName: "gobackward.5")
                }.help("5秒戻る（Option＋←）").accessibilityLabel("5秒戻る")
                Button("−10f") { controller.step(by: -10) }
                    .help("10フレーム戻る（Shift＋←）")
                Button { controller.step(by: -1) } label: {
                    Image(systemName: "backward.frame")
                }.help("1フレーム戻る（←）").accessibilityLabel("1フレーム戻る")
                Button { controller.togglePlayback() } label: {
                    Image(systemName: controller.isPlaybackActive ? "pause.fill" : "play.fill")
                        .frame(width: 24)
                }
                .buttonStyle(.borderedProminent)
                .help("再生／一時停止（Space）")
                .accessibilityLabel(controller.isPlaybackActive ? "一時停止" : "再生")
                Button { controller.step(by: 1) } label: {
                    Image(systemName: "forward.frame")
                }.help("1フレーム進む（→）").accessibilityLabel("1フレーム進む")
                Button("＋10f") { controller.step(by: 10) }
                    .help("10フレーム進む（Shift＋→）")
                Button { controller.jump(by: 5) } label: {
                    Image(systemName: "goforward.5")
                }.help("5秒進む（Option＋→）").accessibilityLabel("5秒進む")
                Spacer(minLength: 8)
                Text("ソース " + controller.currentTimecode + " / " + controller.durationTimecode)
                    .monospacedDigit()
                    .font(.callout)
                    .accessibilityLabel("元動画の位置")
            }
            HStack(spacing: 6) {
                Button("J  逆再生") { controller.adjustShuttle(by: -1) }
                Button("K  停止") { controller.stopShuttle() }
                Button("L  順再生") { controller.adjustShuttle(by: 1) }
                if let rate = controller.shuttleDescription {
                    Text(rate).foregroundStyle(.orange).monospacedDigit()
                }
                if controller.playbackState == .waiting {
                    ProgressView().controlSize(.mini)
                }
                Spacer()
                Text(controller.playbackContextLabel + " " + controller.playbackProgressText)
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .controlSize(.small)
            .help("J／Lを繰り返すと1・2・4・8倍速。Kで停止します")
        }
        .disabled(!controller.hasMedia || controller.isExporting)
    }
}
