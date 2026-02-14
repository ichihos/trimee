import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/models/plan_model.dart';

/// プランの地図ビュー
/// 各スポットをマーカーで表示し、ルート線で接続
class PlanMapView extends StatefulWidget {
  const PlanMapView({
    required this.items,
    this.onItemTap,
    this.onCardTap,
    this.startDate,
    this.focusIndex,
    this.liteMode = false,
    super.key,
  });

  final List<PlanItem> items;
  final void Function(int index)? onItemTap;
  final void Function(int index)? onCardTap;
  final DateTime? startDate;

  /// 外部から指定されたフォーカスインデックス
  final int? focusIndex;

  /// 軽量モード（静的ビットマップとして表示）
  final bool liteMode;

  @override
  State<PlanMapView> createState() => _PlanMapViewState();
}

class _PlanMapViewState extends State<PlanMapView> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int? _selectedIndex;
  int? _filterDay; // null = 全日程表示
  final Map<int, BitmapDescriptor> _markerIcons = {};
  final ScrollController _seekBarScrollController = ScrollController();
  bool _isFocusing = false; // _focusOnItem中はfitBoundsを抑制

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.focusIndex;
    _buildMarkersAndPolylines();
  }

  @override
  void dispose() {
    _seekBarScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PlanMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _buildMarkersAndPolylines();
      _fitBounds();
    }
    // 外部からのフォーカス変更
    if (widget.focusIndex != null &&
        widget.focusIndex != oldWidget.focusIndex) {
      _focusOnItem(widget.focusIndex!);
    }
  }

  /// 指定インデックスのスポットにフォーカス
  void _focusOnItem(int index) {
    if (index < 0 || index >= widget.items.length) return;
    final item = widget.items[index];
    if (item.latitude == null || item.longitude == null) return;

    // フォーカス中はfitBoundsを抑制
    _isFocusing = true;
    setState(() => _selectedIndex = index);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(item.latitude!, item.longitude!), 15),
    );
    // シークバーもスクロール
    _scrollSeekBarTo(index);
    // 2秒後にフォーカスモード解除
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _isFocusing = false;
    });
  }

  void _scrollSeekBarTo(int index) {
    if (!_seekBarScrollController.hasClients) return;
    final itemsWithCoords =
        widget.items
            .asMap()
            .entries
            .where((e) => e.value.latitude != null && e.value.longitude != null)
            .toList();
    final seekIndex = itemsWithCoords.indexWhere((e) => e.key == index);
    if (seekIndex < 0) return;
    final offset = seekIndex * 136.0; // card width + margin
    _seekBarScrollController.animateTo(
      offset.clamp(0, _seekBarScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<BitmapDescriptor> _getMarkerIcon(int day) async {
    if (_markerIcons.containsKey(day)) {
      return _markerIcons[day]!;
    }
    final icon = await _createColoredMarker(_getDayColor(day), day);
    _markerIcons[day] = icon;
    return icon;
  }

  static Future<BitmapDescriptor> _createColoredMarker(
    Color color,
    int day,
  ) async {
    const size = 80.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // ピン形状を描画
    final paint = Paint()..color = color;
    // メインの円
    canvas.drawCircle(const Offset(size / 2, size / 2 - 8), 28, paint);
    // 下の三角（ピンの先）
    final path =
        Path()
          ..moveTo(size / 2 - 14, size / 2 + 10)
          ..lineTo(size / 2, size / 2 + 30)
          ..lineTo(size / 2 + 14, size / 2 + 10)
          ..close();
    canvas.drawPath(path, paint);
    // 白い内円
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2 - 8), 16, whitePaint);
    // 日数テキスト
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$day',
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        size / 2 - textPainter.width / 2,
        size / 2 - 8 - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
  }

  /// 2点間に矢印用の中間ポイントを生成
  List<LatLng> _createArrowPoints(LatLng from, LatLng to) {
    final midLat = (from.latitude + to.latitude) / 2;
    final midLng = (from.longitude + to.longitude) / 2;

    final angle = math.atan2(
      to.latitude - from.latitude,
      to.longitude - from.longitude,
    );

    // 矢印の大きさ（緯度・経度の差で調整）
    final dist = math.sqrt(
      math.pow(to.latitude - from.latitude, 2) +
          math.pow(to.longitude - from.longitude, 2),
    );
    final arrowSize = dist * 0.22;

    // 矢印の2辺
    final leftAngle = angle + math.pi * 0.75;
    final rightAngle = angle - math.pi * 0.75;

    return [
      LatLng(
        midLat + arrowSize * math.sin(leftAngle),
        midLng + arrowSize * math.cos(leftAngle),
      ),
      LatLng(midLat, midLng),
      LatLng(
        midLat + arrowSize * math.sin(rightAngle),
        midLng + arrowSize * math.cos(rightAngle),
      ),
    ];
  }

  Future<void> _buildMarkersAndPolylines() async {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // フィルター適用
    final filteredItems =
        _filterDay == null
            ? widget.items
            : widget.items.where((item) => item.day == _filterDay).toList();

    // 座標があるアイテムのみ処理
    final itemsWithCoords =
        filteredItems
            .asMap()
            .entries
            .where(
              (entry) =>
                  entry.value.latitude != null && entry.value.longitude != null,
            )
            .toList();

    for (final entry in itemsWithCoords) {
      final item = entry.value;
      // 元のリストでのインデックスを取得
      final originalIndex = widget.items.indexOf(item);
      final position = LatLng(item.latitude!, item.longitude!);

      final icon = await _getMarkerIcon(item.day);

      markers.add(
        Marker(
          markerId: MarkerId('item_$originalIndex'),
          position: position,
          icon: icon,
          infoWindow: InfoWindow(
            title: item.location,
            snippet: '${item.time} (${item.durationMinutes}分)',
          ),
          onTap: () {
            setState(() => _selectedIndex = originalIndex);
            widget.onItemTap?.call(originalIndex);
          },
        ),
      );
    }

    // 日程ごとにルート線を作成
    final dayGroups = <int, List<LatLng>>{};
    for (final entry in itemsWithCoords) {
      final item = entry.value;
      final pos = LatLng(item.latitude!, item.longitude!);
      dayGroups.putIfAbsent(item.day, () => []).add(pos);
    }

    for (final dayEntry in dayGroups.entries) {
      final day = dayEntry.key;
      final points = dayEntry.value;
      final color = _getDayColor(day);

      if (points.length > 1) {
        // メインルート線
        polylines.add(
          Polyline(
            polylineId: PolylineId('route_$day'),
            points: points,
            color: color.withValues(alpha: 0.8),
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(8)],
          ),
        );

        // 区間ごとに矢印を追加
        for (var i = 0; i < points.length - 1; i++) {
          final arrowPoints = _createArrowPoints(points[i], points[i + 1]);
          polylines.add(
            Polyline(
              polylineId: PolylineId('arrow_${day}_$i'),
              points: arrowPoints,
              color: color,
              width: 5,
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _markers = markers;
        _polylines = polylines;
      });
    }
  }

  void _setFilterDay(int? day) {
    setState(() {
      _filterDay = day;
      _selectedIndex = null;
    });
    _buildMarkersAndPolylines().then((_) {
      Future.delayed(const Duration(milliseconds: 100), _fitBounds);
    });
  }

  void _fitBounds() {
    if (_isFocusing) return; // フォーカス中はズームアウトしない
    if (_mapController == null || _markers.isEmpty) return;

    final positions = _markers.map((m) => m.position).toList();
    if (positions.isEmpty) return;

    if (positions.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(positions.first, 14),
      );
      return;
    }

    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = widget.items.any(
      (item) => item.latitude != null && item.longitude != null,
    );

    if (!hasCoords) {
      return _buildEmptyState();
    }

    final firstWithCoords = widget.items.firstWhere(
      (item) => item.latitude != null && item.longitude != null,
    );

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              firstWithCoords.latitude!,
              firstWithCoords.longitude!,
            ),
            zoom: 12,
          ),
          markers: _markers,
          polylines: _polylines,
          liteModeEnabled: widget.liteMode,
          onMapCreated: (controller) {
            _mapController = controller;
            Future.delayed(const Duration(milliseconds: 300), () {
              _fitBounds();
              // focusIndex が指定されていれば初期フォーカス
              if (widget.focusIndex != null) {
                Future.delayed(
                  const Duration(milliseconds: 500),
                  () => _focusOnItem(widget.focusIndex!),
                );
              }
            });
          },
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          onTap: (_) => setState(() => _selectedIndex = null),
        ),

        if (!widget.liteMode) ...[
          // 日程フィルターチップ
          Positioned(
            top: AppSizes.paddingS,
            left: AppSizes.paddingS,
            right: AppSizes.paddingS,
            child: _buildDayFilterChips(),
          ),

          // ズームコントロール
          Positioned(
            bottom: 80,
            right: AppSizes.paddingM,
            child: Column(
              children: [
                _ZoomButton(
                  icon: Icons.add,
                  onTap:
                      () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                _ZoomButton(
                  icon: Icons.remove,
                  onTap:
                      () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
                ),
                const SizedBox(height: AppSizes.paddingM),
                _ZoomButton(icon: Icons.fit_screen, onTap: _fitBounds),
              ],
            ),
          ),

          // タイムラインシークバー
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildTimelineSeekBar(),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            '地図表示できるスポットがありません',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            'プランを再生成すると地図情報が追加されます',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayFilterChips() {
    final days = widget.items.map((i) => i.day).toSet().toList()..sort();
    if (days.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingS,
        vertical: AppSizes.paddingXS,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 全表示チップ
            _DayChip(
              label: '全て',
              color: AppColors.accent,
              isSelected: _filterDay == null,
              onTap: () => _setFilterDay(null),
            ),
            for (final day in days) ...[
              const SizedBox(width: 6),
              _DayChip(
                label: '$day日目',
                color: _getDayColor(day),
                isSelected: _filterDay == day,
                onTap: () => _setFilterDay(day),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getDayColor(int day) {
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow.shade700,
      Colors.green,
      Colors.cyan,
      Colors.blue,
      Colors.purple,
    ];
    return colors[(day - 1) % colors.length];
  }

  Widget _buildTimelineSeekBar() {
    // 座標があるアイテムのみ（フィルター適用）
    final itemsWithCoords =
        widget.items.asMap().entries.where((e) {
          final item = e.value;
          if (item.latitude == null || item.longitude == null) return false;
          if (_filterDay != null && item.day != _filterDay) return false;
          return true;
        }).toList();

    if (itemsWithCoords.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
        ),
      ),
      padding: const EdgeInsets.only(
        top: AppSizes.paddingM,
        bottom: AppSizes.paddingS,
      ),
      child: SizedBox(
        height: 72,
        child: ScrollConfiguration(
          behavior: kIsWeb
              ? ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                  overscroll: false,
                )
              : ScrollConfiguration.of(context),
          child: ListView.builder(
          controller: _seekBarScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingS),
          itemCount: itemsWithCoords.length,
          itemBuilder: (context, i) {
            final entry = itemsWithCoords[i];
            final originalIndex = entry.key;
            final item = entry.value;
            final isSelected = _selectedIndex == originalIndex;
            final dayColor = _getDayColor(item.day);

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _focusOnItem(originalIndex);
                widget.onItemTap?.call(originalIndex);
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                widget.onCardTap?.call(originalIndex);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 128,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingS,
                  vertical: AppSizes.paddingXS,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? dayColor.withValues(alpha: 0.95)
                          : AppColors.cardBackground.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  border: Border.all(
                    color:
                        isSelected ? dayColor : dayColor.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: dayColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 時刻 + 日程バッジ
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : dayColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item.day}日目',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : dayColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.time,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color:
                                isSelected
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // スポット名
                    Text(
                      item.location,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        ),
      ),
    );
  }
}

/// 日程フィルターチップ
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ズームボタン
class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
