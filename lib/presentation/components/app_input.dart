import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.isMultiline = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.readOnly = false,
  });
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool isMultiline;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        TextField(
          controller: controller,
          maxLines: isMultiline ? 4 : 1,
          onTap: onTap,
          readOnly: readOnly,
          style:
              AppTypography.body.copyWith(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.body.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space3,
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: AppRadius.borderRadiusSm,
              borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.borderRadiusSm,
              borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.borderRadiusSm,
              borderSide:
                  BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class AppPrioritySelector extends StatelessWidget {
  const AppPrioritySelector({
    super.key,
    required this.selectedPriority,
    required this.onChanged,
  });
  final String selectedPriority;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: AppTypography.label.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        Row(
          children: [
            _buildPriorityOption(context, 'High', AppColors.high),
            const SizedBox(width: AppSpacing.space2),
            _buildPriorityOption(context, 'Medium', AppColors.medium),
            const SizedBox(width: AppSpacing.space2),
            _buildPriorityOption(context, 'Low', AppColors.low),
          ],
        ),
      ],
    );
  }

  Widget _buildPriorityOption(BuildContext context, String level, Color color) {
    final theme = Theme.of(context);
    final bool isSelected =
        selectedPriority.toLowerCase() == level.toLowerCase();
    return GestureDetector(
      onTap: () => onChanged(level),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: AppRadius.borderRadiusFull,
          border: Border.all(
            color: isSelected
                ? color
                : theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.4), blurRadius: 4)
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              level,
              style: AppTypography.label.copyWith(
                color: isSelected
                    ? color
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
