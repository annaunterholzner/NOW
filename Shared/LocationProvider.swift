import Foundation
import CoreLocation

/// Finds out roughly where the person is. Only a coarse position is needed
/// (the sky looks the same across a whole city), so we ask for reduced accuracy.
/// Without permission we fall back to a guess based on the time zone.
@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    @Published private(set) var latitude: Double
    @Published private(set) var longitude: Double
    @Published private(set) var isApproximate = true
    @Published private(set) var status: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private let defaults = UserDefaults.standard

    override init() {
        if defaults.object(forKey: "lastLatitude") != nil {
            latitude = defaults.double(forKey: "lastLatitude")
            longitude = defaults.double(forKey: "lastLongitude")
        } else {
            // Rough guess: longitude from the UTC offset, a mid-latitude in the north.
            let offsetHours = Double(TimeZone.current.secondsFromGMT()) / 3600
            longitude = offsetHours * 15
            latitude = 48
        }
        status = .notDetermined
        super.init()
        status = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        manager.distanceFilter = 5_000
    }

    var isAllowed: Bool {
        switch status {
        case .notDetermined, .denied, .restricted: false
        default: true
        }
    }

    /// Starts updates if permission was already given. Never shows a prompt by itself.
    func start() {
        if isAllowed { manager.startUpdatingLocation() }
    }

    /// Shows the system prompt (used on the welcome screen and in Settings).
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in
            self.status = newStatus
            self.start()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let lat = loc.coordinate.latitude, lng = loc.coordinate.longitude
        Task { @MainActor in
            self.latitude = lat
            self.longitude = lng
            self.isApproximate = false
            self.defaults.set(lat, forKey: "lastLatitude")
            self.defaults.set(lng, forKey: "lastLongitude")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep the last known / approximate position.
    }
}
