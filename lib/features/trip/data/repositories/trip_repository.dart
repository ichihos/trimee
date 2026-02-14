import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/trip_member_model.dart';
import '../../../../shared/models/trip_model.dart';

/// 旅行リポジトリ
class TripRepository {
  TripRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tripsCollection =>
      _firestore.collection('trips');

  /// 旅行を作成
  Future<String> createTrip({
    required String title,
    required String createdBy,
    DateTime? startDate,
    DateTime? endDate,
    String? ownerName,
    String? ownerDeparture,
  }) async {
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
      id: '',
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

    final doc = await _tripsCollection.add(trip.toFirestore());
    return doc.id;
  }

  /// ユーザーの旅行一覧を監視
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

  /// 旅行を監視
  Stream<TripModel?> watchTrip(String tripId) {
    return _tripsCollection.doc(tripId).snapshots().map((doc) {
      if (doc.exists) {
        return TripModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// 旅行を取得
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

  /// メンバーを削除
  Future<void> removeMember(String tripId, String userId) async {
    await _tripsCollection.doc(tripId).update({
      'members': FieldValue.arrayRemove([userId]),
      'updatedAt': Timestamp.now(),
    });
  }

  /// ステータスを更新
  Future<void> updateStatus(String tripId, TripStatus status) async {
    await _tripsCollection.doc(tripId).update({
      'status': status.name,
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

  /// 旅行を更新
  Future<void> updateTrip(TripModel trip) async {
    await _tripsCollection.doc(trip.id).update(trip.toFirestore());
  }

  /// 旅行を削除
  Future<void> deleteTrip(String tripId) async {
    await _tripsCollection.doc(tripId).delete();
  }
}
