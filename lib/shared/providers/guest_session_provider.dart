import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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
    String? departurePoint, // Add departurePoint
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

/// ゲストセッションプロバイダー
final guestSessionProvider =
    StateNotifierProvider<GuestSessionNotifier, GuestSession?>((ref) {
      return GuestSessionNotifier();
    });

/// ゲストセッション管理
class GuestSessionNotifier extends StateNotifier<GuestSession?> {
  GuestSessionNotifier() : super(null);

  static const _uuid = Uuid();

  /// ゲストとして開始（名前なし）
  void startAsGuest() {
    state = GuestSession(id: 'guest_${_uuid.v4()}', name: '', isActive: true);
  }

  /// 名前と出発地を設定
  void setUserInfo({required String name, String? departurePoint}) {
    if (state != null) {
      state = state!.copyWith(name: name, departurePoint: departurePoint);
    } else {
      state = GuestSession(
        id: 'guest_${_uuid.v4()}',
        name: name,
        departurePoint: departurePoint,
        isActive: true,
      );
    }
  }

  /// 名前を設定（互換性維持）
  void setName(String name) => setUserInfo(name: name);

  /// セッション終了（ログイン時など）
  void endSession() {
    state = null;
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
