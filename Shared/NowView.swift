import SwiftUI

/// The whole picture: living landscape + the NOW clock on top.
struct NowView: View {
    @EnvironmentObject private var location: LocationProvider
    @AppStorage("clockScale") private var clockScale: Double = 0.62
    @AppStorage("showInfo") private var showInfo = false

    /// When true (Mac desktop mode) the view never reacts to clicks.
    var interactive = true
    /// Lower on the Mac desktop to save energy.
    var framesPerSecond: Double = 30

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / framesPerSecond)) { timeline in
            let now = timeline.date
            let sky = SkyState(date: now, latitude: location.latitude, longitude: location.longitude)

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height) * clockScale
                ZStack {
                    NatureScene(sky: sky, time: now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000))

                    ClockFace(date: now, daylight: sky.daylight)
                        .frame(width: side, height: side)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.42)

                    if showInfo {
                        InfoCaption(sky: sky, approximate: location.isApproximate)
                            .position(x: geo.size.width / 2, y: geo.size.height - 44)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if interactive { withAnimation { showInfo.toggle() } } }
        .onAppear { location.start() }
    }
}

private struct InfoCaption: View {
    var sky: SkyState
    var approximate: Bool

    var body: some View {
        let season: String = switch sky.dominantSeason {
            case .winter: "Winter"
            case .spring: "Spring"
            case .summer: "Summer"
            case .autumn: "Autumn"
        }
        Text("\(season) · sun \(Int(sky.sunAltitude.rounded()))° · moon \(Int((sky.moonFraction * 100).rounded()))%\(approximate ? " · approx. location" : "")")
            .font(.system(.footnote, design: .rounded).weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
