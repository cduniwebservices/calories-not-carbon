import Flutter
import UIKit
import CoreLocation

// MARK: - Location Manager
/// Native iOS Location Manager for reliable background tracking
@objc class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private var locationManager: CLLocationManager?
    private var eventSink: FlutterEventSink?
    private var isTracking = false
    private var lastLocation: CLLocation?

    private var showsBackgroundLocationIndicator = true
    private let significantChangeDistance: CLLocationDistance = 10
    private let minimumUpdateInterval: TimeInterval = 1.0
    private var lastUpdateTime: Date?

    private override init() {
        super.init()
    }

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

    @objc func requestAlwaysAuthorization() -> Bool {
        guard let manager = locationManager else { return false }

        let status = CLLocationManager.authorizationStatus()

        switch status {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
            return true
        case .authorizedWhenInUse:
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

    @objc func startTracking() -> Bool {
        guard let manager = locationManager else { return false }

        let status = CLLocationManager.authorizationStatus()
        guard status == .authorizedAlways else {
            print("❌ LocationManager: Cannot start - 'Always' authorization required for background tracking")
            return false
        }

        guard !isTracking else { return true }

        manager.startUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()

        isTracking = true
        print("✅ LocationManager: Started tracking with background support")
        return true
    }

    @objc func stopTracking() {
        guard let manager = locationManager else { return }

        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        isTracking = false
        lastLocation = nil

        print("✅ LocationManager: Stopped tracking")
    }

    @objc func isLocationServiceEnabled() -> Bool {
        return CLLocationManager.locationServicesEnabled()
    }

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

    @objc func setShowsBackgroundLocationIndicator(_ enabled: Bool) {
        showsBackgroundLocationIndicator = enabled
        locationManager?.showsBackgroundLocationIndicator = enabled
    }

    @objc func setDistanceFilter(_ distance: CLLocationDistance) {
        locationManager?.distanceFilter = distance
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let now = Date()
        if let lastTime = lastUpdateTime, now.timeIntervalSince(lastTime) < minimumUpdateInterval {
            return
        }
        lastUpdateTime = now

        lastLocation = location

        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": location.altitude,
            "heading": location.course,
            "speed": location.speed,
            "timestamp": location.timestamp.iso8601String
        ]

        NotificationCenter.default.post(
            name: Notification.Name("LocationUpdate"),
            object: nil,
            userInfo: locationData
        )

        if let sink = eventSink {
            sink(locationData)
        }

        print("📍 LocationManager: Location update - Lat: \(location.coordinate.latitude), Lng: \(location.coordinate.longitude)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationManager: Error - \(error.localizedDescription)")

        NotificationCenter.default.post(
            name: Notification.Name("LocationError"),
            object: nil,
            userInfo: ["error": error.localizedDescription]
        )
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔐 LocationManager: Authorization changed to \(getAuthorizationStatus())")

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

// MARK: - Location Stream Handler

class LocationStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var locationObserver: NSObjectProtocol?
    private var errorObserver: NSObjectProtocol?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        locationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("LocationUpdate"),
            object: nil,
            queue: .main
        ) { notification in
            if let locationData = notification.userInfo {
                events(locationData)
            }
        }

        errorObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("LocationError"),
            object: nil,
            queue: .main
        ) { notification in
            if let errorData = notification.userInfo {
                events(FlutterError(code: "LOCATION_ERROR", message: errorData["error"] as? String, details: nil))
            }
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil

        if let observer = locationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = errorObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        return nil
    }
}

// MARK: - App Delegate

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var locationChannel: FlutterMethodChannel?
    private var locationEventChannel: FlutterEventChannel?
    private var locationStreamHandler: LocationStreamHandler?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        setupLocationMethodChannel()
        LocationManager.shared.initialize()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupLocationMethodChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else { return }

        locationChannel = FlutterMethodChannel(
            name: "com.caloriesnotcarbon/location",
            binaryMessenger: controller.binaryMessenger
        )

        locationChannel?.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }

        locationEventChannel = FlutterEventChannel(
            name: "com.caloriesnotcarbon/location_updates",
            binaryMessenger: controller.binaryMessenger
        )

        locationStreamHandler = LocationStreamHandler()
        locationEventChannel?.setStreamHandler(locationStreamHandler)
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            let success = LocationManager.shared.initialize()
            result(success)

        case "requestAlwaysAuthorization":
            let success = LocationManager.shared.requestAlwaysAuthorization()
            result(success)

        case "startTracking":
            let success = LocationManager.shared.startTracking()
            result(success)

        case "stopTracking":
            LocationManager.shared.stopTracking()
            result(true)

        case "isLocationServiceEnabled":
            let enabled = LocationManager.shared.isLocationServiceEnabled()
            result(enabled)

        case "getAuthorizationStatus":
            let status = LocationManager.shared.getAuthorizationStatus()
            result(status)

        case "setShowsBackgroundLocationIndicator":
            if let enabled = call.arguments as? Bool {
                LocationManager.shared.setShowsBackgroundLocationIndicator(enabled)
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected boolean", details: nil))
            }

        case "setDistanceFilter":
            if let distance = call.arguments as? Double {
                LocationManager.shared.setDistanceFilter(distance)
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected double", details: nil))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
