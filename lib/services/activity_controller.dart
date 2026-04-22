import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pedometer/pedometer.dart';
import '../models/fitness_models.dart';
import 'location_service.dart';
import 'local_storage_service.dart';
import 'weather_service.dart';

/// Million-dollar level activity controller with Sensor Fusion (GPS + Accelerometer)
class ActivityController extends ChangeNotifier {
  static final ActivityController _instance = ActivityController._internal();
  factory ActivityController() => _instance;
  ActivityController._internal();

  // Services
  final LocationService _locationService = LocationService();
  final WeatherService _weatherService = WeatherService();
  final _uuid = const Uuid();

  // State management
  ActivitySession? _currentSession;
  ActivityState _state = ActivityState.idle;
  ActivityType _activityType = ActivityType.running;
  FitnessStats _stats = FitnessStats(startTime: DateTime.now());
  bool _isValid = true;

  // Tracking data
  final List<LatLng> _routePoints = [];
  final List<ActivityWaypoint> _waypoints = [];
  LatLng? _lastKnownLocation;
  DateTime? _startTime;
  DateTime? _pauseTime;
  Duration _pausedDuration = Duration.zero;
  Duration _movingDuration = Duration.zero;
  Duration _stationaryDuration = Duration.zero;

  // Timer-based duration tracking for accurate moving/stationary time
  Timer? _durationTimer;
  DateTime? _lastDurationUpdateTime;
  bool _wasMoving = false;

  // Real-time calculations
  Timer? _statsUpdateTimer;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _stepSubscription;
  StreamSubscription? _accelerometerSubscription;

  double _totalDistance = 0.0;
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  List<double> _speedHistory = [];
  int _initialStepCount = 0;
  int _currentStepCount = 0;
  double _totalElevationGain = 0.0;
  double? _lastAltitude;
  DateTime? _lastUpdateTimestamp;

  // Sensor Fusion State
  bool _isPhysicallyMoving = false;
  double _motionMagnitude = 0.0;
  DateTime? _lastSignificantMotionTime;

  // Validation metrics
  int _invalidDataPoints = 0;
  int _totalDataPoints = 0;

  // Performance tracking
  static const Duration _statsUpdateInterval = Duration(seconds: 1);
  static const double _minimumDistanceThreshold = 2.0; // meters
  static const double _minimumSpeedThreshold = 0.5; // m/s (discard speeds below this)
  static const double _motionVibrationThreshold = 0.15; // Gs of force for 'moving'
  static const int _speedHistoryLimit = 60; // 1 minute of history

  // Validation Thresholds
  static const double _maxRunningSpeedMps = 5.0; // 18 km/h
  static const double _maxWalkingSpeedMps = 1.66; // 6 km/h
  static const int _speedAutoDetectThresholdKmhWalking = 6;
  static const int _speedAutoDetectThresholdKmhRunning = 18;

  // GPS Stabilization
  GpsStabilizationState? _gpsStabilizationState;
  final List<double> _altitudeReadings = [];
  final List<double> _speedReadings = [];
  static const int _requiredStableReadings = 5;
  static const double _maxAltitudeVariance = 2.0; // meters
  static const double _maxSpeedVariance = 1.0; // m/s
  static const double _minAccuracyForStability = 20.0; // meters
  static const int _maxWarmupDurationSeconds = 30; // max time to wait for GPS
  DateTime? _warmupStartTime;
  Timer? _warmupCheckTimer;

  // Getters
  ActivitySession? get currentSession => _currentSession;
  ActivityState get state => _state;
  ActivityType get activityType => _activityType;
  FitnessStats get stats => _stats;
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  List<ActivityWaypoint> get waypoints => List.unmodifiable(_waypoints);
  LatLng? get lastKnownLocation => _lastKnownLocation;
  bool get isTracking => _state == ActivityState.running;
  bool get isPaused => _state == ActivityState.paused;
  bool get isWarmingUp => _state == ActivityState.warmingUp;
  bool get canStart => _state == ActivityState.idle;
  bool get canPause => _state == ActivityState.running;
  bool get canResume => _state == ActivityState.paused;
  bool get canStop =>
      _state == ActivityState.running || _state == ActivityState.paused;
  bool get canBeginTracking => _state == ActivityState.warmingUp && (_gpsStabilizationState?.isStable ?? false);
  GpsStabilizationState? get gpsStabilizationData => _gpsStabilizationState;

