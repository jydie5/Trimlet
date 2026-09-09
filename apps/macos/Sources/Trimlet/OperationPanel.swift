import SwiftUI

struct OperationPanel: View {
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
