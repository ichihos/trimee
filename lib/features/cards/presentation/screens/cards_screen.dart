import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/models/card_model.dart';
import '../../../../shared/models/plan_model.dart';
import '../../../../shared/models/trip_member_model.dart';
import '../../../../shared/models/trip_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/name_input_dialog.dart';
import '../../../plan/presentation/providers/plan_provider.dart';
import '../../../trip/presentation/providers/trip_provider.dart';
import '../providers/card_provider.dart';

import '../../../../shared/widgets/chat_overlay.dart';

/// カード集め画面
class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  bool _hasCheckedName = false;
  bool _hasShownInitialAddSheet = false;

  @override
  void initState() {
    super.initState();
    // ユーザー情報チェックを次のフレームで実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserInfo();
    });
  }

  Future<void> _checkUserInfo() async {
    if (_hasCheckedName) return;

    // 子ルート（lobby等）が表示中の場合はスキップ（lobbyで別途チェックされる）
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    _hasCheckedName = true;

    // 既存のメンバー詳細をチェック
    final tripAsync = ref.read(tripDetailProvider(widget.tripId));
    final trip = tripAsync.valueOrNull;
    final userId = ref.read(currentUserIdProvider);

    bool needsUserInfo = true;
    if (userId != null && trip != null) {
      final existingMember = trip.memberDetails[userId];
      if (existingMember != null && existingMember.displayName.isNotEmpty) {
        needsUserInfo = false;
      }
    }

    if (needsUserInfo) {
      final result = await collectUserInfo(context, ref);
      if (result == null && mounted) {
        context.go('/');
        return;
      }

      if (result != null && userId != null && mounted) {
        final member = TripMember(
          userId: userId,
          displayName: result.name,
          departurePoint: result.departurePoint,
          joinedAt: DateTime.now(),
        );
        await ref
            .read(tripControllerProvider.notifier)
            .updateMemberDetails(widget.tripId, userId, member);
      }
    }

    // ユーザー情報入力後に追加シートを自動表示
    if (mounted && !_hasShownInitialAddSheet) {
      _hasShownInitialAddSheet = true;
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        final currentRoute = ModalRoute.of(context);
        if (currentRoute != null && currentRoute.isCurrent) {
          _showAddCardSheet(context, ref);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // lobby等の子ルートから戻った時にユーザー情報チェックを再実行
    if (!_hasCheckedName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkUserInfo();
      });
    }

    final cardsAsync = ref.watch(tripCardsProvider(widget.tripId));
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));

    // 当日モードかどうかを確認
    final trip = tripAsync.valueOrNull;
    final isOngoing = trip?.status == TripStatus.ongoing;

    // 当日モードの場合は専用UIを表示
    if (isOngoing) {
      return _OngoingModeScreen(tripId: widget.tripId, trip: trip!);
    }

    final cardCount = cardsAsync.maybeWhen(
      data: (cards) => cards.length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ChatOverlay(
        tripId: widget.tripId,
        child: SafeArea(
          child: Column(
            children: [
              // ヘッダー
              _CardsHeader(
                tripId: widget.tripId,
                onInvite: () => _showInviteSheet(context),
              ),

              // ステップガイド
              _StepIndicator(cardCount: cardCount),

              // カード一覧
              Expanded(
                child: cardsAsync.when(
                  data: (cards) {
                    if (cards.isEmpty) {
                      return EmptyState(
                        message: '旅の希望や決まっていることを\n追加しましょう',
                        icon: Icons.style_outlined,
                        actionLabel: '追加する',
                        action: () => _showAddCardSheet(context, ref),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(
                        top: AppSizes.paddingS,
                        bottom: 100,
                      ),
                      itemCount: cards.length + 1,
                      itemBuilder: (context, index) {
                        if (index == cards.length) {
                          return _AddCardButton(
                            onTap: () => _showAddCardSheet(context, ref),
                          );
                        }
                        return _AnimatedCardItem(
                          card: cards[index],
                          tripId: widget.tripId,
                          index: index,
                        );
                      },
                    );
                  },
                  loading:
                      () => Center(
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
                  error: (error, stack) => Center(child: Text('エラー: $error')),
                ),
              ),
            ],
          ),
        ),
      ),

      // フローティングボタン: AIプラン生成
      floatingActionButton: _GeneratePlanFAB(tripId: widget.tripId),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showInviteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _InviteSheet(tripId: widget.tripId),
    );
  }

  void _showAddCardSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddCardSheet(tripId: widget.tripId),
    );
  }
}

