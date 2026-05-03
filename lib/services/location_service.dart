import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'background_location_service.dart';
import 'geoid_service.dart';
import 'ios_location_service.dart';

/// Enterprise-level location service for million-dollar app quality
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Geoid service for altitude conversion
  final GeoidService _geoidService = GeoidService();

  // Stream controllers for real-time location updates
  final StreamController<LocationData> _locationController =
      StreamController<LocationData>.broadcast();
  final StreamController<LocationPermissionStatus> _permissionController =
      StreamController<LocationPermissionStatus>.broadcast();
  final StreamController<LocationServiceStatus> _serviceController =
      StreamController<LocationServiceStatus>.broadcast();
  final StreamController<double> _barometerController =
      StreamController<double>.broadcast();

  // Barometer platform channel
  static const MethodChannel _barometerMethodChannel =
      MethodChannel('com.caloriesnotcarbon/barometer');
  static const EventChannel _barometerEventChannel =
      EventChannel('com.caloriesnotcarbon/barometer_updates');
  StreamSubscription? _barometerEventSubscription;
  bool _barometerStarted = false;

  // Getters for streams
  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<LocationPermissionStatus> get permissionStream =>
      _permissionController.stream;
  Stream<LocationServiceStatus> get serviceStream => _serviceController.stream;
  Stream<double> get barometerStream => _barometerController.stream;

  // Background location service
  final BackgroundLocationService _backgroundService = BackgroundLocationService();
  StreamSubscription? _backgroundLocationSubscription;

  // Current state tracking
  LocationData? _currentLocation;
  LocationPermissionStatus _permissionStatus = LocationPermissionStatus.unknown;
  LocationServiceStatus _serviceStatus = LocationServiceStatus.unknown;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<LocationData>? _iosLocationSubscription;
  Timer? _permissionCheckTimer;

  bool _isInitialized = false;
  bool _isTracking = false;

  /// Check if running on iOS
  bool get _isIOS => Platform.isIOS;

  // iOS-specific native location service
  final IOSLocationService _iosLocationService = IOSLocationService();

  /// Initialize the location service with enterprise-level error handling
  /// Uses iOS native LocationManager on iOS for reliable background tracking
  /// Uses standard Geolocator + foreground task on Android
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint(
        '🌍 LocationService: Initializing enterprise location service...',
      );

      // Initialize geoid service
      await _geoidService.initialize();

      // Initialize iOS native service if on iOS
      if (_isIOS) {
        debugPrint('🍎 LocationService: Initializing iOS native location service...');
        await _iosLocationService.initialize();
        // Enable background location indicator (blue bar) for user transparency
        await _iosLocationService.setShowsBackgroundLocationIndicator(true);
        // Set distance filter to 0 so we receive updates even when stationary
        // This is critical for detecting stationary time on iOS
        await _iosLocationService.setDistanceFilter(0.0);
      } else {
        // Initialize background service for Android
        await _backgroundService.initialize();
      }

      // Initial permission and service checks
      await _updatePermissionStatus();
      await _updateServiceStatus();

      // Start monitoring permission changes
      _startPermissionMonitoring();

      _isInitialized = true;
      debugPrint('✅ LocationService: Successfully initialized');
    } catch (e) {
      debugPrint('❌ LocationService: Initialization failed: $e');
      rethrow;
    }
  }

  /// Request location permissions with enterprise UX flow
  Future<LocationPermissionStatus> requestPermission() async {
    try {
      debugPrint('🔐 LocationService: Requesting location permissions...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _permissionStatus = LocationPermissionStatus.serviceDisabled;
        _permissionController.add(_permissionStatus);
        return _permissionStatus;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Update status based on permission result
      switch (permission) {
        case LocationPermission.whileInUse:
          _permissionStatus = LocationPermissionStatus.whileInUse;
          break;
        case LocationPermission.always:
          _permissionStatus = LocationPermissionStatus.always;
          break;
        case LocationPermission.denied:
          _permissionStatus = LocationPermissionStatus.denied;
          break;
        case LocationPermission.deniedForever:
          _permissionStatus = LocationPermissionStatus.deniedForever;
          break;
        case LocationPermission.unableToDetermine:
          _permissionStatus = LocationPermissionStatus.unknown;
          break;
      }

      _permissionController.add(_permissionStatus);
      debugPrint('✅ LocationService: Permission status: $_permissionStatus');

      return _permissionStatus;
    } catch (e) {
      debugPrint('❌ LocationService: Permission request failed: $e');
      _permissionStatus = LocationPermissionStatus.unknown;
      _permissionController.add(_permissionStatus);
      return _permissionStatus;
    }
  }

  /// Start location tracking with enterprise-level accuracy
  /// iOS: Uses native iOS LocationManager for reliable background tracking
  /// Android: Uses Geolocator with foreground task
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    try {
      debugPrint('📍 LocationService: Starting location tracking...');

      // Ensure permissions are granted
      final permissionStatus = await requestPermission();
      if (permissionStatus != LocationPermissionStatus.whileInUse &&
          permissionStatus != LocationPermissionStatus.always) {
        debugPrint('❌ LocationService: Insufficient permissions for tracking');
        return false;
      }

      if (_isIOS) {
        // iOS: Use native location service for reliable background tracking
        debugPrint('🍎 LocationService: Starting iOS native tracking...');

        // Check for "Always" authorization (required for iOS background)
        final iosStatus = await _iosLocationService.getAuthorizationStatus();
        if (iosStatus != 'authorizedAlways') {
          debugPrint('⚠️ LocationService: iOS "Always" authorization recommended for background tracking. Current: $iosStatus');
          // Try to request it
          await _iosLocationService.requestAlwaysAuthorization();
        }

        // Listen to iOS native location stream
        _iosLocationSubscription = _iosLocationService.locationStream.listen(
          (locationData) {
            _currentLocation = locationData;
            _locationController.add(locationData);
            debugPrint('📡 LocationService: iOS native location update - ${locationData.latitude}, ${locationData.longitude}');
          },
          onError: (error) {
            debugPrint('❌ LocationService: iOS native location error: $error');
          },
        );

        // Start iOS native tracking
        final started = await _iosLocationService.startTracking();
        if (!started) {
          debugPrint('❌ LocationService: Failed to start iOS native tracking');
          return false;
        }

        debugPrint('✅ LocationService: iOS native tracking started successfully');
      } else {
        // Android: Use standard Geolocator + foreground task
        debugPrint('🤖 LocationService: Starting Android tracking...');

        // Start background foreground task for continuous tracking
        // This keeps GPS active when app is in background or screen is off
        try {
          final backgroundStarted = await _backgroundService.startTracking();
          if (!backgroundStarted) {
            debugPrint('⚠️ LocationService: Background service could not start. Tracking will only work while app is open.');
          } else {
            debugPrint('✅ LocationService: Background service started successfully.');
          }
        } catch (e) {
          debugPrint('⚠️ LocationService: Error starting background service: $e');
        }

        // Start foreground position stream (keeps working regardless of background service status)
        _positionSubscription = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0, // Receive all updates for high accuracy
          ),
        ).listen(
          (position) {
            debugPrint('📡 LocationService: RAW GPS update received: ${position.latitude}, ${position.longitude} (Acc: ${position.accuracy}m)');
            _onLocationUpdate(position);
          },
          onError: _onLocationError,
          cancelOnError: false,
        );

        // Get initial position
        try {
          final Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
          );
          _onLocationUpdate(position);
        } catch (e) {
          debugPrint('⚠️ LocationService: Failed to get initial position: $e');
        }
      }

    _isTracking = true;
    _startBarometer();
    debugPrint('✅ LocationService: Location tracking started successfully');
    return true;
    } catch (e) {
      debugPrint('❌ LocationService: Failed to start tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    try {
      debugPrint('🛑 LocationService: Stopping location tracking...');

      if (_isIOS) {
        // iOS: Stop native iOS location tracking
        await _iosLocationSubscription?.cancel();
        _iosLocationSubscription = null;
        await _iosLocationService.stopTracking();
      } else {
        // Android: Stop standard Geolocator tracking
        // Stop foreground stream
        await _positionSubscription?.cancel();
        _positionSubscription = null;

        // Stop background service
        await _backgroundService.stopTracking();
      }

    _isTracking = false;
    _stopBarometer();
    debugPrint('✅ LocationService: Location tracking stopped');
  } catch (e) {
    debugPrint('❌ LocationService: Error stopping tracking: $e');
  }
  }

  void _startBarometer() {
    if (_barometerStarted) return;
    try {
      _barometerMethodChannel.invokeMethod<bool>('startBarometer').then((started) {
        if (started == true) {
          _barometerEventSubscription = _barometerEventChannel.receiveBroadcastStream().listen(
            (pressure) {
              if (pressure is double) {
                _barometerController.add(pressure);
              } else if (pressure is num) {
                _barometerController.add(pressure.toDouble());
              }
            },
            onError: (error) {
              debugPrint('⚠️ LocationService: Barometer stream error: $error');
            },
            cancelOnError: false,
          );
          _barometerStarted = true;
          debugPrint('✅ LocationService: Barometer tracking started');
        } else {
          debugPrint('⚠️ LocationService: Barometer not available on this device');
        }
      }).catchError((e) {
        debugPrint('⚠️ LocationService: Barometer not available: $e');
      });
    } catch (e) {
      debugPrint('⚠️ LocationService: Could not start barometer: $e');
    }
  }

  void _stopBarometer() {
    if (!_barometerStarted) return;
    try {
      _barometerEventSubscription?.cancel();
      _barometerEventSubscription = null;
      _barometerMethodChannel.invokeMethod('stopBarometer');
      _barometerStarted = false;
      debugPrint('✅ LocationService: Barometer tracking stopped');
    } catch (e) {
      debugPrint('⚠️ LocationService: Error stopping barometer: $e');
    }
  }

  /// Get current location with caching
  Future<LocationData?> getCurrentLocation() async {
    try {
      if (_currentLocation != null && _isLocationRecent()) {
        return _currentLocation;
      }

      final permissionStatus = await requestPermission();
      if (permissionStatus != LocationPermissionStatus.whileInUse &&
          permissionStatus != LocationPermissionStatus.always) {
        return null;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final locationData = LocationData.fromPosition(position);
      _currentLocation = locationData;
      _locationController.add(locationData);

      return locationData;
    } catch (e) {
      debugPrint('❌ LocationService: Failed to get current location: $e');
      return null;
    }
  }

  /// Calculate distance between two points
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Calculate bearing between two points
  double calculateBearing(LatLng point1, LatLng point2) {
    return Geolocator.bearingBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Open app settings for permission management
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Dispose resources
  void dispose() {
    debugPrint('🧹 LocationService: Disposing resources...');

  _positionSubscription?.cancel();
  _iosLocationSubscription?.cancel();
  _permissionCheckTimer?.cancel();
  _barometerEventSubscription?.cancel();
  _locationController.close();
  _permissionController.close();
  _serviceController.close();
  _barometerController.close();

    // Dispose iOS location service
    _iosLocationService.dispose();

    _isInitialized = false;
    _isTracking = false;
  }

  // Private methods

  // Data quality filtering (applies to all platforms)
  LocationData? _lastValidLocation;
  int _consecutiveValidReadings = 0;
  static const int _minValidReadings = 3;
  static const double _maxAcceptableSpeedMps = 55.56; // 200 km/h
  static const double _maxAcceptableAccuracy = 100.0; // meters
  static const Duration _maxStaleLocationAge = Duration(seconds: 5);

  void _onLocationUpdate(Position position) {
    // Data quality validation
    if (!_isValidLocation(position)) {
      debugPrint(
        '⚠️ LocationService: Discarding invalid location - '
        'Acc: ${position.accuracy}m, Speed: ${position.speed}m/s, '
        'Age: ${DateTime.now().difference(position.timestamp).inSeconds}s',
      );
      return;
    }

    _consecutiveValidReadings++;
    
    final locationData = LocationData.fromPosition(position);
    _currentLocation = locationData;
    _lastValidLocation = locationData;
    _locationController.add(locationData);

    debugPrint(
      '📍 LocationService: Location updated - '
      'Lat: ${position.latitude.toStringAsFixed(6)}, '
      'Lng: ${position.longitude.toStringAsFixed(6)}, '
      'Accuracy: ${position.accuracy.toStringAsFixed(1)}m, '
      'Speed: ${(position.speed * 3.6).toStringAsFixed(1)}km/h',
    );
  }

  /// Validate location data quality
  bool _isValidLocation(Position position) {
    // Check 1: Accuracy must be reasonable
    if (position.accuracy <= 0 || position.accuracy > _maxAcceptableAccuracy) {
      return false;
    }

    // Check 2: Location must not be stale (cached)
    final age = DateTime.now().difference(position.timestamp);
    if (age > _maxStaleLocationAge) {
      return false;
    }

    // Check 3: Speed must be reasonable (-1 is unknown/invalid)
    if (position.speed >= 0 && position.speed > _maxAcceptableSpeedMps) {
      return false;
    }

    // Check 4: Altitude change must be reasonable
    if (_lastValidLocation != null) {
      final altitudeChange = (position.altitude - (_lastValidLocation?.altitude ?? 0)).abs();
      final timeDelta = position.timestamp.difference(_lastValidLocation?.timestamp ?? position.timestamp).inSeconds;
      
      if (timeDelta > 0 && timeDelta < 10 && altitudeChange > 100) {
        // More than 100m altitude change in less than 10 seconds is suspicious
        return false;
      }
    }

    // Check 5: Warm-up period - need minimum valid readings
    if (_consecutiveValidReadings < _minValidReadings) {
      debugPrint('⚠️ LocationService: GPS warming up - reading $_consecutiveValidReadings/$_minValidReadings');
      return true; // Don't reject, just log
    }

    return true;
  }

  void _onLocationError(dynamic error) {
    debugPrint('❌ LocationService: Location error: $error');
    // Could emit error state to stream if needed
  }

  /// Handle location updates from background isolate
  void _onBackgroundLocationUpdate(dynamic message) {
    if (message is Map<String, dynamic>) {
      if (message['type'] == 'location') {
        try {
          final lat = message['latitude'] as double;
          final lon = message['longitude'] as double;
          final alt = message['altitude'] as double?;
          
          double? geoidHeight;
          if (alt != null) {
            geoidHeight = _geoidService.getOrthometricHeight(alt, lat, lon);
          }

          final locationData = LocationData(
            latitude: lat,
            longitude: lon,
            accuracy: message['accuracy'] as double,
            altitude: alt,
            geoidHeight: geoidHeight,
            heading: message['heading'] as double?,
            speed: message['speed'] as double?,
            timestamp: DateTime.parse(message['timestamp'] as String),
          );

          _currentLocation = locationData;
          _locationController.add(locationData);

          debugPrint(
            '📍 LocationService: Background location updated - '
            'Lat: ${locationData.latitude.toStringAsFixed(6)}, '
            'Lng: ${locationData.longitude.toStringAsFixed(6)}, '
            'Acc: ${locationData.accuracy.toStringAsFixed(1)}m',
          );
        } catch (e) {
          debugPrint('❌ LocationService: Error processing background location: $e');
        }
      }
    }
  }

  Future<void> _updatePermissionStatus() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _permissionStatus = LocationPermissionStatus.serviceDisabled;
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        switch (permission) {
          case LocationPermission.whileInUse:
            _permissionStatus = LocationPermissionStatus.whileInUse;
            break;
          case LocationPermission.always:
            _permissionStatus = LocationPermissionStatus.always;
            break;
          case LocationPermission.denied:
            _permissionStatus = LocationPermissionStatus.denied;
            break;
          case LocationPermission.deniedForever:
            _permissionStatus = LocationPermissionStatus.deniedForever;
            break;
          case LocationPermission.unableToDetermine:
            _permissionStatus = LocationPermissionStatus.unknown;
            break;
        }
      }

      _permissionController.add(_permissionStatus);
    } catch (e) {
      debugPrint('❌ LocationService: Error updating permission status: $e');
    }
  }

  Future<void> _updateServiceStatus() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _serviceStatus = serviceEnabled
          ? LocationServiceStatus.enabled
          : LocationServiceStatus.disabled;
      _serviceController.add(_serviceStatus);
    } catch (e) {
      debugPrint('❌ LocationService: Error updating service status: $e');
    }
  }

  void _startPermissionMonitoring() {
    // Check permission status every 30 seconds
    _permissionCheckTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) async {
      await _updatePermissionStatus();
      await _updateServiceStatus();
    });
  }

  bool _isLocationRecent() {
    if (_currentLocation == null) return false;

    final now = DateTime.now();
    final locationTime = _currentLocation!.timestamp;
    final difference = now.difference(locationTime);

    // Consider location recent if it's less than 30 seconds old
    return difference.inSeconds < 30;
  }

  // Getters
  LocationData? get currentLocation => _currentLocation;
  LocationPermissionStatus get permissionStatus => _permissionStatus;
  LocationServiceStatus get serviceStatus => _serviceStatus;
  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;
}