  /// Initialize the activity controller
  Future<bool> initialize() async {
    try {
      debugPrint('🏃 ActivityController: Initializing...');

      // Initialize location services
      await _locationService.initialize();

      debugPrint('✅ ActivityController: Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ ActivityController: Initialization failed: $e');
      return false;
    }
  }

  /// Start a new activity session (enters warmingUp state first)
  Future<bool> startActivity(ActivityType type, {String? activityReplaced}) async {
    if (!canStart) {
      debugPrint(
        '⚠️ ActivityController: Cannot start - invalid state: $_state',
      );
      return false;
    }

    try {
      debugPrint(
        '🚀 ActivityController: Starting activity warm-up (Alternative Transport: $activityReplaced)...',
      );

      // Ensure GPS is ready with timeout and retries
      LocationData? location;
      int retries = 3;

      while (retries > 0 && location == null) {
        try {
          location = await _locationService.getCurrentLocation().timeout(
            const Duration(seconds: 10),
          );
          break;
        } catch (e) {
          retries--;
          if (retries > 0) {
            debugPrint('GPS retry ${4 - retries}/3...');
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }

      if (location == null) {
        debugPrint(
          '❌ ActivityController: Cannot get GPS location after retries',
        );
        return false;
      }

    // Reset all tracking data
    _resetTrackingData();

    // Fetch weather and IP lookup asynchronously (fire-and-forget, will attach to session when ready)
    // Note: These complete after session creation but before beginTracking()
    _fetchStartWeather(location.latitude, location.longitude);
    _fetchStartIpLookup();

      // Set initial activity type and start time
      _activityType = type;
      _startTime = DateTime.now();
      _lastUpdateTimestamp = _startTime;
      _state = ActivityState.warmingUp;
      _warmupStartTime = _startTime;

      // Create new session
      _currentSession = ActivitySession(
        id: _uuid.v4(),
        activityType: type,
        state: _state,
        stats: FitnessStats(startTime: _startTime!),
        isValid: true,
        activityReplaced: activityReplaced,
        createdAt: DateTime.now(),
      );

      // Set initial location
      _lastKnownLocation = LatLng(location.latitude, location.longitude);
      _routePoints.add(_lastKnownLocation!);
      _lastAltitude = location.geoidHeight ?? location.altitude;

      // Add start waypoint
      _waypoints.add(
        ActivityWaypoint(
          location: _lastKnownLocation!,
          timestamp: _startTime!,
          type: 'start',
          altitude: location.geoidHeight ?? location.altitude,
        ),
      );

      // Start GPS tracking for warm-up phase
      final trackingStarted = await _locationService.startTracking();
      if (!trackingStarted) {
        debugPrint('❌ ActivityController: Failed to start GPS tracking');
        _state = ActivityState.idle;
        return false;
      }

      // Initialize GPS stabilization tracking
      _initializeGpsStabilization(location);

      // Start listening to location updates (for warm-up)
      _startLocationTracking();

      // Start listening to pedometer
      _startStepTracking();

      // Start listening to accelerometer (Sensor Fusion)
      _startAccelerometerTracking();

      debugPrint('✅ ActivityController: Activity warming up - waiting for GPS stabilization');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ ActivityController: Failed to start activity: $e');
      _state = ActivityState.idle;
      notifyListeners();
      return false;
    }
  }

  /// Begin actual tracking after GPS stabilization
  Future<bool> beginTracking() async {
    if (_state != ActivityState.warmingUp) {
      debugPrint('⚠️ ActivityController: Cannot begin tracking - not in warmingUp state');
      return false;
    }

    try {
      debugPrint('▶️ ActivityController: GPS stabilized - beginning tracking');

      // Stop warm-up timer
      _warmupCheckTimer?.cancel();
      _warmupCheckTimer = null;

      // Reset start time to actual tracking start
      _startTime = DateTime.now();
      _lastUpdateTimestamp = _startTime;
      _state = ActivityState.running;

    // Reset tracking data for actual tracking (discard warm-up readings)
    _altitudeReadings.clear();
    _speedReadings.clear();
    _totalDistance = 0.0;
    _totalElevationGain = 0.0;
    _lastAltitude = null; // Reset altitude baseline to prevent warm-up drift from affecting elevation
    _routePoints.clear();
    _waypoints.clear();

      // Re-add current position as the true starting point
      if (_lastKnownLocation != null) {
        _routePoints.add(_lastKnownLocation!);
        _waypoints.add(
          ActivityWaypoint(
            location: _lastKnownLocation!,
            timestamp: _startTime!,
            type: 'start',
            altitude: _lastAltitude,
          ),
        );
      }

    // Update session - preserve existing data like weather/IP that was fetched during warm-up
    _currentSession = _currentSession?.copyWith(
      state: _state,
      stats: FitnessStats(startTime: _startTime!),
    );
    debugPrint('📝 ActivityController: Session updated for tracking - preserving warm-up data (weather: ${_currentSession?.startWeather != null})');

    // Start stats update timer
    _startStatsTimer();

    // Start duration tracking timer for accurate moving/stationary time
    _startDurationTimer();

    // Final stabilization state - create new instance since _resetTrackingData cleared the old one
    _gpsStabilizationState = GpsStabilizationState(
      isStabilizing: false,
      isStable: true,
      requiredStableReadings: _requiredStableReadings,
      stabilityMessage: 'GPS Ready - Tracking Started',
    );

    debugPrint('✅ ActivityController: Tracking started successfully');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ ActivityController: Failed to begin tracking: $e');
      return false;
    }
  }

  /// Initialize GPS stabilization tracking
  void _initializeGpsStabilization(LocationData location) {
    _altitudeReadings.clear();
    _speedReadings.clear();
    _warmupStartTime = DateTime.now();

    _gpsStabilizationState = GpsStabilizationState(
      isStabilizing: true,
      isStable: false,
      currentAltitude: location.geoidHeight ?? location.altitude,
      currentSpeed: location.speed ?? 0.0,
      gpsAccuracy: location.accuracy,
      requiredStableReadings: _requiredStableReadings,
      stabilityMessage: 'Waiting for GPS signal to stabilize...',
    );

    // Start warm-up check timer
    _warmupCheckTimer?.cancel();
    _warmupCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkWarmupTimeout();
    });
  }

