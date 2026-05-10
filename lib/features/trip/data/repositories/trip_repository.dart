import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/trip_member_model.dart';
import '../../../../shared/models/trip_model.dart';

/// しおり（旅行）リポジトリ
class TripRepository {
  TripRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tripsCollection =>
      _firestore.collection('trips');

  /// しおりを作成
  Future<String> createTrip({
    required String title,
    required String createdBy,
    DateTime? startDate,
    DateTime? endDate,
    String? ownerName,
  }) async {
    final now = DateTime.now();

    final memberDetails = <String, TripMember>{};
    if (ownerName != null) {
      memberDetails[createdBy] = TripMember(
        userId: createdBy,
        displayName: ownerName,
        isManual: false,
      );
    }

    final trip = TripModel(
      id: '',
      title: title,
      createdBy: createdBy,
      members: [createdBy],
      memberDetails: memberDetails,
      startDate: startDate,
      endDate: endDate,
      createdAt: now,
      updatedAt: now,
    );

    final doc = await _tripsCollection.add(trip.toFirestore());
    return doc.id;
  }

  /// ユーザーのしおり一覧を監視
  Stream<List<TripModel>> watchUserTrips(String userId) {
    return _tripsCollection
        .where('members', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => TripModel.fromFirestore(doc)).toList(),
        );
  }

  /// しおりを監視
  Stream<TripModel?> watchTrip(String tripId) {
    return _tripsCollection.doc(tripId).snapshots().map((doc) {
      if (doc.exists) {
        return TripModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// しおりを取得
  Future<TripModel?> getTrip(String tripId) async {
    final doc = await _tripsCollection.doc(tripId).get();
    if (doc.exists) {
      return TripModel.fromFirestore(doc);
    }
    return null;
  }

  /// メンバーを追加
  Future<void> addMember(String tripId, String userId) async {
    await _tripsCollection.doc(tripId).update({
      'members': FieldValue.arrayUnion([userId]),
      'updatedAt': Timestamp.now(),
    });
  }

  /// メンバー詳細を更新
  Future<void> updateMemberDetails(
    String tripId,
    String userId,
    Map<String, dynamic> memberData,
  ) async {
    await _tripsCollection.doc(tripId).update({
      'memberDetails.$userId': memberData,
      'updatedAt': Timestamp.now(),
    });
  }

  /// しおりを更新
  Future<void> updateTrip(TripModel trip) async {
    await _tripsCollection.doc(trip.id).update(trip.toFirestore());
  }

  /// プランIDを設定
  Future<void> setPlanId(String tripId, String planId) async {
    await _tripsCollection.doc(tripId).update({
      'planId': planId,
      'updatedAt': Timestamp.now(),
    });
  }

  /// カバー画像URLを更新
  Future<void> updateTripImageUrl(String tripId, String? imageUrl) async {
    await _tripsCollection.doc(tripId).update({
      'imageUrl': imageUrl,
      'updatedAt': Timestamp.now(),
    });
  }

  /// しおりを削除
  Future<void> deleteTrip(String tripId) async {
    await _tripsCollection.doc(tripId).delete();
  }
}
