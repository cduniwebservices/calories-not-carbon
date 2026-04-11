import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Activity state management for fitness tracking
enum ActivityState { idle, running, paused, completed }

extension ActivityStateExtension on ActivityState {
  String get displayName {
    switch (this) {
      case ActivityState.idle:
        return 'Idle';
      case ActivityState.running:
        return 'In Progress';
      case ActivityState.paused:
        return 'Paused';
      case ActivityState.completed:
        return 'Completed';
    }
  }

  Color get color {
    switch (this) {
      case ActivityState.idle:
        return Colors.grey;
      case ActivityState.running:
        return Colors.green;
      case ActivityState.paused:
        return Colors.orange;
      case ActivityState.completed:
        return Colors.blue;
    }
  }

  bool get isActive =>
      this == ActivityState.running || this == ActivityState.paused;
}

/// Activity types available for tracking
enum ActivityType { walking, running, cycling, hiking }

extension ActivityTypeExtension on ActivityType {
  String get displayName {
    switch (this) {
      case ActivityType.walking:
        return 'Walking';
      case ActivityType.running:
        return 'Running';
      case ActivityType.cycling:
        return 'Cycling';
      case ActivityType.hiking:
        return 'Hiking';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityType.walking:
        return Icons.directions_walk;
      case ActivityType.running:
        return Icons.directions_run;
      case ActivityType.cycling:
        return Icons.directions_bike;
      case ActivityType.hiking:
        return Icons.terrain;
    }
  }

  /// Average Metabolic Equivalent of Task (MET) for each activity
  double get averageMets {
    switch (this) {
      case ActivityType.walking:
        return 3.5;
      case ActivityType.running:
        return 8.0;
      case ActivityType.cycling:
        return 6.0;
      case ActivityType.hiking:
        return 5.0;
    }
  }
}

/// Core fitness statistics for a session
class FitnessStats {
  final double totalDistanceMeters;
  final Duration totalDuration;
  final Duration activeDuration;
  final double averageSpeedMps;
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

