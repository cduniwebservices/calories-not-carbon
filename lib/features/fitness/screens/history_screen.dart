import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/global_theme.dart';
import '../../../models/fitness_models.dart';
import '../../../providers/activity_providers.dart';
import '../../../components/modern_ui_components.dart';
import '../../../components/app_button.dart';
import '../../../services/navigation_service.dart';
import '../../../utils/responsive_design.dart';

/// Production-quality history screen for viewing past activities
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'This Week',
    'This Month',
    'This Year',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activityHistory = ref.watch(activityHistoryProvider);
    final screenSize = ResponsiveDesign.getScreenSize(context);
    final isCompact = screenSize == ScreenSizeCategory.compact;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: GlobalTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button and title
              _buildHeader(
                theme,
                isCompact,
              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0),

              // Filter chips
              _buildFilterChips(
                theme,
                isCompact,
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

              // History list or empty state
              Expanded(
                child: activityHistory.when(
                  data: (activities) => activities.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildHistoryList(theme, activities),
                  loading: () => _buildLoadingState(theme),
                  error: (error, stack) =>
                      _buildErrorState(theme, error.toString()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isCompact) {
    return Padding(
      padding: EdgeInsets.all(isCompact ? 12.0 : GlobalTheme.spacing16),
      child: Row(
        children: [
          // Back button
          Container(
            width: isCompact ? 36 : 40,
            height: isCompact ? 36 : 40,
            decoration: BoxDecoration(
              color: theme.surfaceCard,
              borderRadius: BorderRadius.circular(GlobalTheme.radiusMedium),
              boxShadow: GlobalTheme.cardShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(GlobalTheme.radiusMedium),
                onTap: () => context.go('/goals'),
                child: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: GlobalTheme.textPrimary,
                  size: isCompact ? 16 : 20,
                ),
              ),
            ),
          ),

          SizedBox(width: isCompact ? 12 : GlobalTheme.spacing16),

          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity History',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: GlobalTheme.textPrimary,
                    fontSize: isCompact ? 20 : 28,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isCompact ? 'Track your progress' : 'Track your progress over time',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: GlobalTheme.textSecondary,
                    fontSize: isCompact ? 11 : 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Stats summary badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : GlobalTheme.spacing12,
              vertical: isCompact ? 4 : GlobalTheme.spacing8,
            ),
            decoration: BoxDecoration(
              gradient: GlobalTheme.primaryGradient,
              borderRadius: BorderRadius.circular(GlobalTheme.radiusLarge),
              boxShadow: GlobalTheme.neonGlow(
                GlobalTheme.primaryNeon,
                opacity: 0.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: Colors.black,
                  size: isCompact ? 12 : 16,
                ),
                SizedBox(width: isCompact ? 2 : GlobalTheme.spacing4),
                Consumer(
                  builder: (context, ref, child) {
                    final totalActivities = ref.watch(totalActivitiesProvider);
                    return Text(
                      isCompact 
                        ? '$totalActivities activ...'
                        : '$totalActivities ${totalActivities == 1 ? 'activity' : 'activities'}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: isCompact ? 10 : 12,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, bool isCompact) {
    return Container(
      height: isCompact ? 44 : 50,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : GlobalTheme.spacing16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final option = _filterOptions[index];
          final isSelected = _selectedFilter == option;

          return Padding(
            padding: EdgeInsets.only(
              right: index < _filterOptions.length - 1
                  ? GlobalTheme.spacing12
                  : 0,
            ),
            child:
                FilterChip(
                      label: Text(
                        option,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isSelected
                              ? Colors.black
                              : GlobalTheme.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = option;
                        });
                      },
                      backgroundColor: theme.surfaceCard,
                      selectedColor: GlobalTheme.primaryNeon,
                      side: BorderSide(
                        color: isSelected
                            ? GlobalTheme.primaryNeon
                            : GlobalTheme.surfaceBorder,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          GlobalTheme.radiusLarge,
                        ),
                      ),
                      elevation: 0,
                      pressElevation: 0,
                    )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 300 + (index * 100)),
                      duration: 400.ms,
                    )
                    .slideX(begin: 0.3, end: 0),
          );
        },
      ),
    );
  }

  Widget _buildHistoryList(ThemeData theme, List<ActivitySession> activities) {
    final filteredActivities = _filterActivities(activities);

    if (filteredActivities.isEmpty) {
      return _buildEmptyFilterState(theme);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(GlobalTheme.spacing16),
      itemCount: filteredActivities.length,
      itemBuilder: (context, index) {
        final activity = filteredActivities[index];
        return _buildActivityCard(theme, activity, index);
      },
    );
  }

  Widget _buildActivityCard(ThemeData theme, ActivitySession activity, int index) {
    return Container(
          margin: const EdgeInsets.only(bottom: GlobalTheme.spacing16),
          decoration: BoxDecoration(
            gradient: GlobalTheme.cardGradient,
            borderRadius: BorderRadius.circular(GlobalTheme.radiusLarge),
            border: Border.all(color: GlobalTheme.surfaceBorder, width: 1),
            boxShadow: GlobalTheme.cardShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(GlobalTheme.radiusLarge),
              onTap: () => _showActivityDetails(activity),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(GlobalTheme.spacing20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with date and activity type
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(GlobalTheme.spacing8),
                              decoration: BoxDecoration(
                                color: _getActivityColor(
                                  activity,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(
                                  GlobalTheme.radiusSmall,
                                ),
                              ),
                              child: Icon(
                                _getActivityIcon(activity),
                                color: _getActivityColor(activity),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: GlobalTheme.spacing12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getActivityTitle(activity),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: GlobalTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(activity.stats.startTime),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: GlobalTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Duration
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: GlobalTheme.spacing12,
                                vertical: GlobalTheme.spacing6,
                              ),
                              decoration: BoxDecoration(
                                color: GlobalTheme.backgroundTertiary,
                                borderRadius: BorderRadius.circular(
                                  GlobalTheme.radiusLarge,
                                ),
                                border: Border.all(
                                  color: GlobalTheme.surfaceBorder.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                _formatDuration(activity.stats.totalDuration),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: GlobalTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: GlobalTheme.spacing20),

                        // Stats row
                        Row(
                          children: [
                            _buildStatItem(
                              theme,
                              'Distance (km)',
                              (activity.stats.totalDistanceMeters / 1000).toStringAsFixed(2),
                              Icons.route_rounded,
                            ),
                            const SizedBox(width: GlobalTheme.spacing24),
                            _buildStatItem(
                              theme,
                              'Pace (/km)',
                              activity.stats.formattedAveragePace,
                              Icons.speed_rounded,
                            ),
                            const SizedBox(width: GlobalTheme.spacing24),
                            _buildStatItem(
                              theme,
                              'Calories (kcal)',
                              activity.stats.formattedCalories,
                              Icons.local_fire_department_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Sync Indicator in bottom right
                  if (activity.isSynced)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Icon(
                        Icons.cloud_done_rounded,
                        color: GlobalTheme.primaryAccent.withOpacity(0.7),
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 100 + (index * 50)),
          duration: 500.ms,
        )
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildStatItem(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: GlobalTheme.primaryAccent),
              const SizedBox(width: GlobalTheme.spacing4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: GlobalTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: GlobalTheme.spacing4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: GlobalTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GlobalTheme.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: GlobalTheme.surfaceCard,
                borderRadius: BorderRadius.circular(GlobalTheme.radiusXLarge),
                boxShadow: GlobalTheme.cardShadow,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 60,
                color: GlobalTheme.textTertiary,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

            const SizedBox(height: GlobalTheme.spacing24),

            Text(
              'No activities yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: GlobalTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: GlobalTheme.spacing8),

            Text(
              'Start your first activity to see your\nprogress and achievements here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GlobalTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: GlobalTheme.spacing32),

            AppButton.primary(
              onPressed: () {
                NavigationService.goToGoals(context);
              },
              text: 'GET STARTED',
              icon: Icons.rocket_launch_rounded,
            ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GlobalTheme.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off_rounded,
              size: 80,
              color: GlobalTheme.textTertiary,
            ).animate().scale(duration: 600.ms),

            const SizedBox(height: GlobalTheme.spacing24),

            Text(
              'No activities found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: GlobalTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: GlobalTheme.spacing8),

            Text(
              'Try adjusting your filter or\nstart a new activity',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GlobalTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return const Center(
      child: LoadingStateCard(
        message: 'Loading your activity history...',
        accentColor: GlobalTheme.primaryAccent,
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GlobalTheme.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(GlobalTheme.spacing20),
              decoration: BoxDecoration(
                color: GlobalTheme.statusError.withOpacity(0.1),
                borderRadius: BorderRadius.circular(GlobalTheme.radiusLarge),
                border: Border.all(
                  color: GlobalTheme.statusError.withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: GlobalTheme.statusError,
              ),
            ),

            const SizedBox(height: GlobalTheme.spacing20),

            Text(
              'Error loading history',
              style: theme.textTheme.titleLarge?.copyWith(
                color: GlobalTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: GlobalTheme.spacing8),

            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GlobalTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: GlobalTheme.spacing24),

            OutlinedButton.icon(
              onPressed: () {
                // Refresh the data
                final _ = ref.refresh(activityHistoryProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  List<ActivitySession> _filterActivities(List<ActivitySession> activities) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (_selectedFilter) {
      case 'This Week':
        // Get the start of the current week (Monday)
        final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        return activities
            .where((activity) => activity.stats.startTime.isAfter(weekStart) || 
                                activity.stats.startTime.isAtSameMomentAs(weekStart))
            .toList();
      case 'This Month':
        final monthStart = DateTime(now.year, now.month, 1);
        return activities
            .where((activity) => activity.stats.startTime.isAfter(monthStart) || 
                                activity.stats.startTime.isAtSameMomentAs(monthStart))
            .toList();
      case 'This Year':
        final yearStart = DateTime(now.year, 1, 1);
        return activities
            .where((activity) => activity.stats.startTime.isAfter(yearStart) || 
                                activity.stats.startTime.isAtSameMomentAs(yearStart))
            .toList();
      default:
        return activities;
    }
  }

  Color _getActivityColor(ActivitySession activity) {
    final speedKmh = activity.stats.averageSpeedMps * 3.6;
    if (speedKmh < 6.0) return GlobalTheme.statusInfo; // Walk
    if (speedKmh < 20.0) return GlobalTheme.primaryAccent; // Run
    return GlobalTheme.primaryAction; // Ride
  }

  IconData _getActivityIcon(ActivitySession activity) {
    final speedKmh = activity.stats.averageSpeedMps * 3.6;
    if (speedKmh < 6.0) return Icons.directions_walk_rounded;
    if (speedKmh < 20.0) return Icons.directions_run_rounded;
    return Icons.directions_bike_rounded;
  }

  String _getActivityTitle(ActivitySession activity) {
    final stats = activity.stats;
    final speedKmh = stats.averageSpeedMps * 3.6;
    
    // Determine activity word based on speed
    String typeWord;
    if (speedKmh < 6.0) {
      typeWord = 'Walk';
    } else if (speedKmh < 20.0) {
      typeWord = 'Run';
    } else {
      typeWord = 'Ride';
    }

    final date = stats.startTime;
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final dayName = dayNames[date.weekday - 1];
    final monthName = monthNames[date.month - 1];
    final dayNum = date.day;
    
    // Ordinal suffix
    String suffix = 'th';
    if (dayNum % 10 == 1 && dayNum % 100 != 11) suffix = 'st';
    else if (dayNum % 10 == 2 && dayNum % 100 != 12) suffix = 'nd';
    else if (dayNum % 10 == 3 && dayNum % 100 != 13) suffix = 'rd';
    
    final year = date.year;
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    
    return '$dayName $dayNum$suffix $monthName $year - $time $typeWord';
  }

  String _formatActivityType(ActivityType type) {
    // This method is now replaced by _getActivityTitle but kept for internal logic if needed
    return type.displayName;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutesStr:$secondsStr';
    }
    return '$minutesStr:$secondsStr';
  }

  String _formatPace(double pace) {
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }

  void _showActivityDetails(ActivitySession activity) {
    NavigationService.goToActivityDetail(context, activity);
  }
}

// Provider for total activities count
final totalActivitiesProvider = Provider<int>((ref) {
  final history = ref.watch(activityHistoryProvider);
  return history.when(
    data: (activities) => activities.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