/// Enterprise-level location data model
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude; // Ellipsoidal height
  final double? geoidHeight; // Orthometric height (MSL)
  final double? heading;
  final double? speed;
  final DateTime timestamp;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.geoidHeight,
    this.heading,
    this.speed,
    required this.timestamp,
  });

  factory LocationData.fromPosition(Position position) {
    final geoidService = GeoidService();
    double? gHeight;
    if (position.altitude != 0) {
      gHeight = geoidService.getOrthometricHeight(
        position.altitude,
        position.latitude,
        position.longitude,
      );
    }

    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      geoidHeight: gHeight,
      heading: position.heading,
      speed: position.speed,
      timestamp: position.timestamp,
    );
  }

  LatLng get latLng => LatLng(latitude, longitude);

  @override
  String toString() {
    return 'LocationData(lat: ${latitude.toStringAsFixed(6)}, '
        'lng: ${longitude.toStringAsFixed(6)}, '
        'accuracy: ${accuracy.toStringAsFixed(1)}m)';
  }
}

/// Permission status enum for better state management
enum LocationPermissionStatus {
  unknown,
  denied,
  deniedForever,
  whileInUse,
  always,
  serviceDisabled,
}

/// Service status enum
enum LocationServiceStatus { unknown, enabled, disabled }

/// Extension for permission status display
extension LocationPermissionStatusExtension on LocationPermissionStatus {
  String get displayName {
    switch (this) {
      case LocationPermissionStatus.unknown:
        return 'Unknown';
      case LocationPermissionStatus.denied:
        return 'Denied';
      case LocationPermissionStatus.deniedForever:
        return 'Permanently Denied';
      case LocationPermissionStatus.whileInUse:
        return 'While Using App';
      case LocationPermissionStatus.always:
        return 'Always Allowed';
      case LocationPermissionStatus.serviceDisabled:
        return 'Location Service Disabled';
    }
  }

  bool get isGranted =>
      this == LocationPermissionStatus.whileInUse ||
      this == LocationPermissionStatus.always;

  bool get isPermanentlyDenied =>
      this == LocationPermissionStatus.deniedForever;

  bool get requiresAppSettings =>
      this == LocationPermissionStatus.deniedForever ||
      this == LocationPermissionStatus.serviceDisabled;
}
