import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/plan_model.dart';

/// プランリポジトリ
class PlanRepository {
  PlanRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _plansCollection(String tripId) =>
      _firestore.collection('trips').doc(tripId).collection('plans');

  /// プランを作成
  Future<String> createPlan({
    required String tripId,
    required String title,
    String? description,
    required List<PlanItem> items,
    required List<String> includedCards,
    required List<String> excludedCards,
  }) async {
    final plan = PlanModel(
      id: '',
      tripId: tripId,
      title: title,
      description: description,
      items: items,
      includedCards: includedCards,
      excludedCards: excludedCards,
      votes: {},
      createdAt: DateTime.now(),
    );

    final doc = await _plansCollection(tripId).add(plan.toFirestore());

    // ステータスをvotingに更新
    await _firestore.collection('trips').doc(tripId).update({
      'status': 'voting',
    });

    return doc.id;
  }

  /// プラン一覧を監視
  Stream<List<PlanModel>> watchPlans(String tripId) {
    return _plansCollection(tripId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => PlanModel.fromFirestore(doc, tripId))
                  .toList(),
        );
  }

  /// プランを取得
  Future<PlanModel?> getPlan(String tripId, String planId) async {
    final doc = await _plansCollection(tripId).doc(planId).get();
    if (doc.exists) {
      return PlanModel.fromFirestore(doc, tripId);
    }
    return null;
  }

  /// プランを更新（updatedAtを自動設定）
  Future<void> updatePlan({
    required String tripId,
    required PlanModel plan,
  }) async {
    final data = plan.toFirestore();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _plansCollection(tripId).doc(plan.id).update(data);
  }

  /// 単一プランをリアルタイム監視
  Stream<PlanModel?> watchPlan(String tripId, String planId) {
    return _plansCollection(tripId).doc(planId).snapshots().map((doc) {
      if (doc.exists) {
        return PlanModel.fromFirestore(doc, tripId);
      }
      return null;
    });
  }

  /// 編集プレゼンスを設定（自分が編集中であることを通知）
  Future<void> setEditingPresence({
    required String tripId,
    required String planId,
    required String? userId,
    String? userName,
  }) async {
    await _plansCollection(
      tripId,
    ).doc(planId).update({'editingBy': userId, 'lastEditedByName': userName});
  }

  /// プランに投票
  Future<void> vote({
    required String tripId,
    required String planId,
    required String userId,
    required bool approve,
  }) async {
    await _plansCollection(
      tripId,
    ).doc(planId).update({'votes.$userId': approve});
  }

  /// プランを削除
  Future<void> deletePlan(String tripId, String planId) async {
    await _plansCollection(tripId).doc(planId).delete();
  }

  /// プランを確定
  Future<void> confirmPlan(String tripId, String planId) async {
    await _firestore.collection('trips').doc(tripId).update({
      'confirmedPlanId': planId,
      'editingPlanId': null,
      'status': 'confirmed',
    });
  }

  /// 編集中プランIDを設定
  Future<void> setEditingPlanId(String tripId, String? planId) async {
    await _firestore.collection('trips').doc(tripId).update({
      'editingPlanId': planId,
    });
  }
}
