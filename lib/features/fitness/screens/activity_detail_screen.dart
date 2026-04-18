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
  double _maxX = 1.0;

  // Zeroed out for full-width graphs without labels
  static const double _chartSideReserved = 0.0;
  static const double _chartNameReserved = 0.0;
  static const double _totalLeftOffset = 0.0;
  static const double _chartBottomReserved = 0.0;
  
  @override
  void initState() {
    super.initState();
    EnterpriseLogger().logInfo('ActivityDetailScreen', 'Initializing for session: ${widget.session.id}');
    try {
      _prepareChartData();
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
      _maxX = 100.0;
      return;
    }
    
    final startTime = widget.session.stats.startTime;
    
    for (var i = 0; i < widget.session.waypoints.length; i++) {
      final waypoint = widget.session.waypoints[i];
      final timeDiff = waypoint.timestamp.difference(startTime).inSeconds.toDouble() / 60; // Minutes
      
      // Use explicit altitude if available, otherwise fallback to elevation gain
      final altitude = waypoint.altitude ?? (waypoint.statsAtTime?.elevationGain ?? 0);
      _elevationSpots.add(FlSpot(timeDiff, altitude));

      if (waypoint.statsAtTime != null) {
        _speedSpots.add(FlSpot(timeDiff, waypoint.statsAtTime!.currentSpeedMps * 3.6)); // km/h
      } else {
        // Fallback or estimation if statsAtTime is missing
        _speedSpots.add(FlSpot(timeDiff, 0));
      }
    }
    
    // If we only have 1 or 0 spots, add some dummy ones for visual
    if (_elevationSpots.length < 2) {
       _elevationSpots = [const FlSpot(0, 0), const FlSpot(100, 10)];
       _speedSpots = [const FlSpot(0, 0), const FlSpot(100, 12)];
    }

    _maxX = _elevationSpots.last.x;
  }

  FitnessStats _interpolateStats(FitnessStats s1, FitnessStats s2, double t, {double? alt1, double? alt2}) {
    final a1 = alt1 ?? s1.altitude;
    final a2 = alt2 ?? s2.altitude;

    return FitnessStats(
      totalDistanceMeters: s1.totalDistanceMeters + (s2.totalDistanceMeters - s1.totalDistanceMeters) * t,
      totalDuration: Duration(milliseconds: (s1.totalDuration.inMilliseconds + (s2.totalDuration.inMilliseconds - s1.totalDuration.inMilliseconds) * t).toInt()),
      activeDuration: Duration(milliseconds: (s1.activeDuration.inMilliseconds + (s2.activeDuration.inMilliseconds - s1.activeDuration.inMilliseconds) * t).toInt()),
      movingDuration: Duration(milliseconds: (s1.movingDuration.inMilliseconds + (s2.movingDuration.inMilliseconds - s1.movingDuration.inMilliseconds) * t).toInt()),
      stationaryDuration: Duration(milliseconds: (s1.stationaryDuration.inMilliseconds + (s2.stationaryDuration.inMilliseconds - s1.stationaryDuration.inMilliseconds) * t).toInt()),
      averageSpeedMps: s1.averageSpeedMps + (s2.averageSpeedMps - s1.averageSpeedMps) * t,
      currentSpeedMps: s1.currentSpeedMps + (s2.currentSpeedMps - s1.currentSpeedMps) * t,
      startTime: s1.startTime,
      totalSteps: (s1.totalSteps + (s2.totalSteps - s1.totalSteps) * t).toInt(),
      elevationGain: s1.elevationGain + (s2.elevationGain - s1.elevationGain) * t,
      altitude: a1 + (a2 - a1) * t,
    );
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
      // Calculate current replay index and interpolated data
      final totalPoints = widget.session.routePoints.length;
      final currentPointIndex = totalPoints > 0 
          ? (totalPoints * _replayProgress).floor().clamp(0, totalPoints - 1)
          : 0;
      final visiblePoints = totalPoints > 0 
          ? widget.session.routePoints.take(currentPointIndex + 1).toList()
          : <LatLng>[];
      
      FitnessStats displayStats = stats;
      double currentX = 0;

      if (widget.session.waypoints.isNotEmpty) {
        final totalWaypoints = widget.session.waypoints.length;
        final double exactIndex = (totalWaypoints - 1) * _replayProgress;
        final int lowerIndex = exactIndex.floor();
        final int upperIndex = exactIndex.ceil();
        final double t = exactIndex - lowerIndex;

        final w1 = widget.session.waypoints[lowerIndex];
        final w2 = widget.session.waypoints[upperIndex];
        
        final startTime = widget.session.stats.startTime;
        final x1 = w1.timestamp.difference(startTime).inSeconds.toDouble() / 60;
        final x2 = w2.timestamp.difference(startTime).inSeconds.toDouble() / 60;
        currentX = x1 + (x2 - x1) * t;

        if (w1.statsAtTime != null && w2.statsAtTime != null) {
          displayStats = _interpolateStats(
            w1.statsAtTime!, 
            w2.statsAtTime!, 
            t,
            alt1: w1.altitude,
            alt2: w2.altitude,
          );
        } else {
          final alt1 = w1.altitude ?? (w1.statsAtTime?.altitude ?? stats.altitude);
          final alt2 = w2.altitude ?? (w2.statsAtTime?.altitude ?? stats.altitude);
          final currentAlt = alt1 + (alt2 - alt1) * t;
          displayStats = (w1.statsAtTime ?? stats).copyWith(altitude: currentAlt);
        }
      } else {
        currentX = _maxX * _replayProgress;
      }

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
                        
                        // 1. Session Summary Card (use full session stats, not interpolated replay data)
                        _buildSummaryCard(theme, widget.session.stats),
                        
                        const SizedBox(height: 24),

                        // Weather Info (if available)
                        if (widget.session.startWeather != null)
                          _buildWeatherSection(theme, widget.session.startWeather!),

                        if (widget.session.startWeather != null)
                          const SizedBox(height: 24),
                        
                        // 2. Map Preview with Replay
                        _buildMapReplay(theme, visiblePoints),
                        
                        const SizedBox(height: 24),
                        
                        // Overlapping Charts Section
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final chartContainerWidth = constraints.maxWidth;
                            // horizontalOffset = left container padding (20)
                            const horizontalOffset = 20.0;
                            final dataAreaWidth = chartContainerWidth - 40.0;
                            
                            final scrubberX = horizontalOffset + (dataAreaWidth * (currentX / _maxX));
                            // Clamp tooltip between left edge (0) and right edge (width - tooltip width)
                            final tooltipLeft = (scrubberX - 65).clamp(0.0, chartContainerWidth - 130.0);

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Column(
                                  children: [
                                    _buildChartSection(
                                      theme, 
                                      'Altitude vs Time', 
                                      'Altitude (m)', 
                                      _elevationSpots,
                                      GlobalTheme.primaryNeon,
                                      currentX,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildChartSection(
                                      theme, 
                                      'Speed vs Time', 
                                      'Speed (km/h)', 
                                      _speedSpots,
                                      GlobalTheme.primaryAction,
                                      currentX,
                                    ),
                                  ],
                                ),
                                
                                // Floating shared tooltip positioned between charts
                                Positioned(
                                  top: 175,
                                  left: tooltipLeft,
                                  child: _buildSharedTooltip(theme, displayStats),
                                ),
                              ],
                            );
                          }
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
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.75,
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
              // Handle bar section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1A0F), // Dark green carbon theme
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GlobalTheme.primaryAccent, // Vivid green handle
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: GlobalTheme.primaryAccent.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Expanded(                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: StatsDisplay(
                   stats: widget.session.stats,
                   state: ActivityState.completed,
                   activityType: widget.session.activityType,
                   accentColor: GlobalTheme.primaryNeon,
                   session: widget.session,
                  ),                ),
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
                '', 
                'DISTANCE (KM)', 
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
                stats.formattedAveragePace, 
                '', 
                'Pace (/km)', 
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
                    strokeWidth: 5.0,
                    color: Colors.black,
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

  List<FlSpot> _calculateWMA(List<FlSpot> spots, {int windowSize = 5, bool dropToZero = false}) {
    if (spots.length < windowSize) return List.from(spots);
    
    List<FlSpot> smoothed = [];
    
    // Weighted moving average: (P1*1 + P2*2 + ... + Pn*n) / (1 + 2 + ... + n)
    int divisor = 0;
    for (int i = 1; i <= windowSize; i++) divisor += i;
    
    for (int i = 0; i < spots.length; i++) {
      // If dropToZero is enabled and current raw value is 0, force smoothed value to 0 instantly
      if (dropToZero && (spots[i].y).abs() < 0.001) {
        smoothed.add(FlSpot(spots[i].x, 0));
        continue;
      }

      if (i < windowSize - 1) {
        smoothed.add(spots[i]);
        continue;
      }
      
      double sum = 0;
      for (int j = 0; j < windowSize; j++) {
        sum += spots[i - (windowSize - 1) + j].y * (j + 1);
      }
      
      smoothed.add(FlSpot(spots[i].x, sum / divisor));
    }
    
    return smoothed;
  }

  Widget _buildChartSection(
    ThemeData theme, 
    String title, 
    String yLabel, 
    List<FlSpot> spots, 
    Color color,
    double currentX,
  ) {
    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    final isAltitude = title.toLowerCase().contains('altitude');
    final isSpeed = title.toLowerCase().contains('speed');
    final smoothedSpots = _calculateWMA(
      spots,
      windowSize: isAltitude ? 12 : 5,
      dropToZero: isSpeed,
    );

    // User request: Altitude Raw = Blue, Altitude Smoothed = Vivid Green (primaryAccent)
    final rawLineColor = isAltitude ? Colors.blue : color;
    final smoothedLineColor = isAltitude ? GlobalTheme.primaryAccent : (title.toLowerCase().contains('speed') 
        ? GlobalTheme.statusWarning 
        : GlobalTheme.primaryAction);

    // Calculate interpolated Y for the given currentX
    double currentY = 0;
    for (var i = 0; i < spots.length - 1; i++) {
      if (currentX >= spots[i].x && currentX <= spots[i+1].x) {
        final t = (currentX - spots[i].x) / (spots[i+1].x - spots[i].x);
        currentY = spots[i].y + (spots[i+1].y - spots[i].y) * t;
        break;
      }
    }

    // Handle bounds
    if (currentX <= spots.first.x) currentY = spots.first.y;
    if (currentX >= spots.last.x) currentY = spots.last.y;

    final dataMinY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final dataMaxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final dataRange = (dataMaxY - dataMinY).abs() < 0.001 ? 1.0 : (dataMaxY - dataMinY);

    // To place data in the middle third, we add one full dataRange worth of padding above and below
    double minY = dataMinY - dataRange;
    double maxY = dataMaxY + dataRange;

    // Safety: Speed and Altitude (usually) shouldn't show negative axes in this context unless necessary
    // For speed specifically, we definitely don't want to go below 0
    if (title.toLowerCase().contains('speed') && minY < 0) {
      minY = 0;
    }

    final displayRange = (maxY - minY).abs() < 0.001 ? 1.0 : (maxY - minY);
    final relativeY = (currentY - minY) / displayRange;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Legend
              Row(
                children: [
                  _buildLegendItem('Raw', rawLineColor),
                  const SizedBox(width: 12),
                  _buildLegendItem('Smoothed', smoothedLineColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final dataWidth = constraints.maxWidth;
              final dataHeight = 120.0;

              final dotLeft = (dataWidth * (currentX / _maxX));
              final dotTop = dataHeight * (1.0 - relativeY);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    height: 120,
                    child: LineChart(
                      LineChartData(
                        lineTouchData: const LineTouchData(
                          handleBuiltInTouches: false,
                        ),
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
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        minX: 0,
                        maxX: _maxX,
                        minY: minY,
                        maxY: maxY,
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          // Raw Data Line
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: rawLineColor.withOpacity(0.4),
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                          ),
                          // Smoothed WMA Line
                          LineChartBarData(
                            spots: smoothedSpots,
                            isCurved: true,
                            color: smoothedLineColor,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  smoothedLineColor.withOpacity(0.3),
                                  smoothedLineColor.withOpacity(0.0),
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
                    left: dotLeft,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),

                  // Dot on the scrubber line
                  Positioned(
                    left: dotLeft - 6,
                    top: dotTop - 6,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: smoothedLineColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: smoothedLineColor.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
              const Icon(Icons.terrain, size: 14, color: GlobalTheme.primaryAccent),
              Text(
                '${stats.altitude.toStringAsFixed(1)} m',
                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.speed, size: 14, color: GlobalTheme.statusWarning),
              Text(
                '${(stats.currentSpeedMps * 3.6).toStringAsFixed(1)} km/h',
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
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    
    if (hours > 0) {
      return '$hours:$minutesStr:$secondsStr';
    }
    return '$minutesStr:$secondsStr';
  }
  
  String _formatDurationShort(Duration d) {
    return _formatDuration(d);
  }

  Widget _buildWeatherSection(ThemeData theme, WeatherData weather) {
    return Container(
      padding: const EdgeInsets.all(GlobalTheme.spacing20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_cloudy_rounded,
                color: GlobalTheme.primaryNeon,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'WEATHER AT START',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: GlobalTheme.primaryNeon,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (weather.location != null)
                Text(
                  '${weather.location!.name}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${weather.tempC.toStringAsFixed(1)}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weather.conditionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Feels like ${weather.feelsLikeC.toStringAsFixed(1)}°',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (weather.conditionIcon.isNotEmpty)
                Image.network(
                  weather.conditionIcon.startsWith('http') ? weather.conditionIcon : 'https:${weather.conditionIcon}',
                  width: 44,
                  height: 44,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.wb_cloudy_outlined,
                    color: GlobalTheme.primaryNeon,
                    size: 32,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSmallWeatherStat('Wind', '${weather.windKph.toStringAsFixed(1)} km/h', Icons.air_rounded),
              _buildSmallWeatherStat('Humidity', '${weather.humidity}%', Icons.water_drop_rounded),
              _buildSmallWeatherStat('Precip', '${weather.precipMm.toStringAsFixed(1)} mm', Icons.umbrella_rounded),
              _buildSmallWeatherStat('UV', weather.uv.toStringAsFixed(1), Icons.wb_sunny_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallWeatherStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.3), size: 14),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
