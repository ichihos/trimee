import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../../shared/providers/guest_session_provider.dart';
import '../../../../shared/providers/firebase_providers.dart' show currentUserIdProvider, isAuthenticatedProvider;
import '../../../../shared/providers/user_profile_provider.dart';
import '../../../../shared/models/user_profile_model.dart';
import '../../../../shared/widgets/animated_widgets.dart';
import '../../../../shared/models/trip_model.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../plan/presentation/providers/plan_provider.dart';
import '../../../plan/presentation/screens/plan_edit_screen.dart';
import '../../../plan/presentation/screens/plan_view_screen.dart';
import '../../../trip/presentation/providers/trip_provider.dart';

/// ホーム画面
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(userTripsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ヘッダー
            SliverToBoxAdapter(
              child: _HomeHeader(
                onCreateTrip: () => _showCreateTripDialog(context, ref),
                onJoinTrip: () => _showJoinTripDialog(context),
              ),
            ),

            // コンテンツ
            tripsAsync.when(
              data: (trips) {
                if (trips.isEmpty) {
                  return SliverFillRemaining(
                    child: EmptyState(
                      message: AppStrings.noTrips,
                      icon: Icons.luggage_outlined,
                      actionLabel: AppStrings.createFirstTrip,
                      action: () => _showCreateTripDialog(context, ref),
                      secondaryActionLabel: '旅に参加する',
                      secondaryAction: () => _showJoinTripDialog(context),
                    ),
                  );
                }

                final activeTrips =
                    trips
                        .where((t) => t.status != TripStatus.confirmed)
                        .toList();
                final pastTrips =
                    trips
                        .where((t) => t.status == TripStatus.confirmed)
                        .toList();

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // アクティブな旅行
                    ...activeTrips.asMap().entries.map(
                      (entry) => _AnimatedTripCard(
                        trip: entry.value,
                        index: entry.key,
                        onTap: () => _navigateToTrip(context, ref, entry.value),
                        onDelete: () => _deleteTrip(context, ref, entry.value),
                      ),
                    ),

                    // 過去の旅行
                    if (pastTrips.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.paddingL),
                      _SectionHeader(title: AppStrings.pastTrips),
                      ...pastTrips.asMap().entries.map(
                        (entry) => _AnimatedTripCard(
                          trip: entry.value,
                          index: entry.key + activeTrips.length,
                          onTap:
                              () => _navigateToTrip(context, ref, entry.value),
                          onDelete:
                              () => _deleteTrip(context, ref, entry.value),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSizes.paddingXXL),
                  ]),
                );
              },
              loading:
                  () => SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 3,
                          ),
                          SizedBox(height: AppSizes.paddingM),
                          Text(
                            AppStrings.loading,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
              error: (error, stack) {
                // コンソールにエラー出力
                debugPrint('❌ userTripsProvider error: $error');
                debugPrint('Stack trace: $stack');

                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.paddingL),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: AppSizes.paddingM),
                          Text(
                            AppStrings.networkError,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          // デバッグ用: 実際のエラーメッセージ
                          const SizedBox(height: AppSizes.paddingS),
                          Text(
                            error.toString(),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTripDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateTripSheet(),
    );
  }

  /// 入力値からトリップIDを抽出（URLが貼られた場合も対応）
  String _extractTripId(String input) {
    // URL形式の場合: https://trimee-ai.com/join/{tripId} or /join/{tripId}
    final urlMatch = RegExp(r'/join/([^/\s?#]+)').firstMatch(input);
    if (urlMatch != null) return urlMatch.group(1)!;
    return input;
  }

  void _showJoinTripDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          insetPadding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          title: Text('旅に参加する', style: AppTypography.titleMedium),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'メンバーから共有されたトリップIDを入力してください',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  decoration: InputDecoration(
                    hintText: 'トリップID',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                      vertical: AppSizes.paddingM,
                    ),
                  ),
                  onSubmitted: (value) {
                    final tripId = _extractTripId(value.trim());
                    if (tripId.isNotEmpty) {
                      Navigator.pop(ctx);
                      context.push('/join/$tripId');
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'キャンセル',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final tripId = _extractTripId(controller.text.trim());
                if (tripId.isNotEmpty) {
                  Navigator.pop(ctx);
                  context.push('/join/$tripId');
                }
              },
              child: Text(
                '参加する',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    ).then((_) => controller.dispose());
  }

  /// 旅程のステータスに応じて適切な画面に遷移
  Future<void> _navigateToTrip(
    BuildContext context,
    WidgetRef ref,
    TripModel trip,
  ) async {
    switch (trip.status) {
      case TripStatus.lobby:
        // ロビー画面へ
        context.go('/trip/${trip.id}/lobby');
        break;
      case TripStatus.collecting:
      case TripStatus.voting:
        // 編集中のプランがあれば直接編集画面へ
        if (trip.editingPlanId != null) {
          await _navigateToEditingPlan(context, ref, trip);
        } else if (trip.status == TripStatus.voting) {
          // 投票中はプラン画面へ
          context.go('/trip/${trip.id}/plan');
        } else {
          // カード集め中はカード画面へ
          context.go('/trip/${trip.id}');
        }
        break;
      case TripStatus.confirmed:
      case TripStatus.ongoing:
        // 確定済み/旅行中は確定プランの閲覧画面へ
        if (trip.confirmedPlanId != null) {
          // ローディング表示
          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingXL,
                      vertical: AppSizes.paddingL,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: AppSizes.paddingM),
                        Text(
                          'プランを読み込み中...',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          );

          try {
            // 確定プランを直接取得
            final confirmedPlan = await ref
                .read(planRepositoryProvider)
                .getPlan(trip.id, trip.confirmedPlanId!);

            // ローディングダイアログを閉じる
            if (context.mounted) {
              Navigator.of(context).pop();
            }

            if (confirmedPlan != null && context.mounted) {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      PlanViewScreen(
                        tripId: trip.id,
                        plan: confirmedPlan,
                        trip: trip,
                      ),
                  transitionDuration: const Duration(milliseconds: 300),
                  reverseTransitionDuration: const Duration(milliseconds: 250),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.3),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
                      child: FadeTransition(
                        opacity: CurveTween(curve: Curves.easeOut).animate(animation),
                        child: child,
                      ),
                    );
                  },
                ),
              );
              return;
            } else {
              // debugPrint('Confirmed plan is null!');
            }
          } catch (e) {
            // ローディングダイアログを閉じる
            if (context.mounted) {
              Navigator.of(context).pop();
            }
            debugPrint('Error loading confirmed plan: $e');
          }

          // 確定プランが見つからない場合はエラー表示してカード画面へ
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('確定プランの読み込みに失敗しました'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
              ),
            );
            // カード画面に遷移（プラン選択画面ではない）
            context.go('/trip/${trip.id}');
          }
        } else {
          // confirmedPlanIdがない場合（異常状態）
          debugPrint('Confirmed plan ID is null for trip: ${trip.id}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('確定プラン情報が見つかりません'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
              ),
            );
            context.go('/trip/${trip.id}');
          }
        }
        break;
    }
  }

  /// 編集中プランに直接遷移
  Future<void> _navigateToEditingPlan(
    BuildContext context,
    WidgetRef ref,
    TripModel trip,
  ) async {
    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingXL,
                vertical: AppSizes.paddingL,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  Text(
                    '編集中のプランを読み込み中...',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    try {
      final plans = await ref.read(tripPlansProvider(trip.id).future);
      final editingPlan =
          plans.where((p) => p.id == trip.editingPlanId).firstOrNull;

      // ローディングダイアログを閉じる
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (editingPlan != null && context.mounted) {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                PlanEditScreen(tripId: trip.id, plan: editingPlan),
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.3),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
                child: FadeTransition(
                  opacity: CurveTween(curve: Curves.easeOut).animate(animation),
                  child: child,
                ),
              );
            },
          ),
        );
        return;
      }
    } catch (e) {
      // ローディングダイアログを閉じる
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      debugPrint('Error loading editing plan: $e');
    }

    // 編集中プランが見つからない場合はフォールバック
    if (context.mounted) {
      if (trip.status == TripStatus.voting) {
        context.go('/trip/${trip.id}/plan');
      } else {
        context.go('/trip/${trip.id}');
      }
    }
  }

  Future<void> _deleteTrip(
    BuildContext context,
    WidgetRef ref,
    TripModel trip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            title: Text('旅行を削除', style: AppTypography.titleMedium),
            content: Text(
              '「${trip.title}」を削除しますか？\nこの操作は取り消せません。',
              style: AppTypography.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'キャンセル',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  '削除',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repo = ref.read(tripRepositoryProvider);
        await repo.deleteTrip(trip.id);
        ref.invalidate(userTripsProvider);
        if (context.mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「${trip.title}」を削除しました'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('削除に失敗しました'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          );
        }
      }
    }
  }
}

