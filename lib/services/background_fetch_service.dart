import 'dart:async';
import 'dart:io';
import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';

// Global callback for background fetch (must be top-level or static)
Future<void> _onBackgroundFetch(String taskId) async {
  debugPrint('🔄 BackgroundFetchService: Background fetch triggered - Task ID: $taskId');
  
  try {
    // Call the registered callback if available
    if (BackgroundFetchService._onFetchCallback != null) {
      await BackgroundFetchService._onFetchCallback!();
    }

    // Always finish the task
    BackgroundFetch.finish(taskId);
    debugPrint('✅ BackgroundFetchService: Task completed - Task ID: $taskId');
  } catch (e) {
    debugPrint('❌ BackgroundFetchService: Task error: $e');
    // Always finish the task even on error
    BackgroundFetch.finish(taskId);
  }
}

// Background fetch timeout callback
void _onTimeout(String taskId) {
  debugPrint('⏱️ BackgroundFetchService: Task timeout - Task ID: $taskId');
  BackgroundFetch.finish(taskId);
}

// Headless task callback (for iOS background execution after app termination)
Future<void> _headlessTask(HeadlessTask task) async {
  final taskId = task.taskId;
  debugPrint('🔄 BackgroundFetchService: Headless task triggered - Task ID: $taskId');

  try {
    // This runs even when the app is terminated
    // Can be used to:
    // 1. Check if tracking should be resumed
    // 2. Sync pending data
    // 3. Send notifications
    
    if (BackgroundFetchService._onHeadlessCallback != null) {
      await BackgroundFetchService._onHeadlessCallback!();
    }
    
    debugPrint('✅ BackgroundFetchService: Headless task completed');
  } catch (e) {
    debugPrint('❌ BackgroundFetchService: Headless task error: $e');
  } finally {
    BackgroundFetch.finish(taskId);
  }
}

/// Background fetch service for iOS background wake-ups
/// This ensures the app can periodically wake up to check/restore location tracking
/// and sync data even when the app is in background or terminated
///
/// Note: Android uses WorkManager for background tasks, but this service
/// is configured to work on both platforms for consistency
class BackgroundFetchService {
  static final BackgroundFetchService _instance = BackgroundFetchService._internal();
  factory BackgroundFetchService() => _instance;
  BackgroundFetchService._internal();

  // Static callbacks that can be accessed from global functions
  static Future<void> Function()? _onFetchCallback;
  static Future<void> Function()? _onHeadlessCallback;

  bool _isInitialized = false;
  bool _isConfigured = false;

  /// Initialize background fetch
  /// 
  /// [onBackgroundFetch] - Called when background fetch triggers (app in background)
  /// [onHeadlessTask] - Called for headless execution (iOS, app terminated)
  Future<void> initialize({
    Future<void> Function()? onBackgroundFetch,
    Future<void> Function()? onHeadlessTask,
  }) async {
    if (_isInitialized) return;

    try {
      debugPrint('🔄 BackgroundFetchService: Initializing...');
      
      // Store callbacks in static variables so they can be accessed from global functions
      _onFetchCallback = onBackgroundFetch;
      _onHeadlessCallback = onHeadlessTask;

      // Configure background fetch
      await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15, // Minimum interval in minutes (iOS minimum is 15)
          stopOnTerminate: false,     // Continue running after app termination
          enableHeadless: true,      // Enable headless execution
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresStorageNotLow: false,
          requiresDeviceIdle: false,
          requiredNetworkType: NetworkType.NONE,
        ),
        _onBackgroundFetch,
        _onTimeout,
      );

      _isConfigured = true;
      debugPrint('✅ BackgroundFetchService: Configured successfully');

      // Register headless task for background execution after app termination
      if (Platform.isIOS) {
        BackgroundFetch.registerHeadlessTask(_headlessTask);
        debugPrint('✅ BackgroundFetchService: Headless task registered');
      }

