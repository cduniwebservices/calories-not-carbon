import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// Core theme and models
import 'theme/global_theme.dart';
import 'models/fitness_models.dart';
import 'services/local_storage_service.dart';
import 'services/sync_service.dart';

// Core screens for the single flow
import 'features/welcome/welcome_screen.dart';
import 'features/goals/goals_screen.dart';
import 'features/fitness/screens/enhanced_run_screen.dart';
import 'features/fitness/screens/session_summary_screen.dart';
import 'features/fitness/screens/history_screen.dart';
import 'features/fitness/screens/activity_detail_screen.dart';
import 'features/fitness/screens/permission_denied_screen.dart';
import 'features/onboarding/permission_onboarding.dart';
import 'features/debug/debug_screen.dart';

// Essential services
import 'services/enterprise_logger.dart';
import 'services/performance_service.dart';
import 'services/cache_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restrict orientation to portrait only
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (_) {}

  // Initialize Sentry with appRunner so Flutter errors are still captured.
  // All other service initializations are inside the appRunner with individual
  // try/catch so that a failure in any one service (e.g. corrupted Hive box,
  // missing Supabase credentials) does not prevent the app from starting.
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.tracesSampleRate = 1.0;
      options.profilesSampleRate = 1.0;
    },
    appRunner: () async {
      await _initializeAppServices();
      runApp(const ProviderScope(child: FitnessApp()));
    },
  );
}

/// Initializes all app services with individual error handling so that
/// a failure in any one service (corrupted Hive, missing Supabase
/// credentials, etc.) does not crash the app on startup.
/// All errors are logged to the debug console so they appear in the
/// app's debug panel.
Future<void> _initializeAppServices() async {
  // 1. Hive local storage (corrupted box is the most common crash-on-reopen)
  try {
    await Hive.initFlutter();
    await LocalStorageService.init();
  } catch (e) {
    debugPrint('⚠️ STARTUP ERROR: Hive init failed: $e');
    _logInitError('Hive init failed', e);
    // LocalStorageService.init() now handles per-box recovery internally
    // with better logging and diagnostics. No need for nuclear deletion here.
    // If init() still fails, it means something fundamental is broken.
    throw e; // Re-throw to trigger Sentry reporting
  }

  // 2. Supabase cloud sync (optional — app works fully offline)
  try {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  } catch (e) {
    debugPrint('⚠️ STARTUP: Supabase unavailable (offline-only mode): $e');
    _logInitWarning('Supabase unavailable', e);
  }

  // 3. Connectivity-based auto-sync (best-effort)
  try {
    SyncService().startListening();
  } catch (e) {
    debugPrint('⚠️ STARTUP: Sync service failed to start: $e');
    _logInitError('Sync service start failed', e);
  }

  // 4. Logger
  try {
    final logger = EnterpriseLogger();
    logger.initialize();
  } catch (e) {
    debugPrint('⚠️ STARTUP: Logger init failed: $e');
  }

  // 5. Performance monitoring
  try {
    final performanceService = PerformanceService();
    performanceService.init();
  } catch (e) {
    debugPrint('⚠️ STARTUP: Performance service init failed: $e');
  }

  // 6. Preload critical data
  try {
    final cacheManager = CacheManager();
    await cacheManager.preloadCriticalData();
  } catch (e) {
    debugPrint('⚠️ STARTUP: Cache preload failed: $e');
    _logInitError('Cache preload failed', e);
  }
}

/// Logs a startup error to the debug panel via EnterpriseLogger, which
/// is safe to call even during early initialization (no-op if not ready).
void _logInitError(String message, dynamic error) {
  try {
    EnterpriseLogger().logError('Startup', '$message: $error', StackTrace.current);
  } catch (_) {}
}

