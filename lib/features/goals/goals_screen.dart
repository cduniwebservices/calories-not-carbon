import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/app_button.dart';
import '../../components/goal_swiper.dart';
import '../../components/profile_header.dart';
import '../../theme/global_theme.dart';
import '../../providers/goal_provider.dart';
import '../../utils/responsive_design.dart';
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

  void _showDescriptionPanel(int index) {
    setState(() {
      _showPanel = true;
      _isDescriptionExpanded = false;
    });
  }

  void _hidePanel() {
    if (_showPanel) {
      setState(() {
        _showPanel = false;
        _isDescriptionExpanded = false;
      });
    }
  }

  void _toggleDescription() {
    setState(() {
      _isDescriptionExpanded = !_isDescriptionExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final goalState = ref.watch(goalProvider);
    final screenSize = ResponsiveDesign.getScreenSize(context);
    final isCompact = screenSize == ScreenSizeCategory.compact;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: GlobalTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 16 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: isCompact ? 16 : 24),

                  // Profile header
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
                    child: ProfileHeader(
                      onUserNameTap: () => DebugScreenOverlay.show(context),
                    ),
                  ),

                  SizedBox(height: isCompact ? 24 : 32),

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
                            fontSize: isCompact ? 22 : 28,
                          ),
                        ),
                        Text(
                          'TRAVEL MODE',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: GlobalTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            fontSize: isCompact ? 28 : 32,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isCompact ? 24 : 40),

                  // Goals swiper
                  TweenAnimationBuilder<double>(
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
                      onSwipe: _hidePanel,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Description
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        goalState.goals[goalState.currentIndex].title,
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: GlobalTheme.primaryNeon,
                                          fontWeight: FontWeight.bold,
                                          fontSize: isCompact ? 18 : 22,
                                        ),
                                      ),
                                      Text(
                                        goalState.goals[goalState.currentIndex].tagline,
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: GlobalTheme.textSecondary,
                                          fontStyle: FontStyle.italic,
                                          fontSize: isCompact ? 12 : 14,
                                        ),
                                      ),
                                    ],
                                  ),                                ),
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
                            if (_isDescriptionExpanded) ...[
                              const SizedBox(height: 8),
                              Text(
                                goalState.goals[goalState.currentIndex].description,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: GlobalTheme.textSecondary,
                                  height: 1.5,
                                  fontSize: isCompact ? 13 : 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  SizedBox(height: isCompact ? 16 : 24),

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
                      text: 'COMMENCE ACTIVITY',
                      width: double.infinity,
                      onPressed: () => context.go('/run'),
                    ),
                  ),

                  SizedBox(height: isCompact ? 16 : 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
