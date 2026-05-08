import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/trip_member_model.dart';
import '../../../../shared/models/trip_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../data/repositories/trip_repository.dart';

/// しおりリポジトリプロバイダー
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(firestore: ref.watch(firestoreProvider));
});

/// ユーザーのしおり一覧プロバイダー
final userTripsProvider = StreamProvider<List<TripModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return ref.watch(tripRepositoryProvider).watchUserTrips(userId);
});

/// しおり詳細プロバイダー
final tripDetailProvider = StreamProvider.family<TripModel?, String>((
  ref,
  tripId,
) {
  return ref.watch(tripRepositoryProvider).watchTrip(tripId);
});

/// しおりコントローラープロバイダー
final tripControllerProvider =
    StateNotifierProvider<TripController, AsyncValue<void>>((ref) {
      return TripController(
        repository: ref.watch(tripRepositoryProvider),
        currentUserId: ref.watch(currentUserIdProvider),
      );
    });

/// しおりコントローラー
class TripController extends StateNotifier<AsyncValue<void>> {
  TripController({
    required TripRepository repository,
    required String? currentUserId,
  }) : _repository = repository,
       _currentUserId = currentUserId,
       super(const AsyncValue.data(null));

  final TripRepository _repository;
  final String? _currentUserId;

  /// しおりを作成
  Future<String?> createTrip({
    required String title,
    DateTime? startDate,
    DateTime? endDate,
    String? ownerName,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    state = const AsyncValue.loading();
    try {
      final tripId = await _repository.createTrip(
        title: title,
        createdBy: userId,
        startDate: startDate,
        endDate: endDate,
        ownerName: ownerName,
      );

      state = const AsyncValue.data(null);
      return tripId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// しおりに参加（招待リンクから）
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

  /// しおりを取得
  Future<TripModel?> getTrip(String tripId) async {
    return _repository.getTrip(tripId);
  }

  /// メンバー詳細を更新
  Future<void> updateMemberDetails(
    String tripId,
    String userId,
    TripMember member,
  ) async {
    await _repository.updateMemberDetails(tripId, userId, member.toJson());
  }
}