/// ホームヘッダー
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.onCreateTrip, required this.onJoinTrip});

  final VoidCallback onCreateTrip;
  final VoidCallback onJoinTrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final isLoggedIn = user != null;

    return Padding(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ロゴ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.appName, style: AppTypography.logoStyle),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  AppStrings.appTagline,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // アクションボタン
          _CreateTripButton(onTap: onCreateTrip),
          const SizedBox(width: AppSizes.paddingS),
          // メニューボタン
          _HeaderMenuButton(
            isLoggedIn: isLoggedIn,
            onSettings: () => _showSettingsSheet(context, ref),
            onLogin: () => context.go('/sign-in'),
            onJoin: onJoinTrip,
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SettingsSheet(),
    );

    // シートから「logout」が返された場合、確認ダイアログを表示
    if (result == 'logout' && context.mounted) {
      _confirmLogout(context, ref);
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            title: Text('ログアウト', style: AppTypography.titleMedium),
            content: Text('ログアウトしますか？', style: AppTypography.bodyMedium),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'キャンセル',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'ログアウト',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
      // GoRouterのrefreshListenableが認証状態変更を検知し、
      // redirectで自動的に/welcomeへ遷移する
    }
  }
}

/// ヘッダーメニューボタン
class _HeaderMenuButton extends StatelessWidget {
  const _HeaderMenuButton({
    required this.isLoggedIn,
    required this.onSettings,
    required this.onLogin,
    this.onJoin,
  });

