import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Activity state management for fitness tracking
enum ActivityState { idle, running, paused, completed }

extension ActivityStateExtension on ActivityState {
  String get displayName {
    switch (this) {
      case ActivityState.idle:
        return 'Ready';
      case ActivityState.running:
        return 'Active';
      case ActivityState.paused:
        return 'Paused';
      case ActivityState.completed:
        return 'Completed';
    }
  }

  bool get isActive => this == ActivityState.running;
  bool get isPaused => this == ActivityState.paused;
  bool get canStart => this == ActivityState.idle;
  bool get canPause => this == ActivityState.running;
  bool get canResume => this == ActivityState.paused;
  bool get canStop =>
      this == ActivityState.running || this == ActivityState.paused;
}

/// Activity type for different workout modes
enum ActivityType { running, walking, cycling, hiking }

extension ActivityTypeExtension on ActivityType {
  String get displayName {
    switch (this) {
      case ActivityType.running:
        return 'Running';
      case ActivityType.walking:
        return 'Walking';
      case ActivityType.cycling:
        return 'Cycling';
      case ActivityType.hiking:
        return 'Hiking';
    }
  }

  String get iconName {
    switch (this) {
      case ActivityType.running:
        return 'directions_run';
      case ActivityType.walking:
        return 'directions_walk';
      case ActivityType.cycling:
        return 'directions_bike';
      case ActivityType.hiking:
        return 'terrain';
    }
  }

  /// Average METs (Metabolic Equivalent of Task) for calorie calculation
  double get averageMets {
    switch (this) {
      case ActivityType.running:
        return 8.0; // ~8 METs for moderate running
      case ActivityType.walking:
        return 3.5; // ~3.5 METs for brisk walking
      case ActivityType.cycling:
        return 6.0; // ~6 METs for leisure cycling
      case ActivityType.hiking:
        return 5.0; // ~5 METs for hiking
    }
  }
}

/// Comprehensive fitness statistics model
class FitnessStats {
  final double totalDistanceMeters;
  final Duration totalDuration;
  final Duration activeDuration;
  final double averageSpeedMps; // meters per second
  final double currentSpeedMps;
  final double maxSpeedMps;
  final double averagePaceSecondsPerKm;
  final double currentPaceSecondsPerKm;
  final int estimatedCalories;
  final DateTime startTime;
  final DateTime? endTime;
  final int totalSteps;
  final double elevationGain;

  const FitnessStats({
    this.totalDistanceMeters = 0.0,
    this.totalDuration = Duration.zero,
    this.activeDuration = Duration.zero,
    this.averageSpeedMps = 0.0,
    this.currentSpeedMps = 0.0,
    this.maxSpeedMps = 0.0,
    this.averagePaceSecondsPerKm = 0.0,
    this.currentPaceSecondsPerKm = 0.0,
    this.estimatedCalories = 0,
    required this.startTime,
    this.endTime,
    this.totalSteps = 0,
    this.elevationGain = 0.0,
  });

  /// Create updated stats with new values
  FitnessStats copyWith({
    double? totalDistanceMeters,
    Duration? totalDuration,
    Duration? activeDuration,
    double? averageSpeedMps,
    double? currentSpeedMps,
    double? maxSpeedMps,
    double? averagePaceSecondsPerKm,
    double? currentPaceSecondsPerKm,
    int? estimatedCalories,
    DateTime? startTime,
    DateTime? endTime,
    int? totalSteps,
    double? elevationGain,
  }) {
    return FitnessStats(
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDuration: totalDuration ?? this.totalDuration,
      activeDuration: activeDuration ?? this.activeDuration,
      averageSpeedMps: averageSpeedMps ?? this.averageSpeedMps,
      currentSpeedMps: currentSpeedMps ?? this.currentSpeedMps,
      maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
      averagePaceSecondsPerKm:
          averagePaceSecondsPerKm ?? this.averagePaceSecondsPerKm,
      currentPaceSecondsPerKm:
          currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalSteps: totalSteps ?? this.totalSteps,
      elevationGain: elevationGain ?? this.elevationGain,
    );
  }

  // Formatted getters for UI display
  String get formattedDistance {
    final km = totalDistanceMeters / 1000;
    return '${km.toStringAsFixed(2)} km';
  }

