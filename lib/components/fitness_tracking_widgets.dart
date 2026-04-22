import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/fitness_models.dart';
import '../services/haptic_service.dart';
import '../theme/global_theme.dart';
import 'app_button.dart';

/// Real-time fitness stats display widget
class FitnessStatsWidget extends StatelessWidget {
  final FitnessStats stats;
  final ActivityState state;
  final Color? accentColor;
  final bool showDetailedStats;

  const FitnessStatsWidget({
    super.key,
    required this.stats,
    required this.state,
    this.accentColor,
    this.showDetailedStats = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State indicator with enhanced animations
          Row(
            children: [
              _buildStateIndicator(state, accent),
              const SizedBox(width: 12),
              Text(
                state.displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
              const Spacer(),
              if (state == ActivityState.running)
                _buildPulsingDot(
                  accent,
                ).animate().scale(duration: 300.ms, curve: Curves.elasticOut),
            ],
          ),

          const SizedBox(height: 28),

          // Primary stats grid with staggered animations
          _buildStatsGrid(theme, accent),

          if (showDetailedStats) ...[
            const SizedBox(height: 24),
            _buildDetailedStats(
              theme,
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildStateIndicator(ActivityState state, Color accent) {
    IconData icon;
    Color color;

    switch (state) {
      case ActivityState.idle:
        icon = Icons.play_circle_outline;
        color = Colors.grey;
        break;
      case ActivityState.running:
        icon = Icons.play_circle_filled;
        color = accent;
        break;
      case ActivityState.paused:
        icon = Icons.pause_circle_filled;
        color = GlobalTheme.statusSuccess;
        break;
      case ActivityState.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildPulsingDot(Color accent) {
    return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .fadeIn(duration: 1.seconds)
        .fadeOut(duration: 1.seconds);
  }

  Widget _buildStatsGrid(ThemeData theme, Color accent) {
    final stats = [
      {
        'label': 'Distance',
        'value': this.stats.formattedDistance,
        'icon': Icons.straighten,
        'delay': 200,
      },
      {
        'label': 'Duration',
        'value': this.stats.formattedActiveDuration,
        'icon': Icons.timer,
        'delay': 300,
      },
      {
        'label': 'Pace',
        'value': this.stats.formattedCurrentPace,
        'icon': Icons.speed,
        'delay': 400,
      },
      {
        'label': 'Calories',
        'value': this.stats.formattedCalories,
        'icon': Icons.local_fire_department,
        'delay': 500,
      },
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: stats.map((stat) {
        return _buildStatCard(
              stat['label'] as String,
              stat['value'] as String,
              stat['icon'] as IconData,
              accent,
              theme,
            )
            .animate(delay: Duration(milliseconds: stat['delay'] as int))
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic)
            .then()
            .shimmer(duration: 2000.ms, color: accent.withOpacity(0.1));
      }).toList(),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color accent,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Stats',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDetailedStatItem(
                'Max Speed',
                stats.formattedCurrentSpeed,
                theme,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDetailedStatItem(
                'Steps',
                stats.formattedSteps,
                theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDetailedStatItem(
                'Elevation',
                stats.formattedElevation,
                theme,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDetailedStatItem(
                'Avg Pace',
                stats.formattedAveragePace,
                theme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailedStatItem(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class ActivityControlsWidget extends StatefulWidget {
  final ActivityState state;
  final ActivityType activityType;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;
  final ValueChanged<ActivityType>? onActivityTypeChanged;
  final Color? accentColor;
  final bool isLoading;

  const ActivityControlsWidget({
    super.key,
    required this.state,
    required this.activityType,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onStop,
    this.onActivityTypeChanged,
    this.accentColor,
    this.isLoading = false,
  });

  @override
  State<ActivityControlsWidget> createState() => _ActivityControlsWidgetState();
}

class _ActivityControlsWidgetState extends State<ActivityControlsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _stopLongPressController;
  bool _isLongPressing = false;

  @override
  void initState() {
    super.initState();
    _stopLongPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Sped up from 2s
    );
    _stopLongPressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onStop?.call();
        _stopLongPressController.reset();
        setState(() => _isLongPressing = false);
      }
    });
  }

  @override
  void dispose() {
    _stopLongPressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accentColor ?? theme.primaryColor;

    if (widget.state == ActivityState.idle) {
      return _buildIdleControls(theme, accent);
    }

    return _buildActiveControls(theme, accent);
  }

  Widget _buildIdleControls(ThemeData theme, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActivityTypeSelector(theme, accent),
          const SizedBox(height: 20),
          AppButton.primary(
            text: 'COMMENCE ACTIVITY',
            onPressed: widget.onStart,
            isLoading: widget.isLoading,
            width: double.infinity,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildActiveControls(ThemeData theme, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Hold to Stop Button - flex reduced to give space
          Expanded(
            flex: 2, 
            child: GestureDetector(
              onLongPressStart: (_) {
                setState(() => _isLongPressing = true);
                _stopLongPressController.forward();
                HapticFeedback.mediumImpact();
              },
              onLongPressEnd: (_) {
                setState(() => _isLongPressing = false);
                if (_stopLongPressController.status != AnimationStatus.completed) {
                  _stopLongPressController.reverse();
                }
              },
              child: Stack(
                children: [
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: GlobalTheme.primaryNeon,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stop_rounded, color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'HOLD TO STOP',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 14, // Slightly smaller to fit narrower button
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Progress Overlay
                  AnimatedBuilder(
                    animation: _stopLongPressController,
                    builder: (context, child) {
                      return FractionallySizedBox(
                        widthFactor: _stopLongPressController.value,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Pause/Resume Button - flex increased for breathing space
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (widget.state == ActivityState.running) {
                  widget.onPause?.call();
                } else {
                  widget.onResume?.call();
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.state == ActivityState.running 
                            ? Icons.pause_rounded 
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.state == ActivityState.running ? 'PAUSE' : 'RESUME',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTypeSelector(ThemeData theme, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity Type',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ActivityType.values.map((type) {
              final isSelected = type == widget.activityType;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: widget.onActivityTypeChanged != null
                      ? () => widget.onActivityTypeChanged!(type)
                      : null,
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? accent : theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected ? accent : theme.dividerColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getActivityIcon(type),
                          size: 16,
                          color: isSelected ? Colors.black : accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          type.displayName,
                          style: TextStyle(
                            color: isSelected ? Colors.black : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(ThemeData theme, Color accent) {
    return InkWell(
      onTap: widget.isLoading ? null : widget.onStart,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(
                  'Start ${widget.activityType.displayName}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.running: return Icons.directions_run;
      case ActivityType.walking: return Icons.directions_walk;
      case ActivityType.cycling: return Icons.directions_bike;
      case ActivityType.hiking: return Icons.terrain;
    }
  }
}

/// Large timer display widget
class FitnessTimerWidget extends StatelessWidget {
  final Duration duration;
  final ActivityState state;
  final Color? accentColor;

  const FitnessTimerWidget({
    super.key,
    required this.duration,
    required this.state,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.primaryColor;

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    final timeText = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withOpacity(0.12), accent.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Duration',
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2, end: 0),

          const SizedBox(height: 12),

          Text(
                timeText,
                style: theme.textTheme.displayLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 52,
                  letterSpacing: -2,
                  height: 1.0,
                ),
              )
              .animate()
              .fadeIn(delay: 400.ms)
              .scale(duration: 600.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(duration: 3000.ms, color: accent.withOpacity(0.3)),

          const SizedBox(height: 16),

          if (state == ActivityState.running)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...List.generate(3, (index) {
                  return Container(
                        margin: EdgeInsets.symmetric(horizontal: 3),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      )
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                      )
                      .scale(
                        duration: Duration(milliseconds: 800 + (index * 200)),
                      );
                }),
              ],
            ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
  }
}
