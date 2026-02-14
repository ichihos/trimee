import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_typography.dart';

/// 空の状態表示ウィジェット
/// 仕様書に基づいた「一言コピー + シンプルなイラスト」のデザイン
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon,
    this.action,
    this.actionLabel,
    this.secondaryAction,
    this.secondaryActionLabel,
  });

  final String message;
  final IconData? icon;
  final VoidCallback? action;
  final String? actionLabel;
  final VoidCallback? secondaryAction;
  final String? secondaryActionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(
                icon,
                size: AppSizes.iconXL * 2,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            const SizedBox(height: AppSizes.paddingL),
            Text(
              message,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: AppSizes.paddingL),
              ElevatedButton(
                onPressed: action,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  ),
                  minimumSize: const Size(200, 48),
                ),
                child: Text(
                  actionLabel!,
                  style: AppTypography.button.copyWith(color: Colors.white),
                ),
              ),
            ],
            if (secondaryAction != null && secondaryActionLabel != null) ...[
              const SizedBox(height: AppSizes.paddingM),
              TextButton(
                onPressed: secondaryAction,
                child: Text(
                  secondaryActionLabel!,
                  style: AppTypography.button.copyWith(color: AppColors.accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
