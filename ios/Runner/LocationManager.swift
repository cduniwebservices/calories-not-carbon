import Foundation
import CoreLocation
import Flutter

/// Native iOS Location Manager for reliable background tracking
/// This handles iOS-specific background location requirements that the Flutter geolocator package cannot fully address
@objc class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private var locationManager: CLLocationManager?
    private var eventSink: FlutterEventSink?
    private var isTracking = false
    private var lastLocation: CLLocation?

    // Background location indicator (blue bar) setting
    private var showsBackgroundLocationIndicator = true

    // Minimum distance filter for significant change monitoring (meters)
    private let significantChangeDistance: CLLocationDistance = 10

    // Minimum time interval between updates (seconds)
    private let minimumUpdateInterval: TimeInterval = 1.0
    private var lastUpdateTime: Date?

    private override init() {
        super.init()
    }

    /// Initialize the location manager
    @objc func initialize() -> Bool {
        guard locationManager == nil else { return true }

        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = significantChangeDistance
        locationManager?.activityType = .fitness
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.pausesLocationUpdatesAutomatically = false
        locationManager?.showsBackgroundLocationIndicator = showsBackgroundLocationIndicator

        return true
    }

    /// Request "Always" authorization for background tracking
    @objc func requestAlwaysAuthorization() -> Bool {
        guard let manager = locationManager else { return false }

        let status = CLLocationManager.authorizationStatus()

        switch status {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
            return true
        case .authorizedWhenInUse:
            // Request upgrade to Always
            manager.requestAlwaysAuthorization()
            return true
        case .authorizedAlways:
            return true
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Start location tracking with iOS-specific optimizations
    @objc func startTracking() -> Bool {
        guard let manager = locationManager else { return false }

        let status = CLLocationManager.authorizationStatus()
        guard status == .authorizedAlways else {
            print("❌ LocationManager: Cannot start - 'Always' authorization required for background tracking")
            return false
        }

        guard !isTracking else { return true }

        // Start standard location updates (for high accuracy)
        manager.startUpdatingLocation()

        // Also start significant location changes (for background reliability)
        manager.startMonitoringSignificantLocationChanges()

        isTracking = true
        print("✅ LocationManager: Started tracking with background support")
        return true
    }

    /// Stop location tracking
    @objc func stopTracking() {
        guard let manager = locationManager else { return }

        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        isTracking = false
        lastLocation = nil

        print("✅ LocationManager: Stopped tracking")
    }

    /// Check if location services are enabled
    @objc func isLocationServiceEnabled() -> Bool {
        return CLLocationManager.locationServicesEnabled()
    }

    /// Get current authorization status
    @objc func getAuthorizationStatus() -> String {
        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorizedAlways"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        @unknown default:
            return "unknown"
        }
    }

    /// Enable or disable background location indicator (blue bar)
    @objc func setShowsBackgroundLocationIndicator(_ enabled: Bool) {
        showsBackgroundLocationIndicator = enabled
        locationManager?.showsBackgroundLocationIndicator = enabled
    }

    /// Set minimum distance filter for updates
    @objc func setDistanceFilter(_ distance: CLLocationDistance) {
        locationManager?.distanceFilter = distance
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Throttle updates to prevent excessive battery drain
        let now = Date()
        if let lastTime = lastUpdateTime, now.timeIntervalSince(lastTime) < minimumUpdateInterval {
            return
        }
        lastUpdateTime = now

        lastLocation = location

        // Send location update to Flutter
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": location.altitude,
            "heading": location.course,
            "speed": location.speed,
            "timestamp": location.timestamp.iso8601String
        ]

        // Post notification for Flutter to pick up
        NotificationCenter.default.post(
            name: Notification.Name("LocationUpdate"),
            object: nil,
            userInfo: locationData
        )

        // Also send via method channel if available
        if let sink = eventSink {
            sink(locationData)
        }

        print("📍 LocationManager: Location update - Lat: \(location.coordinate.latitude), Lng: \(location.coordinate.longitude)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationManager: Error - \(error.localizedDescription)")

        // Send error to Flutter
        NotificationCenter.default.post(
            name: Notification.Name("LocationError"),
            object: nil,
            userInfo: ["error": error.localizedDescription]
        )
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔐 LocationManager: Authorization changed to \(getAuthorizationStatus())")

        // Send authorization change to Flutter
        NotificationCenter.default.post(
            name: Notification.Name("LocationAuthorizationChanged"),
            object: nil,
            userInfo: ["status": getAuthorizationStatus()]
        )
    }
}

// MARK: - Date Extension

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