  /// Check if warm-up has timed out
  void _checkWarmupTimeout() {
    if (_warmupStartTime == null || _state != ActivityState.warmingUp) return;

    final elapsed = DateTime.now().difference(_warmupStartTime!);
    if (elapsed.inSeconds > _maxWarmupDurationSeconds) {
      debugPrint('⚠️ ActivityController: GPS warm-up timed out - forcing begin tracking');
      // Force begin tracking after timeout
      beginTracking();
    }
  }

  /// Update GPS stabilization state with new readings
  void _updateGpsStabilization(LocationData location) {
    if (_state != ActivityState.warmingUp) return;

    final altitude = location.geoidHeight ?? location.altitude ?? 0.0;
    final speed = location.speed ?? 0.0;
    final accuracy = location.accuracy;

    // Add readings
    _altitudeReadings.add(altitude);
    _speedReadings.add(speed);

    // Keep only last N readings
    if (_altitudeReadings.length > _requiredStableReadings) {
      _altitudeReadings.removeAt(0);
    }
    if (_speedReadings.length > _requiredStableReadings) {
      _speedReadings.removeAt(0);
    }

    // Calculate variances if we have enough readings
    double? altitudeVariance;
    double? speedVariance;
    bool isStable = false;
    String message;

    if (_altitudeReadings.length >= 3) {
      altitudeVariance = _calculateVariance(_altitudeReadings);
      speedVariance = _calculateVariance(_speedReadings);

      // Check stability criteria
      final altitudeStable = altitudeVariance <= _maxAltitudeVariance;
      final speedStable = speedVariance <= _maxSpeedVariance;
      final accuracyGood = accuracy <= _minAccuracyForStability;

      if (altitudeStable && speedStable && accuracyGood) {
        isStable = true;
        message = 'GPS signal stable - Ready to start';
      } else {
        final issues = <String>[];
        if (!altitudeStable) issues.add('altitude');
        if (!speedStable) issues.add('speed');
        if (!accuracyGood) issues.add('accuracy');
        message = 'Stabilizing ${issues.join(', ')}...';
      }
    } else {
      message = 'Collecting GPS readings (${_altitudeReadings.length}/$_requiredStableReadings)...';
    }

    _gpsStabilizationState = GpsStabilizationState(
      isStabilizing: true,
      isStable: isStable,
      currentAltitude: altitude,
      currentSpeed: speed,
      altitudeVariance: altitudeVariance,
      speedVariance: speedVariance,
      stableReadingsCount: _altitudeReadings.length,
      requiredStableReadings: _requiredStableReadings,
      gpsAccuracy: accuracy,
      stabilityMessage: message,
    );

    notifyListeners();

    // Auto-begin tracking once stable
    if (isStable && _state == ActivityState.warmingUp) {
      beginTracking();
    }
  }

