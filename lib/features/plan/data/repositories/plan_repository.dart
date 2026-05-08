import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/plan_model.dart';

/// しおりプランリポジトリ
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
    List<PlanItem> items = const [],
  }) async {
    final plan = PlanModel(
      id: '',
      tripId: tripId,
      title: title,
      description: description,
      items: items,
      createdAt: DateTime.now(),
    );

    final doc = await _plansCollection(tripId).add(plan.toFirestore());

    // tripにplanIdを設定
    await _firestore.collection('trips').doc(tripId).update({
      'planId': doc.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
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

  /// プランのアイテムリストのみ更新
  Future<void> updatePlanItems({
    required String tripId,
    required String planId,
    required List<PlanItem> items,
    String? editedByName,
  }) async {
    final update = <String, dynamic>{
      'items': items.map((e) => e.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (editedByName != null) {
      update['lastEditedByName'] = editedByName;
    }
    await _plansCollection(tripId).doc(planId).update(update);
  }

  /// プランのタイトルのみ更新
  Future<void> updatePlanTitle({
    required String tripId,
    required String planId,
    required String title,
  }) async {
    await _plansCollection(tripId).doc(planId).update({
      'title': title,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  /// 編集プレゼンスを設定
  Future<void> setEditingPresence({
    required String tripId,
    required String planId,
    required String? userId,
    String? userName,
  }) async {
    await _plansCollection(tripId).doc(planId).update({
      'editingBy': userId,
      'lastEditedByName': userName,
    });
  }

  /// プランを削除
  Future<void> deletePlan(String tripId, String planId) async {
    await _plansCollection(tripId).doc(planId).delete();
  }
}
