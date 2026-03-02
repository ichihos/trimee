import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/models/plan_model.dart';
import '../../../../shared/models/trip_model.dart';

import '../../../../shared/providers/firebase_providers.dart';
import '../../../../shared/providers/user_profile_provider.dart';
import '../../../../shared/services/ai_service.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/animated_widgets.dart';
import '../../../cards/presentation/providers/card_provider.dart';
import '../../../trip/presentation/providers/trip_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/plan_generation_provider.dart';
import '../widgets/plan_map_view.dart';
import 'plan_edit_screen.dart';
import '../../../../shared/widgets/chat_overlay.dart';

/// プラン確認画面
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    // 画面表示後に自動でプラン生成を開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoGenerateIfNeeded();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// プランがない場合に自動でAI生成を開始
  Future<void> _autoGenerateIfNeeded() async {
    // 既にプランがある場合は生成しない
    final plans = ref.read(tripPlansProvider(widget.tripId)).valueOrNull;
    if (plans != null && plans.isNotEmpty) return;

    // 生成中の場合は何もしない
    final generationState = ref.read(planGenerationProvider(widget.tripId));
    if (generationState.isGenerating ||
        generationState.streamingPlans.isNotEmpty) {
      return;
    }

    // ホストのみが自動生成を実行できる
    final trip = ref.read(tripDetailProvider(widget.tripId)).valueOrNull;
    final currentUserId = ref.read(currentUserIdProvider);
    final isHost = trip?.createdBy == currentUserId;

    if (!isHost) return;

    // 自動生成を開始
    // 少し待ってから開始（画面遷移完了を待つ）
    if (mounted) {
      _generatePlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(tripPlansProvider(widget.tripId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ChatOverlay(
        tripId: widget.tripId,
        child: SafeArea(
          child: Column(
            children: [
              // ヘッダー
              _PlanHeader(onBack: () => context.go('/trip/${widget.tripId}')),

              // メインコンテンツ
              Expanded(child: _buildMainContent(plansAsync)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(AsyncValue<List<PlanModel>> plansAsync) {
    // プロバイダーから生成状態を取得
    final generationState = ref.watch(planGenerationProvider(widget.tripId));
    final isGenerating = generationState.isGenerating;
    final streamingPlans = generationState.streamingPlans;
    final currentPlanTitle = generationState.currentPlanTitle;
    final generatingItems = generationState.generatingItems;
    final error = generationState.error;

    // トリップ情報を取得して確定済みかチェック
    final trip = ref.watch(tripDetailProvider(widget.tripId)).valueOrNull;
    final isConfirmed =
        trip?.status == TripStatus.confirmed && trip?.confirmedPlanId != null;

    // エラーがある場合
    if (error != null) {
      return _ErrorState(
        error: error,
        onRetry:
            () =>
                ref
                    .read(planGenerationProvider(widget.tripId).notifier)
                    .clearError(),
      );
    }

    // リアルタイム生成中または生成済みプランがある場合
    // ただし、DBにプランがまだ保存されていない（または読み込まれていない）場合のみこちらを優先表示
    if (isGenerating || streamingPlans.isNotEmpty) {
      if (streamingPlans.isEmpty) {
        // まだ1つもできていない時

        // プラン生成が始まり、タイトルやアイテムが届き始めている場合はストリーミング表示
        if (currentPlanTitle != null || generatingItems.isNotEmpty) {
          return _RealTimeGenerationView(
            currentPlanTitle: currentPlanTitle,
            items: generatingItems,
            completedPlansCount: 0,
          );
        }

        // カード分析中/分析完了: インサイト表示付きローディング
        return _CardAnalysisLoadingView(
          isAnalyzing: generationState.isAnalyzing,
          analysis: generationState.cardAnalysis,
        );
      }

      // 生成済みプランがあれば表示（生成中の場合は最後にローディングカードを追加）
      final showLoadingCard = isGenerating;
      final itemCount =
          streamingPlans.length +
          (showLoadingCard ? 1 : 0) +
          1; // +1 for Option Card

      // 生成されたプランをPlanModelに変換して表示用にリスト化
      final displayPlans =
          streamingPlans.map((p) => p.toPlanModel(widget.tripId)).toList();

      return Column(
        children: [
          // ページインジケーター（ドット）
          Container(
            margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(itemCount, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        _currentPage == index
                            ? AppColors.accent
                            : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

          // タイトル（PageView外に配置して重なりを防止）
          if (_currentPage < displayPlans.length)
            _SlidingPlanTitle(plan: displayPlans[_currentPage])
          else if (showLoadingCard && _currentPage == streamingPlans.length)
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingS),
              child: Text(
                '生成中...',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const SizedBox(height: 50),

          const SizedBox(height: AppSizes.paddingXS),

          // プランカードスワイプ
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: itemCount,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                HapticFeedback.selectionClick();
              },
              itemBuilder: (context, index) {
                // オプションカード（最後）
                if (index == itemCount - 1) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSizes.paddingS),
                    child: _PlanOptionsCard(
                      onCreateEmpty: _createEmptyPlan,
                      onRegenerate: _generatePlans,
                      onBackToSelection: () => Navigator.of(context).pop(),
                    ),
                  );
                }

                // 生成中カードの表示
                if (showLoadingCard && index == streamingPlans.length) {
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingS,
                      vertical: AppSizes.paddingXS,
                    ),
                    child: AppCard(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _RealTimeGenerationView(
                              currentPlanTitle: currentPlanTitle,
                              items: generatingItems,
                              completedPlansCount: streamingPlans.length,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 生成済みプランの表示
                return _AnimatedPlanCard(
                  plan: displayPlans[index],
                  tripId: widget.tripId,
                  isActive: index == _currentPage,
                  onSelectPlan:
                      () => _selectAndEditPlan(context, displayPlans[index]),
                  onRegenerate: _generatePlans,
                );
              },
            ),
          ),

          const SizedBox(height: AppSizes.paddingS),
        ],
      );
    }

    return plansAsync.when(
      data: (plans) {
        // 確定済みプランがある場合は編集画面（詳細画面）を直接表示
        if (isConfirmed) {
          final confirmedPlan = plans.firstWhere(
            (p) => p.id == trip!.confirmedPlanId,
            orElse: () => plans.first,
          );
          return PlanEditScreen(
            tripId: widget.tripId,
            plan: confirmedPlan,
            onBack: () => context.go('/trip/${widget.tripId}'),
          );
        }

        if (plans.isEmpty) {
          // 自動生成中の状態を表示
          // ホスト以外の場合は「待機中」を表示
          final currentUserId = ref.read(currentUserIdProvider);
          final isHost = trip?.createdBy == currentUserId;
          final isVoting = trip?.status == TripStatus.voting;

          return _EmptyPlanState(
            isGenerating: isGenerating,
            isHost: isHost,
            isTripVoting: isVoting,
            onGenerate: _generatePlans,
          );
        }

        return Column(
          children: [
            // ページインジケーター（ドット）
            Container(
              margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(plans.length + 1, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          _currentPage == index
                              ? AppColors.accent
                              : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // タイトル（PageView外に配置して重なりを防止）
            if (_currentPage < plans.length)
              _SlidingPlanTitle(plan: plans[_currentPage])
            else
              const SizedBox(height: 50),

            const SizedBox(height: AppSizes.paddingXS),

            // プランカードスワイプ
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: plans.length + 1,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  HapticFeedback.selectionClick();
                },
                itemBuilder: (context, index) {
                  // オプションカード
                  if (index == plans.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSizes.paddingS),
                      child: _PlanOptionsCard(
                        onCreateEmpty: _createEmptyPlan,
                        onRegenerate: _generatePlans,
                        onBackToSelection: () => Navigator.of(context).pop(),
                      ),
                    );
                  }

                  return _AnimatedPlanCard(
                    plan: plans[index],
                    tripId: widget.tripId,
                    isActive: index == _currentPage,
                    onSelectPlan:
                        () => _selectAndEditPlan(context, plans[index]),
                    onRegenerate: _generatePlans,
                  );
                },
              ),
            ),

            const SizedBox(height: AppSizes.paddingS),
          ],
        );
      },
      loading: () => const _LoadingState(),
      error:
          (error, stack) => _ErrorState(
            error: error.toString(),
            onRetry: () => ref.invalidate(tripPlansProvider(widget.tripId)),
          ),
    );
  }

  Future<void> _selectAndEditPlan(BuildContext context, PlanModel plan) async {
    HapticFeedback.mediumImpact();

    var editPlan = plan;

    // ストリーミング生成されたプラン（id未設定）の場合、先にFirestoreに保存してIDを取得
    if (plan.id.isEmpty) {
      final planId = await ref
          .read(planControllerProvider.notifier)
          .createPlan(tripId: widget.tripId, plan: plan);
      if (planId == null || !context.mounted) return;
      editPlan = plan.copyWith(id: planId);
    }

    // 編集中プランIDを設定（確定はせず、編集状態として保存）
    await ref
        .read(planControllerProvider.notifier)
        .setEditingPlanId(tripId: widget.tripId, planId: editPlan.id);

    // 編集画面へ遷移
    if (context.mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder:
              (context, animation, secondaryAnimation) =>
                  PlanEditScreen(tripId: widget.tripId, plan: editPlan),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                    begin: const Offset(0.0, 0.3),
                    end: Offset.zero,
                  )
                  .chain(CurveTween(curve: Curves.easeOutCubic))
                  .animate(animation),
              child: FadeTransition(
                opacity: CurveTween(curve: Curves.easeOut).animate(animation),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  Future<void> _generatePlans() async {
    // プロバイダーの状態をクリアしてスタート
    ref.read(planGenerationProvider(widget.tripId).notifier).reset();

    try {
      final trip = await ref.read(tripDetailProvider(widget.tripId).future);
      final cards = await ref.read(tripCardsProvider(widget.tripId).future);

      if (trip == null || cards.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('カードを追加してからプランを生成してください'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          );
        }
        return;
      }

      // メンバープロフィールを取得
      final profileController = ref.read(profileControllerProvider.notifier);
      final memberProfiles = await profileController.getMemberProfiles(
        trip.members,
      );

      // userIdから名前へのマップを作成
      final userIdToName = <String, String>{};
      for (final profile in memberProfiles) {
        userIdToName[profile.userId] = profile.displayName;
      }

      // メンバーの出発地点を取得（名前 → 出発地点）
      final memberDepartures = <String, String>{};
      for (final entry in trip.memberDetails.entries) {
        final member = entry.value;
        if (member.departurePoint != null &&
            member.departurePoint!.isNotEmpty) {
          memberDepartures[member.displayName] = member.departurePoint!;
        }
      }

      final notifier = ref.read(planGenerationProvider(widget.tripId).notifier);

      // Flash（カード分析）と Pro（プラン生成）を並行で実行
      // 分析結果はローディング中にインサイトとして表示される
      notifier.analyzeCards(
        cards: cards,
        memberProfiles: memberProfiles,
        userIdToName: userIdToName,
      );
      notifier.startGeneration(
        tripTitle: trip.title,
        startDate: trip.startDate,
        endDate: trip.endDate,
        cards: cards,
        memberProfiles: memberProfiles,
        userIdToName: userIdToName,
        memberDepartures: memberDepartures.isNotEmpty ? memberDepartures : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('プラン生成開始エラー: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _createEmptyPlan() async {
    try {
      final newPlan = PlanModel(
        id: '', // ID will be assigned by controller
        tripId: widget.tripId,
        title: '新しいプラン',
        items: [],
        createdAt: DateTime.now(),
      );

      final planId = await ref
          .read(planControllerProvider.notifier)
          .createPlan(tripId: widget.tripId, plan: newPlan);

      if (planId != null && mounted) {
        final createdPlan = newPlan.copyWith(id: planId);
        _selectAndEditPlan(context, createdPlan);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('プラン作成エラー: $e')));
      }
    }
  }
}

/// ヘッダー
class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Row(
        children: [
          // 戻るボタン
          IconButton(
            onPressed: onBack,
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
                Row(
                  children: [
                    const AppIcon(type: AppIconType.sparkle, size: 24),
                    const SizedBox(width: AppSizes.paddingXS),
                    Text(AppStrings.plan, style: AppTypography.titleMedium),
                  ],
                ),
                Text('AIが最適なプランをご提案', style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// スライド用プランタイトル
class _SlidingPlanTitle extends StatelessWidget {
  const _SlidingPlanTitle({required this.plan});

  final PlanModel plan;

  @override
  Widget build(BuildContext context) {
    final icon = _getPlanTypeIcon(plan.title);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // アイコン
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: AppIcon(type: icon, size: 20, showBackground: false),
          ),
          const SizedBox(width: AppSizes.paddingS),

          // タイトル
          Flexible(
            child: Text(
              plan.title,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  AppIconType _getPlanTypeIcon(String title) {
    if (title.contains('アクティブ')) return AppIconType.active;
    if (title.contains('のんびり')) return AppIconType.relax;
    if (title.contains('コスパ')) return AppIconType.budget;
    return AppIconType.plan;
  }

}

/// アニメーション付きプランカード
class _AnimatedPlanCard extends ConsumerStatefulWidget {
  const _AnimatedPlanCard({
    required this.plan,
    required this.tripId,
    required this.isActive,
    required this.onSelectPlan,
    required this.onRegenerate,
  });

  final PlanModel plan;
  final String tripId;
  final bool isActive;
  final VoidCallback onSelectPlan;
  final VoidCallback onRegenerate;

  @override
  ConsumerState<_AnimatedPlanCard> createState() => _AnimatedPlanCardState();
}

class _AnimatedPlanCardState extends ConsumerState<_AnimatedPlanCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isMapView = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_AnimatedPlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder:
          (context, child) =>
              Transform.scale(scale: _scaleAnimation.value, child: child),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingXS,
          vertical: AppSizes.paddingXS,
        ),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ヘッダー（コンパクト化）
              _PlanCardHeader(plan: widget.plan),

              // 地図/リスト切り替え
              if (widget.plan.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingM,
                  ),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5), // Light background
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Stack(
                      children: [
                        // Active Indicator
                        AnimatedAlign(
                          alignment:
                              _isMapView
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: FractionallySizedBox(
                            widthFactor: 0.5,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusFull,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Tab Buttons
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isMapView = false),
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.format_list_bulleted_rounded,
                                        size: 20,
                                        color:
                                            !_isMapView
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'リスト',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              !_isMapView
                                                  ? AppColors.textPrimary
                                                  : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isMapView = true),
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.map_outlined,
                                        size: 20,
                                        color:
                                            _isMapView
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '地図',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              _isMapView
                                                  ? AppColors.textPrimary
                                                  : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // タイムラインまたは地図ビュー
              Expanded(
                child:
                    widget.plan.items.isEmpty
                        ? Center(
                          child: Text(
                            'アイテムがありません',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                        : _isMapView
                        ? Padding(
                          padding: const EdgeInsets.all(AppSizes.paddingS),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusM,
                            ),
                            child: PlanMapView(
                              items: widget.plan.items,
                              liteMode: true,
                            ),
                          ),
                        )
                        : Builder(
                          builder: (context) {
                            final tripAsync = ref.watch(
                              tripDetailProvider(widget.tripId),
                            );
                            final startDate = tripAsync.valueOrNull?.startDate;
                            return _DayGroupedTimeline(
                              items: widget.plan.items,
                              startDate: startDate,
                            );
                          },
                        ),
              ),

              Container(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppSizes.radiusL),
                  ),
                ),
                child: Column(
                  children: [
                    // このプランにするボタン（パルスアニメーション付き）
                    PulseAnimation(
                      minScale: 0.98,
                      maxScale: 1.02,
                      duration: const Duration(milliseconds: 2000),
                      child: ScaleTapFeedback(
                        onTap: widget.onSelectPlan,
                        child: Container(
                          height: 48, // Slightly taller
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accent, Color(0xFFD4896E)],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusM,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'このプランをベースにする',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// プランカードヘッダー（コンパクト版）
class _PlanCardHeader extends StatelessWidget {
  const _PlanCardHeader({required this.plan});

  final PlanModel plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, Color(0xFFD4896E)],
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusL),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: AppTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (plan.description != null)
                  Text(
                    plan.description!,
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 1,
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

/// タイムラインアイテム
class _TimelineItem extends StatefulWidget {
  const _TimelineItem({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.index,
  });

  final PlanItem item;
  final bool isFirst;
  final bool isLast;
  final int index;

  @override
  State<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<_TimelineItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // タイムライン
            SizedBox(
              width: 60,
              child: Column(
                children: [
                  // 時刻
                  Text(
                    widget.item.time,
                    style: AppTypography.timeStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.item.durationMinutes > 0)
                    Text(
                      '${widget.item.durationMinutes}分',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

            // ドットと線
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  // 上の線
                  if (!widget.isFirst)
                    Expanded(
                      child: Container(width: 2, color: AppColors.border),
                    ),
                  // ドット
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cardBackground,
                        width: 2,
                      ),
                    ),
                  ),
                  // 下の線
                  if (!widget.isLast)
                    Expanded(
                      child: Container(width: 2, color: AppColors.border),
                    ),
                ],
              ),
            ),

            const SizedBox(width: AppSizes.paddingS),

            // コンテンツ
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.paddingM),
                child: Material(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    onTap: () => _launchSearch(widget.item.location),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.paddingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.item.location,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.textSecondary
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.search,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                          if (widget.item.notes != null) ...[
                            const SizedBox(height: AppSizes.paddingXS),
                            Text(
                              widget.item.notes!,
                              style: AppTypography.caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchSearch(String keyword) async {
    try {
      final query = Uri.encodeComponent(keyword);
      final url = Uri.parse('https://www.google.com/search?q=$query');
      if (await canLaunchUrl(url)) {
        HapticFeedback.lightImpact();
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching search: $e');
    }
  }
}

/// 日付でグループ化されたタイムライン
class _DayGroupedTimeline extends StatelessWidget {
  const _DayGroupedTimeline({required this.items, this.startDate});

  final List<PlanItem> items;
  final DateTime? startDate;

  @override
  Widget build(BuildContext context) {
    // 日付でグループ化
    final groupedItems = <int, List<MapEntry<int, PlanItem>>>{};
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final day = item.day;
      groupedItems.putIfAbsent(day, () => []);
      groupedItems[day]!.add(MapEntry(i, item));
    }

    final days = groupedItems.keys.toList()..sort();
    final isMultiDay = days.length > 1 || (days.isNotEmpty && days.first > 1);

    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      itemCount: _calculateTotalCount(groupedItems, days, isMultiDay),
      itemBuilder: (context, index) {
        return _buildItemAtIndex(index, groupedItems, days, isMultiDay);
      },
    );
  }

  int _calculateTotalCount(
    Map<int, List<MapEntry<int, PlanItem>>> groupedItems,
    List<int> days,
    bool isMultiDay,
  ) {
    if (!isMultiDay) return items.length;
    // 日付ヘッダー数 + アイテム数
    return days.length + items.length;
  }

  Widget _buildItemAtIndex(
    int index,
    Map<int, List<MapEntry<int, PlanItem>>> groupedItems,
    List<int> days,
    bool isMultiDay,
  ) {
    if (!isMultiDay) {
      return _TimelineItem(
        item: items[index],
        isFirst: index == 0,
        isLast: index == items.length - 1,
        index: index,
      );
    }

    // 複数日の場合は日付ヘッダーを含めて表示
    var currentIndex = 0;
    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final day = days[dayIndex];
      final dayItems = groupedItems[day]!;

      // 日付ヘッダーのインデックス
      if (index == currentIndex) {
        return _DayHeader(day: day, startDate: startDate);
      }
      currentIndex++;

      // この日のアイテム
      for (var itemIndex = 0; itemIndex < dayItems.length; itemIndex++) {
        if (index == currentIndex) {
          final entry = dayItems[itemIndex];
          final isFirstInDay = itemIndex == 0;
          final isLastInDay = itemIndex == dayItems.length - 1;
          final isLastOverall = dayIndex == days.length - 1 && isLastInDay;

          return _TimelineItem(
            item: entry.value,
            isFirst: isFirstInDay,
            isLast: isLastOverall,
            index: entry.key,
          );
        }
        currentIndex++;
      }
    }

    return const SizedBox.shrink();
  }
}

/// 日付ヘッダー
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, this.startDate});

  final int day;
  final DateTime? startDate;

  @override
  Widget build(BuildContext context) {
    // 実際の日付を計算
    String? dateText;
    if (startDate != null) {
      final date = startDate!.add(Duration(days: day - 1));
      dateText = '${date.month}/${date.day}（${_weekdayName(date.weekday)}）';
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSizes.paddingM,
        bottom: AppSizes.paddingS,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingM,
              vertical: AppSizes.paddingXS,
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
                const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  '$day日目',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (dateText != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    dateText,
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSizes.paddingS),
          Expanded(child: Container(height: 1, color: AppColors.border)),
        ],
      ),
    );
  }

  String _weekdayName(int weekday) {
    const names = ['月', '火', '水', '木', '金', '土', '日'];
    return names[weekday - 1];
  }
}

/// リアルタイム生成ビュー（アイテムが順次表示される）
class _RealTimeGenerationView extends StatelessWidget {
  const _RealTimeGenerationView({
    required this.currentPlanTitle,
    required this.items,
    required this.completedPlansCount,
  });

  final String? currentPlanTitle;
  final List<PlanItemData> items;
  final int completedPlansCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ヘッダー: 生成状況
        Container(
          margin: const EdgeInsets.all(AppSizes.paddingM),
          padding: const EdgeInsets.all(AppSizes.paddingM),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withValues(alpha: 0.1),
                AppColors.subAccent.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // AI アイコン（アニメーション）
              SpinAnimation(
                duration: const Duration(milliseconds: 2000),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.subAccent],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentPlanTitle != null
                          ? '「$currentPlanTitle」を作成中...'
                          : 'プランを考えています...',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${items.length}件のアイテムを生成済み',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // プログレス
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingS,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Text(
                  '$completedPlansCount/3',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // アイテムリスト
        Expanded(
          child: items.isEmpty ? _buildWaitingState() : _buildItemList(),
        ),
      ],
    );
  }

  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AIThinkingAnimation(
            size: 100,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.subAccent],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.travel_explore,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingL),
          StreamingText(
            text: 'ベストな行程を探しています...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    // 日付でグループ化
    final itemsByDay = <int, List<PlanItemData>>{};
    for (final item in items) {
      itemsByDay.putIfAbsent(item.day, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isNewDay = index == 0 || items[index - 1].day != item.day;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNewDay) ...[
              if (index > 0) const SizedBox(height: AppSizes.paddingM),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingS,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                child: Text(
                  'Day ${item.day}',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingS),
            ],
            _RealTimeItemCard(item: item, index: index),
          ],
        );
      },
    );
  }
}

/// リアルタイム生成中のアイテムカード
class _RealTimeItemCard extends StatefulWidget {
  const _RealTimeItemCard({required this.item, required this.index});

  final PlanItemData item;
  final int index;

  @override
  State<_RealTimeItemCard> createState() => _RealTimeItemCardState();
}

class _RealTimeItemCardState extends State<_RealTimeItemCard>
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
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
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
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
          padding: const EdgeInsets.all(AppSizes.paddingM),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              // 時間
              Container(
                width: 50,
                child: Text(
                  widget.item.time,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 縦線
              Container(
                width: 2,
                height: 40,
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingS,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.accent, AppColors.subAccent],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.location,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.item.notes != null &&
                        widget.item.notes!.isNotEmpty)
                      Text(
                        widget.item.notes!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // 所要時間
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                child: Text(
                  '${widget.item.duration}分',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// カード分析インサイト付きローディングビュー
/// Flash モデルによる分析結果をアニメーション表示しながら、
/// Pro モデルがバックグラウンドでプランを生成中
class _CardAnalysisLoadingView extends StatefulWidget {
  const _CardAnalysisLoadingView({
    required this.isAnalyzing,
    required this.analysis,
  });

  final bool isAnalyzing;
  final CardAnalysis? analysis;

  @override
  State<_CardAnalysisLoadingView> createState() =>
      _CardAnalysisLoadingViewState();
}

class _CardAnalysisLoadingViewState extends State<_CardAnalysisLoadingView>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _revealController;
  int _visibleInsights = 0;
  Timer? _insightTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _revealController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(_CardAnalysisLoadingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 分析完了時にインサイトを1つずつ表示開始
    if (widget.analysis != null && oldWidget.analysis == null) {
      _startRevealingInsights();
    }
  }

  void _startRevealingInsights() {
    _insightTimer?.cancel();
    _visibleInsights = 0;
    _insightTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _visibleInsights++;
      });
      // 全インサイト表示完了
      if (_visibleInsights >= 5) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _revealController.dispose();
    _insightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysis;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI思考中アイコン
            _AIGeneratingIcon(),
            const SizedBox(height: AppSizes.paddingL),

            // メインメッセージ
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                analysis != null ? 'みんなの希望を整理しました' : 'カードの内容を分析中...',
                key: ValueKey(analysis != null),
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSizes.paddingXS),
            Text(
              'AIがベストなプランを考えています',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.paddingXL),

            // 分析中: シマーローディング
            if (analysis == null) ...[_buildShimmerCards()],

            // 分析完了: インサイトを順次表示
            if (analysis != null) ...[
              // キーワードバブル
              if (_visibleInsights >= 1)
                _InsightCard(
                  icon: Icons.tag_rounded,
                  label: 'キーワード',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children:
                        analysis.keywords.map((keyword) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusFull,
                              ),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              keyword,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),

              // 注目スポット
              if (_visibleInsights >= 2)
                _InsightCard(
                  icon: Icons.place_rounded,
                  label: '注目スポット',
                  child: Text(
                    analysis.topSpot,
                    style: AppTypography.bodyMedium,
                  ),
                ),

              // グループスタイル
              if (_visibleInsights >= 3)
                _InsightCard(
                  icon: Icons.groups_rounded,
                  label: 'グループの傾向',
                  child: Text(
                    analysis.groupStyle,
                    style: AppTypography.bodyMedium,
                  ),
                ),

              // メンバーハイライト
              if (_visibleInsights >= 4 && analysis.memberHighlights.isNotEmpty)
                _InsightCard(
                  icon: Icons.person_rounded,
                  label: 'メンバーの声',
                  child: Column(
                    children:
                        analysis.memberHighlights.map((m) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${m.name}: ${m.want}',
                                    style: AppTypography.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ),

              // ファンファクト
              if (_visibleInsights >= 5)
                _InsightCard(
                  icon: Icons.lightbulb_rounded,
                  label: 'おもしろ発見',
                  child: Text(
                    analysis.funFact,
                    style: AppTypography.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],

            const SizedBox(height: AppSizes.paddingL),

            // プログレスバー
            SizedBox(
              width: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.border,
                  color: AppColors.accent,
                  minHeight: 3,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.paddingS),
            TypingIndicator(color: AppColors.textSecondary, dotSize: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCards() {
    return Column(
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final opacity = 0.3 + (_pulseController.value * 0.4);
            return Opacity(opacity: opacity, child: child);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
            padding: const EdgeInsets.all(AppSizes.paddingM),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 80 + (index * 20.0),
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 120 + (index * 10.0),
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// インサイトカード（フェードイン付き）
class _InsightCard extends StatefulWidget {
  const _InsightCard({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
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
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
          padding: const EdgeInsets.all(AppSizes.paddingM),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 16, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingS),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 空のプラン状態
class _EmptyPlanState extends StatefulWidget {
  const _EmptyPlanState({
    required this.isGenerating,
    required this.isHost,
    this.isTripVoting = false,
    required this.onGenerate,
  });

  final bool isGenerating;
  final bool isHost;
  final bool isTripVoting;
  final VoidCallback onGenerate;

  @override
  State<_EmptyPlanState> createState() => _EmptyPlanStateState();
}

class _EmptyPlanStateState extends State<_EmptyPlanState> {
  int _currentStep = 0;
  Timer? _messageTimer;

  final List<String> _loadingMessages = [
    'メンバーの希望を分析しています...',
    '最適なルートを計算中...',
    'エリアの魅力を再発見中...',
    '移動時間を最適化しています...',
    '地元の隠れ家スポットを探しています...',
    '旅行のスタイルに合わせて調整中...',
    '楽しいアクティビティを選定中...',
    '全体のバランスを整えています...',
    'ベストなレストランを選定中...',
    'もうすぐプランが完成します！',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isGenerating || (!widget.isHost && widget.isTripVoting)) {
      _startMessageRotation();
    }
  }

  @override
  void didUpdateWidget(_EmptyPlanState oldWidget) {
    super.didUpdateWidget(oldWidget);
    final effectiveGenerating =
        widget.isGenerating || (!widget.isHost && widget.isTripVoting);
    final oldEffectiveGenerating =
        oldWidget.isGenerating || (!oldWidget.isHost && oldWidget.isTripVoting);

    if (effectiveGenerating && !oldEffectiveGenerating) {
      _currentStep = 0;
      _startMessageRotation();
    } else if (!effectiveGenerating && oldEffectiveGenerating) {
      _stopMessageRotation();
    }
  }

  @override
  void dispose() {
    _stopMessageRotation();
    super.dispose();
  }

  void _startMessageRotation() {
    _stopMessageRotation();
    _messageTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        setState(() {
          _currentStep = (_currentStep + 1) % _loadingMessages.length;
        });
      }
    });
  }

  void _stopMessageRotation() {
    _messageTimer?.cancel();
    _messageTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    // ホスト以外で、投票ステータスの場合は「生成中」として扱う
    // (ホストが生成しているのを待っている状態)
    final effectiveGenerating =
        widget.isGenerating || (!widget.isHost && widget.isTripVoting);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (effectiveGenerating) ...[
              // AI思考中のアイコン
              SpinAnimation(
                duration: const Duration(milliseconds: 2000),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: AppIcon(
                      type: AppIconType.sparkle,
                      size: 48,
                      iconColor: AppColors.accent,
                      showBackground: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),

              // ローディングメッセージ（アニメーション付き）
              SizedBox(
                height: 60,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                  ) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.2),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _loadingMessages[_currentStep],
                    key: ValueKey<int>(_currentStep),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingM),

              // プログレスバー
              SizedBox(
                width: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.border,
                    color: AppColors.accent,
                    minHeight: 4,
                  ),
                ),
              ),
            ] else if (widget.isHost) ...[
              // ホスト用: 非生成時（生成ボタン）
              BounceIn(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.accent.withValues(alpha: 0.2),
                        AppColors.subAccent.withValues(alpha: 0.2),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: AppIcon(
                      type: AppIconType.sparkle,
                      size: 52,
                      showBackground: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),

              Text('まだプランがありません', style: AppTypography.titleMedium),
              const SizedBox(height: AppSizes.paddingS),

              Text(
                'カードを集めたら\nAIにプランを作ってもらいましょう',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.paddingXL),

              ScaleTapFeedback(
                onTap: widget.onGenerate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingXL,
                    vertical: AppSizes.paddingM,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: AppSizes.paddingS),
                      Text(
                        AppStrings.generatePlan,
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // ゲスト用: 非生成時（待機メッセージ）
              BounceIn(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.hourglass_empty_rounded,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),

              Text(
                'プラン生成待ち',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.paddingS),

              Text(
                'ホストがプランを作成するのを\n待っています...',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// AI生成中アイコン（洗練されたデザイン）
class _AIGeneratingIcon extends StatefulWidget {
  const _AIGeneratingIcon();

  @override
  State<_AIGeneratingIcon> createState() => _AIGeneratingIconState();
}

class _AIGeneratingIconState extends State<_AIGeneratingIcon>
    with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外側の回転リング
          AnimatedBuilder(
            animation: _rotateController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateController.value * 2 * 3.14159,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.0),
                        AppColors.accent.withValues(alpha: 0.6),
                        AppColors.subAccent.withValues(alpha: 0.6),
                        AppColors.subAccent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // 内側の円
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.08),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.accent, Color(0xFFD4896E)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),
          // 周囲のスパークル
          ...List.generate(3, (index) {
            final delay = index * 0.33;
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final value = ((_pulseController.value + delay) % 1.0);
                final angle =
                    (index * 2.0944) + (_rotateController.value * 0.5);
                final radius = 44.0 + (value * 8);
                return Transform.translate(
                  offset: Offset(
                    radius * math.cos(angle),
                    radius * math.sin(angle),
                  ),
                  child: Opacity(
                    opacity: (1.0 - value) * 0.8,
                    child: const AppIcon(
                      type: AppIconType.sparkle,
                      size: 18,
                      showBackground: false,
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

/// 生成中のヒントメッセージ
class _GeneratingTips extends StatefulWidget {
  const _GeneratingTips();

  @override
  State<_GeneratingTips> createState() => _GeneratingTipsState();
}

class _GeneratingTipsState extends State<_GeneratingTips> {
  int _currentTip = 0;
  static const _tips = [
    '🗺️ みんなの行きたい場所を整理中...',
    '⏰ 最適な時間配分を計算中...',
    '🚗 移動ルートを最適化中...',
    '💡 おすすめスポットを検討中...',
    '✨ 素敵なプランを仕上げ中...',
  ];

  @override
  void initState() {
    super.initState();
    _cycleTips();
  }

  void _cycleTips() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _currentTip = (_currentTip + 1) % _tips.length;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Text(
        _tips[_currentTip],
        key: ValueKey(_currentTip),
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// ローディング状態
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 3,
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            AppStrings.loading,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// エラー状態
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSizes.paddingM),
            Text('エラーが発生しました', style: AppTypography.titleMedium),
            const SizedBox(height: AppSizes.paddingS),
            Text(
              error,
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.paddingL),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }
}

/// プラン選択確認ダイアログ
class _PlanSelectedDialog extends StatefulWidget {
  const _PlanSelectedDialog({
    required this.planTitle,
    required this.onComplete,
  });

  final String planTitle;
  final VoidCallback onComplete;

  @override
  State<_PlanSelectedDialog> createState() => _PlanSelectedDialogState();
}

class _PlanSelectedDialogState extends State<_PlanSelectedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // 紙吹雪を少し遅らせて表示
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _showConfetti = true);
        HapticFeedback.heavyImpact();
      }
    });

    // 自動的に遷移
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 紙吹雪エフェクト
        if (_showConfetti)
          Positioned.fill(
            child: ConfettiOverlay(
              particleCount: 60,
              duration: const Duration(milliseconds: 2500),
              colors: const [
                AppColors.accent,
                AppColors.subAccent,
                Color(0xFFFFD700),
                Color(0xFFFF69B4),
                Color(0xFF87CEEB),
                Color(0xFFFF6B6B),
              ],
            ),
          ),

        // メインダイアログ
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    margin: const EdgeInsets.all(AppSizes.paddingXL),
                    padding: const EdgeInsets.all(AppSizes.paddingXL),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 成功アニメーション（パーティクルバースト付き）
                        SuccessCheckAnimation(
                          size: 80,
                          color: AppColors.subAccent,
                          showParticles: true,
                        ),
                        const SizedBox(height: AppSizes.paddingL),

                        // タイトル（ストリーミングテキスト）
                        StreamingText(
                          text: 'プランを選択しました',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          charDuration: const Duration(milliseconds: 40),
                        ),
                        const SizedBox(height: AppSizes.paddingS),

                        // プラン名
                        BounceIn(
                          delay: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.paddingM,
                              vertical: AppSizes.paddingS,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accent.withValues(alpha: 0.15),
                                  AppColors.subAccent.withValues(alpha: 0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusFull,
                              ),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  '🎯',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    widget.planTitle,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.paddingL),

                        // 説明
                        SlideFadeIn(
                          delay: const Duration(milliseconds: 400),
                          child: Text(
                            '編集画面でスケジュールを\nカスタマイズできます',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppSizes.paddingM),

                        // ローディング（タイピングドット付き）
                        SlideFadeIn(
                          delay: const Duration(milliseconds: 500),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TypingIndicator(
                                color: AppColors.accent,
                                dotSize: 6,
                              ),
                              const SizedBox(width: AppSizes.paddingM),
                              Text(
                                '編集画面を準備中',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// オプション選択カード（プランが見つからない場合など）
class _PlanOptionsCard extends StatelessWidget {
  const _PlanOptionsCard({
    required this.onCreateEmpty,
    required this.onRegenerate,
    required this.onBackToSelection,
  });

  final VoidCallback onCreateEmpty;
  final VoidCallback onRegenerate;
  final VoidCallback onBackToSelection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingXS,
        vertical: AppSizes.paddingXS,
      ),
      child: AppCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIcon(type: AppIconType.plan, size: 48),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              '気になるプランが\nありませんでしたか？',
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.paddingL),

            // 一から作成
            _OptionButton(
              icon: Icons.edit_note_rounded,
              label: '一からプランを決める',
              color: AppColors.subAccent,
              onTap: onCreateEmpty,
            ),
            const SizedBox(height: AppSizes.paddingM),

            // 再生成
            _OptionButton(
              icon: Icons.refresh_rounded,
              label: '別のプランを生成する',
              color: AppColors.accent,
              onTap: onRegenerate,
            ),
            const SizedBox(height: AppSizes.paddingM),

            // 戻る
            TextButton.icon(
              onPressed: onBackToSelection,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text('カード選択からやり直す', style: AppTypography.bodySmall),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
