import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/global_theme.dart';
import '../../../models/fitness_models.dart';
import '../../../components/app_button.dart';
import '../../../services/navigation_service.dart';
import '../../../services/enterprise_logger.dart';
import 'enhanced_run_screen.dart';

/// Detailed activity history screen with replay functionality
class ActivityDetailScreen extends ConsumerStatefulWidget {
  final ActivitySession session;

  const ActivityDetailScreen({super.key, required this.session});

  @override
  ConsumerState<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  double _replayProgress = 1.0;
  final MapController _mapController = MapController();
  
  // Data for charts
  List<FlSpot> _elevationSpots = [];
  List<FlSpot> _speedSpots = [];
  
  @override
  void initState() {
    super.initState();
    EnterpriseLogger().logInfo('ActivityDetailScreen', 'Initializing for session: ${widget.session.id}');
    try {
      _prepareChartData();
      EnterpriseLogger().logInfo('ActivityDetailScreen', 'Chart data prepared successfully. Elevation spots: ${_elevationSpots.length}, Speed spots: ${_speedSpots.length}');
    } catch (e, stack) {
      EnterpriseLogger().logError('ActivityDetailScreen', 'Error preparing chart data: $e', stack);
    }
  }

  void _prepareChartData() {
    _elevationSpots = [];
    _speedSpots = [];

    if (widget.session.waypoints.isEmpty) {
      EnterpriseLogger().logWarning('ActivityDetailScreen', 'No waypoints found in session');
      // Add default spots for visual representation even if no waypoints exist
      _elevationSpots = [const FlSpot(0, 0), const FlSpot(100, 10)];
      _speedSpots = [const FlSpot(0, 0), const FlSpot(100, 12)];
      return;
    }
    
    final startTime = widget.session.stats.startTime;
    
    for (var i = 0; i < widget.session.waypoints.length; i++) {
      final waypoint = widget.session.waypoints[i];
      final timeDiff = waypoint.timestamp.difference(startTime).inSeconds.toDouble() / 60; // Minutes
      
      if (waypoint.statsAtTime != null) {
        _elevationSpots.add(FlSpot(timeDiff, waypoint.statsAtTime!.elevationGain));
        _speedSpots.add(FlSpot(timeDiff, waypoint.statsAtTime!.currentSpeedMps * 3.6)); // km/h
      } else {
        // Fallback or estimation if statsAtTime is missing
        _elevationSpots.add(FlSpot(timeDiff, 0));
        _speedSpots.add(FlSpot(timeDiff, 0));
      }
    }
    
    // If we only have 1 or 0 spots, add some dummy ones for visual
    if (_elevationSpots.length < 2) {
       _elevationSpots = [const FlSpot(0, 0), const FlSpot(100, 10)];
       _speedSpots = [const FlSpot(0, 0), const FlSpot(100, 12)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = widget.session.stats;
    
    // Safety check for route points
    if (widget.session.routePoints.isEmpty) {
      EnterpriseLogger().logWarning('ActivityDetailScreen', 'Route points are empty for session ${widget.session.id}');
    }

    try {
      // Calculate current replay index
      final totalPoints = widget.session.routePoints.length;
      final currentPointIndex = totalPoints > 0 
          ? (totalPoints * _replayProgress).floor().clamp(0, totalPoints - 1)
          : 0;
      final visiblePoints = totalPoints > 0 
          ? widget.session.routePoints.take(currentPointIndex + 1).toList()
          : <LatLng>[];
      
      // Get stats at current replay point
      FitnessStats? currentStats;
      if (widget.session.waypoints.isNotEmpty) {
        final totalWaypoints = widget.session.waypoints.length;
        final currentWaypointIndex = (totalWaypoints * _replayProgress).floor().clamp(0, totalWaypoints - 1);
        currentStats = widget.session.waypoints[currentWaypointIndex].statsAtTime;
      }
      
      final displayStats = currentStats ?? stats;

      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Container(
          decoration: const BoxDecoration(
            gradient: GlobalTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                _buildHeader(theme),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        
                        // 1. Session Summary Card
                        _buildSummaryCard(theme, displayStats),
                        
                        const SizedBox(height: 24),
                        
                        // 2. Map Preview with Replay
                        _buildMapReplay(theme, visiblePoints),
                        
                        const SizedBox(height: 24),
                        
                        // Overlapping Charts Section
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              children: [
                                _buildChartSection(
                                  theme, 
                                  'Elevation vs Time', 
                                  'Elevation (m)', 
                                  _elevationSpots,
                                  GlobalTheme.primaryNeon,
                                  _replayProgress,
                                ),
                                const SizedBox(height: 12),
                                _buildChartSection(
                                  theme, 
                                  'Speed vs Time', 
                                  'Speed (km/h)', 
                                  _speedSpots,
                                  GlobalTheme.primaryAction,
                                  _replayProgress,
                                ),
                              ],
                            ),
                            
                            // Floating shared tooltip positioned between charts
                            Positioned(
                              top: 175, // Overlap point between elevation and speed charts
                              left: 20 + (MediaQuery.of(context).size.width - 190) * _replayProgress,
                              child: _buildSharedTooltip(theme, displayStats),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // 5. Scrubber Slider
                        _buildScrubber(theme),
                        
                        const SizedBox(height: 32),
                        
                        // 6. View Full Stats Button
                        AppButton.primary(
                          text: 'View Full Stats',
                          width: double.infinity,
                          icon: Icons.analytics_outlined,
                          onPressed: () => _showFullStats(context),
                        ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e, stack) {
      EnterpriseLogger().logError('ActivityDetailScreen', 'CRITICAL BUILD ERROR: $e', stack);
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Error loading activity details'),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showFullStats(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: GlobalTheme.backgroundPrimary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FULL ACTIVITY STATS',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: Colors.white10),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: StatsDisplay(
                    stats: widget.session.stats,
                    state: ActivityState.completed,
                    accentColor: GlobalTheme.primaryNeon,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(GlobalTheme.spacing16),
      child: Row(
        children: [
          // Back button - Standardised
          Container(
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

          const SizedBox(width: GlobalTheme.spacing16),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity Details',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: GlobalTheme.textPrimary,
                  ),
                ),
                Text(
                  'Review your session and metrics',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: GlobalTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, FitnessStats stats) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Text(
            'SESSION SUMMARY',
            style: theme.textTheme.labelLarge?.copyWith(
              color: GlobalTheme.primaryNeon,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                (stats.totalDistanceMeters / 1000).toStringAsFixed(2), 
                'km', 
                'Distance', 
                Icons.route, 
                GlobalTheme.primaryAccent,
              ),
              _buildSummaryItem(
                _formatDurationShort(stats.activeDuration), 
                '', 
                'Time', 
                Icons.timer, 
                GlobalTheme.primaryAction,
              ),
              _buildSummaryItem(
                stats.formattedAveragePace.split('/')[0], 
                '', 
                'Pace', 
                Icons.speed, 
                const Color(0xFFD4AF37),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String value, String unit, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMapReplay(ThemeData theme, List<LatLng> visiblePoints) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.session.routePoints.isNotEmpty 
                ? widget.session.routePoints.first 
                : const LatLng(0, 0),
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fitness.mobile',
            ),
            if (visiblePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: visiblePoints,
                    strokeWidth: 4.0,
                    color: const Color(0xFF00BCD4),
                  ),
                ],
              ),
            if (visiblePoints.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: visiblePoints.last,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(
    ThemeData theme, 
    String title, 
    String yLabel, 
    List<FlSpot> spots, 
    Color color,
    double progress,
  ) {
    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate interpolated point for smooth movement
    final double exactIndex = (spots.length - 1) * progress;
    final int lowerIndex = exactIndex.floor();
    final int upperIndex = exactIndex.ceil();
    final double t = exactIndex - lowerIndex;

    final lowerSpot = spots[lowerIndex];
    final upperSpot = spots[upperIndex];
    final currentY = lowerSpot.y + (upperSpot.y - lowerSpot.y) * t;
    
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final rangeY = (maxY - minY).abs() < 0.001 ? 1.0 : (maxY - minY);
    
    // Calculate vertical offset (fl_chart Y increases UP, but Positioned 'top' increases DOWN)
    final relativeY = (currentY - minY) / rangeY;
    final dotTop = 100 * (1.0 - relativeY); // 100 is approx height of chart area inside the 120 container

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 120,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                      getDrawingVerticalLine: (value) => FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                          ),
                        ),
                        axisNameWidget: Text(
                          yLabel,
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                          ),
                        ),
                        axisNameWidget: Text(
                          'Time (m)',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    minY: minY,
                    maxY: maxY,
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color.withOpacity(0.3),
                              color.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Scrubber Vertical Line
              Positioned(
                left: 30 + (MediaQuery.of(context).size.width - 100) * progress,
                top: 0,
                bottom: 20,
                child: Container(
                  width: 2,
                  color: color.withOpacity(0.5),
                ),
              ),
              
              // Dot on the scrubber line - smoothly follows the curve
              Positioned(
                left: 30 + (MediaQuery.of(context).size.width - 100) * progress - 5,
                top: dotTop + 10, // Adjusted for padding/alignment
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSharedTooltip(ThemeData theme, FitnessStats stats) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDuration(stats.activeDuration),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const Divider(height: 12, color: Colors.black12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.speed, size: 14, color: GlobalTheme.primaryAction),
              Text(
                '${(stats.currentSpeedMps * 3.6).toStringAsFixed(1)} km/h',
                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.terrain, size: 14, color: GlobalTheme.primaryNeon),
              Text(
                '${stats.elevationGain.toStringAsFixed(1)} m',
                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScrubber(ThemeData theme) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 6,
          activeTrackColor: GlobalTheme.primaryNeon,
          inactiveTrackColor: Colors.white.withOpacity(0.1),
          thumbColor: GlobalTheme.primaryNeon,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15),
          overlayColor: GlobalTheme.primaryNeon.withOpacity(0.2),
        ),
        child: Slider(
          value: _replayProgress,
          onChanged: (value) {
            setState(() => _replayProgress = value);
            // Center map on current point
            if (widget.session.routePoints.isNotEmpty) {
              final totalPoints = widget.session.routePoints.length;
              final index = (totalPoints * value).floor().clamp(0, totalPoints - 1);
              _mapController.move(widget.session.routePoints[index], _mapController.camera.zoom);
            }
          },
        ),
      ),
    );
  }

  Widget _buildFullStatsButton(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [GlobalTheme.primaryNeon, GlobalTheme.primaryNeon.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: GlobalTheme.primaryNeon.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // View full stats logic
          },
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Text(
              'View Full Stats',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
  
  String _formatDurationShort(Duration d) {
    final m = d.inMinutes;
    return '${m}m';
  }
}
