import 'dart:async';
import 'dart:isolate';
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
  final _receivePort = ReceivePort();
  SendPort? _sendPort;

  /// Initialize foreground task
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Configure foreground task options
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
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 1000, // Run every 1000ms (1 second)
        autoRunOnBoot: false,
        allowWifiLock: true,
        allowWakeLock: true,
      ),
    );

    // Set up receive port to get messages from isolate
    _receivePort.listen(_handleMessageFromIsolate);

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

      // Request permissions for foreground service
      if (!await FlutterForegroundTask.canDrawOverlays) {
        await FlutterForegroundTask.openSystemAlertWindowSettings();
      }

      // Request notification permission (Android 13+)
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      // Start foreground service
      final result = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: '🏃 Workout in Progress',
        notificationText: 'Tracking your location...',
        callback: startLocationTrackingCallback,
      );

      debugPrint('✅ BackgroundLocationService: Service started - $result');
      return result;
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

  /// Get send port for communicating with isolate
  SendPort? get sendPort => _sendPort;

  /// Handle messages from isolate
  void _handleMessageFromIsolate(dynamic message) {
    if (message is SendPort) {
      _sendPort = message;
      debugPrint('✅ BackgroundLocationService: Got send port from isolate');
    } else if (message is Map<String, dynamic>) {
      debugPrint('📡 BackgroundLocationService: Received data from isolate: $message');
    }
  }

  /// Check if service is running
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// Dispose resources
  void dispose() {
    _receivePort.close();
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
  SendPort? _sendPort;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    debugPrint('🎯 LocationTrackingTaskHandler: Started');

    // Start listening to GPS updates
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0, // Get every update
        timeLimit: null,
      ),
    ).listen(
      (Position position) {
        _onLocationUpdate(position);
      },
      onError: (error) {
        debugPrint('❌ LocationTrackingTaskHandler: GPS error: $error');
      },
    );

    // Send initial message to main isolate
    sendPort?.send({'type': 'started', 'timestamp': timestamp.toIso8601String()});
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    // This is called every interval (1 second)
    // We don't need to do anything here since GPS stream handles updates
    _sendPort = sendPort;
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    debugPrint('🛑 LocationTrackingTaskHandler: Destroyed');
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
  }

  @override
  void onNotificationDismissed() {
    debugPrint('🔘 Notification dismissed');
  }

  void _onLocationUpdate(Position position) {
    final locationData = LocationData.fromPosition(position);

    // Send location data to main isolate
    _sendPort?.send({
      'type': 'location',
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'heading': position.heading,
      'speed': position.speed,
      'timestamp': position.timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
    });

    debugPrint(
      '📡 LocationTrackingTaskHandler: GPS - '
      'Lat: ${position.latitude.toStringAsFixed(6)}, '
      'Lng: ${position.longitude.toStringAsFixed(6)}, '
      'Acc: ${position.accuracy.toStringAsFixed(1)}m, '
      'Speed: ${position.speed.toStringAsFixed(1)}m/s',
    );
  }
}