/// ステップガイド
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.cardCount});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    final isReady = cardCount >= 3;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // ステップ1
          _StepDot(number: 1, isActive: true, isDone: isReady),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '希望を集める',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // 矢印
          Icon(
            Icons.chevron_right,
            size: 16,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 4),
          // ステップ2
          _StepDot(number: 2, isActive: false, isDone: false),
          const SizedBox(width: 6),
          Text(
            'AIがプラン作成',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (isReady) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_circle, size: 14, color: AppColors.accent),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.number,
    required this.isActive,
    required this.isDone,
  });

  final int number;
  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color:
            isActive
                ? AppColors.accent
                : AppColors.border.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// ヘッダー
class _CardsHeader extends ConsumerWidget {
  const _CardsHeader({required this.tripId, required this.onInvite});

  final String tripId;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripDetailProvider(tripId));
    final trip = tripAsync.valueOrNull;

    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Row(
        children: [
          // 戻るボタン
          IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.paddingM),

          // タイトル
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.everyonesWishlist,
                  style: AppTypography.titleMedium,
                ),
                Text('まずは気になる場所をひとつ', style: AppTypography.caption),
              ],
            ),
          ),

          // メンバーアバター一覧
          if (trip != null)
            GestureDetector(onTap: onInvite, child: _MemberAvatars(trip: trip)),

          const SizedBox(width: AppSizes.paddingS),

          // 招待ボタン
          IconButton(
            onPressed: onInvite,
            icon: const Icon(Icons.person_add_outlined, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// メンバーアバター表示（Googleスプシ風）
class _MemberAvatars extends StatelessWidget {
  const _MemberAvatars({required this.trip});

  final TripModel trip;

  static const _avatarColors = [
    Color(0xFF4285F4), // Blue
    Color(0xFF34A853), // Green
    Color(0xFFFBBC05), // Yellow
    Color(0xFFEA4335), // Red
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF9800), // Orange
  ];

  @override
  Widget build(BuildContext context) {
    final members = trip.memberDetails.values.toList();
    if (members.isEmpty) return const SizedBox.shrink();

    // 最大表示数
    const maxShow = 4;
    final showMembers = members.take(maxShow).toList();
    final extraCount = members.length - maxShow;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: showMembers.length * 24.0 + 8,
          height: 32,
          child: Stack(
            children: [
              for (var i = 0; i < showMembers.length; i++)
                Positioned(
                  left: i * 20.0,
                  child: _AvatarCircle(
                    name: showMembers[i].displayName,
                    color: _avatarColors[i % _avatarColors.length],
                  ),
                ),
              if (extraCount > 0)
                Positioned(
                  left: showMembers.length * 20.0,
                  child: Container(
                    width: 32,
                    height: 32,
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
                          fontSize: 10,
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

/// アバターサークル
class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      width: 32,
      height: 32,
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// アニメーション付きカードアイテム
class _AnimatedCardItem extends StatefulWidget {
  const _AnimatedCardItem({
    required this.card,
    required this.tripId,
    required this.index,
  });

  final CardModel card;
  final String tripId;
  final int index;

  @override
  State<_AnimatedCardItem> createState() => _AnimatedCardItemState();
}

class _AnimatedCardItemState extends State<_AnimatedCardItem>
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

    Future.delayed(Duration(milliseconds: widget.index * 80), () {
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
        child: _CardItem(card: widget.card, tripId: widget.tripId),
      ),
    );
  }
}

/// カードアイテム
class _CardItem extends ConsumerStatefulWidget {
  const _CardItem({required this.card, required this.tripId});

  final CardModel card;
  final String tripId;

  @override
  ConsumerState<_CardItem> createState() => _CardItemState();
}

class _CardItemState extends ConsumerState<_CardItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _floatAnimation = Tween<double>(
      begin: 0,
      end: -4,
    ).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  void _onLike() {
    if (widget.card.cardType.isConfirmed) return;
    HapticFeedback.lightImpact();
    _floatController.forward().then((_) => _floatController.reverse());
    ref
        .read(cardControllerProvider.notifier)
        .react(
          tripId: widget.tripId,
          cardId: widget.card.id,
          reaction: ReactionType.up,
        );
  }

  Future<void> _deleteCard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            title: Text('カードを削除', style: AppTypography.titleMedium),
            content: Text(
              '「${widget.card.title}」を削除しますか？\nこの操作は取り消せません。',
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

    if (confirmed == true && mounted) {
      await ref
          .read(cardControllerProvider.notifier)
          .deleteCard(tripId: widget.tripId, cardId: widget.card.id);
    }
  }

  /// 投稿者名を取得
  String _getCreatorName(WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    if (widget.card.createdBy == currentUserId) {
      return 'あなた';
    }
    return 'メンバー';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';
    final currentReaction = widget.card.reactions[currentUserId];
    final isLiked = currentReaction == ReactionType.up;
    final likeCount = widget.card.upCount;
    final isNegative = widget.card.cardType.isNegative;
    final isConfirmed = widget.card.cardType.isConfirmed;
    final accentColor =
        isConfirmed
            ? AppColors.subAccent
            : isNegative
            ? AppColors.error
            : AppColors.accent;
    final isOwnCard = widget.card.createdBy == currentUserId;

    return AnimatedBuilder(
      animation: _floatAnimation,
      builder:
          (context, child) => Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: child,
          ),
      child: Dismissible(
        key: ValueKey(widget.card.id),
        direction:
            isOwnCard ? DismissDirection.endToStart : DismissDirection.none,
        confirmDismiss: (_) async {
          await _deleteCard();
          return false; // deleteCard handles deletion, don't auto-dismiss
        },
        background: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingM,
            vertical: AppSizes.paddingXS,
          ),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: GestureDetector(
          onLongPress: isOwnCard ? _deleteCard : null,
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingM,
              vertical: AppSizes.paddingXS,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              border: Border.all(
                color:
                    isLiked && !isConfirmed
                        ? AppColors.reactionUp.withValues(alpha: 0.4)
                        : AppColors.border.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Row(
                children: [
                  // 左: アイコン
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: Center(
                      child: Text(
                        widget.card.cardType.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingM),

                  // 中央: テキスト情報
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // タイトル
                        Text(
                          widget.card.title,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // 投稿者 & カテゴリ
                        Row(
                          children: [
                            Text(
                              widget.card.anonymous
                                  ? AppStrings.anonymous
                                  : _getCreatorName(ref),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 6),
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.textSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              widget.card.cardType.label,
                              style: AppTypography.caption.copyWith(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 右: いいねボタン（決まっていることカードでは非表示）
                  if (!isConfirmed)
                    GestureDetector(
                      onTap: _onLike,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isLiked
                                  ? AppColors.reactionUp.withValues(alpha: 0.12)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                          border: Border.all(
                            color:
                                isLiked
                                    ? AppColors.reactionUp
                                    : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color:
                                  isLiked
                                      ? AppColors.reactionUp
                                      : AppColors.textSecondary,
                            ),
                            if (likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$likeCount',
                                style: AppTypography.labelSmall.copyWith(
                                  color:
                                      isLiked
                                          ? AppColors.reactionUp
                                          : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// カード追加ボタン
class _AddCardButton extends StatelessWidget {
  const _AddCardButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.border,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Text(
                AppStrings.addCard,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AIプラン生成FAB
class _GeneratePlanFAB extends ConsumerWidget {
  const _GeneratePlanFAB({required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(tripCardsProvider(tripId));
    final cardCount = cardsAsync.maybeWhen(
      data: (cards) => cards.length,
      orElse: () => 0,
    );

    void onPressed() {
      if (cardCount < 3) {
        // 3枚未満の場合は警告ダイアログを表示
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Row(
                  children: [
                    const AppIcon(type: AppIconType.idea, size: 28),
                    const SizedBox(width: 8),
                    const Text('カードを追加してください'),
                  ],
                ),
                content: Text(
                  '現在$cardCount枚のカードが登録されています。\n\nプラン生成には3枚以上のカードが必要です。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      } else {
        context.go('/trip/$tripId/plan');
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
      width: double.infinity,
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text(
          AppStrings.generatePlan,
          style: AppTypography.button.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

const _uuid = Uuid();

/// 招待シート
class _InviteSheet extends ConsumerWidget {
  const _InviteSheet({required this.tripId});

  final String tripId;

  Future<void> _showAddManualMemberDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();
    final departureController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (dialogContext) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
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
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  TextField(
                    controller: departureController,
                    decoration: const InputDecoration(
                      labelText: '出発地点（任意）',
                      hintText: '例: 東京駅',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
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
                                const SnackBar(content: Text('名前を入力してください')),
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
    );

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

/// カード追加シート
class _AddCardSheet extends ConsumerStatefulWidget {
  const _AddCardSheet({required this.tripId});

  final String tripId;

  @override
  ConsumerState<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<_AddCardSheet> {
  final _titleController = TextEditingController();
  CardType _selectedCardType = CardType.confirmed;
  bool _isAnonymous = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
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

          // タイトル
          Row(
            children: [
              Text(
                _selectedCardType.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: AppSizes.paddingS),
              Text(_selectedCardType.hint, style: AppTypography.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),

          // カードタイプ選択
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  CardType.values.map((type) {
                    final isSelected = _selectedCardType == type;
                    final color =
                        type.isNegative
                            ? AppColors.error
                            : type.isConfirmed
                            ? const Color(0xFF4CAF50)
                            : AppColors.accent;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSizes.paddingS),
                      child: ChoiceChip(
                        label: Text('${type.emoji} ${type.label}'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCardType = type);
                          }
                        },
                        selectedColor: color.withValues(alpha: 0.2),
                        checkmarkColor: color,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: isSelected ? color : AppColors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),

          // 入力フィールド
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: _getHintText(),
              prefixIcon: Icon(_getIcon(), color: AppColors.textSecondary),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addCard(),
          ),
          const SizedBox(height: AppSizes.paddingM),

          // 匿名オプション
          InkWell(
            onTap: () => setState(() => _isAnonymous = !_isAnonymous),
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingS),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color:
                          _isAnonymous ? AppColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            _isAnonymous ? AppColors.accent : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child:
                        _isAnonymous
                            ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                            : null,
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppStrings.anonymous}で投稿',
                        style: AppTypography.bodyMedium,
                      ),
                      Text('誰が投稿したかわからなくなります', style: AppTypography.caption),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSizes.paddingL),

          // 追加ボタン
          ElevatedButton(
            onPressed: _isLoading ? null : _addCard,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _selectedCardType.isNegative
                      ? AppColors.error
                      : AppColors.accent,
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
                      '追加する',
                      style: AppTypography.button.copyWith(color: Colors.white),
                    ),
          ),
        ],
      ),
    );
  }

  String _getHintText() {
    // ざっくりした入力でもOKなことが伝わるヒント
    return switch (_selectedCardType) {
      CardType.confirmed => '例: 飛行機は予約済み、宿は○○ホテル',
      CardType.place => '例: 関西、海が見えるところ、京都',
      CardType.activity => '例: お酒飲みたい、のんびりしたい、温泉',
      CardType.atmosphere => '例: ゆっくり寝たい、写真いっぱい撮りたい',
      CardType.budget => '例: できるだけ安く、1人2万円くらい',
      CardType.avoidPlace => '例: 人混み、観光地っぽいとこ',
      CardType.avoidActivity => '例: 早起き、長時間移動',
    };
  }

  IconData _getIcon() {
    return switch (_selectedCardType) {
      CardType.confirmed => Icons.check_circle_outline,
      CardType.place => Icons.place_outlined,
      CardType.activity => Icons.sports_outlined,
      CardType.atmosphere => Icons.auto_awesome_outlined,
      CardType.budget => Icons.savings_outlined,
      CardType.avoidPlace => Icons.wrong_location_outlined,
      CardType.avoidActivity => Icons.do_not_disturb_outlined,
    };
  }

  Future<void> _addCard() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(cardControllerProvider.notifier)
          .createCard(
            tripId: widget.tripId,
            title: title,
            cardType: _selectedCardType,
            anonymous: _isAnonymous,
          );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// 旅行当日モード画面
class _OngoingModeScreen extends ConsumerWidget {
  const _OngoingModeScreen({required this.tripId, required this.trip});

  final String tripId;
  final TripModel trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(tripPlansProvider(tripId));

    // 確定されたプランを取得
    final confirmedPlan = plansAsync.whenOrNull(
      data:
          (plans) =>
              plans.where((p) => p.id == trip.confirmedPlanId).firstOrNull,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ヘッダー
            _OngoingHeader(trip: trip),

            // コンテンツ
            Expanded(
              child:
                  confirmedPlan != null
                      ? _OngoingContent(plan: confirmedPlan, trip: trip)
                      : const Center(child: Text('プランが見つかりません')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 当日モードヘッダー
class _OngoingHeader extends StatelessWidget {
  const _OngoingHeader({required this.trip});

  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 旅行中バッジ
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, Color(0xFFD4896E)],
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.flight_takeoff,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '旅行中',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trip.title,
                  style: AppTypography.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 当日モードコンテンツ
class _OngoingContent extends StatelessWidget {
  const _OngoingContent({required this.plan, required this.trip});

  final PlanModel plan;
  final TripModel trip;

  int _getCurrentDay() {
    if (trip.startDate == null) return 1;
    final now = DateTime.now();
    final diff = now.difference(trip.startDate!).inDays;
    return diff + 1;
  }

  int _getCurrentItemIndex(List<PlanItem> items, int currentDay) {
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // 今日のアイテムを取得
    final todayItems = items.where((item) => item.day == currentDay).toList();
    if (todayItems.isEmpty) return -1;

    // 現在時刻より前で最も近いアイテムを見つける
    for (int i = todayItems.length - 1; i >= 0; i--) {
      if (todayItems[i].time.compareTo(currentTime) <= 0) {
        return items.indexOf(todayItems[i]);
      }
    }
    return items.indexOf(todayItems.first);
  }

  @override
  Widget build(BuildContext context) {
    final currentDay = _getCurrentDay();
    final items = plan.items;
    final currentIndex = _getCurrentItemIndex(items, currentDay);
    final todayItems = items.where((item) => item.day == currentDay).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 今日のスケジュール
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingM,
                  vertical: AppSizes.paddingXS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$currentDay日目',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text('${todayItems.length}スポット', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),

          // スケジュールタイムライン
          if (todayItems.isEmpty)
            AppCard(
              padding: EdgeInsets.all(AppSizes.paddingL),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: AppSizes.paddingM),
                    Text(
                      '今日の予定はありません',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...todayItems.asMap().entries.map((entry) {
              final index = items.indexOf(entry.value);
              final item = entry.value;
              final isCurrent = index == currentIndex;
              final isPast = index < currentIndex;

              return _OngoingTimelineItem(
                item: item,
                isCurrent: isCurrent,
                isPast: isPast,
                isFirst: entry.key == 0,
                isLast: entry.key == todayItems.length - 1,
              );
            }),

          const SizedBox(height: AppSizes.paddingXL),

          // 次のスポット（現在より後のアイテムがあれば）
          if (currentIndex >= 0 && currentIndex < items.length - 1) ...[
            Text('次のスポット', style: AppTypography.titleSmall),
            const SizedBox(height: AppSizes.paddingS),
            _NextSpotCard(item: items[currentIndex + 1]),
          ],
        ],
      ),
    );
  }
}

/// 当日モードタイムラインアイテム
class _OngoingTimelineItem extends StatelessWidget {
  const _OngoingTimelineItem({
    required this.item,
    required this.isCurrent,
    required this.isPast,
    required this.isFirst,
    required this.isLast,
  });

  final PlanItem item;
  final bool isCurrent;
  final bool isPast;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        isCurrent
            ? AppColors.accent
            : (isPast ? AppColors.subAccent : AppColors.textSecondary);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 時刻
          SizedBox(
            width: 50,
            child: Text(
              item.time,
              style: AppTypography.labelMedium.copyWith(
                color: accentColor,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),

          // タイムライン
          SizedBox(
            width: 30,
            child: Column(
              children: [
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 8,
                    color: isPast ? AppColors.subAccent : AppColors.border,
                  ),
                Container(
                  width: isCurrent ? 16 : 12,
                  height: isCurrent ? 16 : 12,
                  decoration: BoxDecoration(
                    color:
                        isCurrent
                            ? AppColors.accent
                            : (isPast
                                ? AppColors.subAccent
                                : AppColors.cardBackground),
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor, width: 2),
                  ),
                  child:
                      isPast
                          ? const Icon(
                            Icons.check,
                            size: 8,
                            color: Colors.white,
                          )
                          : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 30,
                    color: isPast ? AppColors.subAccent : AppColors.border,
                  ),
              ],
            ),
          ),

          const SizedBox(width: AppSizes.paddingS),

          // コンテンツ
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isCurrent)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'NOW',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          item.location,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration:
                                isPast ? TextDecoration.lineThrough : null,
                            color: isPast ? AppColors.textSecondary : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.notes!, style: AppTypography.caption),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 次のスポットカード
class _NextSpotCard extends StatelessWidget {
  const _NextSpotCard({required this.item});

  final PlanItem item;

  Future<void> _openInMaps() async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/${Uri.encodeComponent(item.location)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingS),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: const Icon(Icons.place, color: AppColors.accent),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.location, style: AppTypography.titleSmall),
                    Text(
                      '${item.time} 〜 ${item.durationMinutes}分',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.paddingS),
            Text(item.notes!, style: AppTypography.bodySmall),
          ],
          const SizedBox(height: AppSizes.paddingM),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openInMaps,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Google Mapsで開く'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
