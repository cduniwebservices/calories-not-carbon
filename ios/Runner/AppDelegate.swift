import Flutter
import UIKit
import CoreLocation

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

    // Setup method channel for native location manager
    setupLocationMethodChannel()

    // Initialize native location manager
    LocationManager.shared.initialize()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Method Channel Setup

  private func setupLocationMethodChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }

    // Method channel for location commands
    locationChannel = FlutterMethodChannel(
      name: "com.caloriesnotcarbon/location",
      binaryMessenger: controller.binaryMessenger
    )

    locationChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }

    // Event channel for location updates
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

// MARK: - Location Stream Handler

class LocationStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var locationObserver: NSObjectProtocol?
  private var errorObserver: NSObjectProtocol?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events

    // Observe location updates from native manager
    locationObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name("LocationUpdate"),
      object: nil,
      queue: .main
    ) { notification in
      if let locationData = notification.userInfo {
        events(locationData)
      }
    }

    // Observe errors
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
