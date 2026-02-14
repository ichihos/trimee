import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:trimee/core/constants/app_colors.dart';
import 'package:trimee/core/constants/app_sizes.dart';
import 'package:trimee/core/constants/app_typography.dart';
import 'package:trimee/core/constants/mapbox_config.dart';
import 'package:trimee/shared/models/plan_model.dart';
import 'package:trimee/shared/services/video_export_service.dart';

class TravelAnimationScreen extends ConsumerStatefulWidget {
  const TravelAnimationScreen({required this.items, this.planTitle, super.key});

  final List<PlanItem> items;
  final String? planTitle;

  @override
  ConsumerState<TravelAnimationScreen> createState() =>
      _TravelAnimationScreenState();
}

class _TravelAnimationScreenState extends ConsumerState<TravelAnimationScreen>
    with TickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  // Annotation managers kept for potential future cleanup
  // ignore: unused_field
  PolylineAnnotationManager? _polylineAnnotationManager;
  // ignore: unused_field
  CircleAnnotationManager? _circleAnnotationManager;

  bool _isPlaying = false;
  bool _showIntro = true;
  bool _showOutro = false;
  int _currentStep = 0;
  Timer? _animationTimer;

  bool _isRecording = false;
  bool _isExportAvailable = false;

  late AnimationController _introController;
  late AnimationController _cardController;
  late AnimationController _outroController;

  List<PlanItem> get _validItems =>
      widget.items
          .where((i) => i.latitude != null && i.longitude != null)
          .toList();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      MapboxOptions.setAccessToken(MapboxConfig.accessToken);
    }

    _introController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _outroController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // イントロアニメーション
    _introController.forward();

    // エクスポート機能の利用可否チェック
    _checkExportAvailability();
  }

  Future<void> _checkExportAvailability() async {
    final available = await VideoExportService.isAvailable();
    if (mounted) {
      setState(() => _isExportAvailable = available);
    }
  }

  Future<void> _startExport() async {
    HapticFeedback.mediumImpact();
    final started = await VideoExportService.startRecording();
    if (!started || !mounted) return;

    setState(() {
      _isRecording = true;
      _showIntro = false;
      _showOutro = false;
      _currentStep = 0;
    });

    // 少し待ってからアニメーション再生開始
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _play();
  }

  Future<void> _stopExportAndSave() async {
    final path = await VideoExportService.stopRecording();
    if (!mounted) return;

    setState(() => _isRecording = false);

    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('動画をカメラロールに保存しました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('動画の保存に失敗しました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _introController.dispose();
    _cardController.dispose();
    _outroController.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _mapboxMap?.logo.updateSettings(
      LogoSettings(
        position: OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 8,
        marginBottom: 8,
      ),
    );
    _mapboxMap?.attribution.updateSettings(
      AttributionSettings(
        position: OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 90,
        marginBottom: 8,
      ),
    );

    _drawRoute();
  }

  Future<void> _drawRoute() async {
    if (_mapboxMap == null) return;

    final positions =
        _validItems.map((i) => Position(i.longitude!, i.latitude!)).toList();
    if (positions.isEmpty) return;

    // ルート線（グロー効果: 太い半透明の下地 + 細いメイン線）
    final polyManager =
        await _mapboxMap!.annotations.createPolylineAnnotationManager();
    _polylineAnnotationManager = polyManager;

    // 下地のグロー線
    await polyManager.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: positions),
        lineColor: AppColors.accent.withValues(alpha: 0.3).toARGB32(),
        lineWidth: 10.0,
        lineOpacity: 0.5,
        lineJoin: LineJoin.ROUND,
      ),
    );
    // メイン線
    await polyManager.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: positions),
        lineColor: AppColors.accent.toARGB32(),
        lineWidth: 3.5,
        lineOpacity: 0.9,
        lineJoin: LineJoin.ROUND,
      ),
    );

    // スポットマーカー（CircleAnnotation）
    final circleManager =
        await _mapboxMap!.annotations.createCircleAnnotationManager();
    _circleAnnotationManager = circleManager;

    for (var i = 0; i < _validItems.length; i++) {
      final item = _validItems[i];
      // 外側のリング
      await circleManager.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(item.longitude!, item.latitude!),
          ),
          circleRadius: 10.0,
          circleColor: Colors.white.toARGB32(),
          circleOpacity: 0.9,
          circleStrokeWidth: 2.5,
          circleStrokeColor: AppColors.accent.toARGB32(),
        ),
      );
      // 内側の塗り
      await circleManager.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(item.longitude!, item.latitude!),
          ),
          circleRadius: 5.0,
          circleColor: AppColors.accent.toARGB32(),
          circleOpacity: 1.0,
        ),
      );
    }

    _fitToBounds();
  }

  Future<void> _fitToBounds() async {
    if (_mapboxMap == null || _validItems.isEmpty) return;

    final points =
        _validItems
            .map((i) => Point(coordinates: Position(i.longitude!, i.latitude!)))
            .toList();

    final cameraOptions = await _mapboxMap!.cameraForCoordinatesPadding(
      points,
      CameraOptions(),
      MbxEdgeInsets(top: 120, left: 60, bottom: 200, right: 60),
      null,
      null,
    );

    _mapboxMap!.flyTo(
      cameraOptions,
      MapAnimationOptions(duration: 1500, startDelay: 0),
    );
  }

  void _play() {
    if (_mapboxMap == null || _validItems.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _showIntro = false;
      _showOutro = false;
      _isPlaying = true;
    });
    _animateToStep(_currentStep);
  }

  void _pause() {
    HapticFeedback.lightImpact();
    _animationTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _skipTo(int step) {
    if (step < 0 || step >= _validItems.length) return;
    _animationTimer?.cancel();
    HapticFeedback.selectionClick();

    setState(() {
      _currentStep = step;
      _showOutro = false;
    });

    if (_isPlaying) {
      _animateToStep(step);
    } else {
      _flyToStep(step);
    }
  }

  Future<void> _flyToStep(int step) async {
    if (_mapboxMap == null) return;
    final item = _validItems[step];
    _cardController.forward(from: 0);

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(item.longitude!, item.latitude!)),
        zoom: 15.5,
        pitch: 55.0,
        bearing:
            step > 0 ? _calculateBearing(_validItems[step - 1], item) : 0.0,
      ),
      MapAnimationOptions(duration: 2000, startDelay: 0),
    );
  }

  Future<void> _animateToStep(int step) async {
    if (step >= _validItems.length) {
      // アニメーション終了 → アウトロ
      setState(() {
        _isPlaying = false;
        _showOutro = true;
      });
      _outroController.forward(from: 0);
      HapticFeedback.mediumImpact();

      // 録画中なら自動停止して保存
      if (_isRecording) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _stopExportAndSave();
        });
      }

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _fitToBounds();
      });
      return;
    }

    setState(() => _currentStep = step);
    _cardController.forward(from: 0);

    final item = _validItems[step];
    final isFirst = step == 0;

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(item.longitude!, item.latitude!)),
        zoom: isFirst ? 14.5 : 15.5,
        pitch: isFirst ? 45.0 : 55.0,
        bearing:
            step > 0 ? _calculateBearing(_validItems[step - 1], item) : 0.0,
      ),
      MapAnimationOptions(duration: isFirst ? 2500 : 3000, startDelay: 0),
    );

    HapticFeedback.selectionClick();

    _animationTimer = Timer(Duration(seconds: isFirst ? 4 : 5), () {
      if (mounted && _isPlaying) {
        _animateToStep(step + 1);
      }
    });
  }

  double _calculateBearing(PlanItem from, PlanItem to) {
    final lat1 = from.latitude! * math.pi / 180;
    final lon1 = from.longitude! * math.pi / 180;
    final lat2 = to.latitude! * math.pi / 180;
    final lon2 = to.longitude! * math.pi / 180;

    final y = math.sin(lon2 - lon1) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(lon2 - lon1);
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 地図
          // 地図 (Webでは非対応)
          if (kIsWeb)
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'この機能は現在アプリ版のみ対応しています',
                      style: AppTypography.bodyLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'スマートフォンアプリをご利用ください',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            MapWidget(
              key: const ValueKey('mapWidget'),
              styleUri: MapboxStyles.DARK,
              onMapCreated: _onMapCreated,
            ),

          // 上部グラデーション（テキスト可読性のため）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 下部グラデーション
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200 + bottomPadding,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // 閉じるボタン
          Positioned(
            top: topPadding + 8,
            left: 12,
            child: _GlassButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),

          // 録画中インジケーター
          if (_isRecording)
            Positioned(
              top: topPadding + 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                    SizedBox(width: 4),
                    Text(
                      'REC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // プログレスドット（再生中に表示）
          if ((_isPlaying || !_showIntro) && !_showOutro)
            Positioned(
              top: topPadding + 16,
              left: 60,
              right: 60,
              child: _ProgressDots(
                total: _validItems.length,
                current: _currentStep,
                onTap: _skipTo,
              ),
            ),

          // イントロオーバーレイ
          if (_showIntro)
            _IntroOverlay(
              controller: _introController,
              title: widget.planTitle ?? '旅の軌跡',
              spotCount: _validItems.length,
              dayCount:
                  _validItems.isEmpty
                      ? 0
                      : _validItems.map((i) => i.day).toSet().length,
              onPlay: _play,
              onExport: _isExportAvailable ? _startExport : null,
            ),

          // スポットカード（再生中 or 停止中で選択スポットあり）
          if (!_showIntro && !_showOutro && _validItems.isNotEmpty)
            Positioned(
              bottom: bottomPadding + 100,
              left: 16,
              right: 16,
              child: _AnimatedSpotCard(
                key: ValueKey('spot_$_currentStep'),
                controller: _cardController,
                item: _validItems[_currentStep],
                stepIndex: _currentStep,
                totalSteps: _validItems.length,
              ),
            ),

          // アウトロオーバーレイ
          if (_showOutro)
            _OutroOverlay(
              controller: _outroController,
              title: widget.planTitle ?? '旅の軌跡',
              onReplay: () {
                setState(() {
                  _showOutro = false;
                  _currentStep = 0;
                });
                _play();
              },
              onClose: () => Navigator.pop(context),
            ),

          // コントロールバー（イントロ・アウトロ以外で表示）
          if (!_showIntro && !_showOutro)
            Positioned(
              bottom: bottomPadding + 20,
              left: 0,
              right: 0,
              child: _ControlBar(
                isPlaying: _isPlaying,
                canSkipBack: _currentStep > 0,
                canSkipForward: _currentStep < _validItems.length - 1,
                onPlay: _play,
                onPause: _pause,
                onSkipBack: () => _skipTo(_currentStep - 1),
                onSkipForward: () => _skipTo(_currentStep + 1),
              ),
            ),
        ],
      ),
    );
  }
}

