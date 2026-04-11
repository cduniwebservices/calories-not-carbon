import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_storage_service.dart';
import '../models/fitness_models.dart';

/// Offline-first sync service: saves locally, syncs to Supabase on WiFi
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  int _syncedCount = 0;
  int _failedCount = 0;

  // Callbacks for UI feedback
  Function(int total, int synced, int failed)? onSyncProgress;
  Function(String message)? onSyncComplete;
  Function(String error)? onSyncError;

  /// Start listening to connectivity changes
  void startListening() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  /// Stop listening
  void stopListening() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> result) {
    // Auto-sync on any active connection (WiFi or Mobile)
    if (result.any((r) => r != ConnectivityResult.none)) {
      syncPendingActivities();
    }
  }

  /// Sync all pending (unsynced) activities to Supabase
  Future<void> syncPendingActivities() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _syncedCount = 0;
    _failedCount = 0;

    try {
      final pending = LocalStorageService.getPendingSync();
      final total = pending.length;

      if (total == 0) {
        onSyncComplete?.call('All activities are up to date');
        _isSyncing = false;
        return;
      }

      onSyncProgress?.call(total, 0, 0);

      for (int i = 0; i < pending.length; i++) {
        final activity = pending[i];
        final success = await _uploadToSupabase(activity);

        if (success) {
          await LocalStorageService.markAsSynced(activity.id);
          _syncedCount++;
        } else {
          _failedCount++;
        }

        onSyncProgress?.call(total, _syncedCount, _failedCount);
      }

      onSyncComplete?.call(
        'Sync complete: $_syncedCount synced, $_failedCount failed',
      );
    } catch (e) {
      onSyncError?.call('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Manual sync trigger (works on any connection)
  Future<void> manualSync() async {
    await syncPendingActivities();
  }

  /// Upload a single activity to Supabase
  Future<bool> _uploadToSupabase(ActivitySession activity) async {
    try {
      final supabase = Supabase.instance.client;
      final sessionJson = activity.toJson();

      await supabase.from('activities').insert({
        'id': activity.id,
        'device_id': LocalStorageService.getDeviceId(),
        'activity_type': activity.activityType.name,
        'state': activity.state.name,
        'total_distance_meters': activity.stats.totalDistanceMeters,
        'total_duration_ms': activity.stats.totalDuration.inMilliseconds,
        'active_duration_ms': activity.stats.activeDuration.inMilliseconds,
        'average_speed_mps': activity.stats.averageSpeedMps,
        'max_speed_mps': activity.stats.maxSpeedMps,
        'estimated_calories': activity.stats.estimatedCalories,
        'total_steps': activity.stats.totalSteps,
        'elevation_gain': activity.stats.elevationGain,
        'is_valid': activity.isValid,
        'start_time': activity.stats.startTime.toIso8601String(),
        'end_time': activity.stats.endTime?.toIso8601String(),
        'route_points': sessionJson['routePoints'], // Use rich data from model
        'metadata': activity.metadata,
        'created_at': DateTime.now().toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }


  /// Get sync status
  Map<String, dynamic> getSyncStatus() {
    final pending = LocalStorageService.getPendingSync();
    return {
      'pending': pending.length,
      'isSyncing': _isSyncing,
      'lastSyncedCount': _syncedCount,
      'lastFailedCount': _failedCount,
    };
  }

  /// Check if currently syncing
  bool get isSyncing => _isSyncing;
}
