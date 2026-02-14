import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/models/plan_model.dart';
import '../../../../shared/models/trip_model.dart';
import '../../../../shared/services/ai_service.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../providers/plan_provider.dart';
import '../widgets/placeholder_action_sheet.dart';
import '../widgets/plan_map_view.dart';
import 'plan_edit_screen.dart';

/// プラン閲覧画面（読み取り専用）
class PlanViewScreen extends ConsumerStatefulWidget {
  const PlanViewScreen({
    super.key,
    required this.tripId,
    required this.plan,
    this.trip,
  });

  final String tripId;
  final PlanModel plan;
  final TripModel? trip;

  @override
  ConsumerState<PlanViewScreen> createState() => _PlanViewScreenState();
}

class _PlanViewScreenState extends ConsumerState<PlanViewScreen> {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  int _currentDay = 1;
  bool _isMapView = false;

  @override
  void initState() {
    super.initState();
    _updateCurrentDay();
    // 1分ごとに現在時刻を更新
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
          _updateCurrentDay();
        });
      }
    });
  }

  void _updateCurrentDay() {
    if (widget.trip?.startDate != null) {
      final startDate = widget.trip!.startDate!;
      final today = DateTime.now();
      final difference = today.difference(startDate).inDays;
      _currentDay = difference + 1;
      if (_currentDay < 1) _currentDay = 1;
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  /// リアルタイムのプランデータを取得（fallbackは初期値）
  PlanModel get _currentPlan {
    final watchedPlan = ref
        .watch(
          watchPlanProvider(
            (tripId: widget.tripId, planId: widget.plan.id),
          ),
        )
        .valueOrNull;
    return watchedPlan ?? widget.plan;
  }

  @override
  Widget build(BuildContext context) {
    final plan = _currentPlan;

    // 日ごとにアイテムをグループ化
    final itemsByDay = <int, List<PlanItem>>{};
    for (final item in plan.items) {
      itemsByDay.putIfAbsent(item.day, () => []).add(item);
    }
    final days = itemsByDay.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ヘッダー
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.accent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // 編集ボタン
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: _navigateToEdit,
                tooltip: 'プランを編集',
              ),
              // 共有ボタン
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: _sharePlan,
                tooltip: '共有',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _PlanHeader(
                plan: plan,
                trip: widget.trip,
                currentTime: _currentTime,
              ),
            ),
          ),

          // ビュー切り替えタブ
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingM,
                vertical: AppSizes.paddingS,
              ),
              child: _ViewModeToggle(
                isMapView: _isMapView,
                onChanged: (val) => setState(() => _isMapView = val),
              ),
            ),
          ),

          if (_isMapView)
            // 地図ビュー
            SliverFillRemaining(
              child: PlanMapView(
                items: plan.items,
                startDate: widget.trip?.startDate,
              ),
            )
          else ...[
            // 日付タブ（固定表示）
            if (days.length > 1)
              SliverPersistentHeader(
                pinned: true,
                delegate: _DayTabDelegate(
                  days: days,
                  currentDay: _currentDay,
                  onDaySelected: (day) {
                    HapticFeedback.selectionClick();
                  },
                ),
              ),

            // スケジュールリスト
            SliverPadding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (days.isEmpty) {
                    return const _EmptySchedule();
                  }

                  final day = days[index];
                  final items = itemsByDay[day]!;
                  final isToday = day == _currentDay;

                  return _DaySection(
                    day: day,
                    items: items,
                    isToday: isToday,
                    currentTime: _currentTime,
                    trip: widget.trip,
                  );
                }, childCount: days.isEmpty ? 1 : days.length),
              ),
            ),

            // 下部余白
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ],
      ),
      // フローティング編集ボタン
      floatingActionButton:
          _isMapView
              ? null
              : FloatingActionButton.extended(
                onPressed: _navigateToEdit,
                backgroundColor: AppColors.accent,
                icon: const Icon(Icons.edit, color: Colors.white),
                label: Text(
                  '編集する',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
    );
  }

  void _navigateToEdit() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) =>
                PlanEditScreen(tripId: widget.tripId, plan: _currentPlan),
      ),
    );
  }

  void _sharePlan() {
    HapticFeedback.lightImpact();

    final plan = _currentPlan;
    final trip = widget.trip;
    final buf = StringBuffer();

    // タイトル
    if (trip != null) {
      buf.writeln(trip.title);
      if (trip.formattedDateRange.isNotEmpty) {
        buf.writeln(trip.formattedDateRange);
      }
      buf.writeln();
    }
    buf.writeln(plan.title);
    if (plan.description != null && plan.description!.isNotEmpty) {
      buf.writeln(plan.description);
    }
    buf.writeln();

    // 日程ごとにグルーピング
    final itemsByDay = <int, List<PlanItem>>{};
    for (final item in plan.items) {
      itemsByDay.putIfAbsent(item.day, () => []).add(item);
    }
    final days = itemsByDay.keys.toList()..sort();

    for (final day in days) {
      String dayLabel = '$day日目';
      if (trip?.startDate != null) {
        final date = trip!.startDate!.add(Duration(days: day - 1));
        final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
        dayLabel +=
            ' ${date.month}/${date.day}（${weekdays[date.weekday - 1]}）';
      }
      buf.writeln('--- $dayLabel ---');

      final items = itemsByDay[day]!
        ..sort((a, b) => a.time.compareTo(b.time));
      for (final item in items) {
        buf.writeln('${item.time}  ${item.location}（${item.durationMinutes}分）');
        if (item.notes != null && item.notes!.isNotEmpty) {
          buf.writeln('  ${item.notes}');
        }
      }
      buf.writeln();
    }

    buf.writeln('trimeeで作成');

    Share.share(buf.toString());
  }
}

