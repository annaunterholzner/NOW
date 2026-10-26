import SwiftUI

/// The whole picture: living landscape + the NOW clock. Nothing else on screen,
/// so it works as a background. Setup happens once on the welcome card.
struct NowView: View {
    @EnvironmentObject private var location: LocationProvider
    @AppStorage(SettingsKey.landscape) private var landscapeRaw = Landscape.mountains.rawValue
    @AppStorage(SettingsKey.clockScale) private var clockScale = 0.62
    @AppStorage(SettingsKey.showSeconds) private var showSeconds = true
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    #if os(iOS)
    @AppStorage(SettingsKey.keepAwake) private var keepAwake = true
    @State private var showSettings = false
    #endif

    /// False on the Mac desktop: never reacts to clicks and never shows the welcome card.
    var interactive = true
    /// Lower on the Mac desktop to save energy.
    var framesPerSecond: Double = 30

    private var landscape: Landscape { Landscape(rawValue: landscapeRaw) ?? .mountains }

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / framesPerSecond)) { timeline in
                let now = timeline.date
                let sky = SkyState(date: now, latitude: location.latitude, longitude: location.longitude)

                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height) * clockScale
                    ZStack {
                        NatureScene(sky: sky,
                                    time: now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000),
                                    landscape: landscape)
                        ClockFace(date: now, showSeconds: showSeconds)
                            .frame(width: side, height: side)
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
                    }
                }
            }
            .ignoresSafeArea()

            if interactive && !hasOnboarded {
                Color.black.opacity(0.3).ignoresSafeArea()
                OnboardingView()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(16)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear { location.start() }
        #if os(iOS)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.6) { if hasOnboarded { showSettings = true } }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
                .environmentObject(location)
                .presentationDetents([.medium, .large])
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepAwake }
        .onChange(of: keepAwake) { _, on in UIApplication.shared.isIdleTimerDisabled = on }
        #endif
    }
}
