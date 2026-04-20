import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../models/fitness_models.dart';
import 'enterprise_logger.dart';

/// Hive adapters for GPS activity models
class ActivitySessionAdapter extends TypeAdapter<ActivitySession> {
  @override
  final int typeId = 0;

  @override
  String get typeName => 'ActivitySession';

  @override
  ActivitySession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final index = reader.readByte();
      final value = reader.read();
      fields[index] = value;
    }
    return ActivitySession(
      id: fields[0] as String,
      activityType: ActivityType.values[fields[1] as int],
      state: ActivityState.values[fields[2] as int],
      stats: fields[3] as FitnessStats,
      routePoints: (fields[4] as List).cast<LatLng>(),
      waypoints: (fields[5] as List).cast<ActivityWaypoint>(),
      isValid: fields[7] as bool? ?? true,
      activityReplaced: fields[8] as String?,
      startWeather: fields[9] as WeatherData?,
      startIpLookup: fields[10] as IpLookupData?,
      isSynced: fields[11] as bool? ?? false,
      syncedAt: fields[12] != null ? DateTime.fromMillisecondsSinceEpoch(fields[12] as int) : null,
      lastSyncAttempt: fields[13] != null ? DateTime.fromMillisecondsSinceEpoch(fields[13] as int) : null,
      createdAt: fields[14] != null ? DateTime.fromMillisecondsSinceEpoch(fields[14] as int) : null,
    );
  }

  @override
  void write(BinaryWriter writer, ActivitySession obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.activityType.index)
      ..writeByte(2)
      ..write(obj.state.index)
      ..writeByte(3)
      ..write(obj.stats)
      ..writeByte(4)
      ..write(obj.routePoints)
      ..writeByte(5)
      ..write(obj.waypoints)
      ..writeByte(6)
      ..write(null) // Was metadata, keeping index for compatibility if needed or just skipping
      ..writeByte(7)
      ..write(obj.isValid)
      ..writeByte(8)
      ..write(obj.activityReplaced)
      ..writeByte(9)
      ..write(obj.startWeather)
      ..writeByte(10)
      ..write(obj.startIpLookup)
      ..writeByte(11)
      ..write(obj.isSynced)
      ..writeByte(12)
      ..write(obj.syncedAt?.millisecondsSinceEpoch)
      ..writeByte(13)
      ..write(obj.lastSyncAttempt?.millisecondsSinceEpoch)
      ..writeByte(14)
      ..write(obj.createdAt?.millisecondsSinceEpoch);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) &&
      other is ActivitySessionAdapter &&
      runtimeType == other.runtimeType &&
      typeId == other.typeId;
}

class FitnessStatsAdapter extends TypeAdapter<FitnessStats> {
  @override
  final int typeId = 1;

  @override
  String get typeName => 'FitnessStats';

  @override
  FitnessStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final index = reader.readByte();
      final value = reader.read();
      fields[index] = value;
    }
    return FitnessStats(
      totalDistanceMeters: fields[0] as double,
      totalDuration: Duration(milliseconds: fields[1] as int),
      activeDuration: Duration(milliseconds: fields[2] as int),
      averageSpeedMps: fields[3] as double,
      currentSpeedMps: fields[4] as double,
      maxSpeedMps: fields[5] as double,
      averagePaceSecondsPerKm: fields[6] as double,
      currentPaceSecondsPerKm: fields[7] as double,
      estimatedCalories: fields[8] as int,
      startTime: DateTime.fromMillisecondsSinceEpoch(fields[9] as int),
      endTime: fields[10] != null
          ? DateTime.fromMillisecondsSinceEpoch(fields[10] as int)
          : null,
      totalSteps: fields[11] as int,
      elevationGain: fields[12] as double,
      altitude: fields[13] as double? ?? 0.0,
    );
  }

  @override
  void write(BinaryWriter writer, FitnessStats obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.totalDistanceMeters)
      ..writeByte(1)
      ..write(obj.totalDuration.inMilliseconds)
      ..writeByte(2)
      ..write(obj.activeDuration.inMilliseconds)
      ..writeByte(3)
      ..write(obj.averageSpeedMps)
      ..writeByte(4)
      ..write(obj.currentSpeedMps)
      ..writeByte(5)
      ..write(obj.maxSpeedMps)
      ..writeByte(6)
      ..write(obj.averagePaceSecondsPerKm)
      ..writeByte(7)
      ..write(obj.currentPaceSecondsPerKm)
      ..writeByte(8)
      ..write(obj.estimatedCalories)
      ..writeByte(9)
      ..write(obj.startTime.millisecondsSinceEpoch)
      ..writeByte(10)
      ..write(obj.endTime?.millisecondsSinceEpoch)
      ..writeByte(11)
      ..write(obj.totalSteps)
      ..writeByte(12)
      ..write(obj.elevationGain)
      ..writeByte(13)
      ..write(obj.altitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) &&
      other is FitnessStatsAdapter &&
      runtimeType == other.runtimeType &&
      typeId == other.typeId;
}

