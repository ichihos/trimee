import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/plan_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../data/repositories/plan_repository.dart';

/// プランリポジトリプロバイダー
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(firestore: ref.watch(firestoreProvider));
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
    required String title,
    String? description,
    List<PlanItem> items = const [],
  }) async {
    state = const AsyncValue.loading();
    try {
      final planId = await _repository.createPlan(
        tripId: tripId,
        title: title,
        description: description,
        items: items,
      );

      state = const AsyncValue.data(null);
      return planId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
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
    } catch (_) {}
  }

  /// アイテムリストのみ更新
  Future<void> updatePlanItems({
    required String tripId,
    required String planId,
    required List<PlanItem> items,
    String? editedByName,
  }) async {
    try {
      await _repository.updatePlanItems(
        tripId: tripId,
        planId: planId,
        items: items,
        editedByName: editedByName,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
}
