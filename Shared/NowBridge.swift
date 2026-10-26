import Foundation
import WebKit
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// How a scene is shown: in the app's own window, or as the Mac desktop background.
enum NowMode: String {
    case window, wallpaper
}

/// Connects the native app to the scene page (`preview/index.html`, bundled as `index.html`).
///
/// The page draws everything: the moving body, the sky, the ink clock and its Settings card.
/// The app adds what a web page can't do on its own: the real location, settings shared between
/// the window and every desktop screen, desktop mode, open at login and keeping the screen on.
@MainActor
final class NowBridge: NSObject, WKScriptMessageHandler {
    static let shared = NowBridge()

    private final class Entry {
        weak var view: WKWebView?
        let mode: NowMode
        var ready = false
        init(view: WKWebView, mode: NowMode) { self.view = view; self.mode = mode }
    }

    private var entries: [Entry] = []
    private var pendingOpenSettings = false
    private let settings = NowSettings.shared
    private let location = LocationProvider.shared

    private override init() {
        super.init()
        location.onChange = { [weak self] lat, lng in
            self?.run("window.NOW && NOW.setLocation(\(lat), \(lng))")
        }
    }

    // MARK: - Making scene views

    func makeWebView(mode: NowMode) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "now")
        config.userContentController.addUserScript(
            WKUserScript(source: bootScript(mode: mode), injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let web = WKWebView(frame: .zero, configuration: config)
        #if os(iOS)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        #endif

        entries.removeAll { $0.view == nil }
        entries.append(Entry(view: web, mode: mode))
        loadScene(into: web)
        return web
    }

    /// The page is written without <html>/<head>, so wrap it the way a browser preview does.
    private func loadScene(into web: WKWebView) {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html"),
              let body = try? String(contentsOf: url, encoding: .utf8) else { return }
        let page = """
        <!doctype html>
        <html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
        <style>html, body { margin: 0; height: 100%; } body { -webkit-user-select: none; user-select: none; -webkit-touch-callout: none; }</style>
        </head><body>
        \(body)
        </body></html>
        """
        web.loadHTMLString(page, baseURL: url.deletingLastPathComponent())
    }

    /// Everything the page needs to know before its own script runs.
    private func bootScript(mode: NowMode) -> String {
        #if os(iOS)
        let platform = "ios"
        let extra: [String: Any] = [:]
        #else
        let platform = "mac"
        let extra: [String: Any] = [
            "desktop": DesktopController.shared.isOn,
            "openAtLogin": DesktopController.shared.openAtLogin,
        ]
        #endif
        let fps = mode == .wallpaper ? 24 : 0
        let place = NowSettings.json(["lat": location.latitude, "lng": location.longitude])
        return "window.NOW_APP = { platform: \"\(platform)\", mode: \"\(mode.rawValue)\", fps: \(fps), "
            + "settings: \(settings.json(adding: extra)), location: \(place) };"
    }

    // MARK: - Messages from the page

    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            self.handle(type: type, body: body, from: message.webView)
        }
    }

    private func handle(type: String, body: [String: Any], from source: WKWebView?) {
        switch type {
        case "ready":
            guard let entry = entries.first(where: { $0.view === source }) else { return }
            entry.ready = true
            if pendingOpenSettings && entry.mode == .window {
                pendingOpenSettings = false
                source?.evaluateJavaScript("window.NOW && NOW.openSettings()", completionHandler: nil)
            }
        case "set":
            guard let key = body["key"] as? String, let value = body["value"] else { return }
            settings.set(key, value)
            broadcast([key: value], except: source)
            #if os(iOS)
            if key == "keepAwake" { applyKeepAwake() }
            #endif
        case "desktop":
            #if os(macOS)
            DesktopController.shared.setOn((body["on"] as? Bool) ?? false)
            #endif
        case "openAtLogin":
            #if os(macOS)
            DesktopController.shared.setOpenAtLogin((body["on"] as? Bool) ?? false)
            #endif
        default:
            break
        }
    }

    // MARK: - Talking to the page

    /// Tell every open scene (except the one that made the change) about new settings.
    func broadcast(_ values: [String: Any], except source: WKWebView? = nil) {
        let js = "window.NOW && NOW.apply(\(NowSettings.json(values)))"
        for entry in entries {
            if let view = entry.view, view !== source { view.evaluateJavaScript(js, completionHandler: nil) }
        }
    }

    private func run(_ js: String) {
        for entry in entries { entry.view?.evaluateJavaScript(js, completionHandler: nil) }
    }

    /// Open the Settings card in the app window. If the window is still loading, do it once it's ready.
    func openSettings() {
        if let entry = entries.last(where: { $0.mode == .window && $0.view?.window != nil && $0.ready }) {
            entry.view?.evaluateJavaScript("window.NOW && NOW.openSettings()", completionHandler: nil)
        } else {
            pendingOpenSettings = true
        }
    }

    #if os(iOS)
    func applyKeepAwake() {
        UIApplication.shared.isIdleTimerDisabled = settings.bool("keepAwake", default: true)
    }
    #endif
}

#if os(iOS)
/// The scene as a SwiftUI view.
struct NowWebView: UIViewRepresentable {
    var mode: NowMode = .window
    func makeUIView(context: Context) -> WKWebView { NowBridge.shared.makeWebView(mode: mode) }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#else
/// The scene as a SwiftUI view.
struct NowWebView: NSViewRepresentable {
    var mode: NowMode = .window
    func makeNSView(context: Context) -> WKWebView { NowBridge.shared.makeWebView(mode: mode) }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif
