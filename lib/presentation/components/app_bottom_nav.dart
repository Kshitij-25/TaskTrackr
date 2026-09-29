import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAddTap,
  });
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      padding: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      elevation: 16,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
                context, 0, Icons.home_outlined, 'Home', currentIndex == 0),
            _buildNavItem(context, 1, Icons.check_box_outlined, 'Tasks',
                currentIndex == 1),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(context, 2, Icons.calendar_today_outlined, 'Calendar',
                currentIndex == 2),
            _buildNavItem(context, 3, Icons.bar_chart_outlined, 'Insights',
                currentIndex == 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon,
      String label, bool isActive) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppFab extends StatefulWidget {
  const AppFab({
    super.key,
    required this.onPressed,
    this.isCompact = false,
  });
  final VoidCallback onPressed;
  final bool isCompact;

  @override
  State<AppFab> createState() => _AppFabState();
}

class _AppFabState extends State<AppFab> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double size = widget.isCompact ? 44.0 : 56.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Ripple effect
            Container(
              width: size * (1.0 + (_controller.value * 0.8)),
              height: size * (1.0 + (_controller.value * 0.8)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary
                    .withValues(alpha: 0.3 * (1.0 - _controller.value)),
              ),
            ),
            child!,
          ],
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(size / 2),
            child: Icon(
              Icons.add,
              color: theme.colorScheme.onPrimary,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
