import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/models/plan_model.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../shared/providers/user_profile_provider.dart';
import '../../../../shared/services/ai_service.dart';
import '../../../../shared/services/plan_export_service.dart';
import '../../../../shared/utils/file_saver.dart' as file_saver;
import '../../../../shared/providers/ad_provider.dart';
import '../../../../shared/widgets/animated_widgets.dart';
import '../providers/plan_provider.dart';
import 'plan_view_screen.dart';
import 'travel_animation_screen.dart';

/// しおり編集画面（共同編集対応）
class PlanEditScreen extends ConsumerStatefulWidget {
  const PlanEditScreen({
    super.key,
    required this.tripId,
    required this.plan,
    this.tripTitle,
    this.startDate,
    this.endDate,
  });

  final String tripId;
  final PlanModel plan;
  final String? tripTitle;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  ConsumerState<PlanEditScreen> createState() => _PlanEditScreenState();
}

class _PlanEditScreenState extends ConsumerState<PlanEditScreen> {
  final _uuid = const Uuid();
  final GlobalKey _exportKey = GlobalKey();

  late TextEditingController _titleController;
  late List<PlanItem> _items;
  bool _isSaving = false;
  bool _showSaveIndicator = false;
  Timer? _debounceTimer;
  final ScrollController _scrollController = ScrollController();

  // リアルタイム同期用
  String? _otherEditorName;
  DateTime? _lastSaveTime;
  DateTime? _ignoreStreamUntil;
  bool _isDragging = false;