  final bool isLoggedIn;
  final VoidCallback onSettings;
  final VoidCallback onLogin;
  final VoidCallback? onJoin;

  void _showMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + 4,
        overlay.size.width - offset.dx - button.size.width,
        0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      color: AppColors.cardBackground,
      items: [
        if (isLoggedIn) ...[
          PopupMenuItem(
            value: 'join',
            child: Row(
              children: [
                Icon(
                  Icons.group_add_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSizes.paddingS),
                Text('旅に参加する', style: AppTypography.bodyMedium),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'settings',
            child: Row(
              children: [
                Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSizes.paddingS),
                Text('設定', style: AppTypography.bodyMedium),
              ],
            ),
          ),
        ] else
          PopupMenuItem(
            value: 'login',
            child: Row(
              children: [
                Icon(
                  Icons.login_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSizes.paddingS),
                Text('ログイン', style: AppTypography.bodyMedium),
              ],
            ),
          ),
      ],
    );

    if (result == 'settings') {
      onSettings();
    } else if (result == 'login') {
      onLogin();
    } else if (result == 'join') {
      onJoin?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.cardBackground,
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Icon(
          Icons.menu_rounded,
          color: AppColors.textSecondary,
          size: 22,
        ),
      ),
    );
  }
}

/// 新規作成ボタン
class _CreateTripButton extends StatefulWidget {
  const _CreateTripButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CreateTripButton> createState() => _CreateTripButtonState();
}

class _CreateTripButtonState extends State<_CreateTripButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder:
            (context, child) =>
                Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingL,
            vertical: AppSizes.paddingM,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, Color(0xFFE07B4C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                '新しい旅',
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 設定シート
class _SettingsSheet extends ConsumerWidget {
  _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final isGuest = user == null || user.isAnonymous;
    final email = user?.email;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // タイトル
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSizes.paddingS),
                  Text('設定 / アカウント', style: AppTypography.titleMedium),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.paddingM),
            const Divider(height: 1),

            // アカウント情報
            if (isGuest)
              _SettingsMenuItem(
                icon: Icons.person_outline,
                label: 'ゲストユーザー',
                trailing: const SizedBox.shrink(),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingL,
                  vertical: AppSizes.paddingM,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_circle,
                      size: 40,
                      color: AppColors.accent.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: AppSizes.paddingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ログイン中',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            email?.isNotEmpty == true ? email! : '連携アカウント',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (!isGuest) const Divider(height: 1, indent: 56),

            // テーマ設定
            _SettingsMenuItem(
              icon: Icons.dark_mode_outlined,
              label: 'ダークモード',
              trailing: Switch.adaptive(
                value: ref.watch(themeModeProvider) == ThemeMode.dark,
                onChanged: (value) {
                  ref.read(themeModeProvider.notifier).toggleDarkMode(value);
                },
                activeColor: AppColors.accent,
              ),
            ),

            const Divider(height: 1, indent: 56),

            // ログアウト
            _SettingsMenuItem(
              icon: Icons.logout,
              label: 'ログアウト',
              color: Colors.redAccent,
              onTap: () => Navigator.pop(context, 'logout'),
            ),

            const SizedBox(height: AppSizes.paddingM),
          ],
        ),
      ),
    );
  }
}