  /// Calculate variance of a list of values
  double _calculateVariance(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => math.pow(v - mean, 2)).toList();
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  /// Pause the current activity
  Future<bool> pauseActivity() async {
    if (!canPause) {
      debugPrint(
        '⚠️ ActivityController: Cannot pause - invalid state: $_state',
      );
      return false;
    }

    try {
      debugPrint('⏸️ ActivityController: Pausing activity...');

      _pauseTime = DateTime.now();
      _state = ActivityState.paused;

      // Add pause waypoint
      if (_lastKnownLocation != null) {
        _waypoints.add(
          ActivityWaypoint(
            location: _lastKnownLocation!,
            timestamp: _pauseTime!,
            type: 'pause',
            statsAtTime: _stats,
            altitude: _lastAltitude,
          ),
        );
      }

      // Stop timers and sensors but keep GPS tracking for resume
      _statsUpdateTimer?.cancel();
      _pauseDurationTimer();
      _stepSubscription?.pause();
      _stopAccelerometerTracking();

      debugPrint('✅ ActivityController: Activity paused');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ ActivityController: Failed to pause activity: $e');
      return false;
    }
  }

  /// Resume the paused activity
  Future<bool> resumeActivity() async {
    if (!canResume) {
      debugPrint(
        '⚠️ ActivityController: Cannot resume - invalid state: $_state',
      );
      return false;
    }

    try {
      debugPrint('▶️ ActivityController: Resuming activity...');

      if (_pauseTime != null) {
        // Add to total paused duration
        _pausedDuration += DateTime.now().difference(_pauseTime!);
        _pauseTime = null;
      }

      _state = ActivityState.running;
      _lastUpdateTimestamp = DateTime.now();

      // Add resume waypoint
      if (_lastKnownLocation != null) {
        _waypoints.add(
          ActivityWaypoint(
            location: _lastKnownLocation!,
            timestamp: DateTime.now(),
            type: 'resume',
            altitude: _lastAltitude,
          ),
        );
      }

      // Restart stats timer and sensors
      _startStatsTimer();
      _resumeDurationTimer();
      _stepSubscription?.resume();
      _startAccelerometerTracking();

      debugPrint('✅ ActivityController: Activity resumed');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ ActivityController: Failed to resume activity: $e');
      return false;
    }
  }

