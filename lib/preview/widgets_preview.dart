import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/app_button.dart';
import '../components/neon_card.dart';
import '../components/modern_ui_components.dart';
import '../components/fitness_tracking_widgets.dart';
import '../models/fitness_models.dart';
import '../theme/global_theme.dart';

/// Widget Preview System for Calories Not Carbon
/// 
/// Usage:
/// 1. Run with: flutter run -t lib/preview/widgets_preview.dart
/// 2. Browse widgets in different states and sizes
/// 3. Test interactions in isolation

void main() {
  runApp(const WidgetPreviewApp());
}

/// Entry point for widget preview mode
class WidgetPreviewApp extends StatelessWidget {
  const WidgetPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Widget Preview - Calories Not Carbon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: GlobalTheme.backgroundPrimary,
        cardColor: GlobalTheme.backgroundSecondary,
        primaryColor: GlobalTheme.accentPrimary,
      ),
      home: const WidgetPreviewScreen(),
    );
  }
}

/// Main preview screen with categorized widgets
class WidgetPreviewScreen extends StatefulWidget {
  const WidgetPreviewScreen({super.key});

  @override
  State<WidgetPreviewScreen> createState() => _WidgetPreviewScreenState();
}

class _WidgetPreviewScreenState extends State<WidgetPreviewScreen> {
  String _selectedCategory = 'All';
  double _previewScale = 1.0;
  bool _showGrid = true;

