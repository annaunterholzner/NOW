import SwiftUI

/// An analog clock where every hand simply says NOW.
struct ClockFace: View {
    var date: Date
    /// 0 = night, 1 = day — the face adapts its glass and ink a little.
    var daylight: Double

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            let r = d / 2
            let a = angles(for: date)

            ZStack {
                // glass dial
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.55)
                Circle()
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: max(1, r * 0.012))

                // hour marks
                ForEach(0..<60, id: \.self) { i in
                    let major = i % 5 == 0
                    Capsule()
                        .fill(Color.white.opacity(major ? 0.9 : 0.45))
                        .frame(width: r * (major ? 0.022 : 0.009), height: r * (major ? 0.09 : 0.04))
                        .offset(y: -r * (major ? 0.86 : 0.88))
                        .rotationEffect(.degrees(Double(i) * 6))
                }

                NowHand(angle: a.hour, length: r * 0.52, width: r * 0.13, fill: handFill, ink: ink)
                NowHand(angle: a.minute, length: r * 0.76, width: r * 0.10, fill: handFill, ink: ink)
                NowHand(angle: a.second, length: r * 0.86, width: r * 0.068, fill: accent, ink: .white)

                Circle().fill(accent).frame(width: r * 0.075, height: r * 0.075)
                Circle().fill(Color.white).frame(width: r * 0.03, height: r * 0.03)
            }
            .frame(width: d, height: d)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .shadow(color: .black.opacity(0.25), radius: r * 0.04, y: r * 0.02)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text(date, style: .time))
    }

    private var handFill: Color { Color(red: 0.99, green: 0.97, blue: 0.92) }
    private var ink: Color { Color(red: 0.16, green: 0.18, blue: 0.24) }
    private var accent: Color { Color(red: 0.93, green: 0.42, blue: 0.33) }

    private func angles(for date: Date) -> (hour: Angle, minute: Angle, second: Angle) {
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let s = Double(c.second ?? 0) + Double(c.nanosecond ?? 0) / 1e9
        let m = Double(c.minute ?? 0) + s / 60
        let h = Double((c.hour ?? 0) % 12) + m / 60
        return (.degrees(h * 30), .degrees(m * 6), .degrees(s * 6))
    }
}

/// One hand: a rounded bar with "NOW" written along it, always readable.
struct NowHand: View {
    var angle: Angle
    var length: CGFloat
    var width: CGFloat
    var fill: Color
    var ink: Color

    var body: some View {
        // Keep the text upright-ish: on the left half of the dial, turn it around.
        let deg = angle.degrees.truncatingRemainder(dividingBy: 360)
        let flipped = deg > 180
        let tail = width * 0.9

        Capsule()
            .fill(fill)
            .overlay(
                Text("NOW")
                    .font(.system(size: width * 0.62, weight: .heavy, design: .rounded))
                    .kerning(width * 0.08)
                    .foregroundStyle(ink)
                    .fixedSize()
                    .rotationEffect(.degrees(flipped ? 90 : -90))
                    .offset(y: -(length - tail) * 0.18)
            )
            .frame(width: width, height: length + tail)
            .offset(y: -(length - tail) / 2)
            .rotationEffect(angle)
            .shadow(color: .black.opacity(0.18), radius: width * 0.15, y: width * 0.08)
    }
}