  /// Stop and complete the current activity
  Future<bool> stopActivity() async {
    if (!canStop) {
      debugPrint('⚠️ ActivityController: Cannot stop - invalid state: $_state');
      return false;
    }

    try {
      debugPrint('🛑 ActivityController: Stopping activity...');

      final endTime = DateTime.now();
      
      // If currently paused, add the last pause interval to total paused duration
      if (_state == ActivityState.paused && _pauseTime != null) {
        _pausedDuration += endTime.difference(_pauseTime!);
        _pauseTime = null;
      }

      _state = ActivityState.completed;

      // Perform final validation check
      _performFinalValidation();

      // Add final waypoint
      if (_lastKnownLocation != null) {
        _waypoints.add(
          ActivityWaypoint(
            location: _lastKnownLocation!,
            timestamp: endTime,
            type: 'finish',
            statsAtTime: _stats,
            altitude: _lastAltitude,
          ),
        );
      }

      // Update final stats
      _updateFinalStats(endTime);

      // Stop all tracking
      await _stopLocationTracking();
      _stopStepTracking();
      _stopAccelerometerTracking();
      _statsUpdateTimer?.cancel();

      // Update session with final data
      if (_currentSession != null) {
        _currentSession = _currentSession!.copyWith(
          activityType: _activityType,
          state: ActivityState.completed,
          stats: _stats,
          routePoints: List.from(_routePoints),
          waypoints: List.from(_waypoints),
          isValid: _isValid,
        );

        // Save activity locally for offline-first sync
        await LocalStorageService.saveActivity(_currentSession!);
        debugPrint('💾 ActivityController: Activity saved locally - Valid: $_isValid');
      }

      debugPrint(
        '✅ ActivityController: Activity completed - ${_stats.formattedDistance} in ${_stats.formattedDuration}',
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ ActivityController: Failed to stop activity: $e');
      return false;
    }
  }

  /// Reset to idle state
  void resetActivity() {
    debugPrint('🔄 ActivityController: Resetting activity...');

    _stopLocationTracking();
    _stopStepTracking();
    _stopAccelerometerTracking();
    _statsUpdateTimer?.cancel();
    _resetTrackingData();
    _state = ActivityState.idle;
    _currentSession = null;

    notifyListeners();
  }

  /// Private methods

  Future<void> _fetchStartIpLookup() async {
    try {
      final ipData = await _weatherService.getIpLookup();
      if (ipData != null && _currentSession != null) {
        _currentSession = _currentSession!.copyWith(startIpLookup: ipData);
        debugPrint('🌐 ActivityController: IP lookup recorded: ${ipData.ip} (${ipData.city})');
      }
    } catch (e) {
      debugPrint('⚠️ ActivityController: Error during IP lookup: $e');
    }
  }

  Future<void> _fetchStartWeather(double lat, double lon) async {
    try {
      debugPrint('🌍 ActivityController: Fetching start weather for $lat, $lon...');
      final weather = await _weatherService.getCurrentWeather(lat, lon);
      if (weather != null && _currentSession != null) {
        _currentSession = _currentSession!.copyWith(startWeather: weather);
        debugPrint('🌍 ActivityController: Start weather recorded: ${weather.tempC}°C in ${weather.location?.name}');
      } else if (weather == null) {
        debugPrint('⚠️ ActivityController: Weather fetch returned null (check WEATHER_API_KEY)');
      } else {
        debugPrint('⚠️ ActivityController: Weather fetched but session is null');
      }
    } catch (e) {
      debugPrint('⚠️ ActivityController: Error fetching start weather: $e');
    }
  }

  void _resetTrackingData() {
    _routePoints.clear();
    _waypoints.clear();
    _lastKnownLocation = null;
    _startTime = null;
    _pauseTime = null;
    _pausedDuration = Duration.zero;
    _movingDuration = Duration.zero;
    _stationaryDuration = Duration.zero;
    _durationTimer?.cancel();
    _durationTimer = null;
    _lastDurationUpdateTime = null;
    _wasMoving = false;
    _totalDistance = 0.0;
    _currentSpeed = 0.0;
    _maxSpeed = 0.0;
    _speedHistory.clear();
    _initialStepCount = 0;
    _currentStepCount = 0;
    _totalElevationGain = 0.0;
    _lastAltitude = null;
    _stats = FitnessStats(startTime: DateTime.now());
    _isValid = true;
    _invalidDataPoints = 0;
    _totalDataPoints = 0;
    // Reset GPS stabilization
    _altitudeReadings.clear();
    _speedReadings.clear();
    _warmupStartTime = null;
    _warmupCheckTimer?.cancel();
    _warmupCheckTimer = null;
    _gpsStabilizationState = null;
  }

  void _startLocationTracking() {
    _locationSubscription = _locationService.locationStream.listen(
      _onLocationUpdate,
      onError: (error) {
        debugPrint('❌ ActivityController: Location stream error: $error');
      },
    );
  }

  Future<void> _stopLocationTracking() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    await _locationService.stopTracking();
  }
  