/// プランヘッダー
class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
    required this.plan,
    required this.trip,
    required this.currentTime,
  });

  final PlanModel plan;
  final TripModel? trip;
  final DateTime currentTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, Color(0xFFD4896E)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 旅行タイトル（トリップ名がある場合）
              if (trip != null) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.luggage_outlined,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trip!.title,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    if (trip!.startDate != null) ...[
                      const SizedBox(width: AppSizes.paddingS),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                        ),
                        child: Text(
                          trip!.formattedDateRange,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSizes.paddingS),
              ],

              // プランタイトル
              Text(
                plan.title,
                style: AppTypography.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.paddingXS),

              // プラン説明
              if (plan.description != null && plan.description!.isNotEmpty)
                Text(
                  plan.description!,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: AppSizes.paddingM),

              // スポット数 & 現在時刻
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${plan.items.length}スポット',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 現在時刻
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 日付タブのデリゲート
class _DayTabDelegate extends SliverPersistentHeaderDelegate {
  _DayTabDelegate({
    required this.days,
    required this.currentDay,
    required this.onDaySelected,
  });

  final List<int> days;
  final int currentDay;
  final Function(int) onDaySelected;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              days.map((day) {
                final isToday = day == currentDay;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSizes.paddingS),
                  child: GestureDetector(
                    onTap: () => onDaySelected(day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingM,
                        vertical: AppSizes.paddingS,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isToday
                                ? AppColors.accent
                                : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusFull,
                        ),
                        border: Border.all(
                          color: isToday ? AppColors.accent : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isToday) ...[
                            const Icon(
                              Icons.today,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            '$day日目',
                            style: AppTypography.labelMedium.copyWith(
                              color:
                                  isToday
                                      ? Colors.white
                                      : AppColors.textPrimary,
                              fontWeight:
                                  isToday ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 56;

  @override
  double get minExtent => 56;

  @override
  bool shouldRebuild(covariant _DayTabDelegate oldDelegate) {
    return days != oldDelegate.days || currentDay != oldDelegate.currentDay;
  }
}

/// 日別セクション
class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.items,
    required this.isToday,
    required this.currentTime,
    this.trip,
  });

  final int day;
  final List<PlanItem> items;
  final bool isToday;
  final DateTime currentTime;
  final TripModel? trip;

  @override
  Widget build(BuildContext context) {
    // 時間順にソート
    final sortedItems = List<PlanItem>.from(items)
      ..sort((a, b) => a.time.compareTo(b.time));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日付ヘッダー
        _DayHeader(day: day, isToday: isToday, trip: trip),
        const SizedBox(height: AppSizes.paddingS),

        // スケジュールアイテム
        ...sortedItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == sortedItems.length - 1;
          final isCurrent = isToday && _isCurrentItem(item, sortedItems, index);
          final isPast = isToday && _isPastItem(item);

          return _ScheduleItem(
            item: item,
            isLast: isLast,
            isCurrent: isCurrent,
            isPast: isPast,
            destination: trip?.title,
          );
        }),

        const SizedBox(height: AppSizes.paddingL),
      ],
    );
  }

  bool _isCurrentItem(PlanItem item, List<PlanItem> items, int index) {
    final itemTime = _parseTime(item.time);
    if (itemTime == null) return false;

    final now = TimeOfDay.fromDateTime(currentTime);
    final nowMinutes = now.hour * 60 + now.minute;
    final itemMinutes = itemTime.hour * 60 + itemTime.minute;
    final itemEndMinutes = itemMinutes + item.durationMinutes;

    // 現在時刻がこのアイテムの時間内
    if (nowMinutes >= itemMinutes && nowMinutes < itemEndMinutes) {
      return true;
    }

    // 次のアイテムまでの間
    if (index < items.length - 1) {
      final nextItem = items[index + 1];
      final nextTime = _parseTime(nextItem.time);
      if (nextTime != null) {
        final nextMinutes = nextTime.hour * 60 + nextTime.minute;
        if (nowMinutes >= itemEndMinutes && nowMinutes < nextMinutes) {
          return true;
        }
      }
    }

    return false;
  }

  bool _isPastItem(PlanItem item) {
    final itemTime = _parseTime(item.time);
    if (itemTime == null) return false;

    final now = TimeOfDay.fromDateTime(currentTime);
    final nowMinutes = now.hour * 60 + now.minute;
    final itemEndMinutes =
        (itemTime.hour * 60 + itemTime.minute) + item.durationMinutes;

    return nowMinutes > itemEndMinutes;
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }
}

