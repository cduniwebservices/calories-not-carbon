import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/fitness_models.dart';
import '../../../providers/activity_providers.dart';
import '../../../components/interactive_map_widget.dart';
import '../../../components/fitness_tracking_widgets.dart';
import '../../../services/navigation_service.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/global_theme.dart';
import '../../debug/debug_screen.dart';

/// Million-dollar level fitness tracking screen with real-time GPS integration
class EnhancedRunScreen extends ConsumerStatefulWidget {
  const EnhancedRunScreen({super.key});

  @override
  ConsumerState<EnhancedRunScreen> createState() => _EnhancedRunScreenState();
}

class _EnhancedRunScreenState extends ConsumerState<EnhancedRunScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  ActivityType _selectedActivityType = ActivityType.running;
  bool _isInitialized = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeActivityController();

    // Check for auto-start parameter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoStartParameter();
    });
  }

  Future<void> _checkAutoStartParameter() async {
    // Auto-start immediately when screen loads
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      final actions = ref.read(activityActionsProvider);
      await _handleStartActivity(actions);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeActivityController() async {
    try {
      final actions = ref.read(activityActionsProvider);
      await actions.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing activity controller: $e');
      // Show user-friendly error but don't block the UI
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activityState = ref.watch(activityStateProvider);
    final fitnessStats = ref.watch(fitnessStatsProvider);
    final routePoints = ref.watch(routePointsProvider);
    final actions = ref.read(activityActionsProvider);
    final mediaQuery = MediaQuery.of(context);

    if (!_isInitialized) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // PERFORMANCE FIX: Simple loading indicator
                CircularProgressIndicator(color: theme.primaryColor),
                SizedBox(height: mediaQuery.size.height * 0.02),
                Text('Initializing GPS...', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // App bar with activity status
                _buildAppBar(theme, activityState, fitnessStats, actions),

                // Tab bar for Map/Stats view
                if (activityState != ActivityState.idle)
                  _buildTabBar(theme)
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: -0.1, end: 0),

                // Main content area
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: activityState == ActivityState.idle
                        ? _buildLoadingView(theme)
                        : _buildActiveTrackingView(
                            theme,
                            activityState,
                            fitnessStats,
                            routePoints,
                            actions,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(
    ThemeData theme,
    ActivityState state,
    FitnessStats stats,
    ActivityActions actions,
  ) {
    final statusText = _getStatusText(state);
    final statusColor = _getStatusColor(state, theme);
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.height < 700;
    final speedKmh = stats.currentSpeedMps * 3.6;
    final speedIcon = _getActivityIconFromSpeed(speedKmh);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        isCompact ? 8 : 16,
        20,
        isCompact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: GlobalTheme.primaryNeon,
            child: Icon(
              speedIcon,
              color: Colors.black,
              size: isCompact ? 22 : 24,
            ),
          )
          .animate()
          .scale(duration: 400.ms, curve: Curves.elasticOut),

          const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => DebugScreenOverlay.show(context),
                      child: Text(
                        'Calories Not Carbon',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: GlobalTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2, end: 0),

                const SizedBox(height: 2),

                Text(
                  statusText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: GlobalTheme.textSecondary,
                  ),
                ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1, end: 0),
              ],
            ),
          ),

          if (state != ActivityState.idle)
            AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 12,
                    vertical: isCompact ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          )
                          .animate(onPlay: (controller) => controller.repeat())
                          .fadeIn(duration: 800.ms)
                          .fadeOut(duration: 800.ms),

                      SizedBox(width: isCompact ? 6 : 8),

                      Text(
                        state.displayName.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          fontSize: isCompact ? 10 : 11,
                        ),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(delay: 300.ms)
                .slideX(begin: 0.3, end: 0, curve: Curves.elasticOut),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      color: Colors.black87,
      child: TabBar(
        controller: _tabController,
        indicatorColor: GlobalTheme.primaryNeon,
        indicatorWeight: 3,
        labelColor: GlobalTheme.primaryNeon,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: const [
          Tab(icon: Icon(Icons.map, size: 24), text: 'Map'),
          Tab(icon: Icon(Icons.analytics_outlined, size: 24), text: 'Stats'),
        ],
      ),
    );
  }

  Widget _buildLoadingView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GlobalTheme.primaryNeon),
          const SizedBox(height: 16),
          Text(
            'Searching for GPS satellites...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTrackingView(
    ThemeData theme,
    ActivityState state,
    FitnessStats stats,
    List<LatLng> routePoints,
    ActivityActions actions,
  ) {
    return TabBarView(
      controller: _tabController,
      children: [
        // Map view
        _buildMapView(theme, state, stats, routePoints, actions),

        // Stats view
        _buildStatsView(theme, state, stats, actions),
      ],
    );
  }

  Widget _buildMapView(
    ThemeData theme,
    ActivityState state,
    FitnessStats stats,
    List<LatLng> routePoints,
    ActivityActions actions,
  ) {
    return Stack(
      children: [
        // Interactive map
        Positioned.fill(
          child: InteractiveMapWidget(
            showCurrentLocation: true,
            showRoute: true,
            enableTracking: state.isActive,
            routeColor: theme.primaryColor,
            accentColor: theme.primaryColor,
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ActivityControlsWidget(
            state: state,
            activityType: actions.activityType,
            onPause: () => _handlePauseActivity(actions),
            onResume: () => _handleResumeActivity(actions),
            onStop: () => _handleStopActivity(actions),
            accentColor: theme.primaryColor,
            isLoading: _isLoading,
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0),
        ),
      ],
    );
  }

  Widget _buildStatsView(
    ThemeData theme,
    ActivityState state,
    FitnessStats stats,
    ActivityActions actions,
  ) {
    return Stack(
      children: [
        // Stats content
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 120, // Space for floating buttons
            ),
            child: StatsDisplay(
              stats: stats,
              state: state,
              accentColor: theme.primaryColor,
            ),
          ),
        ),

        // Floating controls at the bottom
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: ActivityControlsWidget(
            state: state,
            activityType: actions.activityType,
            onPause: () => _handlePauseActivity(actions),
            onResume: () => _handleResumeActivity(actions),
            onStop: () => _handleStopActivity(actions),
            accentColor: theme.primaryColor,
            isLoading: _isLoading,
          ),
        ),
      ],
    );
  }
}

