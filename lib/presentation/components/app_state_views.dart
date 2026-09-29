import 'package:flutter/material.dart';
import 'package:svg_flutter/svg.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.iconPath,
    this.iconData,
    this.actionLabel,
    this.onActionPressed,
  });
  final String title;
  final String subtitle;
  final String? iconPath;
  final IconData? iconData;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconPath != null)
              SvgPicture.asset(
                iconPath!,
                height: 120,
                colorFilter: ColorFilter.mode(
                  theme.colorScheme.primary.withValues(alpha: 0.2),
                  BlendMode.srcIn,
                ),
              )
            else if (iconData != null)
              Icon(
                iconData,
                size: 80,
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            const SizedBox(height: AppSpacing.space6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.heading2.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: AppSpacing.space8),
              AppButton(
                text: actionLabel!,
                onPressed: onActionPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.error,
    this.onRetry,
  });
  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'Something went wrong',
              style: AppTypography.heading2.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.space6),
              AppButton(
                text: 'Try Again',
                onPressed: onRetry,
                variant: ButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
