import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/card_model.dart';
import '../../../../shared/models/user_profile_model.dart';
import '../../../../shared/services/ai_service.dart';
import 'plan_provider.dart';

/// プラン生成の状態
class PlanGenerationState {
  final bool isGenerating;
  final bool isAnalyzing;
  final CardAnalysis? cardAnalysis;
  final List<GeneratedPlan> streamingPlans;
  final String? currentPlanTitle;
  final List<PlanItemData> generatingItems;
  final String? error;

  const PlanGenerationState({
    this.isGenerating = false,
    this.isAnalyzing = false,
    this.cardAnalysis,
    this.streamingPlans = const [],
    this.currentPlanTitle,
    this.generatingItems = const [],
    this.error,
  });

  PlanGenerationState copyWith({
    bool? isGenerating,
    bool? isAnalyzing,
    CardAnalysis? cardAnalysis,
    List<GeneratedPlan>? streamingPlans,
    String? currentPlanTitle,
    List<PlanItemData>? generatingItems,
    String? error,
  }) {
    return PlanGenerationState(
      isGenerating: isGenerating ?? this.isGenerating,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      cardAnalysis: cardAnalysis ?? this.cardAnalysis,
      streamingPlans: streamingPlans ?? this.streamingPlans,
      currentPlanTitle: currentPlanTitle,
      generatingItems: generatingItems ?? this.generatingItems,
      error: error,
    );
  }

  PlanGenerationState update({
    bool? isGenerating,
    bool? isAnalyzing,
    CardAnalysis? cardAnalysis,
    bool clearCardAnalysis = false,
    List<GeneratedPlan>? streamingPlans,
    String? currentPlanTitle,
    bool clearCurrentPlanTitle = false,
    List<PlanItemData>? generatingItems,
    String? error,
    bool clearError = false,
  }) {
    return PlanGenerationState(
      isGenerating: isGenerating ?? this.isGenerating,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      cardAnalysis:
          clearCardAnalysis
              ? null
              : (cardAnalysis ?? this.cardAnalysis),
      streamingPlans: streamingPlans ?? this.streamingPlans,
      currentPlanTitle:
          clearCurrentPlanTitle
              ? null
              : (currentPlanTitle ?? this.currentPlanTitle),
      generatingItems: generatingItems ?? this.generatingItems,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// プラン生成状態管理プロバイダー
final planGenerationProvider = StateNotifierProvider.family<
  PlanGenerationNotifier,
  PlanGenerationState,
  String
>((ref, tripId) {
  return PlanGenerationNotifier(ref, tripId);
});

class PlanGenerationNotifier extends StateNotifier<PlanGenerationState> {
  final Ref _ref;
  final String _tripId;

  PlanGenerationNotifier(this._ref, this._tripId)
    : super(const PlanGenerationState());

  /// カード分析を開始（Flash使用・高速）
  /// プラン生成と並行して実行し、ローディング中にインサイトを表示する
  Future<void> analyzeCards({
    required List<CardModel> cards,
    required List<UserProfileModel> memberProfiles,
    required Map<String, String> userIdToName,
  }) async {
    state = state.update(isAnalyzing: true);
    try {
      final aiService = _ref.read(aiServiceProvider);
      final analysis = await aiService.analyzeCards(
        cards: cards,
        memberProfiles: memberProfiles,
        userIdToName: userIdToName,
      );
      if (mounted) {
        state = state.update(isAnalyzing: false, cardAnalysis: analysis);
      }
    } catch (_) {
      if (mounted) {
        state = state.update(isAnalyzing: false);
      }
    }
  }

  /// 生成を開始する（AI Serviceを呼び出す）
  Future<void> startGeneration({
    required String tripTitle,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<CardModel> cards,
    required List<UserProfileModel> memberProfiles,
    required Map<String, String> userIdToName,
    Map<String, String>? memberDepartures,
  }) async {
    if (state.isGenerating) return;

    state = state.update(isGenerating: true, streamingPlans: [], generatingItems: [], clearCurrentPlanTitle: true);

    try {
      final aiService = _ref.read(aiServiceProvider);

      await for (final event in aiService.generateWithRealTimeStream(
        tripTitle: tripTitle,
        startDate: startDate,
        endDate: endDate,
        cards: cards,
        memberProfiles: memberProfiles,
        userIdToName: userIdToName,
        memberDepartures: memberDepartures,
      )) {
        switch (event) {
          case GenerationStarted():
            break;

          case GenerationTextChunk():
            break;

          case GenerationPlanStarted(:final title):
            state = state.update(currentPlanTitle: title, generatingItems: []);
            break;

          case GenerationItemGenerated(:final item):
            state = state.update(
              generatingItems: [...state.generatingItems, item],
            );
            break;

          case GenerationPlanCompleted(:final plan):
            if (!state.streamingPlans.any(
              (p) => p.title == plan.title && p.type == plan.type,
            )) {
              state = state.update(
                streamingPlans: [...state.streamingPlans, plan],
                clearCurrentPlanTitle: true,
                generatingItems: [],
              );
            } else {
              state = state.update(
                clearCurrentPlanTitle: true,
                generatingItems: [],
              );
            }
            break;

          case GenerationCompleted(:final plans):
            state = state.update(isGenerating: false, streamingPlans: plans);

            try {
              final planController = _ref.read(planControllerProvider.notifier);
              for (final plan in plans) {
                await planController.createPlan(
                  tripId: _tripId,
                  plan: plan.toPlanModel(_tripId),
                );
              }
            } catch (e) {
              state = state.update(error: 'プランの保存に失敗しました: $e');
            }
            break;

          case GenerationError(:final message):
            state = state.update(error: message);
            break;
        }
      }
    } catch (e) {
      state = state.update(isGenerating: false, error: e.toString());
    } finally {
      if (state.isGenerating) {
        state = state.update(isGenerating: false);
      }
    }
  }

  /// 生成状態をリセット
  void reset() {
    state = const PlanGenerationState();
  }

  /// エラーをクリア
  void clearError() {
    state = state.update(clearError: true);
  }
}