  String get formattedDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;
    final seconds = totalDuration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedActiveDuration {
    final hours = activeDuration.inHours;
    final minutes = activeDuration.inMinutes % 60;
    final seconds = activeDuration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedAverageSpeed {
    final kmh = averageSpeedMps * 3.6; // Convert m/s to km/h
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  String get formattedCurrentSpeed {
    final kmh = currentSpeedMps * 3.6; // Convert m/s to km/h
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  String get formattedAveragePace {
    if (averagePaceSecondsPerKm <= 0) return '--:--';

    final minutes = (averagePaceSecondsPerKm / 60).floor();
    final seconds = (averagePaceSecondsPerKm % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedCurrentPace {
    if (currentPaceSecondsPerKm <= 0) return '--:--';

    final minutes = (currentPaceSecondsPerKm / 60).floor();
    final seconds = (currentPaceSecondsPerKm % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedCalories => '$estimatedCalories cal';

  String get formattedSteps => totalSteps.toString();

  String get formattedElevation => '${elevationGain.toStringAsFixed(0)} m';

  @override
  String toString() {
    return 'FitnessStats(distance: $formattedDistance, duration: $formattedDuration, pace: $formattedAveragePace)';
  }
}

/// Activity session model for data persistence
class ActivitySession {
  final String id;
  final ActivityType activityType;
  final ActivityState state;
  final FitnessStats stats;
  final List<LatLng> routePoints;
  final List<ActivityWaypoint> waypoints;
  final Map<String, dynamic> metadata;

  const ActivitySession({
    required this.id,
    required this.activityType,
    required this.state,
    required this.stats,
    this.routePoints = const [],
    this.waypoints = const [],
    this.metadata = const {},
  });

  ActivitySession copyWith({
    String? id,
    ActivityType? activityType,
    ActivityState? state,
    FitnessStats? stats,
    List<LatLng>? routePoints,
    List<ActivityWaypoint>? waypoints,
    Map<String, dynamic>? metadata,
  }) {
    return ActivitySession(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      state: state ?? this.state,
      stats: stats ?? this.stats,
      routePoints: routePoints ?? this.routePoints,
      waypoints: waypoints ?? this.waypoints,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityType': activityType.name,
      'state': state.name,
      'totalDistanceMeters': stats.totalDistanceMeters,
      'totalDuration': stats.totalDuration.inMilliseconds,
      'activeDuration': stats.activeDuration.inMilliseconds,
      'averageSpeedMps': stats.averageSpeedMps,
      'maxSpeedMps': stats.maxSpeedMps,
      'estimatedCalories': stats.estimatedCalories,
      'startTime': stats.startTime.toIso8601String(),
      'endTime': stats.endTime?.toIso8601String(),
      'totalSteps': stats.totalSteps,
      'elevationGain': stats.elevationGain,
      'routePoints': routePoints
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
      'waypoints': waypoints.map((wp) => wp.toJson()).toList(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory ActivitySession.fromJson(Map<String, dynamic> json) {
    return ActivitySession(
      id: json['id'],
      activityType: ActivityType.values.firstWhere(
        (type) => type.name == json['activityType'],
        orElse: () => ActivityType.running,
      ),
      state: ActivityState.values.firstWhere(
        (state) => state.name == json['state'],
        orElse: () => ActivityState.completed,
      ),
      stats: FitnessStats(
        totalDistanceMeters: json['totalDistanceMeters']?.toDouble() ?? 0.0,
        totalDuration: Duration(milliseconds: json['totalDuration'] ?? 0),
        activeDuration: Duration(milliseconds: json['activeDuration'] ?? 0),
        averageSpeedMps: json['averageSpeedMps']?.toDouble() ?? 0.0,
        maxSpeedMps: json['maxSpeedMps']?.toDouble() ?? 0.0,
        estimatedCalories: json['estimatedCalories'] ?? 0,
        startTime: DateTime.parse(json['startTime']),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'])
            : null,
        totalSteps: json['totalSteps'] ?? 0,
        elevationGain: json['elevationGain']?.toDouble() ?? 0.0,
      ),
      routePoints:
          (json['routePoints'] as List?)
              ?.map((point) => LatLng(point['lat'], point['lng']))
              .toList() ??
          [],
      waypoints:
          (json['waypoints'] as List?)
              ?.map((wp) => ActivityWaypoint.fromJson(wp))
              .toList() ??
          [],
      metadata: json['metadata'] ?? {},
    );
  }
}

/// Waypoint model for marking special points during activity
class ActivityWaypoint {
  final LatLng location;
  final DateTime timestamp;
  final String type; // 'start', 'pause', 'resume', 'milestone', 'finish'
  final String? note;
  final FitnessStats? statsAtTime;

  const ActivityWaypoint({
    required this.location,
    required this.timestamp,
    required this.type,
    this.note,
    this.statsAtTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'location': {'lat': location.latitude, 'lng': location.longitude},
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'note': note,
      'statsAtTime': statsAtTime != null
          ? {
              'totalDistanceMeters': statsAtTime!.totalDistanceMeters,
              'totalDuration': statsAtTime!.totalDuration.inMilliseconds,
              'averageSpeedMps': statsAtTime!.averageSpeedMps,
            }
          : null,
    };
  }

  factory ActivityWaypoint.fromJson(Map<String, dynamic> json) {
    return ActivityWaypoint(
      location: LatLng(json['location']['lat'], json['location']['lng']),
      timestamp: DateTime.parse(json['timestamp']),
      type: json['type'],
      note: json['note'],
      statsAtTime: json['statsAtTime'] != null
          ? FitnessStats(
              totalDistanceMeters:
                  json['statsAtTime']['totalDistanceMeters']?.toDouble() ?? 0.0,
              totalDuration: Duration(
                milliseconds: json['statsAtTime']['totalDuration'] ?? 0,
              ),
              averageSpeedMps:
                  json['statsAtTime']['averageSpeedMps']?.toDouble() ?? 0.0,
              startTime: DateTime.parse(json['timestamp']),
            )
          : null,
    );
  }
}

/// Goal types for fitness goals
enum GoalType { petrolDieselCar, electricVehicle, motorcycle, train, boat }

/// Goal difficulty levels
enum GoalLevel { easy, hard, extreme }

/// Fitness goal model
class Goal {
  final String id;
  final GoalType type;
  final String title;
  final String description;
  final GoalLevel level;
  final Duration duration;
  final String carbonOffsetPotential; // "Low", "Medium", "High"
  final double co2PerKm;
  final IconData icon;
  final String? image;
  final bool isSelected;

  const Goal({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.level,
    required this.duration,
    required this.carbonOffsetPotential,
    required this.co2PerKm,
    required this.icon,
    this.image,
    this.isSelected = false,
  });

  Goal copyWith({
    String? id,
    GoalType? type,
    String? title,
    String? description,
    GoalLevel? level,
    Duration? duration,
    String? carbonOffsetPotential,
    double? co2PerKm,
    IconData? icon,
    String? image,
    bool? isSelected,
  }) {
    return Goal(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      level: level ?? this.level,
      duration: duration ?? this.duration,
      carbonOffsetPotential: carbonOffsetPotential ?? this.carbonOffsetPotential,
      co2PerKm: co2PerKm ?? this.co2PerKm,
      icon: icon ?? this.icon,
      image: image ?? this.image,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  String get levelText {
    switch (level) {
      case GoalLevel.easy:
        return 'Easy';
      case GoalLevel.hard:
        return 'Hard';
      case GoalLevel.extreme:
        return 'Extreme';
    }
  }

  String get durationText {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

/// Sample goals for the app
final List<Goal> sampleGoals = [
  Goal(
    id: 'petrol_diesel_car',
    type: GoalType.petrolDieselCar,
    title: 'Petrol/Diesel Car',
    description:
        'Track your carbon footprint from driving a conventional petrol or diesel car.',
    level: GoalLevel.easy,
    duration: const Duration(minutes: 30),
    carbonOffsetPotential: 'High',
    co2PerKm: 0.171,
    icon: Icons.directions_car,
  ),
  Goal(
    id: 'electric_vehicle',
    type: GoalType.electricVehicle,
    title: 'Electric Vehicle',
    description:
        'Compare the environmental impact of driving an electric vehicle versus conventional cars.',
    level: GoalLevel.hard,
    duration: const Duration(minutes: 45),
    carbonOffsetPotential: 'Medium',
    co2PerKm: 0.051,
    icon: Icons.ev_station,
  ),
  Goal(
    id: 'motorcycle',
    type: GoalType.motorcycle,
    title: 'Motorcycle',
    description:
        'Track the emissions and environmental impact of riding a motorcycle.',
    level: GoalLevel.easy,
    duration: const Duration(minutes: 40),
    carbonOffsetPotential: 'Medium',
    co2PerKm: 0.103,
    icon: Icons.motorcycle,
  ),
  Goal(
    id: 'train',
    type: GoalType.train,
    title: 'Train',
    description:
        'See how your train commute compares to other methods of transportation.',
    level: GoalLevel.extreme,
    duration: const Duration(hours: 2),
    carbonOffsetPotential: 'Low',
    co2PerKm: 0.041,
    icon: Icons.train,
  ),
  Goal(
    id: 'boat',
    type: GoalType.boat,
    title: 'Boat',
    description:
        'Track the carbon emissions from boat travel and water transportation.',
    level: GoalLevel.hard,
    duration: const Duration(minutes: 25),
    carbonOffsetPotential: 'High',
    co2PerKm: 0.267,
    icon: Icons.directions_boat,
  ),
];
