import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/providers/firebase_providers.dart';

/// 認証リポジトリプロバイダー
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

/// 認証リポジトリ
class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// 現在のユーザー
  User? get currentUser => _auth.currentUser;

  /// 認証状態の監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Googleでサインイン（プラットフォーム対応）
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: ポップアップ認証
      final googleProvider = GoogleAuthProvider();
      final credential = await _auth.signInWithPopup(googleProvider);
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException.fromErrorCode('user-cancelled');
      }
      await _createUserDocument(user);
      return credential;
    } else {
      // Mobile (iOS/Android): google_sign_in パッケージ使用
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw FirebaseAuthException.fromErrorCode('user-cancelled');
      }

      final googleAuth = await googleUser.authentication;

      // accessTokenまたはidTokenがnullの場合はエラー
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        throw FirebaseAuthException.fromErrorCode('invalid-credential');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _createUserDocument(userCredential.user!);
      return userCredential;
    }
  }

  /// Appleでサインイン（iOS/Web対応）
  Future<UserCredential> signInWithApple() async {
    if (kIsWeb) {
      // Web: Firebase直接認証
      final appleProvider = OAuthProvider('apple.com');
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      final credential = await _auth.signInWithPopup(appleProvider);
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException.fromErrorCode('user-cancelled');
      }
      await _createUserDocument(user);
      return credential;
    } else {
      // iOS: sign_in_with_apple パッケージ使用
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Appleは初回のみ名前を返すため、ここで保存
      final displayName = appleCredential.givenName != null
          ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
          : null;

      await _createUserDocument(userCredential.user!, name: displayName);
      return userCredential;
    }
  }

  /// メールとパスワードでサインイン
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// メールとパスワードでアカウント作成
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user!.updateDisplayName(name);
    await _createUserDocument(credential.user!, name: name);
    return credential;
  }

  /// 匿名アカウントをGoogleにリンク（UIDを維持）
  Future<UserCredential> linkWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw FirebaseAuthException.fromErrorCode('invalid-user');
    }

    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      final credential = await user.linkWithPopup(googleProvider);
      await _createUserDocument(credential.user!);
      return credential;
    } else {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException.fromErrorCode('user-cancelled');
      }
      final googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        throw FirebaseAuthException.fromErrorCode('invalid-credential');
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await user.linkWithCredential(credential);
      await _createUserDocument(userCredential.user!);
      return userCredential;
    }
  }

  /// 匿名アカウントをAppleにリンク（UIDを維持）
  Future<UserCredential> linkWithApple() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw FirebaseAuthException.fromErrorCode('invalid-user');
    }

    if (kIsWeb) {
      final appleProvider = OAuthProvider('apple.com');
      appleProvider.addScope('email');
      appleProvider.addScope('name');
      final credential = await user.linkWithPopup(appleProvider);
      await _createUserDocument(credential.user!);
      return credential;
    } else {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      final userCredential = await user.linkWithCredential(oauthCredential);
      final displayName = appleCredential.givenName != null
          ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
          : null;
      await _createUserDocument(userCredential.user!, name: displayName);
      return userCredential;
    }
  }

  /// 匿名アカウントをメール/パスワードにリンク（UIDを維持）
  Future<UserCredential> linkWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw FirebaseAuthException.fromErrorCode('invalid-user');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    final userCredential = await user.linkWithCredential(credential);
    await userCredential.user!.updateDisplayName(name);
    await _createUserDocument(userCredential.user!, name: name);
    return userCredential;
  }

  /// サインアウト
  Future<void> signOut() async {
    // Googleサインアウト
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // Google Sign-Inが初期化されていない場合は無視
      }
    }
    await _auth.signOut();
  }

  /// ユーザードキュメントを作成
  Future<void> _createUserDocument(User user, {String? name}) async {
    // uidがnullまたは空の場合はエラー
    final uid = user.uid;
    if (uid.isEmpty) {
      throw FirebaseAuthException.fromErrorCode('invalid-user');
    }

    final docRef = _firestore.collection('users').doc(uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      // すべての文字列を安全に取得
      final userName = name ?? user.displayName ?? '';
      final userEmail = user.email ?? '';
      final userPhotoUrl = user.photoURL;

      final userModel = UserModel(
        id: uid,
        name: userName,
        email: userEmail,
        photoUrl: userPhotoUrl,
        createdAt: DateTime.now(),
      );
      await docRef.set(userModel.toFirestore());
    }
  }

  /// ユーザー情報を取得
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  /// ユーザー情報を更新
  Future<void> updateUser(UserModel user) async {
    await _firestore.collection('users').doc(user.id).update(user.toFirestore());
  }

  /// ランダムなnonce生成（Apple Sign-In用）
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// SHA256ハッシュ生成（Apple Sign-In用）
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

/// Firebase Auth例外のカスタムクラス
class FirebaseAuthException implements Exception {
  final String code;
  final String? message;

  FirebaseAuthException(this.code, [this.message]);

  factory FirebaseAuthException.fromErrorCode(String code) {
    return FirebaseAuthException(code, _getMessageFromCode(code));
  }

  static String _getMessageFromCode(String code) {
    switch (code) {
      case 'user-cancelled':
        return 'ログインがキャンセルされました';
      case 'invalid-credential':
        return '認証情報の取得に失敗しました。もう一度お試しください';
      case 'invalid-user':
        return 'ユーザー情報の取得に失敗しました。もう一度お試しください';
      default:
        return '認証エラーが発生しました';
    }
  }

  @override
  String toString() => message ?? code;
}
