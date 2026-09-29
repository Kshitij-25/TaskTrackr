import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_badge.dart';

class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.title,
    required this.date,
    required this.priority,
    required this.category,
    this.isCompleted = false,
    this.isPending = false,
    this.onTap,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });
  final String title;
  final String date;
  final String priority;
  final String category;
  final bool isCompleted;
  final bool isPending;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _completeController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _completeController = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1, end: 1.1)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.1, end: 1)
              .chain(CurveTween(curve: AppMotion.easeSpring)),
          weight: 50),
    ]).animate(_completeController);
  }

  @override
  void dispose() {
    _completeController.dispose();
    super.dispose();
  }

  void _handleToggle() {
    if (!widget.isCompleted) {
      _completeController.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
    widget.onToggle?.call(!widget.isCompleted);
  }

  @override
  Widget build(BuildContext context) {
    Color priorityColor;
    switch (widget.priority.toLowerCase()) {
      case 'high':
        priorityColor = AppColors.high;
        break;
      case 'medium':
        priorityColor = AppColors.medium;
        break;
      default:
        priorityColor = AppColors.low;
    }

    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(widget.title + widget.date),
      secondaryBackground: _buildSwipeBackground(
        color: AppColors.danger,
        icon: Icons.delete_outline,
        alignment: Alignment.centerRight,
      ),
      background: _buildSwipeBackground(
        color: AppColors.primary,
        icon: Icons.edit_outlined,
        alignment: Alignment.centerLeft,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          widget.onDelete?.call();
          return true;
        } else {
          widget.onEdit?.call();
          return false;
        }
      },
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          HapticFeedback.lightImpact();
        }
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: AppMotion.normal,
            margin: const EdgeInsets.only(bottom: AppSpacing.space3),
            transform: _isHovering
                ? Matrix4.translationValues(0, -1, 0)
                : Matrix4.identity(),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.borderRadiusMd,
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: _isHovering ? 0.08 : 0.04),
                  blurRadius: _isHovering ? 12 : 4,
                  offset: Offset(0, _isHovering ? 4 : 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.borderRadiusMd,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      color: priorityColor,
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: widget.onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.space3),
                          child: Row(
                            children: [
                              // Improved Checkbox Touch Target
                              InkWell(
                                onTap: _handleToggle,
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  child: AnimatedContainer(
                                    duration: AppMotion.normal,
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: widget.isCompleted
                                          ? AppColors.success
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: widget.isCompleted
                                            ? AppColors.success
                                            : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: widget.isCompleted
                                        ? const Icon(Icons.check,
                                            size: 14, color: Colors.white)
                                        : null,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: AppTypography.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: widget.isCompleted
                                            ? theme.colorScheme.onSurface
                                                .withValues(alpha: 0.4)
                                            : theme.colorScheme.onSurface,
                                        decoration: widget.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: AppSpacing.space1),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined,
                                            size: 10,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.4)),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.date,
                                          style: AppTypography.label.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.4)),
                                        ),
                                        const SizedBox(
                                            width: AppSpacing.space3),
                                        AppBadge.priority(widget.priority),
                                        const SizedBox(
                                            width: AppSpacing.space2),
                                        AppBadge(label: widget.category),
                                        if (widget.isPending) ...[
                                          const SizedBox(
                                              width: AppSpacing.space2),
                                          Icon(
                                            Icons.cloud_upload_outlined,
                                            size: 14,
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.6),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.space4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space3),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space6),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.borderRadiusMd,
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}
