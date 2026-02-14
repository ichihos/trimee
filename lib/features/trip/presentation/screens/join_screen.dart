import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/models/trip_member_model.dart';
import '../../../../shared/models/trip_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../shared/providers/guest_session_provider.dart';
import '../../../../shared/widgets/name_input_dialog.dart';
import '../providers/trip_provider.dart';

/// 旅行参加画面（招待リンクから）
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, required this.tripId, this.personalLinkId});

  final String tripId;
  final String? personalLinkId;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  TripModel? _trip;
  TripMember? _existingMember;
  bool _isLoading = true;
  bool _isJoining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final trip = await ref
          .read(tripControllerProvider.notifier)
          .getTrip(widget.tripId);
      TripMember? existingMember;

      // 個別リンクの場合、既存の手動メンバーを検索
      if (widget.personalLinkId != null && trip != null) {
        existingMember = trip.memberDetails.values.firstWhere(
          (m) => m.personalLinkId == widget.personalLinkId,
          orElse: () => const TripMember(userId: '', displayName: ''),
        );
        if (existingMember.userId.isEmpty) {
          existingMember = null;
        }
      }

      if (mounted) {
        setState(() {
          _trip = trip;
          _existingMember = existingMember;
          _isLoading = false;
          if (trip == null) {
            _error = '旅行が見つかりませんでした';
          } else if (widget.personalLinkId != null && existingMember == null) {
            _error = '無効な招待リンクです';
          }
        });
      }
    } catch (e, st) {
      debugPrint('JoinScreen._loadTrip error: $e');
      debugPrint('Stack trace: $st');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'エラーが発生しました: $e';
        });
      }
    }
  }

  Future<void> _joinTrip() async {
    setState(() => _isJoining = true);

    try {
      // 個別リンクの場合は既存メンバーとして参加
      if (_existingMember != null) {
        // ゲストセッションに名前を設定
        ref
            .read(guestSessionProvider.notifier)
            .setName(_existingMember!.displayName);
        context.go('/trip/${widget.tripId}');
        return;
      }

      // 通常の参加フロー
      final hasName = await ensureUserHasName(context, ref);
      if (!hasName) {
        setState(() => _isJoining = false);
        return;
      }

      final success = await ref
          .read(tripControllerProvider.notifier)
          .joinTrip(widget.tripId);
      if (mounted) {
        if (success) {
          context.go('/trip/${widget.tripId}');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('参加に失敗しました'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isGuest = ref.watch(isGuestModeProvider);
    final hasSession = isAuthenticated || isGuest;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildError()
                : _buildContent(hasSession),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 40,
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),
            Text(
              _error!,
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.paddingXL),
            ElevatedButton(
              onPressed: () => context.go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
              child: Text(
                'ホームに戻る',
                style: AppTypography.button.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool hasSession) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        children: [
          const Spacer(),
          // 招待アイコン
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group_add_rounded,
              color: AppColors.accent,
              size: 48,
            ),
          ),
          const SizedBox(height: AppSizes.paddingXL),

          // タイトル
          Text('旅行への招待', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSizes.paddingS),

          Text(
            '「${_trip!.title}」に招待されています',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.paddingXL),

          // 旅行情報カード
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.flight_takeoff_rounded,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSizes.paddingS),
                    Expanded(
                      child: Text(
                        _trip!.title,
                        style: AppTypography.titleMedium,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSizes.paddingM),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSizes.paddingS),
                    Text(
                      _trip!.formattedDateRange,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSizes.paddingS),
                Row(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSizes.paddingS),
                    Text(
                      '${_trip!.members.length}人が参加中',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),

          // 参加ボタン
          if (hasSession) ...[
            ElevatedButton(
              onPressed: _isJoining ? null : _joinTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(52),
              ),
              child:
                  _isJoining
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        'この旅行に参加する',
                        style: AppTypography.button.copyWith(
                          color: Colors.white,
                        ),
                      ),
            ),
          ] else ...[
            // 未ログインの場合
            ElevatedButton(
              onPressed: () => _startAsGuest(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(
                'ゲストとして参加',
                style: AppTypography.button.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            OutlinedButton(
              onPressed: () => context.push('/sign-in'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('ログインして参加'),
            ),
          ],
          const SizedBox(height: AppSizes.paddingM),
        ],
      ),
    );
  }

  Future<void> _startAsGuest() async {
    // ゲストセッション開始
    ref.read(guestSessionProvider.notifier).startAsGuest();

    // 名前入力ダイアログを表示
    final name = await NameInputDialog.show(context);
    if (name == null || name.isEmpty) {
      // キャンセルした場合はゲストセッションを終了
      ref.read(guestSessionProvider.notifier).endSession();
      return;
    }

    // 旅行に参加
    await _joinTrip();
  }
}