  final List<String> _categories = [
    'All',
    'Buttons',
    'Cards',
    'Fitness',
    'Metrics',
    'Status',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Preview'),
        backgroundColor: GlobalTheme.backgroundSecondary,
        actions: [
          // Scale control
          Row(
            children: [
              const Text('Scale:'),
              Slider(
                value: _previewScale,
                min: 0.5,
                max: 1.5,
                divisions: 10,
                label: '${(_previewScale * 100).toInt()}%',
                onChanged: (value) => setState(() => _previewScale = value),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Grid toggle
          IconButton(
            icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off),
            tooltip: 'Toggle Grid',
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Category selector
          Container(
            height: 60,
            color: GlobalTheme.backgroundSecondary.withOpacity(0.5),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = category);
                      }
                    },
                    backgroundColor: GlobalTheme.backgroundPrimary,
                    selectedColor: GlobalTheme.accentPrimary.withOpacity(0.3),
                  ),
                );
              },
            ),
          ),
          // Widget previews
          Expanded(
            child: _buildPreviewGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewGrid() {
    final previews = _getPreviewsForCategory(_selectedCategory);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 
            ? 4 
            : constraints.maxWidth > 800 
                ? 3 
                : constraints.maxWidth > 500 
                    ? 2 
                    : 1;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: previews.length,
          itemBuilder: (context, index) {
            return _buildPreviewCard(previews[index]);
          },
        );
      },
    );
  }

  Widget _buildPreviewCard(WidgetPreview preview) {
    return Card(
      elevation: 4,
      color: GlobalTheme.backgroundSecondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview title
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GlobalTheme.backgroundPrimary,
              border: Border(
                bottom: BorderSide(
                  color: GlobalTheme.accentPrimary.withOpacity(0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    preview.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (preview.tags.isNotEmpty)
                  ...preview.tags.map((tag) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )),
              ],
            ),
          ),
          // Widget preview area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: _showGrid ? BoxDecoration(
                color: GlobalTheme.backgroundPrimary.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: GlobalTheme.textSecondary.withOpacity(0.1),
                ),
              ) : null,
              child: Center(
                child: Transform.scale(
                  scale: _previewScale,
                  child: preview.builder(context),
                ),
              ),
            ),
          ),
          // Description
          if (preview.description != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                preview.description!,
                style: TextStyle(
                  fontSize: 12,
                  color: GlobalTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  List<WidgetPreview> _getPreviewsForCategory(String category) {
    final allPreviews = _getAllPreviews();
    
    if (category == 'All') {
      return allPreviews;
    }
    
    return allPreviews.where((p) => p.category == category).toList();
  }

  List<WidgetPreview> _getAllPreviews() {
    return [
      // Buttons
      WidgetPreview(
        name: 'App Button - Primary',
        category: 'Buttons',
        tags: ['primary', 'filled'],
        description: 'Main call-to-action button with accent color',
        builder: (context) => AppButton.primary(
          text: 'Start Workout',
          onPressed: () {},
        ),
      ),
      WidgetPreview(
        name: 'App Button - Secondary',
        category: 'Buttons',
        tags: ['secondary', 'outlined'],
        description: 'Secondary action with outline style',
        builder: (context) => AppButton.secondary(
          text: 'Cancel',
          onPressed: () {},
        ),
      ),
      WidgetPreview(
        name: 'App Button - Ghost',
        category: 'Buttons',
        tags: ['ghost', 'text'],
        description: 'Low emphasis button for subtle actions',
        builder: (context) => AppButton.ghost(
          text: 'Skip',
          onPressed: () {},
        ),
      ),
      WidgetPreview(
        name: 'App Button - Loading',
        category: 'Buttons',
        tags: ['loading', 'disabled'],
        description: 'Button in loading state',
        builder: (context) => const AppButton.primary(
          text: 'Saving...',
          onPressed: null,
          isLoading: true,
        ),
      ),
      WidgetPreview(
        name: 'App Button - With Icon',
        category: 'Buttons',
        tags: ['icon', 'composite'],
        description: 'Button with leading icon',
        builder: (context) => AppButton.primary(
          text: 'Add Goal',
          onPressed: () {},
          icon: Icons.add,
        ),
      ),
      WidgetPreview(
        name: 'Enhanced FAB',
        category: 'Buttons',
        tags: ['fab', 'floating'],
        description: 'Enhanced floating action button',
        builder: (context) => EnhancedFAB(
          icon: Icons.add,
          onPressed: () {},
          label: 'New Activity',
        ),
      ),

      // Cards
      WidgetPreview(
        name: 'Neon Card',
        category: 'Cards',
        tags: ['neon', 'glow', 'dark'],
        description: 'Card with neon glow effect',
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: NeonCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 48,
                    color: GlobalTheme.accentPrimary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Workout Complete!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      WidgetPreview(
        name: 'Permission Prompt Card',
        category: 'Cards',
        tags: ['permission', 'prompt'],
        description: 'Card for requesting permissions',
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: PermissionPromptCard(
            icon: Icons.location_on,
            title: 'Location Access',
            description: 'Allow location access to track your workouts',
            onAllow: () {},
            onDeny: () {},
          ),
        ),
      ),
      WidgetPreview(
        name: 'Loading State Card',
        category: 'Cards',
        tags: ['loading', 'skeleton'],
        description: 'Loading placeholder card',
        builder: (context) => const Padding(
          padding: EdgeInsets.all(16),
          child: LoadingStateCard(),
        ),
      ),
      WidgetPreview(
        name: 'Error State Card',
        category: 'Cards',
        tags: ['error', 'retry'],
        description: 'Error display with retry option',
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorStateCard(
            message: 'Failed to load activity data',
            onRetry: () {},
          ),
        ),
      ),

      // Metrics
      WidgetPreview(
        name: 'Metric Card - Distance',
        category: 'Metrics',
        tags: ['metric', 'stat'],
        description: 'Card for displaying fitness metrics',
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: MetricCard(
            label: 'Distance',
            value: '5.2',
            unit: 'km',
            icon: Icons.route,
            accentColor: GlobalTheme.accentPrimary,
          ),
        ),
      ),
      WidgetPreview(
        name: 'Metric Card - Calories',
        category: 'Metrics',
        tags: ['metric', 'stat'],
        description: 'Calories burned metric card',
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: MetricCard(
            label: 'Calories',
            value: '245',
            unit: 'kcal',
            icon: Icons.local_fire_department,
            accentColor: Colors.orange,
          ),
        ),
      ),
      WidgetPreview(
        name: 'Metric Card - Highlighted',
        category: 'Metrics',
        tags: ['metric', 'highlighted'],
        description: 'Highlighted metric card',
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: MetricCard(
            label: 'Active Time',
            value: '23:45',
            unit: 'min',
            icon: Icons.timer,
            accentColor: GlobalTheme.accentPrimary,
            isHighlighted: true,
          ),
        ),
      ),

      // Fitness Widgets
      WidgetPreview(
        name: 'Fitness Stats - Idle',
        category: 'Fitness',
        tags: ['stats', 'idle'],
        description: 'Fitness stats in idle state',
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: FitnessStatsWidget(
            stats: FitnessStats(
              distance: 0,
              calories: 0,
              duration: const Duration(seconds: 0),
              avgPace: 0,
              currentPace: 0,
            ),
            state: ActivityState.idle,
          ),
        ),
      ),
      WidgetPreview(
        name: 'Fitness Stats - Running',
        category: 'Fitness',
        tags: ['stats', 'running'],
        description: 'Fitness stats while running',
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: FitnessStatsWidget(
            stats: FitnessStats(
              distance: 5.2,
              calories: 245,
              duration: const Duration(minutes: 23, seconds: 45),
              avgPace: 5.5,
              currentPace: 5.2,
            ),
            state: ActivityState.running,
          ),
        ),
      ),
      WidgetPreview(
        name: 'Fitness Stats - Paused',
        category: 'Fitness',
        tags: ['stats', 'paused'],
        description: 'Fitness stats in paused state',
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: FitnessStatsWidget(
            stats: FitnessStats(
              distance: 3.1,
              calories: 156,
              duration: const Duration(minutes: 18, seconds: 30),
              avgPace: 5.8,
              currentPace: 0,
            ),
            state: ActivityState.paused,
          ),
        ),
      ),

      // Status Indicators
      WidgetPreview(
        name: 'Status Indicator - Online',
        category: 'Status',
        tags: ['status', 'online'],
        description: 'Online status indicator',
        builder: (context) => const Padding(
          padding: EdgeInsets.all(16),
          child: StatusIndicator(
            status: Status.online,
            label: 'GPS Connected',
          ),
        ),
      ),
      WidgetPreview(
        name: 'Status Indicator - Syncing',
        category: 'Status',
        tags: ['status', 'syncing'],
        description: 'Syncing status indicator',
        builder: (context) => const Padding(
          padding: EdgeInsets.all(16),
          child: StatusIndicator(
            status: Status.syncing,
            label: 'Syncing Data...',
          ),
        ),
      ),
      WidgetPreview(
        name: 'Status Indicator - Offline',
        category: 'Status',
        tags: ['status', 'offline'],
        description: 'Offline status indicator',
        builder: (context) => const Padding(
          padding: EdgeInsets.all(16),
          child: StatusIndicator(
            status: Status.offline,
            label: 'GPS Signal Lost',
          ),
        ),
      ),
    ];
  }
}

/// Data class for widget preview
class WidgetPreview {
  final String name;
  final String category;
  final List<String> tags;
  final String? description;
  final Widget Function(BuildContext) builder;

  const WidgetPreview({
    required this.name,
    required this.category,
    this.tags = const [],
    this.description,
    required this.builder,
  });
}

/// Preview wrapper for Riverpod-dependent widgets
class PreviewWrapper extends StatelessWidget {
  final Widget child;
  final List<Override> overrides;

  const PreviewWrapper({
    super.key,
    required this.child,
    this.overrides = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: child,
    );
  }
}
