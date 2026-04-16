import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:pedometer/pedometer.dart';
import '../models/fitness_models.dart';
import 'location_service.dart';
import 'local_storage_service.dart';
import 'weather_service.dart';

/// Million-dollar level activity controller for real-time fitness tracking
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

  // Real-time calculations
  Timer? _statsUpdateTimer;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _stepSubscription;
  double _totalDistance = 0.0;
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  List<double> _speedHistory = [];
  int _initialStepCount = 0;
  int _currentStepCount = 0;
  double _totalElevationGain = 0.0;
  double? _lastAltitude;
  DateTime? _lastUpdateTimestamp;

  // Validation metrics
  int _invalidDataPoints = 0;
  int _totalDataPoints = 0;

  // Performance tracking
  static const Duration _statsUpdateInterval = Duration(seconds: 1);
  static const double _minimumDistanceThreshold = 2.0; // meters
  static const double _minimumSpeedThreshold = 0.5; // m/s (discard speeds below this)
  static const int _speedHistoryLimit = 60; // 1 minute of history
  
  // Validation Thresholds
  static const double _maxRunningSpeedMps = 5.0;  // 18 km/h
  static const double _maxWalkingSpeedMps = 1.66; // 6 km/h
  static const int _speedAutoDetectThresholdKmhWalking = 6;
  static const int _speedAutoDetectThresholdKmhRunning = 18;

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
  bool get canStart => _state == ActivityState.idle;
  bool get canPause => _state == ActivityState.running;
  bool get canResume => _state == ActivityState.paused;
  bool get canStop =>
      _state == ActivityState.running || _state == ActivityState.paused;

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

  /// Start a new activity session
  Future<bool> startActivity(ActivityType type, {String? activityReplaced}) async {
    if (!canStart) {
      debugPrint(
        '⚠️ ActivityController: Cannot start - invalid state: $_state',
      );
      return false;
    }

    try {
      debugPrint(
        '🚀 ActivityController: Starting activity (Alternative Transport: $activityReplaced)...',
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

      // Fetch weather and IP lookup asynchronously
      _fetchStartWeather(location.latitude, location.longitude);
      _fetchStartIpLookup();

      // Set initial activity type and start time
      _activityType = type;
      _startTime = DateTime.now();
      _lastUpdateTimestamp = _startTime;
      _state = ActivityState.running;

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

      // Start GPS tracking
      final trackingStarted = await _locationService.startTracking();
      if (!trackingStarted) {
        debugPrint('❌ ActivityController: Failed to start GPS tracking');
        _state = ActivityState.idle;
        return false;
      }

      // Start listening to location updates
      _startLocationTracking();
      
      // Start listening to pedometer
      _startStepTracking();

      // Start stats update timer
      _startStatsTimer();

      debugPrint('✅ ActivityController: Activity started successfully');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ ActivityController: Failed to start activity: $e');
      _state = ActivityState.idle;
      notifyListeners();
      return false;
    }
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

      // Stop timers but keep GPS tracking for resume
      _statsUpdateTimer?.cancel();
      _stepSubscription?.pause();

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

      // Restart stats timer and pedometer
      _startStatsTimer();
      _stepSubscription?.resume();

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
      final weather = await _weatherService.getCurrentWeather(lat, lon);
      if (weather != null && _currentSession != null) {
        _currentSession = _currentSession!.copyWith(startWeather: weather);
        debugPrint('🌍 ActivityController: Start weather recorded: ${weather.tempC}°C');
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

  void _startStatsTimer() {
    _statsUpdateTimer?.cancel();
    _statsUpdateTimer = Timer.periodic(_statsUpdateInterval, (_) {
      if (_state == ActivityState.running) {
        _updateStats();
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
    if (_state != ActivityState.running) return;

    try {
      final newLocation = LatLng(locationData.latitude, locationData.longitude);
      final timestamp = DateTime.now();
      
      // Calculate time difference from the absolute last location update
      // This prevents "leaking" stationary time into moving duration
      final lastTime = _lastUpdateTimestamp ?? _startTime ?? timestamp;
      final timeDiff = timestamp.difference(lastTime);

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

        // Only process if movement is significant AND above speed threshold (discarding 0/low speeds)
        if (distance >= _minimumDistanceThreshold && instantSpeed >= _minimumSpeedThreshold) {
          _totalDistance += distance;
          _movingDuration += timeDiff;
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
          _currentSpeed = 0.0;
          _updateStats();

          final currentAlt = locationData.geoidHeight ?? locationData.altitude;
          if (_waypoints.isEmpty || _waypoints.last.type != 'stationary' || 
              timestamp.difference(_waypoints.last.timestamp).inSeconds > 5) {
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
      
      // Update the absolute last update timestamp regardless of movement
      _lastUpdateTimestamp = timestamp;
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

    final averageSpeed = activeDuration.inSeconds > 0
        ? _totalDistance / activeDuration.inSeconds
        : 0.0;

    // Auto-detect activity type based on moving average speed
    _updateActivityTypeFromSpeed(averageSpeed);

    final averagePace = averageSpeed > 0 ? 1000.0 / averageSpeed : 0.0;
    final currentPace = _currentSpeed > _minimumSpeedThreshold
        ? 1000.0 / _currentSpeed
        : 0.0;

    final calories = _calculateCalories(
      activeDuration,
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

    final averageSpeed = activeDuration.inSeconds > 0
        ? _totalDistance / activeDuration.inSeconds
        : 0.0;

    _updateActivityTypeFromSpeed(averageSpeed);

    final averagePace = averageSpeed > 0 ? 1000.0 / averageSpeed : 0.0;
    final calories = _calculateCalories(activeDuration, _totalDistance, _activityType);
    final displaySteps = _currentStepCount > 0 
        ? _currentStepCount 
        : _estimateSteps(_totalDistance, _activityType);

    _stats = _stats.copyWith(
      totalDistanceMeters: _totalDistance,
      totalDuration: totalDuration,
      activeDuration: activeDuration,
      movingDuration: _movingDuration,
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
    if (activeDuration.inMinutes <= 0) return 0;
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
    _statsUpdateTimer?.cancel();
    super.dispose();
  }
}