  String get formattedDistance {
    if (totalDistanceMeters >= 1000) {
      return '${(totalDistanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${totalDistanceMeters.toStringAsFixed(0)} m';
  }

  String get formattedDuration {
    final minutes = activeDuration.inMinutes;
    final seconds = activeDuration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedActiveDuration => formattedDuration;

  String get formattedAveragePace {
    if (averagePaceSecondsPerKm == 0 || averagePaceSecondsPerKm.isInfinite) {
      return '--:-- /km';
    }
    final mins = averagePaceSecondsPerKm ~/ 60;
    final secs = (averagePaceSecondsPerKm % 60).toInt();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')} /km';
  }

  String get formattedCurrentPace {
    if (currentPaceSecondsPerKm == 0 || currentPaceSecondsPerKm.isInfinite) {
      return '--:-- /km';
    }
    final mins = currentPaceSecondsPerKm ~/ 60;
    final secs = (currentPaceSecondsPerKm % 60).toInt();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')} /km';
  }

  String get formattedCurrentSpeed =>
      '${(currentSpeedMps * 3.6).toStringAsFixed(1)} km/h';

  String get formattedSteps => totalSteps.toString();

  String get formattedElevation => '${elevationGain.toStringAsFixed(1)} m';

  String get formattedCalories => estimatedCalories.toString();

  @override
  String toString() {
    return 'FitnessStats(distance: $formattedDistance, duration: $formattedDuration, pace: $formattedAveragePace)';
  }
}

/// Location details from the weather service
class WeatherLocation {
  final String name;
  final String region;
  final String country;
  final String tzId;
  final int localtimeEpoch;
  final String localtime;
  final String utcOffset;

  const WeatherLocation({
    required this.name,
    required this.region,
    required this.country,
    required this.tzId,
    required this.localtimeEpoch,
    required this.localtime,
    required this.utcOffset,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'region': region,
      'country': country,
      'tz_id': tzId,
      'localtime_epoch': localtimeEpoch,
      'localtime': localtime,
      'utc_offset': utcOffset,
    };
  }

  factory WeatherLocation.fromJson(Map<String, dynamic> json) {
    return WeatherLocation(
      name: json['name'] as String? ?? '',
      region: json['region'] as String? ?? '',
      country: json['country'] as String? ?? '',
      tzId: json['tz_id'] as String? ?? '',
      localtimeEpoch: json['localtime_epoch'] as int? ?? 0,
      localtime: json['localtime'] as String? ?? '',
      utcOffset: json['utc_offset'] as String? ?? '',
    );
  }
}

/// Weather data at a specific point in time
class WeatherData {
  final WeatherLocation? location;
  final String lastUpdated;
  final int lastUpdatedEpoch;
  final double tempC;
  final int isDay;
  final String conditionText;
  final String conditionIcon;
  final int conditionCode;
  final double windKph;
  final int windDegree;
  final String windDir;
  final double pressureMb;
  final double precipMm;
  final int humidity;
  final int cloud;
  final double feelsLikeC;
  final double windChillC;
  final double heatIndexC;
  final double dewPointC;
  final double visKm;
  final double uv;
  final double gustKph;

  const WeatherData({
    this.location,
    required this.lastUpdated,
    required this.lastUpdatedEpoch,
    required this.tempC,
    required this.isDay,
    required this.conditionText,
    required this.conditionIcon,
    required this.conditionCode,
    required this.windKph,
    required this.windDegree,
    required this.windDir,
    required this.pressureMb,
    required this.precipMm,
    required this.humidity,
    required this.cloud,
    required this.feelsLikeC,
    required this.windChillC,
    required this.heatIndexC,
    required this.dewPointC,
    required this.visKm,
    required this.uv,
    required this.gustKph,
  });

  Map<String, dynamic> toJson() {
    return {
      'location': location?.toJson(),
      'last_updated': lastUpdated,
      'last_updated_epoch': lastUpdatedEpoch,
      'temp_c': tempC,
      'is_day': isDay,
      'condition_text': conditionText,
      'condition_icon': conditionIcon,
      'condition_code': conditionCode,
      'wind_kph': windKph,
      'wind_degree': windDegree,
      'wind_dir': windDir,
      'pressure_mb': pressureMb,
      'precip_mm': precipMm,
      'humidity': humidity,
      'cloud': cloud,
      'feelslike_c': feelsLikeC,
      'windchill_c': windChillC,
      'heatindex_c': heatIndexC,
      'dewpoint_c': dewPointC,
      'vis_km': visKm,
      'uv': uv,
      'gust_kph': gustKph,
    };
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      location: json['location'] != null ? WeatherLocation.fromJson(json['location']) : null,
      lastUpdated: json['last_updated'] as String? ?? '',
      lastUpdatedEpoch: json['last_updated_epoch'] as int? ?? 0,
      tempC: (json['temp_c'] as num? ?? 0).toDouble(),
      isDay: json['is_day'] as int? ?? 0,
      conditionText: json['condition_text'] as String? ?? '',
      conditionIcon: json['condition_icon'] as String? ?? '',
      conditionCode: json['condition_code'] as int? ?? 0,
      windKph: (json['wind_kph'] as num? ?? 0).toDouble(),
      windDegree: json['wind_degree'] as int? ?? 0,
      windDir: json['wind_dir'] as String? ?? '',
      pressureMb: (json['pressure_mb'] as num? ?? 0).toDouble(),
      precipMm: (json['precip_mm'] as num? ?? 0).toDouble(),
      humidity: json['humidity'] as int? ?? 0,
      cloud: json['cloud'] as int? ?? 0,
      feelsLikeC: (json['feelslike_c'] as num? ?? 0).toDouble(),
      windChillC: (json['windchill_c'] as num? ?? 0).toDouble(),
      heatIndexC: (json['heatindex_c'] as num? ?? 0).toDouble(),
      dewPointC: (json['dewpoint_c'] as num? ?? 0).toDouble(),
      visKm: (json['vis_km'] as num? ?? 0).toDouble(),
      uv: (json['uv'] as num? ?? 0).toDouble(),
      gustKph: (json['gust_kph'] as num? ?? 0).toDouble(),
    );
  }
}

/// IP lookup data for security verification
class IpLookupData {
  final String ip;
  final String type;
  final String continentCode;
  final String continentName;
  final String countryCode;
  final String countryName;
  final bool isEu;
  final int geonameId;
  final String city;
  final String region;

