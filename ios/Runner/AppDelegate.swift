import Flutter
import UIKit
import CoreLocation
import CoreMotion

// MARK: - Location Manager
/// Native iOS Location Manager for reliable background tracking
@objc class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private var locationManager: CLLocationManager?
    private var eventSink: FlutterEventSink?
    private var isTracking = false
    private var lastLocation: CLLocation?

    private var showsBackgroundLocationIndicator = true
    private let trackingDistanceFilter: CLLocationDistance = 0
    private let minimumUpdateInterval: TimeInterval = 1.0
    private var lastUpdateTime: Date?
    
    // Data quality filtering
    private var lastValidLocation: CLLocation?
    private var validReadingCount = 0
    private let minValidReadingsBeforeAccept = 3
    private let maxAcceptableSpeedMps: CLLocationSpeed = 55.56 // 200 km/h max (covers cycling, running, any human activity)
    private let maxAcceptableHorizontalAccuracy: CLLocationAccuracy = 100.0 // meters
    private let maxAcceptableAltitudeChange: CLLocationDistance = 100.0 // meters per reading
    private let minAcceptableTimestampAge: TimeInterval = -5.0 // reject cached locations older than 5 seconds

    private override init() {
        super.init()
    }

    @objc func initialize() -> Bool {
        guard locationManager == nil else { return true }

        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = trackingDistanceFilter
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

        // Validate location quality
        guard isValidLocation(location) else {
            print("⚠️ LocationManager: Discarding invalid location - accuracy: \(location.horizontalAccuracy)m, speed: \(location.speed)m/s")
            return
        }

        lastLocation = location
        lastValidLocation = location
        validReadingCount += 1

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

        print("📍 LocationManager: Location update - Lat: \(location.coordinate.latitude), Lng: \(location.coordinate.longitude), Acc: \(location.horizontalAccuracy)m")
    }

    /// Validate location quality to filter out GPS glitches and cached data
    private func isValidLocation(_ location: CLLocation) -> Bool {
        // Check 1: Horizontal accuracy must be reasonable
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy <= maxAcceptableHorizontalAccuracy else {
            print("⚠️ LocationManager: Invalid accuracy - \(location.horizontalAccuracy)m")
            return false
        }

        // Check 2: Timestamp should not be stale (cached location)
        let timestampAge = location.timestamp.timeIntervalSinceNow
        guard timestampAge >= minAcceptableTimestampAge else {
            print("⚠️ LocationManager: Stale location - \(abs(timestampAge))s old")
            return false
        }

        // Check 3: Speed must be reasonable for human activity
        // -1.0 means speed is invalid/unknown, which is acceptable
        if location.speed >= 0 && location.speed > maxAcceptableSpeedMps {
            print("⚠️ LocationManager: Impossible speed - \(location.speed)m/s (\(location.speed * 3.6)km/h)")
            return false
        }

        // Check 4: Altitude change must be reasonable
        if let lastValid = lastValidLocation {
            let altitudeChange = abs(location.altitude - lastValid.altitude)
            let timeInterval = location.timestamp.timeIntervalSince(lastValid.timestamp)
            
            // Only check altitude change if readings are close in time (< 10 seconds)
            if timeInterval < 10 && altitudeChange > maxAcceptableAltitudeChange {
                print("⚠️ LocationManager: Extreme altitude change - \(altitudeChange)m in \(timeInterval)s")
                return false
            }
        }

        // Check 5: Need minimum valid readings before accepting (warm-up period)
        // This prevents initial GPS lock spikes
        if validReadingCount < minValidReadingsBeforeAccept {
            print("⚠️ LocationManager: Warming up - reading \(validReadingCount + 1)/\(minValidReadingsBeforeAccept)")
            // Still increment but don't reject entirely
            return true
        }

        return true
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

// MARK: - Barometer Manager

@objc class BarometerManager: NSObject, FlutterStreamHandler {
  static let shared = BarometerManager()
  private var altimeter: CMAltimeter?
  private var eventSink: FlutterEventSink?
  private var isStarted = false

  private override init() {
    super.init()
  }

  @objc func start() -> Bool {
    guard CMAltimeter.isRelativeAltitudeAvailable() else {
      print("⚠️ BarometerManager: Barometer not available on this device")
      return false
    }
    guard !isStarted else { return true }

    altimeter = CMAltimeter()
    altimeter?.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
      if let error = error {
        print("❌ BarometerManager: Error - \(error.localizedDescription)")
        return
      }
      guard let data = data else { return }
      // CMAltitudeData.pressure is in kPa, convert to hPa (1 kPa = 10 hPa)
      let pressureHpa = data.pressure.doubleValue * 10.0
      self?.eventSink?(pressureHpa)
    }
    isStarted = true
    print("✅ BarometerManager: Started")
    return true
  }

  @objc func stop() {
    altimeter?.stopRelativeAltitudeUpdates()
    altimeter = nil
    isStarted = false
    print("✅ BarometerManager: Stopped")
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    stop()
    return nil
  }
}

// MARK: - App Delegate

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var locationChannel: FlutterMethodChannel?
  private var locationEventChannel: FlutterEventChannel?
  private var locationStreamHandler: LocationStreamHandler?
  private var barometerChannel: FlutterMethodChannel?
  private var barometerEventChannel: FlutterEventChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    setupLocationMethodChannel()
    setupBarometerMethodChannel()
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

  private func setupBarometerMethodChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }

    barometerChannel = FlutterMethodChannel(
      name: "com.caloriesnotcarbon/barometer",
      binaryMessenger: controller.binaryMessenger
    )

    barometerChannel?.setMethodCallHandler { (call, result) in
      switch call.method {
      case "startBarometer":
        let started = BarometerManager.shared.start()
        result(started)
      case "stopBarometer":
        BarometerManager.shared.stop()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    barometerEventChannel = FlutterEventChannel(
      name: "com.caloriesnotcarbon/barometer_updates",
      binaryMessenger: controller.binaryMessenger
    )
    barometerEventChannel?.setStreamHandler(BarometerManager.shared)
  }
}
