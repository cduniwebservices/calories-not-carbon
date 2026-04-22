import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Activity state management for fitness tracking
enum ActivityState { idle, warmingUp, running, paused, completed }

extension ActivityStateExtension on ActivityState {
  String get displayName {
    switch (this) {
      case ActivityState.idle:
        return 'Idle';
      case ActivityState.warmingUp:
        return 'GPS Stabilizing';
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
      case ActivityState.warmingUp:
        return Colors.amber;
      case ActivityState.running:
        return Colors.green;
      case ActivityState.paused:
        return Colors.orange;
      case ActivityState.completed:
        return Colors.blue;
    }
  }

  bool get isActive =>
      this == ActivityState.warmingUp ||
      this == ActivityState.running ||
      this == ActivityState.paused;
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
  final Duration movingDuration;
  final Duration stationaryDuration;
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
  final double altitude;

  const FitnessStats({
    this.totalDistanceMeters = 0.0,
    this.totalDuration = Duration.zero,
    this.activeDuration = Duration.zero,
    this.movingDuration = Duration.zero,
    this.stationaryDuration = Duration.zero,
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
    this.altitude = 0.0,
  });

  FitnessStats copyWith({
    double? totalDistanceMeters,
    Duration? totalDuration,
    Duration? activeDuration,
    Duration? movingDuration,
    Duration? stationaryDuration,
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
    double? altitude,
  }) {
    return FitnessStats(
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDuration: totalDuration ?? this.totalDuration,
      activeDuration: activeDuration ?? this.activeDuration,
      movingDuration: movingDuration ?? this.movingDuration,
      stationaryDuration: stationaryDuration ?? this.stationaryDuration,
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
      altitude: altitude ?? this.altitude,
    );
  }

  String get formattedDistance {
    return '${(totalDistanceMeters / 1000).toStringAsFixed(2)} km';
  }

  String get formattedDuration {
    final hours = activeDuration.inHours;
    final minutes = activeDuration.inMinutes % 60;
    final seconds = activeDuration.inSeconds % 60;
    
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    
    if (hours > 0) {
      return '$hours:$minutesStr:$secondsStr';
    }
    return '$minutesStr:$secondsStr';
  }

  String get formattedActiveDuration => formattedDuration;

  String get formattedAveragePace {
    if (averagePaceSecondsPerKm == 0 || averagePaceSecondsPerKm.isInfinite) {
      return "--'--\"";
    }
    final mins = averagePaceSecondsPerKm ~/ 60;
    final secs = (averagePaceSecondsPerKm % 60).toInt();
    return "${mins.toString()}'${secs.toString().padLeft(2, '0')}\"";
  }