/// すりガラス風の丸ボタン
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// プログレスドット
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.total,
    required this.current,
    required this.onTap,
  });

  final int total;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        final isPast = i < current;
        return GestureDetector(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isActive ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color:
                  isActive
                      ? AppColors.accent
                      : isPast
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.25),
            ),
          ),
        );
      }),
    );
  }
}

/// イントロオーバーレイ
class _IntroOverlay extends StatelessWidget {
  const _IntroOverlay({
    required this.controller,
    required this.title,
    required this.spotCount,
    required this.dayCount,
    required this.onPlay,
    this.onExport,
  });

  final AnimationController controller;
  final String title;
  final int spotCount;
  final int dayCount;
  final VoidCallback onPlay;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final fadeIn = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    final slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    final buttonFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.3),
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Spacer(flex: 3),

              // タイトル
              FadeTransition(
                opacity: fadeIn,
                child: SlideTransition(
                  position: slideUp,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.6),
                          ),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.route_rounded,
                              color: AppColors.accent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '旅の軌跡',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (dayCount > 0) ...[
                            _InfoChip(
                              icon: Icons.calendar_today_rounded,
                              label: '$dayCount日間',
                            ),
                            const SizedBox(width: 12),
                          ],
                          _InfoChip(
                            icon: Icons.place_rounded,
                            label: '$spotCountスポット',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // 再生ボタン
              FadeTransition(
                opacity: buttonFade,
                child: GestureDetector(
                  onTap: onPlay,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent,
                          AppColors.accent.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              FadeTransition(
                opacity: buttonFade,
                child: Text(
                  'タップして再生',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),

              if (onExport != null) ...[
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: buttonFade,
                  child: GestureDetector(
                    onTap: onExport,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusFull,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.videocam_rounded,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '動画として保存',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

/// 情報チップ
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white60, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: Colors.white60),
        ),
      ],
    );
  }
}

