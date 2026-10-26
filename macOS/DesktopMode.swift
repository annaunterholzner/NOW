import AppKit
import SwiftUI

/// Puts NOW behind your desktop icons, like a living wallpaper — on every screen and every Space.
@MainActor
final class DesktopController: ObservableObject {
    static let shared = DesktopController()

    @Published var isOn: Bool = UserDefaults.standard.bool(forKey: "desktopMode") {
        didSet {
            UserDefaults.standard.set(isOn, forKey: "desktopMode")
            isOn ? show() : hide()
        }
    }

    private var windows: [NSWindow] = []
    private var screenObserver: NSObjectProtocol?

    private init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                let c = DesktopController.shared
                if c.isOn { c.show() }   // rebuild for new / resized displays
            }
        }
    }

    func show() {
        hide()
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless],
                                  backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: false)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = true
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: NowView(interactive: false, framesPerSecond: 15)
                    .environmentObject(LocationProvider.shared)
            )
            window.orderFront(nil)
            windows.append(window)
        }
    }

    func owns(_ window: NSWindow) -> Bool { windows.contains(window) }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            LocationProvider.shared.start()
            let desktop = DesktopController.shared
            if desktop.isOn { desktop.show() }
            // Running as a background: once set up, don't pop a window open on every launch.
            if desktop.isOn && UserDefaults.standard.bool(forKey: SettingsKey.hasOnboarded) {
                try? await Task.sleep(for: .milliseconds(200))
                for window in NSApp.windows where !desktop.owns(window) && window.isVisible && window.canBecomeMain {
                    window.close()
                }
            }
        }
    }

    /// Keep running in the menu bar so the desktop clock stays alive.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct DesktopMenu: View {
    @ObservedObject private var desktop = DesktopController.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open NOW Window") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Toggle("Show NOW on Desktop", isOn: $desktop.isOn)
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Divider()
        Button("Quit NOW") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
