import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

/// Service for handling background location tracking via foreground task
/// This keeps GPS active even when screen is off or app is in background
class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  bool _isInitialized = false;

  /// Initialize foreground task
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Configure foreground task options for v9.x
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_tracking_channel',
        channelName: 'Location Tracking',
        channelDescription: 'Tracking your workout location',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        showWhen: true,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWifiLock: true,
        allowWakeLock: true,
      ),
    );

    _isInitialized = true;
    debugPrint('✅ BackgroundLocationService: Initialized');
  }

  /// Start foreground task with location tracking
  Future<bool> startTracking() async {
    try {
      // Check if service is already running
      if (await FlutterForegroundTask.isRunningService) {
        debugPrint('⚠️ BackgroundLocationService: Service already running');
        return true;
      }

      // Request notification permission (Android 13+)
      final notificationPermission = await FlutterForegroundTask.requestNotificationPermission();
      if (notificationPermission == NotificationPermission.denied) {
        debugPrint('❌ BackgroundLocationService: Notification permission denied');
        return false;
      }

      // Start foreground service
      final result = await FlutterForegroundTask.startService(
        notificationTitle: '🏃 Workout in Progress',
        notificationText: 'Tracking your location...',
        callback: startLocationTrackingCallback,
      );

      final success = result is ServiceRequestSuccess;
      debugPrint('✅ BackgroundLocationService: Service started - success: $success');
      return success;
    } catch (e) {
      debugPrint('❌ BackgroundLocationService: Failed to start service: $e');
      return false;
    }
  }

  /// Stop foreground task
  Future<void> stopTracking() async {
    try {
      if (!await FlutterForegroundTask.isRunningService) {
        debugPrint('⚠️ BackgroundLocationService: Service not running');
        return;
      }

      await FlutterForegroundTask.stopService();
      debugPrint('✅ BackgroundLocationService: Service stopped');
    } catch (e) {
      debugPrint('❌ BackgroundLocationService: Error stopping service: $e');
    }
  }

  /// Update notification with workout progress
  Future<void> updateNotification(String title, String text) async {
    if (!await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  /// Check if service is running
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// Dispose resources
  void dispose() {
    _isInitialized = false;
  }
}

/// Callback that runs in foreground task isolate
@pragma('vm:entry-point')
void startLocationTrackingCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTrackingTaskHandler());
}

/// Task handler for location tracking in foreground
class LocationTrackingTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionSubscription;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('🎯 LocationTrackingTaskHandler: Started');

    // Start listening to GPS updates
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0, // Get every update
      ),
    ).listen(
      (Position position) {
        _onLocationUpdate(position);
      },
      onError: (error) {
        debugPrint('❌ LocationTrackingTaskHandler: GPS error: $error');
      },
    );
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // This is called periodically
    // GPS stream handles the actual location updates
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('🛑 LocationTrackingTaskHandler: Destroyed (timeout: $isTimeout)');
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('🔘 Notification button pressed: $id');
  }

  @override
  void onNotificationPressed() {
    debugPrint('🔘 Notification pressed');
    // Could open the app here
    FlutterForegroundTask.launchApp();
  }

  void _onLocationUpdate(Position position) {
    // Send location data to main isolate
    final data = {
      'type': 'location',
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'heading': position.heading,
      'speed': position.speed,
      'timestamp': position.timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };

    FlutterForegroundTask.sendDataToMain(data);

    debugPrint(
      '📡 LocationTrackingTaskHandler: GPS - '
      'Lat: ${position.latitude.toStringAsFixed(6)}, '
      'Lng: ${position.longitude.toStringAsFixed(6)}, '
      'Acc: ${position.accuracy.toStringAsFixed(1)}m, '
      'Speed: ${position.speed.toStringAsFixed(1)}m/s',
    );
  }
}