/// アニメーション付きスポットカード
class _AnimatedSpotCard extends StatelessWidget {
  const _AnimatedSpotCard({
    super.key,
    required this.controller,
    required this.item,
    required this.stepIndex,
    required this.totalSteps,
  });

  final AnimationController controller;
  final PlanItem item;
  final int stepIndex;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 上段: 日程・時間・番号
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent,
                          AppColors.accent.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.day}日目',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.time,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${stepIndex + 1} / $totalSteps',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // スポット名
              Text(
                item.location,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),

              // ノート（あれば）
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.notes!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // 滞在時間
              if (item.durationMinutes > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.durationMinutes}分',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// アウトロオーバーレイ
class _OutroOverlay extends StatelessWidget {
  const _OutroOverlay({
    required this.controller,
    required this.title,
    required this.onReplay,
    required this.onClose,
  });

  final AnimationController controller;
  final String title;
  final VoidCallback onReplay;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);

    return FadeTransition(
      opacity: fade,
      child: Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // チェックマークアイコン
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: AppColors.accent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '旅の予定をひと通り確認しました',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // ボタン群
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // もう一度
                    GestureDetector(
                      onTap: onReplay,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.replay_rounded,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'もう一度',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 閉じる
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent,
                              AppColors.accent.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '閉じる',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// コントロールバー
class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.isPlaying,
    required this.canSkipBack,
    required this.canSkipForward,
    required this.onPlay,
    required this.onPause,
    required this.onSkipBack,
    required this.onSkipForward,
  });

  final bool isPlaying;
  final bool canSkipBack;
  final bool canSkipForward;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 前へ
        _GlassButton(
          icon: Icons.skip_previous_rounded,
          onTap: canSkipBack ? onSkipBack : () {},
        ),
        const SizedBox(width: 16),

        // 再生 / 一時停止
        GestureDetector(
          onTap: isPlaying ? onPause : onPlay,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.accent,
                  AppColors.accent.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),

        const SizedBox(width: 16),

        // 次へ
        _GlassButton(
          icon: Icons.skip_next_rounded,
          onTap: canSkipForward ? onSkipForward : () {},
        ),
      ],
    );
  }
}
