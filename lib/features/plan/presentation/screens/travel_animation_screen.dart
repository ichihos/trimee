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
  bool _isPlaying = false;
  bool _showIntro = true;
  bool _showOutro = false;
  bool _isTransiting = false;
  bool _showCard = true;
  int _currentStep = 0;
  Timer? _animationTimer;
  String _currentTransitEmoji = '🚗';

  bool _isRecording = false;
  bool _isExportAvailable = false;

  late AnimationController _introController;
  late AnimationController _cardController;
  late AnimationController _outroController;
  late AnimationController _transitController;

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
    _transitController = AnimationController(
      duration: const Duration(milliseconds: 3000),
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
    _transitController.dispose();
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

    if (_validItems.isEmpty) return;

    // スポットマーカー（CircleAnnotation）
    final circleManager =
        await _mapboxMap!.annotations.createCircleAnnotationManager();

    // 番号付きテキストラベル（PointAnnotation）
    final pointManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();

    for (var i = 0; i < _validItems.length; i++) {
      final item = _validItems[i];
      // 外側のリング
      await circleManager.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(item.longitude!, item.latitude!),
          ),
          circleRadius: 11.0,
          circleColor: Colors.white.toARGB32(),
          circleOpacity: 0.95,
          circleStrokeWidth: 3.0,
          circleStrokeColor: AppColors.accent.toARGB32(),
        ),
      );
      // 内側の塗り
      await circleManager.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(item.longitude!, item.latitude!),
          ),
          circleRadius: 6.0,
          circleColor: AppColors.accent.toARGB32(),
          circleOpacity: 1.0,
        ),
      );
      // 番号ラベル
      await pointManager.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(item.longitude!, item.latitude!),
          ),
          textField: '${i + 1}',
          textSize: 11.0,
          textColor: Colors.white.toARGB32(),
          textHaloColor: AppColors.accent.toARGB32(),
          textHaloWidth: 1.5,
          textOffset: [0.0, -2.2],
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
      _isTransiting = false;
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
      _isTransiting = false;
      _showCard = true;
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

      if (_isRecording) {
        // 録画中: アウトロ表示後に停止 → 全体表示
        Future.delayed(const Duration(seconds: 1), () async {
          if (mounted) await _stopExportAndSave();
          if (mounted) _fitToBounds();
        });
      } else {
        // 通常再生: アウトロ表示後に全体表示
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _fitToBounds();
        });
      }
      return;
    }

    final item = _validItems[step];
    final isFirst = step == 0;
    final cameraDuration = isFirst ? 2500 : 3000;

    setState(() {
      _currentStep = step;
      _showCard = false;
    });

    // 最初のスポット以外はトランジットオーバーレイを表示
    if (!isFirst) {
      final from = _validItems[step - 1];
      setState(() {
        _isTransiting = true;
        _currentTransitEmoji = _transitEmoji(from, item);
      });
      _transitController.duration = Duration(milliseconds: cameraDuration);
      _transitController.forward(from: 0);
    }

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(item.longitude!, item.latitude!)),
        zoom: isFirst ? 14.5 : 15.5,
        pitch: isFirst ? 45.0 : 55.0,
        bearing:
            step > 0 ? _calculateBearing(_validItems[step - 1], item) : 0.0,
      ),
      MapAnimationOptions(duration: cameraDuration, startDelay: 0),
    );

    HapticFeedback.selectionClick();

    // カメラ移動完了後にトランジット非表示 → カード表示 → 閲覧時間後に次へ
    _animationTimer = Timer(
      Duration(milliseconds: cameraDuration),
      () {
        if (!mounted) return;
        setState(() {
          _isTransiting = false;
          _showCard = true;
        });
        _cardController.forward(from: 0);

        // カード閲覧時間(1500ms)後に次のステップへ
        _animationTimer = Timer(
          const Duration(milliseconds: 1500),
          () {
            if (mounted && _isPlaying) {
              _animateToStep(step + 1);
            }
          },
        );
      },
    );
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

          // トランジットオーバーレイ（スポット間移動中）
          if (_isTransiting)
            _TransitOverlay(
              controller: _transitController,
              emoji: _currentTransitEmoji,
              toName: _validItems[_currentStep].location,
            ),

          // スポットカード（再生中 or 停止中で選択スポットあり）
          if (!_showIntro && !_showOutro && !_isTransiting && _showCard && _validItems.isNotEmpty)
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
  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
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
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.35),
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

              // スポット名（タイプ絵文字付き）
              Row(
                children: [
                  Text(
                    _spotEmoji(item.location),
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.location,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),

              // ノート（あれば）
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.notes!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
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

    return Positioned.fill(
      child: FadeTransition(
        opacity: fade,
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

/// トランジットオーバーレイ（スポット間移動中）
class _TransitOverlay extends StatelessWidget {
  const _TransitOverlay({
    required this.controller,
    required this.emoji,
    required this.toName,
  });

  final AnimationController controller;
  final String emoji;
  final String toName;

  @override
  Widget build(BuildContext context) {
    // フェードイン（widget自体は _isTransiting=false で消えるのでフェードアウト不要）
    final opacity = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );

    final bounce = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 1.0, curve: Curves.linear),
      ),
    );

    return Positioned.fill(
      child: FadeTransition(
        opacity: opacity,
        child: Center(
          child: AnimatedBuilder(
            animation: bounce,
            builder: (context, child) {
              final yOffset = math.sin(bounce.value * math.pi * 3) * 8;
              return Transform.translate(
                offset: Offset(0, yOffset),
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 乗り物絵文字（グロー付き）
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 行き先テキスト
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.accent,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          toName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
          onTap: onSkipBack,
          enabled: canSkipBack,
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
          onTap: onSkipForward,
          enabled: canSkipForward,
        ),
      ],
    );
  }
}

/// スポット名からタイプ絵文字を推定
String _spotEmoji(String location) {
  final l = location.toLowerCase();
  if (RegExp(r'神社|寺|temple|shrine').hasMatch(l)) return '⛩️';
  if (RegExp(r'城|castle').hasMatch(l)) return '🏯';
  if (RegExp(r'公園|山|自然|garden|park|森|滝|湖').hasMatch(l)) return '🌲';
  if (RegExp(r'海|ビーチ|beach|港').hasMatch(l)) return '🏖️';
  if (RegExp(r'レストラン|カフェ|食|グルメ|cafe|restaurant|ラーメン|寿司|焼').hasMatch(l)) return '🍽️';
  if (RegExp(r'ホテル|旅館|inn|hotel|宿').hasMatch(l)) return '🏨';
  if (RegExp(r'駅|station').hasMatch(l)) return '🚉';
  if (RegExp(r'空港|airport').hasMatch(l)) return '✈️';
  if (RegExp(r'美術館|博物館|museum|水族館|動物園').hasMatch(l)) return '🏛️';
  if (RegExp(r'温泉|spa|風呂').hasMatch(l)) return '♨️';
  if (RegExp(r'買|ショッピング|モール|shop|market|商店').hasMatch(l)) return '🛍️';
  return '📍';
}

/// 2点間のハーバーサイン距離（km）
double _haversineDistance(PlanItem from, PlanItem to) {
  const r = 6371.0; // 地球半径 km
  final lat1 = from.latitude! * math.pi / 180;
  final lat2 = to.latitude! * math.pi / 180;
  final dLat = (to.latitude! - from.latitude!) * math.pi / 180;
  final dLon = (to.longitude! - from.longitude!) * math.pi / 180;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// 距離に応じた移動手段絵文字
String _transitEmoji(PlanItem from, PlanItem to) {
  final dist = _haversineDistance(from, to);
  if (dist < 1.0) return '🚶';
  if (dist < 15.0) return '🚗';
  if (dist < 100.0) return '🚃';
  return '✈️';
}
