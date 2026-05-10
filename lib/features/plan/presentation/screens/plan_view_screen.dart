import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../shared/providers/ad_provider.dart';
import '../../../../shared/utils/file_saver.dart' as file_saver;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/models/plan_model.dart';
import '../../../../shared/services/plan_export_service.dart';
import 'plan_edit_screen.dart';
import 'travel_animation_screen.dart';

/// しおりビュー画面（かわいい時間連動UI）
class PlanViewScreen extends ConsumerStatefulWidget {
  const PlanViewScreen({
    super.key,
    required this.tripId,
    required this.plan,
    this.startDate,
    this.endDate,
    this.tripTitle,
  });

  final String tripId;
  final PlanModel plan;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? tripTitle;

  @override
  ConsumerState<PlanViewScreen> createState() => _PlanViewScreenState();
}

class _PlanViewScreenState extends ConsumerState<PlanViewScreen> {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  final GlobalKey _exportKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentItem());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// 当日かどうか判定（JST基準）
  /// startDateからday番号に対応する日付を計算し、今日のJST日付と一致するかチェック
  bool _isTodayDay(int day) {
    if (widget.startDate == null) return false;
    // JST = UTC+9
    final nowJst = _currentTime.toUtc().add(const Duration(hours: 9));
    final tripDate = widget.startDate!.toUtc().add(const Duration(hours: 9)).add(Duration(days: day - 1));
    return nowJst.year == tripDate.year &&
        nowJst.month == tripDate.month &&
        nowJst.day == tripDate.day;
  }

  void _scrollToCurrentItem() {
    if (widget.startDate == null) return;
    // 当日のDayを見つける
    final items = widget.plan.items;
    int? todayDay;
    for (final item in items) {
      if (_isTodayDay(item.day)) {
        todayDay = item.day;
        break;
      }
    }
    if (todayDay == null) return;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    int targetIndex = 0;
    for (var i = 0; i < items.length; i++) {
      if (items[i].day != todayDay) continue;
      final parts = items[i].time.split(':');
      if (parts.length == 2) {
        final itemMinutes = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
        if (itemMinutes <= currentMinutes) targetIndex = i;
      }
    }

    if (targetIndex > 0 && _scrollController.hasClients) {
      _scrollController.animateTo(
        targetIndex * 140.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _isCurrentItem(PlanItem item) {
    if (!_isTodayDay(item.day)) return false;
    final currentMinutes = _currentTime.hour * 60 + _currentTime.minute;
    final parts = item.time.split(':');
    if (parts.length != 2) return false;
    final startMinutes = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    return currentMinutes >= startMinutes && currentMinutes < startMinutes + item.durationMinutes;
  }

  bool _isPastItem(PlanItem item) {
    if (!_isTodayDay(item.day)) return false;
    final currentMinutes = _currentTime.hour * 60 + _currentTime.minute;
    final parts = item.time.split(':');
    if (parts.length != 2) return false;
    final startMinutes = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    return currentMinutes > startMinutes + item.durationMinutes;
  }

  String get _safeFileName {
    final title = widget.plan.title.replaceAll(RegExp(r'[^\w\u3040-\u9FFF]'), '_');
    return title.isEmpty ? 'shiori' : title;
  }

  // --- Export ---
  Future<void> _showAdThenExport(Future<void> Function() exportFn) async {
    final adService = ref.read(adServiceProvider);
    if (adService.isSupported) {
      await adService.showInterstitialAdIfNeeded();
    }
    await exportFn();
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

  Future<void> _exportAsImage() async {
    _showExportProgress('画像を作成中...');
    try {
      final bytes = await PlanExportService.exportImageAsBytes(_exportKey, pixelRatio: 2.0);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (kIsWeb) {
        file_saver.triggerBrowserDownload(bytes, '$_safeFileName.png', 'image/png');
        _showExportSuccess('画像をダウンロードしました');
      } else {
        final path = await file_saver.saveToFile(bytes, '$_safeFileName.png');
        if (mounted) {
          final box = context.findRenderObject() as RenderBox?;
          final sharePositionOrigin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
          await Share.shareXFiles(
            [XFile(path)],
            text: widget.plan.title,
            sharePositionOrigin: sharePositionOrigin,
          );
        }
      }
    } catch (e) {
      if (mounted) { Navigator.of(context).pop(); _showExportError('画像の作成に失敗しました'); }
    }
  }

  Future<void> _exportAsPdf() async {
    _showExportProgress('PDFを作成中...');
    try {
      final bytes = await PlanExportService.exportPdfAsBytes(
        plan: widget.plan,
        tripTitle: widget.tripTitle ?? widget.plan.title,
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
            text: widget.plan.title,
            sharePositionOrigin: sharePositionOrigin,
          );
        }
      }
    } catch (e) {
      if (mounted) { Navigator.of(context).pop(); _showExportError('PDFの作成に失敗しました'); }
    }
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
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              ListTile(
                leading: Icon(Icons.image_outlined, color: AppColors.accent),
                title: const Text('画像で保存'),
                onTap: () { Navigator.pop(ctx); _showAdThenExport(_exportAsImage); },
              ),
              ListTile(
                leading: Icon(Icons.picture_as_pdf_outlined, color: AppColors.accent),
                title: const Text('PDFで保存'),
                onTap: () { Navigator.pop(ctx); _showAdThenExport(_exportAsPdf); },
              ),
              ListTile(
                leading: Icon(Icons.play_circle_outline, color: AppColors.accent),
                title: const Text('アニメーションで見る'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TravelAnimationScreen(
                        items: widget.plan.items,
                        planTitle: widget.plan.title,
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

  /// Dayから日付文字列を生成
  String _dayDateLabel(int day) {
    if (widget.startDate == null) return 'Day $day';
    final date = widget.startDate!.add(Duration(days: day - 1));
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return 'Day $day  ${date.month}/${date.day}（${weekdays[date.weekday - 1]}）';
  }

  void _openEditScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlanEditScreen(
          tripId: widget.tripId,
          plan: widget.plan,
          tripTitle: widget.tripTitle,
          startDate: widget.startDate,
          endDate: widget.endDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.plan.items;
    final dayGroups = <int, List<PlanItem>>{};
    for (final item in items) {
      dayGroups.putIfAbsent(item.day, () => []).add(item);
    }
    final sortedDays = dayGroups.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.plan.title,
          style: AppTypography.titleMedium,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        titleSpacing: 0,
        actions: [
          // エクスポート
          IconButton(
            icon: Icon(Icons.ios_share_outlined, color: AppColors.textSecondary),
            onPressed: _showExportMenu,
          ),
        ],
      ),
      body: RepaintBoundary(
        key: _exportKey,
        child: items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_stories_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: AppSizes.paddingM),
                    Text('まだ予定がありません', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSizes.paddingL),
                    ElevatedButton.icon(
                      onPressed: _openEditScreen,
                      icon: const Icon(Icons.add),
                      label: const Text('予定を追加'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(AppSizes.paddingM, 0, AppSizes.paddingM, AppSizes.paddingXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final day in sortedDays) ...[
                      _ShioriDayHeader(
                        label: _dayDateLabel(day),
                        isToday: _isTodayDay(day),
                      ),
                      for (final item in dayGroups[day]!)
                        _ShioriItemCard(
                          item: item,
                          isCurrent: _isCurrentItem(item),
                          isPast: _isPastItem(item),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// しおり Day ヘッダー
class _ShioriDayHeader extends StatelessWidget {
  const _ShioriDayHeader({required this.label, this.isToday = false});
  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.paddingXL, bottom: AppSizes.paddingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isToday) ...[
                  const Icon(Icons.today, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.3),
                    AppColors.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// しおりアイテムカード（時間連動UI）
class _ShioriItemCard extends StatelessWidget {
  const _ShioriItemCard({
    required this.item,
    required this.isCurrent,
    required this.isPast,
  });

  final PlanItem item;
  final bool isCurrent;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final cardColor = isCurrent
        ? AppColors.accent.withValues(alpha: 0.08)
        : AppColors.cardBackground;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        color: cardColor,
        elevation: isCurrent ? 4 : 1,
        shadowColor: isCurrent ? AppColors.accent.withValues(alpha: 0.3) : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          side: isCurrent
              ? BorderSide(color: AppColors.accent.withValues(alpha: 0.4), width: 1.5)
              : BorderSide(color: AppColors.border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 時間
              Column(
                children: [
                  Text(
                    item.time,
                    style: AppTypography.labelMedium.copyWith(
                      color: isCurrent ? AppColors.accent : AppColors.textSecondary,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Text(
                        'NOW',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: AppSizes.paddingM),
              // タイムライン
              Container(
                width: 2,
                height: 60,
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.accent : AppColors.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              // コンテンツ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(
                        item.location.isEmpty ? '（未定）' : item.location,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600, fontSize: isCurrent ? 16 : 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('${item.durationMinutes}分',
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                      if (item.notes != null && item.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppSizes.radiusS),
                          ),
                          child: Text(item.notes!,
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      if (item.isBooked) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
                              const SizedBox(width: 4),
                              Text('予約済み',
                                style: AppTypography.caption.copyWith(
                                  color: Colors.green[600], fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              // end Expanded
            ],
          ),
        ),
      ),
    );
  }
}
