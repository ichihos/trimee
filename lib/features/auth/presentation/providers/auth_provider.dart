import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../shared/providers/guest_session_provider.dart';
import '../../../../shared/providers/user_profile_provider.dart';

/// 認証状態プロバイダー
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// 認証コントローラープロバイダー
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      return AuthController(ref.watch(authRepositoryProvider), ref);
    });

/// 認証コントローラー
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._repository, this._ref)
    : super(const AsyncValue.data(null));

  final AuthRepository _repository;
  final Ref _ref;

  /// Googleでサインイン
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final credential = await _repository.signInWithGoogle();
      await _migrateGuestProfile(credential.user!.uid);
    });
  }

  /// Appleでサインイン
  Future<void> signInWithApple() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final credential = await _repository.signInWithApple();
      await _migrateGuestProfile(credential.user!.uid);
    });
  }

  /// メールでサインイン
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final credential = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      await _migrateGuestProfile(credential.user!.uid);
    });
  }

  /// メールでアカウント作成
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final credential = await _repository.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      await _migrateGuestProfile(credential.user!.uid);
    });
  }

  /// 匿名アカウントをGoogleにリンク（データ継承）
  Future<bool> linkWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      await _repository.linkWithGoogle();
      _finalizeAccountLink();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// 匿名アカウントをAppleにリンク（データ継承）
  Future<bool> linkWithApple() async {
    state = const AsyncValue.loading();
    try {
      await _repository.linkWithApple();
      _finalizeAccountLink();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// 匿名アカウントをメールにリンク（データ継承）
  Future<bool> linkWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.linkWithEmail(
        email: email,
        password: password,
        name: name,
      );
      _finalizeAccountLink();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// サインアウト
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.signOut());
  }

  /// アカウントリンク完了後の処理（UIDは同じなのでデータ移行不要）
  void _finalizeAccountLink() {
    final localProfile = _ref.read(localProfileProvider);
    if (localProfile != null) {
      final repository = _ref.read(userProfileRepositoryProvider);
      repository.saveProfile(localProfile);
    }
    _ref.read(guestSessionProvider.notifier).endSession();
  }

  /// ゲストプロファイルをFirestoreに移行（新規サインイン用）
  Future<void> _migrateGuestProfile(String newUserId) async {
    final localProfile = _ref.read(localProfileProvider);
    if (localProfile == null) return;

    final repository = _ref.read(userProfileRepositoryProvider);
    final now = DateTime.now();
    final migratedProfile = localProfile.copyWith(
      userId: newUserId,
      updatedAt: now,
    );
    await repository.saveProfile(migratedProfile);

    _ref.read(guestSessionProvider.notifier).endSession();
    _ref.read(localProfileProvider.notifier).setProfile(migratedProfile);
  }
}
