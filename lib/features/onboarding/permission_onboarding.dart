import 'package:calories_not_carbon/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/permission_service.dart';
import '../../services/location_service.dart';
import '../../services/local_storage_service.dart';
import '../../components/modern_ui_components.dart';
import '../../components/app_button.dart';
import '../../theme/global_theme.dart';

/// Enterprise-level permission onboarding flow
class PermissionOnboardingFlow extends StatefulWidget {
  final VoidCallback onComplete;
  final bool debugMode;

  const PermissionOnboardingFlow({
    super.key,
    required this.onComplete,
    this.debugMode = false,
  });

  @override
  State<PermissionOnboardingFlow> createState() =>
      _PermissionOnboardingFlowState();
}

class _PermissionOnboardingFlowState extends State<PermissionOnboardingFlow>
    with TickerProviderStateMixin {
  final PermissionService _permissionService = PermissionService();
  final LocationService _locationService = LocationService();

  late PageController _pageController;
  late AnimationController _progressController;

  int _currentPage = 0;
  bool _isLoading = false;
  PermissionState _permissionState = PermissionState.unknown;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome!',
      subtitle: 'Your climate impact companion',
      description:
          'Record your physical activities and see the carbon emissions you\'ve helped prevent. Every movement counts for the planet.',
      icon: Icons.eco,
      color: GlobalTheme.primaryAccent,
    ),
    OnboardingPage(
      title: 'Location Access',
      subtitle: 'Measure your journeys',
      description:
          'GPS helps calculate the distance you\'ve traveled. On iPhone, please select "Allow While Using App" then "Change to Always Allow" to ensure tracking works when your screen is off.',
      icon: Icons.location_on,
      color: GlobalTheme.primaryAction,
    ),
    OnboardingPage(
      title: 'Activity Detection',
      subtitle: 'Recognize your movement',
      description:
          'Automatically identify different types of activities so your effort is accurately reflected in your climate impact.',
      icon: Icons.directions_run,
      color: GlobalTheme.primaryNeon,
    ),
    OnboardingPage(
      title: 'Background Updates',
      subtitle: 'Keep logging active',
      description:
          'Notifications keep the app running in the background so your activities are captured even when the screen is off.',
      icon: Icons.notifications_active,
      color: GlobalTheme.primaryAction,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _permissionService.initialize();
    await _locationService.initialize();

    // Listen to permission changes
    _permissionService.permissionStream.listen((state) {
      if (mounted) {
        setState(() {
          _permissionState = state;
        });
      }
    });

    // Check if permissions are already granted - skip onboarding if so (unless in debug mode)
    final currentState = _permissionService.currentState;
    if (currentState == PermissionState.allGranted && !widget.debugMode) {
      debugPrint('✅ Permissions already granted, skipping onboarding');
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _requestPermissions();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _permissionService.requestFitnessPermissions();

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      // Mark onboarding as complete since user successfully granted permissions
      await LocalStorageService.markOnboardingComplete();
      debugPrint('✅ PermissionOnboarding: Permissions granted, onboarding marked complete');
      
      // Check if notification permission was specifically denied or not granted
      final notificationStatus = result.permissions[Permission.notification];
      if (notificationStatus != null && !notificationStatus.isGranted) {
        if (mounted) {
          _showNotificationExplanationDialog();
        }
      } else {
        widget.onComplete();
      }
    } else {
      if (mounted) {
        _showPermissionDeniedDialog();
      }
    }
  }

  void _showNotificationExplanationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: GlobalTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.notifications_paused_rounded, color: GlobalTheme.primaryAction, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Notifications Required',
                style: TextStyle(color: GlobalTheme.textPrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Notifications keep the app running while your screen is off, so your activities are fully captured and your carbon impact is accurately calculated.',
          style: TextStyle(color: GlobalTheme.textSecondary, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _retryNotificationPermission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalTheme.primaryAction,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('ENABLE NOTIFICATIONS'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryNotificationPermission() async {
    setState(() {
      _isLoading = true;
    });
    
    final status = await _permissionService.requestNotificationPermission();
    
    setState(() {
      _isLoading = false;
    });
    
    if (status.isGranted) {
      widget.onComplete();
    } else {
      // If still denied, show the explanation dialog again
      if (mounted) {
        _showNotificationExplanationDialog();
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: GlobalTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Permissions Required',
                style: TextStyle(color: GlobalTheme.textPrimary),
              ),
            ),
          ],
        ),
        content: const Text(
          'Location and activity permissions are needed to calculate your carbon impact. Please enable them in your device settings to continue.',
          style: TextStyle(color: GlobalTheme.textSecondary, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _permissionService.openPermissionSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalTheme.primaryNeon,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('OPEN SETTINGS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlobalTheme.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),

            // Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  _progressController.animateTo((index + 1) / _pages.length);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], index);
                },
              ),
            ),

            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              if (_currentPage > 0)
                IconButton(
                  onPressed: _previousPage,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: GlobalTheme.textSecondary,
                  ),
                ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (_currentPage + 1) / _pages.length,
            backgroundColor: GlobalTheme.textTertiary.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              _pages[_currentPage].color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, int index) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Spacer(),

          // Icon
          Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: page.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(page.icon, size: 60, color: page.color),
              )
              .animate(key: ValueKey(index))
              .scale(duration: 600.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(duration: 2000.ms, color: page.color.withOpacity(0.3)),

          const SizedBox(height: 48),

          // Title
          Text(
                page.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
              .animate(key: ValueKey('title_$index'))
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0),

          const SizedBox(height: 16),

          // Subtitle
          Text(
                page.subtitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: page.color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              )
              .animate(key: ValueKey('subtitle_$index'))
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.3, end: 0),

          const SizedBox(height: 24),

          // Description
          Text(
                page.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              )
              .animate(key: ValueKey('description_$index'))
              .fadeIn(delay: 600.ms)
              .slideY(begin: 0.3, end: 0),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Permission status indicator (on last page)
          if (_currentPage == _pages.length - 1 &&
              _permissionState != PermissionState.unknown)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: StatusIndicator(
                status: _permissionService.getPermissionStatusText(),
                color: _getStatusColor(),
                icon: _getStatusIcon(),
                isPulsing: _permissionState == PermissionState.denied,
              ),
            ),

          // Main action button
          AppButton.primary(
            onPressed: _isLoading ? null : _nextPage,
            isLoading: _isLoading,
            text: _currentPage == _pages.length - 1
                ? 'Grant Permissions'
                : 'Continue',
            width: double.infinity,
            icon: _currentPage == _pages.length - 1 ? Icons.lock_open_rounded : Icons.arrow_forward_rounded,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.5, end: 0);
  }

  Color _getStatusColor() {
    switch (_permissionState) {
      case PermissionState.allGranted:
        return AppTheme.neonGreen;
      case PermissionState.partiallyGranted:
        return Colors.orange;
      case PermissionState.denied:
      case PermissionState.permanentlyDenied:
        return Colors.red;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getStatusIcon() {
    switch (_permissionState) {
      case PermissionState.allGranted:
        return Icons.check_circle;
      case PermissionState.partiallyGranted:
        return Icons.warning;
      case PermissionState.denied:
      case PermissionState.permanentlyDenied:
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Color _getButtonTextColor() {
    final color = _pages[_currentPage].color;
    // Calculate if the color is light or dark to determine text color
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

/// Onboarding page data model
class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;

  const OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
  });
}
