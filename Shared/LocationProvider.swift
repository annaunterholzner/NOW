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
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        manager.distanceFilter = 5_000
    }

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
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .denied, .restricted, .notDetermined: break
            default: manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.latitude = loc.coordinate.latitude
            self.longitude = loc.coordinate.longitude
            self.isApproximate = false
            self.defaults.set(self.latitude, forKey: "lastLatitude")
            self.defaults.set(self.longitude, forKey: "lastLongitude")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep the last known / approximate position.
    }
}
