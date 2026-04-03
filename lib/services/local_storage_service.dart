import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../models/fitness_models.dart';

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
      metadata: Map<String, dynamic>.from(fields[6] as Map),
    );
  }

  @override
  void write(BinaryWriter writer, ActivitySession obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.metadata);
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
    );
  }

  @override
  void write(BinaryWriter writer, FitnessStats obj) {
    writer
      ..writeByte(13)
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
      ..write(obj.elevationGain);
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
      note: fields[3] as String?,
      statsAtTime: fields[4] as FitnessStats?,
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
      ..write(obj.note)
      ..writeByte(4)
      ..write(obj.statsAtTime);
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
    await _activityBox.put(session.id, session);
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
      final updated = activity.copyWith(
        metadata: {...activity.metadata, 'synced': true, 'synced_at': DateTime.now().toIso8601String()},
      );
      await saveActivity(updated);
    }
  }

  static Future<void> deleteActivity(String id) async {
    await _activityBox.delete(id);
  }

  static Future<void> clearAllActivities() async {
    await _activityBox.clear();
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

  static bool _isSynced(ActivitySession session) {
    return session.metadata['synced'] == true;
  }

  // Box access for external use
  static Box<ActivitySession> get activityBox => _activityBox;
  static Box<dynamic> get settingsBox => _settingsBox;
}