class LatLngAdapter extends TypeAdapter<LatLng> {
  @override
  final int typeId = 2;

  @override
  String get typeName => 'LatLng';

  @override
  LatLng read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final index = reader.readByte();
      final value = reader.read();
      fields[index] = value;
    }
    return LatLng(fields[0] as double, fields[1] as double);
  }

  @override
  void write(BinaryWriter writer, LatLng obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) &&
      other is LatLngAdapter &&
      runtimeType == other.runtimeType &&
      typeId == other.typeId;
}

class ActivityWaypointAdapter extends TypeAdapter<ActivityWaypoint> {
  @override
  final int typeId = 3;

  @override
  String get typeName => 'ActivityWaypoint';

  @override
  ActivityWaypoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final index = reader.readByte();
      final value = reader.read();
      fields[index] = value;
    }
    return ActivityWaypoint(
      location: fields[0] as LatLng,
      timestamp: DateTime.fromMillisecondsSinceEpoch(fields[1] as int),
      type: fields[2] as String,
      statsAtTime: fields[3] as FitnessStats?,
      altitude: fields[4] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, ActivityWaypoint obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.location)
      ..writeByte(1)
      ..write(obj.timestamp.millisecondsSinceEpoch)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.statsAtTime)
      ..writeByte(4)
      ..write(obj.altitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) &&
      other is ActivityWaypointAdapter &&
      runtimeType == other.runtimeType &&
      typeId == other.typeId;
}

class WeatherLocationAdapter extends TypeAdapter<WeatherLocation> {
  @override
  final int typeId = 4;

  @override
  String get typeName => 'WeatherLocation';

  @override
  WeatherLocation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final index = reader.readByte();
      final value = reader.read();
      fields[index] = value;
    }
    return WeatherLocation(
      name: fields[0] as String,
      region: fields[1] as String,
      country: fields[2] as String,
      tzId: fields[3] as String,
      localtimeEpoch: fields[4] as int,
      localtime: fields[5] as String,
      utcOffset: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WeatherLocation obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.region)
      ..writeByte(2)
      ..write(obj.country)
      ..writeByte(3)
      ..write(obj.tzId)
      ..writeByte(4)
      ..write(obj.localtimeEpoch)
      ..writeByte(5)
      ..write(obj.localtime)
      ..writeByte(6)
      ..write(obj.utcOffset);
  }
}

class WeatherDataAdapter extends TypeAdapter<WeatherData> {
  @override
  final int typeId = 5;

  @override
  String get typeName => 'WeatherData';

  @override
  WeatherData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final index = reader.readByte();
      final value = reader.read();
      fields[index] = value;
    }
    return WeatherData(
      location: fields[0] as WeatherLocation?,
      lastUpdated: fields[1] as String,
      lastUpdatedEpoch: fields[2] as int,
      tempC: fields[3] as double,
      isDay: fields[4] as int,
      conditionText: fields[5] as String,
      conditionIcon: fields[6] as String,
      conditionCode: fields[7] as int,
      windKph: fields[8] as double,
      windDegree: fields[9] as int,
      windDir: fields[10] as String,
      pressureMb: fields[11] as double,
      precipMm: fields[12] as double,
      humidity: fields[13] as int,
      cloud: fields[14] as int,
      feelsLikeC: fields[15] as double,
      windChillC: fields[16] as double,
      heatIndexC: fields[17] as double,
      dewPointC: fields[18] as double,
      visKm: fields[19] as double,
      uv: fields[20] as double,
      gustKph: fields[21] as double,
    );
  }

  @override
  void write(BinaryWriter writer, WeatherData obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.location)
      ..writeByte(1)
      ..write(obj.lastUpdated)
      ..writeByte(2)
      ..write(obj.lastUpdatedEpoch)
      ..writeByte(3)
      ..write(obj.tempC)
      ..writeByte(4)
      ..write(obj.isDay)
      ..writeByte(5)
      ..write(obj.conditionText)
      ..writeByte(6)
      ..write(obj.conditionIcon)
      ..writeByte(7)
      ..write(obj.conditionCode)
      ..writeByte(8)
      ..write(obj.windKph)
      ..writeByte(9)
      ..write(obj.windDegree)
      ..writeByte(10)
      ..write(obj.windDir)
      ..writeByte(11)
      ..write(obj.pressureMb)
      ..writeByte(12)
      ..write(obj.precipMm)
      ..writeByte(13)
      ..write(obj.humidity)
      ..writeByte(14)
      ..write(obj.cloud)
      ..writeByte(15)
      ..write(obj.feelsLikeC)
      ..writeByte(16)
      ..write(obj.windChillC)
      ..writeByte(17)
      ..write(obj.heatIndexC)
      ..writeByte(18)
      ..write(obj.dewPointC)
      ..writeByte(19)
      ..write(obj.visKm)
      ..writeByte(20)
      ..write(obj.uv)
      ..writeByte(21)
      ..write(obj.gustKph);
  }
}

