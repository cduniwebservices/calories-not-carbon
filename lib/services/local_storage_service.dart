import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../models/fitness_models.dart';
import 'enterprise_logger.dart';

Map<String, dynamic>? _castToStringMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return null;
}

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
      id: fields[0] as String? ?? '',
      activityType: ActivityType.values[fields[1] as int? ?? 0],
      state: ActivityState.values[fields[2] as int? ?? 0],
      stats: fields[3] as FitnessStats? ?? FitnessStats(startTime: DateTime.now()),
      routePoints: (fields[4] as List? ?? []).cast<LatLng>(),
      waypoints: (fields[5] as List? ?? []).cast<ActivityWaypoint>(),
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
      totalDistanceMeters: (fields[0] as num? ?? 0).toDouble(),
      totalDuration: Duration(milliseconds: (fields[1] as int? ?? 0)),
      activeDuration: Duration(milliseconds: (fields[2] as int? ?? 0)),
      movingDuration: Duration(milliseconds: fields[14] as int? ?? 0),
      stationaryDuration: Duration(milliseconds: fields[15] as int? ?? 0),
      averageSpeedMps: (fields[3] as num? ?? 0).toDouble(),
      currentSpeedMps: (fields[4] as num? ?? 0).toDouble(),
      maxSpeedMps: (fields[5] as num? ?? 0).toDouble(),
      averagePaceSecondsPerKm: (fields[6] as num? ?? 0).toDouble(),
      currentPaceSecondsPerKm: (fields[7] as num? ?? 0).toDouble(),
      estimatedCalories: fields[8] as int? ?? 0,
      startTime: DateTime.fromMillisecondsSinceEpoch(fields[9] as int? ?? DateTime.now().millisecondsSinceEpoch),
      endTime: fields[10] != null
          ? DateTime.fromMillisecondsSinceEpoch(fields[10] as int)
          : null,
      totalSteps: fields[11] as int? ?? 0,
      elevationGain: (fields[12] as num? ?? 0).toDouble(),
      altitude: (fields[13] as num? ?? 0).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, FitnessStats obj) {
    writer
      ..writeByte(16)
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
      ..write(obj.altitude)
      ..writeByte(14)
      ..write(obj.movingDuration.inMilliseconds)
      ..writeByte(15)
      ..write(obj.stationaryDuration.inMilliseconds);
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
    return LatLng((fields[0] as num? ?? 0).toDouble(), (fields[1] as num? ?? 0).toDouble());
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
      location: fields[0] as LatLng? ?? const LatLng(0, 0),
      timestamp: DateTime.fromMillisecondsSinceEpoch(fields[1] as int? ?? 0),
      type: fields[2] as String? ?? 'track_point',
      statsAtTime: fields[3] as FitnessStats?,
      altitude: (fields[4] as num?)?.toDouble(),
      rawSensorData: _castToStringMap(fields[5]),
    );
  }

  @override
  void write(BinaryWriter writer, ActivityWaypoint obj) {
    writer
    ..writeByte(6)
    ..writeByte(0)
    ..write(obj.location)
    ..writeByte(1)
    ..write(obj.timestamp.millisecondsSinceEpoch)
    ..writeByte(2)
    ..write(obj.type)
    ..writeByte(3)
    ..write(obj.statsAtTime)
    ..writeByte(4)
    ..write(obj.altitude)
    ..writeByte(5)
    ..write(obj.rawSensorData);
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
      name: fields[0] as String? ?? '',
      region: fields[1] as String? ?? '',
      country: fields[2] as String? ?? '',
      tzId: fields[3] as String? ?? '',
      localtimeEpoch: fields[4] as int? ?? 0,
      localtime: fields[5] as String? ?? '',
      utcOffset: fields[6] as String? ?? '',
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
      lastUpdated: fields[1] as String? ?? '',
      lastUpdatedEpoch: fields[2] as int? ?? 0,
      tempC: (fields[3] as num? ?? 0).toDouble(),
      isDay: fields[4] as int? ?? 0,
      conditionText: fields[5] as String? ?? '',
      conditionIcon: fields[6] as String? ?? '',
      conditionCode: fields[7] as int? ?? 0,
      windKph: (fields[8] as num? ?? 0).toDouble(),
      windDegree: fields[9] as int? ?? 0,
      windDir: fields[10] as String? ?? '',
      pressureMb: (fields[11] as num? ?? 0).toDouble(),
      precipMm: (fields[12] as num? ?? 0).toDouble(),
      humidity: fields[13] as int? ?? 0,
      cloud: fields[14] as int? ?? 0,
      feelsLikeC: (fields[15] as num? ?? 0).toDouble(),
      windChillC: (fields[16] as num? ?? 0).toDouble(),
      heatIndexC: (fields[17] as num? ?? 0).toDouble(),
      dewPointC: (fields[18] as num? ?? 0).toDouble(),
      visKm: (fields[19] as num? ?? 0).toDouble(),
      uv: (fields[20] as num? ?? 0).toDouble(),
      gustKph: (fields[21] as num? ?? 0).toDouble(),
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
      ip: fields[0] as String? ?? '',
      type: fields[1] as String? ?? '',
      continentCode: fields[2] as String? ?? '',
      continentName: fields[3] as String? ?? '',
      countryCode: fields[4] as String? ?? '',
      countryName: fields[5] as String? ?? '',
      isEu: fields[6] as bool? ?? false,
      geonameId: fields[7] as int? ?? 0,
      city: fields[8] as String? ?? '',
      region: fields[9] as String? ?? '',
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

  static Box<ActivitySession>? _activityBox;
  static Box<dynamic>? _settingsBox;
  static bool _isInitialized = false;

  /// Whether the storage service was successfully initialized.
  static bool get isInitialized => _isInitialized;

  static Future<void> init() async {
    // Register adapters
    Hive.registerAdapter(ActivitySessionAdapter());
    Hive.registerAdapter(FitnessStatsAdapter());
    Hive.registerAdapter(LatLngAdapter());
    Hive.registerAdapter(ActivityWaypointAdapter());
    Hive.registerAdapter(WeatherLocationAdapter());
    Hive.registerAdapter(WeatherDataAdapter());
    Hive.registerAdapter(IpLookupDataAdapter());

    // Open settings box (small, low risk of corruption)
    _settingsBox = await Hive.openBox(_settingsBoxName);

    // Open activities box with per-entry corruption recovery
    _activityBox = await _openActivityBoxSafe();

    _isInitialized = true;

    // Set default device ID if not exists
    if (_settingsBox?.get('device_id') == null) {
      await _settingsBox?.put(
        'device_id',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    }
  }

  /// Opens the activities box with per-entry corruption recovery.
  ///
  /// Hive 2.x stores all entries in a single binary file. If the file is
  /// corrupt at the storage level (page/frame corruption), `openBox` will
  /// throw and no individual entries can be read. In this case we must
  /// delete the box and start fresh — but we log diagnostic info first to
  /// help identify the root cause.
  ///
  /// The first line of defense against corruption is the null-safe adapter
  /// reads in this file and the robust `saveActivity` method that catches
  /// write errors.
  static Future<Box<ActivitySession>> _openActivityBoxSafe() async {
    try {
      return await Hive.openBox<ActivitySession>(_activityBoxName);
    } catch (e) {
      debugPrint('⚠️ LocalStorage: Batch openBox failed: $e');
      EnterpriseLogger().logError(
        'Local DB',
        'Hive openBox failed, clearing box',
        StackTrace.current,
        metadata: {'error': e.toString()},
      );
    }

    // Log the current box file size for diagnostics before deleting
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final boxFile = File('${appDir.path}/$_activityBoxName.hive');
      if (await boxFile.exists()) {
        final size = await boxFile.length();
        debugPrint('📊 LocalStorage: Corrupt box file size: $size bytes');
        EnterpriseLogger().logInfo('Local DB', 'Corrupt box file stats', metadata: {
          'path': boxFile.path,
          'sizeBytes': size,
        });
      }
    } catch (_) {}

    // Nuclear option: delete and re-create the box
    try {
      await Hive.deleteBoxFromDisk(_activityBoxName);
      final newBox = await Hive.openBox<ActivitySession>(_activityBoxName);
      debugPrint('✅ LocalStorage: Box cleared and re-created successfully');
      return newBox;
    } catch (e) {
      debugPrint('❌ LocalStorage: Failed to re-create box: $e');
      EnterpriseLogger().logError(
        'Local DB',
        'Failed to re-create activity box',
        StackTrace.current,
        metadata: {'error': e.toString()},
      );
      rethrow;
    }
  }

  // Activity Box Operations
  static Future<void> saveActivity(ActivitySession session) async {
    final box = _activityBox;
    if (box == null) {
      EnterpriseLogger().logError('Local DB', 'Cannot save activity: storage not initialized', StackTrace.current);
      return;
    }
    try {
      await box.put(session.id, session);
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
    return _activityBox?.get(id);
  }

  static List<ActivitySession> getAllActivities() {
    final box = _activityBox;
    if (box == null) return [];
    return box.values.toList();
  }

  static List<ActivitySession> getPendingSync() {
    final box = _activityBox;
    if (box == null) return [];
    return box.values.where((a) => !_isSynced(a)).toList();
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
    final box = _activityBox;
    if (box == null) return;
    await box.delete(id);
    EnterpriseLogger().logInfo('Local DB', 'Activity deleted: $id');
  }

  static Future<void> clearAllActivities() async {
    final box = _activityBox;
    if (box == null) return;
    try {
      final count = box.length;
      await box.clear();
      EnterpriseLogger().logInfo('Local DB', 'Cleared all local activities', metadata: {'count': count});
    } catch (e) {
      EnterpriseLogger().logError('Local DB', 'Failed to clear activities: $e', StackTrace.current);
    }
  }

  // Settings Operations
  static String getDeviceId() {
    return _settingsBox?.get('device_id', defaultValue: 'unknown') as String? ?? 'unknown';
  }

  static Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox?.put(key, value);
  }

  static T? getSetting<T>(String key) {
    return _settingsBox?.get(key) as T?;
  }

  // Onboarding completion tracking
  static bool hasCompletedOnboarding() {
    return _settingsBox?.get('has_completed_onboarding', defaultValue: false) as bool? ?? false;
  }

  static Future<void> markOnboardingComplete() async {
    await _settingsBox?.put('has_completed_onboarding', true);
    EnterpriseLogger().logInfo('Onboarding', 'User marked onboarding as complete');
  }

  static Future<void> resetOnboarding() async {
    await _settingsBox?.put('has_completed_onboarding', false);
    EnterpriseLogger().logInfo('Onboarding', 'Onboarding status reset');
  }

  static bool _isSynced(ActivitySession session) {
    return session.isSynced;
  }

  // Box access for external use
  static Box<ActivitySession>? get activityBox => _activityBox;
  static Box<dynamic>? get settingsBox => _settingsBox;
}
