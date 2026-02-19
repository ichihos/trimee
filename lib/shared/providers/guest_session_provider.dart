import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ゲストセッション状態
class GuestSession {
  const GuestSession({
    required this.id,
    required this.name,
    this.departurePoint,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? departurePoint;
  final bool isActive;

  GuestSession copyWith({
    String? id,
    String? name,
    String? departurePoint,
    bool? isActive,
  }) {
    return GuestSession(
      id: id ?? this.id,
      name: name ?? this.name,
      departurePoint: departurePoint ?? this.departurePoint,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// SharedPreferencesのキー
const _kGuestName = 'guest_name';
const _kGuestDeparture = 'guest_departure';
const _kGuestIsActive = 'guest_is_active';

/// ゲストセッションプロバイダー
final guestSessionProvider =
    StateNotifierProvider<GuestSessionNotifier, GuestSession?>((ref) {
      return GuestSessionNotifier();
    });

/// ゲストセッション管理
class GuestSessionNotifier extends StateNotifier<GuestSession?> {
  GuestSessionNotifier() : super(null);

  SharedPreferences? _prefs;

  /// SharedPreferencesを設定
  void setPrefs(SharedPreferences prefs) {
    _prefs = prefs;
  }

  /// 起動時にセッションを復元（リロード対策）
  void restoreSession(SharedPreferences prefs) {
    _prefs = prefs;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // 匿名ユーザーの場合のみゲストセッションを復元
    if (currentUser.isAnonymous) {
      final name = prefs.getString(_kGuestName) ?? '';
      final departure = prefs.getString(_kGuestDeparture);
      final isActive = prefs.getBool(_kGuestIsActive) ?? false;
      if (isActive) {
        state = GuestSession(
          id: currentUser.uid,
          name: name,
          departurePoint: departure,
          isActive: true,
        );
      }
    }
  }

  /// ゲストとして開始（Firebase Anonymous Auth）
  Future<void> startAsGuest() async {
    try {
      final credential = await FirebaseAuth.instance.signInAnonymously();
      final uid = credential.user!.uid;
      state = GuestSession(id: uid, name: '', isActive: true);
      _prefs?.setBool(_kGuestIsActive, true);
    } catch (e) {
      debugPrint('Anonymous auth failed: $e');
      // フォールバック: ローカルIDで開始
      final uid = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      state = GuestSession(id: uid, name: '', isActive: true);
      _prefs?.setBool(_kGuestIsActive, true);
    }
  }

  /// 名前と出発地を設定
  void setUserInfo({required String name, String? departurePoint}) {
    if (state != null) {
      state = state!.copyWith(name: name, departurePoint: departurePoint);
    } else {
      final uid =
          FirebaseAuth.instance.currentUser?.uid ??
          'guest_${DateTime.now().millisecondsSinceEpoch}';
      state = GuestSession(
        id: uid,
        name: name,
        departurePoint: departurePoint,
        isActive: true,
      );
    }
    // SharedPreferencesに保存
    _prefs?.setString(_kGuestName, name);
    if (departurePoint != null) {
      _prefs?.setString(_kGuestDeparture, departurePoint);
    }
    _prefs?.setBool(_kGuestIsActive, true);
  }

  /// 名前を設定（互換性維持）
  void setName(String name) => setUserInfo(name: name);

  /// セッション終了（ログイン時など）
  void endSession() {
    state = null;
    _prefs?.remove(_kGuestName);
    _prefs?.remove(_kGuestDeparture);
    _prefs?.setBool(_kGuestIsActive, false);
  }

  /// ゲストかどうか
  bool get isGuest => state != null && state!.isActive;

  /// 名前が設定されているか
  bool get hasName => state != null && state!.name.isNotEmpty;
}

/// ゲストモードかどうか
final isGuestModeProvider = Provider<bool>((ref) {
  final guestSession = ref.watch(guestSessionProvider);
  return guestSession != null && guestSession.isActive;
});

/// ゲスト名
final guestNameProvider = Provider<String?>((ref) {
  final guestSession = ref.watch(guestSessionProvider);
  return guestSession?.name;
});
