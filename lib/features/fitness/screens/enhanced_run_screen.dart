import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/fitness_models.dart';
import '../../../providers/activity_providers.dart';
import '../../../providers/goal_provider.dart';
import '../../../components/interactive_map_widget.dart';
import '../../../components/fitness_tracking_widgets.dart';
import '../../../services/navigation_service.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/global_theme.dart';
import '../../../utils/responsive_design.dart';
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
  final ActivityType _selectedActivityType = ActivityType.running;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isStopDialogShowing = false;

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
    // Auto-start GPS warm-up immediately when screen loads
    // User must still press START button once GPS stabilizes
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      final actions = ref.read(activityActionsProvider);
      await _handleStartActivity(actions);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Reset the map reveal flag so animation plays again when returning to run screen
    InteractiveMapWidget.resetRevealFlag();
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
    final gpsStabilization = ref.watch(gpsStabilizingProvider);
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
                Text(
                  'Initialising GPS...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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

                // Tab bar for Map/Stats view (only when actually running, not warming up)
                if (activityState == ActivityState.running || activityState == ActivityState.paused)
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
                    child: _buildContentView(
                      activityState,
                      gpsStabilization,
                      theme,
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

  Widget _buildContentView(
    ActivityState activityState,
    GpsStabilizationState gpsStabilization,
    ThemeData theme,
    FitnessStats stats,
    List<LatLng> routePoints,
    ActivityActions actions,
  ) {
    switch (activityState) {
      case ActivityState.idle:
        return _buildLoadingView(theme);
      case ActivityState.warmingUp:
        return _buildWarmingUpView(theme, gpsStabilization, actions);
      case ActivityState.running:
      case ActivityState.paused:
        return _buildActiveTrackingView(
          theme,
          activityState,
          stats,
          routePoints,
          actions,
        );
      case ActivityState.completed:
        return _buildLoadingView(theme);
    }
  }

  Widget _buildAppBar(
    ThemeData theme,
    ActivityState state,
    FitnessStats stats,
    ActivityActions actions,
  ) {
    final statusText = _isStopDialogShowing ? 'Confirm activity stop' : _getStatusText(state);
    final statusColor = _isStopDialogShowing ? GlobalTheme.statusError : _getStatusColor(state, theme);
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
              ),
              child: Text(
                _isStopDialogShowing ? 'STOPPED' : state.displayName.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ).animate().fadeIn(delay: 600.ms).scale(curve: Curves.elasticOut),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      color: theme.cardColor,
      child: TabBar(
        controller: _tabController,
        indicatorColor: GlobalTheme.primaryNeon,
        indicatorWeight: 3,
        labelColor: GlobalTheme.primaryNeon,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
        tabs: const [
          Tab(icon: Icon(Icons.map_outlined, size: 24), text: 'Map'),
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

  Widget _buildWarmingUpView(
    ThemeData theme,
    GpsStabilizationState stabilizationState,
    ActivityActions actions,
  ) {
    final progress = stabilizationState.progress.clamp(0.0, 1.0);
    final isStable = stabilizationState.isStable;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // GPS Icon with pulse animation
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isStable
                    ? GlobalTheme.primaryNeon.withOpacity(0.2)
                    : Colors.amber.withOpacity(0.2),
              ),
              child: Icon(
                isStable ? Icons.gps_fixed : Icons.gps_not_fixed,
                size: 56,
                color: isStable ? GlobalTheme.primaryNeon : Colors.amber,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(duration: 1500.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.05, 1.05)),

            const SizedBox(height: 32),

            // Status text
            Text(
              isStable ? 'Signal Stable!' : 'Calibrating...',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(),

            const SizedBox(height: 12),

            // Stability message
            Text(
              stabilizationState.stabilityMessage ?? 'Waiting for accurate readings...',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GlobalTheme.textSecondary,
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 32),

            // Progress indicator
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: isStable ? GlobalTheme.primaryNeon : Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ).animate().slideX(begin: -1, end: 0, duration: 500.ms),

            const SizedBox(height: 16),

            // Reading count
            Text(
              '${stabilizationState.stableReadingsCount}/${stabilizationState.requiredStableReadings} stable readings',
              style: theme.textTheme.bodySmall?.copyWith(
                color: GlobalTheme.textTertiary,
              ),
            ),

            const SizedBox(height: 32),

            // Current metrics display
            if (stabilizationState.currentAltitude != null) ...[
              _buildMetricRow(
                'Altitude',
                '${stabilizationState.currentAltitude!.toStringAsFixed(1)} m',
                Icons.terrain_outlined,
                stabilizationState.altitudeVariance != null
                    ? '±${stabilizationState.altitudeVariance!.toStringAsFixed(1)}m variance'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildMetricRow(
                'Speed',
                '${((stabilizationState.currentSpeed ?? 0) * 3.6).toStringAsFixed(1)} km/h',
                Icons.speed_outlined,
                stabilizationState.speedVariance != null
                    ? '±${(stabilizationState.speedVariance! * 3.6).toStringAsFixed(1)} km/h variance'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildMetricRow(
                'Accuracy',
                '${stabilizationState.gpsAccuracy.toStringAsFixed(1)} m',
                Icons.gps_fixed_outlined,
                stabilizationState.gpsAccuracy <= 10
                    ? 'Excellent'
                    : stabilizationState.gpsAccuracy <= 20
                        ? 'Good'
                        : 'Poor',
              ),
            ],

            const Spacer(),

            // Manual start button (shown when stable)
            if (isStable)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: GlobalTheme.primaryNeon,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: GlobalTheme.primaryNeon.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    actions.beginTracking();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'START ACTIVITY',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1))
                  .then()
                  .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon, String? subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GlobalTheme.primaryNeon.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: GlobalTheme.primaryNeon, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: GlobalTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: GlobalTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
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
              activityType: actions.activityType,
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

  // Helper methods
  String _getStatusText(ActivityState state) {
    switch (state) {
      case ActivityState.idle:
        return 'HEALTHY HUMANS, HEALTHY PLANET';
      case ActivityState.warmingUp:
        return 'Please wait';
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
      case ActivityState.warmingUp:
        return Colors.amber;
      case ActivityState.running:
        return GlobalTheme.primaryAccent; // Green
      case ActivityState.paused:
        return GlobalTheme.statusWarning; // Orange/Amber
      case ActivityState.completed:
        return Colors.green;
    }
  }

  IconData _getActivityIconFromSpeed(double speedKmh) {
    if (speedKmh < 6.0) {
      return Icons.directions_walk;
    } else if (speedKmh < 18.0) {
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

      final goalState = ref.read(goalProvider);
      final selectedGoal = goalState.selectedGoal;
      final activityReplaced = selectedGoal?.id;

      final success = await actions.startActivity(
        _selectedActivityType,
        activityReplaced: activityReplaced,
      );
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
    final distance = ref.read(fitnessStatsProvider).totalDistanceMeters;

    setState(() {
      _isStopDialogShowing = true;
    });

    try {
      // Check for minimum distance requirement (1km)
      if (distance < 1000) {
        final shouldDiscard = await _showInsufficientDistanceDialog();
        if (shouldDiscard == true) {
          actions.resetActivity();
          if (mounted) {
            context.go('/goals');
          }
          return;
        }
        
        if (mounted) {
          setState(() {
            _isStopDialogShowing = false;
          });
        }
        return;
      }

      final shouldStop = await _showStopConfirmation();
      if (!shouldStop) {
        if (mounted) {
          setState(() {
            _isStopDialogShowing = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

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
          _isStopDialogShowing = false;
        });
      }
    }
  }

  Future<bool> _showInsufficientDistanceDialog() async {
    await HapticFeedback.heavyImpact();

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            title: const Text(
              'INSUFFICIENT DISTANCE RECORDED',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 18,
              ),
            ),
            content: const Text(
              'Your activity does not meet the minimum distance requirement of 1km. This session will not be saved to your device.',
              style: TextStyle(color: GlobalTheme.textSecondary, height: 1.5),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('CONTINUE ACTIVITY', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlobalTheme.statusError,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'DISCARD',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showStopConfirmation() async {
    // Haptic feedback for important dialog
    await HapticFeedback.mediumImpact();

    final screenSize = ResponsiveDesign.getScreenSize(context);
    final isCompact = screenSize == ScreenSizeCategory.compact;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            title: Text(
              'STOP ACTIVITY?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: isCompact ? 20 : 24,
                  ),
            ),
            content: Text(
              'Are you sure you want to stop and save this activity? Your progress will be saved.',
              style: TextStyle(
                color: GlobalTheme.textSecondary, 
                height: 1.5,
                fontSize: isCompact ? 14 : 16,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              if (isCompact)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await HapticService.fitnessHaptic('light');
                          Navigator.of(context).pop(true);
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('STOP & SAVE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalTheme.primaryNeon,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await HapticService.fitnessHaptic('light');
                          Navigator.of(context).pop(false);
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('CANCEL'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GlobalTheme.primaryNeon,
                          side: const BorderSide(color: GlobalTheme.primaryNeon, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await HapticService.fitnessHaptic('light');
                          Navigator.of(context).pop(false);
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('CANCEL'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GlobalTheme.primaryNeon,
                          side: const BorderSide(color: GlobalTheme.primaryNeon, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await HapticService.fitnessHaptic('light');
                          Navigator.of(context).pop(true);
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('STOP & SAVE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalTheme.primaryNeon,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ],
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

/// Specialized widget for the high-end stats display
class StatsDisplay extends ConsumerWidget {
  final FitnessStats stats;
  final ActivityState state;
  final ActivityType activityType;
  final Color accentColor;
  final ActivitySession? session;

  const StatsDisplay({
    super.key,
    required this.stats,
    required this.state,
    required this.activityType,
    required this.accentColor,
    this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goalState = ref.watch(goalProvider);
    final currentSession = ref.watch(currentActivitySessionProvider);
    final displaySession = session ?? currentSession;
    
    // Provide a fallback goal if none is selected
    final selectedGoal = goalState.selectedGoal ?? (goalState.goals.isNotEmpty ? goalState.goals.first : const Goal(
      id: 'default',
      type: GoalType.petrolDieselCar,
      title: 'Default',
      tagline: 'Track your activity',
      description: 'Default goal',
      level: GoalLevel.easy,
      duration: Duration(minutes: 30),
      carbonOffsetPotential: 'Medium',
      co2PerKm: 0.171,
      icon: Icons.directions_car,
    ));
    
    // Calculation logic
    final distanceKm = stats.totalDistanceMeters / 1000.0;

    // 1. CO2 if they had used the replaced transport
    final co2EmittedByTransport = distanceKm * selectedGoal.co2PerKm;

    // 2. CO2 generated by the actual activity
    // Based on activity type and speed — accounts for food production calories burned
    // Sources: walking ~0.027 kg CO2/km, running ~0.033 kg CO2/km, cycling ~0.022 kg CO2/km
    double activityFootprintPerKm;

    switch (activityType) {
      case ActivityType.walking:
        activityFootprintPerKm = 0.027;
        break;
      case ActivityType.running:
        // Running burns more calories → higher food-related CO2
        activityFootprintPerKm = 0.033;
        break;
      case ActivityType.cycling:
        // Cycling is more efficient → lower food-related CO2 per km
        activityFootprintPerKm = 0.022;
        break;
      case ActivityType.hiking:
        activityFootprintPerKm = 0.030;
        break;
    }

    final co2GeneratedByActivity = distanceKm * activityFootprintPerKm;

    // 3. Final Saved
    final co2SavedKg = co2EmittedByTransport - co2GeneratedByActivity;
    
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

        // 2. Enhanced CO2 Saved Section
        _buildCO2Panel(
          theme, 
          co2SavedKg, 
          selectedGoal, 
          activityType, 
          co2EmittedByTransport, 
          co2GeneratedByActivity,
        ),

        const SizedBox(height: 32),

        // 3. Stats Grid (4 items)
        _buildStatsGrid(theme),

        const SizedBox(height: 40),

        // 4. Secondary Stats (Two Column)
        _buildFixedTwoColumnGrid(context, [
          _buildHalfWidthStat(theme, 'MAX SPEED (km/h)', (stats.maxSpeedMps * 3.6).toStringAsFixed(1), Icons.speed),
          _buildHalfWidthStat(theme, 'ELEVATION (m)', stats.elevationGain.toStringAsFixed(0), Icons.terrain_outlined),
          _buildHalfWidthStat(theme, 'TIME MOVING', _formatDuration(stats.movingDuration), Icons.directions_walk),
          _buildHalfWidthStat(theme, 'TIME STATIONARY', _formatDuration(stats.stationaryDuration), Icons.pause_circle_outline),
        ]),

        const SizedBox(height: 40),

        // 5. Start Times (Two Column)
        _buildFixedTwoColumnGrid(context, [
          _buildTimeItem(theme, 'LOCAL START', _formatTime(stats.startTime), displaySession?.startWeather?.location?.utcOffset ?? 'ACST'),
          _buildTimeItem(theme, 'UTC START', _formatTime(stats.startTime.toUtc()), 'UTC'),
        ]),

        const SizedBox(height: 40),

        // 6. Weather Info (Two Column)
        if (displaySession?.startWeather != null)
          _buildFixedTwoColumnGrid(context, [
            _buildWeatherItem(
              theme, 
              'WEATHER', 
              '${displaySession!.startWeather!.tempC.toStringAsFixed(1)}°C, ${displaySession.startWeather!.conditionText}', 
              Icons.wb_cloudy_outlined,
              networkIcon: displaySession.startWeather!.conditionIcon,
            ),
            _buildWeatherItem(theme, 'HUMIDITY', '${displaySession.startWeather!.humidity}%', Icons.opacity),
          ])
        else
          _buildFixedTwoColumnGrid(context, [
            _buildWeatherItem(theme, 'WEATHER', 'NA', Icons.wb_cloudy_outlined),
            _buildWeatherItem(theme, 'HUMIDITY', 'NA', Icons.opacity),
          ]),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFixedTwoColumnGrid(BuildContext context, List<Widget> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Wrap(
          spacing: 0,
          runSpacing: 32,
          children: items.map((item) => SizedBox(
            width: width / 2,
            child: item,
          )).toList(),
        );
      },
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

  Widget _buildCO2Panel(
    ThemeData theme, 
    double co2Saved, 
    Goal replacedGoal, 
    ActivityType activity,
    double emittedByTransport,
    double generatedByActivity,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A331A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: GlobalTheme.primaryAccent.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Centralized Large Icon and Value
          Icon(Icons.eco_rounded, color: GlobalTheme.primaryAccent, size: 48)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(duration: 2.seconds, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
          
          const SizedBox(height: 12),
          
          Text(
            co2Saved.toStringAsFixed(2),
            style: theme.textTheme.displayMedium?.copyWith(
              color: GlobalTheme.primaryAccent,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          
          Text(
            'TOTAL CO2 SAVED (kg)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF4A664A),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF1A331A), thickness: 1),
          const SizedBox(height: 20),
          
          // Two-Column Comparison
          Row(
            children: [
              // Replaced Transport
              Expanded(
                child: Column(
                  children: [
                    Icon(replacedGoal.icon, color: const Color(0xFF4A664A), size: 20),
                    const SizedBox(height: 8),
                    Text(
                      'REPLACED (kg)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF4A664A),
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      emittedByTransport.toStringAsFixed(3),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Minus Sign
              const Icon(Icons.remove, color: Color(0xFF1A331A), size: 16),
              
              // Actual Activity
              Expanded(
                child: Column(
                  children: [
                    Icon(activity.icon, color: const Color(0xFF4A664A), size: 20),
                    const SizedBox(height: 8),
                    Text(
                      'ACTUAL (kg)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF4A664A),
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      generatedByActivity.toStringAsFixed(3),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
            _buildGridItem(theme, 'DISTANCE (km)', stats.formattedDistance.split(' ')[0], Icons.directions_run),
            _buildGridItem(theme, 'AVG SPEED (km/h)', (stats.averageSpeedMps * 3.6).toStringAsFixed(1), Icons.speed),
            _buildGridItem(theme, 'PACE (/km)', stats.formattedAveragePace, Icons.timer_outlined),
            _buildGridItem(theme, 'CALORIES (kcal)', stats.estimatedCalories.toString(), Icons.local_fire_department_outlined),
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

  Widget _buildWeatherItem(ThemeData theme, String label, String value, IconData icon, {String? networkIcon}) {
    final parts = value.split(',');
    final firstPart = parts[0].trim();
    final description = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
    final isNA = firstPart == 'NA' && description.isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
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
        
        // Temperature and Icon Row
        if (label.contains('WEATHER') && !isNA)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (networkIcon != null && networkIcon.isNotEmpty)
                Image.network(
                  networkIcon.startsWith('http') ? networkIcon : 'https:$networkIcon',
                  width: 28,
                  height: 28,
                  errorBuilder: (_, __, ___) => Icon(icon, color: GlobalTheme.primaryNeon, size: 28),
                )
              else
                Icon(icon, color: GlobalTheme.primaryNeon, size: 28),
              const SizedBox(width: 8),
              Text(
                firstPart,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: GlobalTheme.primaryNeon,
                  fontSize: 24,
                ),
              ),
            ],
          )
        else if (!isNA)
          // For Non-weather stats (like Humidity)
          Column(
            children: [
              Icon(icon, color: GlobalTheme.primaryNeon, size: 28),
              const SizedBox(height: 8),
              Text(
                firstPart,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: GlobalTheme.primaryNeon,
                  fontSize: 24,
                ),
              ),
            ],
          )
        else
          // NA state
          Icon(icon, color: GlobalTheme.primaryNeon, size: 28),

        // Description / Subtitle
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: GlobalTheme.primaryNeon.withOpacity(0.8),
              fontSize: 10,
              letterSpacing: 1.1,
            ),
          ),
        ] else if (isNA) ...[
          const SizedBox(height: 8),
          Text(
            'NA',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: GlobalTheme.primaryNeon,
              fontSize: 24,
            ),
          ),
        ],
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