  void _startStepTracking() {
    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCountUpdate,
        onError: (error) {
          debugPrint('❌ ActivityController: Pedometer error: $error');
        },
      );
    } catch (e) {
      debugPrint('⚠️ ActivityController: Could not start pedometer: $e');
    }
  }
  
  void _stopStepTracking() {
    _stepSubscription?.cancel();
    _stepSubscription = null;
  }

  void _startAccelerometerTracking() {
    try {
      _accelerometerSubscription = userAccelerometerEventStream().listen(
        _onAccelerometerUpdate,
        onError: (error) {
          debugPrint('❌ ActivityController: Accelerometer error: $error');
        },
      );
    } catch (e) {
      debugPrint('⚠️ ActivityController: Could not start accelerometer: $e');
    }
  }

  void _stopAccelerometerTracking() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _isPhysicallyMoving = false;
  }

  void _onAccelerometerUpdate(UserAccelerometerEvent event) {
    // Calculate the magnitude of the 3D acceleration vector
    // This is 'User' acceleration (linear), meaning gravity is already filtered out
    _motionMagnitude = math.sqrt(
      math.pow(event.x, 2) + 
      math.pow(event.y, 2) + 
      math.pow(event.z, 2)
    );

    // If magnitude is above threshold, user is physically moving (walking, cycling, etc)
    if (_motionMagnitude > _motionVibrationThreshold) {
      _isPhysicallyMoving = true;
      _lastSignificantMotionTime = DateTime.now();
    } else {
      // If we haven't seen significant motion for 1.5 seconds, we are stationary
      if (_lastSignificantMotionTime == null || 
          DateTime.now().difference(_lastSignificantMotionTime!).inMilliseconds > 1500) {
        _isPhysicallyMoving = false;
      }
    }
  }

  void _startStatsTimer() {
    _statsUpdateTimer?.cancel();
    _statsUpdateTimer = Timer.periodic(_statsUpdateInterval, (_) {
      if (_state == ActivityState.running) {
        _updateStats();
      }
    });
  }

  /// Start the duration timer that tracks moving vs stationary time every second
  void _startDurationTimer() {
    _durationTimer?.cancel();
    _lastDurationUpdateTime = DateTime.now();
    _wasMoving = false;
    
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state != ActivityState.running) return;
      
      final now = DateTime.now();
      final timeDiff = now.difference(_lastDurationUpdateTime ?? now);
      _lastDurationUpdateTime = now;
      
      // Add time to moving or stationary based on current movement state
      if (_isPhysicallyMoving || _currentSpeed > 0.5) {
        _movingDuration += timeDiff;
        _wasMoving = true;
      } else {
        _stationaryDuration += timeDiff;
        _wasMoving = false;
      }
    });
  }

  /// Pause the duration timer
  void _pauseDurationTimer() {
    _durationTimer?.cancel();
    _lastDurationUpdateTime = null;
  }

  /// Resume the duration timer
  void _resumeDurationTimer() {
    _lastDurationUpdateTime = DateTime.now();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state != ActivityState.running) return;
      
      final now = DateTime.now();
      final timeDiff = now.difference(_lastDurationUpdateTime ?? now);
      _lastDurationUpdateTime = now;
      
      if (_isPhysicallyMoving || _currentSpeed > 0.5) {
        _movingDuration += timeDiff;
        _wasMoving = true;
      } else {
        _stationaryDuration += timeDiff;
        _wasMoving = false;
      }
    });
  }

  void _onStepCountUpdate(StepCount event) {
    if (_initialStepCount == 0) {
      _initialStepCount = event.steps;
    }
    
    _currentStepCount = event.steps - _initialStepCount;
    debugPrint('👣 ActivityController: Hardware steps: $_currentStepCount');
  }

  void _onLocationUpdate(dynamic locationData) {
    // Update GPS stabilization during warmup
    if (_state == ActivityState.warmingUp && locationData is LocationData) {
      _updateGpsStabilization(locationData);
      return;
    }

    if (_state != ActivityState.running) return;

    try {
      final newLocation = LatLng(locationData.latitude, locationData.longitude);
      final timestamp = DateTime.now();
      
      // Calculate time difference from the absolute last location update
      // This prevents "leaking" stationary time into moving duration
      final lastTime = _lastUpdateTimestamp ?? _startTime ?? timestamp;
      final timeDiff = timestamp.difference(lastTime);

      // Update the absolute last update timestamp IMMEDIATELY
      // This ensures that any calls to _updateStats() during this method 
      // see the correct 'gap' time.
      _lastUpdateTimestamp = timestamp;

      if (_lastKnownLocation != null) {
        final distance = Geolocator.distanceBetween(
          _lastKnownLocation!.latitude,
          _lastKnownLocation!.longitude,
          newLocation.latitude,
          newLocation.longitude,
        );

        // Calculate instantaneous speed
        double instantSpeed = 0.0;
        if (locationData.speed != null && locationData.speed > 0) {
          instantSpeed = locationData.speed;
        } else if (timeDiff.inMilliseconds > 0) {
          instantSpeed = distance / (timeDiff.inMilliseconds / 1000.0);
        }

        // SENSOR FUSION:
        // Trust GPS if movement is significant. 
        // Use Accelerometer to confirm slow movement and prevent jitter.
        final bool isGpsMoving = distance >= _minimumDistanceThreshold && instantSpeed >= _minimumSpeedThreshold;
        final bool isActuallyMoving = isGpsMoving || (instantSpeed > 0.3 && _isPhysicallyMoving);

      if (isActuallyMoving) {
        _totalDistance += distance;
        // NOTE: Duration is tracked by _durationTimer, NOT here
        // to prevent double-counting when iOS pauses/resumes location updates
        _currentSpeed = instantSpeed;
          _routePoints.add(newLocation);

          // VALIDATION: Cadence and Speed check
          _validateDataPoint(distance, _currentSpeed);

          // Update max speed
          if (_currentSpeed > _maxSpeed) {
            _maxSpeed = _currentSpeed;
          }

          // Update speed history
          _speedHistory.add(_currentSpeed);
          if (_speedHistory.length > _speedHistoryLimit) {
            _speedHistory.removeAt(0);
          }

          // Track elevation
          final currentAlt = locationData.geoidHeight ?? locationData.altitude;
          if (currentAlt != null) {
            if (_lastAltitude != null) {
              final elevationChange = currentAlt - _lastAltitude!;
              if (elevationChange > 0) {
                _totalElevationGain += elevationChange;
              }
            }
            _lastAltitude = currentAlt;
          }

          _lastKnownLocation = newLocation;

          // Update stats immediately for responsive UI
          _updateStats();

          // Record waypoint
          _waypoints.add(
            ActivityWaypoint(
              location: newLocation,
              timestamp: timestamp,
              type: 'track_point',
              statsAtTime: _stats,
              altitude: currentAlt,
            ),
          );
      } else {
        // STATIONARY
        // NOTE: Duration is tracked by _durationTimer, NOT here
        // to prevent double-counting when iOS pauses/resumes location updates
        _currentSpeed = 0.0;
          _updateStats();

          final currentAlt = locationData.geoidHeight ?? locationData.altitude;
          if (_waypoints.isEmpty || _waypoints.last.type != 'stationary' || 
              timestamp.difference(_waypoints.last.timestamp).inSeconds > 2) {
            _waypoints.add(
              ActivityWaypoint(
                location: newLocation,
                timestamp: timestamp,
                type: 'stationary',
                statsAtTime: _stats,
                altitude: currentAlt,
              ),
            );
          }
        }
      } else {
        // First location
        _lastKnownLocation = newLocation;
        _routePoints.add(newLocation);
        final currentAlt = locationData.geoidHeight ?? locationData.altitude;
        _lastAltitude = currentAlt;
        
        _updateStats();
        
        _waypoints.add(
          ActivityWaypoint(
            location: newLocation,
            timestamp: timestamp,
            type: 'start_point',
            statsAtTime: _stats,
            altitude: currentAlt,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ ActivityController: Error processing location update: $e');
    }
  }
  void _validateDataPoint(double distanceMeters, double speedMps) {
    _totalDataPoints++;
    bool isPointValid = true;
    
    if (_activityType == ActivityType.running && speedMps > _maxRunningSpeedMps) {
      isPointValid = false;
    } else if (_activityType == ActivityType.walking && speedMps > _maxWalkingSpeedMps) {
      isPointValid = false;
    }
    
    if (_totalDistance > 50 && _currentStepCount < 10 && speedMps > 3.0) {
      isPointValid = false;
    }
    
    if (!isPointValid) _invalidDataPoints++;
  }

  void _performFinalValidation() {
    if (_totalDataPoints > 0) {
      final invalidRatio = _invalidDataPoints / _totalDataPoints;
      if (invalidRatio > 0.20) _isValid = false;
    }
    if (_totalDistance > 500 && _stats.activeDuration.inMinutes < 2) _isValid = false;
  }

  void _updateActivityTypeFromSpeed(double speedMps) {
    double speedKmh = speedMps * 3.6;
    if (speedKmh < _speedAutoDetectThresholdKmhWalking) {
      _activityType = ActivityType.walking;
    } else if (speedKmh < _speedAutoDetectThresholdKmhRunning) {
      _activityType = ActivityType.running;
    } else {
      _activityType = ActivityType.cycling;
    }
  }

  void _updateStats() {
    if (_startTime == null) return;

    final now = DateTime.now();
    final totalDuration = now.difference(_startTime!);

    // Active duration is wall-clock time minus paused time
    // This ensures the UI timer ticks every second while running
    final activeDuration = totalDuration - _pausedDuration;

    // Duration timer now tracks moving/stationary time accurately every second
    // Just use the tracked values directly
    final provisionalMoving = _movingDuration;
    final provisionalStationary = _stationaryDuration;

    // Ensure duration never exceeds active time due to clock drift
    final totalTrackedMs = provisionalMoving.inMilliseconds + provisionalStationary.inMilliseconds;
    if (totalTrackedMs > activeDuration.inMilliseconds) {
      // Scale down proportionally if there's drift
      final ratio = activeDuration.inMilliseconds / totalTrackedMs;
      _movingDuration = Duration(milliseconds: (_movingDuration.inMilliseconds * ratio).toInt());
      _stationaryDuration = Duration(milliseconds: (_stationaryDuration.inMilliseconds * ratio).toInt());
    } else if (totalTrackedMs < activeDuration.inMilliseconds) {
      // If there's a gap, add it to stationary
      final gap = Duration(milliseconds: activeDuration.inMilliseconds - totalTrackedMs);
      _stationaryDuration += gap;
    }

    // Use movingDuration for average speed to keep it stable when stationary
    final averageSpeed = _movingDuration.inSeconds > 0
        ? _totalDistance / _movingDuration.inSeconds
        : 0.0;

    // Auto-detect activity type based on moving average speed
    _updateActivityTypeFromSpeed(averageSpeed);

    final averagePace = averageSpeed > 0 ? 1000.0 / averageSpeed : 0.0;
    final currentPace = _currentSpeed > _minimumSpeedThreshold
        ? 1000.0 / _currentSpeed
        : 0.0;

    // Calories should be based on time spent moving
    final calories = _calculateCalories(
      _movingDuration,
      _totalDistance,
      _activityType,
    );
    
    final displaySteps = _currentStepCount > 0 
        ? _currentStepCount 
        : _estimateSteps(_totalDistance, _activityType);

    _stats = FitnessStats(
      totalDistanceMeters: _totalDistance,
      totalDuration: totalDuration,
      activeDuration: activeDuration,
      movingDuration: _movingDuration,
      stationaryDuration: _stationaryDuration,
      averageSpeedMps: averageSpeed,
      currentSpeedMps: _currentSpeed,
      maxSpeedMps: _maxSpeed,
      averagePaceSecondsPerKm: averagePace,
      currentPaceSecondsPerKm: currentPace,
      estimatedCalories: calories,
      startTime: _startTime!,
      endTime: _state == ActivityState.completed ? now : null,
      totalSteps: displaySteps,
      elevationGain: _totalElevationGain,
      altitude: _lastAltitude ?? 0.0,
    );

    notifyListeners();
  }

  void _updateFinalStats(DateTime endTime) {
    final totalDuration = endTime.difference(_startTime!);
    final activeDuration = totalDuration - _pausedDuration;
    final stationaryDuration = _stationaryDuration;

    final averageSpeed = _movingDuration.inSeconds > 0
        ? _totalDistance / _movingDuration.inSeconds
        : 0.0;

    _updateActivityTypeFromSpeed(averageSpeed);

    final averagePace = averageSpeed > 0 ? 1000.0 / averageSpeed : 0.0;
    final calories = _calculateCalories(_movingDuration, _totalDistance, _activityType);
    final displaySteps = _currentStepCount > 0 
        ? _currentStepCount 
        : _estimateSteps(_totalDistance, _activityType);

    _stats = _stats.copyWith(
      totalDistanceMeters: _totalDistance,
      totalDuration: totalDuration,
      activeDuration: activeDuration,
      movingDuration: _movingDuration,
      stationaryDuration: stationaryDuration,
      averageSpeedMps: averageSpeed,
      maxSpeedMps: _maxSpeed,
      averagePaceSecondsPerKm: averagePace,
      estimatedCalories: calories,
      endTime: endTime,
      totalSteps: displaySteps,
      elevationGain: _totalElevationGain,
      altitude: _lastAltitude ?? 0.0,
    );
  }

  int _calculateCalories(Duration activeDuration, double distanceMeters, ActivityType activityType) {
    const averageWeightKg = 70.0;
    final timeHours = activeDuration.inMilliseconds / (1000 * 60 * 60);
    final mets = activityType.averageMets;
    return (mets * averageWeightKg * timeHours).round();
  }

  int _estimateSteps(double distanceMeters, ActivityType activityType) {
    switch (activityType) {
      case ActivityType.running: return (distanceMeters / 1.2).round();
      case ActivityType.walking: return (distanceMeters / 0.8).round();
      case ActivityType.hiking: return (distanceMeters / 0.7).round();
      default: return 0;
    }
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _stopStepTracking();
    _stopAccelerometerTracking();
    _statsUpdateTimer?.cancel();
    super.dispose();
  }
}
