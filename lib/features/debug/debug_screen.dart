import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../models/fitness_models.dart';
import '../../services/local_storage_service.dart';
import '../../services/sync_service.dart';
import '../../services/activity_controller.dart';
import '../../providers/activity_providers.dart';
import '../../theme/global_theme.dart';

import 'package:flutter/foundation.dart';

class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();
  String _queryText = '';
  String _queryResult = '';
  ActivityState? _lastKnownState;
  List<LatLng> _lastRoutePoints = [];
  FitnessStats? _lastStats;
  Timer? _pollTimer;
  DebugPrintCallback? _oldDebugPrint;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _addLog('🔧 Debug screen opened');
    _addLog('📦 Local DB activities: ${LocalStorageService.getAllActivities().length}');
    _startGpsPolling();
    
    // Intercept debugPrint to show in UI
    _oldDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        _addLog(message);
      }
      if (_oldDebugPrint != null) {
        _oldDebugPrint!(message, wrapWidth: wrapWidth);
      }
    };
  }

  @override
  void dispose() {
    if (_oldDebugPrint != null) {
      debugPrint = _oldDebugPrint!;
    }
    _pollTimer?.cancel();
    _logScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Poll the activity controller every second for GPS data
  void _startGpsPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final activityState = ref.watch(activityStateProvider);
      final stats = ref.watch(fitnessStatsProvider);
      final routePoints = ref.watch(routePointsProvider);

      // Log state changes
      if (activityState != _lastKnownState) {
        _addLog('🔄 State: ${_lastKnownState?.name ?? 'N/A'} → $activityState');
        _lastKnownState = activityState;
      }

      // Log new route points
      if (routePoints.length > _lastRoutePoints.length) {
        final newPoints = routePoints.skip(_lastRoutePoints.length).toList();
        for (final point in newPoints) {
          _addLog(
            '📍 GPS: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
          );
        }
        _lastRoutePoints = routePoints;
      }

      // Log stats updates during activity
      if (activityState == ActivityState.running && stats != _lastStats) {
        if (_lastStats != null) {
          final dist = stats.totalDistanceMeters - (_lastStats?.totalDistanceMeters ?? 0);
          if (dist > 0) {
            _addLog(
              '📊 Dist: ${stats.formattedDistance} | Speed: ${(stats.currentSpeedMps * 3.6).toStringAsFixed(1)} km/h | Cal: ${stats.estimatedCalories} | Route points: ${routePoints.length}',
            );
          }
        }
        _lastStats = stats;
      }

      // Log GPS availability
      if (activityState == ActivityState.running && routePoints.isEmpty) {
        _addLog('⚠️ Activity running but NO GPS route points received!');
      }
    });
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 23);
      _logs.add('[$timestamp] $message');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlobalTheme.backgroundPrimary,
      appBar: AppBar(
        title: const Text('🔧 Debug Console', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.go('/run'),
        ),
        actions: const [],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: GlobalTheme.primaryNeon,
          labelColor: GlobalTheme.primaryNeon,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.stream), text: 'Logs'),
            Tab(icon: Icon(Icons.storage), text: 'Local DB'),
            Tab(icon: Icon(Icons.route), text: 'Mock Route'),
            Tab(icon: Icon(Icons.bug_report), text: 'Sentry'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogsTab(),
          _buildLocalDbTab(),
          _buildMockRouteTab(),
          _buildSentryTab(),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    final activityState = ref.watch(activityStateProvider);
    final stats = ref.watch(fitnessStatsProvider);
    final routePoints = ref.watch(routePointsProvider);

    return Column(
      children: [
        // Live GPS status panel
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black87,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    activityState == ActivityState.running ? Icons.circle : Icons.circle_outlined,
                    size: 10,
                    color: activityState == ActivityState.running
                        ? Colors.green
                        : activityState == ActivityState.paused
                        ? Colors.orange
                        : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'State: ${activityState.name.toUpperCase()}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    'Points: ${routePoints.length}',
                    style: TextStyle(color: routePoints.isNotEmpty ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (activityState != ActivityState.idle) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('📏 ${stats.formattedDistance}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const SizedBox(width: 12),
                    Text('⚡ ${(stats.currentSpeedMps * 3.6).toStringAsFixed(1)} km/h', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const SizedBox(width: 12),
                    Text('🔥 ${stats.estimatedCalories} cal', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const SizedBox(width: 12),
                    Text('⏱️ ${stats.formattedDuration}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
                if (routePoints.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '📍 Last: ${routePoints.last.latitude.toStringAsFixed(6)}, ${routePoints.last.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ],
            ],
          ),
        ),
        // Log list
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black54,
          child: Row(
            children: [
              const Icon(Icons.circle, size: 10, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Live GPS & DB Logs (${_logs.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _logs.clear()),
                child: const Text('Clear', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.black,
            child: ListView.builder(
              controller: _logScrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                Color logColor = Colors.green;
                if (log.contains('❌') || log.contains('ERROR')) logColor = Colors.red;
                if (log.contains('⚠️') || log.contains('WARN')) logColor = Colors.orange;
                if (log.contains('💾')) logColor = Colors.blue;
                if (log.contains('☁️')) logColor = Colors.purple;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    log,
                    style: TextStyle(
                      color: logColor,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalDbTab() {
    final activities = LocalStorageService.getAllActivities();
    final pending = LocalStorageService.getPendingSync();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          Row(
            children: [
              Expanded(child: _buildStatCard('Total', activities.length.toString(), Icons.storage)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Pending Sync', pending.length.toString(), Icons.cloud_upload)),
            ],
          ),
          const SizedBox(height: 16),

          // Query section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GlobalTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Query Local DB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by activity_type, state, or device_id...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _queryText = value;
                      _queryResult = _performQuery(value);
                    });
                  },
                ),
                if (_queryText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _queryResult.isEmpty ? 'No results found' : _queryResult,
                        style: const TextStyle(color: Colors.green, fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Activity list
          const Text('Recent Activities', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...activities.take(10).map((a) => _buildActivityTile(a)).toList(),
          if (activities.isEmpty)
            const Center(child: Text('No activities stored yet', style: TextStyle(color: Colors.grey))),

          const SizedBox(height: 16),

          // Actions
          ElevatedButton.icon(
            onPressed: () {
              LocalStorageService.clearAllActivities();
              _addLog('🗑️ All local activities cleared');
              setState(() {});
            },
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text('Clear All Local Data', style: TextStyle(color: Colors.red)),
            style: ElevatedButton.styleFrom(backgroundColor: GlobalTheme.surfaceCard),
          ),
        ],
      ),
    );
  }

  String _performQuery(String query) {
    if (query.isEmpty) return '';
    final activities = LocalStorageService.getAllActivities();
    final results = activities.where((a) {
      final q = query.toLowerCase();
      return a.activityType.name.contains(q) ||
             a.state.name.contains(q) ||
             a.metadata['device_id']?.toLowerCase().contains(q) == true ||
             a.id.contains(q);
    }).toList();

    if (results.isEmpty) return 'No matching activities';
    return results.map((a) =>
      '${a.id.substring(0, 8)}... | ${a.activityType.name} | ${a.state.name} | ${a.stats.formattedDistance} | ${a.stats.formattedCalories}'
    ).join('\n');
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GlobalTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: GlobalTheme.primaryNeon, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActivityTile(ActivitySession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GlobalTheme.surfaceCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${session.activityType.name.toUpperCase()} • ${session.state.name}',
            style: const TextStyle(color: GlobalTheme.primaryNeon, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'ID: ${session.id.substring(0, 8)}... | Distance: ${session.stats.formattedDistance} | Calories: ${session.stats.estimatedCalories}',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          Text(
            'Duration: ${session.stats.formattedDuration} | Route points: ${session.routePoints.length}',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          Text(
            'Synced: ${session.metadata['synced'] == true ? '✅' : '❌'}',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMockRouteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Mock GPS Route',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Creates a realistic walking/running route and sends it to Supabase for testing.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          _buildMockRouteButton(
            icon: Icons.directions_walk,
            label: 'Generate Walk Route (2km)',
            color: Colors.blue,
            onTap: () => _generateMockRoute('walking', 2000),
          ),
          const SizedBox(height: 12),

          _buildMockRouteButton(
            icon: Icons.directions_run,
            label: 'Generate Run Route (5km)',
            color: Colors.green,
            onTap: () => _generateMockRoute('running', 5000),
          ),
          const SizedBox(height: 12),

          _buildMockRouteButton(
            icon: Icons.directions_bike,
            label: 'Generate Cycle Route (15km)',
            color: Colors.orange,
            onTap: () => _generateMockRoute('cycling', 15000),
          ),

          const SizedBox(height: 32),

          // Manual sync button
          ElevatedButton.icon(
            onPressed: () async {
              _addLog('🔄 Manual sync triggered...');
              await SyncService().manualSync();
              _addLog('✅ Manual sync complete');
              setState(() {});
            },
            icon: const Icon(Icons.cloud_upload, color: Colors.purple),
            label: const Text('Force Sync to Supabase', style: TextStyle(color: Colors.purple)),
            style: ElevatedButton.styleFrom(backgroundColor: GlobalTheme.surfaceCard),
          ),
        ],
      ),
    );
  }

  Widget _buildMockRouteButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: ElevatedButton.styleFrom(
        backgroundColor: GlobalTheme.surfaceCard,
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  Future<void> _generateMockRoute(String type, int distanceMeters) async {
    _addLog('🗺️ Generating mock $type route (${distanceMeters}m)...');

    // Generate realistic GPS points around Sydney
    final points = <LatLng>[];
    final startLat = -33.8688;
    final startLng = 151.2093;
    final random = Random();
    int totalDistance = 0;
    double lat = startLat;
    double lng = startLng;

    // Speed in m/s for different activity types
    final speedMap = {'walking': 1.4, 'running': 3.0, 'cycling': 6.0};
    final speed = speedMap[type] ?? 1.4;

    while (totalDistance < distanceMeters) {
      points.add(LatLng(lat, lng));
      _addLog('📍 Point: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}');

      // Random direction change (realistic path)
      final angle = random.nextDouble() * 2 * pi;
      final step = random.nextDouble() * 10 + 5; // 5-15m steps
      lat += step * 0.00001 * cos(angle);
      lng += step * 0.00001 * sin(angle);
      totalDistance += step.toInt();
    }

    // Add final point
    points.add(LatLng(lat, lng));

    // Create session
    final duration = Duration(seconds: (distanceMeters / speed).toInt());
    final session = ActivitySession(
      id: const Uuid().v4(),
      activityType: ActivityType.values.firstWhere(
        (t) => t.name == type,
        orElse: () => ActivityType.walking,
      ),
      state: ActivityState.completed,
      stats: FitnessStats(
        totalDistanceMeters: distanceMeters.toDouble(),
        totalDuration: duration,
        activeDuration: duration,
        averageSpeedMps: speed,
        maxSpeedMps: speed * 1.5,
        averagePaceSecondsPerKm: 1000 / speed,
        currentPaceSecondsPerKm: 1000 / speed,
        estimatedCalories: (distanceMeters / 1000 * 50).toInt(),
        startTime: DateTime.now().subtract(duration),
        endTime: DateTime.now(),
        totalSteps: type == 'walking' || type == 'running'
            ? (distanceMeters / 0.762).toInt()
            : 0,
        elevationGain: random.nextDouble() * 50,
      ),
      routePoints: points,
      waypoints: [],
      metadata: {'device_id': LocalStorageService.getDeviceId(), 'source': 'mock'},
    );

    // Save locally
    await LocalStorageService.saveActivity(session);
    _addLog('💾 Mock session saved locally: ${session.id}');
    _addLog('📊 Distance: ${session.stats.formattedDistance}, Duration: ${session.stats.formattedDuration}');

    // Send to Supabase
    _addLog('☁️ Uploading to Supabase...');
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('activities').insert({
        'id': session.id,
        'device_id': LocalStorageService.getDeviceId(),
        'activity_type': session.activityType.name,
        'state': session.state.name,
        'total_distance_meters': session.stats.totalDistanceMeters,
        'total_duration_ms': session.stats.totalDuration.inMilliseconds,
        'active_duration_ms': session.stats.activeDuration.inMilliseconds,
        'average_speed_mps': session.stats.averageSpeedMps,
        'max_speed_mps': session.stats.maxSpeedMps,
        'estimated_calories': session.stats.estimatedCalories,
        'total_steps': session.stats.totalSteps,
        'elevation_gain': session.stats.elevationGain,
        'start_time': session.stats.startTime.toIso8601String(),
        'end_time': session.stats.endTime?.toIso8601String(),
        'route_points': session.routePoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        'metadata': session.metadata,
        'created_at': DateTime.now().toIso8601String(),
      });

      await LocalStorageService.markAsSynced(session.id);
      _addLog('✅ Successfully uploaded to Supabase');
    } catch (e) {
      _addLog('❌ Supabase upload failed: $e');
    }

    setState(() {});
  }

  Widget _buildSentryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sentry Crash Testing',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use these buttons to verify Sentry integration and test different error types.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          _buildSentryButton(
            label: 'Throw Exception',
            description: 'Throws a StateError to test crash capture',
            color: Colors.red,
            onTap: () {
              _addLog('🐛 Throwing test exception...');
              throw StateError('This is a test exception from debug console');
            },
          ),
          const SizedBox(height: 12),

          _buildSentryButton(
            label: 'Capture Message',
            description: 'Sends a simple message to Sentry',
            color: Colors.orange,
            onTap: () async {
              await Sentry.captureMessage('Debug console test message');
              _addLog('📨 Sentry message sent');
            },
          ),
          const SizedBox(height: 12),

          _buildSentryButton(
            label: 'Capture Exception',
            description: 'Sends a captured exception without crashing',
            color: Colors.yellow,
            onTap: () async {
              try {
                throw Exception('Simulated database timeout');
              } catch (e, stack) {
                await Sentry.captureException(e, stackTrace: stack);
                _addLog('⚠️ Exception captured to Sentry (no crash)');
              }
            },
          ),
          const SizedBox(height: 12),

          _buildSentryButton(
            label: 'Add Breadcrumb & Capture',
            description: 'Adds context breadcrumbs before capturing',
            color: Colors.blue,
            onTap: () async {
              await Sentry.addBreadcrumb(
                Breadcrumb(
                  message: 'Debug console action',
                  category: 'debug',
                  level: SentryLevel.info,
                ),
              );
              await Sentry.captureMessage('Breadcrumb test with context', level: SentryLevel.warning);
              _addLog('🍞 Breadcrumb added and message sent');
            },
          ),
          const SizedBox(height: 12),

          _buildSentryButton(
            label: 'Test Performance Transaction',
            description: 'Creates and finishes a test transaction',
            color: Colors.purple,
            onTap: () async {
              final transaction = Sentry.startTransaction(
                'debug.test_action',
                'debug',
                bindToScope: true,
              );
              await Future.delayed(const Duration(milliseconds: 500));
              transaction.status = SpanStatus.ok();
              await transaction.finish();
              _addLog('📊 Performance transaction completed');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSentryButton({
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GlobalTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withOpacity(0.2),
              foregroundColor: color,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