  const IpLookupData({
    required this.ip,
    required this.type,
    required this.continentCode,
    required this.continentName,
    required this.countryCode,
    required this.countryName,
    required this.isEu,
    required this.geonameId,
    required this.city,
    required this.region,
  });

  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'type': type,
      'continent_code': continentCode,
      'continent_name': continentName,
      'country_code': countryCode,
      'country_name': countryName,
      'is_eu': isEu,
      'geoname_id': geonameId,
      'city': city,
      'region': region,
    };
  }

  factory IpLookupData.fromJson(Map<String, dynamic> json) {
    return IpLookupData(
      ip: json['ip'] as String? ?? '',
      type: json['type'] as String? ?? '',
      continentCode: json['continent_code'] as String? ?? '',
      continentName: json['continent_name'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '',
      countryName: json['country_name'] as String? ?? '',
      isEu: json['is_eu'] as bool? ?? false,
      geonameId: json['geoname_id'] as int? ?? 0,
      city: json['city'] as String? ?? '',
      region: json['region'] as String? ?? '',
    );
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
  final bool isValid;
  final String? activityReplaced;
  final WeatherData? startWeather;
  final IpLookupData? startIpLookup;

  const ActivitySession({
    required this.id,
    required this.activityType,
    required this.state,
    required this.stats,
    this.routePoints = const [],
    this.waypoints = const [],
    this.metadata = const {},
    this.isValid = true,
    this.activityReplaced,
    this.startWeather,
    this.startIpLookup,
  });

  bool get isSynced => metadata['synced'] == true;

  ActivitySession copyWith({
    String? id,
    ActivityType? activityType,
    ActivityState? state,
    FitnessStats? stats,
    List<LatLng>? routePoints,
    List<ActivityWaypoint>? waypoints,
    Map<String, dynamic>? metadata,
    bool? isValid,
    String? activityReplaced,
    WeatherData? startWeather,
    IpLookupData? startIpLookup,
  }) {
    return ActivitySession(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      state: state ?? this.state,
      stats: stats ?? this.stats,
      routePoints: routePoints ?? this.routePoints,
      waypoints: waypoints ?? this.waypoints,
      metadata: metadata ?? this.metadata,
      isValid: isValid ?? this.isValid,
      activityReplaced: activityReplaced ?? this.activityReplaced,
      startWeather: startWeather ?? this.startWeather,
      startIpLookup: startIpLookup ?? this.startIpLookup,
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
      'currentSpeedMps': stats.currentSpeedMps,
      'maxSpeedMps': stats.maxSpeedMps,
      'averagePaceSecondsPerKm': stats.averagePaceSecondsPerKm,
      'currentPaceSecondsPerKm': stats.currentPaceSecondsPerKm,
      'estimatedCalories': stats.estimatedCalories,
      'startTime': stats.startTime.toIso8601String(),
      'endTime': stats.endTime?.toIso8601String(),
      'totalSteps': stats.totalSteps,
      'elevationGain': stats.elevationGain,
      'isValid': isValid,
      'activityReplaced': activityReplaced,
      'startWeather': startWeather?.toJson(),
      'startIpLookup': startIpLookup?.toJson(),
      // Store rich waypoints data in the routePoints field for high fidelity
      'routePoints': waypoints.map((wp) => wp.toJson()).toList(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory ActivitySession.fromJson(Map<String, dynamic> json) {
    final rawRoute = json['routePoints'] as List? ?? [];
    
    // Determine if we have rich waypoint data or just simple coordinates
    List<ActivityWaypoint> parsedWaypoints = [];
    List<LatLng> parsedCoords = [];

    if (rawRoute.isNotEmpty) {
      if (rawRoute.first is Map && rawRoute.first.containsKey('location')) {
        // High fidelity format (waypoints)
        parsedWaypoints = rawRoute.map((wp) => ActivityWaypoint.fromJson(wp)).toList();
        parsedCoords = parsedWaypoints.map((wp) => wp.location).toList();
      } else {
        // Legacy/simple format (LatLng only)
        parsedCoords = rawRoute
            .map((point) => LatLng(point['lat'], point['lng']))
            .toList();
      }
    }

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
        currentSpeedMps: json['currentSpeedMps']?.toDouble() ?? 0.0,
        maxSpeedMps: json['maxSpeedMps']?.toDouble() ?? 0.0,
        averagePaceSecondsPerKm: json['averagePaceSecondsPerKm']?.toDouble() ?? 0.0,
        currentPaceSecondsPerKm: json['currentPaceSecondsPerKm']?.toDouble() ?? 0.0,
        estimatedCalories: json['estimatedCalories'] ?? 0,
        startTime: DateTime.parse(json['startTime']),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'])
            : null,
        totalSteps: json['totalSteps'] ?? 0,
        elevationGain: json['elevationGain']?.toDouble() ?? 0.0,
      ),
      routePoints: parsedCoords,
      waypoints: parsedWaypoints,
      metadata: json['metadata'] ?? {},
      isValid: json['isValid'] ?? true,
      activityReplaced: json['activityReplaced'],
      startWeather: json['startWeather'] != null ? WeatherData.fromJson(json['startWeather']) : null,
      startIpLookup: json['startIpLookup'] != null ? IpLookupData.fromJson(json['startIpLookup']) : null,
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
  final double? altitude;

  const ActivityWaypoint({
    required this.location,
    required this.timestamp,
    required this.type,
    this.note,
    this.statsAtTime,
    this.altitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'location': {'lat': location.latitude, 'lng': location.longitude},
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'note': note,
      'altitude': altitude,
      'statsAtTime': statsAtTime != null
          ? {
              'totalDistanceMeters': statsAtTime!.totalDistanceMeters,
              'totalDuration': statsAtTime!.totalDuration.inMilliseconds,
              'averageSpeedMps': statsAtTime!.averageSpeedMps,
              'currentSpeedMps': statsAtTime!.currentSpeedMps,
              'elevationGain': statsAtTime!.elevationGain,
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
      altitude: json['altitude']?.toDouble(),
      statsAtTime: json['statsAtTime'] != null
          ? FitnessStats(
              totalDistanceMeters:
                  json['statsAtTime']['totalDistanceMeters']?.toDouble() ?? 0.0,
              totalDuration: Duration(
                milliseconds: json['statsAtTime']['totalDuration'] ?? 0,
              ),
              averageSpeedMps:
                  json['statsAtTime']['averageSpeedMps']?.toDouble() ?? 0.0,
              currentSpeedMps:
                  json['statsAtTime']['currentSpeedMps']?.toDouble() ?? 0.0,
              elevationGain:
                  json['statsAtTime']['elevationGain']?.toDouble() ?? 0.0,
              startTime: DateTime.parse(json['timestamp']),
            )
          : null,
    );
  }
}

/// Goal types available in the application
enum GoalType { petrolDieselCar, electricVehicle, motorcycle, train, boat }

/// Goal level difficulty
enum GoalLevel { easy, hard, extreme }

/// Model for travel mode/carbon offset goals
class Goal {
  final String id;
  final GoalType type;
  final String title;
  final String description;
  final GoalLevel level;
  final Duration duration;
  final String carbonOffsetPotential;
  final double co2PerKm; // kg CO2 per km
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

/// Default travel modes for carbon calculation
final List<Goal> defaultGoals = [
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