/// Specialized widget for the high-end stats display
class StatsDisplay extends ConsumerWidget {
  final FitnessStats stats;
  final ActivityState state;
  final Color accentColor;

  const StatsDisplay({
    super.key,
    required this.stats,
    required this.state,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goalState = ref.watch(goalProvider);
    final selectedGoal = goalState.selectedGoal ?? sampleGoals.first;
    
    // Calculate CO2 saved
    final distanceKm = stats.totalDistanceMeters / 1000.0;
    final co2SavedKg = distanceKm * selectedGoal.co2PerKm;
    
    return Column(
      children: [
        // 1. Large Timer Display
        _buildLargeTimer(theme, stats.activeDuration),
        
        const SizedBox(height: 8),
        Text(
          'ACTIVE DURATION',
          style: theme.textTheme.labelSmall?.copyWith(
            color: GlobalTheme.textTertiary,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 32),

        // 2. CO2 Saved Section (Green Panel)
        _buildCO2Panel(theme, co2SavedKg),

        const SizedBox(height: 32),

        // 3. Stats Grid (4 items)
        _buildStatsGrid(theme),

        const SizedBox(height: 40),

        // 4. Max Speed & Elevation Gain
        _buildSecondaryStats(theme),

        const SizedBox(height: 40),

        // 5. Time Moving & Time Stationary
        _buildTimeStats(theme),

        const SizedBox(height: 40),

        // 6. Start Times
        _buildStartTimes(theme),

        const SizedBox(height: 40),

        // 7. Weather & Humidity
        _buildWeatherInfo(theme),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLargeTimer(ThemeData theme, Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    final timeText = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Text(
      timeText,
      style: theme.textTheme.displayLarge?.copyWith(
        fontSize: 100,
        fontWeight: FontWeight.w800,
        color: GlobalTheme.primaryNeon,
        letterSpacing: -4,
        height: 1.0,
        shadows: [
          Shadow(
            color: GlobalTheme.primaryNeon.withOpacity(0.3),
            blurRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCO2Panel(ThemeData theme, double co2Saved) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A0F),
        borderRadius: BorderRadius.circular(4),
        border: const Border(
          top: BorderSide(color: Color(0xFF1A331A), width: 1),
          bottom: BorderSide(color: Color(0xFF1A331A), width: 1),
        ),
        image: DecorationImage(
          image: const AssetImage('assets/images/leaf_texture.png'), // Placeholder if not exist
          opacity: 0.1,
          fit: BoxFit.cover,
          onError: (_, __) => {},
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CURRENT CO2 SAVED:',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF4A664A),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'CO2 OFFSET POTENTIAL:',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF4A664A),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.eco_outlined, color: GlobalTheme.primaryAccent, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'CO2 SAVED: ',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: GlobalTheme.primaryAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: '${co2Saved.toStringAsFixed(1)} kg',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: GlobalTheme.primaryAccent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Offset: ${(co2Saved * 1000 / 5.2).toStringAsFixed(0)} g', // Arbitrary calculation for 'Offset'
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4A664A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildGridItem(theme, 'DISTANCE\n(km)', stats.formattedDistance.split(' ')[0], Icons.directions_run),
            _buildGridItem(theme, 'AVG SPEED\n(km/h)', (stats.averageSpeedMps * 3.6).toStringAsFixed(1), Icons.speed),
            _buildGridItem(theme, 'CURRENT\nPACE', stats.formattedCurrentPace, Icons.timer_outlined),
            _buildGridItem(theme, 'CALORIES', stats.estimatedCalories.toString(), Icons.local_fire_department_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildGridItem(ThemeData theme, String label, String value, IconData icon) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: GlobalTheme.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Icon(icon, color: GlobalTheme.primaryNeon, size: 24),
        const SizedBox(height: 12),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        Text(
          label.contains('DISTANCE') ? 'km' : (label.contains('SPEED') ? 'km/h' : (label.contains('PACE') ? '/km' : 'cal')),
          style: theme.textTheme.labelSmall?.copyWith(
            color: GlobalTheme.textTertiary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryStats(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildHalfWidthStat(theme, 'MAX SPEED (km/h):', '${(stats.maxSpeedMps * 3.6).toStringAsFixed(1)} km/h', Icons.speed),
        _buildHalfWidthStat(theme, 'ELEVATION GAIN (m):', '${stats.elevationGain.toStringAsFixed(0)} m', Icons.terrain_outlined),
      ],
    );
  }

  Widget _buildHalfWidthStat(ThemeData theme, String label, String value, IconData icon) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: GlobalTheme.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Icon(icon, color: GlobalTheme.primaryNeon, size: 28),
        const SizedBox(height: 12),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: GlobalTheme.primaryNeon,
            fontSize: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeStats(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildHalfWidthStat(theme, 'TIME MOVING:', stats.formattedActiveDuration, Icons.directions_walk),
        _buildHalfWidthStat(theme, 'TIME STATIONARY:', _formatDuration(stats.totalDuration - stats.activeDuration), Icons.pause_circle_outline),
      ],
    );
  }

  Widget _buildStartTimes(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildTimeItem(theme, 'LOCAL START:', _formatTime(stats.startTime), 'ACST'),
        _buildTimeItem(theme, 'UTC START:', _formatTime(stats.startTime.toUtc()), 'UTC'),
      ],
    );
  }

  Widget _buildTimeItem(ThemeData theme, String label, String value, String tz) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: GlobalTheme.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: GlobalTheme.primaryNeon,
            fontSize: 24,
          ),
        ),
        Text(
          tz,
          style: theme.textTheme.labelSmall?.copyWith(
            color: GlobalTheme.textTertiary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherInfo(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildWeatherItem(theme, 'CURRENT WEATHER:', '28°C, Partly Cloudy', Icons.wb_cloudy_outlined),
        _buildWeatherItem(theme, 'HUMIDITY:', '65%', Icons.opacity),
      ],
    );
  }

  Widget _buildWeatherItem(ThemeData theme, String label, String value, IconData icon) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: GlobalTheme.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (label.contains('WEATHER'))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: GlobalTheme.primaryNeon, size: 28),
              const SizedBox(width: 8),
              Text(
                value.split(',')[0],
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: GlobalTheme.primaryNeon,
                  fontSize: 24,
                ),
              ),
            ],
          )
        else
          Icon(icon, color: GlobalTheme.primaryNeon, size: 28),
        const SizedBox(height: 8),
        Text(
          label.contains('WEATHER') ? value.split(',')[1].trim() : value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: GlobalTheme.primaryNeon,
            fontSize: 24,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }
}

