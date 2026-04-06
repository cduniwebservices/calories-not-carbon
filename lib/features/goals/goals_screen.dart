import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/app_button.dart';
import '../../components/goal_swiper.dart';
import '../../components/profile_header.dart';
import '../../theme/global_theme.dart';
import '../../providers/goal_provider.dart';
import '../debug/debug_screen.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  bool _showPanel = false;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showDescriptionPanel() {
    setState(() {
      _showPanel = true;
      _isDescriptionExpanded = false;
    });
  }

  void _toggleDescription() {
    setState(() {
      _isDescriptionExpanded = !_isDescriptionExpanded;
    });
  }

  void _openDebugScreen() {
    DebugScreenOverlay.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final goalState = ref.watch(goalProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: GlobalTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Profile header with debug access
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 500),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Expanded(child: ProfileHeader()),
                      // Debug button - positioned to the right of profile header
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openDebugScreen,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: GlobalTheme.surfaceCard.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: GlobalTheme.primaryNeon.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.bug_report,
                              color: GlobalTheme.primaryNeon.withOpacity(0.7),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Title section
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose your regular',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: GlobalTheme.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        'TRAVEL MODE',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: GlobalTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Goals swiper
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 700),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 40 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: GoalSwiper(
                      onGoalSelected: _showDescriptionPanel,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Description (hidden until card is tapped)
                if (_showPanel)
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: GlobalTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: GlobalTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  goalState.goals[goalState.currentIndex].title,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: GlobalTheme.primaryNeon,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _toggleDescription,
                                child: Icon(
                                  _isDescriptionExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: GlobalTheme.primaryNeon,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_isDescriptionExpanded)
                            Text(
                              goalState.goals[goalState.currentIndex].description,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: GlobalTheme.textSecondary,
                                height: 1.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Continue button
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 700),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: AppButton.primary(
                    text: 'COMMENCE JOURNEY',
                    width: double.infinity,
                    onPressed: () => context.go('/run'),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
