import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_typography.dart';
import '../../shared/models/trip_member_model.dart';
import '../../features/trip/presentation/providers/trip_provider.dart';
import 'app_icon.dart';

const _uuid = Uuid();

/// メンバー招待シート（共有ウィジェット）
///
/// カード画面・プラン選択画面などから共通で利用します。
class InviteSheet extends ConsumerWidget {
  const InviteSheet({super.key, required this.tripId});

  final String tripId;

  Future<void> _showAddManualMemberDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();
    final departureController = TextEditingController();
    final departureFocus = FocusNode();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (dialogContext) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            insetPadding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'メンバーを追加',
                      style: AppTypography.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.paddingS),
                    Text(
                      'セッションに参加できないメンバーを代わりに追加します',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.paddingL),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '名前',
                        hintText: '例: たろう',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => departureFocus.requestFocus(),
                    ),
                    const SizedBox(height: AppSizes.paddingM),
                    TextField(
                      controller: departureController,
                      focusNode: departureFocus,
                      decoration: const InputDecoration(
                        labelText: '出発地点（任意）',
                        hintText: '例: 東京駅',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(dialogContext, {
                          'name': name,
                          'departure': departureController.text.trim(),
                        });
                      },
                    ),
                    const SizedBox(height: AppSizes.paddingL),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('キャンセル'),
                          ),
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('名前を入力してください'),
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(dialogContext, {
                                'name': name,
                                'departure': departureController.text.trim(),
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                            ),
                            child: const Text(
                              '追加',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    nameController.dispose();
    departureController.dispose();
    departureFocus.dispose();

    if (result != null) {
      final personalLinkId = _uuid.v4().substring(0, 8);
      final memberId = 'manual_$personalLinkId';
      final member = TripMember(
        userId: memberId,
        displayName: result['name']!,
        departurePoint:
            result['departure']!.isNotEmpty ? result['departure'] : null,
        isManual: true,
        personalLinkId: personalLinkId,
        joinedAt: DateTime.now(),
      );

      await ref
          .read(tripControllerProvider.notifier)
          .updateMemberDetails(tripId, memberId, member);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['name']}さんを追加しました'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteLink = 'https://trimee-ai.com/join/$tripId';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドル
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSizes.paddingL),

          Row(
            children: [
              const AppIcon(type: AppIconType.group, size: 28),
              const SizedBox(width: AppSizes.paddingS),
              Text(
                AppStrings.inviteMembers,
                style: AppTypography.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),

          Text(
            'リンクを共有するか、メンバーを手動で追加できます',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingL),

          // リンクコピーボタン
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteLink));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(AppStrings.linkCopied),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.link_rounded),
            label: const Text(AppStrings.copyLink),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),

          // 手動追加ボタン
          OutlinedButton.icon(
            onPressed: () => _showAddManualMemberDialog(context, ref),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('メンバーを手動で追加'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.subAccent,
              side: const BorderSide(color: AppColors.subAccent),
            ),
          ),
          const SizedBox(height: AppSizes.paddingL),
        ],
      ),
    );
  }
}