  // 画像インポート用
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.plan.title);
    _items = _ensureItemIds(widget.plan.items);
    _lastSaveTime = widget.plan.updatedAt ?? widget.plan.createdAt;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setPresence(active: true);
      _listenToExternalChanges();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _scrollController.dispose();
    _setPresence(active: false);
    super.dispose();
  }

  List<PlanItem> _ensureItemIds(List<PlanItem> items) {
    return items
        .map((item) => item.id.isEmpty ? item.copyWith(id: _uuid.v4()) : item)
        .toList();
  }

  void _setPresence({required bool active}) {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    ref
        .read(planControllerProvider.notifier)
        .setEditingPresence(
          tripId: widget.tripId,
          planId: widget.plan.id,
          userId: active ? userId : null,
          userName: active ? profile?.displayName : null,
        );
  }

  void _listenToExternalChanges() {
    final currentUserId = ref.read(currentUserIdProvider);
    ref.listenManual(
      watchPlanProvider((tripId: widget.tripId, planId: widget.plan.id)),
      (previous, next) {
        final plan = next.valueOrNull;
        if (plan == null || !mounted) return;

        if (_ignoreStreamUntil != null &&
            DateTime.now().isBefore(_ignoreStreamUntil!)) {
          return;
        }
        _ignoreStreamUntil = null;

        // 他のユーザーの編集プレゼンス
        if (plan.editingBy != null && plan.editingBy != currentUserId) {
          setState(() {
            _otherEditorName = plan.lastEditedByName ?? '他のメンバー';
          });
        } else if (_otherEditorName != null) {
          setState(() => _otherEditorName = null);
        }

        // 外部からの変更を反映
        if (plan.updatedAt != null &&
            _lastSaveTime != null &&
            plan.updatedAt!.isAfter(_lastSaveTime!)) {
          bool updated = false;

          if (plan.title != _titleController.text) {
            _titleController.text = plan.title;
            updated = true;
          }

          if (!_isDragging && plan.items.isNotEmpty) {
            final newItems = _ensureItemIds(plan.items);
            if (_itemsChanged(newItems)) {
              _items = newItems;
              updated = true;
            }
          }

          if (updated) {
            _lastSaveTime = plan.updatedAt;
            setState(() => _showSaveIndicator = true);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _showSaveIndicator = false);
            });
          }
        }
      },
    );
  }

  bool _itemsChanged(List<PlanItem> newItems) {
    if (_items.length != newItems.length) return true;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].location != newItems[i].location ||
          _items[i].time != newItems[i].time ||
          _items[i].notes != newItems[i].notes) {
        return true;
      }
    }
    return false;
  }

  void _saveItems() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_isSaving) return;
      setState(() => _isSaving = true);
      _ignoreStreamUntil = DateTime.now().add(const Duration(seconds: 3));

      final profile = ref.read(currentUserProfileProvider).valueOrNull;

      await ref
          .read(planControllerProvider.notifier)
          .updatePlanItems(
            tripId: widget.tripId,
            planId: widget.plan.id,
            items: _items,
            editedByName: profile?.displayName,
          );

      _lastSaveTime = DateTime.now();
      if (mounted) {
        setState(() {
          _isSaving = false;
          _showSaveIndicator = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showSaveIndicator = false);
        });
      }
    });
  }

  void _saveTitle() {
    _ignoreStreamUntil = DateTime.now().add(const Duration(seconds: 3));
    ref
        .read(planControllerProvider.notifier)
        .updatePlanTitle(
          tripId: widget.tripId,
          planId: widget.plan.id,
          title: _titleController.text,
        );
    _lastSaveTime = DateTime.now();
  }

  // --- 画像インポート ---
  Future<void> _importFromImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final bytes = await image.readAsBytes();
      final mimeType = image.mimeType ?? 'image/jpeg';

      final newItems = await ref.read(aiServiceProvider).analyzeImageForItinerary(
        imageBytes: bytes,
        mimeType: mimeType,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      if (newItems.isNotEmpty && mounted) {
        final addedItems = _ensureItemIds(newItems);
        setState(() {
          _items.addAll(addedItems);
          _isAnalyzing = false;
        });
        _saveItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${addedItems.length}件の予定をインポートしました'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          );
        }
      } else {
        setState(() => _isAnalyzing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('画像から予定を読み取れませんでした'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('インポートに失敗しました: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
          ),
        );
      }
    }
  }

  // --- アイテム操作 ---
  void _addItem() {
    final maxDay = _items.isEmpty ? 1 : _items.map((e) => e.day).reduce((a, b) => a > b ? a : b);
    setState(() {
      _items.add(PlanItem(
        id: _uuid.v4(),
        day: maxDay,
        time: '12:00',
        location: '',
        durationMinutes: 60,
      ));
    });
    _saveItems();
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
    _saveItems();
  }

  void _editItem(int index) {
    final item = _items[index];
    _showEditItemDialog(item, (updated) {
      setState(() => _items[index] = updated);
      _saveItems();
    });
  }

  void _showEditItemDialog(PlanItem item, ValueChanged<PlanItem> onSave) {
    final locationCtrl = TextEditingController(text: item.location);
    final timeCtrl = TextEditingController(text: item.time);
    final notesCtrl = TextEditingController(text: item.notes ?? '');
    final durationCtrl = TextEditingController(text: item.durationMinutes.toString());
    var day = item.day;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: AppSizes.paddingL,
            right: AppSizes.paddingL,
            top: AppSizes.paddingL,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSizes.paddingL,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ハンドル
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.paddingL),
                Text('予定を編集', style: AppTypography.titleMedium),
                const SizedBox(height: AppSizes.paddingL),

                // Day
                Row(
                  children: [
                    Text('Day ', style: AppTypography.labelMedium),
                    SizedBox(
                      width: 60,
                      child: DropdownButton<int>(
                        value: day,
                        isExpanded: true,
                        items: List.generate(10, (i) => i + 1)
                            .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                            .toList(),
                        onChanged: (v) => setSheetState(() => day = v!),
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingL),
                    // Time
                    Expanded(
                      child: TextField(
                        controller: timeCtrl,
                        decoration: InputDecoration(
                          labelText: '時間',
                          hintText: '10:00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Location
                TextField(
                  controller: locationCtrl,
                  decoration: InputDecoration(
                    labelText: '場所・予定',
                    hintText: '東京タワー',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Duration
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '滞在時間（分）',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Notes
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'メモ',
                    hintText: '予約番号: XXX',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.paddingL),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      onSave(item.copyWith(
                        day: day,
                        time: timeCtrl.text,
                        location: locationCtrl.text,
                        notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                        durationMinutes: int.tryParse(durationCtrl.text) ?? 60,
                      ));
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingM),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                    ),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      locationCtrl.dispose();
      timeCtrl.dispose();
      notesCtrl.dispose();
      durationCtrl.dispose();
    });
  }

  // --- エクスポート ---
  Future<void> _showAdThenExport(Future<void> Function() exportFn) async {
    // エクスポート前にインタースティシャル広告
    final adService = ref.read(adServiceProvider);
    if (adService.isSupported) {
      await adService.showInterstitialAdIfNeeded();
    }
    await exportFn();
  }

  String get _safeFileName {
    final title = _titleController.text.replaceAll(RegExp(r'[^\w\u3040-\u9FFF]'), '_');
    return title.isEmpty ? 'shiori' : title;
  }

  Future<void> _exportAsImage() async {
    _showExportProgress('画像を作成中...');
    try {
      final bytes = await PlanExportService.exportImageAsBytes(
        _exportKey,
        pixelRatio: 3.0,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss progress

      if (kIsWeb) {
        file_saver.triggerBrowserDownload(bytes, '$_safeFileName.png', 'image/png');
        _showExportSuccess('画像をダウンロードしました');
      } else {
        final path = await file_saver.saveToFile(bytes, '$_safeFileName.png');
        if (mounted) {
          await Share.shareXFiles([XFile(path)], text: _titleController.text);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showExportError('画像の作成に失敗しました');
      }
    }
  }

  Future<void> _exportAsPdf() async {
    _showExportProgress('PDFを作成中...');
    try {
      final plan = widget.plan.copyWith(items: _items, title: _titleController.text);
      final bytes = await PlanExportService.exportPdfAsBytes(
        plan: plan,
        tripTitle: widget.tripTitle ?? plan.title,
        startDate: widget.startDate,
      );
      if (!mounted) return;
      Navigator.of(context).pop();

      if (kIsWeb) {
        file_saver.triggerBrowserDownload(bytes, '$_safeFileName.pdf', 'application/pdf');
        _showExportSuccess('PDFをダウンロードしました');
      } else {
        final path = await file_saver.saveToFile(bytes, '$_safeFileName.pdf');
        if (mounted) {
          final box = context.findRenderObject() as RenderBox?;
          final sharePositionOrigin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
          await Share.shareXFiles(
            [XFile(path)], 
            text: _titleController.text,
            sharePositionOrigin: sharePositionOrigin,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showExportError('PDFの作成に失敗しました');
      }
    }
  }

  void _showExportProgress(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3),
                const SizedBox(height: 16),
                Text(message, style: AppTypography.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExportSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusM)),
      ),
    );
  }

  void _showExportError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusM)),
      ),
    );
  }

  void _showExportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.image_outlined, color: AppColors.accent),
                title: const Text('画像で保存'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAdThenExport(_exportAsImage);
                },
              ),
              ListTile(
                leading: Icon(Icons.picture_as_pdf_outlined, color: AppColors.accent),
                title: const Text('PDFで保存'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAdThenExport(_exportAsPdf);
                },
              ),
              ListTile(
                leading: Icon(Icons.play_circle_outline, color: AppColors.accent),
                title: const Text('アニメーションで見る'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TravelAnimationScreen(
                        items: _items,
                        planTitle: _titleController.text,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSizes.paddingM),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 日ごとにグループ化
    final dayGroups = <int, List<MapEntry<int, PlanItem>>>{};
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      dayGroups.putIfAbsent(item.day, () => []).add(MapEntry(i, item));
    }
    final sortedDays = dayGroups.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: SizedBox(
          height: 36,
          child: TextField(
            controller: _titleController,
            style: AppTypography.titleMedium,
            decoration: InputDecoration(
              hintText: 'しおりのタイトル',
              hintStyle: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onSubmitted: (_) => _saveTitle(),
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
              _saveTitle();
            },
          ),
        ),
        actions: [
          if (_showSaveIndicator)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.cloud_done_outlined, color: AppColors.accent, size: 20),
            ),
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
            ),
          // しおりビュー
          IconButton(
            icon: Icon(Icons.auto_stories_outlined, color: AppColors.textSecondary),
            tooltip: 'しおりビュー',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlanViewScreen(
                    tripId: widget.tripId,
                    plan: widget.plan.copyWith(items: _items, title: _titleController.text),
                    startDate: widget.startDate,
                    endDate: widget.endDate,
                    tripTitle: widget.tripTitle,
                  ),
                ),
              );
            },
          ),
          // エクスポート
          IconButton(
            icon: Icon(Icons.ios_share_outlined, color: AppColors.textSecondary),
            tooltip: 'エクスポート',
            onPressed: _showExportMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // 共同編集バナー
          if (_otherEditorName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM, vertical: AppSizes.paddingS),
              color: AppColors.accent.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16, color: AppColors.accent),
                  const SizedBox(width: AppSizes.paddingS),
                  Text(
                    '$_otherEditorNameが編集中',
                    style: AppTypography.caption.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ),

          // 画像解析中 — スケルトンカードで体感待ち時間を短縮
          if (_isAnalyzing)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.paddingM, AppSizes.paddingS, AppSizes.paddingM, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: AppSizes.paddingS),
                    child: Text('画像を解析中...', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                  ),
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.paddingS),
                      child: Row(
                        children: [
                          ShimmerLoading(width: 50, height: 14, borderRadius: 4),
                          const SizedBox(width: 28),
                          Expanded(child: ShimmerLoading(width: double.infinity, height: 52, borderRadius: AppSizes.radiusM)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // メインコンテンツ
          Expanded(
            child: RepaintBoundary(
              key: _exportKey,
              child: _items.isEmpty
                  ? _buildEmptyState()
                  : ReorderableListView.builder(
                      scrollController: _scrollController,
                      padding: const EdgeInsets.all(AppSizes.paddingM),
                      itemCount: _items.length + sortedDays.length,
                      onReorderStart: (_) => _isDragging = true,
                      onReorderEnd: (_) => _isDragging = false,
                      onReorder: (oldIndex, newIndex) {
                        // ヘッダーを除いた実際のインデックスに変換
                        final actualOld = _flatToItemIndex(oldIndex, sortedDays, dayGroups);
                        final rawNew = _flatToItemIndex(newIndex > oldIndex ? newIndex - 1 : newIndex, sortedDays, dayGroups);
                        if (actualOld == null || rawNew == null) return;
                        var actualNew = rawNew;
                        if (actualNew > actualOld) actualNew++;

                        setState(() {
                          final item = _items.removeAt(actualOld);
                          if (actualNew > _items.length) actualNew = _items.length;
                          _items.insert(actualNew, item);
                        });
                        _saveItems();
                      },
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          child: child,
                        );
                      },
                      itemBuilder: (context, flatIndex) {
                        // flatIndexをDay headerかitemかに変換
                        int headerCount = 0;
                        for (final day in sortedDays) {
                          if (flatIndex == headerCount) {
                            // Day header（並べ替え不可）
                            return IgnorePointer(
                              key: ValueKey('day_header_$day'),
                              child: _DayHeader(day: day, startDate: widget.startDate),
                            );
                          }
                          headerCount++;
                          final items = dayGroups[day]!;
                          if (flatIndex < headerCount + items.length) {
                            final localIndex = flatIndex - headerCount;
                            final itemEntry = items[localIndex];
                            return _ItemTile(
                              key: ValueKey('item_${itemEntry.value.id}'),
                              item: itemEntry.value,
                              onEdit: () => _editItem(itemEntry.key),
                              onDelete: () => _removeItem(itemEntry.key),
                              isFirst: localIndex == 0,
                              isLast: localIndex == items.length - 1,
                            );
                          }
                          headerCount += items.length;
                        }
                        return const SizedBox.shrink(key: ValueKey('empty'));
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  int? _flatToItemIndex(int flatIndex, List<int> sortedDays, Map<int, List<MapEntry<int, PlanItem>>> dayGroups) {
    int headerCount = 0;
    for (final day in sortedDays) {
      headerCount++; // header
      final items = dayGroups[day]!;
      if (flatIndex < headerCount) return null; // header
      if (flatIndex < headerCount + items.length) {
        return items[flatIndex - headerCount].key;
      }
      headerCount += items.length;
    }
    return null;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: AppSizes.paddingL),
            Text(
              'しおりに予定を追加しましょう',
              style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.paddingS),
            Text(
              '手動で追加するか、画像からインポートできます',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.paddingXL),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('手動で追加'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                ElevatedButton.icon(
                  onPressed: _importFromImage,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('画像から'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Day ヘッダー（編集用 — 日付表示付き）
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, this.startDate});
  final int day;
  final DateTime? startDate;

  String get _label {
    if (startDate == null) return 'Day $day';
    final date = startDate!.add(Duration(days: day - 1));
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return 'Day $day — ${date.month}/${date.day}（${weekdays[date.weekday - 1]}）';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.paddingXL, bottom: AppSizes.paddingS),
      child: Row(
        children: [
          const SizedBox(width: 54),
          // Day ラベル
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              _label,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.paddingS),
          Expanded(child: Divider(color: AppColors.accent.withValues(alpha: 0.2))),
        ],
      ),
    );
  }
}

/// アイテムタイル（タイムライン編集用）
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.isFirst = false,
    this.isLast = false,
  });

  final PlanItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isFirst;
  final bool isLast;

  Color get _timeColor {
    final parts = item.time.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '12') ?? 12;
    if (hour < 7) return Colors.indigo;
    if (hour < 10) return Colors.orange;
    if (hour < 12) return Colors.amber[700]!;
    if (hour < 14) return Colors.deepOrange;
    if (hour < 17) return Colors.teal;
    if (hour < 19) return Colors.deepPurple;
    return Colors.indigo;
  }

  @override
  Widget build(BuildContext context) {
    final color = _timeColor;

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // === 左レール: 時間 + タイムライン ===
              SizedBox(
                width: 50,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.time,
                      style: AppTypography.labelMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.durationMinutes}分',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // === タイムライン縦線 + ノード ===
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: isFirst ? Colors.transparent : AppColors.border,
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: isLast ? Colors.transparent : AppColors.border,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // === コンテンツカード ===
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.fromLTRB(AppSizes.paddingM, AppSizes.paddingS, AppSizes.paddingXS, AppSizes.paddingS),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.location.isEmpty ? '（場所未設定）' : item.location,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: item.location.isEmpty
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (item.notes != null && item.notes!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.notes!,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (item.isBooked) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 12, color: Colors.green[600]),
                                  const SizedBox(width: 3),
                                  Text('予約済み',
                                    style: AppTypography.caption.copyWith(
                                      color: Colors.green[600],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // 削除ボタン
                      GestureDetector(
                        onTap: onDelete,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.delete_outline, size: 20, color: AppColors.error.withValues(alpha: 0.5)),
                        ),
                      ),
                      // ドラッグハンドル
                      Icon(Icons.drag_handle, size: 20, color: AppColors.textSecondary.withValues(alpha: 0.3)),
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