  String get formattedCurrentPace {
    if (currentPaceSecondsPerKm == 0 || currentPaceSecondsPerKm.isInfinite) {
      return "--'--\"";
    }
    final mins = currentPaceSecondsPerKm ~/ 60;
    final secs = (currentPaceSecondsPerKm % 60).toInt();
    return "${mins.toString()}'${secs.toString().padLeft(2, '0')}\"";
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
      isEu: json['is_eu']?.toString().toLowerCase() == 'true',
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
  final bool isValid;
  final String? activityReplaced;
  final WeatherData? startWeather;
  final IpLookupData? startIpLookup;
  final bool isSynced;
  final DateTime? createdAt;
  final DateTime? syncedAt;
  final DateTime? lastSyncAttempt;

  const ActivitySession({
    required this.id,
    required this.activityType,
    required this.state,
    required this.stats,
    this.routePoints = const [],
    this.waypoints = const [],
    this.isValid = true,
    this.activityReplaced,
    this.startWeather,
    this.startIpLookup,
    this.isSynced = false,
    this.createdAt,
    this.syncedAt,
    this.lastSyncAttempt,
  });

  ActivitySession copyWith({
    String? id,
    ActivityType? activityType,
    ActivityState? state,
    FitnessStats? stats,
    List<LatLng>? routePoints,
    List<ActivityWaypoint>? waypoints,
    bool? isValid,
    String? activityReplaced,
    WeatherData? startWeather,
    IpLookupData? startIpLookup,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? syncedAt,
    DateTime? lastSyncAttempt,
  }) {
    return ActivitySession(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      state: state ?? this.state,
      stats: stats ?? this.stats,
      routePoints: routePoints ?? this.routePoints,
      waypoints: waypoints ?? this.waypoints,
      isValid: isValid ?? this.isValid,
      activityReplaced: activityReplaced ?? this.activityReplaced,
      startWeather: startWeather ?? this.startWeather,
      startIpLookup: startIpLookup ?? this.startIpLookup,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityType': activityType.name,
      'activityReplaced': activityReplaced,
      'state': state.name,
      'isValid': isValid,
      'totalDistanceMeters': stats.totalDistanceMeters,
      'totalDuration': stats.totalDuration.inMilliseconds,
      'activeDuration': stats.activeDuration.inMilliseconds,
      'movingDuration': stats.movingDuration.inMilliseconds,
      'stationaryDuration': stats.stationaryDuration.inMilliseconds,
      'averageSpeedMps': stats.averageSpeedMps,
      'currentSpeedMps': stats.currentSpeedMps,
      'maxSpeedMps': stats.maxSpeedMps,
      'averagePaceSecondsPerKm': stats.averagePaceSecondsPerKm,
      'currentPaceSecondsPerKm': stats.currentPaceSecondsPerKm,
      'estimatedCalories': stats.estimatedCalories,
      'startTime': stats.startTime.toIso8601String(),
      'endTime': stats.endTime?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
      'totalSteps': stats.totalSteps,
      'elevationGain': stats.elevationGain,
      'startIpLookup': startIpLookup?.toJson(),
      'startWeather': startWeather?.toJson(),
      // Store rich waypoints data in the routePoints field for high fidelity
      'routePoints': waypoints.map((wp) => wp.toJson()).toList(),
      'isSynced': isSynced,
      'lastSyncAttempt': lastSyncAttempt?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory ActivitySession.fromJson(Map<String, dynamic> json) {
    final rawRoute = (json['routePoints'] ?? json['route_points']) as List? ?? [];
    
    // Determine if we have rich waypoint data or just simple coordinates
    List<ActivityWaypoint> parsedWaypoints = [];
    List<LatLng> parsedCoords = [];

    if (rawRoute.isNotEmpty) {
      if (rawRoute.first is Map && (rawRoute.first as Map).containsKey('location')) {
        // High fidelity format (waypoints)
        parsedWaypoints = rawRoute.map((wp) => ActivityWaypoint.fromJson(wp as Map<String, dynamic>)).toList();
        parsedCoords = parsedWaypoints.map((wp) => wp.location).toList();
      } else {
        // Legacy/simple format (LatLng only)
        parsedCoords = rawRoute
            .map((point) => LatLng(
                (point['lat'] ?? point['latitude']) as double,
                (point['lng'] ?? point['longitude']) as double))
            .toList();
      }
    }

    return ActivitySession(
      id: json['id'] as String,
      activityType: ActivityType.values.firstWhere(
        (type) => type.name == (json['activityType'] ?? json['activity_type']),
        orElse: () => ActivityType.running,
      ),
      state: ActivityState.values.firstWhere(
        (state) => state.name == json['state'],
        orElse: () => ActivityState.completed,
      ),
      stats: FitnessStats(
        totalDistanceMeters: (json['totalDistanceMeters'] ?? json['total_distance_meters'])?.toDouble() ?? 0.0,
        totalDuration: Duration(milliseconds: json['totalDuration'] ?? json['total_duration_ms'] ?? 0),
        activeDuration: Duration(milliseconds: json['activeDuration'] ?? json['active_duration_ms'] ?? 0),
        movingDuration: Duration(milliseconds: json['movingDuration'] ?? json['moving_duration_ms'] ?? 0),
        stationaryDuration: Duration(milliseconds: json['stationaryDuration'] ?? json['stationary_duration_ms'] ?? 0),
        averageSpeedMps: (json['averageSpeedMps'] ?? json['average_speed_mps'])?.toDouble() ?? 0.0,
        currentSpeedMps: (json['currentSpeedMps'] ?? json['current_speed_mps'])?.toDouble() ?? 0.0,
        maxSpeedMps: (json['maxSpeedMps'] ?? json['max_speed_mps'])?.toDouble() ?? 0.0,
        averagePaceSecondsPerKm: (json['averagePaceSecondsPerKm'] ?? json['average_pace_seconds_per_km'])?.toDouble() ?? 0.0,
        currentPaceSecondsPerKm: (json['currentPaceSecondsPerKm'] ?? json['current_pace_seconds_per_km'])?.toDouble() ?? 0.0,
        estimatedCalories: json['estimatedCalories'] ?? json['estimated_calories'] ?? 0,
        startTime: DateTime.parse((json['startTime'] ?? json['start_time']) as String),
        endTime: (json['endTime'] ?? json['end_time']) != null
            ? DateTime.parse((json['endTime'] ?? json['end_time']) as String)
            : null,
        totalSteps: json['totalSteps'] ?? json['total_steps'] ?? 0,
        elevationGain: (json['elevationGain'] ?? json['elevation_gain'])?.toDouble() ?? 0.0,
      ),
      routePoints: parsedCoords,
      waypoints: parsedWaypoints,
      isValid: json['isValid'] ?? json['is_valid'] ?? true,
      activityReplaced: json['activityReplaced'] ?? json['activity_replaced'] as String?,
      startWeather: (json['startWeather'] ?? json['start_weather']) != null 
          ? WeatherData.fromJson((json['startWeather'] ?? json['start_weather']) as Map<String, dynamic>) 
          : null,
      startIpLookup: (json['startIpLookup'] ?? json['start_ip_lookup']) != null 
          ? IpLookupData.fromJson((json['startIpLookup'] ?? json['start_ip_lookup']) as Map<String, dynamic>) 
          : null,
      isSynced: json['isSynced'] ?? json['is_synced'] ?? (json['metadata']?['synced'] == true),
      createdAt: (json['createdAt'] ?? json['created_at']) != null
          ? DateTime.parse((json['createdAt'] ?? json['created_at']) as String)
          : null,
      syncedAt: (json['syncedAt'] ?? json['synced_at'] ?? json['metadata']?['synced_at']) != null
          ? DateTime.parse((json['syncedAt'] ?? json['synced_at'] ?? json['metadata']?['synced_at']) as String)
          : null,
      lastSyncAttempt: (json['lastSyncAttempt'] ?? json['last_sync_attempt'] ?? json['metadata']?['last_sync_attempt']) != null
          ? DateTime.parse((json['lastSyncAttempt'] ?? json['last_sync_attempt'] ?? json['metadata']?['last_sync_attempt']) as String)
          : null,
    );
  }
}

/// Waypoint model for marking special points during activity
class ActivityWaypoint {
  final LatLng location;
  final DateTime timestamp;
  final String type; // 'start', 'pause', 'resume', 'milestone', 'finish', 'track_point'
  final FitnessStats? statsAtTime;
  final double? altitude;

  const ActivityWaypoint({
    required this.location,
    required this.timestamp,
    required this.type,
    this.statsAtTime,
    this.altitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'location': {'lat': location.latitude, 'lng': location.longitude},
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'altitude': altitude,
      'statsAtTime': statsAtTime != null
          ? {
              'totalDistanceMeters': statsAtTime!.totalDistanceMeters,
              'totalDuration': statsAtTime!.totalDuration.inMilliseconds,
              'activeDuration': statsAtTime!.activeDuration.inMilliseconds,
              'movingDuration': statsAtTime!.movingDuration.inMilliseconds,
              'stationaryDuration': statsAtTime!.stationaryDuration.inMilliseconds,
              'averageSpeedMps': statsAtTime!.averageSpeedMps,
              'currentSpeedMps': statsAtTime!.currentSpeedMps,
              'totalSteps': statsAtTime!.totalSteps,
              'elevationGain': statsAtTime!.elevationGain,
            }
          : null,
    };
  }

  factory ActivityWaypoint.fromJson(Map<String, dynamic> json) {
    final locationMap = json['location'] as Map<String, dynamic>;
    final statsJson = json['statsAtTime'] as Map<String, dynamic>?;

    return ActivityWaypoint(
      location: LatLng(
        (locationMap['lat'] ?? locationMap['latitude'])?.toDouble() ?? 0.0,
        (locationMap['lng'] ?? locationMap['longitude'])?.toDouble() ?? 0.0,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: json['type'] as String,
      altitude: json['altitude']?.toDouble(),
      statsAtTime: statsJson != null
          ? FitnessStats(
              totalDistanceMeters: (statsJson['totalDistanceMeters'] ??
                      statsJson['total_distance_meters'])
                  ?.toDouble() ??
                  0.0,
              totalDuration: Duration(
                milliseconds: statsJson['totalDuration'] ??
                    statsJson['total_duration_ms'] ??
                    0,
              ),
              activeDuration: Duration(
                milliseconds: statsJson['activeDuration'] ??
                    statsJson['active_duration_ms'] ??
                    0,
              ),
              movingDuration: Duration(
                milliseconds: statsJson['movingDuration'] ??
                    statsJson['moving_duration_ms'] ??
                    0,
              ),
              stationaryDuration: Duration(
                milliseconds: statsJson['stationaryDuration'] ??
                    statsJson['stationary_duration_ms'] ??
                    0,
              ),
              averageSpeedMps: (statsJson['averageSpeedMps'] ??
                      statsJson['average_speed_mps'])
                  ?.toDouble() ??
                  0.0,
              currentSpeedMps: (statsJson['currentSpeedMps'] ??
                      statsJson['current_speed_mps'])
                  ?.toDouble() ??
                  0.0,
              totalSteps: statsJson['totalSteps'] ?? statsJson['total_steps'] ?? 0,
              elevationGain: (statsJson['elevationGain'] ??
                      statsJson['elevation_gain'])
                  ?.toDouble() ??
                  0.0,
              startTime: DateTime.parse(json['timestamp'] as String),
            )
          : null,
    );
  }
}

/// Goal types available in the application
enum GoalType { petrolDieselCar, electricVehicle, motorcycle, train, boat }

extension GoalTypeExtension on GoalType {
  String get displayName {
    switch (this) {
      case GoalType.petrolDieselCar:
        return 'Petrol/Diesel Car';
      case GoalType.electricVehicle:
        return 'Electric Vehicle';
      case GoalType.motorcycle:
        return 'Motorcycle';
      case GoalType.train:
        return 'Train';
      case GoalType.boat:
        return 'Boat/Ferry';
    }
  }
}

/// Goal level difficulty
enum GoalLevel { easy, hard, extreme }

/// Model for travel mode/carbon offset goals
class Goal {
  final String id;
  final GoalType type;
  final String title;
  final String tagline;
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
    required this.tagline,
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
    String? tagline,
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
      tagline: tagline ?? this.tagline,
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

/// GPS stabilization state for warm-up phase
class GpsStabilizationState {
  final bool isStabilizing;
  final bool isStable;
  final double? currentAltitude;
  final double? currentSpeed;
  final double? altitudeVariance;
  final double? speedVariance;
  final int stableReadingsCount;
  final int requiredStableReadings;
  final double gpsAccuracy;
  final String? stabilityMessage;

  const GpsStabilizationState({
    this.isStabilizing = false,
    this.isStable = false,
    this.currentAltitude,
    this.currentSpeed,
    this.altitudeVariance,
    this.speedVariance,
    this.stableReadingsCount = 0,
    this.requiredStableReadings = 5,
    this.gpsAccuracy = double.infinity,
    this.stabilityMessage,
  });

  GpsStabilizationState copyWith({
    bool? isStabilizing,
    bool? isStable,
    double? currentAltitude,
    double? currentSpeed,
    double? altitudeVariance,
    double? speedVariance,
    int? stableReadingsCount,
    int? requiredStableReadings,
    double? gpsAccuracy,
    String? stabilityMessage,
  }) {
    return GpsStabilizationState(
      isStabilizing: isStabilizing ?? this.isStabilizing,
      isStable: isStable ?? this.isStable,
      currentAltitude: currentAltitude ?? this.currentAltitude,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      altitudeVariance: altitudeVariance ?? this.altitudeVariance,
      speedVariance: speedVariance ?? this.speedVariance,
      stableReadingsCount: stableReadingsCount ?? this.stableReadingsCount,
      requiredStableReadings: requiredStableReadings ?? this.requiredStableReadings,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      stabilityMessage: stabilityMessage ?? this.stabilityMessage,
    );
  }

  /// Progress percentage (0.0 to 1.0)
  double get progress => stableReadingsCount / requiredStableReadings;
}

/// Default travel modes for carbon calculation
final List<Goal> defaultGoals = [
  Goal(
    id: 'petrol_diesel_car',
    type: GoalType.petrolDieselCar,
    title: GoalType.petrolDieselCar.displayName,
    tagline: 'Step out, drive less...',
    description:
        'Conventional internal combustion engines are a primary source of individual carbon emissions. By tracking your activity against this mode, you can visualize the significant volume of CO₂ prevented by choosing active transport. This goal helps highlight the direct environmental benefit of leaving your car at home for short trips.',
    level: GoalLevel.easy,
    duration: const Duration(minutes: 30),
    carbonOffsetPotential: 'High',
    co2PerKm: 0.171,
    icon: Icons.directions_car,
  ),
  Goal(
    id: 'electric_vehicle',
    type: GoalType.electricVehicle,
    title: GoalType.electricVehicle.displayName,
    tagline: 'Better than batteries...',
    description:
        'Electric vehicles offer a cleaner alternative to fossil fuels, but they still carry an environmental footprint from manufacturing and energy production. Tracking against an EV helps you understand the nuance of modern sustainable travel. Even when compared to clean tech, walking or cycling remains the most effective way to reduce your personal impact.',
    level: GoalLevel.hard,
    duration: const Duration(minutes: 45),
    carbonOffsetPotential: 'Medium',
    co2PerKm: 0.051,
    icon: Icons.ev_station,
  ),
  Goal(
    id: 'motorcycle',
    type: GoalType.motorcycle,
    title: GoalType.motorcycle.displayName,
    tagline: 'Pure human power...',
    description:
        'While motorcycles are often more fuel-efficient than cars, they still contribute to local air pollution and carbon levels. This mode represents a middle ground in motorized transport emissions. By choosing to walk instead, you are making a positive choice for both global carbon reduction and local urban air quality.',
    level: GoalLevel.easy,
    duration: const Duration(minutes: 40),
    carbonOffsetPotential: 'Medium',
    co2PerKm: 0.103,
    icon: Icons.motorcycle,
  ),
  Goal(
    id: 'train',
    type: GoalType.train,
    title: GoalType.train.displayName,
    tagline: 'Your own pace...',
    description:
        'Rail travel is one of the most efficient forms of mass transit, moving large numbers of people with a relatively low per-person footprint. Tracking your walk as a replacement for a train trip shows your commitment to the lowest possible emission tiers. It helps quantify the final step in achieving a truly zero-carbon commute.',
    level: GoalLevel.extreme,
    duration: const Duration(hours: 2),
    carbonOffsetPotential: 'Low',
    co2PerKm: 0.041,
    icon: Icons.train,
  ),
  Goal(
    id: 'boat',
    type: GoalType.boat,
    title: GoalType.boat.displayName,
    tagline: 'Explore on foot...',
    description:
        'Marine transport can be surprisingly carbon-intensive depending on the vessel type and fuel efficiency. Tracking emissions from water-based travel highlights often-overlooked sources of carbon in coastal or river regions. Replacing these trips with active land-based routes can lead to substantial and measurable carbon savings.',
    level: GoalLevel.hard,
    duration: const Duration(minutes: 25),
    carbonOffsetPotential: 'High',
    co2PerKm: 0.267,
    icon: Icons.directions_boat,
  ),
];
