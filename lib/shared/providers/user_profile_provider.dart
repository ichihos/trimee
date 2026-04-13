import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile_model.dart';
import 'firebase_providers.dart';
import 'guest_session_provider.dart';

/// プロフィールリポジトリプロバイダー
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(firestore: ref.watch(firestoreProvider));
});

/// プロフィールリポジトリ
class UserProfileRepository {
  UserProfileRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _profilesCollection =>
      _firestore.collection('userProfiles');

  /// プロフィールを取得
  Future<UserProfileModel?> getProfile(String userId) async {
    final doc = await _profilesCollection.doc(userId).get();
    if (doc.exists) {
      return UserProfileModel.fromFirestore(doc);
    }
    return null;
  }

  /// プロフィールを作成/更新
  Future<void> saveProfile(UserProfileModel profile) async {
    await _profilesCollection
        .doc(profile.userId)
        .set(profile.toFirestore(), SetOptions(merge: true));
  }

  /// プロフィールを監視
  Stream<UserProfileModel?> watchProfile(String userId) {
    return _profilesCollection.doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfileModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// 複数ユーザーのプロフィールを取得
  Future<List<UserProfileModel>> getProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    // Firestoreの制限（in句は10件まで）に対応
    final profiles = <UserProfileModel>[];
    for (var i = 0; i < userIds.length; i += 10) {
      final batch = userIds.skip(i).take(10).toList();
      final snapshot =
          await _profilesCollection
              .where(FieldPath.documentId, whereIn: batch)
              .get();
      profiles.addAll(
        snapshot.docs.map((doc) => UserProfileModel.fromFirestore(doc)),
      );
    }
    return profiles;
  }
}

/// ゲスト用ローカルプロフィールストレージ
final localProfileProvider =
    StateNotifierProvider<LocalProfileNotifier, UserProfileModel?>((ref) {
      return LocalProfileNotifier();
    });

/// ローカルプロフィールのNotifier
class LocalProfileNotifier extends StateNotifier<UserProfileModel?> {
  LocalProfileNotifier() : super(null);

  /// プロフィールを設定
  void setProfile(UserProfileModel profile) {
    state = profile;
  }

  /// プロフィールを更新
  void updateProfile({
    String? displayName,
    AgeRange? ageRange,
    Gender? gender,
    List<TravelStyle>? travelStyles,
  }) {
    if (state == null) return;
    state = state!.copyWith(
      displayName: displayName ?? state!.displayName,
      ageRange: ageRange ?? state!.ageRange,
      gender: gender ?? state!.gender,
      travelStyles: travelStyles ?? state!.travelStyles,
      updatedAt: DateTime.now(),
    );
  }

  /// プロフィールがあるか
  bool get hasProfile => state != null;

  /// プロフィールが完成しているか（必須項目入力済み）
  /// 名前はチームごとに設定するため、年代のみ必須
  bool get isProfileComplete => state != null && state!.ageRange != null;
}

/// 単一ユーザーのプロフィールを取得するプロバイダー
final userProfileProvider = FutureProvider.family<UserProfileModel?, String>((
  ref,
  userId,
) async {
  final isGuest = ref.watch(isGuestModeProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  // ゲストで自分のIDの場合
  if (isGuest && !isAuthenticated && userId == currentUserId) {
    final localProfile = ref.watch(localProfileProvider);
    if (localProfile != null) {
      return localProfile;
    }
    // localProfileがなくてもguestSessionから名前を取得
    final guestName = ref.watch(guestNameProvider);
    if (guestName != null && guestName.isNotEmpty) {
      final now = DateTime.now();
      return UserProfileModel(
        userId: userId,
        displayName: guestName,
        createdAt: now,
        updatedAt: now,
      );
    }
    return null;
  }

  // 他のゲストユーザーのIDの場合（guest_で始まる）
  if (userId.startsWith('guest_')) {
    // Firestoreには存在しないのでnullを返す（将来的にはローカルキャッシュを使う）
    return null;
  }

  return ref.watch(userProfileRepositoryProvider).getProfile(userId);
});

/// 現在のユーザープロフィールプロバイダー
final currentUserProfileProvider = StreamProvider<UserProfileModel?>((ref) {
  final isGuest = ref.watch(isGuestModeProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  // ゲストの場合はローカルから
  if (isGuest && !isAuthenticated) {
    final localProfile = ref.watch(localProfileProvider);
    return Stream.value(localProfile);
  }

  // 認証済みの場合はFirebaseから
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);

  return ref.watch(userProfileRepositoryProvider).watchProfile(userId);
});

/// プロフィールがまだ読み込み中かどうか（認証済みユーザー向け）
final isProfileLoadingProvider = Provider<bool>((ref) {
  final isGuest = ref.watch(isGuestModeProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  if (isGuest && !isAuthenticated) return false;

  final profileAsync = ref.watch(currentUserProfileProvider);
  return profileAsync.isLoading;
});

/// プロフィールが完成しているかどうか
/// 名前はチームごとに設定するため、年代のみ必須
final isProfileCompleteProvider = Provider<bool>((ref) {
  final isGuest = ref.watch(isGuestModeProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  if (isGuest && !isAuthenticated) {
    // ゲストの場合は名前（localProfileまたはguestSession）があればOK
    final localProfile = ref.watch(localProfileProvider);
    if (localProfile != null) return true;

    final guestName = ref.watch(guestNameProvider);
    return guestName != null && guestName.isNotEmpty;
  }

  final profileAsync = ref.watch(currentUserProfileProvider);
  return profileAsync.when(
    data: (profile) => profile != null, // 名前があればOKとする
    loading: () => false,
    error: (_, __) => false,
  );
});

/// プロフィールコントローラープロバイダー
final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<void>>((ref) {
      return ProfileController(
        ref: ref,
        repository: ref.watch(userProfileRepositoryProvider),
        currentUserId: ref.watch(currentUserIdProvider),
        isGuest:
            ref.watch(isGuestModeProvider) &&
            !ref.watch(isAuthenticatedProvider),
      );
    });

/// プロフィールコントローラー
class ProfileController extends StateNotifier<AsyncValue<void>> {
  ProfileController({
    required Ref ref,
    required UserProfileRepository repository,
    required String? currentUserId,
    required bool isGuest,
  }) : _ref = ref,
       _repository = repository,
       _currentUserId = currentUserId,
       _isGuest = isGuest,
       super(const AsyncValue.data(null));

  final Ref _ref;
  final UserProfileRepository _repository;
  final String? _currentUserId;
  final bool _isGuest;

  /// プロフィールを保存
  Future<bool> saveProfile({
    required String displayName,
    AgeRange? ageRange,
    Gender? gender,
    List<TravelStyle> travelStyles = const [],
  }) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    state = const AsyncValue.loading();
    try {
      final now = DateTime.now();
      final profile = UserProfileModel(
        userId: userId,
        displayName: displayName,
        ageRange: ageRange,
        gender: gender,
        travelStyles: travelStyles,
        createdAt: now,
        updatedAt: now,
      );

      if (_isGuest) {
        _ref.read(localProfileProvider.notifier).setProfile(profile);
      } else {
        await _repository.saveProfile(profile);
      }

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// 旅行メンバーのプロフィールを取得
  Future<List<UserProfileModel>> getMemberProfiles(
    List<String> memberIds,
  ) async {
    if (_isGuest) {
      // ゲストの場合は自分のプロフィールのみ
      final localProfile = _ref.read(localProfileProvider);
      if (localProfile != null && memberIds.contains(localProfile.userId)) {
        return [localProfile];
      }
      return [];
    }
    return _repository.getProfiles(memberIds);
  }
}