/// 日付ヘッダー
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.isToday, this.trip});

  final int day;
  final bool isToday;
  final TripModel? trip;

  @override
  Widget build(BuildContext context) {
    String? dateText;
    if (trip?.startDate != null) {
      final date = trip!.startDate!.add(Duration(days: day - 1));
      dateText = '${date.month}/${date.day}（${_weekdayName(date.weekday)}）';
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingM,
            vertical: AppSizes.paddingS,
          ),
          decoration: BoxDecoration(
            gradient:
                isToday
                    ? const LinearGradient(
                      colors: [AppColors.accent, Color(0xFFD4896E)],
                    )
                    : null,
            color: isToday ? null : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            border: isToday ? null : Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isToday ? Icons.today : Icons.calendar_today,
                size: 16,
                color: isToday ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '$day日目',
                style: AppTypography.labelMedium.copyWith(
                  color: isToday ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (dateText != null) ...[
                const SizedBox(width: 6),
                Text(
                  dateText,
                  style: AppTypography.caption.copyWith(
                    color:
                        isToday
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isToday) ...[
          const SizedBox(width: AppSizes.paddingS),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingS,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.subAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSizes.radiusS),
            ),
            child: Text(
              'TODAY',
              style: AppTypography.caption.copyWith(
                color: AppColors.subAccent,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
        const Spacer(),
      ],
    );
  }

  String _weekdayName(int weekday) {
    const names = ['月', '火', '水', '木', '金', '土', '日'];
    return names[weekday - 1];
  }
}

/// スケジュールアイテム
class _ScheduleItem extends StatelessWidget {
  const _ScheduleItem({
    required this.item,
    required this.isLast,
    required this.isCurrent,
    required this.isPast,
    this.destination,
  });

  final PlanItem item;
  final bool isLast;
  final bool isCurrent;
  final bool isPast;
  final String? destination;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイムライン
          SizedBox(
            width: 70,
            child: Column(
              children: [
                // 時間
                Text(
                  item.time,
                  style: AppTypography.titleSmall.copyWith(
                    color:
                        isCurrent
                            ? AppColors.accent
                            : isPast
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                // 所要時間
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

          // タイムラインドット＆ライン
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // ドット
                Container(
                  width: isCurrent ? 16 : 12,
                  height: isCurrent ? 16 : 12,
                  decoration: BoxDecoration(
                    color:
                        isCurrent
                            ? AppColors.accent
                            : isPast
                            ? AppColors.textSecondary.withValues(alpha: 0.5)
                            : AppColors.subAccent,
                    shape: BoxShape.circle,
                    border:
                        isCurrent
                            ? Border.all(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              width: 3,
                            )
                            : null,
                    boxShadow:
                        isCurrent
                            ? [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                            : null,
                  ),
                  child:
                      isCurrent
                          ? const Icon(
                            Icons.navigation,
                            size: 8,
                            color: Colors.white,
                          )
                          : null,
                ),
                // ライン
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            isPast
                                ? AppColors.border
                                : AppColors.accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: AppSizes.paddingS),

          // コンテンツカード
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.paddingM),
              child: _ItemCard(
                item: item,
                isCurrent: isCurrent,
                isPast: isPast,
                destination: destination,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// アイテムカード
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.isCurrent,
    required this.isPast,
    this.destination,
  });

  final PlanItem item;
  final bool isCurrent;
  final bool isPast;
  final String? destination;

  bool get _isPlaceholder =>
      item.isPlaceholder || item.location.startsWith('※');

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border:
              isCurrent ? Border.all(color: AppColors.accent, width: 2) : null,
          boxShadow:
              isCurrent
                  ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 現在進行中バッジ
            if (isCurrent)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingM,
                  vertical: AppSizes.paddingXS,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accent, Color(0xFFD4896E)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppSizes.radiusL - 2),
                    topRight: Radius.circular(AppSizes.radiusL - 2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_filled,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '今ここ',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // メインコンテンツ
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 場所名
                  Row(
                    children: [
                      Icon(
                        Icons.place,
                        size: 18,
                        color:
                            isCurrent
                                ? AppColors.accent
                                : isPast
                                ? AppColors.textSecondary
                                : AppColors.subAccent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.location,
                          style: AppTypography.titleSmall.copyWith(
                            color:
                                isPast
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // メモ
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.paddingS),
                    Text(
                      item.notes!,
                      style: AppTypography.bodySmall.copyWith(
                        color:
                            isPast
                                ? AppColors.textSecondary.withValues(alpha: 0.7)
                                : AppColors.textSecondary,
                      ),
                    ),
                  ],

                  // アクションボタン
                  const SizedBox(height: AppSizes.paddingS),
                  if (_isPlaceholder)
                    // プレースホルダーの場合は文脈に応じたアクション
                    _PlaceholderActions(
                      item: item,
                      destination: destination,
                      isPast: isPast,
                    )
                  else
                    Row(
                      children: [
                        // 地図で見る
                        _ActionChip(
                          icon: Icons.map_outlined,
                          label: '地図',
                          onTap: () => _openMap(context, item),
                          isPast: isPast,
                        ),
                        const SizedBox(width: AppSizes.paddingS),
                        // 検索
                        _ActionChip(
                          icon: Icons.search,
                          label: '検索',
                          onTap: () => _searchLocation(context, item),
                          isPast: isPast,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMap(BuildContext context, PlanItem item) {
    var query = item.location;
    // プレースホルダーの場合はキーワードのみを抽出
    if (item.isPlaceholder || item.location.startsWith('※')) {
      query =
          item.location
              .replaceAll('※', '')
              .replaceAll(RegExp(r'（.*?）'), '')
              .replaceAll(RegExp(r'\(.*?\)'), '') // 半角ッコも考慮
              .trim();
    }

    final url = Uri.parse(
      'https://www.google.com/maps/search/${Uri.encodeComponent(query)}',
    );
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _searchLocation(BuildContext context, PlanItem item) {
    var query = item.location;
    // プレースホルダーの場合はキーワードのみを抽出
    if (item.isPlaceholder || item.location.startsWith('※')) {
      query =
          item.location
              .replaceAll('※', '')
              .replaceAll(RegExp(r'（.*?）'), '')
              .replaceAll(RegExp(r'\(.*?\)'), '')
              .trim();
    }

    final url = Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
    );
    launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

/// アクションチップ
class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPast,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingS,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color:
              isPast
                  ? AppColors.border.withValues(alpha: 0.5)
                  : AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isPast ? AppColors.textSecondary : AppColors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isPast ? AppColors.textSecondary : AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// プレースホルダー用アクション
class _PlaceholderActions extends StatelessWidget {
  const _PlaceholderActions({
    required this.item,
    required this.isPast,
    this.destination,
  });

  final PlanItem item;
  final bool isPast;
  final String? destination;

  @override
  Widget build(BuildContext context) {
    final type = PlaceholderHelper.detectType(item.location);
    final icon = PlaceholderHelper.getIcon(type);
    final label = PlaceholderHelper.getLabel(type);

    return Wrap(
      spacing: AppSizes.paddingS,
      runSpacing: AppSizes.paddingS,
      children: [
        // メインアクション（AIおすすめ）
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            showPlaceholderActionSheet(
              context: context,
              item: item,
              destination: destination,
              onSelectSuggestion: (name, lat, lng) {
                // View画面なので選択時は編集画面への案内
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('「$name」に決定するには編集画面から変更してください'),
                    action: SnackBarAction(
                      label: '編集',
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                );
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingS,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPast
                    ? [
                        AppColors.border.withValues(alpha: 0.5),
                        AppColors.border.withValues(alpha: 0.5),
                      ]
                    : [
                        AppColors.accent.withValues(alpha: 0.1),
                        AppColors.subAccent.withValues(alpha: 0.1),
                      ],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              border: Border.all(
                color: isPast
                    ? AppColors.border
                    : AppColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 12,
                  color: isPast ? AppColors.textSecondary : AppColors.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: isPast ? AppColors.textSecondary : AppColors.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 直接検索ボタン
        _ActionChip(
          icon: Icons.search,
          label: '検索',
          onTap: () {
            final keyword = PlaceholderHelper.extractKeyword(item.location);
            final area = destination ?? '';
            final url = Uri.parse(
              'https://www.google.com/search?q=${Uri.encodeComponent('$area $keyword')}',
            );
            launchUrl(url, mode: LaunchMode.externalApplication);
          },
          isPast: isPast,
        ),
      ],
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
            child: _ViewToggleButton(
              icon: Icons.view_list_rounded,
              label: '時系列',
              isSelected: !isMapView,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ViewToggleButton(
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

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
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

/// 空のスケジュール
class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIcon(
              type: AppIconType.plan,
              size: 64,
              showBackground: true,
            ),
            const SizedBox(height: AppSizes.paddingL),
            Text('スケジュールがありません', style: AppTypography.titleMedium),
            const SizedBox(height: AppSizes.paddingS),
            Text(
              '編集ボタンからスケジュールを追加しましょう',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
