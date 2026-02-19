import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/plan_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../data/repositories/plan_repository.dart';

/// プランリポジトリプロバイダー
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(firestore: ref.watch(firestoreProvider));
});

/// 旅行のプラン一覧プロバイダー
final tripPlansProvider = StreamProvider.family<List<PlanModel>, String>((
  ref,
  tripId,
) {
  return ref.watch(planRepositoryProvider).watchPlans(tripId);
});

/// 単一プランのリアルタイム監視プロバイダー
final watchPlanProvider = StreamProvider.family<
  PlanModel?,
  ({String tripId, String planId})
>((ref, args) {
  return ref.watch(planRepositoryProvider).watchPlan(args.tripId, args.planId);
});

/// プランコントローラープロバイダー
final planControllerProvider =
    StateNotifierProvider<PlanController, AsyncValue<void>>((ref) {
      return PlanController(
        repository: ref.watch(planRepositoryProvider),
        currentUserId: ref.watch(currentUserIdProvider),
      );
    });

/// プランコントローラー
class PlanController extends StateNotifier<AsyncValue<void>> {
  PlanController({
    required PlanRepository repository,
    required String? currentUserId,
  }) : _repository = repository,
       _currentUserId = currentUserId,
       super(const AsyncValue.data(null));

  final PlanRepository _repository;
  final String? _currentUserId;

  /// プランを作成
  Future<String?> createPlan({
    required String tripId,
    required PlanModel plan,
  }) async {
    state = const AsyncValue.loading();
    try {
      final planId = await _repository.createPlan(
        tripId: tripId,
        title: plan.title,
        description: plan.description,
        items: plan.items,
        includedCards: plan.includedCards,
        excludedCards: plan.excludedCards,
      );

      state = const AsyncValue.data(null);
      return planId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// プランに投票
  Future<void> vote({
    required String tripId,
    required String planId,
    required bool approve,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;

    state = const AsyncValue.loading();
    try {
      state = await AsyncValue.guard(
        () => _repository.vote(
          tripId: tripId,
          planId: planId,
          userId: userId,
          approve: approve,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// プランを確定
  Future<void> confirmPlan({
    required String tripId,
    required String planId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.confirmPlan(tripId, planId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// プランを更新
  Future<void> updatePlan({
    required String tripId,
    required PlanModel plan,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updatePlan(tripId: tripId, plan: plan);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 編集プレゼンスを設定
  Future<void> setEditingPresence({
    required String tripId,
    required String planId,
    required String? userId,
    String? userName,
  }) async {
    try {
      await _repository.setEditingPresence(
        tripId: tripId,
        planId: planId,
        userId: userId,
        userName: userName,
      );
    } catch (_) {
      // プレゼンス更新の失敗は無視
    }
  }

  /// タイトルのみ更新
  Future<void> updatePlanTitle({
    required String tripId,
    required String planId,
    required String title,
  }) async {
    try {
      await _repository.updatePlanTitle(
        tripId: tripId,
        planId: planId,
        title: title,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 説明のみ更新
  Future<void> updatePlanDescription({
    required String tripId,
    required String planId,
    required String description,
  }) async {
    try {
      await _repository.updatePlanDescription(
        tripId: tripId,
        planId: planId,
        description: description,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// アイテムリストのみ更新
  Future<void> updatePlanItems({
    required String tripId,
    required String planId,
    required List<PlanItem> items,
  }) async {
    try {
      await _repository.updatePlanItems(
        tripId: tripId,
        planId: planId,
        items: items,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// プランのアイコンのみ更新
  Future<void> updatePlanIcon({
    required String tripId,
    required String planId,
    required String? iconUrl,
  }) async {
    try {
      await _repository.updatePlanIcon(
        tripId: tripId,
        planId: planId,
        iconUrl: iconUrl,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 編集中プランIDを設定（旅行ドキュメントに保存）
  Future<void> setEditingPlanId({
    required String tripId,
    required String? planId,
  }) async {
    await _repository.setEditingPlanId(tripId, planId);
  }
}
