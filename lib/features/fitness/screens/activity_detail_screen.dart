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
    _prepareChartData();
  }

  void _prepareChartData() {
    if (widget.session.waypoints.isEmpty) return;
    
    final startTime = widget.session.stats.startTime;
    
    for (var i = 0; i < widget.session.waypoints.length; i++) {
      final waypoint = widget.session.waypoints[i];
      final timeDiff = waypoint.timestamp.difference(startTime).inSeconds.toDouble();
      
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
    
    // Calculate current replay index
    final totalPoints = widget.session.routePoints.length;
    final currentPointIndex = (totalPoints * _replayProgress).floor().clamp(0, totalPoints - 1);
    final visiblePoints = widget.session.routePoints.take(currentPointIndex + 1).toList();
    
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
                      
                      // 3. Elevation Chart
                      _buildChartSection(
                        theme, 
                        'Elevation vs Time', 
                        'Elevation (m)', 
                        _elevationSpots,
                        GlobalTheme.primaryNeon,
                        _replayProgress,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 4. Speed Chart
                      _buildChartSection(
                        theme, 
                        'Speed vs Time', 
                        'Speed (km/h)', 
                        _speedSpots,
                        GlobalTheme.primaryAction,
                        _replayProgress,
                        showTooltip: true,
                        currentValue: (displayStats.currentSpeedMps * 3.6).toStringAsFixed(1),
                        currentTime: _formatDuration(displayStats.activeDuration),
                        currentDistance: (displayStats.totalDistanceMeters / 1000).toStringAsFixed(2),
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
                        onPressed: () {
                          // View full stats logic
                        },
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
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Back', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Run Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 60), // Balance the back button
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
    {bool showTooltip = false, String? currentValue, String? currentTime, String? currentDistance}
  ) {
    final maxTime = spots.last.x;
    final currentTimeX = maxTime * progress;
    
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
                  color: color,
                ),
              ),
              
              // Tooltip on the scrubber
              if (showTooltip && progress > 0.1)
                Positioned(
                  left: 30 + (MediaQuery.of(context).size.width - 100) * progress - 45,
                  top: 40,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          currentTime ?? '',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          '$currentDistance km',
                          style: const TextStyle(color: Colors.black, fontSize: 10),
                        ),
                        Text(
                          '$currentValue km/h',
                          style: const TextStyle(color: Colors.black, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Dot on the scrubber line
              Positioned(
                left: 30 + (MediaQuery.of(context).size.width - 100) * progress - 5,
                top: 20, // Adjust based on actual data point
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
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