/// 設定メニュー項目
class _SettingsMenuItem extends StatelessWidget {
  const _SettingsMenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingL,
          vertical: AppSizes.paddingS,
        ),
        child: Row(
          children: [
            Icon(icon, color: itemColor, size: 22),
            const SizedBox(width: AppSizes.paddingM),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(color: itemColor),
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// セクションヘッダー
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingL,
        vertical: AppSizes.paddingS,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSizes.paddingS),
          Text(
            title,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// アニメーション付き旅行カード
class _AnimatedTripCard extends StatefulWidget {
  const _AnimatedTripCard({
    required this.trip,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  final TripModel trip;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_AnimatedTripCard> createState() => _AnimatedTripCardState();
}

class _AnimatedTripCardState extends State<_AnimatedTripCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // 遅延してアニメーション開始（カスケード効果）
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _SwipeTripCard(
          trip: widget.trip,
          onTap: widget.onTap,
          onDelete: widget.onDelete,
        ),
      ),
    );
  }
}

/// LINE風スワイプ削除カード
class _SwipeTripCard extends StatefulWidget {
  const _SwipeTripCard({
    required this.trip,
    required this.onTap,
    required this.onDelete,
  });

  final TripModel trip;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_SwipeTripCard> createState() => _SwipeTripCardState();
}

class _SwipeTripCardState extends State<_SwipeTripCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  double _dragExtent = 0;
  static const double _deleteButtonWidth = 80;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dx).clamp(
        -_deleteButtonWidth,
        0,
      );
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300 || _dragExtent < -_deleteButtonWidth * 0.5) {
      _animateTo(-_deleteButtonWidth);
    } else {
      _animateTo(0);
    }
  }

  void _animateTo(double target) {
    _slideAnim = Tween<Offset>(
      begin: Offset(_dragExtent, 0),
      end: Offset(target, 0),
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _dragExtent = target);
      }
    });
  }

  void _resetSwipe() {
    _animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    // AppCardのデフォルトマージンに合わせる
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Stack(
          children: [
            // 背景の削除ボタン（右端に固定）
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _resetSwipe();
                      widget.onDelete();
                    },
                    child: Container(
                      width: _deleteButtonWidth,
                      decoration: const BoxDecoration(color: Colors.redAccent),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(height: 2),
                          Text(
                            '削除',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // メインカード（スライド）
            AnimatedBuilder(
              animation: _slideController,
              builder: (context, child) {
                final offset =
                    _slideController.isAnimating
                        ? _slideAnim.value
                        : Offset(_dragExtent, 0);
                return Transform.translate(offset: offset, child: child);
              },
              child: GestureDetector(
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                child: _TripCard(
                  trip: widget.trip,
                  onTap: widget.onTap,
                  margin: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 旅行カード
class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap, this.margin});

  final TripModel trip;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      margin: margin,
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上部: タイトルと日程
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 旅行タイプアイコン
              TripTypeIcon(title: trip.title, size: 48),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title,
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.paddingXS),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trip.formattedDateRange,
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ステータスインジケーター
              if (trip.status == TripStatus.confirmed)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.subAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.subAccent,
                    size: 16,
                  ),
                ),
            ],
          ),

          SizedBox(height: AppSizes.paddingM),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSizes.paddingM),

          // 下部: メンバーとステータス
          Row(
            children: [
              // メンバーアバター（イニシャル表示）
              _TripMemberAvatars(trip: trip),
              const Spacer(),
              // ステータスバッジ
              if (trip.status != TripStatus.confirmed)
                _StatusBadge(status: trip.status),
            ],
          ),
        ],
      ),
    );
  }
}

