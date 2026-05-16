import SwiftUI

struct ClockView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let date = context.date
            VStack(spacing: 8) {
                AnalogClock(date: date)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 20)

                DigitalReadout(date: date)
            }
            .padding(.vertical, 8)
        }
    }
}

private struct AnalogClock: View {
    let date: Date

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 2

            // 文字盤
            let face = Path(ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))
            context.fill(face, with: .color(.white.opacity(0.06)))
            context.stroke(face, with: .color(.white.opacity(0.3)), lineWidth: 1.5)

            // 時マーカー
            for hour in 0..<12 {
                let angle = Double(hour) / 12 * 2 * .pi - .pi / 2
                let outer = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                let inner = CGPoint(
                    x: center.x + cos(angle) * radius * 0.86,
                    y: center.y + sin(angle) * radius * 0.86
                )
                var marker = Path()
                marker.move(to: outer)
                marker.addLine(to: inner)
                context.stroke(marker, with: .color(.white.opacity(0.7)), lineWidth: hour % 3 == 0 ? 3 : 1.5)
            }

            let comps = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
            let hour = Double(comps.hour ?? 0)
            let minute = Double(comps.minute ?? 0)
            let second = Double(comps.second ?? 0) + Double(comps.nanosecond ?? 0) / 1_000_000_000

            // 時針
            let hourAngle = ((hour.truncatingRemainder(dividingBy: 12)) + minute / 60) / 12 * 2 * .pi - .pi / 2
            drawHand(in: context, center: center, angle: hourAngle, length: radius * 0.55, width: 4, color: .white)

            // 分針
            let minuteAngle = (minute + second / 60) / 60 * 2 * .pi - .pi / 2
            drawHand(in: context, center: center, angle: minuteAngle, length: radius * 0.78, width: 3, color: .white)

            // 秒針（赤）
            let secondAngle = second / 60 * 2 * .pi - .pi / 2
            drawHand(in: context, center: center, angle: secondAngle, length: radius * 0.86, width: 1.5, color: .red)

            // 中心点
            let dotSize: CGFloat = 6
            let dot = Path(ellipseIn: CGRect(
                x: center.x - dotSize / 2, y: center.y - dotSize / 2,
                width: dotSize, height: dotSize
            ))
            context.fill(dot, with: .color(.white))
        }
    }

    private func drawHand(in context: GraphicsContext, center: CGPoint, angle: Double, length: CGFloat, width: CGFloat, color: Color) {
        let end = CGPoint(
            x: center.x + cos(angle) * length,
            y: center.y + sin(angle) * length
        )
        var path = Path()
        path.move(to: center)
        path.addLine(to: end)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}

private struct DigitalReadout: View {
    let date: Date

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日 (E)"
        return f
    }()

    var body: some View {
        VStack(spacing: 2) {
            Text(Self.timeFormatter.string(from: date))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(Self.dateFormatter.string(from: date))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ClockView()
}
