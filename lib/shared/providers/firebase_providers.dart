import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'guest_session_provider.dart';

/// Firebase Auth プロバイダー
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Firestore プロバイダー
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Firebase Storage プロバイダー
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

/// 認証状態のストリームプロバイダー
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// 現在のユーザーIDプロバイダー（Firebase認証 or ゲストID）
final currentUserIdProvider = Provider<String?>((ref) {
  // Firebase認証ユーザー優先
  final authState = ref.watch(authStateProvider);

  // ローディング中はFirebase Authの現在のユーザーを直接チェック
  if (authState.isLoading) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      return currentUser.uid;
    }
  } else if (authState.value != null) {
    return authState.value!.uid;
  }

  // ゲストセッション
  final guestSession = ref.watch(guestSessionProvider);
  if (guestSession != null && guestSession.isActive) {
    return guestSession.id;
  }

  return null;
});

/// ログイン済み（Firebase認証）かどうか
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  // ローディング中はFirebase Authの現在のユーザーを直接チェック
  if (authState.isLoading) {
    return FirebaseAuth.instance.currentUser != null;
  }
  return authState.value != null;
});

/// 現在のユーザー名
final currentUserNameProvider = Provider<String?>((ref) {
  // Firebase認証ユーザー
  final firebaseUser = ref.watch(authStateProvider).value;
  if (firebaseUser != null) {
    return firebaseUser.displayName;
  }

  // ゲスト名
  final guestSession = ref.watch(guestSessionProvider);
  return guestSession?.name;
});
