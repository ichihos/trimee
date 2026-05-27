import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/ad_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../../shared/models/trip_model.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/trip_image_picker.dart';
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
      bottomNavigationBar: kIsWeb ? null : const _BannerAdWidget(),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ヘッダー
            SliverToBoxAdapter(
              child: _HomeHeader(
                onCreateTrip: () => _showCreateTripDialog(context, ref),
                onShareTrip: () => _showShareTripPicker(context, ref),
                onShareApp: () => _shareApp(context),
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
                    ),
                  );
                }

                final activeTrips =
                    trips
                        .where((t) => t.planId == null || t.endDate == null || t.endDate!.isAfter(DateTime.now()))
                        .toList();
                final pastTrips =
                    trips
                        .where((t) => t.planId != null && t.endDate != null && t.endDate!.isBefore(DateTime.now()))
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

  Future<void> _showCreateTripDialog(BuildContext context, WidgetRef ref) async {
    final method = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                      child: const Icon(Icons.flight_takeoff_rounded, color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: AppSizes.paddingS),
                    Text(AppStrings.newTrip, style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.paddingXS),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
                child: Text(
                  'しおりの作り方を選んでください',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
                child: Row(
                  children: [
                    Expanded(
                      child: _CreateMethodCard(
                        icon: Icons.edit_outlined,
                        label: '手動で作成',
                        subtitle: '予定をひとつずつ追加',
                        onTap: () => Navigator.pop(ctx, 'manual'),
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingM),
                    Expanded(
                      child: _CreateMethodCard(
                        icon: Icons.photo_camera_outlined,
                        label: '画像から読み取り',
                        subtitle: '写真やスクショから',
                        onTap: () => Navigator.pop(ctx, 'image'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),
            ],
          ),
        ),
      ),
    );

    if (method == null || !context.mounted) return;

    try {
      final tripId = await ref
          .read(tripControllerProvider.notifier)
          .createTrip(title: '');

      if (tripId == null || !context.mounted) return;

      final planId = await ref
          .read(planControllerProvider.notifier)
          .createPlan(tripId: tripId, title: '');

      if (planId == null || !context.mounted) return;

      final plan = await ref
          .read(planRepositoryProvider)
          .getPlan(tripId, planId);

      if (plan != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlanEditScreen(
              tripId: tripId,
              plan: plan,
              autoImportImage: method == 'image',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating trip: $e');
    }
  }

  void _showShareTripPicker(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.read(userTripsProvider);
    final trips = tripsAsync.valueOrNull ?? [];
    final tripsWithPlan = trips.where((t) => t.planId != null).toList();

    if (tripsWithPlan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('共有できるしおりがありません'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
                child: Row(
                  children: [
                    Icon(Icons.ios_share, color: AppColors.accent, size: 22),
                    const SizedBox(width: AppSizes.paddingS),
                    Text('共有するしおりを選択', style: AppTypography.titleMedium),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.paddingM),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tripsWithPlan.length,
                  itemBuilder: (ctx, i) {
                    final trip = tripsWithPlan[i];
                    final iconName = trip.imageUrl?.startsWith('icon:') == true
                        ? trip.imageUrl!.substring(5)
                        : TripIconAssets.fromTitle(trip.title);
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          TripIconAssets.path(iconName),
                          width: 44, height: 44, fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        trip.title.isNotEmpty ? trip.title : TripIconAssets.displayName(iconName),
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: trip.startDate != null
                          ? Text(trip.formattedDateRange, style: AppTypography.caption)
                          : null,
                      trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                      onTap: () {
                        Navigator.pop(ctx);
                        _navigateToPlan(context, ref, trip);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareApp(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    Share.share(
      'trimee - 計画から、旅ははじまる\n旅の計画をもっと楽しく！\nhttps://apps.apple.com/app/trimee/id6744187498',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// しおりの適切な画面に遷移
  Future<void> _navigateToTrip(
    BuildContext context,
    WidgetRef ref,
    TripModel trip,
  ) async {
    if (trip.planId != null) {
      // プランが存在する場合 → 読み込んで編集/閲覧画面へ
      _navigateToPlan(context, ref, trip);
    } else {
      // プランがない場合 → 新規作成して編集画面へ
      _createAndNavigateToPlan(context, ref, trip);
    }
  }

  /// 既存プランを読み込んで遷移
  Future<void> _navigateToPlan(
    BuildContext context,
    WidgetRef ref,
    TripModel trip,
  ) async {
    try {
      final plan = await ref
          .read(planRepositoryProvider)
          .getPlan(trip.id, trip.planId!);

      if (plan != null && context.mounted) {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                PlanViewScreen(
                  tripId: trip.id,
                  plan: plan,
                  tripTitle: trip.title,
                  startDate: trip.startDate,
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
      }
    } catch (e) {
      debugPrint('Error loading plan: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('しおりの読み込みに失敗しました'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
          ),
        );
      }
    }
  }

  /// 新規プランを作成して遷移
  Future<void> _createAndNavigateToPlan(
    BuildContext context,
    WidgetRef ref,
    TripModel trip,
  ) async {
    try {
      final planId = await ref
          .read(planControllerProvider.notifier)
          .createPlan(
            tripId: trip.id,
            title: trip.title,
          );

      if (planId != null && context.mounted) {
        final plan = await ref
            .read(planRepositoryProvider)
            .getPlan(trip.id, planId);
        if (plan != null && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlanEditScreen(
                tripId: trip.id,
                plan: plan,
                tripTitle: trip.title,
                startDate: trip.startDate,
                endDate: trip.endDate,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating plan: $e');
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
  const _HomeHeader({
    required this.onCreateTrip,
    required this.onShareTrip,
    required this.onShareApp,
  });

  final VoidCallback onCreateTrip;
  final VoidCallback onShareTrip;
  final VoidCallback onShareApp;

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
            onShareTrip: onShareTrip,
            onShareApp: onShareApp,
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
    required this.onShareTrip,
    required this.onShareApp,
  });

  final bool isLoggedIn;
  final VoidCallback onSettings;
  final VoidCallback onLogin;
  final VoidCallback onShareTrip;
  final VoidCallback onShareApp;

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
            value: 'share_trip',
            child: Row(
              children: [
                Icon(
                  Icons.ios_share,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSizes.paddingS),
                Text('しおりを共有する', style: AppTypography.bodyMedium),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'share_app',
            child: Row(
              children: [
                Icon(
                  Icons.favorite_outline,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSizes.paddingS),
                Text('アプリをシェアする', style: AppTypography.bodyMedium),
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
    } else if (result == 'share_trip') {
      onShareTrip();
    } else if (result == 'share_app') {
      onShareApp();
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
class _TripCard extends ConsumerWidget {
  const _TripCard({required this.trip, required this.onTap, this.margin});

  final TripModel trip;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? margin;

  void _showImagePicker(BuildContext context, WidgetRef ref) {
    showTripImagePicker(context, tripId: trip.id, currentImageUrl: trip.imageUrl);
  }

  String _fallbackTitle(TripModel trip) {
    final imageUrl = trip.imageUrl;
    if (imageUrl != null && imageUrl.startsWith('icon:')) {
      return TripIconAssets.displayName(imageUrl.substring(5));
    }
    return TripIconAssets.displayName(TripIconAssets.fromTitle(trip.title));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: onTap,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM, vertical: AppSizes.paddingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => _showImagePicker(context, ref),
            child: _TripCoverImage(trip: trip),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.title.isNotEmpty
                      ? trip.title
                      : _fallbackTitle(trip),
                  style: AppTypography.titleMedium.copyWith(
                    color: trip.title.isNotEmpty
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (trip.startDate != null) ...[
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
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            size: 22,
          ),
        ],
      ),
    );
  }
}

/// カバー画像 or デフォルトアイコン
class _TripCoverImage extends StatelessWidget {
  const _TripCoverImage({required this.trip});
  final TripModel trip;

  static const _size = 96.0;
  static const _radius = 20.0;

  @override
  Widget build(BuildContext context) {
    final imageUrl = trip.imageUrl;

    // カスタム写真が設定されている場合
    if (imageUrl != null && imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Image.network(
          imageUrl,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildAssetIcon(),
        ),
      );
    }

    // アイコン名が設定されている場合（icon:beach 等）
    if (imageUrl != null && imageUrl.startsWith('icon:')) {
      final name = imageUrl.substring(5);
      return ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Image.asset(
          TripIconAssets.path(name),
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildAssetIcon(),
        ),
      );
    }

    // 未設定 → タイトルから推定したアセットアイコン
    return _buildAssetIcon();
  }

  Widget _buildAssetIcon() {
    final iconName = TripIconAssets.fromTitle(trip.title);
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: Image.asset(
        TripIconAssets.path(iconName),
        width: _size,
        height: _size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// バナー広告ウィジェット
class _BannerAdWidget extends StatefulWidget {
  const _BannerAdWidget();

  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();

    return Container(
      color: AppColors.background,
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// 作成方法カード（手動 / 画像読み取り）
class _CreateMethodCard extends StatelessWidget {
  const _CreateMethodCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingM,
          vertical: AppSizes.paddingL,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.accent, size: 24),
            ),
            const SizedBox(height: AppSizes.paddingS),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
