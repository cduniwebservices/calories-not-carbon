import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/fitness_models.dart';
import '../services/activity_controller.dart';
import '../services/local_storage_service.dart';

/// Provider for the activity controller singleton
final activityControllerProvider = Provider<ActivityController>((ref) {
  return ActivityController();
});

/// Provider for GPS stabilization status
final gpsStabilizingProvider = StateNotifierProvider<GpsStabilizationNotifier, GpsStabilizationState>((ref) {
  final controller = ref.watch(activityControllerProvider);
  return GpsStabilizationNotifier(controller);
});

/// Provider for current activity session
final currentActivitySessionProvider =
    StateNotifierProvider<ActivitySessionNotifier, ActivitySession?>((ref) {
      final controller = ref.watch(activityControllerProvider);
      return ActivitySessionNotifier(controller);
    });

/// Provider for activity state
final activityStateProvider =
    StateNotifierProvider<ActivityStateNotifier, ActivityState>((ref) {
      final controller = ref.watch(activityControllerProvider);
      return ActivityStateNotifier(controller);
    });

/// Provider for fitness stats
final fitnessStatsProvider =
    StateNotifierProvider<FitnessStatsNotifier, FitnessStats>((ref) {
      final controller = ref.watch(activityControllerProvider);
      return FitnessStatsNotifier(controller);
    });

/// Provider for route points
final routePointsProvider =
    StateNotifierProvider<RoutePointsNotifier, List<LatLng>>((ref) {
      final controller = ref.watch(activityControllerProvider);
      return RoutePointsNotifier(controller);
    });

/// Provider for current location
final currentLocationProvider =
    StateNotifierProvider<CurrentLocationNotifier, LatLng?>((ref) {
      final controller = ref.watch(activityControllerProvider);
      return CurrentLocationNotifier(controller);
    });

/// Activity session state notifier
class ActivitySessionNotifier extends StateNotifier<ActivitySession?> {
  final ActivityController _controller;

  ActivitySessionNotifier(this._controller) : super(null) {
    _controller.addListener(_onControllerUpdate);
    state = _controller.currentSession;
  }

  void _onControllerUpdate() {
    if (mounted) {
      state = _controller.currentSession;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }
}

/// Activity state notifier
class ActivityStateNotifier extends StateNotifier<ActivityState> {
  final ActivityController _controller;

  ActivityStateNotifier(this._controller) : super(ActivityState.idle) {
    _controller.addListener(_onControllerUpdate);
    state = _controller.state;
  }

  void _onControllerUpdate() {
    if (mounted) {
      state = _controller.state;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }
}

/// Fitness stats state notifier
class FitnessStatsNotifier extends StateNotifier<FitnessStats> {
  final ActivityController _controller;

  FitnessStatsNotifier(this._controller)
    : super(FitnessStats(startTime: DateTime.now())) {
    _controller.addListener(_onControllerUpdate);
    state = _controller.stats;
  }

  void _onControllerUpdate() {
    if (mounted) {
      state = _controller.stats;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }
}

/// Route points state notifier
class RoutePointsNotifier extends StateNotifier<List<LatLng>> {
  final ActivityController _controller;

  RoutePointsNotifier(this._controller) : super([]) {
    _controller.addListener(_onControllerUpdate);
    state = _controller.routePoints;
  }

  void _onControllerUpdate() {
    if (mounted) {
      state = _controller.routePoints;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }
}

/// Current location state notifier
class CurrentLocationNotifier extends StateNotifier<LatLng?> {
  final ActivityController _controller;

  CurrentLocationNotifier(this._controller) : super(null) {
    _controller.addListener(_onControllerUpdate);
    state = _controller.lastKnownLocation;
  }

  void _onControllerUpdate() {
    if (mounted) {
      state = _controller.lastKnownLocation;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }
}

/// Activity actions provider
final activityActionsProvider = Provider<ActivityActions>((ref) {
  final controller = ref.watch(activityControllerProvider);
  return ActivityActions(controller);
});

/// Activity actions class for UI interaction
class ActivityActions {
  final ActivityController _controller;

  ActivityActions(this._controller);

  /// Initialize the activity controller
  Future<bool> initialize() => _controller.initialize();

  /// Start a new activity (includes GPS warm-up phase)
  Future<bool> startActivity(ActivityType type, {String? activityReplaced}) =>
      _controller.startActivity(type, activityReplaced: activityReplaced);

  /// Begin actual tracking after GPS stabilization
  Future<bool> beginTracking() => _controller.beginTracking();

  /// Pause current activity
  Future<bool> pauseActivity() => _controller.pauseActivity();

  /// Resume paused activity
  Future<bool> resumeActivity() => _controller.resumeActivity();

  /// Stop current activity
  Future<bool> stopActivity() => _controller.stopActivity();

  /// Reset activity to idle
  void resetActivity() => _controller.resetActivity();

  /// Check if action is available
  bool get canStart => _controller.canStart;
  bool get canPause => _controller.canPause;
  bool get canResume => _controller.canResume;
  bool get canStop => _controller.canStop;
  bool get isTracking => _controller.isTracking;
  bool get isPaused => _controller.isPaused;
  ActivityType get activityType => _controller.activityType;
  bool get isWarmingUp => _controller.isWarmingUp;
}

/// GPS stabilization notifier
class GpsStabilizationNotifier extends StateNotifier<GpsStabilizationState> {
  final ActivityController _controller;

  GpsStabilizationNotifier(this._controller) : super(const GpsStabilizationState()) {
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    final stabilizationData = _controller.gpsStabilizationData;
    if (stabilizationData != null) {
      state = stabilizationData;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }
}

/// Provider for activity history (fetches from local storage)
final activityHistoryProvider = FutureProvider<List<ActivitySession>>((ref) async {
  // Return all activities from local storage
  // In a real app, this might include sorting and filtering
  await Future.delayed(const Duration(milliseconds: 300)); // Brief delay for UX

  final activities = LocalStorageService.getAllActivities();
  
  // Sort by start time descending (newest first)
  activities.sort((a, b) => b.stats.startTime.compareTo(a.stats.startTime));
  
  return activities;
});