class IpLookupDataAdapter extends TypeAdapter<IpLookupData> {
  @override
  final int typeId = 6;

  @override
  String get typeName => 'IpLookupData';

  @override
  IpLookupData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final index = reader.readByte();
      final value = reader.read();
      fields[index] = value;
    }
    return IpLookupData(
      ip: fields[0] as String,
      type: fields[1] as String,
      continentCode: fields[2] as String,
      continentName: fields[3] as String,
      countryCode: fields[4] as String,
      countryName: fields[5] as String,
      isEu: fields[6] as bool,
      geonameId: fields[7] as int,
      city: fields[8] as String,
      region: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, IpLookupData obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.ip)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.continentCode)
      ..writeByte(3)
      ..write(obj.continentName)
      ..writeByte(4)
      ..write(obj.countryCode)
      ..writeByte(5)
      ..write(obj.countryName)
      ..writeByte(6)
      ..write(obj.isEu)
      ..writeByte(7)
      ..write(obj.geonameId)
      ..writeByte(8)
      ..write(obj.city)
      ..writeByte(9)
      ..write(obj.region);
  }
}

/// Local storage service for managing Hive boxes
class LocalStorageService {
  static const String _activityBoxName = 'activities';
  static const String _settingsBoxName = 'settings';

  static late Box<ActivitySession> _activityBox;
  static late Box<dynamic> _settingsBox;

  static Future<void> init() async {
    // Register adapters
    Hive.registerAdapter(ActivitySessionAdapter());
    Hive.registerAdapter(FitnessStatsAdapter());
    Hive.registerAdapter(LatLngAdapter());
    Hive.registerAdapter(ActivityWaypointAdapter());
    Hive.registerAdapter(WeatherLocationAdapter());
    Hive.registerAdapter(WeatherDataAdapter());
    Hive.registerAdapter(IpLookupDataAdapter());

    // Open boxes
    _activityBox = await Hive.openBox<ActivitySession>(_activityBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);

    // Set default device ID if not exists
    if (_settingsBox.get('device_id') == null) {
      await _settingsBox.put(
        'device_id',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    }
  }

  // Activity Box Operations
  static Future<void> saveActivity(ActivitySession session) async {
    try {
      await _activityBox.put(session.id, session);
      EnterpriseLogger().logInfo('Local DB', 'Activity saved: ${session.id}', metadata: {
        'type': session.activityType.name,
        'state': session.state.name,
        'distance': session.stats.totalDistanceMeters,
      });
    } catch (e) {
      EnterpriseLogger().logError('Local DB', 'Failed to save activity: $e', StackTrace.current);
      rethrow;
    }
  }

  static ActivitySession? getActivity(String id) {
    return _activityBox.get(id);
  }

  static List<ActivitySession> getAllActivities() {
    return _activityBox.values.toList();
  }

  static List<ActivitySession> getPendingSync() {
    return _activityBox.values.where((a) => !_isSynced(a)).toList();
  }

  static Future<void> markAsSynced(String id) async {
    final activity = getActivity(id);
    if (activity != null) {
      try {
        final updated = activity.copyWith(
          isSynced: true,
          syncedAt: DateTime.now(),
        );
        await saveActivity(updated);
        EnterpriseLogger().logInfo('Local DB', 'Activity marked as synced: $id');
      } catch (e) {
        EnterpriseLogger().logError('Local DB', 'Failed to mark as synced: $id ($e)', StackTrace.current);
      }
    }
  }

  static Future<void> deleteActivity(String id) async {
    await _activityBox.delete(id);
    EnterpriseLogger().logInfo('Local DB', 'Activity deleted: $id');
  }

  static Future<void> clearAllActivities() async {
    try {
      final count = _activityBox.length;
      await _activityBox.clear();
      EnterpriseLogger().logInfo('Local DB', 'Cleared all local activities', metadata: {'count': count});
    } catch (e) {
      EnterpriseLogger().logError('Local DB', 'Failed to clear activities: $e', StackTrace.current);
    }
  }

  // Settings Operations
  static String getDeviceId() {
    return _settingsBox.get('device_id', defaultValue: 'unknown') as String;
  }

  static Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  static T? getSetting<T>(String key) {
    return _settingsBox.get(key) as T?;
  }

  // Onboarding completion tracking
  static bool hasCompletedOnboarding() {
    return _settingsBox.get('has_completed_onboarding', defaultValue: false) as bool;
  }

  static Future<void> markOnboardingComplete() async {
    await _settingsBox.put('has_completed_onboarding', true);
    EnterpriseLogger().logInfo('Onboarding', 'User marked onboarding as complete');
  }

  static Future<void> resetOnboarding() async {
    await _settingsBox.put('has_completed_onboarding', false);
    EnterpriseLogger().logInfo('Onboarding', 'Onboarding status reset');
  }

  static bool _isSynced(ActivitySession session) {
    return session.isSynced;
  }

  // Box access for external use
  static Box<ActivitySession> get activityBox => _activityBox;
  static Box<dynamic> get settingsBox => _settingsBox;
}
