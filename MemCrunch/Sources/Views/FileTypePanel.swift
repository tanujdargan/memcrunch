import SwiftUI

struct FileTypePanel: View {
    @Bindable var viewModel: ScanViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("File Types")
                        .font(.headline)

                    if let stats = viewModel.fileTypeStats {
                        Text("\(FormatHelpers.formatNumber(stats.total_files)) files, \(FormatHelpers.formatSize(stats.total_size))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Donut chart
                if let stats = viewModel.fileTypeStats, !stats.categories.isEmpty {
                    DonutChart(categories: stats.categories)
                        .frame(height: 160)
                        .padding(.vertical, 4)
                }

                // Category list
                if let stats = viewModel.fileTypeStats {
                    VStack(spacing: 2) {
                        ForEach(stats.categories) { category in
                            CategoryRow(category: category, totalSize: stats.total_size)
                        }
                    }
                }
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .onAppear {
            viewModel.updateFileTypeStats()
        }
        .onChange(of: viewModel.selectedNodeId) { _, _ in
            viewModel.updateFileTypeStats()
        }
    }
}

// MARK: - Donut Chart

struct DonutChart: View {
    let categories: [CategoryStats]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 10
            let innerRadius = radius * 0.55
            let totalSize = categories.reduce(0.0) { $0 + Double($1.total_size) }

            guard totalSize > 0 else { return }

            var startAngle = Angle.degrees(-90)

            for category in categories {
                let proportion = Double(category.total_size) / totalSize
                let sweepAngle = Angle.degrees(proportion * 360)
                let endAngle = startAngle + sweepAngle

                var path = Path()
                path.addArc(center: center, radius: radius,
                           startAngle: startAngle, endAngle: endAngle, clockwise: false)
                path.addArc(center: center, radius: innerRadius,
                           startAngle: endAngle, endAngle: startAngle, clockwise: true)
                path.closeSubpath()

                context.fill(path, with: .color(Color(hex: category.color)))

                startAngle = endAngle
            }
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: CategoryStats
    let totalSize: UInt64

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: category.color))
                        .frame(width: 10, height: 10)

                    Text(category.category)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(FormatHelpers.formatSize(category.total_size))
                            .font(.caption)
                            .monospacedDigit()

                        Text(FormatHelpers.formatPercentage(category.total_size, of: totalSize))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(isExpanded ? .degrees(90) : .degrees(0))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(category.top_extensions, id: \.extension_) { ext in
                        HStack(spacing: 6) {
                            Text(".\(ext.extension_)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)

                            // Size bar
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: category.color).opacity(0.3))
                                    .frame(
                                        width: geo.size.width * min(1.0, Double(ext.total_size) / Double(category.total_size)),
                                        height: 4
                                    )
                            }
                            .frame(height: 4)

                            Text(FormatHelpers.formatSize(ext.total_size))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                                .frame(width: 55, alignment: .trailing)
                        }
                        .padding(.horizontal, 22)
                    }
                }
                .padding(.bottom, 6)
            }
        }
    }
}