  Widget _buildFeaturesShowcase(ThemeData theme) {
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.height < 700;

    final features = [
      {
        'icon': Icons.gps_fixed,
        'title': 'Real-time GPS',
        'description': 'Accurate location tracking with live route mapping',
        'delay': 800,
      },
      {
        'icon': Icons.speed,
        'title': 'Live Metrics',
        'description':
            'Distance, pace, time, and calories updated every second',
        'delay': 900,
      },
      {
        'icon': Icons.save,
        'title': 'Session History',
        'description': 'Save and review your workout sessions',
        'delay': 1000,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isCompact ? 18 : null,
          ),
        ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.2, end: 0),

        SizedBox(height: isCompact ? 16 : 20),

        ...features.asMap().entries.map((entry) {
          final feature = entry.value;

          return Container(
                margin: EdgeInsets.only(bottom: isCompact ? 16 : 20),
                child: InkWell(
                  onTap: () async {
                    // Add haptic feedback for interactions
                    await HapticFeedback.lightImpact();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 16 : 20),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isCompact ? 12 : 16),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.primaryColor.withOpacity(0.2),
                            ),
                          ),
                          child: Icon(
                            feature['icon'] as IconData,
                            color: theme.primaryColor,
                            size: isCompact ? 20 : 24,
                          ),
                        ),

                        SizedBox(width: isCompact ? 16 : 20),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feature['title'] as String,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isCompact ? 14 : null,
                                ),
                              ),
                              SizedBox(height: isCompact ? 4 : 6),
                              Text(
                                feature['description'] as String,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                  height: 1.4,
                                  fontSize: isCompact ? 12 : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: Duration(milliseconds: feature['delay'] as int))
              .slideX(begin: 0.3, end: 0, curve: Curves.easeOutCubic);
        }).toList(),
      ],
    );
  }

  // Helper methods
  String _getStatusText(ActivityState state) {
    switch (state) {
      case ActivityState.idle:
        return 'HEALTHY HUMANS, HEALTHY PLANET';
      case ActivityState.running:
        return 'Activity in progress';
      case ActivityState.paused:
        return 'Activity paused';
      case ActivityState.completed:
        return 'Activity completed';
    }
  }

  Color _getStatusColor(ActivityState state, ThemeData theme) {
    switch (state) {
      case ActivityState.idle:
        return theme.colorScheme.onSurface.withOpacity(0.7);
      case ActivityState.running:
        return theme.primaryColor;
      case ActivityState.paused:
        return GlobalTheme.statusSuccess;
      case ActivityState.completed:
        return Colors.green;
    }
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.running:
        return Icons.directions_run;
      case ActivityType.walking:
        return Icons.directions_walk;
      case ActivityType.cycling:
        return Icons.directions_bike;
      case ActivityType.hiking:
        return Icons.terrain;
    }
  }

  IconData _getActivityIconFromSpeed(double speedKmh) {
    if (speedKmh < 6.0) {
      return Icons.directions_walk;
    } else if (speedKmh < 20.0) {
      return Icons.directions_run;
    } else {
      return Icons.directions_bike;
    }
  }

  // Action handlers with enhanced UX
  Future<void> _handleStartActivity(ActivityActions actions) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Haptic feedback for start action
      await HapticFeedback.mediumImpact();

      final success = await actions.startActivity(_selectedActivityType);
      if (!success) {
        await HapticFeedback.mediumImpact();
        _showErrorSnackBar(
          'Failed to start activity. Please check GPS and permissions.',
        );
      } else {
        // Success haptic feedback
        await HapticFeedback.mediumImpact();
      }
    } catch (e) {
      await HapticFeedback.mediumImpact();
      _showErrorSnackBar('Error starting activity: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePauseActivity(ActivityActions actions) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await HapticFeedback.mediumImpact();
      await actions.pauseActivity();
    } catch (e) {
      await HapticFeedback.mediumImpact();
      _showErrorSnackBar('Error pausing activity: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResumeActivity(ActivityActions actions) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await HapticFeedback.mediumImpact();
      await actions.resumeActivity();
    } catch (e) {
      await HapticFeedback.mediumImpact();
      _showErrorSnackBar('Error resuming activity: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleStopActivity(ActivityActions actions) async {
    final shouldStop = await _showStopConfirmation();
    if (!shouldStop) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await HapticFeedback.mediumImpact();

      // Stop the activity and get the completed session
      final success = await actions.stopActivity();
      if (!success) {
        await HapticFeedback.mediumImpact();
        _showErrorSnackBar('Failed to stop activity. Please try again.');
        return;
      }

      // Get the completed session from the controller
      final completedSession = ref
          .read(activityControllerProvider)
          .currentSession;
      if (completedSession == null) {
        await HapticFeedback.mediumImpact();
        _showErrorSnackBar('Session data not available. Activity stopped.');
        return;
      }

      // Success feedback
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.mediumImpact();

      // Navigate to session summary screen with session data
      if (mounted) {
        NavigationService.goToSessionSummary(context, completedSession);
      }
    } catch (e) {
      await HapticFeedback.mediumImpact();
      _showErrorSnackBar('Error stopping activity: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showStopConfirmation() async {
    // Haptic feedback for important dialog
    await HapticFeedback.mediumImpact();

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Stop Activity?')),
              ],
            ),
            content: const Text(
              'Are you sure you want to stop and save this activity? Your progress will be saved.',
              style: TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await HapticService.fitnessHaptic('light');
                  Navigator.of(context).pop(false);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  await HapticService.fitnessHaptic('light');
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.stop, size: 18),
                label: const Text(
                  'Stop & Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 180),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