/// メンバーアバター表示（ホーム画面トリップカード用）
class _TripMemberAvatars extends StatelessWidget {
  const _TripMemberAvatars({required this.trip});

  final TripModel trip;

  static const _avatarColors = [
    Color(0xFF4285F4),
    Color(0xFF34A853),
    Color(0xFFFBBC05),
    Color(0xFFEA4335),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF9800),
  ];

  @override
  Widget build(BuildContext context) {
    final members = trip.memberDetails.values.toList();
    if (members.isEmpty) {
      // memberDetailsがない場合はmembersの数だけ表示
      return Text('${trip.members.length}人', style: AppTypography.caption);
    }

    const maxShow = 4;
    final showMembers = members.take(maxShow).toList();
    final extraCount = members.length - maxShow;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: showMembers.length * 18.0 + 8 + (extraCount > 0 ? 18.0 : 0),
          height: 26,
          child: Stack(
            children: [
              for (var i = 0; i < showMembers.length; i++)
                Positioned(
                  left: i * 16.0,
                  child: _TripAvatarCircle(
                    name: showMembers[i].displayName,
                    color: _avatarColors[i % _avatarColors.length],
                  ),
                ),
              if (extraCount > 0)
                Positioned(
                  left: showMembers.length * 16.0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '+$extraCount',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// アバターサークル（ホーム画面トリップカード用）
class _TripAvatarCircle extends StatelessWidget {
  const _TripAvatarCircle({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.background, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// ステータスバッジ
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TripStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TripStatus.lobby => ('メンバー待ち', AppColors.textSecondary),
      TripStatus.collecting => ('カード集め中', AppColors.accent),
      TripStatus.voting => (AppStrings.votePending, AppColors.subAccent),
      TripStatus.confirmed => ('確定', AppColors.subAccent),
      TripStatus.ongoing => ('旅行中', AppColors.subAccent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingS,
        vertical: AppSizes.paddingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 旅行作成シート（2ステップ: 旅の情報 → あなたの情報）
class _CreateTripSheet extends ConsumerStatefulWidget {
  const _CreateTripSheet();

  @override
  ConsumerState<_CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends ConsumerState<_CreateTripSheet> {
  final _titleController = TextEditingController();
  final _nameController = TextEditingController();
  final _departureController = TextEditingController();
  final _departureFocus = FocusNode();
  DateTimeRange? _dateRange;
  bool _isDateUndecided = false;
  bool _isLoading = false;
  bool _showSuccess = false;
  int _currentStep = 0; // 0 = 旅の情報, 1 = あなたの情報

  @override
  void initState() {
    super.initState();
    // 既存の名前があればプリセット
    final existingName = ref.read(guestNameProvider);
    if (existingName != null && existingName.isNotEmpty) {
      _nameController.text = existingName;
    }
    final session = ref.read(guestSessionProvider);
    if (session?.departurePoint != null) {
      _departureController.text = session!.departurePoint!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _nameController.dispose();
    _departureController.dispose();
    _departureFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSizes.paddingL,
          right: AppSizes.paddingL,
          top: AppSizes.paddingM,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.paddingL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ハンドル
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),

            // 成功表示
            if (_showSuccess)
              _buildSuccessState()
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.15, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    ),
                  );
                },
                child: _currentStep == 0
                    ? _buildStepOne(key: const ValueKey(0))
                    : _buildStepTwo(key: const ValueKey(1)),
              ),
          ],
        ),
      ),
    );
  }

  /// ステップ1: 旅の情報（タイトル・日程）
  Widget _buildStepOne({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // タイトル
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: const Icon(
                Icons.flight_takeoff_rounded,
                color: AppColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSizes.paddingS),
            Text(AppStrings.newTrip, style: AppTypography.headlineSmall),
          ],
        ),
        const SizedBox(height: AppSizes.paddingXS),
        Text(
          'メンバーの希望を集めて旅を計画',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.paddingL),

        // 旅行タイトル入力
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: AppStrings.tripTitle,
            hintText: AppStrings.tripTitleHint,
            prefixIcon: Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _goToStepTwo(),
        ),
        const SizedBox(height: AppSizes.paddingM),

        // 日程オプション
        InkWell(
          onTap: () {
            setState(() {
              _isDateUndecided = !_isDateUndecided;
              if (_isDateUndecided) _dateRange = null;
            });
          },
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSizes.paddingS,
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color:
                        _isDateUndecided
                            ? AppColors.accent
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color:
                          _isDateUndecided
                              ? AppColors.accent
                              : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child:
                      _isDateUndecided
                          ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                          : null,
                ),
                const SizedBox(width: AppSizes.paddingM),
                Text(
                  AppStrings.tripDateUndecided,
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ),

        // 日程選択
        if (!_isDateUndecided) ...[
          const SizedBox(height: AppSizes.paddingS),
          OutlinedButton.icon(
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                saveText: '決定',
                initialEntryMode: DatePickerEntryMode.calendarOnly,
              );
              if (range != null) {
                setState(() => _dateRange = range);
              }
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              _dateRange != null
                  ? '${_dateRange!.start.month}/${_dateRange!.start.day} - ${_dateRange!.end.month}/${_dateRange!.end.day}'
                  : '日程を選択',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],

        const SizedBox(height: AppSizes.paddingL),

        // 次へボタン
        ElevatedButton(
          onPressed: () => _goToStepTwo(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            minimumSize: const Size.fromHeight(52),
          ),
          child: Text(
            '次へ',
            style: AppTypography.button.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: AppSizes.paddingS),
      ],
    );
  }

  /// ステップ2: あなたの情報（名前・出発地点）
  Widget _buildStepTwo({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ヘッダー（戻るボタン付き）
        Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _currentStep = 0);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.paddingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'あなたのことを教えてください',
                    style: AppTypography.headlineSmall,
                  ),
                  Text(
                    'メンバーに表示される情報です',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.paddingL),

        // 名前入力
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'ニックネーム',
            hintText: '例: たろう',
            prefixIcon: Icon(
              Icons.person_outline,
              color: AppColors.textSecondary,
            ),
          ),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _departureFocus.requestFocus(),
          autofocus: true,
        ),
        const SizedBox(height: AppSizes.paddingM),

        // 出発地点入力
        TextField(
          controller: _departureController,
          focusNode: _departureFocus,
          decoration: InputDecoration(
            labelText: '出発地点',
            hintText: '例: 東京駅、新宿など',
            prefixIcon: Icon(
              Icons.location_on_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _createTrip(),
        ),
        const SizedBox(height: AppSizes.paddingXS),
        Text(
          '※ AIが交通費や移動時間を考慮したプランを作成します',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),

        const SizedBox(height: AppSizes.paddingL),

        // 旅を始めるボタン
        ElevatedButton(
          onPressed: _isLoading ? null : () => _createTrip(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            minimumSize: const Size.fromHeight(52),
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text(
                    '旅を始める',
                    style: AppTypography.button.copyWith(
                      color: Colors.white,
                    ),
                  ),
        ),
        const SizedBox(height: AppSizes.paddingS),
      ],
    );
  }

  /// 成功表示
  Widget _buildSuccessState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingXL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SuccessCheckAnimation(size: 64),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            '旅を作成しました!',
            style: AppTypography.titleMedium,
          ),
        ],
      ),
    );
  }

  void _goToStepTwo() {
    HapticFeedback.lightImpact();
    setState(() => _currentStep = 1);
  }

  /// ユーザー情報を保存（name_input_dialog.dart と同じパターン）
  void _saveUserInfo(String name, String? departure) {
    ref.read(guestSessionProvider.notifier).setUserInfo(
      name: name,
      departurePoint: departure,
    );

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
  }

  Future<void> _createTrip() async {
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

    var title = _titleController.text.trim();
    if (title.isEmpty) {
      title = '新しい旅';
    }

    final departure = _departureController.text.trim();
    _saveUserInfo(name, departure.isNotEmpty ? departure : null);

    setState(() => _isLoading = true);

    try {
      final tripId = await ref
          .read(tripControllerProvider.notifier)
          .createTrip(
            title: title,
            startDate: _dateRange?.start,
            endDate: _dateRange?.end,
            ownerName: name,
            ownerDeparture: departure.isNotEmpty ? departure : null,
          );

      if (mounted) {
        if (tripId != null) {
          // 成功アニメーション表示
          setState(() => _showSuccess = true);
          HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) {
            Navigator.of(context).pop();
            if (context.mounted) {
              context.go('/trip/$tripId/lobby');
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('旅行の作成に失敗しました'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
