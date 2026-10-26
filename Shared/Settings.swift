import SwiftUI
#if os(macOS)
import ServiceManagement
#endif

/// Stored choices. Asked once on the welcome screen, changed later only in Settings,
/// so the clock itself can run as a clean background.
enum SettingsKey {
    static let landscape = "landscape"
    static let clockScale = "clockScale"
    static let showSeconds = "showSeconds"
    static let hasOnboarded = "hasOnboarded"
    static let keepAwake = "keepAwake"
}

let accentCoral = Color(red: 0.93, green: 0.42, blue: 0.33)

// MARK: - Welcome (first launch)

struct OnboardingView: View {
    @AppStorage(SettingsKey.landscape) private var landscape = Landscape.mountains.rawValue
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    #if os(macOS)
    @ObservedObject private var desktop = DesktopController.shared
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOW")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .kerning(6)
                    Text("A clock for the present moment. The picture follows the real sun, moon and seasons where you are.")
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Choose your scenery")
                    SceneryPicker(selection: $landscape)
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Where are you?")
                    LocationRow()
                }
                #if os(macOS)
                Toggle("Show NOW on my Desktop, behind my icons", isOn: $desktop.isOn)
                #endif
                Button {
                    withAnimation { hasOnboarded = true }
                } label: {
                    Text("Start").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(accentCoral)

                Text(laterHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .frame(maxWidth: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var laterHint: String {
        #if os(iOS)
        "Later, press and hold anywhere on the screen to open Settings."
        #else
        "Later, find Settings under the clock icon in the menu bar, or press ⌘,."
        #endif
    }
}

// MARK: - Settings

struct SettingsView: View {
    @AppStorage(SettingsKey.landscape) private var landscape = Landscape.mountains.rawValue
    @AppStorage(SettingsKey.clockScale) private var clockScale = 0.62
    @AppStorage(SettingsKey.showSeconds) private var showSeconds = true
    #if os(iOS)
    @AppStorage(SettingsKey.keepAwake) private var keepAwake = true
    @Environment(\.dismiss) private var dismiss
    #else
    @ObservedObject private var desktop = DesktopController.shared
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    #endif

    var body: some View {
        Form {
            Section("Scenery") {
                SceneryPicker(selection: $landscape)
                    .padding(.vertical, 4)
            }
            Section("Clock") {
                LabeledContent("Size") {
                    Slider(value: $clockScale, in: 0.35...0.8)
                }
                Toggle("Second hand", isOn: $showSeconds)
            }
            Section("Location") {
                LocationRow()
            }
            #if os(iOS)
            Section {
                Toggle("Keep screen on", isOn: $keepAwake)
            } footer: {
                Text("Handy on a stand or nightstand. Uses more battery when not charging.")
            }
            #else
            Section("Mac") {
                Toggle("Show NOW on Desktop", isOn: $desktop.isOn)
                Toggle("Open at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            openAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            #endif
        }
        .formStyle(.grouped)
        #if os(iOS)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        #else
        .frame(width: 460)
        #endif
    }
}

// MARK: - Pieces

struct SectionLabel: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .kerning(1)
            .foregroundStyle(.secondary)
    }
}

/// Two cards with small live pictures of each scenery.
struct SceneryPicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Landscape.allCases) { l in
                let selected = selection == l.rawValue
                Button {
                    selection = l.rawValue
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        SceneryThumbnail(landscape: l)
                            .aspectRatio(16 / 10, contentMode: .fit)
                        Text(l.title)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selected ? Color.primary : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

struct SceneryThumbnail: View {
    var landscape: Landscape
    @EnvironmentObject private var location: LocationProvider

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            NatureScene(sky: SkyState(date: tl.date, latitude: location.latitude, longitude: location.longitude),
                        time: tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000),
                        landscape: landscape, showLife: false)
        }
    }
}

/// Shows whether the real location is used, and lets the person allow it.
struct LocationRow: View {
    @EnvironmentObject private var location: LocationProvider

    var body: some View {
        switch location.status {
        case .notDetermined:
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    location.requestPermission()
                } label: {
                    Label("Use my location", systemImage: "location.fill")
                }
                Text("Only a rough position is used, and it never leaves your device. Without it, NOW guesses from your time zone.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        case .denied, .restricted:
            VStack(alignment: .leading, spacing: 8) {
                Text("Location is off, so NOW guesses from your time zone.")
                if let url = settingsURL { Link("Turn on location in Settings", destination: url) }
            }
        default:
            Label(location.isApproximate ? "Finding your location…" : "Using your location",
                  systemImage: "location.fill")
        }
    }

    private var settingsURL: URL? {
        #if os(iOS)
        URL(string: UIApplication.openSettingsURLString)
        #else
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
        #endif
    }
}
