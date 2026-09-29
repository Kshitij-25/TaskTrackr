import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

enum BadgeType { priority, status, category }

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.type = BadgeType.category,
    this.isOutline = false,
  });

  factory AppBadge.priority(String level) {
    Color color;
    switch (level.toLowerCase()) {
      case 'high':
        color = AppColors.high;
        break;
      case 'medium':
        color = AppColors.medium;
        break;
      default:
        color = AppColors.low;
    }
    return AppBadge(
      label: level,
      color: color,
      type: BadgeType.priority,
    );
  }
  final String label;
  final Color? color;
  final IconData? icon;
  final BadgeType type;
  final bool isOutline;

  @factory
  static AppBadge status(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = AppColors.success;
        break;
      case 'overdue':
        color = AppColors.warning;
        break;
      case 'blocked':
        color = AppColors.danger;
        break;
      case 'in progress':
        color = AppColors.primary;
        break;
      default:
        color = AppColors.neutral400;
    }
    return AppBadge(
      label: status,
      color: color,
      type: BadgeType.status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = color ?? AppColors.primary;
    final Color bgColor =
        isOutline ? Colors.transparent : baseColor.withValues(alpha: 0.1);
    final Color textColor = baseColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.borderRadiusFull,
        border: isOutline
            ? Border.all(color: baseColor.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (type == BadgeType.priority) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: baseColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
          ],
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: AppSpacing.space2),
          ],
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
