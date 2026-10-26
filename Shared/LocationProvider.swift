import Foundation
import CoreLocation

/// Finds out roughly where the person is. Only a coarse position is needed
/// (the sky looks the same across a whole city), so we ask for reduced accuracy.
/// Without permission we fall back to a guess based on the time zone.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    private(set) var latitude: Double
    private(set) var longitude: Double
    /// Called whenever a new position arrives.
    var onChange: (@MainActor (Double, Double) -> Void)?

    private let manager = CLLocationManager()
    private let defaults = UserDefaults.standard

    override init() {
        let saved = UserDefaults.standard
        if saved.object(forKey: "lastLatitude") != nil {
            latitude = saved.double(forKey: "lastLatitude")
            longitude = saved.double(forKey: "lastLongitude")
        } else {
            // Rough guess: longitude from the UTC offset, a mid-latitude in the north.
            let offsetHours = Double(TimeZone.current.secondsFromGMT()) / 3600
            longitude = offsetHours * 15
            latitude = 48
        }
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        manager.distanceFilter = 5_000
    }

    /// Asks once if we haven't asked before, then keeps the position up to date.
    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            break
        default:
            manager.startUpdatingLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .notDetermined, .denied, .restricted: break
            default: self.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let lat = loc.coordinate.latitude, lng = loc.coordinate.longitude
        Task { @MainActor in
            self.latitude = lat
            self.longitude = lng
            self.defaults.set(lat, forKey: "lastLatitude")
            self.defaults.set(lng, forKey: "lastLongitude")
            self.onChange?(lat, lng)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep the last known or approximate position.
    }
}
