import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fitness_models.dart';
import '../providers/goal_provider.dart';
import '../theme/global_theme.dart';
import '../utils/responsive_design.dart';
import 'neon_card.dart';

class GoalSwiper extends ConsumerStatefulWidget {
  final Function(int index)? onGoalSelected;
  final VoidCallback? onSwipe;

  const GoalSwiper({super.key, this.onGoalSelected, this.onSwipe});

  @override
  ConsumerState<GoalSwiper> createState() => _GoalSwiperState();
}

class _GoalSwiperState extends ConsumerState<GoalSwiper>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.8, // Better spacing
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350), // Faster animation
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goalState = ref.watch(goalProvider);
    final screenSize = ResponsiveDesign.getScreenSize(context);
    
    // Adjust height based on screen size
    final double swiperHeight = screenSize == ScreenSizeCategory.compact ? 280 : 320;

    return SizedBox(
      height: swiperHeight,
      child: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          ref.read(goalProvider.notifier).setCurrentIndex(index);
          widget.onSwipe?.call();
        },
        itemCount: goalState.goals.length,
        itemBuilder: (context, index) {
          final goal = goalState.goals[index];
          final isActive = index == goalState.currentIndex;

          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..scale(isActive ? 1.0 : 0.85),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: GoalCard(
                    goal: goal,
                    index: index,
                    isActive: isActive,
                    onTap: () {
                      ref.read(goalProvider.notifier).selectGoal(goal);
                      widget.onGoalSelected?.call(index);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GoalCard extends StatefulWidget {
  final Goal goal;
  final int index;
  final bool isActive;
  final VoidCallback? onTap;

  const GoalCard({
    super.key,
    required this.goal,
    required this.index,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(GoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNeonCard = widget.isActive;
    final screenSize = ResponsiveDesign.getScreenSize(context);
    final isCompact = screenSize == ScreenSizeCategory.compact;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return NeonCard(
          onTap: widget.onTap,
          isGlowing: isNeonCard,
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          gradient: isNeonCard ? GlobalTheme.primaryGradient : null,
          backgroundColor: isNeonCard ? null : GlobalTheme.surfaceCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Goal type indicator
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 12,
                  vertical: isCompact ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: isNeonCard
                      ? Colors.black.withOpacity(0.2)
                      : GlobalTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.index + 1}/5',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isNeonCard
                        ? Colors.black
                        : GlobalTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: isCompact ? 10 : 12,
                  ),
                ),
              ),

              const Spacer(),

              // Transport icon - Centered correctly using Stack and Align
              Expanded(
                flex: 3,
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxHeight * 0.8;
                      final iconSize = size * 0.6;
                      
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: isNeonCard
                                  ? Colors.black.withOpacity(0.15)
                                  : GlobalTheme.primaryNeon.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Icon(
                            widget.goal.icon,
                            size: iconSize,
                            color: isNeonCard ? Colors.black : GlobalTheme.primaryNeon,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Goal title
              Flexible(
                child: Text(
                  widget.goal.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: isNeonCard ? Colors.black : GlobalTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: isCompact ? 18 : 22,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 12),

              // Goal details
              Row(
                children: [
                  Expanded(
                    child: _buildDetailChip(
                      'Carbon Potential',
                      widget.goal.carbonOffsetPotential,
                      isNeonCard,
                      isCompact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailChip(
                      'CO₂/km',
                      '${(widget.goal.co2PerKm * 1000).toInt()}g',
                      isNeonCard,
                      isCompact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailChip(String label, String value, bool isNeonCard, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12, 
        vertical: isCompact ? 6 : 8
      ),
      decoration: BoxDecoration(
        color: isNeonCard
            ? Colors.black.withOpacity(0.2)
            : GlobalTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isNeonCard
                  ? Colors.black.withOpacity(0.6)
                  : GlobalTheme.textTertiary,
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? 8 : 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: isNeonCard ? Colors.black : GlobalTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: isCompact ? 11 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
