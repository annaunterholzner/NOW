import SwiftUI

/// An analog clock where every hour reads NOW. The hands are plain and clean.
struct ClockFace: View {
    var date: Date
    var showSeconds: Bool = true

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            let r = d / 2
            let a = angles(for: date)

            ZStack {
                // glass dial
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)
                Circle()
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: max(1, r * 0.012))

                // small minute marks between the hours
                ForEach(0..<60, id: \.self) { i in
                    if i % 5 != 0 {
                        Capsule()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: r * 0.01, height: r * 0.04)
                            .offset(y: -r * 0.9)
                            .rotationEffect(.degrees(Double(i) * 6))
                    }
                }

                // NOW at every hour, following the circle; the lower ones turned to stay readable
                ForEach(0..<12, id: \.self) { i in
                    let bottom = (4...8).contains(i)
                    Text("NOW")
                        .font(.system(size: r * 0.105, weight: .heavy, design: .rounded))
                        .kerning(r * 0.012)
                        .foregroundStyle(Color.white.opacity(0.96))
                        .shadow(color: .black.opacity(0.3), radius: r * 0.015)
                        .fixedSize()
                        .offset(y: bottom ? r * 0.79 : -r * 0.79)
                        .rotationEffect(.degrees(Double(i) * 30 - (bottom ? 180 : 0)))
                }

                Hand(angle: a.hour, length: r * 0.5, width: r * 0.06, tail: r * 0.08, color: cream)
                Hand(angle: a.minute, length: r * 0.72, width: r * 0.042, tail: r * 0.08, color: cream)
                Circle().fill(cream).frame(width: r * 0.1, height: r * 0.1)

                if showSeconds {
                    Hand(angle: a.second, length: r * 0.84, width: r * 0.014, tail: r * 0.2, color: coral)
                    Circle().fill(coral).frame(width: r * 0.06, height: r * 0.06)
                        .offset(y: r * 0.17)
                        .rotationEffect(a.second)
                    Circle().fill(coral).frame(width: r * 0.06, height: r * 0.06)
                }
                Circle().fill(Color(red: 0.16, green: 0.18, blue: 0.24)).frame(width: r * 0.024, height: r * 0.024)
            }
            .frame(width: d, height: d)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .shadow(color: .black.opacity(0.22), radius: r * 0.04, y: r * 0.02)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text(date, style: .time))
    }

    private var cream: Color { Color(red: 0.99, green: 0.97, blue: 0.92) }
    private var coral: Color { Color(red: 0.93, green: 0.42, blue: 0.33) }

    private func angles(for date: Date) -> (hour: Angle, minute: Angle, second: Angle) {
        let c = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let s = Double(c.second ?? 0) + Double(c.nanosecond ?? 0) / 1e9
        let m = Double(c.minute ?? 0) + s / 60
        let h = Double((c.hour ?? 0) % 12) + m / 60
        return (.degrees(h * 30), .degrees(m * 6), .degrees(s * 6))
    }
}

/// A plain rounded hand that pivots at the centre of the dial.
private struct Hand: View {
    var angle: Angle
    var length: CGFloat
    var width: CGFloat
    var tail: CGFloat
    var color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length + tail)
            .offset(y: -(length - tail) / 2)
            .rotationEffect(angle)
            .shadow(color: .black.opacity(0.25), radius: width * 0.5, y: width * 0.15)
    }
}
