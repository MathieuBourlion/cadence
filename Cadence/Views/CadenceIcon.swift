import SwiftUI

/// Programmatic Cadence app icon. Resolution-independent — pass any `size`.
/// All measurements derived proportionally; no hardcoded point values.
struct CadenceIcon: View {
    let size: CGFloat

    // MARK: - Layout constants (as ratios)

    private var cornerRadius: CGFloat { size * 0.215 }
    private var inset: CGFloat { size * 0.18 }
    private var usableWidth: CGFloat { size - 2 * inset }
    private var usableHeight: CGFloat { size - 2 * inset }
    private var barWidth: CGFloat { usableWidth * 0.13 }
    private var gap: CGFloat { (usableWidth - barWidth * 6) / 5 }
    private var baselineY: CGFloat { inset + usableHeight }   // canvas top-down
    private var circleGap: CGFloat { 6 * (size / 200) }
    private var innerStrokeWidth: CGFloat { 0.5 * (size / 200) }

    private let heightFractions: [CGFloat] = [0.25, 0.38, 0.50, 0.35, 0.21, 0.29]
    private let activeIndex = 2

    // MARK: - Colors

    private let bgTop    = Color(hex: "#1E1D1C")
    private let bgBottom = Color(hex: "#141312")

    private let activeTop    = Color(hex: "#F2F0EC")
    private let activeBottom = Color(hex: "#C8C4BE")

    private let inactiveTop    = Color(hex: "#3C3A37")
    private let inactiveBottom = Color(hex: "#2C2B28")

    private let dotColor = Color(hex: "#F2F0EC")

    // MARK: - Body

    var body: some View {
        Canvas { ctx, _ in
            // 1. Background
            let bgRect = CGRect(x: 0, y: 0, width: size, height: size)
            let bgPath = Path(roundedRect: bgRect, cornerRadius: cornerRadius)
            ctx.fill(bgPath, with: .linearGradient(
                Gradient(colors: [bgTop, bgBottom]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size)
            ))

            // 2. Bars
            for i in 0..<6 {
                let barHeight = heightFractions[i] * usableHeight
                let x = inset + CGFloat(i) * (barWidth + gap)
                let y = baselineY - barHeight
                let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                let barRadius = 2 * (size / 200)
                let barPath = Path(roundedRect: barRect, cornerRadius: barRadius)

                if i == activeIndex {
                    ctx.fill(barPath, with: .linearGradient(
                        Gradient(colors: [activeTop, activeBottom]),
                        startPoint: CGPoint(x: x, y: y),
                        endPoint: CGPoint(x: x, y: y + barHeight)
                    ))
                } else {
                    ctx.fill(barPath, with: .linearGradient(
                        Gradient(colors: [inactiveTop, inactiveBottom]),
                        startPoint: CGPoint(x: x, y: y),
                        endPoint: CGPoint(x: x, y: y + barHeight)
                    ))
                }
            }

            // 3. Circle above active bar
            let activeBarHeight = heightFractions[activeIndex] * usableHeight
            let activeBarX = inset + CGFloat(activeIndex) * (barWidth + gap)
            let activeBarTopY = baselineY - activeBarHeight
            let circleDiameter = barWidth * 0.55
            let circleRadius = circleDiameter / 2
            let circleCenterX = activeBarX + barWidth / 2
            let circleCenterY = activeBarTopY - circleGap - circleRadius
            let circleRect = CGRect(
                x: circleCenterX - circleRadius,
                y: circleCenterY - circleRadius,
                width: circleDiameter,
                height: circleDiameter
            )
            ctx.fill(Path(ellipseIn: circleRect), with: .color(dotColor))

            // 4. Baseline
            let baseline = Path { p in
                p.move(to: CGPoint(x: inset, y: baselineY))
                p.addLine(to: CGPoint(x: inset + usableWidth, y: baselineY))
            }
            ctx.stroke(baseline, with: .color(.white.opacity(0.10)), lineWidth: 1)

            // 5. Inner stroke
            let innerInset = innerStrokeWidth / 2
            let strokeRect = bgRect.insetBy(dx: innerInset, dy: innerInset)
            let strokePath = Path(roundedRect: strokeRect, cornerRadius: cornerRadius - innerInset)
            ctx.stroke(strokePath, with: .color(.white.opacity(0.07)), lineWidth: innerStrokeWidth)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Hex color helper

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Export helper

/// Renders `CadenceIcon` at `size` points and returns an `NSImage`.
/// Use this to generate PNG files for the AppIcon asset catalog.
///
/// Recommended sizes: 1024, 512, 256, 128, 64, 32, 16
/// Save each output as `AppIcon-{size}.png` in
/// `Cadence/Assets.xcassets/AppIcon.appiconset/`
@MainActor
func renderCadenceIcon(size: CGFloat, scale: CGFloat = 2) -> NSImage? {
    let renderer = ImageRenderer(content: CadenceIcon(size: size))
    renderer.scale = scale
    return renderer.nsImage
}

// MARK: - Preview

#Preview("App Icon Sizes") {
    HStack(spacing: 24) {
        VStack(spacing: 4) {
            CadenceIcon(size: 512)
            Text("512").font(.caption).foregroundStyle(.secondary)
        }
        VStack(spacing: 4) {
            CadenceIcon(size: 128)
            Text("128").font(.caption).foregroundStyle(.secondary)
        }
        VStack(spacing: 4) {
            CadenceIcon(size: 64)
            Text("64").font(.caption).foregroundStyle(.secondary)
        }
    }
    .padding(24)
    .background(.black)
}
