import Foundation

/// The person's choices (scene, clock size, second hand, …), kept by the app so that
/// the window and every desktop screen share them. Stored as one small JSON object,
/// exactly as the scene page reads and writes it.
@MainActor
final class NowSettings {
    static let shared = NowSettings()

    private let storageKey = "nowSettings"
    private(set) var values: [String: Any] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            values = dict
        }
    }

    func bool(_ key: String, default fallback: Bool) -> Bool {
        (values[key] as? Bool) ?? fallback
    }

    func set(_ key: String, _ value: Any) {
        values[key] = value
        if let data = try? JSONSerialization.data(withJSONObject: values) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// All settings as a JSON object literal, with optional extra values mixed in.
    func json(adding extra: [String: Any] = [:]) -> String {
        let merged = values.merging(extra) { _, new in new }
        guard JSONSerialization.isValidJSONObject(merged),
              let data = try? JSONSerialization.data(withJSONObject: merged),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    static func json(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}
