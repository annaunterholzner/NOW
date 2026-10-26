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
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }   // nightstand-friendly
        }
        #else
        WindowGroup("NOW") {
            NowView()
                .environmentObject(location)
                .frame(minWidth: 360, minHeight: 360)
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("NOW", systemImage: "clock") {
            DesktopMenu()
        }
        #endif
    }
}
