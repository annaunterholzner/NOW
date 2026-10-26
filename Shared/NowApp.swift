import SwiftUI

@main
struct NowApp: App {
    @StateObject private var location = LocationProvider.shared

    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        #if os(iOS)
        WindowGroup {
            NowView()
                .environmentObject(location)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
        #else
        WindowGroup("NOW", id: "main") {
            NowView()
                .environmentObject(location)
                .frame(minWidth: 420, minHeight: 420)
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
                .environmentObject(location)
        }

        MenuBarExtra("NOW", systemImage: "clock") {
            DesktopMenu()
        }
        #endif
    }
}
