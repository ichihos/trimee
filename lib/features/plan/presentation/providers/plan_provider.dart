import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/models/plan_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../shared/providers/guest_session_provider.dart';
import '../../../trip/presentation/providers/trip_provider.dart';
import '../../data/repositories/plan_repository.dart';

const _uuid = Uuid();

/// プランリポジトリプロバイダー
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(firestore: ref.watch(firestoreProvider));
});

/// ゲスト用ローカルプランストレージ
final localPlansProvider =
    StateNotifierProvider<LocalPlansNotifier, Map<String, List<PlanModel>>>((
      ref,
    ) {
      return LocalPlansNotifier();
    });

/// ローカルプランストレージのNotifier
class LocalPlansNotifier extends StateNotifier<Map<String, List<PlanModel>>> {
  LocalPlansNotifier() : super({});

  /// プランを追加
  String addPlan({
    required String tripId,
    required String title,
    String? description,
    List<PlanItem> items = const [],
    List<String> includedCards = const [],
    List<String> excludedCards = const [],
  }) {
    final planId = _uuid.v4();
    final plan = PlanModel(
      id: planId,
      tripId: tripId,
      title: title,
      description: description,
      items: items,
      includedCards: includedCards,
      excludedCards: excludedCards,
      votes: {},
      createdAt: DateTime.now(),
    );
    final tripPlans = state[tripId] ?? [];
    state = {
      ...state,
      tripId: [...tripPlans, plan],
    };
    return planId;
  }

  /// プラン一覧を取得
  List<PlanModel> getPlans(String tripId) {
    return state[tripId] ?? [];
  }

  /// プランを更新
  void updatePlan({required String tripId, required PlanModel plan}) {
    final tripPlans = state[tripId] ?? [];
    final updatedPlans =
        tripPlans.map((p) => p.id == plan.id ? plan : p).toList();
    state = {...state, tripId: updatedPlans};
  }

  /// プランに投票
  void vote(String tripId, String planId, String userId, bool approve) {
    final tripPlans = state[tripId] ?? [];
    final updatedPlans =
        tripPlans.map((plan) {
          if (plan.id == planId) {
            final newVotes = Map<String, bool>.from(plan.votes);
            newVotes[userId] = approve;
            return plan.copyWith(votes: newVotes);
          }
          return plan;
        }).toList();
    state = {...state, tripId: updatedPlans};
  }
}

/// 旅行のプラン一覧プロバイダー
final tripPlansProvider = StreamProvider.family<List<PlanModel>, String>((
  ref,
  tripId,
) {
  final isGuest = ref.watch(isGuestModeProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  // ゲストユーザーの場合はローカルストレージから取得
  if (isGuest && !isAuthenticated) {
    final localPlans = ref.watch(localPlansProvider)[tripId] ?? [];
    return Stream.value(localPlans);
  }

  return ref.watch(planRepositoryProvider).watchPlans(tripId);
});

/// 単一プランのリアルタイム監視プロバイダー
final watchPlanProvider = StreamProvider.family<
  PlanModel?,
  ({String tripId, String planId})
>((ref, args) {
  final isGuest = ref.watch(isGuestModeProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  if (isGuest && !isAuthenticated) {
    final localPlans = ref.watch(localPlansProvider)[args.tripId] ?? [];
    final plan = localPlans.where((p) => p.id == args.planId).firstOrNull;
    return Stream.value(plan);
  }

  return ref.watch(planRepositoryProvider).watchPlan(args.tripId, args.planId);
});

/// プランコントローラープロバイダー
final planControllerProvider =
    StateNotifierProvider<PlanController, AsyncValue<void>>((ref) {
      return PlanController(
        ref: ref,
        repository: ref.watch(planRepositoryProvider),
        currentUserId: ref.watch(currentUserIdProvider),
        isGuest:
            ref.watch(isGuestModeProvider) &&
            !ref.watch(isAuthenticatedProvider),
      );
    });

/// プランコントローラー
class PlanController extends StateNotifier<AsyncValue<void>> {
  PlanController({
    required Ref ref,
    required PlanRepository repository,
    required String? currentUserId,
    required bool isGuest,
  }) : _ref = ref,
       _repository = repository,
       _currentUserId = currentUserId,
       _isGuest = isGuest,
       super(const AsyncValue.data(null));

  final Ref _ref;
  final PlanRepository _repository;
  final String? _currentUserId;
  final bool _isGuest;

  /// プランを作成
  Future<String?> createPlan({
    required String tripId,
    required PlanModel plan,
  }) async {
    state = const AsyncValue.loading();
    try {
      String planId;

      if (_isGuest) {
        // ゲストユーザーはローカルストレージに保存
        planId = _ref
            .read(localPlansProvider.notifier)
            .addPlan(
              tripId: tripId,
              title: plan.title,
              description: plan.description,
              items: plan.items,
              includedCards: plan.includedCards,
              excludedCards: plan.excludedCards,
            );
      } else {
        // 認証済みユーザーはFirebaseに保存
        planId = await _repository.createPlan(
          tripId: tripId,
          title: plan.title,
          description: plan.description,
          items: plan.items,
          includedCards: plan.includedCards,
          excludedCards: plan.excludedCards,
        );
      }

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
      if (_isGuest) {
        _ref
            .read(localPlansProvider.notifier)
            .vote(tripId, planId, userId, approve);
        state = const AsyncValue.data(null);
      } else {
        state = await AsyncValue.guard(
          () => _repository.vote(
            tripId: tripId,
            planId: planId,
            userId: userId,
            approve: approve,
          ),
        );
      }
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
      if (_isGuest) {
        // ゲストユーザーはローカルストレージを更新
        _ref.read(localTripsProvider.notifier).confirmPlan(tripId, planId);
        state = const AsyncValue.data(null);
      } else {
        // 認証済みユーザーはFirestoreを更新
        await _repository.confirmPlan(tripId, planId);
        state = const AsyncValue.data(null);
      }
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
      if (_isGuest) {
        _ref
            .read(localPlansProvider.notifier)
            .updatePlan(tripId: tripId, plan: plan);
        state = const AsyncValue.data(null);
      } else {
        await _repository.updatePlan(tripId: tripId, plan: plan);
        state = const AsyncValue.data(null);
      }
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
    if (_isGuest) return;
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

  /// 編集中プランIDを設定（旅行ドキュメントに保存）
  Future<void> setEditingPlanId({
    required String tripId,
    required String? planId,
  }) async {
    if (_isGuest) {
      // ゲストユーザーはローカルストレージを更新
      final trips = _ref.read(localTripsProvider);
      final trip = trips.firstWhere((t) => t.id == tripId);
      _ref
          .read(localTripsProvider.notifier)
          .updateTrip(trip.copyWith(editingPlanId: planId));
    } else {
      await _repository.setEditingPlanId(tripId, planId);
    }
  }
}
