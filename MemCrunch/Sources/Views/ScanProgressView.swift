import SwiftUI

struct ScanProgressView: View {
    @Bindable var viewModel: ScanViewModel

    @State private var elapsedSeconds: Int = 0

    private var progressFraction: Double {
        guard viewModel.scanningVolumeTotal > 0 else { return 0 }
        return min(1.0, Double(viewModel.bytesScanned) / Double(viewModel.scanningVolumeTotal))
    }

    private var elapsed: String {
        if elapsedSeconds < 60 { return "\(elapsedSeconds)s" }
        return "\(elapsedSeconds / 60)m \(elapsedSeconds % 60)s"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Scanning...")
                    .font(.title3)
                    .fontWeight(.semibold)

                // Progress bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.quaternary)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(4, geo.size.width * progressFraction))
                                .animation(.easeInOut(duration: 0.3), value: viewModel.bytesScanned)
                        }
                    }
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    HStack {
                        Text("\(Int(progressFraction * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                            .monospacedDigit()

                        Spacer()

                        Text(FormatHelpers.formatSize(viewModel.bytesScanned))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: 240)

                // Stats
                HStack(spacing: 24) {
                    StatItem(
                        icon: "doc.fill",
                        value: FormatHelpers.formatNumber(viewModel.filesScanned),
                        label: "files"
                    )
                    StatItem(
                        icon: "folder.fill",
                        value: FormatHelpers.formatNumber(viewModel.dirsScanned),
                        label: "folders"
                    )
                    StatItem(
                        icon: "clock",
                        value: elapsed,
                        label: "elapsed"
                    )
                }

                // Current path
                Text(viewModel.currentPath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 300, alignment: .leading)

                Button("Cancel") {
                    viewModel.cancelScan()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 20, y: 8)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if viewModel.isScanning {
                elapsedSeconds += 1
            }
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
