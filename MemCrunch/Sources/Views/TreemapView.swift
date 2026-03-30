import SwiftUI

struct TreemapView: View {
    @Bindable var viewModel: ScanViewModel

    @State private var hoveredRect: TreemapRect?
    @State private var tooltipPosition: CGPoint = .zero
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    drawTreemap(context: context, size: size)
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hoveredRect = findRect(at: location)
                        tooltipPosition = location
                    case .ended:
                        hoveredRect = nil
                    }
                }
                .onTapGesture(count: 1) { location in
                    if let rect = findRect(at: location) {
                        if rect.is_dir {
                            viewModel.drillDown(into: rect.id)
                        } else {
                            viewModel.selectNode(rect.id)
                        }
                    }
                }
                .onChange(of: geometry.size) { _, newSize in
                    canvasSize = newSize
                    viewModel.updateTreemap(width: newSize.width, height: newSize.height)
                }
                .onAppear {
                    canvasSize = geometry.size
                    viewModel.updateTreemap(width: geometry.size.width, height: geometry.size.height)
                }
                .onChange(of: viewModel.selectedNodeId) { _, _ in
                    viewModel.updateTreemap(width: canvasSize.width, height: canvasSize.height)
                }

                // Tooltip
                if let rect = hoveredRect {
                    tooltipView(for: rect)
                        .position(
                            x: min(tooltipPosition.x + 100, geometry.size.width - 100),
                            y: max(tooltipPosition.y - 35, 30)
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Drawing

    private func drawTreemap(context: GraphicsContext, size: CGSize) {
        let rects = viewModel.treemapRects

        if rects.isEmpty {
            let text = Text("No data to display")
                .font(.title3)
                .foregroundColor(.secondary)
            context.draw(context.resolve(text),
                         at: CGPoint(x: size.width / 2, y: size.height / 2),
                         anchor: .center)
            return
        }

        for rect in rects {
            let isHovered = hoveredRect?.id == rect.id
            let cgRect = CGRect(x: rect.x, y: rect.y, width: rect.w, height: rect.h)
            let color = Color(hex: rect.color)
            let cornerRadius: CGFloat = rect.w > 20 && rect.h > 20 ? 4 : 1
            let rrPath = Path(roundedRect: cgRect, cornerRadius: cornerRadius)

            // Fill
            let fillOpacity = isHovered ? 0.95 : (rect.is_dir ? 0.5 : 0.8)
            context.fill(rrPath, with: .color(color.opacity(fillOpacity)))

            // Border
            if isHovered {
                context.stroke(rrPath, with: .color(.white.opacity(0.9)), lineWidth: 2)
            } else {
                context.stroke(rrPath, with: .color(.black.opacity(0.25)), lineWidth: 0.5)
            }

            // Directory indicator: small folder icon area
            if rect.is_dir && rect.w > 30 && rect.h > 30 {
                let badge = CGRect(x: rect.x + rect.w - 18, y: rect.y + 4, width: 14, height: 14)
                let badgePath = Path(roundedRect: badge, cornerRadius: 2)
                context.fill(badgePath, with: .color(.black.opacity(0.2)))
                let folderIcon = Text("📁").font(.system(size: 10))
                context.draw(context.resolve(folderIcon),
                             at: CGPoint(x: badge.midX, y: badge.midY),
                             anchor: .center)
            }

            // Labels — only when there's actually room
            drawLabel(context: context, rect: rect)
        }
    }

    private func drawLabel(context: GraphicsContext, rect: TreemapRect) {
        let padding: CGFloat = 6
        let availW = rect.w - padding * 2
        let availH = rect.h - padding * 2

        // Need at least 40x14 for any text
        guard availW >= 40 && availH >= 14 else { return }

        // Clipping context so text never bleeds outside the rect
        var context = context
        context.drawLayer { ctx in
            ctx.clip(to: Path(CGRect(x: rect.x, y: rect.y, width: rect.w, height: rect.h)))

            // Name
            let fontSize = min(12.0, max(9.0, min(availW / 10, availH / 3)))
            let nameText = Text(rect.name)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(.white)
            ctx.draw(ctx.resolve(nameText),
                     in: CGRect(x: rect.x + padding,
                                y: rect.y + padding,
                                width: availW,
                                height: fontSize + 2))

            // Size (only if tall enough for a second line)
            if availH >= 30 {
                let sizeText = Text(FormatHelpers.formatSize(rect.size))
                    .font(.system(size: max(8, fontSize - 2)))
                    .foregroundColor(.white.opacity(0.7))
                ctx.draw(ctx.resolve(sizeText),
                         in: CGRect(x: rect.x + padding,
                                    y: rect.y + padding + fontSize + 2,
                                    width: availW,
                                    height: fontSize))
            }
        }
    }

    // MARK: - Hit testing

    private func findRect(at point: CGPoint) -> TreemapRect? {
        // Flat layout = no overlap, but search reverse for consistent behavior
        for rect in viewModel.treemapRects.reversed() {
            if point.x >= rect.x && point.x <= rect.x + rect.w &&
               point.y >= rect.y && point.y <= rect.y + rect.h {
                return rect
            }
        }
        return nil
    }

    // MARK: - Tooltip

    @ViewBuilder
    private func tooltipView(for rect: TreemapRect) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(rect.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(FormatHelpers.formatSize(rect.size))
                    .monospacedDigit()
                if let ext = rect.extension_ {
                    Text(".\(ext)")
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if rect.is_dir {
                Text("Double-click to open")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}