/// Logs a startup warning to the debug panel.
void _logInitWarning(String message, dynamic warning) {
  try {
    EnterpriseLogger().logWarning('Startup', '$message: $warning');
  } catch (_) {}
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fitness Tracker',
      theme: GlobalTheme.themeData,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// Clean, focused router with single app flow
final GoRouter _router = GoRouter(
  initialLocation: '/',
  observers: [AppNavigatorObserver()],
  errorBuilder: (context, state) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: GlobalTheme.backgroundGradient),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: GlobalTheme.statusError,
            ),
            SizedBox(height: 16),
            Text(
              'Page Not Found',
              style: TextStyle(
                color: GlobalTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  routes: [
    // Main app flow: Welcome → Goals → Run → Summary → History
    GoRoute(
      path: '/',
      name: 'welcome',
      pageBuilder: (context, state) => _buildPageWithTransition(
        key: state.pageKey,
        child: const WelcomeScreen(),
      ),
    ),

    GoRoute(
      path: '/goals',
      name: 'goals',
      pageBuilder: (context, state) => _buildPageWithTransition(
        key: state.pageKey,
        child: const GoalsScreen(),
      ),
    ),

    GoRoute(
      path: '/run',
      name: 'run',
      pageBuilder: (context, state) => _buildPageWithTransition(
        key: state.pageKey,
        child: const EnhancedRunScreen(),
      ),
    ),

    GoRoute(
      path: '/session-summary',
      name: 'session-summary',
      pageBuilder: (context, state) {
        final session = state.extra as ActivitySession?;
        if (session == null) {
          // Redirect to history if no session provided
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/history');
          });
          return _buildPageWithTransition(
            key: state.pageKey,
            child: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return _buildPageWithTransition(
          key: state.pageKey,
          child: SessionSummaryScreen(session: session),
        );
      },
    ),

    GoRoute(
      path: '/history',
      name: 'history',
      pageBuilder: (context, state) => _buildPageWithTransition(
        key: state.pageKey,
        child: const HistoryScreen(),
      ),
    ),

    GoRoute(
      path: '/activity-detail',
      name: 'activity-detail',
      pageBuilder: (context, state) {
        final session = state.extra as ActivitySession?;
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/history');
          });
          return _buildPageWithTransition(
            key: state.pageKey,
            child: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return _buildPageWithTransition(
          key: state.pageKey,
          child: ActivityDetailScreen(session: session),
        );
      },
    ),

    // Permission flow
    GoRoute(
      path: '/permission-onboarding',
      name: 'permission-onboarding',
      pageBuilder: (context, state) {
        final isDebug = state.uri.queryParameters['debug'] == 'true';
        return _buildPageWithTransition(
          key: state.pageKey,
          child: PermissionOnboardingFlow(
            debugMode: isDebug,
            onComplete: () => context.go('/goals'),
          ),
        );
      },
    ),

    GoRoute(
      path: '/permission-denied',
      name: 'permission-denied',
      pageBuilder: (context, state) => _buildPageWithTransition(
        key: state.pageKey,
        child: const PermissionDeniedScreen(),
      ),
    ),

    // Secret debug screen - uses overlay modal
    GoRoute(
      path: '/debug',
      name: 'debug',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const DebugScreen(),
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.3),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
  ],
);

// Unified page transition for consistent UX
CustomTransitionPage _buildPageWithTransition({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      final tween = Tween(begin: begin, end: end);
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      );

      return SlideTransition(
        position: tween.animate(curvedAnimation),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
  );
}

/// Navigation observer for enterprise logging
class AppNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logNavigation(route, 'PUSH');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logNavigation(route, 'POP');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logNavigation(newRoute, 'REPLACE');
    }
  }

  void _logNavigation(Route<dynamic> route, String type) {
    // Get GoRouter context from the navigator to extract the current route
    final ctx = navigator?.context;
    if (ctx == null) return;

    final goRouter = GoRouter.of(ctx);
    final uri = goRouter.routerDelegate.currentConfiguration.uri.toString();
    final name = route.settings.name ?? uri;

    EnterpriseLogger().logNavigation(
      'Navigator',
      '[$type] Route: $name',
    );
  }
}
