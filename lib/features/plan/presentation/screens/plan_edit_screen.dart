import 'dart:async';
import 'travel_animation_screen.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import '../../../../shared/utils/file_saver.dart' as file_saver;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/models/expense_model.dart';
import '../../../../shared/models/plan_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../shared/providers/user_profile_provider.dart';
import '../../../../shared/services/ai_service.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_icon.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/widgets/animated_widgets.dart';
import '../../../trip/presentation/providers/trip_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/plan_provider.dart';
import '../widgets/plan_map_view.dart';
import '../../../../shared/services/plan_export_service.dart';
import '../widgets/placeholder_action_sheet.dart';

/// プラン編集画面
class PlanEditScreen extends ConsumerStatefulWidget {
  const PlanEditScreen({
    super.key,
    required this.tripId,
    required this.plan,
    this.onBack,
  });

  final String tripId;
  final PlanModel plan;
  final VoidCallback? onBack;

  @override
  ConsumerState<PlanEditScreen> createState() => _PlanEditScreenState();
}

class _PlanEditScreenState extends ConsumerState<PlanEditScreen> {
  String? _selectedItemId;
  final _uuid = const Uuid();
  final GlobalKey _exportKey = GlobalKey();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<PlanItem> _items;
  String? _iconUrl;
  bool _isSaving = false;
  bool _showSaveIndicator = false;
  Timer? _debounceTimer;
  bool _isMapView = false;
  final ScrollController _mainScrollController = ScrollController();