      _isInitialized = true;
      debugPrint('✅ BackgroundFetchService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ BackgroundFetchService: Initialization error: $e');
    }
  }

  /// Start background fetch
  Future<void> start() async {
    if (!_isConfigured) {
      debugPrint('⚠️ BackgroundFetchService: Not configured yet, cannot start');
      return;
    }

    try {
      debugPrint('🔄 BackgroundFetchService: Starting...');
      await BackgroundFetch.start();
      debugPrint('✅ BackgroundFetchService: Started successfully');
    } catch (e) {
      debugPrint('❌ BackgroundFetchService: Start error: $e');
    }
  }

  /// Stop background fetch
  Future<void> stop() async {
    if (!_isConfigured) return;

    try {
      debugPrint('🛑 BackgroundFetchService: Stopping...');
      await BackgroundFetch.stop();
      debugPrint('✅ BackgroundFetchService: Stopped successfully');
    } catch (e) {
      debugPrint('❌ BackgroundFetchService: Stop error: $e');
    }
  }

  /// Get status of background fetch
  Future<int> getStatus() async {
    try {
      final status = await BackgroundFetch.status;
      debugPrint('📊 BackgroundFetchService: Status = $status');
      return status;
    } catch (e) {
      debugPrint('❌ BackgroundFetchService: Status check error: $e');
      return -1;
    }
  }

  /// Simulate a background fetch event (for testing)
  Future<void> simulate() async {
    try {
      debugPrint('🧪 BackgroundFetchService: Simulating background fetch...');
      await BackgroundFetch.simulateBackgroundFetch();
      debugPrint('✅ BackgroundFetchService: Simulation triggered');
    } catch (e) {
      debugPrint('❌ BackgroundFetchService: Simulation error: $e');
    }
  }

  /// Schedule a custom background task
  /// This can be used to schedule one-off or periodic custom tasks
  Future<void> scheduleTask({
    required String taskId,
    required int delay, // Delay in milliseconds
    bool periodic = false,
    bool requiresNetwork = false,
    bool requiresCharging = false,
  }) async {
    try {
      debugPrint('📅 BackgroundFetchService: Scheduling task - ID: $taskId, Delay: ${delay}ms');
      
      await BackgroundFetch.scheduleTask(
        TaskConfig(
          taskId: taskId,
          delay: delay,
          periodic: periodic,
          forceAlarmManager: false,
          stopOnTerminate: false,
          enableHeadless: true,
          requiresNetworkConnectivity: requiresNetwork,
          requiresCharging: requiresCharging,
        ),
      );
      
      debugPrint('✅ BackgroundFetchService: Task scheduled - ID: $taskId');
    } catch (e) {
      debugPrint('❌ BackgroundFetchService: Schedule task error: $e');
    }
  }

  /// Check if background fetch is available
  Future<bool> isAvailable() async {
    try {
      final status = await BackgroundFetch.status;
      return status != BackgroundFetch.STATUS_DENIED &&
             status != BackgroundFetch.STATUS_DISABLED;
    } catch (e) {
      debugPrint('❌ BackgroundFetchService: Availability check error: $e');
      return false;
    }
  }

  /// Get platform-specific status string
  String getStatusString(int status) {
    switch (status) {
      case BackgroundFetch.STATUS_RESTRICTED:
        return 'Restricted';
      case BackgroundFetch.STATUS_DENIED:
        return 'Denied';
      case BackgroundFetch.STATUS_AVAILABLE:
        return 'Available';
      case BackgroundFetch.STATUS_DISABLED:
        return 'Disabled';
      default:
        return 'Unknown';
    }
  }

  /// Dispose resources
  void dispose() {
    debugPrint('🧹 BackgroundFetchService: Disposing...');
    _onFetchCallback = null;
    _onHeadlessCallback = null;
    _isInitialized = false;
    _isConfigured = false;
  }
}

/// Provider for background fetch service state
class BackgroundFetchProvider extends ChangeNotifier {
  final BackgroundFetchService _service = BackgroundFetchService();
  
  int _status = -1;
  bool _isInitialized = false;

  int get status => _status;
  bool get isInitialized => _isInitialized;
  String get statusString => _service.getStatusString(_status);

  Future<void> initialize({
    Future<void> Function()? onBackgroundFetch,
    Future<void> Function()? onHeadlessTask,
  }) async {
    await _service.initialize(
      onBackgroundFetch: onBackgroundFetch,
      onHeadlessTask: onHeadlessTask,
    );
    _isInitialized = true;
    _status = await _service.getStatus();
    notifyListeners();
  }

  Future<void> start() async {
    await _service.start();
  }

  Future<void> stop() async {
    await _service.stop();
  }

  Future<void> refreshStatus() async {
    _status = await _service.getStatus();
    notifyListeners();
  }

  Future<void> simulate() async {
    await _service.simulate();
  }

  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
