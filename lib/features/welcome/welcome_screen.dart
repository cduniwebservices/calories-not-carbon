import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../components/app_button.dart';
import '../../theme/global_theme.dart';
import '../../services/version_service.dart';
import '../../services/sync_service.dart';
import '../../services/permission_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {

  @override
  void initState() {
    super.initState();
    // Attempt to sync any pending activities when app starts
    SyncService().syncPendingActivities();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: GlobalTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Header badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Text(
                          'HEALTHY HUMANS, HEALTHY PLANET',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: GlobalTheme.textSecondary,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),

                    const Spacer(flex: 2),

                    // Main Illustration
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        height: 380,
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1A331A), Color(0xFF0F1A0F)],
                          ),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF42FF9E).withOpacity(0.1),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          'assets/icons/icon-logo-4-color.svg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),

                    const Spacer(flex: 3),

                    // App Title
                    Text(
                      'CALORIES',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        color: GlobalTheme.textPrimary,
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2, end: 0),
                    Text(
                      'NOT',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        color: GlobalTheme.textPrimary,
                      ),
                    ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2, end: 0),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            'CARBON',
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              color: GlobalTheme.primaryNeon,
                            ),
                          ).animate().fadeIn(delay: 800.ms).slideX(begin: -0.2, end: 0),
                        ),
                        
                        // Version number - repositioned to right side above button area
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Opacity(
                            opacity: 0.4,
                            child: Text(
                              VersionService.displayVersion,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: GlobalTheme.textTertiary,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 1000.ms),
                      ],
                    ),

                    const SizedBox(height: 120), // Padding for the fixed button
                  ],
                ),
              ),

              // Fixed Bottom Button - matching tracking screen position
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 900),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: AppButton.primary(
                    text: 'GET STARTED',
                    width: double.infinity,
                    icon: Icons.rocket_launch_rounded,
                    onPressed: () async {
                      await HapticFeedback.mediumImpact();
                      
                      // Check permissions first
                      final permissionService = PermissionService();
                      await permissionService.initialize();
                      final state = permissionService.currentState;
                      
                      if (mounted) {
                        if (state == PermissionState.allGranted) {
                          context.go('/goals');
                        } else {
                          context.go('/permission-onboarding');
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
