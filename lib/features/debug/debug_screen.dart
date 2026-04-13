import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/fitness_models.dart';
import '../../services/local_storage_service.dart';
import '../../services/sync_service.dart';
import '../../services/weather_service.dart';
import '../../services/activity_controller.dart';
import '../../services/enterprise_logger.dart';
import '../../providers/activity_providers.dart';
import '../../theme/global_theme.dart';

import 'package:flutter/foundation.dart';

/// Static helper to show the debug screen as a full-screen overlay
class DebugScreenOverlay {
  static void show(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.3),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const DebugScreen(),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _logScrollController = ScrollController();
  String _queryText = '';
  String _queryResult = '';
  String _weatherResult = '';
  String _ipResult = '';
  bool _weatherLoading = false;
  bool _ipLoading = false;
  ActivityState? _lastKnownState;
  List<LatLng> _lastRoutePoints = [];
  FitnessStats? _lastStats;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    EnterpriseLogger().logInfo('Debug Screen', 'Debug screen opened');
    _startGpsPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _logScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Poll the activity controller every second for GPS data
  void _startGpsPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final activityState = ref.read(activityStateProvider);
      final stats = ref.read(fitnessStatsProvider);
      final routePoints = ref.read(routePointsProvider);

      // Log state changes
      if (activityState != _lastKnownState) {
        EnterpriseLogger().logInfo('GPS Poll', '🔄 State: ${_lastKnownState?.name ?? 'N/A'} → $activityState');
        _lastKnownState = activityState;
      }

      // Log new route points
      if (routePoints.length > _lastRoutePoints.length) {
        final newPoints = routePoints.skip(_lastRoutePoints.length).toList();
        for (final point in newPoints) {
          EnterpriseLogger().logInfo('GPS Poll', '📍 GPS: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}');
        }
        _lastRoutePoints = routePoints;
      }

