import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_typography.dart';
import '../models/user_profile_model.dart';
import '../providers/firebase_providers.dart';
import '../providers/guest_session_provider.dart';
import '../providers/user_profile_provider.dart';
import 'app_icon.dart';

/// ユーザー入力結果
class UserInputResult {
  final String name;
  final String? departurePoint;

  const UserInputResult({required this.name, this.departurePoint});
}

/// 名前・出発地点入力ダイアログ
class NameInputDialog extends ConsumerStatefulWidget {
  const NameInputDialog({
    super.key,
    this.title = 'お名前を教えてください',
    this.message = '他のメンバーに表示される名前を入力してください',
    this.hintText = '例: たろう',
    this.confirmLabel = '参加する',
    this.askDeparturePoint = false,
  });

  final String title;
  final String message;
  final String hintText;
  final String confirmLabel;
  final bool askDeparturePoint;

  /// ダイアログを表示（名前のみ、後方互換性のため）
  static Future<String?> show(
    BuildContext context, {
    String? title,
    String? message,
    String? hintText,
    String? confirmLabel,
  }) async {
    final result = await showDialog<UserInputResult>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => NameInputDialog(
            title: title ?? 'お名前を教えてください',
            message: message ?? '他のメンバーに表示される名前を入力してください',
            hintText: hintText ?? '例: たろう',
            confirmLabel: confirmLabel ?? '参加する',
            askDeparturePoint: false,
          ),
    );
    return result?.name;
  }

  /// ダイアログを表示（名前＋出発地点）
  static Future<UserInputResult?> showWithDeparture(
    BuildContext context, {
    String? title,
    String? message,
    String? hintText,
    String? confirmLabel,
  }) {
    return showDialog<UserInputResult>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => NameInputDialog(
            title: title ?? 'あなたのことを教えてください',
            message: message ?? '名前と出発地点を入力してください',
            hintText: hintText ?? '例: たろう',
            confirmLabel: confirmLabel ?? '始める',
            askDeparturePoint: true,
          ),
    );
  }

  @override
  ConsumerState<NameInputDialog> createState() => _NameInputDialogState();
}

class _NameInputDialogState extends ConsumerState<NameInputDialog> {
  final _nameController = TextEditingController();
  final _departureController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _departureFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final existingName = ref.read(guestNameProvider);
    if (existingName != null && existingName.isNotEmpty) {
      _nameController.text = existingName;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _departureController.dispose();
    _nameFocusNode.dispose();
    _departureFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: AppIcon(type: AppIconType.group, size: 32),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),

              Text(
                widget.title,
                style: AppTypography.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.paddingS),

              Text(
                widget.message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.paddingL),

              // 名前入力
              TextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                decoration: InputDecoration(
                  labelText: 'ニックネーム',
                  hintText: widget.hintText,
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: AppColors.textSecondary,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction:
                    widget.askDeparturePoint
                        ? TextInputAction.next
                        : TextInputAction.done,
                onSubmitted: (_) {
                  if (widget.askDeparturePoint) {
                    _departureFocusNode.requestFocus();
                  } else {
                    _submit();
                  }
                },
              ),

              // 出発地点入力（オプション）
              if (widget.askDeparturePoint) ...[
                const SizedBox(height: AppSizes.paddingM),
                TextField(
                  controller: _departureController,
                  focusNode: _departureFocusNode,
                  decoration: InputDecoration(
                    labelText: '出発地点',
                    hintText: '例: 東京駅、新宿など',
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  '※ AIが交通費や移動時間を考慮したプランを作成します',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              const SizedBox(height: AppSizes.paddingL),

              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  widget.confirmLabel,
                  style: AppTypography.button.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('名前を入力してください'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
        ),
      );
      return;
    }

    ref.read(guestSessionProvider.notifier).setName(name);

    final isGuest = ref.read(isGuestModeProvider);
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (isGuest && !isAuthenticated) {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        final localProfile = ref.read(localProfileProvider);
        if (localProfile != null) {
          ref
              .read(localProfileProvider.notifier)
              .updateProfile(displayName: name);
        } else {
          final now = DateTime.now();
          ref
              .read(localProfileProvider.notifier)
              .setProfile(
                UserProfileModel(
                  userId: userId,
                  displayName: name,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      }
    }

    final departure = _departureController.text.trim();
    Navigator.of(context).pop(
      UserInputResult(
        name: name,
        departurePoint: departure.isNotEmpty ? departure : null,
      ),
    );
  }
}

/// 名前が必要かどうかをチェックするユーティリティ
Future<bool> ensureGuestHasName(BuildContext context, WidgetRef ref) async {
  final isGuest = ref.read(isGuestModeProvider);
  final hasName = ref.read(guestSessionProvider.notifier).hasName;

  if (isGuest && !hasName) {
    final name = await NameInputDialog.show(context);
    return name != null && name.isNotEmpty;
  }

  return true;
}

/// ユーザーが名前を持っているかチェック（ゲスト・ログインユーザー両方）
Future<bool> ensureUserHasName(BuildContext context, WidgetRef ref) async {
  final isAuthenticated = ref.read(isAuthenticatedProvider);
  final isGuest = ref.read(isGuestModeProvider);

  if (isAuthenticated) {
    final userName = ref.read(currentUserNameProvider);
    if (userName != null && userName.isNotEmpty) {
      return true;
    }
    final name = await NameInputDialog.show(
      context,
      title: 'ニックネームを設定',
      message: '他のメンバーに表示される名前を入力してください',
      confirmLabel: '設定する',
    );
    if (name != null && name.isNotEmpty) {
      ref.read(guestSessionProvider.notifier).setName(name);
      return true;
    }
    return false;
  }

  if (isGuest) {
    final hasName = ref.read(guestSessionProvider.notifier).hasName;
    if (!hasName) {
      final name = await NameInputDialog.show(context);
      return name != null && name.isNotEmpty;
    }
  }

  return true;
}

/// ユーザー情報（名前＋出発地点）を収集
Future<UserInputResult?> collectUserInfo(
  BuildContext context,
  WidgetRef ref, {
  bool forceShow = false,
}) async {
  final isGuest = ref.read(isGuestModeProvider);
  final hasName = ref.read(guestSessionProvider.notifier).hasName;

  if (!forceShow && hasName) {
    final existingName = ref.read(guestNameProvider);
    final session = ref.read(guestSessionProvider);
    if (existingName != null && existingName.isNotEmpty) {
      return UserInputResult(
        name: existingName,
        departurePoint: session?.departurePoint,
      );
    }
  }

  final result = await NameInputDialog.showWithDeparture(
    context,
    title: 'あなたのことを教えてください',
    message: '名前と出発地点を入力してください',
    confirmLabel: '始める',
  );

  if (result != null) {
    ref
        .read(guestSessionProvider.notifier)
        .setUserInfo(name: result.name, departurePoint: result.departurePoint);

    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (isGuest && !isAuthenticated) {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        final now = DateTime.now();
        final localProfile = ref.read(localProfileProvider);

        if (localProfile != null) {
          ref
              .read(localProfileProvider.notifier)
              .updateProfile(displayName: result.name);
        } else {
          ref
              .read(localProfileProvider.notifier)
              .setProfile(
                UserProfileModel(
                  userId: userId,
                  displayName: result.name,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      }
    }
  }

  return result;
}
