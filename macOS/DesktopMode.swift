import AppKit
import SwiftUI
import ServiceManagement

/// Puts NOW behind your desktop icons, like a living wallpaper, on every screen and every Space.
/// Also owns "Open at login".
@MainActor
final class DesktopController: ObservableObject {
    static let shared = DesktopController()

    @Published private(set) var isOn: Bool
    @Published private(set) var openAtLogin: Bool

    private var windows: [NSWindow] = []
    private var screenObserver: NSObjectProtocol?

    private init() {
        isOn = NowSettings.shared.bool("desktop", default: false)
        openAtLogin = SMAppService.mainApp.status == .enabled
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                let desktop = DesktopController.shared
                if desktop.isOn { desktop.show() }   // rebuild for new or resized displays
            }
        }
    }

    func setOn(_ on: Bool) {
        isOn = on
        NowSettings.shared.set("desktop", on)
        if on { show() } else { hide() }
        NowBridge.shared.broadcast(["desktop": on])
    }

    func setOpenAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            // macOS may ask for approval in System Settings › General › Login Items.
        }
        openAtLogin = SMAppService.mainApp.status == .enabled
        NowSettings.shared.set("openAtLogin", openAtLogin)
        NowBridge.shared.broadcast(["openAtLogin": openAtLogin])
    }

    func show() {
        hide()
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: false)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = true
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.contentView = NowBridge.shared.makeWebView(mode: .wallpaper)
            window.orderFront(nil)
            windows.append(window)
        }
    }

    func owns(_ window: NSWindow) -> Bool { windows.contains(window) }

    func hide() {
        windows.forEach { $0.orderOut(nil); $0.contentView = nil }
        windows.removeAll()
    }
}

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            LocationProvider.shared.start()
            let desktop = DesktopController.shared
            guard desktop.isOn else { return }
            desktop.show()
            // Running as a background: once set up, start quietly without opening the window.
            if NowSettings.shared.bool("onboarded", default: false) {
                try? await Task.sleep(for: .milliseconds(300))
                for window in NSApp.windows where !desktop.owns(window) && window.isVisible && window.canBecomeMain {
                    window.close()
                }
            }
        }
    }

    /// Keep running in the menu bar so the desktop clock stays alive.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// The clock icon in the menu bar.
struct DesktopMenu: View {
    @ObservedObject private var desktop = DesktopController.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open NOW Window") { showWindow() }
        Button("Settings…") {
            showWindow()
            NowBridge.shared.openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Toggle("Show NOW on Desktop", isOn: Binding(get: { desktop.isOn }, set: { desktop.setOn($0) }))
        Toggle("Open at Login", isOn: Binding(get: { desktop.openAtLogin }, set: { desktop.setOpenAtLogin($0) }))
        Divider()
        Button("Quit NOW") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func showWindow() {
        openWindow(id: "main")
        NSApp.activate()
    }
}
