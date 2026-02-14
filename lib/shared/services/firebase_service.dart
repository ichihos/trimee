import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firebaseサービスのシングルトン
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  /// Firestore インスタンス
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Firebase Auth インスタンス
  FirebaseAuth get auth => FirebaseAuth.instance;

  /// Firebase Storage インスタンス
  FirebaseStorage get storage => FirebaseStorage.instance;

  /// 現在のユーザー
  User? get currentUser => auth.currentUser;

  /// 現在のユーザーID
  String? get currentUserId => currentUser?.uid;

  /// ログイン状態の監視
  Stream<User?> get authStateChanges => auth.authStateChanges();

  // コレクション参照
  CollectionReference<Map<String, dynamic>> get usersCollection =>
      firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get tripsCollection =>
      firestore.collection('trips');

  /// 旅行のカードコレクション
  CollectionReference<Map<String, dynamic>> cardsCollection(String tripId) =>
      tripsCollection.doc(tripId).collection('cards');

  /// 旅行のプランコレクション
  CollectionReference<Map<String, dynamic>> plansCollection(String tripId) =>
      tripsCollection.doc(tripId).collection('plans');

  /// 旅行の旅程コレクション
  CollectionReference<Map<String, dynamic>> itineraryCollection(
          String tripId) =>
      tripsCollection.doc(tripId).collection('itinerary');

  /// 旅行のチャットコレクション
  CollectionReference<Map<String, dynamic>> chatCollection(String tripId) =>
      tripsCollection.doc(tripId).collection('chat');

  /// メンバーの希望コレクション
  CollectionReference<Map<String, dynamic>> memberPreferencesCollection(
          String tripId) =>
      tripsCollection.doc(tripId).collection('memberPreferences');
}
