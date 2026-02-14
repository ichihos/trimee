import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_typography.dart';
import '../models/card_model.dart';

/// リアクションボタン（👍 😐 👎）
class ReactionButton extends StatelessWidget {
  const ReactionButton({
    super.key,
    required this.type,
    required this.count,
    required this.onTap,
    this.isSelected = false,
  });

  final ReactionType type;
  final int count;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final (emoji, color) = switch (type) {
      ReactionType.up => ('👍', AppColors.reactionUp),
      ReactionType.neutral => ('😐', AppColors.reactionNeutral),
      ReactionType.down => ('👎', AppColors.reactionDown),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: AppSizes.animationDurationFast),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingS,
          vertical: AppSizes.paddingXS,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: AppSizes.paddingXS),
            Text(
              count.toString(),
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// リアクションボタングループ
class ReactionButtonGroup extends StatelessWidget {
  const ReactionButtonGroup({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onReact,
  });

  final Map<String, ReactionType> reactions;
  final String currentUserId;
  final void Function(ReactionType) onReact;

  @override
  Widget build(BuildContext context) {
    final currentReaction = reactions[currentUserId];
    final upCount = reactions.values.where((r) => r == ReactionType.up).length;
    final neutralCount =
        reactions.values.where((r) => r == ReactionType.neutral).length;
    final downCount =
        reactions.values.where((r) => r == ReactionType.down).length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReactionButton(
          type: ReactionType.up,
          count: upCount,
          isSelected: currentReaction == ReactionType.up,
          onTap: () => onReact(ReactionType.up),
        ),
        const SizedBox(width: AppSizes.paddingS),
        ReactionButton(
          type: ReactionType.neutral,
          count: neutralCount,
          isSelected: currentReaction == ReactionType.neutral,
          onTap: () => onReact(ReactionType.neutral),
        ),
        const SizedBox(width: AppSizes.paddingS),
        ReactionButton(
          type: ReactionType.down,
          count: downCount,
          isSelected: currentReaction == ReactionType.down,
          onTap: () => onReact(ReactionType.down),
        ),
      ],
    );
  }
}
