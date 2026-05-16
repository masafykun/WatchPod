import Foundation
import CoreLocation
import WeatherKit
import Combine

@MainActor
final class WeatherManager: NSObject, ObservableObject {
    @Published private(set) var locationName: String = "位置情報取得中…"
    @Published private(set) var currentTemp: String = "--°"
    @Published private(set) var currentHumidity: String = "--%"
    @Published private(set) var currentConditionSymbol: String = "questionmark"
    @Published private(set) var currentConditionLabel: String = "—"
    @Published private(set) var hourly: [HourlyEntry] = []
    @Published var errorMessage: String?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastUpdated: Date?

    struct HourlyEntry: Identifiable {
        let id = UUID()
        let date: Date
        let temp: String
        let humidity: String
        let symbol: String
    }

    private let locationManager = CLLocationManager()
    private let service = WeatherService.shared
    private var currentLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            errorMessage = "位置情報の使用が許可されていません"
        @unknown default:
            break
        }
    }

    func refresh() {
        guard let loc = currentLocation else {
            start()
            return
        }
        Task { await fetchWeather(for: loc) }
    }

    private func fetchWeather(for location: CLLocation) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let weather = try await service.weather(for: location)
            applyWeather(weather)
            await resolvePlacemark(location)
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = "天気取得エラー: \(error.localizedDescription)"
        }
    }

    private func applyWeather(_ weather: Weather) {
        let cur = weather.currentWeather
        let tempFormatter = MeasurementFormatter()
        tempFormatter.unitOptions = [.providedUnit]
        tempFormatter.numberFormatter.maximumFractionDigits = 0

        currentTemp = tempFormatter.string(from: cur.temperature.converted(to: .celsius))
        currentHumidity = String(format: "%.0f%%", cur.humidity * 100)
        currentConditionSymbol = cur.symbolName
        currentConditionLabel = cur.condition.description

        let now = Date()
        let hours = weather.hourlyForecast
            .filter { $0.date >= now }
            .prefix(12)
        hourly = hours.map { hour in
            HourlyEntry(
                date: hour.date,
                temp: tempFormatter.string(from: hour.temperature.converted(to: .celsius)),
                humidity: String(format: "%.0f%%", hour.humidity * 100),
                symbol: hour.symbolName
            )
        }
    }

    private func resolvePlacemark(_ location: CLLocation) async {
        let geocoder = CLGeocoder()
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            let parts = [placemark.locality, placemark.subLocality].compactMap { $0 }
            locationName = parts.isEmpty ? (placemark.name ?? "現在地") : parts.joined(separator: " ")
        }
    }
}

extension WeatherManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.errorMessage = "位置情報の使用が許可されていません"
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = loc
            await self.fetchWeather(for: loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = "位置情報エラー: \(error.localizedDescription)"
        }
    }
}
