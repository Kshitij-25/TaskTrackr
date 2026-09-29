import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

enum ButtonVariant { primary, secondary, ghost, destructive }

enum ButtonSize { small, large, medium }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
  });
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final double height = widget.size == ButtonSize.small
        ? 36.0
        : widget.size == ButtonSize.large
            ? 48.0
            : 44.0;

    final Color backgroundColor = _getBackgroundColor();
    final Color textColor = _getTextColor();
    final BorderSide? border = _getBorder();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        transform: _isHovering && widget.variant == ButtonVariant.primary
            ? Matrix4.translationValues(0, -2, 0)
            : Matrix4.identity(),
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            elevation:
                widget.variant == ButtonVariant.primary && _isHovering ? 8 : 0,
            shadowColor: AppColors.primary.withValues(alpha: 0.4),
            padding: EdgeInsets.symmetric(
              horizontal: widget.size == ButtonSize.small
                  ? AppSpacing.space3
                  : AppSpacing.space4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusSm,
              side: border ?? BorderSide.none,
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) &&
                  widget.variant == ButtonVariant.secondary) {
                return AppColors.primary.withValues(alpha: 0.1);
              }
              return null;
            }),
          ),
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 18),
                      const SizedBox(width: AppSpacing.space2),
                    ],
                    Text(
                      widget.text,
                      style: AppTypography.label.copyWith(
                        color: textColor,
                        fontSize: widget.size == ButtonSize.small ? 13 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (widget.onPressed == null) return AppColors.neutral200;
    switch (widget.variant) {
      case ButtonVariant.primary:
        return AppColors.primary;
      case ButtonVariant.secondary:
        return _isHovering ? AppColors.primary : AppColors.primaryLight;
      case ButtonVariant.ghost:
        return Colors.transparent;
      case ButtonVariant.destructive:
        return AppColors.danger.withValues(alpha: 0.1);
    }
  }

  Color _getTextColor() {
    if (widget.onPressed == null) return AppColors.neutral400;
    switch (widget.variant) {
      case ButtonVariant.primary:
        return Colors.white;
      case ButtonVariant.secondary:
        return _isHovering ? Colors.white : AppColors.primary;
      case ButtonVariant.ghost:
        return AppColors.neutral600;
      case ButtonVariant.destructive:
        return AppColors.danger;
    }
  }

  BorderSide? _getBorder() {
    return null;
  }
}