      // Log stats updates during activity
      if (activityState == ActivityState.running && stats != _lastStats) {
        if (_lastStats != null) {
          final dist = stats.totalDistanceMeters - (_lastStats?.totalDistanceMeters ?? 0);
          if (dist > 0) {
            EnterpriseLogger().logInfo('GPS Poll', '📊 Dist: ${stats.formattedDistance} | Speed: ${(stats.currentSpeedMps * 3.6).toStringAsFixed(1)} km/h | Route points: ${routePoints.length}');
          }
        }
        _lastStats = stats;
      }
    });
  }

  Future<void> _shareLogs() async {
    final logs = EnterpriseLogger().exportLogs();
    if (logs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No logs to share')),
        );
      }
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/calories_not_carbon_logs.txt');
      await file.writeAsString(logs);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Calories Not Carbon Debug Logs',
        text: 'Streaming logs from the Enterprise Logger.',
      );
    } catch (e) {
      EnterpriseLogger().logError('Debug Screen', '❌ Error sharing logs: $e', StackTrace.current);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      appBar: AppBar(
        title: const Text('Debug Console', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        elevation: 0,
        leadingWidth: 72,
        leading: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: GlobalTheme.surfaceCard,
              borderRadius: BorderRadius.circular(GlobalTheme.radiusMedium),
              boxShadow: GlobalTheme.cardShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(GlobalTheme.radiusMedium),
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: GlobalTheme.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: GlobalTheme.primaryNeon,
          labelColor: GlobalTheme.primaryNeon,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.stream), text: 'Logs'),
            Tab(icon: Icon(Icons.storage), text: 'Local DB'),
            Tab(icon: Icon(Icons.route), text: 'Simulate'),
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
    final allLogs = EnterpriseLogger().getRecentLogs(200);

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
              ],
            ],
          ),
        ),
        // Log header
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black54,
          child: Row(
            children: [
              const Icon(Icons.circle, size: 10, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Enterprise Logs (${allLogs.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _shareLogs,
                icon: const Icon(Icons.share, size: 16, color: GlobalTheme.primaryNeon),
                label: const Text('Share', style: TextStyle(color: GlobalTheme.primaryNeon)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  EnterpriseLogger().clearAll();
                  setState(() {});
                },
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
              itemCount: allLogs.length,
              itemBuilder: (context, index) {
                final log = allLogs[index];
                Color logColor = Colors.green;
                if (log.level == LogLevel.error) logColor = Colors.red;
                if (log.level == LogLevel.warning) logColor = Colors.orange;
                if (log.category == 'Navigation') logColor = Colors.blue;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    log.toString(),
                    style: TextStyle(
                      color: logColor,
                      fontFamily: 'monospace',
                      fontSize: 11,
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    EnterpriseLogger().logInfo('Debug', '🔄 Manual sync triggered...');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Syncing activities...'), duration: Duration(seconds: 1)),
                    );

                    // Listen for sync result
                    String? syncResult;
                    String? syncError;
                    SyncService().onSyncComplete = (message) {
                      syncResult = message;
                      EnterpriseLogger().logInfo('Debug', '📋 Sync result: $message');
                    };
                    SyncService().onSyncError = (error) {
                      syncError = error;
                      EnterpriseLogger().logError('Debug', '❌ Sync error: $error', StackTrace.current);
                    };

                    await SyncService().manualSync();

                    if (mounted) {
                      setState(() {});

                      // Show appropriate message based on result
                      if (syncError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sync failed: $syncError'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      } else if (syncResult != null) {
                        final failedMatch = RegExp(r'(\d+) failed').firstMatch(syncResult!);
                        final failedCount = failedMatch != null ? int.parse(failedMatch.group(1)!) : 0;

                        if (failedCount > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('⚠️ $syncResult — check Logs tab for error details'),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ $syncResult'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.cloud_upload, color: Colors.purple),
                  label: const Text('Sync to Remote', style: TextStyle(color: Colors.purple)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalTheme.surfaceCard,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await LocalStorageService.clearAllActivities();
                    ref.read(activityActionsProvider).resetActivity();
                    ref.invalidate(activityHistoryProvider);
                    EnterpriseLogger().logInfo('Debug', '🗑️ All local activities cleared');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Local data cleared')),
                      );
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text('Clear All Local Data', style: TextStyle(color: Colors.red)),                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalTheme.surfaceCard,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
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
    final isSynced = session.isSynced;
    final syncedAt = session.syncedAt;
    final lastAttemptedAt = session.lastSyncAttempt;

    String syncedTime = '';
    String attemptedTime = '';

    if (syncedAt != null) {
      final dt = syncedAt.toLocal();
      syncedTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    }

    if (lastAttemptedAt != null) {
      final dt = lastAttemptedAt.toLocal();
      attemptedTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    }

    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Text(
                'Synced:',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(width: 4),
              Text(
                isSynced ? '✅' : '❌',
                style: const TextStyle(fontSize: 11),
              ),
              if (isSynced && syncedTime.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '@ $syncedTime',
                  style: const TextStyle(color: Colors.green, fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
              if (!isSynced && attemptedTime.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  'attempted @ $attemptedTime',
                  style: const TextStyle(color: Colors.orange, fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _fetchTestWeather() async {
    setState(() {
      _weatherLoading = true;
      _weatherResult = '';
    });

    try {
      final weather = await WeatherService().getCurrentWeather(-33.8688, 151.2093);
      if (weather != null) {
        setState(() {
          _weatherResult = 
              'Location: ${weather.location?.name ?? "N/A"}, ${weather.location?.country ?? "N/A"}\n'
              'Temperature: ${weather.tempC}°C (feels like ${weather.feelsLikeC}°C)\n'
              'Condition: ${weather.conditionText}\n'
              'Wind: ${weather.windKph} kph ${weather.windDir}\n'
              'Humidity: ${weather.humidity}%\n'
              'Pressure: ${weather.pressureMb} mb\n'
              'Visibility: ${weather.visKm} km\n'
              'UV Index: ${weather.uv}\n'
              'Cloud Cover: ${weather.cloud}%\n'
              'Local Time: ${weather.location?.localtime ?? "N/A"}';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Weather fetched successfully'),
              backgroundColor: Color(0xFFF57F17),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _weatherResult = 'Error: Weather API returned null (check API key or logs)';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Weather fetch returned null — check API key'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _weatherResult = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Weather fetch failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _weatherLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTestIpLookup() async {
    setState(() {
      _ipLoading = true;
      _ipResult = '';
    });

    try {
      final ipData = await WeatherService().getIpLookup();
      if (ipData != null) {
        setState(() {
          _ipResult = 
              'IP: ${ipData.ip}\n'
              'Type: ${ipData.type}\n'
              'City: ${ipData.city}\n'
              'Region: ${ipData.region}\n'
              'Country: ${ipData.countryName} (${ipData.countryCode})\n'
              'Continent: ${ipData.continentName} (${ipData.continentCode})\n'
              'EU Member: ${ipData.isEu ? "Yes" : "No"}\n'
              'Geoname ID: ${ipData.geonameId}';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ IP lookup successful'),
              backgroundColor: Color(0xFF00796B),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _ipResult = 'Error: IP lookup returned null (check API key or logs)';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ IP lookup returned null — check API key'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _ipResult = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ IP lookup failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _ipLoading = false;
        });
      }
    }
  }

  List<InlineSpan> _formatWeatherLine(String line) {
    final colonIndex = line.indexOf(':');
    if (colonIndex > 0) {
      return [
        TextSpan(
          text: '${line.substring(0, colonIndex + 1)} ',
          style: const TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        TextSpan(
          text: line.substring(colonIndex + 1).trim(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ];
    }
    return [
      TextSpan(
        text: line,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
      ),
    ];
  }

  List<InlineSpan> _formatIpLine(String line) {
    final colonIndex = line.indexOf(':');
    if (colonIndex > 0) {
      return [
        TextSpan(
          text: '${line.substring(0, colonIndex + 1)} ',
          style: const TextStyle(
            color: Colors.teal,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        TextSpan(
          text: line.substring(colonIndex + 1).trim(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ];
    }
    return [
      TextSpan(
        text: line,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
      ),
    ];
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
            'Creates a realistic walking/activity route and sends it to Supabase for testing.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          _buildMockRouteButton(
            icon: Icons.directions_walk,
            label: 'Generate Walk Route (2km)',
            color: Colors.blue,
            onTap: () => _generateMockRoute('walking', 2000),
          ),
          const SizedBox(height: 4),
          const Text(
            'CO₂ footprint: 0.027 kg/km',
            style: TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          _buildMockRouteButton(
            icon: Icons.directions_run,
            label: 'Generate Activity Route (5km)',
            color: Colors.green,
            onTap: () => _generateMockRoute('running', 5000),
          ),
          const SizedBox(height: 4),
          const Text(
            'CO₂ footprint: 0.033 kg/km',
            style: TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          _buildMockRouteButton(
            icon: Icons.directions_bike,
            label: 'Generate Cycle Route (15km)',
            color: Colors.orange,
            onTap: () => _generateMockRoute('cycling', 15000),
          ),
          const SizedBox(height: 4),
          const Text(
            'CO₂ footprint: 0.022 kg/km',
            style: TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ),

    const SizedBox(height: 48),

    const Text(
      'Test Weather API',
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    const SizedBox(height: 8),
    const Text(
      'Fetch live weather and IP location data from WeatherAPI.com',
      style: TextStyle(color: Colors.grey),
    ),
    const SizedBox(height: 24),

    _buildMockRouteButton(
      icon: Icons.wb_sunny,
      label: _weatherLoading ? 'Fetching...' : 'Fetch Current Weather',
      color: Colors.amber,
      onTap: _weatherLoading ? null : () => _fetchTestWeather(),
    ),
    const SizedBox(height: 12),

    if (_weatherResult.isNotEmpty)
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _weatherResult.split('\n').map((line) {
            final isLabel = line.contains(':');
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: isLabel
                  ? RichText(
                      text: TextSpan(
                        children: _formatWeatherLine(line),
                      ),
                    )
                  : Text(
                      line,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                    ),
            );
          }).toList(),
        ),
      ),

    const SizedBox(height: 16),

    _buildMockRouteButton(
      icon: Icons.location_searching,
      label: _ipLoading ? 'Fetching...' : 'Fetch IP Location',
      color: Colors.teal,
      onTap: _ipLoading ? null : () => _fetchTestIpLookup(),
    ),
    const SizedBox(height: 12),

    if (_ipResult.isNotEmpty)
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.teal.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _ipResult.split('\n').map((line) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RichText(
                text: TextSpan(
                  children: _formatIpLine(line),
                ),
              ),
            );
          }).toList(),
        ),
      ),

    const SizedBox(height: 48),

    const Text(
      'Access Hidden App Screens',
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    const SizedBox(height: 8),
    const Text(
      'Navigate to permission and onboarding screens for testing',
      style: TextStyle(color: Colors.grey),
    ),
    const SizedBox(height: 24),
    _buildMockRouteButton(
      icon: Icons.touch_app,
      label: 'Test Permission Onboarding',
      color: Colors.cyan,
      onTap: () {
        Navigator.of(context).pop();
        context.push('/permission-onboarding?debug=true');
      },
    ),
    const SizedBox(height: 12),
    _buildMockRouteButton(
      icon: Icons.location_off,
      label: 'Test Permission Denied Screen',
      color: Colors.redAccent,
      onTap: () {
        Navigator.of(context).pop();
        context.push('/permission-denied');
      },
    ),
    const SizedBox(height: 32),
  ],
),
);
}

  Widget _buildMockRouteButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
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
    EnterpriseLogger().logInfo('Debug', '🗺️ Generating mock $type route (${distanceMeters}m)...');

    // Generate realistic GPS points around Sydney
    final points = <LatLng>[];
    final startLat = -33.8688;
    final startLng = 151.2093;
    final random = Random();
    int totalDistance = 0;
    double lat = startLat;
    double lng = startLng;
    
    // Altitude generation: Start at some base altitude and vary it realistically
    double currentAltitude = 50.0 + random.nextDouble() * 100.0;
    double totalElevationGain = 0.0;

    // Speed in m/s for different activity types
    final speedMap = {'walking': 1.4, 'running': 3.0, 'cycling': 6.0};
    final speed = speedMap[type] ?? 1.4;

    while (totalDistance < distanceMeters) {
      points.add(LatLng(lat, lng));
      
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
    final startTime = DateTime.now().subtract(duration);
    
    // Generate mock waypoints (one every 100m or so)
    final waypoints = <ActivityWaypoint>[];
    double waypointAltitude = currentAltitude;
    
    for (var i = 0; i < points.length; i += (points.length / 10).floor().clamp(1, points.length)) {
      final point = points[i];
      final progress = i / points.length;
      final waypointDuration = Duration(seconds: (duration.inSeconds * progress).toInt());
      final waypointTimestamp = startTime.add(waypointDuration);
      
      // Random altitude change between waypoints (-2m to +3m)
      final altChange = (random.nextDouble() * 5.0) - 2.0;
      waypointAltitude += altChange;
      if (altChange > 0) totalElevationGain += altChange;
      
      waypoints.add(ActivityWaypoint(
        location: point,
        timestamp: waypointTimestamp,
        type: i == 0 ? 'start' : (i >= points.length - 1 ? 'finish' : 'milestone'),
        altitude: waypointAltitude,
        statsAtTime: FitnessStats(
          totalDistanceMeters: distanceMeters * progress,
          totalDuration: waypointDuration,
          activeDuration: waypointDuration,
          averageSpeedMps: speed,
          currentSpeedMps: speed + (random.nextDouble() - 0.5),
          startTime: startTime,
          elevationGain: totalElevationGain,
        ),
      ));
    }

    // Generate mock weather
    final mockWeather = WeatherData(
      location: const WeatherLocation(
        name: 'Sydney',
        region: 'New South Wales',
        country: 'Australia',
        tzId: 'Australia/Sydney',
        localtimeEpoch: 1775881598,
        localtime: '2026-04-11 13:56',
        utcOffset: '+10:00',
      ),
      lastUpdated: '2026-04-11 13:45',
      lastUpdatedEpoch: 1775880900,
      tempC: 24.5,
      isDay: 1,
      conditionText: 'Partly Cloudy',
      conditionIcon: '//cdn.weatherapi.com/weather/64x64/day/116.png',
      conditionCode: 1003,
      windKph: 12.5,
      windDegree: 180,
      windDir: 'S',
      pressureMb: 1012.0,
      precipMm: 0.0,
      humidity: 65,
      cloud: 40,
      feelsLikeC: 25.2,
      windChillC: 24.5,
      heatIndexC: 25.2,
      dewPointC: 17.5,
      visKm: 10.0,
      uv: 6.0,
      gustKph: 18.5,
    );

    // Generate mock IP lookup
    const mockIpLookup = IpLookupData(
      ip: '1.1.1.1',
      type: 'ipv4',
      continentCode: 'OC',
      continentName: 'Oceania',
      countryCode: 'AU',
      countryName: 'Australia',
      isEu: false,
      geonameId: 2147714,
      city: 'Sydney',
      region: 'New South Wales',
    );

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
        startTime: startTime,
        endTime: DateTime.now(),
        totalSteps: type == 'walking' || type == 'running'
            ? (distanceMeters / 0.762).toInt()
            : 0,
        elevationGain: totalElevationGain,
      ),
      routePoints: points,
      waypoints: waypoints,
      isValid: true,
      activityReplaced: 'petrol_diesel_car',
      startWeather: mockWeather,
      startIpLookup: mockIpLookup,
    );

    // Save locally
    await LocalStorageService.saveActivity(session);
    EnterpriseLogger().logInfo('Debug', '💾 Mock session saved locally: ${session.id}');
    EnterpriseLogger().logInfo('Debug', '📊 Distance: ${session.stats.formattedDistance}, Duration: ${session.stats.formattedDuration}');

    // Invalidate history provider so it refreshes when opened
    ref.invalidate(activityHistoryProvider);

    // Send to Supabase
    EnterpriseLogger().logInfo('Debug', '☁️ Uploading to Supabase...');
    bool uploadSuccess = false;
    String? uploadError;
    try {
      final sessionJson = session.toJson();
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
        'is_valid': session.isValid,
        'activity_replaced': session.activityReplaced,
        'start_weather': session.startWeather?.toJson(),
        'start_ip_lookup': session.startIpLookup?.toJson(),
        'start_time': session.stats.startTime.toIso8601String(),
        'end_time': session.stats.endTime?.toIso8601String(),
        'route_points': sessionJson['routePoints'],
        'created_at': DateTime.now().toIso8601String(),
      });

      await LocalStorageService.markAsSynced(session.id);
      EnterpriseLogger().logInfo('Debug', '✅ Successfully uploaded to Supabase');
      uploadSuccess = true;
    } catch (e) {
      uploadError = e.toString();
      EnterpriseLogger().logInfo('Debug', '❌ Supabase upload failed: $e');
    }

    if (mounted) {
      if (uploadSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${session.activityType.displayName} route generated & synced (${session.stats.formattedDistance})'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Route saved locally but sync failed: $uploadError'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
              EnterpriseLogger().logInfo('Debug', '🐛 Throwing test exception...');
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
              EnterpriseLogger().logInfo('Debug', '📨 Sentry message sent');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Sentry message sent'),
                    backgroundColor: Color(0xFF2E7D32),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
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
                EnterpriseLogger().logInfo('Debug', '⚠️ Exception captured to Sentry (no crash)');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Exception captured by Sentry'),
                      backgroundColor: Color(0xFFF57F17),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
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
              EnterpriseLogger().logInfo('Debug', '🍞 Breadcrumb added and message sent');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Breadcrumb & message sent to Sentry'),
                    backgroundColor: Color(0xFF1565C0),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
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
              EnterpriseLogger().logInfo('Debug', '📊 Performance transaction completed');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Performance transaction completed'),
                    backgroundColor: Color(0xFF6A1B9A),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(Icons.bug_report, color: color),
          label: Text(label, style: TextStyle(color: color)),
          style: ElevatedButton.styleFrom(
            backgroundColor: GlobalTheme.surfaceCard,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(description, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ),
      ],
    );
  }
}
