import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/models/trip_member_model.dart';
import '../../../../shared/models/trip_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../shared/providers/guest_session_provider.dart';
import '../../data/repositories/trip_repository.dart';

const _uuid = Uuid();

/// 旅行リポジトリプロバイダー
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(firestore: ref.watch(firestoreProvider));
});

/// ゲスト用ローカル旅行ストレージ
final localTripsProvider =
    StateNotifierProvider<LocalTripsNotifier, List<TripModel>>((ref) {
      return LocalTripsNotifier();
    });

/// ローカル旅行ストレージのNotifier
class LocalTripsNotifier extends StateNotifier<List<TripModel>> {
  LocalTripsNotifier() : super([]);

  /// 旅行を追加
  String addTrip({
    required String title,
    required String createdBy,
    DateTime? startDate,
    DateTime? endDate,
    String? ownerName,
    String? ownerDeparture,
  }) {
    final tripId = _uuid.v4();
    final now = DateTime.now();

    final memberDetails = <String, TripMember>{};
    if (ownerName != null) {
      memberDetails[createdBy] = TripMember(
        userId: createdBy,
        displayName: ownerName,
        departurePoint: ownerDeparture,
        isManual: false,
      );
    }

    final trip = TripModel(
      id: tripId,
      title: title,
      createdBy: createdBy,
      members: [createdBy],
      memberDetails: memberDetails,
      startDate: startDate,
      endDate: endDate,
      status: TripStatus.collecting,
      createdAt: now,
      updatedAt: now,
    );
    state = [...state, trip];
    return tripId;
  }

  /// 旅行を取得
  TripModel? getTrip(String tripId) {
    return state.where((t) => t.id == tripId).firstOrNull;
  }

  /// 旅行を更新
  void updateTrip(TripModel trip) {
    state = state.map((t) => t.id == trip.id ? trip : t).toList();
  }

  /// 旅行を削除
  void deleteTrip(String tripId) {
    state = state.where((t) => t.id != tripId).toList();
  }

  /// プランを確定
  void confirmPlan(String tripId, String planId) {
    state =
        state.map((t) {
          if (t.id == tripId) {
            return t.copyWith(
              confirmedPlanId: planId,
              status: TripStatus.confirmed,
            );
          }
          return t;
        }).toList();
  }

  /// メンバー詳細を更新
  void updateMemberDetails(String tripId, String userId, TripMember member) {
    state =
        state.map((t) {
          if (t.id == tripId) {
            final newDetails = Map<String, TripMember>.from(t.memberDetails);
            newDetails[userId] = member;
            return t.copyWith(memberDetails: newDetails);
          }
          return t;
        }).toList();
  }
}

/// ユーザーの旅行一覧プロバイダー
final userTripsProvider = StreamProvider<List<TripModel>>((ref) {
  final isGuest = ref.watch(isGuestModeProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  // ゲストユーザーの場合はローカルストレージから取得
  if (isGuest && !isAuthenticated) {
    final localTrips = ref.watch(localTripsProvider);
    return Stream.value(localTrips);
  }

  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return ref.watch(tripRepositoryProvider).watchUserTrips(userId);
});

/// 旅行詳細プロバイダー
final tripDetailProvider = StreamProvider.family<TripModel?, String>((
  ref,
  tripId,
) {
  final isGuest = ref.watch(isGuestModeProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  // ゲストユーザーの場合はローカルストレージから取得
  if (isGuest && !isAuthenticated) {
    final localTrips = ref.watch(localTripsProvider);
    final localTrip = localTrips.where((t) => t.id == tripId).firstOrNull;
    return Stream.value(localTrip);
  }

  return ref.watch(tripRepositoryProvider).watchTrip(tripId);
});

/// 旅行コントローラープロバイダー
final tripControllerProvider =
    StateNotifierProvider<TripController, AsyncValue<void>>((ref) {
      return TripController(
        ref: ref,
        repository: ref.watch(tripRepositoryProvider),
        currentUserId: ref.watch(currentUserIdProvider),
        isGuest:
            ref.watch(isGuestModeProvider) &&
            !ref.watch(isAuthenticatedProvider),
      );
    });

/// 旅行コントローラー
class TripController extends StateNotifier<AsyncValue<void>> {
  TripController({
    required Ref ref,
    required TripRepository repository,
    required String? currentUserId,
    required bool isGuest,
  }) : _ref = ref,
       _repository = repository,
       _currentUserId = currentUserId,
       _isGuest = isGuest,
       super(const AsyncValue.data(null));

  final Ref _ref;
  final TripRepository _repository;
  final String? _currentUserId;
  final bool _isGuest;

  /// 旅行を作成
  Future<String?> createTrip({
    required String title,
    DateTime? startDate,
    DateTime? endDate,
    String? ownerName,
    String? ownerDeparture,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    state = const AsyncValue.loading();
    try {
      String tripId;

      if (_isGuest) {
        // ゲストユーザーはローカルストレージに保存
        tripId = _ref
            .read(localTripsProvider.notifier)
            .addTrip(
              title: title,
              createdBy: userId,
              startDate: startDate,
              endDate: endDate,
              ownerName: ownerName,
              ownerDeparture: ownerDeparture,
            );
      } else {
        // 認証済みユーザーはFirebaseに保存
        tripId = await _repository.createTrip(
          title: title,
          createdBy: userId,
          startDate: startDate,
          endDate: endDate,
          ownerName: ownerName,
          ownerDeparture: ownerDeparture,
        );
      }

      state = const AsyncValue.data(null);
      return tripId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// メンバーを招待
  Future<void> inviteMember(String tripId, String userId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.addMember(tripId, userId));
  }

  /// 旅行のステータスを更新
  Future<void> updateStatus(String tripId, TripStatus status) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.updateStatus(tripId, status),
    );
  }

  /// 旅行に参加（招待リンクから）
  Future<bool> joinTrip(String tripId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    state = const AsyncValue.loading();
    try {
      await _repository.addMember(tripId, userId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// 旅行を取得（招待リンク用）
  Future<TripModel?> getTrip(String tripId) async {
    return _repository.getTrip(tripId);
  }

  /// メンバー詳細を更新
  Future<void> updateMemberDetails(
    String tripId,
    String userId,
    TripMember member,
  ) async {
    if (_isGuest) {
      _ref
          .read(localTripsProvider.notifier)
          .updateMemberDetails(tripId, userId, member);
    } else {
      await _repository.updateMemberDetails(tripId, userId, member.toJson());
    }
  }
}
