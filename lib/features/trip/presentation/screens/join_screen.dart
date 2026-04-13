import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/models/trip_member_model.dart';
import '../../../../shared/models/trip_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../shared/providers/guest_session_provider.dart';
import '../../../../shared/utils/browser_detector.dart';
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

      if (context.mounted) {
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

        // 非正規ブラウザチェック
        if (trip != null && _error == null) {
          _checkBrowser();
        }
      }
    } catch (e, st) {
      debugPrint('JoinScreen._loadTrip error: $e');
      debugPrint('Stack trace: $st');
      if (context.mounted) {
        setState(() {
          _isLoading = false;
          _error = 'エラーが発生しました: $e';
        });
      }
    }
  }

  void _checkBrowser() {
    if (BrowserDetector.isInAppBrowser()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _showBrowserWarning();
        }
      });
    }
  }

  void _showBrowserWarning() {
    final browserName = BrowserDetector.getBrowserName();
    final currentUrl = Uri.base.toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.accent),
            const SizedBox(width: AppSizes.paddingS),
            const Expanded(child: Text('ブラウザの互換性について')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$browserNameアプリ内ブラウザでは一部の機能が正常に動作しない可能性があります。',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              '下記のボタンでURLをコピーして、Safari・Chrome・Edgeなどの標準ブラウザで開いてください。',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Container(
              padding: const EdgeInsets.all(AppSizes.paddingS),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                currentUrl,
                style: AppTypography.caption.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('このまま続ける'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: currentUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('URLをコピーしました'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
              );
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.copy_rounded),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            label: Text(
              'URLをコピー',
              style: AppTypography.button.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// 旅行のステータスに応じた遷移先パスを返す
  String _routeForStatus(TripStatus status) {
    switch (status) {
      case TripStatus.lobby:
        return '/trip/${widget.tripId}/lobby';
      case TripStatus.collecting:
        return '/trip/${widget.tripId}';
      case TripStatus.voting:
      case TripStatus.confirmed:
      case TripStatus.ongoing:
        return '/trip/${widget.tripId}/plan';
    }
  }

  Future<bool> _joinTrip() async {
    setState(() => _isJoining = true);

    try {
      // 個別リンクの場合は既存メンバーとして参加
      if (_existingMember != null) {
        // ゲストセッションに名前を設定
        ref
            .read(guestSessionProvider.notifier)
            .setName(_existingMember!.displayName);
        context.go(_routeForStatus(_trip!.status));
        return true;
      }

      // 名前＋出発地点を収集
      final userInfo = await collectUserInfo(context, ref, forceShow: true);
      if (userInfo == null) {
        setState(() => _isJoining = false);
        return false;
      }

      final success = await ref
          .read(tripControllerProvider.notifier)
          .joinTrip(widget.tripId);
          
      if (!context.mounted) return false;

      if (success) {
        // メンバー詳細に出発地点を保存
        final userId = ref.read(currentUserIdProvider);
        if (userId != null) {
          final member = TripMember(
            userId: userId,
            displayName: userInfo.name,
            departurePoint: userInfo.departurePoint,
            joinedAt: DateTime.now(),
          );
          await ref
              .read(tripControllerProvider.notifier)
              .updateMemberDetails(widget.tripId, userId, member);
        }
        if (!context.mounted) return true;
        // ignore: use_build_context_synchronously
        context.go(_routeForStatus(_trip!.status));
        return true;
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('参加に失敗しました'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
          ),
        );
        return false;
      }
    } finally {
      if (context.mounted) {
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
    // ゲストセッション開始（Firebase Anonymous Auth）
    await ref.read(guestSessionProvider.notifier).startAsGuest();
    if (!context.mounted) return;

    // 旅行に参加（ダイアログ収集はここで行われる）
    final success = await _joinTrip();
    
    // キャンセルされた場合はゲストセッションを終了して無名ゲストが残るのを防ぐ
    if (!success && context.mounted) {
      ref.read(guestSessionProvider.notifier).endSession();
    }
  }
}
