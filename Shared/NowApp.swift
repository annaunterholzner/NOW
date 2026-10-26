import SwiftUI

@main
struct NowApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        #if os(iOS)
        WindowGroup {
            NowWebView()
                .ignoresSafeArea()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                .onAppear {
                    LocationProvider.shared.start()
                    NowBridge.shared.applyKeepAwake()
                }
        }
        #else
        Window("NOW", id: "main") {
            NowWebView()
                .ignoresSafeArea()
                .frame(minWidth: 420, minHeight: 420)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { NowBridge.shared.openSettings() }
                    .keyboardShortcut(",")
            }
        }

        MenuBarExtra("NOW", systemImage: "clock") {
            DesktopMenu()
        }
        #endif
    }
}