  // リアルタイム同期用
  bool _hasExternalUpdate = false;
  String? _otherEditorName;
  DateTime? _lastSaveTime;
  /// この時刻までのストリーム更新を無視する（Firestoreの複数スナップショット対策）
  DateTime? _ignoreStreamUntil;
  bool _isDragging = false; // ドラッグ中かどうか

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.plan.title);
    _descriptionController = TextEditingController(
      text: widget.plan.description,
    );
    _items = _ensureItemIds(widget.plan.items);
    _iconUrl = widget.plan.iconUrl;
    _lastSaveTime = widget.plan.updatedAt ?? widget.plan.createdAt;

    // 編集プレゼンスを設定
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setPresence(active: true);
      _listenToExternalChanges();
      // ゲストの場合はログインシートを自動表示
      _showGuestLoginSheetIfNeeded();
    });
  }

  // _triggerAutoSave は削除し、個別の更新メソッドを使用する
  // void _triggerAutoSave() { ... }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _mainScrollController.dispose();
    // 編集プレゼンスをクリア
    _setPresence(active: false);
    super.dispose();
  }

  /// アイテムリストのID空欠を埋める
  List<PlanItem> _ensureItemIds(List<PlanItem> items) {
    return items
        .map((item) => item.id.isEmpty ? item.copyWith(id: _uuid.v4()) : item)
        .toList();
  }

  /// 編集プレゼンスを設定/解除
  void _setPresence({required bool active}) {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final userName = profile?.displayName;

    ref
        .read(planControllerProvider.notifier)
        .setEditingPresence(
          tripId: widget.tripId,
          planId: widget.plan.id,
          userId: active ? userId : null,
          userName: active ? userName : null,
        );
  }

  /// 外部変更をリッスン
  void _listenToExternalChanges() {
    final currentUserId = ref.read(currentUserIdProvider);
    ref.listenManual(
      watchPlanProvider((tripId: widget.tripId, planId: widget.plan.id)),
      (previous, next) {
        final plan = next.valueOrNull;
        if (plan == null || !mounted) return;

        // 自分の保存による更新は無視（時間ベースで判定）
        if (_ignoreStreamUntil != null &&
            DateTime.now().isBefore(_ignoreStreamUntil!)) {
          return;
        }
        _ignoreStreamUntil = null;

        // 他のユーザーが編集中か確認
        if (plan.editingBy != null && plan.editingBy != currentUserId) {
          // プレゼンスが5分以上古い場合はスタール（アプリクラッシュ等）と判断
          final isStale =
              plan.updatedAt != null &&
              DateTime.now().difference(plan.updatedAt!).inMinutes > 5;
          if (isStale) {
            // スタールなプレゼンスをクリア
            ref
                .read(planControllerProvider.notifier)
                .setEditingPresence(
                  tripId: widget.tripId,
                  planId: widget.plan.id,
                  userId: null,
                );
            if (_otherEditorName != null && mounted) {
              setState(() => _otherEditorName = null);
            }
          } else {
            if (mounted) {
              setState(() {
                _otherEditorName = plan.lastEditedByName ?? '他のメンバー';
              });
            }
          }
        } else {
          if (_otherEditorName != null && mounted) {
            setState(() => _otherEditorName = null);
          }
        }

        // 外部からの変更がある場合（updatedAtが自分のlastSaveTimeより新しい）
        if (plan.updatedAt != null &&
            _lastSaveTime != null &&
            plan.updatedAt!.isAfter(_lastSaveTime!)) {
          // 部分更新を反映
          bool updated = false;

          // タイトル
          if (plan.title != _titleController.text) {
            _titleController.text = plan.title;
            updated = true;
          }
          // 説明
          if (plan.description != _descriptionController.text) {
            _descriptionController.text = plan.description ?? '';
            updated = true;
          }
          // アイテム (ドラッグ中以外)
          if (!_isDragging) {
            // セーフガード: サーバー側のitemsが空で、ローカルが空でない場合は上書きしない
            // (編集画面遷移直後などに空のデータが飛んできて消えるのを防ぐ)
            if (plan.items.isEmpty && _items.isNotEmpty) {
              // 無視する
            } else if (plan.items.length != _items.length) {
              _items = _ensureItemIds(plan.items);
              updated = true;
            } else {
              _items = _ensureItemIds(plan.items);
              updated = true;
            }
          }

          if (updated && mounted) {
            setState(() {
              _lastSaveTime = plan.updatedAt;
              // アイコンなども必要なら更新
              _iconUrl = plan.iconUrl;
            });
          }
        }
      },
    );
  }

  /// 外部変更を取り込む
  void _applyExternalUpdate() {
    final planAsync = ref.read(
      watchPlanProvider((tripId: widget.tripId, planId: widget.plan.id)),
    );
    final plan = planAsync.valueOrNull;
    if (plan == null) return;

    setState(() {
      _titleController.text = plan.title;
      _descriptionController.text = plan.description ?? '';
      _items = _ensureItemIds(plan.items);
      _iconUrl = plan.iconUrl;
      _hasExternalUpdate = false;
      _lastSaveTime = plan.updatedAt;
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('最新の変更を反映しました'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
      ),
    );
  }

  /// タイトルを更新
  Future<void> _updateTitle(String newTitle) async {
    if (widget.plan.title == newTitle) return;

    _ignoreStreamUntil = DateTime.now().add(const Duration(seconds: 2));
    try {
      await ref
          .read(planControllerProvider.notifier)
          .updatePlanTitle(
            tripId: widget.tripId,
            planId: widget.plan.id,
            title: newTitle,
          );
      _lastSaveTime = DateTime.now();
    } catch (e) {
      _ignoreStreamUntil = null;
      // エラー処理
    }
  }

  /// アイコンを更新
  Future<void> _updateIcon(String? newIconUrl) async {
    _ignoreStreamUntil = DateTime.now().add(const Duration(seconds: 2));
    try {
      await ref
          .read(planControllerProvider.notifier)
          .updatePlanIcon(
            tripId: widget.tripId,
            planId: widget.plan.id,
            iconUrl: newIconUrl,
          );
      _lastSaveTime = DateTime.now();
    } catch (e) {
      _ignoreStreamUntil = null;
    }
  }

  /// 説明を更新
  Future<void> _updateDescription(String newDescription) async {
    if (widget.plan.description == newDescription) return;

    _ignoreStreamUntil = DateTime.now().add(const Duration(seconds: 2));
    try {
      await ref
          .read(planControllerProvider.notifier)
          .updatePlanDescription(
            tripId: widget.tripId,
            planId: widget.plan.id,
            description: newDescription,
          );
      _lastSaveTime = DateTime.now();
    } catch (e) {
      _ignoreStreamUntil = null;
    }
  }

  /// アイテムリストを更新
  Future<void> _updateItems(List<PlanItem> newItems) async {
    if (_isSaving) return; // 重複防止（必要に応じて）

    setState(() {
      _isSaving = true;
      _showSaveIndicator = true;
    });

    _ignoreStreamUntil = DateTime.now().add(const Duration(seconds: 2));

    try {
      await ref
          .read(planControllerProvider.notifier)
          .updatePlanItems(
            tripId: widget.tripId,
            planId: widget.plan.id,
            items: newItems,
          );
      _lastSaveTime = DateTime.now();
    } catch (e) {
      _ignoreStreamUntil = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() => _showSaveIndicator = false);
          }
        });
      }
    }
  }

  void _showEditInfoDialog() {
    final titleController = TextEditingController(text: _titleController.text);
    final descController = TextEditingController(
      text: _descriptionController.text,
    );
    final descFocus = FocusNode();

    void save(BuildContext dialogContext) {
      setState(() {
        _titleController.text = titleController.text;
        _descriptionController.text = descController.text;
      });
      _updateTitle(titleController.text);
      _updateDescription(descController.text);
      Navigator.pop(dialogContext);
    }

    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('プラン詳細を編集'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'タイトル',
                    hintText: 'プランのタイトル',
                  ),
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => descFocus.requestFocus(),
                ),
                const SizedBox(height: AppSizes.paddingM),
                TextField(
                  controller: descController,
                  focusNode: descFocus,
                  decoration: const InputDecoration(
                    labelText: '説明',
                    hintText: 'プランの説明',
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => save(dialogContext),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => save(dialogContext),
                child: const Text('保存'),
              ),
            ],
          ),
    ).then((_) {
      titleController.dispose();
      descController.dispose();
      descFocus.dispose();
    });
  }

  void _scrollToItem(String itemId) {
    final index = _items.indexWhere((e) => e.id == itemId);
    if (index < 0) return;

    // アイテムの推定位置までスクロール（ヘッダー・挿入ボタン分を考慮）
    final estimatedOffset = index * 120.0;
    _mainScrollController.animateTo(
      estimatedOffset.clamp(0.0, _mainScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _addItem() {
    _showEditItemSheet(
      item: null,
      onSave: (newItem) {
        // IDがなければ生成
        final itemToAdd =
            newItem.id.isEmpty ? newItem.copyWith(id: _uuid.v4()) : newItem;

        setState(() {
          _items.add(itemToAdd);
        });
        _updateItems(_items);
      },
    );
  }

  void _editItem(int index) {
    _showEditItemSheet(
      item: _items[index],
      onSave: (updatedItem) {
        setState(() {
          _items[index] = updatedItem;
        });
        _updateItems(_items);
      },
      onDelete: () {
        setState(() {
          _items.removeAt(index);
        });
        _updateItems(_items);
      },
    );
  }

  void _editItemById(String itemId) {
    final index = _items.indexWhere((e) => e.id == itemId);
    if (index >= 0) {
      _editItem(index);
    }
  }

  void _showEditItemSheet({
    required PlanItem? item,
    required Function(PlanItem) onSave,
    VoidCallback? onDelete,
    int? defaultDay,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _EditItemSheet(
            item: item,
            onSave: onSave,
            onDelete: onDelete,
            tripId: widget.tripId,
            planId: widget.plan.id,
            defaultDay: defaultDay,
          ),
    );
  }

  void _showInsertOptions({required int insertAtIndex, required int day}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusL),
        ),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingL),
                  Text('スポットを追加', style: AppTypography.titleMedium),
                  const SizedBox(height: AppSizes.paddingL),
                  ListTile(
                    leading: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.accent,
                    ),
                    title: const Text('自分で入力する'),
                    subtitle: const Text(
                      '場所・時間を手動で設定',
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditItemSheet(
                        item: null,
                        defaultDay: day,
                        onSave: (newItem) {
                          // ID生成
                          final itemToAdd =
                              newItem.id.isEmpty
                                  ? newItem.copyWith(id: _uuid.v4())
                                  : newItem;
                          setState(() {
                            _items.insert(insertAtIndex, itemToAdd);
                          });
                          _updateItems(_items);
                        },
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.accent,
                    ),
                    title: const Text('AIに追加を依頼する'),
                    subtitle: const Text(
                      '自然言語でスポットを提案',
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showAIInsertSheet(insertAtIndex: insertAtIndex);
                    },
                  ),
                  const SizedBox(height: AppSizes.paddingS),
                ],
              ),
            ),
          ),
    );
  }

  void _showAIInsertSheet({required int insertAtIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _AIInsertSheet(
            planTitle: _titleController.text,
            planDescription: _descriptionController.text,
            items: _items,
            insertAtIndex: insertAtIndex,
            onInsert: (newItems) {
              setState(() {
                for (var i = 0; i < newItems.length; i++) {
                  _items.insert(insertAtIndex + i, newItems[i]);
                }
              });
              _updateItems(_items);
            },
          ),
    );
  }

  Widget _buildDayGroupedList({DateTime? startDate}) {
    // 日付でグループ化
    final groupedItems = <int, List<MapEntry<int, PlanItem>>>{};
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final day = item.day;
      groupedItems.putIfAbsent(day, () => []);
      groupedItems[day]!.add(MapEntry(i, item));
    }

    final days = groupedItems.keys.toList()..sort();
    final isMultiDay = days.length > 1 || (days.isNotEmpty && days.first > 1);

    // フラットなリストを作成（日付ヘッダー + アイテム + 挿入ボタン）
    final flatList = <_DayGroupItem>[];
    for (final day in days) {
      if (isMultiDay) {
        flatList.add(_DayGroupItem.header(day));
      }
      final dayEntries = groupedItems[day]!;
      for (var i = 0; i < dayEntries.length; i++) {
        final entry = dayEntries[i];
        flatList.add(_DayGroupItem.item(entry.key, entry.value));
        // 各アイテムの後に挿入ボタンを配置
        final nextInsertIndex = entry.key + 1;
        flatList.add(_DayGroupItem.insertButton(nextInsertIndex, day));
      }
    }


    return ReorderableListView.builder(
      buildDefaultDragHandles: false, // カスタムハンドルを使用
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: flatList.length,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final scale = Tween<double>(
              begin: 1.0,
              end: 1.02,
            ).evaluate(animation);
            return Transform.scale(scale: scale, child: child);
          },
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            child: child,
          ),
        );
      },
      onReorderStart: (_) => _isDragging = true,
      onReorderEnd: (_) => _isDragging = false,
      onReorder: (oldIndex, newIndex) {
        // ヘッダー・挿入ボタンは並び替え対象外
        final oldItem = flatList[oldIndex];
        if (oldItem.isHeader || oldItem.isInsertButton) return;

        // 実際のアイテムインデックスを取得
        final actualOldIndex = oldItem.itemIndex!;

        // 新しい位置のアイテムインデックスを計算
        var actualNewIndex = 0;
        if (newIndex >= flatList.length) {
          actualNewIndex = _items.length;
        } else {
          final newItem = flatList[newIndex];
          if (newItem.isHeader) {
            // ヘッダーの直後に移動
            actualNewIndex = groupedItems[newItem.day]!.first.key;
          } else {
            actualNewIndex = newItem.itemIndex!;
          }
        }

        if (actualOldIndex == actualNewIndex) return;

        HapticFeedback.lightImpact();
        setState(() {
          if (actualOldIndex < actualNewIndex) {
            actualNewIndex -= 1;
          }
          final item = _items.removeAt(actualOldIndex);
          _items.insert(actualNewIndex, item);
        });
        _updateItems(_items);
      },
      itemBuilder: (context, index) {
        final groupItem = flatList[index];

        if (groupItem.isHeader) {
          return _DayHeaderEdit(
            key: ValueKey('header_${groupItem.day}'),
            day: groupItem.day!,
            startDate: startDate,
          );
        }

        if (groupItem.isInsertButton) {
          return _InsertButton(
            key: ValueKey('insert_${groupItem.insertAtIndex}_${groupItem.day}'),
            onTap:
                () => _showInsertOptions(
                  insertAtIndex: groupItem.insertAtIndex!,
                  day: groupItem.day!,
                ),
          );
        }

        final itemIndex = groupItem.itemIndex!;
        final item = groupItem.planItem!;
        final dayItems = groupedItems[item.day]!;
        final indexInDay = dayItems.indexWhere((e) => e.key == itemIndex);
        final isFirstInDay = indexInDay == 0;
        final isLastInDay = indexInDay == dayItems.length - 1;

        return _TimelineEditItem(
          key: ValueKey(item.id),
          item: item,
          index: itemIndex,
          reorderIndex: index,
          isFirst: isFirstInDay,
          isLast: isLastInDay,
          showDayBadge: !isMultiDay,
          destination:
              item.isPlaceholder ? _extractDestinationForItem(item) : null,
          onTap: () => _editItem(itemIndex),
          onDelete: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _items.removeAt(itemIndex);
            });
            _updateItems(_items);
          },
          onMapJump: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedItemId = item.id;
              _isMapView = true;
            });
            // 地図が見えるようにスクロールをトップへ
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_mainScrollController.hasClients) {
                _mainScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          },
          onUpdateLocation: (name, lat, lng) {
            HapticFeedback.mediumImpact();
            setState(() {
              _items[itemIndex] = item.copyWith(
                location: name,
                latitude: lat,
                longitude: lng,
                isPlaceholder: false,
              );
            });
            _updateItems(_items);
          },
        );
      },
    );
  }

  /// プレースホルダーの近くにある具体的なスポット名からエリアを推定する
  /// 同じ日の前後のスポットを優先し、なければ全体から取得
  String? _extractDestinationForItem(PlanItem placeholderItem) {
    final day = placeholderItem.day;
    final itemIndex = _items.indexOf(placeholderItem);

    // 同じ日の具体的なスポットを探す（近い順）
    final sameDayConcrete = <PlanItem>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.day == day && !item.isPlaceholder && item.location.isNotEmpty) {
        sameDayConcrete.add(item);
      }
    }

    if (sameDayConcrete.isNotEmpty) {
      // 最も近いスポットを返す
      sameDayConcrete.sort((a, b) {
        final distA = (_items.indexOf(a) - itemIndex).abs();
        final distB = (_items.indexOf(b) - itemIndex).abs();
        return distA.compareTo(distB);
      });
      return sameDayConcrete.first.location;
    }

    // 同じ日にない場合は全体から最初の具体的スポットを返す
    for (final item in _items) {
      if (!item.isPlaceholder && item.location.isNotEmpty) {
        return item.location;
      }
    }
    return null;
  }

  /// 全体の目的地エリアを抽出（予約セクション等で使用）
  String? _extractDestination() {
    for (final item in _items) {
      if (!item.isPlaceholder && item.location.isNotEmpty) {
        return item.location;
      }
    }
    return null;
  }

  void _showAIAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _AIAssistantSheet(
            planTitle: _titleController.text,
            planDescription: _descriptionController.text,
            items: _items,
            onApplySuggestion: (newItems) {
              // 空リストの場合は適用しない
              if (newItems.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('AIの提案にアイテムが含まれていません'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                );
                return;
              }
              setState(() {
                _items = _ensureItemIds(newItems);
              });
              _updateItems(_items);
            },
          ),
    );
  }

  void _confirmPlan() {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            title: Row(
              children: [
                const AppIcon(type: AppIconType.travel, size: 28),
                const SizedBox(width: AppSizes.paddingS),
                Text('プランを確定', style: AppTypography.titleMedium),
              ],
            ),
            content: Text('このプランで旅行を確定しますか？', style: AppTypography.bodyMedium),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'キャンセル',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);

                  // プランを確定
                  await ref
                      .read(planControllerProvider.notifier)
                      .confirmPlan(
                        tripId: widget.tripId,
                        planId: widget.plan.id,
                      );

                  if (mounted) {
                    // 「いってらっしゃい」トーストを表示
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const AppIcon(
                              type: AppIconType.sparkle,
                              size: 24,
                              showBackground: false,
                              iconColor: Colors.white,
                            ),
                            const SizedBox(width: AppSizes.paddingS),
                            Text(
                              'いってらっしゃい！',
                              style: AppTypography.labelMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.subAccent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusM),
                        ),
                      ),
                    );

                    // ホーム画面に戻る
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.subAccent,
                ),
                child: Text(
                  '確定する',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _showTravelAnimation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => TravelAnimationScreen(
              items: _items,
              planTitle: _titleController.text,
            ),
      ),
    );
  }

  void _showGuestLoginSheetIfNeeded() {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final currentUserId = ref.read(currentUserIdProvider);
    if (!isAuthenticated && currentUserId != null) {
      _showGuestLoginSheet(context);
    }
  }

  void _showGuestLoginSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => _GuestLoginSheet(
            onSuccess: () {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('アカウント登録が完了しました！データはそのまま引き継がれます'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                );
              }
            },
          ),
    );
  }

  void _showExportSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'プランをエクスポート',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.paddingL),
                  _ExportOption(
                    icon: Icons.image_outlined,
                    label: '画像として保存',
                    subtitle: '現在の画面をPNG画像としてキャプチャ',
                    onTap: () {
                      Navigator.pop(context);
                      _exportAsImage();
                    },
                  ),
                  const SizedBox(height: AppSizes.paddingS),
                  _ExportOption(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDFとして保存',
                    subtitle: 'タイムライン形式のPDFを生成',
                    onTap: () {
                      Navigator.pop(context);
                      _exportAsPdf();
                    },
                  ),
                  const SizedBox(height: AppSizes.paddingS),
                  _ExportOption(
                    icon: Icons.text_snippet_outlined,
                    label: 'テキストで共有',
                    subtitle: 'プラン内容をテキスト形式で共有',
                    onTap: () {
                      Navigator.pop(context);
                      _shareAsText();
                    },
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                ],
              ),
            ),
          ),
    );
  }

  Rect _getShareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _exportAsImage() async {
    try {
      final bytes = await PlanExportService.exportImageAsBytes(_exportKey);
      if (!mounted) return;

      final filename = 'plan_${DateTime.now().millisecondsSinceEpoch}.png';
      if (kIsWeb) {
        file_saver.triggerBrowserDownload(bytes, filename, 'image/png');
      } else {
        final path = await file_saver.saveToFile(bytes, filename);
        await Share.shareXFiles(
          [XFile(path)],
          subject: _titleController.text,
          sharePositionOrigin: _getShareOrigin(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('画像エクスポートエラー: $e')));
      }
    }
  }

  Future<void> _exportAsPdf() async {
    try {
      final tripAsync = await ref.read(
        tripDetailProvider(widget.tripId).future,
      );
      final bytes = await PlanExportService.exportPdfAsBytes(
        plan: widget.plan.copyWith(
          title: _titleController.text,
          description: _descriptionController.text,
          items: _items,
        ),
        tripTitle: tripAsync?.title ?? '',
        startDate: tripAsync?.startDate,
      );
      if (!mounted) return;

      final filename = 'plan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      if (kIsWeb) {
        file_saver.triggerBrowserDownload(bytes, filename, 'application/pdf');
      } else {
        final path = await file_saver.saveToFile(bytes, filename);
        await Share.shareXFiles(
          [XFile(path)],
          subject: _titleController.text,
          sharePositionOrigin: _getShareOrigin(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDFエクスポートエラー: $e')));
      }
    }
  }

  void _shareAsText() {
    final buf = StringBuffer();
    buf.writeln(_titleController.text);
    if (_descriptionController.text.isNotEmpty) {
      buf.writeln(_descriptionController.text);
    }
    buf.writeln();

    final itemsByDay = <int, List<PlanItem>>{};
    for (final item in _items) {
      itemsByDay.putIfAbsent(item.day, () => []).add(item);
    }
    final days = itemsByDay.keys.toList()..sort();

    for (final day in days) {
      buf.writeln('--- $day日目 ---');
      final items = itemsByDay[day]!..sort((a, b) => a.time.compareTo(b.time));
      for (final item in items) {
        buf.writeln('${item.time}  ${item.location}（${item.durationMinutes}分）');
        if (item.notes != null && item.notes!.isNotEmpty) {
          buf.writeln('  ${item.notes}');
        }
      }
      buf.writeln();
    }

    buf.writeln('trimeeで作成');
    Share.share(buf.toString(), sharePositionOrigin: _getShareOrigin());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: AppSizes.paddingM,
          right: AppSizes.paddingM,
          top: AppSizes.paddingM,
          bottom: MediaQuery.of(context).padding.bottom + AppSizes.paddingM,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // AIに相談ボタン
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showAIAssistant,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('AIに相談'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.paddingM),
            // このプランで確定ボタン
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _confirmPlan,
                icon: const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'プランを確定する',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.subAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RepaintBoundary(
          key: _exportKey,
          child: Column(
            children: [
              // ヘッダー
              _EditHeader(
                onBack: widget.onBack ?? () => Navigator.pop(context),
                isSaving: _isSaving,
                showSaveIndicator: _showSaveIndicator,
                onPlayAnimation: _showTravelAnimation,
                onExport: _showExportSheet,
              ),

              // 他のユーザーが編集中バナー
              if (_otherEditorName != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingM,
                    vertical: AppSizes.paddingS,
                  ),
                  color: Colors.amber.shade50,
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: AppSizes.paddingXS),
                      Expanded(
                        child: Text(
                          '$_otherEditorNameも編集中です',
                          style: AppTypography.caption.copyWith(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 外部変更通知バナー
              if (_hasExternalUpdate)
                GestureDetector(
                  onTap: _applyExternalUpdate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                      vertical: AppSizes.paddingS,
                    ),
                    color: AppColors.accent.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        Icon(Icons.sync, size: 16, color: AppColors.accent),
                        const SizedBox(width: AppSizes.paddingXS),
                        Expanded(
                          child: Text(
                            '他のメンバーが変更しました',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.paddingS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusFull,
                            ),
                          ),
                          child: Text(
                            '反映する',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ゲストユーザー向けログイン促進バナー
              if (!ref.watch(isAuthenticatedProvider) &&
                  ref.watch(currentUserIdProvider) != null)
                _GuestLoginBanner(onTap: () => _showGuestLoginSheet(context)),

              // メインコンテンツ
              Expanded(
                child: SingleChildScrollView(
                  controller: _mainScrollController,
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // プラン情報カード
                      _PlanInfoCard(
                        tripId: widget.tripId,
                        planId: widget.plan.id,
                        titleController: _titleController,
                        descriptionController: _descriptionController,
                        iconUrl: _iconUrl,
                        onEdit: _showEditInfoDialog,
                        onIconChanged: (url) {
                          setState(() => _iconUrl = url);
                          _updateIcon(url);
                        },
                      ),

                      const SizedBox(height: AppSizes.paddingL),

                      // ビュー切り替えタブ
                      _ViewModeToggle(
                        isMapView: _isMapView,
                        onChanged: (isMap) {
                          setState(() => _isMapView = isMap);
                          if (!isMap && _selectedItemId != null) {
                            // マップ→リスト: 選択アイテムへスクロール
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _scrollToItem(_selectedItemId!);
                            });
                          }
                        },
                      ),

                      const SizedBox(height: AppSizes.paddingM),

                      // 地図ビューまたはスケジュールセクション
                      if (_isMapView)
                        SizedBox(
                          height: 400,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusL,
                            ),
                            child: PlanMapView(
                              items: _items,
                              focusItemId: _selectedItemId,
                              onItemTap: (itemId) {
                                setState(() => _selectedItemId = itemId);
                              },
                              onCardTap: (itemId) => _editItemById(itemId),
                            ),
                          ),
                        )
                      else ...[
                        // スケジュールセクション
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSizes.paddingS),
                            Text('スケジュール', style: AppTypography.titleSmall),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('追加'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.accent,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSizes.paddingS),

                        // タイムラインアイテム
                        if (_items.isEmpty)
                          _EmptySchedule(onAdd: _addItem)
                        else
                          Builder(
                            builder: (context) {
                              final tripAsync = ref.watch(
                                tripDetailProvider(widget.tripId),
                              );
                              final trip = tripAsync.valueOrNull;
                              final startDate = trip?.startDate;
                              return _buildDayGroupedList(startDate: startDate);
                            },
                          ),
                      ],

                      const SizedBox(height: AppSizes.paddingXL),

                      // 予約状況サマリー
                      _BookingStatusSummary(items: _items),

                      const SizedBox(height: AppSizes.paddingM),

                      // 予約・手配セクション
                      _BookingLinksSection(destination: _extractDestination()),

                      const SizedBox(height: AppSizes.paddingXL),

                      // 予算管理セクション
                      _ExpenseSection(tripId: widget.tripId),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 編集ヘッダー
class _EditHeader extends StatelessWidget {
  const _EditHeader({
    required this.onBack,
    required this.isSaving,
    required this.showSaveIndicator,
    required this.onPlayAnimation,
    required this.onExport,
  });

  final VoidCallback onBack;
  final bool isSaving;
  final bool showSaveIndicator;
  final VoidCallback onPlayAnimation;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Row(
        children: [
          // 戻るボタン
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.paddingS),

          // アニメーションボタン
          IconButton(
            onPressed: onPlayAnimation,
            icon: const Icon(Icons.movie_creation_outlined),
            tooltip: '旅の軌跡を再生',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
              foregroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.paddingXS),

          // エクスポートボタン
          IconButton(
            onPressed: onExport,
            icon: const Icon(Icons.ios_share, size: 20),
            tooltip: 'エクスポート',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
              foregroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.paddingM),

          // タイトル
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.subAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: AppColors.subAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '選択中のプラン',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.subAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('スケジュールを編集', style: AppTypography.titleMedium),
              ],
            ),
          ),

          // 保存インジケータ
          if (isSaving || showSaveIndicator)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isSaving
                        ? AppColors.accent.withValues(alpha: 0.1)
                        : AppColors.subAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                border: Border.all(
                  color:
                      isSaving
                          ? AppColors.accent.withValues(alpha: 0.3)
                          : AppColors.subAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSaving)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  else
                    Icon(
                      Icons.cloud_done_rounded,
                      size: 16,
                      color: AppColors.subAccent,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    isSaving ? '保存中...' : '自動保存済み',
                    style: AppTypography.labelSmall.copyWith(
                      color: isSaving ? AppColors.accent : AppColors.subAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// エクスポートオプション行
class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                child: Icon(icon, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ゲストユーザー向けログイン促進バナー
class _GuestLoginBanner extends StatelessWidget {
  const _GuestLoginBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingM,
          vertical: AppSizes.paddingS,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.08),
              AppColors.subAccent.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
              ),
              child: Icon(
                Icons.person_add_outlined,
                size: 18,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSizes.paddingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'アカウント登録でデータを保護',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'ログインするとデータが安全に保存されます',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

/// ゲストユーザー向けログイン/サインアップシート
class _GuestLoginSheet extends ConsumerStatefulWidget {
  const _GuestLoginSheet({required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  ConsumerState<_GuestLoginSheet> createState() => _GuestLoginSheetState();
}

class _GuestLoginSheetState extends ConsumerState<_GuestLoginSheet> {
  bool _showEmailForm = false;
  bool _isLoading = false;
  String? _errorMessage;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String _extractErrorMessage(Object error, String fallback) {
    final msg = error.toString();
    // FirebaseAuthException のメッセージを抽出
    if (msg.contains('email-already-in-use')) {
      return 'このメールアドレスは既に使用されています';
    }
    if (msg.contains('credential-already-in-use') || msg.contains('provider-already-linked')) {
      return 'このアカウントは既に別のユーザーに紐づいています';
    }
    if (msg.contains('invalid-email')) {
      return 'メールアドレスの形式が正しくありません';
    }
    if (msg.contains('weak-password')) {
      return 'パスワードが弱すぎます。6文字以上にしてください';
    }
    if (msg.contains('popup-closed-by-user') || msg.contains('user-cancelled')) {
      return 'ログインがキャンセルされました';
    }
    if (msg.contains('network-request-failed')) {
      return 'ネットワークエラーが発生しました。接続を確認してください';
    }
    debugPrint('Auth error: $msg');
    return fallback;
  }

  Future<void> _linkWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final success =
        await ref.read(authControllerProvider.notifier).linkWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      widget.onSuccess();
    } else {
      final authState = ref.read(authControllerProvider);
      final error = authState.error;
      setState(() => _errorMessage = error != null
          ? _extractErrorMessage(error, 'Googleアカウントとの連携に失敗しました')
          : 'Googleアカウントとの連携に失敗しました');
    }
  }

  Future<void> _linkWithApple() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final success =
        await ref.read(authControllerProvider.notifier).linkWithApple();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      widget.onSuccess();
    } else {
      final authState = ref.read(authControllerProvider);
      final error = authState.error;
      setState(() => _errorMessage = error != null
          ? _extractErrorMessage(error, 'Apple IDとの連携に失敗しました')
          : 'Apple IDとの連携に失敗しました');
    }
  }

  Future<void> _linkWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      setState(() => _errorMessage = 'すべての項目を入力してください');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'パスワードは6文字以上で入力してください');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final success = await ref
        .read(authControllerProvider.notifier)
        .linkWithEmail(email: email, password: password, name: name);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      widget.onSuccess();
    } else {
      final authState = ref.read(authControllerProvider);
      final error = authState.error;
      setState(() => _errorMessage = error != null
          ? _extractErrorMessage(error, 'メールアドレスでの登録に失敗しました')
          : 'メールアドレスでの登録に失敗しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ハンドル
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),

              // アイコン
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
                child: Icon(
                  Icons.how_to_reg_outlined,
                  size: 32,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: AppSizes.paddingM),

              Text(
                'アカウントを作成',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.paddingXS),
              Text(
                '現在のプランデータはそのまま引き継がれます',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.paddingL),

              // エラーメッセージ
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.paddingS),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.caption.copyWith(
                      color: Colors.red[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),
              ],

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(AppSizes.paddingL),
                  child: CircularProgressIndicator(),
                )
              else if (_showEmailForm)
                _buildEmailForm()
              else
                _buildSocialButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        // Googleボタン
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _linkWithGoogle,
            icon: Image.asset(
              'assets/images/google_logo.png',
              width: 20,
              height: 20,
              errorBuilder:
                  (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
            ),
            label: const Text('Googleで続ける'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.paddingS),

        // Appleボタン
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _linkWithApple,
              icon: const Icon(Icons.apple, size: 24),
              label: const Text('Appleで続ける'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingS),
        ],

        // メールボタン
        SizedBox(
          width: double.infinity,
          height: 52,
          child: TextButton.icon(
            onPressed: () => setState(() => _showEmailForm = true),
            icon: const Icon(Icons.email_outlined, size: 20),
            label: const Text('メールアドレスで登録'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.paddingM),

        // 注記
        Text(
          'ゲストデータは端末にのみ保存されています。\nアカウント登録でデータを安全に保護できます。',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Column(
      children: [
        // 戻るリンク
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed:
                () => setState(() {
                  _showEmailForm = false;
                  _errorMessage = null;
                }),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('戻る'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.paddingS),

        // 名前
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: '名前',
            hintText: 'ニックネーム',
            prefixIcon: const Icon(Icons.person_outline, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
          ),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _emailFocus.requestFocus(),
        ),
        const SizedBox(height: AppSizes.paddingS),

        // メール
        TextField(
          controller: _emailController,
          focusNode: _emailFocus,
          decoration: InputDecoration(
            labelText: 'メールアドレス',
            hintText: 'example@email.com',
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
        ),
        const SizedBox(height: AppSizes.paddingS),

        // パスワード
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          decoration: InputDecoration(
            labelText: 'パスワード',
            hintText: '6文字以上',
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
          ),
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _linkWithEmail(),
        ),
        const SizedBox(height: AppSizes.paddingL),

        // 登録ボタン
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _linkWithEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
            child: const Text(
              'アカウントを作成',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}

/// プラン情報カード
class _PlanInfoCard extends ConsumerStatefulWidget {
  const _PlanInfoCard({
    required this.tripId,
    required this.planId,
    required this.titleController,
    required this.descriptionController,
    required this.iconUrl,
    required this.onEdit,
    required this.onIconChanged,
  });

  final String tripId;
  final String planId;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final String? iconUrl;
  final VoidCallback onEdit;
  final Function(String? url) onIconChanged;

  @override
  ConsumerState<_PlanInfoCard> createState() => _PlanInfoCardState();
}

class _PlanInfoCardState extends ConsumerState<_PlanInfoCard> {
  bool _isUploadingIcon = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUploadIcon() async {
    HapticFeedback.lightImpact();

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusL),
        ),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingL),
                  Text('プランのアイコン画像', style: AppTypography.titleMedium),
                  const SizedBox(height: AppSizes.paddingL),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_outlined,
                      color: AppColors.accent,
                    ),
                    title: const Text('ライブラリから選択'),
                    onTap: () => Navigator.pop(context, 'gallery'),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.accent,
                    ),
                    title: const Text('カメラで撮影'),
                    onTap: () => Navigator.pop(context, 'camera'),
                  ),
                  if (widget.iconUrl != null)
                    ListTile(
                      leading: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      title: const Text(
                        'アイコンを削除',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onTap: () => Navigator.pop(context, 'delete'),
                    ),
                  const SizedBox(height: AppSizes.paddingS),
                ],
              ),
            ),
          ),
    );

    if (result == null || !mounted) return;

    if (result == 'delete') {
      widget.onIconChanged(null);
      return;
    }

    final source =
        result == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image == null || !mounted) return;

    setState(() => _isUploadingIcon = true);

    try {
      final bytes = await image.readAsBytes();
      final ref = FirebaseStorage.instance
          .ref()
          .child('plans')
          .child(widget.tripId)
          .child('${widget.planId}_icon.jpg');

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await ref.getDownloadURL();

      if (mounted) {
        widget.onIconChanged(downloadUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像のアップロードに失敗しました: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingIcon = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // アイコン画像
          GestureDetector(
            onTap: _pickAndUploadIcon,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child:
                  _isUploadingIcon
                      ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        ),
                      )
                      : widget.iconUrl != null
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusM - 2,
                        ),
                        child: CachedNetworkImage(
                          imageUrl: widget.iconUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.textSecondary,
                              ),
                        ),
                      )
                      : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 24,
                            color: AppColors.accent,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'アイコン',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.accent,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
          const SizedBox(width: AppSizes.paddingM),
          // タイトルと説明
          Expanded(
            child: GestureDetector(
              onTap: widget.onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // タイトル表示
                  Text(
                    widget.titleController.text.isEmpty
                        ? 'プランのタイトル'
                        : widget.titleController.text,
                    style: AppTypography.titleMedium.copyWith(
                      color:
                          widget.titleController.text.isEmpty
                              ? AppColors.textSecondary.withValues(alpha: 0.5)
                              : AppColors.textPrimary,
                    ),
                  ),
                  if (widget.descriptionController.text.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.paddingS),
                    Text(
                      widget.descriptionController.text,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 予約状況サマリー
class _BookingStatusSummary extends StatelessWidget {
  const _BookingStatusSummary({required this.items});

  final List<PlanItem> items;

  @override
  Widget build(BuildContext context) {
    final bookedItems = items.where((i) => i.isBooked).toList();
    final nonPlaceholderCount = items.where((i) => !i.isPlaceholder).length;

    if (nonPlaceholderCount == 0) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingS),
            decoration: BoxDecoration(
              color:
                  bookedItems.isNotEmpty
                      ? AppColors.accent.withValues(alpha: 0.1)
                      : AppColors.border.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppSizes.radiusS),
            ),
            child: Icon(
              Icons.bookmark_added,
              size: 20,
              color:
                  bookedItems.isNotEmpty
                      ? AppColors.accent
                      : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('予約状況', style: AppTypography.labelMedium),
                const SizedBox(height: 2),
                Text(
                  bookedItems.isEmpty
                      ? 'まだ予約がありません'
                      : '${bookedItems.length}/$nonPlaceholderCount 件予約済み',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          if (bookedItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingS,
                vertical: AppSizes.paddingXS,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text(
                '${(bookedItems.length / nonPlaceholderCount * 100).round()}%',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 予約・手配リンクセクション
class _BookingLinksSection extends StatelessWidget {
  const _BookingLinksSection({this.destination});

  final String? destination;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _encodeQuery(String? text) {
    return Uri.encodeComponent(text ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.bookmark_outline,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSizes.paddingS),
            Text('予約・手配', style: AppTypography.titleSmall),
          ],
        ),
        const SizedBox(height: AppSizes.paddingM),

        // 宿泊リンク
        _LinkCategory(
          icon: Icons.hotel_outlined,
          title: '宿泊を探す',
          links: [
            _LinkItem(
              name: '楽天トラベル',
              onTap:
                  () => _launchUrl(
                    'https://travel.rakuten.co.jp/keyword/?f_keyword=${_encodeQuery(destination)}',
                  ),
            ),
            _LinkItem(
              name: 'じゃらん',
              onTap:
                  () => _launchUrl(
                    'https://www.jalan.net/uw/uwp1100/uww1101.do?keyword=${_encodeQuery(destination)}',
                  ),
            ),
            _LinkItem(
              name: 'Booking.com',
              onTap:
                  () => _launchUrl(
                    'https://www.booking.com/searchresults.ja.html?ss=${_encodeQuery(destination)}',
                  ),
            ),
          ],
        ),

        const SizedBox(height: AppSizes.paddingM),

        // 交通リンク
        _LinkCategory(
          icon: Icons.train_outlined,
          title: '交通を調べる',
          links: [
            _LinkItem(
              name: 'Yahoo!乗換案内',
              onTap: () => _launchUrl('https://transit.yahoo.co.jp/'),
            ),
            _LinkItem(
              name: 'Google Maps',
              onTap:
                  () => _launchUrl(
                    'https://www.google.com/maps/search/${_encodeQuery(destination)}',
                  ),
            ),
            _LinkItem(
              name: 'えきねっと（JR）',
              onTap: () => _launchUrl('https://www.eki-net.com/'),
            ),
          ],
        ),

        const SizedBox(height: AppSizes.paddingM),

        // 観光情報リンク
        _LinkCategory(
          icon: Icons.explore_outlined,
          title: '観光情報',
          links: [
            _LinkItem(
              name: 'じゃらん観光ガイド',
              onTap:
                  () => _launchUrl(
                    'https://www.jalan.net/kankou/?screenId=OUW1121&keyword=${_encodeQuery(destination)}',
                  ),
            ),
            _LinkItem(
              name: 'トリップアドバイザー',
              onTap:
                  () => _launchUrl(
                    'https://www.tripadvisor.jp/Search?q=${_encodeQuery(destination)}',
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LinkCategory extends StatelessWidget {
  const _LinkCategory({
    required this.icon,
    required this.title,
    required this.links,
  });

  final IconData icon;
  final String title;
  final List<_LinkItem> links;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: AppSizes.paddingS),
              Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingS),
          Wrap(
            spacing: AppSizes.paddingS,
            runSpacing: AppSizes.paddingS,
            children: links,
          ),
        ],
      ),
    );
  }
}

class _LinkItem extends StatelessWidget {
  const _LinkItem({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingM,
          vertical: AppSizes.paddingS,
        ),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 12, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

/// 予算管理セクション
class _ExpenseSection extends ConsumerStatefulWidget {
  const _ExpenseSection({required this.tripId});

  final String tripId;

  @override
  ConsumerState<_ExpenseSection> createState() => _ExpenseSectionState();
}

class _ExpenseSectionState extends ConsumerState<_ExpenseSection> {
  bool _isExpanded = false;

  void _showAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddExpenseSheet(tripId: widget.tripId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider(widget.tripId));
    final total = ExpenseCalculator.calculateTotal(expenses);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSizes.paddingS),
            Text('予算管理', style: AppTypography.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: _showAddExpenseSheet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('追加'),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.paddingS),

        // サマリーカード
        AppCard(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('総額', style: AppTypography.caption),
                      Text(
                        '¥${_formatNumber(total)}',
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${expenses.length}件の支出',
                        style: AppTypography.caption,
                      ),
                      if (expenses.isNotEmpty)
                        GestureDetector(
                          onTap:
                              () => setState(() => _isExpanded = !_isExpanded),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isExpanded ? '閉じる' : '詳細を見る',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.accent,
                                ),
                              ),
                              Icon(
                                _isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 16,
                                color: AppColors.accent,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // 詳細リスト
              if (_isExpanded && expenses.isNotEmpty) ...[
                const SizedBox(height: AppSizes.paddingM),
                const Divider(),
                const SizedBox(height: AppSizes.paddingS),
                ...expenses.map(
                  (expense) => _ExpenseListItem(
                    expense: expense,
                    onDelete: () {
                      ref
                          .read(expensesProvider(widget.tripId).notifier)
                          .removeExpense(expense.id);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),

        // 空状態
        if (expenses.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.paddingS),
            child: Text('支出を記録して、旅行後の精算をスムーズに', style: AppTypography.caption),
          ),
      ],
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

class _ExpenseListItem extends StatelessWidget {
  const _ExpenseListItem({required this.expense, required this.onDelete});

  final ExpenseItem expense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.paddingS),
      child: Row(
        children: [
          Text(expense.category.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSizes.paddingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(expense.category.label, style: AppTypography.caption),
              ],
            ),
          ),
          Text(
            '¥${expense.amount}',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 16),
            color: AppColors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet({required this.tripId});

  final String tripId;

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();
  ExpenseCategory _selectedCategory = ExpenseCategory.other;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _save() {
    final description = _descriptionController.text.trim();
    final amount = int.tryParse(_amountController.text) ?? 0;

    if (description.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('内容と金額を入力してください')));
      return;
    }

    ref
        .read(expensesProvider(widget.tripId).notifier)
        .addExpense(
          description: description,
          amount: amount,
          paidBy: '', // TODO: 現在のユーザーID
          splitWith: [],
          category: _selectedCategory,
        );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSizes.paddingL,
        right: AppSizes.paddingL,
        top: AppSizes.paddingM,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.paddingL,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ハンドル
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),

            // タイトル
            Row(
              children: [
                const Icon(Icons.add_card, color: AppColors.accent),
                const SizedBox(width: AppSizes.paddingS),
                Text('支出を追加', style: AppTypography.headlineSmall),
              ],
            ),
            const SizedBox(height: AppSizes.paddingL),

            // カテゴリ選択
            Wrap(
              spacing: AppSizes.paddingS,
              runSpacing: AppSizes.paddingS,
              children:
                  ExpenseCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = category),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingM,
                          vertical: AppSizes.paddingS,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppColors.accent.withValues(alpha: 0.1)
                                  : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppColors.accent
                                    : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(category.emoji),
                            const SizedBox(width: 4),
                            Text(
                              category.label,
                              style: AppTypography.labelSmall.copyWith(
                                color:
                                    isSelected
                                        ? AppColors.accent
                                        : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: AppSizes.paddingM),

            // 内容入力
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '内容',
                hintText: '例: ホテル代、新幹線代',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _amountFocus.requestFocus(),
            ),
            const SizedBox(height: AppSizes.paddingM),

            // 金額入力
            TextField(
              controller: _amountController,
              focusNode: _amountFocus,
              decoration: InputDecoration(
                labelText: '金額',
                hintText: '10000',
                prefixIcon: const Icon(Icons.currency_yen),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSizes.paddingL),

            // 保存ボタン
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
              ),
              child: Text(
                '追加する',
                style: AppTypography.button.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 日付グループアイテム（ヘッダーまたはアイテム）
class _DayGroupItem {
  final bool isHeader;
  final bool isInsertButton;
  final int? day;
  final int? itemIndex;
  final PlanItem? planItem;
  final int? insertAtIndex; // 挿入ボタン用: この位置に挿入

  _DayGroupItem._({
    required this.isHeader,
    this.isInsertButton = false,
    this.day,
    this.itemIndex,
    this.planItem,
    this.insertAtIndex,
  });

  factory _DayGroupItem.header(int day) {
    return _DayGroupItem._(isHeader: true, day: day);
  }

  factory _DayGroupItem.item(int index, PlanItem item) {
    return _DayGroupItem._(
      isHeader: false,
      itemIndex: index,
      planItem: item,
      day: item.day,
    );
  }

  factory _DayGroupItem.insertButton(int insertIndex, int day) {
    return _DayGroupItem._(
      isHeader: false,
      isInsertButton: true,
      insertAtIndex: insertIndex,
      day: day,
    );
  }
}

/// 日付ヘッダー（編集画面用）
class _DayHeaderEdit extends StatelessWidget {
  const _DayHeaderEdit({super.key, required this.day, this.startDate});

  final int day;
  final DateTime? startDate;

  @override
  Widget build(BuildContext context) {
    // 実際の日付を計算
    String? dateText;
    if (startDate != null) {
      final date = startDate!.add(Duration(days: day - 1));
      dateText = '${date.month}/${date.day}（${_weekdayName(date.weekday)}）';
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSizes.paddingM,
        bottom: AppSizes.paddingS,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingM,
              vertical: AppSizes.paddingXS,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFFD4896E)],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  '$day日目',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (dateText != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    dateText,
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSizes.paddingS),
          Expanded(child: Container(height: 1, color: AppColors.border)),
        ],
      ),
    );
  }

  String _weekdayName(int weekday) {
    const names = ['月', '火', '水', '木', '金', '土', '日'];
    return names[weekday - 1];
  }
}

/// 空のスケジュール
class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.border,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_location_alt_outlined,
                color: AppColors.accent,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              'スポットを追加',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.paddingXS),
            Text('タップしてスポットを追加', style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

/// タイムライン編集アイテム
class _TimelineEditItem extends StatelessWidget {
  const _TimelineEditItem({
    super.key,
    required this.item,
    required this.index,
    required this.reorderIndex,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onDelete,
    this.showDayBadge = false,
    this.destination,
    this.onUpdateLocation,
    this.onMapJump,
  });

  final PlanItem item;
  final int index;
  final int reorderIndex;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool showDayBadge;
  final String? destination;
  final Function(String name, double? lat, double? lng)? onUpdateLocation;

  /// 地図ビューにジャンプ（座標がある場合のみ）
  final VoidCallback? onMapJump;

  bool get _isPlaceholder =>
      item.isPlaceholder || item.location.startsWith('※');

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss_${item.time}_${item.location}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSizes.paddingL),
        margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('削除しますか？'),
                content: Text('「${item.location}」を削除します。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('削除'),
                  ),
                ],
              ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // タイムライン
              SizedBox(
                width: 60,
                child: Column(
                  children: [
                    // 時刻バッジ
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingS,
                        vertical: AppSizes.paddingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      ),
                      child: Text(
                        item.time,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (item.durationMinutes > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${item.durationMinutes}分',
                        style: AppTypography.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),

              // ドットと線
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    if (!isFirst)
                      Container(width: 2, height: 8, color: AppColors.border),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.cardBackground,
                          width: 2,
                        ),
                      ),
                    ),
                    if (!isLast)
                      Container(width: 2, height: 40, color: AppColors.border),
                  ],
                ),
              ),

              const SizedBox(width: AppSizes.paddingS),

              // コンテンツカード
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.location,
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.isBooked) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '予約済',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (item.notes != null &&
                                item.notes!.isNotEmpty) ...[
                              const SizedBox(height: AppSizes.paddingXS),
                              Text(
                                item.notes!,
                                style: AppTypography.caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            // プレースホルダーの場合はアクションボタンを表示
                            if (_isPlaceholder) ...[
                              const SizedBox(height: AppSizes.paddingS),
                              _PlaceholderActionButton(
                                item: item,
                                destination: destination,
                                onUpdateLocation: onUpdateLocation,
                              ),
                            ],
                          ],
                        ),
                      ),
                      // 右側の操作カラム（マップ・ドラッグ）
                      const SizedBox(width: AppSizes.paddingS),
                      Column(
                        children: [
                          if (onMapJump != null) ...[
                            IconButton(
                              onPressed: onMapJump,
                              icon: Icon(
                                Icons.map_outlined,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(32, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          ReorderableDragStartListener(
                            index: reorderIndex,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                size: 20,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// プレースホルダー用アクションボタン
class _PlaceholderActionButton extends StatelessWidget {
  const _PlaceholderActionButton({
    required this.item,
    this.destination,
    this.onUpdateLocation,
  });

  final PlanItem item;
  final String? destination;
  final Function(String name, double? lat, double? lng)? onUpdateLocation;

  @override
  Widget build(BuildContext context) {
    final type = PlaceholderHelper.detectType(item.location);
    final icon = PlaceholderHelper.getIcon(type);
    final label = PlaceholderHelper.getLabel(type);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showPlaceholderActionSheet(
          context: context,
          item: item,
          destination: destination,
          onSelectSuggestion: (name, lat, lng) {
            onUpdateLocation?.call(name, lat, lng);
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingS,
          vertical: AppSizes.paddingXS,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.1),
              AppColors.subAccent.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 14, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

/// アイテム編集ボトムシート
class _EditItemSheet extends StatefulWidget {
  const _EditItemSheet({
    required this.item,
    required this.onSave,
    required this.tripId,
    required this.planId,
    this.onDelete,
    this.defaultDay,
  });

  final PlanItem? item;
  final Function(PlanItem) onSave;
  final String tripId;
  final String planId;
  final VoidCallback? onDelete;
  final int? defaultDay;

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late TextEditingController _locationController;
  late TextEditingController _notesController;
  late TextEditingController _durationController;
  late TextEditingController _bookingUrlController;
  late TextEditingController _bookingNoteController;
  final _durationFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _bookingUrlFocus = FocusNode();
  final _bookingNoteFocus = FocusNode();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  int _selectedDay = 1;
  bool _isBooked = false;
  String? _bookingImageUrl;
  bool _isUploadingImage = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(
      text: widget.item?.location ?? '',
    );
    _notesController = TextEditingController(text: widget.item?.notes ?? '');
    _durationController = TextEditingController(
      text: widget.item?.durationMinutes.toString() ?? '60',
    );
    _bookingUrlController = TextEditingController(
      text: widget.item?.bookingUrl ?? '',
    );
    _bookingNoteController = TextEditingController(
      text: widget.item?.bookingNote ?? '',
    );
    _isBooked = widget.item?.isBooked ?? false;
    _bookingImageUrl = widget.item?.bookingImageUrl;

    if (widget.defaultDay != null) {
      _selectedDay = widget.defaultDay!;
    }
    if (widget.item != null) {
      _selectedDay = widget.item!.day;
      final parts = widget.item!.time.split(':');
      if (parts.length == 2) {
        _selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 10,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    _bookingUrlController.dispose();
    _bookingNoteController.dispose();
    _durationFocus.dispose();
    _notesFocus.dispose();
    _bookingUrlFocus.dispose();
    _bookingNoteFocus.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.accent),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickBookingImage() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusL),
        ),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingL),
                  Text('予約画像', style: AppTypography.titleMedium),
                  const SizedBox(height: AppSizes.paddingL),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_outlined,
                      color: AppColors.accent,
                    ),
                    title: const Text('ライブラリから選択'),
                    onTap: () => Navigator.pop(context, 'gallery'),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.accent,
                    ),
                    title: const Text('カメラで撮影'),
                    onTap: () => Navigator.pop(context, 'camera'),
                  ),
                  if (_bookingImageUrl != null)
                    ListTile(
                      leading: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      title: const Text(
                        '画像を削除',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onTap: () => Navigator.pop(context, 'delete'),
                    ),
                  const SizedBox(height: AppSizes.paddingS),
                ],
              ),
            ),
          ),
    );

    if (result == null || !mounted) return;

    if (result == 'delete') {
      setState(() => _bookingImageUrl = null);
      return;
    }

    final source =
        result == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final XFile? image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image == null || !mounted) return;

    setState(() => _isUploadingImage = true);

    try {
      final bytes = await image.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('plans')
          .child(widget.tripId)
          .child('${widget.planId}_booking_$timestamp.jpg');

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await ref.getDownloadURL();

      if (mounted) {
        setState(() => _bookingImageUrl = downloadUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像のアップロードに失敗しました: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _save() {
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('場所を入力してください')));
      return;
    }

    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    final newItem = PlanItem(
      day: _selectedDay,
      time: timeStr,
      location: _locationController.text.trim(),
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      durationMinutes: int.tryParse(_durationController.text) ?? 60,
      latitude: widget.item?.latitude,
      longitude: widget.item?.longitude,
      cardId: widget.item?.cardId,
      isPlaceholder: widget.item?.isPlaceholder ?? false,
      isBooked: _isBooked,
      bookingUrl:
          _bookingUrlController.text.trim().isEmpty
              ? null
              : _bookingUrlController.text.trim(),
      bookingNote:
          _bookingNoteController.text.trim().isEmpty
              ? null
              : _bookingNoteController.text.trim(),
      bookingImageUrl: _bookingImageUrl,
    );

    widget.onSave(newItem);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSizes.paddingL,
        right: AppSizes.paddingL,
        top: AppSizes.paddingM,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.paddingL,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ハンドル
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),

            // タイトル
            Row(
              children: [
                Icon(
                  isNew ? Icons.add_location_alt : Icons.edit_location_alt,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppSizes.paddingS),
                Text(
                  isNew ? 'スポットを追加' : 'スポットを編集',
                  style: AppTypography.headlineSmall,
                ),
                const Spacer(),
                if (!isNew && widget.onDelete != null)
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDelete!();
                    },
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.error,
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingL),

            // 日程選択（セグメント形式）
            Text('日程', style: AppTypography.labelMedium),
            const SizedBox(height: AppSizes.paddingS),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(7, (index) {
                  final day = index + 1;
                  final isSelected = _selectedDay == day;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < 6 ? AppSizes.paddingS : 0,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedDay = day);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppColors.accent
                                  : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppColors.accent
                                    : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: AppTypography.titleMedium.copyWith(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),

            // 時間選択
            GestureDetector(
              onTap: _selectTime,
              child: AppCard(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.paddingS),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      ),
                      child: const Icon(
                        Icons.access_time,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingS),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('時間', style: AppTypography.caption),
                        Text(
                          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                          style: AppTypography.titleMedium,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),

            // 場所入力
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: '場所',
                hintText: '例: 渋谷駅、東京タワー',
                prefixIcon: const Icon(Icons.place_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
              ),
              autofocus: isNew,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _durationFocus.requestFocus(),
            ),
            const SizedBox(height: AppSizes.paddingS),

            // Google検索ボタン
            GestureDetector(
              onTap: () {
                final location = _locationController.text.trim();
                if (location.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('場所を入力してください')));
                  return;
                }
                HapticFeedback.lightImpact();
                final url =
                    'https://www.google.com/search?q=${Uri.encodeComponent(location)}';
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingM,
                  vertical: AppSizes.paddingS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Googleで検索',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.open_in_new,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.item?.latitude != null &&
                widget.item?.longitude != null) ...[
              const SizedBox(height: AppSizes.paddingS),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final lat = widget.item!.latitude!;
                  final lng = widget.item!.longitude!;
                  final label = Uri.encodeComponent(widget.item!.location);
                  final url =
                      'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$label';
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingM,
                    vertical: AppSizes.paddingS,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Google Mapで見る',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.open_in_new,
                        size: 12,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSizes.paddingM),

            // 滞在時間
            TextField(
              controller: _durationController,
              focusNode: _durationFocus,
              decoration: InputDecoration(
                labelText: '滞在時間（分）',
                hintText: '60',
                prefixIcon: const Icon(Icons.timer_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _notesFocus.requestFocus(),
            ),
            const SizedBox(height: AppSizes.paddingM),

            // メモ入力
            TextField(
              controller: _notesController,
              focusNode: _notesFocus,
              decoration: InputDecoration(
                labelText: 'メモ（任意）',
                hintText: '過ごし方やポイントなど',
                prefixIcon: const Icon(Icons.notes_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: AppSizes.paddingL),

            // 予約情報セクション
            Row(
              children: [
                Icon(
                  Icons.bookmark_outline,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSizes.paddingS),
                Text('予約情報', style: AppTypography.labelMedium),
                const Spacer(),
                Switch.adaptive(
                  value: _isBooked,
                  onChanged: (v) => setState(() => _isBooked = v),
                  activeColor: AppColors.accent,
                ),
              ],
            ),
            if (_isBooked) ...[
              const SizedBox(height: AppSizes.paddingS),
              TextField(
                controller: _bookingUrlController,
                focusNode: _bookingUrlFocus,
                decoration: InputDecoration(
                  labelText: '予約URL（任意）',
                  hintText: 'https://...',
                  prefixIcon: const Icon(Icons.link_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _bookingNoteFocus.requestFocus(),
              ),
              if (_bookingUrlController.text.trim().isNotEmpty) ...[
                const SizedBox(height: AppSizes.paddingXS),
                GestureDetector(
                  onTap: () {
                    final url = _bookingUrlController.text.trim();
                    if (url.isNotEmpty) {
                      launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '予約サイトを開く',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.paddingS),
              TextField(
                controller: _bookingNoteController,
                focusNode: _bookingNoteFocus,
                decoration: InputDecoration(
                  labelText: '予約メモ（任意）',
                  hintText: '確認番号、予約名など',
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
                maxLines: 2,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSizes.paddingM),
              // 予約画像
              GestureDetector(
                onTap: _isUploadingImage ? null : _pickBookingImage,
                child:
                    _bookingImageUrl != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: _bookingImageUrl!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder:
                                    (_, __) => Container(
                                      height: 160,
                                      color: AppColors.cardBackground,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    onPressed: _pickBookingImage,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        : Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusM,
                            ),
                            border: Border.all(
                              color: AppColors.border,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child:
                              _isUploadingImage
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: AppSizes.paddingS),
                                      Text(
                                        '予約画像を追加',
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                        ),
              ),
            ],
            const SizedBox(height: AppSizes.paddingL),

            // 保存ボタン
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, Color(0xFFE07B4C)],
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isNew ? Icons.add_circle : Icons.check_circle,
                      size: 20,
                    ),
                    const SizedBox(width: AppSizes.paddingS),
                    Text(
                      isNew ? '追加する' : '保存する',
                      style: AppTypography.button.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AIアシスタントシート
class _AIAssistantSheet extends ConsumerStatefulWidget {
  const _AIAssistantSheet({
    required this.planTitle,
    required this.planDescription,
    required this.items,
    required this.onApplySuggestion,
  });

  final String planTitle;
  final String planDescription;
  final List<PlanItem> items;
  final Function(List<PlanItem>) onApplySuggestion;

  @override
  ConsumerState<_AIAssistantSheet> createState() => _AIAssistantSheetState();
}

class _AIAssistantSheetState extends ConsumerState<_AIAssistantSheet> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  PlanEditSuggestion? _lastSuggestion;

  // クイックアクション
  static const _quickActions = [
    ('時間に余裕を持たせて', Icons.schedule),
    ('もっとアクティブに', Icons.directions_run),
    ('ランチスポットを追加', Icons.restaurant),
    ('移動時間を考慮して', Icons.directions_car),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // キーボードを閉じる
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _messages.add(_ChatMessage(text: message, isUser: true));
      _isLoading = true;
    });
    _inputController.clear();

    // スクロール
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      final aiService = ref.read(aiServiceProvider);
      final suggestion = await aiService.suggestPlanEdit(
        userRequest: message,
        currentPlanTitle: widget.planTitle,
        currentPlanDescription: widget.planDescription,
        currentItems: widget.items,
      );

      setState(() {
        _lastSuggestion = suggestion;
        _messages.add(
          _ChatMessage(
            text: suggestion.suggestion,
            isUser: false,
            tips: suggestion.tips,
            hasUpdatedItems: suggestion.updatedItems != null,
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
          _ChatMessage(text: 'すみません、エラーが発生しました。もう一度お試しください。', isUser: false),
        );
        _isLoading = false;
      });
    }
  }

  void _applySuggestion() {
    if (_lastSuggestion?.updatedItems != null) {
      final newItems = _lastSuggestion!.toPlanItems();
      if (newItems != null && newItems.isNotEmpty) {
        widget.onApplySuggestion(newItems);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('AIの提案を適用しました'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('提案の変換に失敗しました。もう一度お試しください'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
          ),
        );
      }
    }
  }

  void _showPreview() {
    if (_lastSuggestion?.updatedItems == null) return;
    final newItems = _lastSuggestion!.toPlanItems();
    if (newItems == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _SuggestionPreviewSheet(
            currentItems: widget.items,
            suggestedItems: newItems,
            suggestionText: _lastSuggestion!.suggestion,
            onApply: () {
              Navigator.pop(ctx);
              _applySuggestion();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      child: Column(
        children: [
          // ハンドル
          Padding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // ヘッダー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingS),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, Color(0xFFE07B4C)],
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AIアシスタント', style: AppTypography.titleMedium),
                      Text('プランの調整をお手伝いします', style: AppTypography.caption),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          const Divider(height: AppSizes.paddingL),

          // メッセージエリア
          Expanded(
            child:
                _messages.isEmpty
                    ? _buildWelcomeView()
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSizes.paddingM),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isLoading) {
                          return _buildLoadingBubble();
                        }
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
          ),

          // 提案プレビュー＆適用ボタン
          if (_lastSuggestion?.updatedItems != null)
            SlideFadeIn(
              offset: const Offset(0, 20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingL,
                  vertical: AppSizes.paddingS,
                ),
                child: Row(
                  children: [
                    // プレビューボタン
                    Expanded(
                      child: ScaleTapFeedback(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showPreview();
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusM,
                            ),
                            border: Border.all(color: AppColors.accent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                color: AppColors.accent,
                                size: 20,
                              ),
                              const SizedBox(width: AppSizes.paddingXS),
                              Text(
                                '確認する',
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingS),
                    // 適用ボタン
                    Expanded(
                      child: PulseAnimation(
                        minScale: 0.98,
                        maxScale: 1.02,
                        duration: const Duration(milliseconds: 2000),
                        child: ScaleTapFeedback(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _applySuggestion();
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.subAccent,
                                  Color(0xFF6BAF68),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusM,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.subAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: AppSizes.paddingXS),
                                Text(
                                  '適用する',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 入力エリア
          Container(
            padding: EdgeInsets.only(
              left: AppSizes.paddingM,
              right: AppSizes.paddingM,
              top: AppSizes.paddingS,
              bottom:
                  MediaQuery.of(context).viewInsets.bottom + AppSizes.paddingM,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: '例: ランチの時間を長めにして',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusFull,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingM,
                        vertical: AppSizes.paddingS,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingS),
                IconButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () => _sendMessage(_inputController.text),
                  icon: const Icon(Icons.send_rounded),
                  color: AppColors.accent,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeView() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        children: [
          // アニメーション付きアイコン
          BounceIn(
            child: Container(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.1),
                    AppColors.subAccent.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          SlideFadeIn(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'プランの調整をリクエストしてください',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingXL),
          SlideFadeIn(
            delay: const Duration(milliseconds: 300),
            child: Text(
              'クイックアクション',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          Wrap(
            spacing: AppSizes.paddingS,
            runSpacing: AppSizes.paddingS,
            alignment: WrapAlignment.center,
            children:
                _quickActions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final action = entry.value;
                  return SlideFadeIn(
                    delay: Duration(milliseconds: 400 + index * 100),
                    child: ScaleTapFeedback(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _sendMessage(action.$1);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingM,
                          vertical: AppSizes.paddingS,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(action.$2, size: 16, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text(
                              action.$1,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    // ユーザーメッセージは右から、AIメッセージは左からスライドイン
    return SlideFadeIn(
      offset: Offset(message.isUser ? 20 : -20, 0),
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.paddingM),
        child: Row(
          mainAxisAlignment:
              message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isUser) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, Color(0xFFE07B4C)],
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSizes.paddingS),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    message.isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    decoration: BoxDecoration(
                      color:
                          message.isUser
                              ? AppColors.accent
                              : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      border:
                          message.isUser
                              ? null
                              : Border.all(color: AppColors.border),
                      boxShadow:
                          message.isUser
                              ? [
                                BoxShadow(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Text(
                      message.text,
                      style: AppTypography.bodyMedium.copyWith(
                        color:
                            message.isUser
                                ? Colors.white
                                : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (message.tips != null) ...[
                    const SizedBox(height: AppSizes.paddingXS),
                    BounceIn(
                      delay: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingS,
                          vertical: AppSizes.paddingXS,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.subAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSizes.radiusS),
                          border: Border.all(
                            color: AppColors.subAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 14,
                              color: AppColors.subAccent,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                message.tips!,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.subAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (message.hasUpdatedItems) ...[
                    const SizedBox(height: AppSizes.paddingXS),
                    BounceIn(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingS,
                          vertical: AppSizes.paddingXS,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent.withValues(alpha: 0.1),
                              AppColors.subAccent.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon(
                              type: AppIconType.sparkle,
                              size: 16,
                              showBackground: false,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'スケジュール更新案があります',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (message.isUser) ...[
              const SizedBox(width: AppSizes.paddingS),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return SlideFadeIn(
      offset: const Offset(-20, 0),
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.paddingM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AIアイコン（パルスアニメーション付き）
            PulseAnimation(
              minScale: 0.95,
              maxScale: 1.05,
              duration: const Duration(milliseconds: 1500),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, Color(0xFFE07B4C)],
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.paddingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingM,
                vertical: AppSizes.paddingM,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // タイピングインジケーター
                  TypingIndicator(
                    color: AppColors.accent,
                    dotSize: 6,
                    duration: const Duration(milliseconds: 1200),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  Text(
                    '考え中',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// チャットメッセージ
class _ChatMessage {
  final String text;
  final bool isUser;
  final String? tips;
  final bool hasUpdatedItems;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.tips,
    this.hasUpdatedItems = false,
  });
}

/// AI提案プレビューシート
class _SuggestionPreviewSheet extends StatelessWidget {
  const _SuggestionPreviewSheet({
    required this.currentItems,
    required this.suggestedItems,
    required this.suggestionText,
    required this.onApply,
  });

  final List<PlanItem> currentItems;
  final List<PlanItem> suggestedItems;
  final String suggestionText;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    // 既存アイテムのlocationセットを作成して差分判定
    final currentLocations =
        currentItems.map((i) => '${i.day}_${i.time}_${i.location}').toSet();

    // 日程ごとにグルーピング
    final dayGroups = <int, List<_PreviewItem>>{};
    for (final item in suggestedItems) {
      final key = '${item.day}_${item.time}_${item.location}';
      final isNew = !currentLocations.contains(key);
      dayGroups
          .putIfAbsent(item.day, () => [])
          .add(_PreviewItem(item: item, isNew: isNew));
    }

    final days = dayGroups.keys.toList()..sort();
    final addedCount =
        dayGroups.values.expand((v) => v).where((p) => p.isNew).length;
    final removedCount =
        currentItems.length - (suggestedItems.length - addedCount);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      child: Column(
        children: [
          // ハンドル
          Padding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // ヘッダー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingS),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, Color(0xFFE07B4C)],
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: const Icon(
                    Icons.compare_arrows,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('提案プレビュー', style: AppTypography.titleMedium),
                      Text(
                        suggestionText,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          // 差分サマリー
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingL,
              vertical: AppSizes.paddingS,
            ),
            child: Row(
              children: [
                if (addedCount > 0)
                  _DiffBadge(
                    label: '+$addedCount 追加',
                    color: AppColors.subAccent,
                  ),
                if (addedCount > 0 && removedCount > 0)
                  const SizedBox(width: AppSizes.paddingS),
                if (removedCount > 0)
                  _DiffBadge(
                    label: '-$removedCount 削除',
                    color: Colors.redAccent,
                  ),
                const SizedBox(width: AppSizes.paddingS),
                _DiffBadge(
                  label: '計${suggestedItems.length}件',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // プレビューリスト
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              itemCount: days.length,
              itemBuilder: (context, dayIndex) {
                final day = days[dayIndex];
                final items = dayGroups[day]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewDayHeader(day: day),
                    ...items.map(
                      (pi) => _PreviewItemCard(item: pi.item, isNew: pi.isNew),
                    ),
                    const SizedBox(height: AppSizes.paddingS),
                  ],
                );
              },
            ),
          ),

          // 適用ボタン
          Container(
            padding: EdgeInsets.only(
              left: AppSizes.paddingL,
              right: AppSizes.paddingL,
              top: AppSizes.paddingM,
              bottom: MediaQuery.of(context).padding.bottom + AppSizes.paddingM,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ScaleTapFeedback(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '戻る',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                Expanded(
                  flex: 2,
                  child: ScaleTapFeedback(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onApply();
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.subAccent, Color(0xFF6BAF68)],
                        ),
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.subAccent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: AppSizes.paddingS),
                          Text(
                            'この内容で適用する',
                            style: AppTypography.labelMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewItem {
  final PlanItem item;
  final bool isNew;
  const _PreviewItem({required this.item, required this.isNew});
}

/// プレビュー用日付ヘッダー
class _PreviewDayHeader extends StatelessWidget {
  const _PreviewDayHeader({required this.day});
  final int day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSizes.paddingS,
        bottom: AppSizes.paddingS,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingM,
              vertical: AppSizes.paddingXS,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFFD4896E)],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  '$day日目',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.paddingS),
          Expanded(child: Container(height: 1, color: AppColors.border)),
        ],
      ),
    );
  }
}

/// プレビュー用アイテムカード
class _PreviewItemCard extends StatelessWidget {
  const _PreviewItemCard({required this.item, required this.isNew});

  final PlanItem item;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color:
            isNew
                ? AppColors.subAccent.withValues(alpha: 0.08)
                : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(
          color:
              isNew
                  ? AppColors.subAccent.withValues(alpha: 0.4)
                  : AppColors.border,
          width: isNew ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // 時間
          SizedBox(
            width: 52,
            child: Text(
              item.time,
              style: AppTypography.timeStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.paddingS),
          // タイムラインドット
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isNew ? AppColors.subAccent : AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: (isNew ? AppColors.subAccent : AppColors.accent)
                      .withValues(alpha: 0.3),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.paddingS),
          // コンテンツ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.location,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isNew)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.subAccent,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                        ),
                        child: Text(
                          'NEW',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.notes!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${item.durationMinutes}分',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 差分バッジ
class _DiffBadge extends StatelessWidget {
  const _DiffBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// ビュー切り替えトグル
class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.isMapView, required this.onChanged});

  final bool isMapView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              icon: Icons.view_list_rounded,
              label: '時系列',
              isSelected: !isMapView,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              icon: Icons.map_outlined,
              label: '地図',
              isSelected: isMapView,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

/// トグルボタン
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: AppSizes.paddingS,
          horizontal: AppSizes.paddingM,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cardBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// タイムライン行程間の挿入ボタン
class _InsertButton extends StatelessWidget {
  const _InsertButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            // 左側余白（時刻列と揃える）
            const SizedBox(width: 60),
            // タイムライン上の+ボタン
            SizedBox(
              width: 40,
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 14,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
            // 右側の点線
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(
                  left: 4,
                  right: AppSizes.paddingM,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AI挿入シート（軽量版）
class _AIInsertSheet extends ConsumerStatefulWidget {
  const _AIInsertSheet({
    required this.planTitle,
    required this.planDescription,
    required this.items,
    required this.insertAtIndex,
    required this.onInsert,
  });

  final String planTitle;
  final String planDescription;
  final List<PlanItem> items;
  final int insertAtIndex;
  final Function(List<PlanItem>) onInsert;

  @override
  ConsumerState<_AIInsertSheet> createState() => _AIInsertSheetState();
}

class _AIInsertSheetState extends ConsumerState<_AIInsertSheet> {
  final _inputController = TextEditingController();
  bool _isLoading = false;
  List<PlanItem>? _suggestedItems;
  String? _suggestionText;

  static const _quickActions = [
    'ランチスポットを追加',
    'カフェで休憩',
    '観光スポットを追加',
    'お土産を買う時間',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest(String message) async {
    if (message.trim().isEmpty) return;

    // キーボードを閉じる
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isLoading = true;
      _suggestedItems = null;
      _suggestionText = null;
    });

    try {
      final aiService = ref.read(aiServiceProvider);

      // 挿入位置のコンテキストを付加
      final contextMessage = _buildContextMessage(message);

      final suggestion = await aiService.suggestPlanEdit(
        userRequest: contextMessage,
        currentPlanTitle: widget.planTitle,
        currentPlanDescription: widget.planDescription,
        currentItems: widget.items,
      );

      if (!mounted) return;

      // 差分を抽出（新しく追加されたアイテム）
      final newItems = _extractNewItems(suggestion.toPlanItems());

      setState(() {
        _suggestionText = suggestion.suggestion;
        _suggestedItems = newItems;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestionText = 'エラーが発生しました。もう一度お試しください。';
          _isLoading = false;
        });
      }
    }
  }

  String _buildContextMessage(String userMessage) {
    // 前後のアイテム情報をコンテキストとして付加
    final idx = widget.insertAtIndex;
    final prevItem = idx > 0 ? widget.items[idx - 1] : null;
    final nextItem = idx < widget.items.length ? widget.items[idx] : null;

    final context = StringBuffer();
    if (prevItem != null) {
      context.write('「${prevItem.location}（${prevItem.time}）」の後');
    }
    if (nextItem != null) {
      if (context.isNotEmpty) context.write('、');
      context.write('「${nextItem.location}（${nextItem.time}）」の前');
    }

    if (context.isNotEmpty) {
      return '${context.toString()}に、$userMessage';
    }
    return userMessage;
  }

  List<PlanItem>? _extractNewItems(List<PlanItem>? allItems) {
    if (allItems == null) return null;

    // 既存のlocation一覧
    final existingLocations = widget.items.map((i) => i.location).toSet();

    // 新しいアイテムを抽出
    final newItems =
        allItems
            .where((item) => !existingLocations.contains(item.location))
            .toList();

    return newItems.isNotEmpty ? newItems : null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSizes.paddingL,
        right: AppSizes.paddingL,
        top: AppSizes.paddingM,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.paddingL,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ハンドル
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),

            // タイトル
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.accent),
                const SizedBox(width: AppSizes.paddingS),
                Text('AIにスポット追加を依頼', style: AppTypography.headlineSmall),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.paddingM),

            // 挿入位置の説明
            _buildInsertContext(),
            const SizedBox(height: AppSizes.paddingM),

            // クイックアクション
            if (_suggestedItems == null && !_isLoading)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _quickActions
                        .map(
                          (action) => ActionChip(
                            label: Text(
                              action,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: AppColors.cardBackground,
                            side: BorderSide(color: AppColors.border),
                            onPressed: () {
                              _inputController.text = action;
                              _sendRequest(action);
                            },
                          ),
                        )
                        .toList(),
              ),
            if (_suggestedItems == null && !_isLoading)
              const SizedBox(height: AppSizes.paddingM),

            // 入力欄
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: '例: この辺りでランチが食べたい',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendRequest,
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingS),
                IconButton.filled(
                  onPressed:
                      _isLoading
                          ? null
                          : () => _sendRequest(_inputController.text),
                  icon:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.send, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accent,
                  ),
                ),
              ],
            ),

            // ローディング
            if (_isLoading) ...[
              const SizedBox(height: AppSizes.paddingL),
              Center(
                child: Text(
                  'AIが考えています...',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],

            // 提案テキスト
            if (_suggestionText != null && !_isLoading) ...[
              const SizedBox(height: AppSizes.paddingM),
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Text(_suggestionText!, style: AppTypography.bodyMedium),
              ),
            ],

            // 提案されたアイテムのプレビュー
            if (_suggestedItems != null && !_isLoading) ...[
              const SizedBox(height: AppSizes.paddingM),
              Text('追加するスポット:', style: AppTypography.labelMedium),
              const SizedBox(height: AppSizes.paddingS),
              for (final item in _suggestedItems!)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.place, color: AppColors.accent, size: 20),
                      const SizedBox(width: AppSizes.paddingS),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.location,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${item.day}日目 ${item.time}  ${item.durationMinutes}分',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (item.notes != null)
                              Text(
                                item.notes!,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSizes.paddingS),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, Color(0xFFE07B4C)],
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    widget.onInsert(_suggestedItems!);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${_suggestedItems!.length}件のスポットを追加しました',
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusM),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle, size: 20),
                      const SizedBox(width: AppSizes.paddingS),
                      Text(
                        '追加する',
                        style: AppTypography.button.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSizes.paddingS),
          ],
        ),
      ),
    );
  }

  Widget _buildInsertContext() {
    final idx = widget.insertAtIndex;
    final prevItem = idx > 0 ? widget.items[idx - 1] : null;
    final nextItem = idx < widget.items.length ? widget.items[idx] : null;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_vert, size: 16, color: AppColors.accent),
          const SizedBox(width: AppSizes.paddingS),
          Expanded(
            child: Text(
              prevItem != null && nextItem != null
                  ? '${prevItem.location} と ${nextItem.location} の間に追加'
                  : prevItem != null
                  ? '${prevItem.location} の後に追加'
                  : nextItem != null
                  ? '${nextItem.location} の前に追加'
                  : 'スケジュールに追加',
              style: AppTypography.caption.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
