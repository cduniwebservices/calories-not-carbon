import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'location_service.dart';

/// iOS-specific location service using native platform channels
/// This provides reliable background tracking on iOS that the standard
/// geolocator package cannot fully achieve
///
/// On Android, this delegates to the standard LocationService
class IOSLocationService {
  static final IOSLocationService _instance = IOSLocationService._internal();
  factory IOSLocationService() => _instance;
  IOSLocationService._internal();

  // Platform channels for native iOS communication
  static const MethodChannel _methodChannel = MethodChannel(
    'com.caloriesnotcarbon/location',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.caloriesnotcarbon/location_updates',
  );

  // Stream controllers
  final StreamController<LocationData> _locationController =
      StreamController<LocationData>.broadcast();
  StreamSubscription? _eventSubscription;

  // State tracking
  bool _isInitialized = false;
  bool _isTracking = false;
  LocationData? _currentLocation;

  /// Check if running on iOS
  bool get isIOS => Platform.isIOS;

  /// Get the location stream
  Stream<LocationData> get locationStream => _locationController.stream;

  /// Get current location
  LocationData? get currentLocation => _currentLocation;

  /// Initialize the service
  Future<bool> initialize() async {
    if (!isIOS) return false;
    if (_isInitialized) return true;

    try {
      debugPrint('🍎 IOSLocationService: Initializing native iOS location service...');

      final success = await _methodChannel.invokeMethod<bool>('initialize') ?? false;

      if (success) {
        _isInitialized = true;
        debugPrint('✅ IOSLocationService: Native iOS location service initialized');
      } else {
        debugPrint('❌ IOSLocationService: Failed to initialize native service');
      }

      return success;
    } catch (e) {
      debugPrint('❌ IOSLocationService: Initialization error: $e');
      return false;
    }
  }

  /// Request "Always" authorization (required for background tracking on iOS)
  Future<bool> requestAlwaysAuthorization() async {
    if (!isIOS) return false;

    try {
      debugPrint('🔐 IOSLocationService: Requesting Always authorization...');
      final success = await _methodChannel.invokeMethod<bool>('requestAlwaysAuthorization') ?? false;
      debugPrint('✅ IOSLocationService: Always authorization request completed');
      return success;
    } catch (e) {
      debugPrint('❌ IOSLocationService: Authorization request error: $e');
      return false;
    }
  }

  /// Start location tracking with background support
  Future<bool> startTracking() async {
    if (!isIOS) return false;
    if (_isTracking) return true;

    try {
      debugPrint('📍 IOSLocationService: Starting iOS native tracking...');

      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      // Check authorization status
      final status = await getAuthorizationStatus();
      if (status != 'authorizedAlways') {
        debugPrint('⚠️ IOSLocationService: Background tracking requires "Always" authorization. Current: $status');
        // Still try to start - native side will handle it
      }

      // Start listening to location updates from native side
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _onLocationUpdate,
        onError: _onLocationError,
        cancelOnError: false,
      );

      // Start native tracking
      final success = await _methodChannel.invokeMethod<bool>('startTracking') ?? false;

      if (success) {
        _isTracking = true;
        debugPrint('✅ IOSLocationService: iOS native tracking started');
      } else {
        debugPrint('❌ IOSLocationService: Failed to start native tracking');
        await _eventSubscription?.cancel();
        _eventSubscription = null;
      }

      return success;
    } catch (e) {
      debugPrint('❌ IOSLocationService: Start tracking error: $e');
      return false;
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    if (!isIOS) return;

    try {
      debugPrint('🛑 IOSLocationService: Stopping iOS native tracking...');

      await _eventSubscription?.cancel();
      _eventSubscription = null;

      await _methodChannel.invokeMethod('stopTracking');
      _isTracking = false;

      debugPrint('✅ IOSLocationService: iOS native tracking stopped');
    } catch (e) {
      debugPrint('❌ IOSLocationService: Stop tracking error: $e');
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    if (!isIOS) return false;

    try {
      return await _methodChannel.invokeMethod<bool>('isLocationServiceEnabled') ?? false;
    } catch (e) {
      debugPrint('❌ IOSLocationService: Error checking service status: $e');
      return false;
    }
  }

  /// Get current authorization status
  /// Returns: notDetermined, restricted, denied, authorizedAlways, authorizedWhenInUse
  Future<String> getAuthorizationStatus() async {
    if (!isIOS) return 'unknown';

    try {
      return await _methodChannel.invokeMethod<String>('getAuthorizationStatus') ?? 'unknown';
    } catch (e) {
      debugPrint('❌ IOSLocationService: Error getting authorization status: $e');
      return 'unknown';
    }
  }

  /// Enable/disable background location indicator (blue bar)
  /// This shows users that the app is using location in background
  Future<void> setShowsBackgroundLocationIndicator(bool enabled) async {
    if (!isIOS) return;

    try {
      await _methodChannel.invokeMethod('setShowsBackgroundLocationIndicator', enabled);
      debugPrint('✅ IOSLocationService: Background location indicator set to $enabled');
    } catch (e) {
      debugPrint('❌ IOSLocationService: Error setting background indicator: $e');
    }
  }

  /// Set minimum distance filter for location updates (in meters)
  Future<void> setDistanceFilter(double distance) async {
    if (!isIOS) return;

    try {
      await _methodChannel.invokeMethod('setDistanceFilter', distance);
      debugPrint('✅ IOSLocationService: Distance filter set to ${distance}m');
    } catch (e) {
      debugPrint('❌ IOSLocationService: Error setting distance filter: $e');
    }
  }

  /// Check if tracking is active
  bool get isTracking => _isTracking;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  // Private methods

  void _onLocationUpdate(dynamic data) {
    if (data is! Map) return;

    try {
      final locationData = LocationData(
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        accuracy: (data['accuracy'] as num).toDouble(),
        altitude: data['altitude'] != null ? (data['altitude'] as num).toDouble() : null,
        heading: data['heading'] != null ? (data['heading'] as num).toDouble() : null,
        speed: data['speed'] != null ? (data['speed'] as num).toDouble() : null,
        timestamp: DateTime.parse(data['timestamp'] as String),
      );

      _currentLocation = locationData;
      _locationController.add(locationData);

      debugPrint(
        '📍 IOSLocationService: Location update - '
        'Lat: ${locationData.latitude.toStringAsFixed(6)}, '
        'Lng: ${locationData.longitude.toStringAsFixed(6)}, '
        'Acc: ${locationData.accuracy.toStringAsFixed(1)}m',
      );
    } catch (e) {
      debugPrint('❌ IOSLocationService: Error parsing location data: $e');
    }
  }

  void _onLocationError(dynamic error) {
    debugPrint('❌ IOSLocationService: Location error: $error');
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _locationController.close();
  }
}

/// Extension to convert iOS authorization status to our enum
extension IOSAuthorizationStatusExtension on String {
  LocationPermissionStatus toLocationPermissionStatus() {
    switch (this) {
      case 'notDetermined':
        return LocationPermissionStatus.unknown;
      case 'restricted':
        return LocationPermissionStatus.deniedForever;
      case 'denied':
        return LocationPermissionStatus.denied;
      case 'authorizedAlways':
        return LocationPermissionStatus.always;
      case 'authorizedWhenInUse':
        return LocationPermissionStatus.whileInUse;
      default:
        return LocationPermissionStatus.unknown;
    }
  }
}
