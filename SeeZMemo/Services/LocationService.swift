import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    var coordinate: CLLocationCoordinate2D?
    var address = ""
    var country = ""
    var errorMessage: String?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "定位權限未開啟，可手動輸入地址。"
        @unknown default:
            errorMessage = "目前無法取得定位。"
        }
    }

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async {
        self.coordinate = coordinate
        do {
            let marks = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), preferredLocale: Locale(identifier: "zh_Hant_TW"))
            let source = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if let mark = marks.min(by: {
                ($0.location?.distance(from: source) ?? .greatestFiniteMagnitude) <
                ($1.location?.distance(from: source) ?? .greatestFiniteMagnitude)
            }) {
                address = formattedAddress(from: mark)
                country = mark.country?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
        } catch {
            errorMessage = "地址反查失敗，仍可保留座標或手動輸入。"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { await reverseGeocode(location.coordinate) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "定位失敗，可稍後重試或手動輸入地址。"
    }

    private func formattedAddress(from mark: CLPlacemark) -> String {
        let street = [mark.thoroughfare, mark.subThoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined()
        return [mark.administrativeArea, mark.locality, mark.subLocality, street]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { values, value in
                if !values.contains(value) { values.append(value) }
            }
            .joined()
    }
}
