import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/global_theme.dart';
import '../services/navigation_service.dart';

class ProfileHeader extends ConsumerWidget {
  final bool showNotification;
  final VoidCallback? onUserNameTap;

  const ProfileHeader({
    super.key,
    this.showNotification = true,
    this.onUserNameTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Simple avatar
        CircleAvatar(
          radius: 22,
          backgroundColor: GlobalTheme.primaryNeon,
          child: const Icon(Icons.person, color: Colors.black, size: 24),
        ),
        const SizedBox(width: 12),

        // User info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onUserNameTap,
                child: Text(
                  'Anonymous User',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: GlobalTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Burn to earn!',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: GlobalTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // History icon
        if (showNotification)
          IconButton(
            onPressed: () => NavigationService.goToHistory(context),
            icon: const Icon(Icons.history_rounded, size: 24),
            style: IconButton.styleFrom(
              foregroundColor: GlobalTheme.textSecondary,
              backgroundColor: GlobalTheme.surfaceCard,
            ),
          ),
      ],
    );
  }
}
