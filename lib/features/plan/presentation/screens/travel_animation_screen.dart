import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:trimee/core/constants/app_colors.dart';
import 'package:trimee/core/constants/app_sizes.dart';
import 'package:trimee/core/constants/app_typography.dart';
import 'package:trimee/core/constants/mapbox_config.dart';
import 'package:trimee/shared/models/plan_model.dart';
import 'package:trimee/shared/providers/ad_provider.dart';
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
  String _currentTransitLabel = '車';

  // 地図上の乗り物アノテーション
  PointAnnotationManager? _vehicleAnnotationManager;
  PointAnnotation? _vehicleAnnotation;
  Timer? _vehicleMovementTimer;
  final Map<String, Uint8List> _vehicleIconCache = {};

  // スポット到着時Lottieオーバーレイ
  bool _showSpotLottie = false;
  double _spotLottieX = 0;
  double _spotLottieY = 0;
  String _spotLottieAsset = '';

  // 日程トランジション
  bool _showDayTransition = false;
  int _dayTransitionDay = 1;

  // 旅のサマリー（アウトロ用）
  double _totalDistanceKm = 0;

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
    setState(() => _isRecording = false);

    // リワード広告のオプトイン確認
    if (!kIsWeb) {
      final shouldShowAd = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          title: const Text('動画を保存'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('動画を保存します。広告を視聴することで、開発を支援できます。'),
              const SizedBox(height: AppSizes.paddingM),
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingS),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSizes.paddingS),
                    Expanded(
                      child: Text(
                        '広告視聴は任意です',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('広告なしで保存'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('広告を見る'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      if (shouldShowAd == true) {
        // リワード広告を表示
        final adService = ref.read(adServiceProvider);
        final rewarded = await adService.showRewardedAd();
        if (!mounted) return;

        if (rewarded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ありがとうございます！'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (shouldShowAd == null) {
        // ダイアログがキャンセルされた場合は録画を停止して終了
        await VideoExportService.stopRecording();
        return;
      }
    }

    // 録画を停止して保存
    final path = await VideoExportService.stopRecording();
    if (!mounted) return;

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
    _vehicleMovementTimer?.cancel();
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
    _initVehicleManager();
  }

  Future<void> _initVehicleManager() async {
    _vehicleAnnotationManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();
  }

  Future<void> _startVehicleAnimation(
    PlanItem from,
    PlanItem to,
    int durationMs,
  ) async {
    if (_vehicleAnnotationManager == null) return;

    // アイコンPNGを取得/キャッシュ
    final data = _vehicleIconData(from, to);
    final cacheKey = '${data.icon.codePoint}';
    if (!_vehicleIconCache.containsKey(cacheKey)) {
      _vehicleIconCache[cacheKey] = await _renderVehicleIcon(
        data.icon,
        data.color,
      );
    }
    final iconBytes = _vehicleIconCache[cacheKey]!;

    final fromPos = Position(from.longitude!, from.latitude!);
    final toPos = Position(to.longitude!, to.latitude!);
    final initialBearing = _bearingBetween(fromPos, toPos);

    // 出発地点にアノテーション作成
    _vehicleAnnotation = await _vehicleAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: fromPos),
        image: iconBytes,
        iconSize: 0.5,
        iconRotate: initialBearing,
        iconAnchor: IconAnchor.CENTER,
      ),
    );

    // 移動タイマー開始（~30fps）
    final stopwatch = Stopwatch()..start();
    _vehicleMovementTimer?.cancel();
    _vehicleMovementTimer = Timer.periodic(const Duration(milliseconds: 33), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final elapsed = stopwatch.elapsedMilliseconds;
      final t = (elapsed / durationMs).clamp(0.0, 1.0);

      if (t >= 1.0) {
        timer.cancel();
        return;
      }

      final easedT = _easeInOutCubic(t);
      final currentPos = _interpolatePosition(fromPos, toPos, easedT);

      // 少し先の位置からベアリング計算
      final lookAheadT = (t + 0.03).clamp(0.0, 1.0);
      final lookAheadPos = _interpolatePosition(fromPos, toPos, lookAheadT);
      final bearing = _bearingBetween(currentPos, lookAheadPos);

      _vehicleAnnotation!.geometry = Point(coordinates: currentPos);
      _vehicleAnnotation!.iconRotate = bearing;

      try {
        await _vehicleAnnotationManager!.update(_vehicleAnnotation!);
      } catch (_) {
        timer.cancel();
      }
    });
  }

  Future<void> _removeVehicleAnnotation() async {
    _vehicleMovementTimer?.cancel();
    _vehicleMovementTimer = null;
    if (_vehicleAnnotation != null && _vehicleAnnotationManager != null) {
      try {
        await _vehicleAnnotationManager!.delete(_vehicleAnnotation!);
      } catch (_) {}
      _vehicleAnnotation = null;
    }
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
      // スポット名ラベル（地図上に表示）
      await pointManager.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(item.longitude!, item.latitude!),
          ),
          textField: item.location,
          textSize: 12.0,
          textColor: Colors.white.toARGB32(),
          textHaloColor: Colors.black.toARGB32(),
          textHaloWidth: 2.0,
          textOffset: [0.0, 1.8],
          textMaxWidth: 10.0,
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

    // 総距離を計算（アウトロ用）
    double totalDist = 0;
    for (var i = 1; i < _validItems.length; i++) {
      totalDist += _haversineDistance(_validItems[i - 1], _validItems[i]);
    }

    setState(() {
      _showIntro = false;
      _showOutro = false;
      _isTransiting = false;
      _isPlaying = true;
      _totalDistanceKm = totalDist;
    });

    // ルート俯瞰 → 1800ms後に最初のスポットへ
    _fitToBounds();
    _animationTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && _isPlaying) {
        _animateToStep(_currentStep);
      }
    });
  }

  void _pause() {
    HapticFeedback.lightImpact();
    _animationTimer?.cancel();
    _vehicleMovementTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _skipTo(int step) {
    if (step < 0 || step >= _validItems.length) return;
    _animationTimer?.cancel();
    _removeVehicleAnnotation();
    HapticFeedback.selectionClick();

    setState(() {
      _currentStep = step;
      _showOutro = false;
      _isTransiting = false;
      _showCard = true;
      _showSpotLottie = false;
      _showDayTransition = false;
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
        Future.delayed(const Duration(seconds: 1), () async {
          if (mounted) await _stopExportAndSave();
          if (mounted) _fitToBounds();
        });
      } else {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _fitToBounds();
        });
      }
      return;
    }

    final item = _validItems[step];
    final isFirst = step == 0;
    final PlanItem? prevItem = isFirst ? null : _validItems[step - 1];

    setState(() {
      _currentStep = step;
      _showCard = false;
      _showSpotLottie = false;
    });

    // 日程が変わった場合 → Day トランジション演出
    if (!isFirst && prevItem != null && item.day != prevItem.day) {
      setState(() {
        _showDayTransition = true;
        _dayTransitionDay = item.day;
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted || !_isPlaying) return;
      setState(() => _showDayTransition = false);
    }

    // カメラ設定（距離に応じてズーム・ピッチを変える）
    final camera = _cameraForTransit(prevItem, item);
    final cameraDuration = isFirst ? 2500 : 3000;

    // 最初のスポット以外は地図上に乗り物アイコンを表示して移動
    if (!isFirst && prevItem != null) {
      final travelTime = _estimatedTravelTime(prevItem, item);
      setState(() {
        _isTransiting = true;
        _currentTransitLabel = '${_transitLabel(prevItem, item)} $travelTime';
      });
      _transitController.duration = Duration(milliseconds: cameraDuration);
      _transitController.forward(from: 0);
      _startVehicleAnimation(prevItem, item, cameraDuration);
    }

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(item.longitude!, item.latitude!)),
        zoom: camera.zoom,
        pitch: camera.pitch,
        bearing: prevItem != null ? _calculateBearing(prevItem, item) : 0.0,
      ),
      MapAnimationOptions(duration: cameraDuration, startDelay: 0),
    );

    HapticFeedback.selectionClick();

    // カメラ到着後 → 乗り物削除 → Lottie → 間 → カード → 閲覧 → 次へ
    _animationTimer = Timer(Duration(milliseconds: cameraDuration), () async {
      if (!mounted) return;
      await _removeVehicleAnnotation();

      // 1) スポット到着Lottieを表示（カードはまだ出さない）
      if (_mapboxMap != null) {
        try {
          final screenCoord = await _mapboxMap!.pixelForCoordinate(
            Point(coordinates: Position(item.longitude!, item.latitude!)),
          );
          if (mounted) {
            setState(() {
              _showSpotLottie = true;
              _spotLottieX = screenCoord.x;
              _spotLottieY = screenCoord.y;
              _spotLottieAsset = _spotLottieAssetFor(item.location);
            });
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() => _isTransiting = false);

      // 2) 600msの「間」でLottieを味わう
      _animationTimer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        // 3) カード表示（stagger animation）
        setState(() => _showCard = true);
        _cardController.forward(from: 0);

        // 4) 2500ms閲覧後、次のステップへ
        _animationTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted && _isPlaying) {
            _animateToStep(step + 1);
          }
        });
      });
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      color: Colors.white,
                      size: 10,
                    ),
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

          // トランジット情報ピル（スポット間移動中 - 上部に小さく表示）
          if (_isTransiting)
            _TransitInfoPill(
              controller: _transitController,
              transitLabel: _currentTransitLabel,
              toName: _validItems[_currentStep].location,
              topPadding: topPadding,
            ),

          // 日程トランジションオーバーレイ
          if (_showDayTransition) _DayTransitionOverlay(day: _dayTransitionDay),

          // スポット到着Lottieオーバーレイ（地図上のスポット位置に表示）
          if (_showSpotLottie && _spotLottieAsset.isNotEmpty)
            Positioned(
              left: _spotLottieX - 50,
              top: _spotLottieY - 80,
              width: 100,
              height: 100,
              child: IgnorePointer(
                child: Lottie.asset(
                  _spotLottieAsset,
                  fit: BoxFit.contain,
                  repeat: false,
                ),
              ),
            ),

          // スポットカード（再生中 or 停止中で選択スポットあり）
          if (!_showIntro &&
              !_showOutro &&
              !_isTransiting &&
              _showCard &&
              _validItems.isNotEmpty)
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
              spotCount: _validItems.length,
              dayCount:
                  _validItems.isEmpty
                      ? 0
                      : _validItems.map((i) => i.day).toSet().length,
              totalDistanceKm: _totalDistanceKm,
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

              // 再生ボタン（パルスグロー付き）
              FadeTransition(
                opacity: buttonFade,
                child: _PulsePlayButton(onTap: onPlay),
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

/// アニメーション付きスポットカード（スタガードアニメーション + フロスト効果）
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
    // 全体のスライドイン
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    final cardFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    // スタガード: 上段（日程バッジ + 時間）
    final topRowFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    // スタガード: メイン（スポットアイコン + 名前）
    final mainFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
    );
    final mainSlide = Tween<Offset>(
      begin: const Offset(-0.1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    // スタガード: 下段（ノート + 滞在時間）
    final detailFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: cardFade,
      child: SlideTransition(
        position: slide,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
                  // 上段: 日程・時間・番号（stagger 1）
                  FadeTransition(
                    opacity: topRowFade,
                    child: Row(
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
                  ),
                  const SizedBox(height: 10),

                  // スポット名（stagger 2 - スライド付き）
                  FadeTransition(
                    opacity: mainFade,
                    child: SlideTransition(
                      position: mainSlide,
                      child: Builder(
                        builder: (context) {
                          final spot = _spotIcon(item.location);
                          return Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: spot.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  spot.icon,
                                  color: spot.color,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
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
                          );
                        },
                      ),
                    ),
                  ),

                  // 下段（stagger 3）
                  FadeTransition(
                    opacity: detailFade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 地域の特徴タグ（桃鉄風）
                        Builder(
                          builder: (context) {
                            final specialties = _getAreaSpecialties(item.location);
                            if (specialties.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: specialties.map((s) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          s.color.withValues(alpha: 0.3),
                                          s.color.withValues(alpha: 0.15),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: s.color.withValues(alpha: 0.5),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          s.emoji,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          s.label,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// アウトロオーバーレイ（旅のサマリー付き）
class _OutroOverlay extends StatelessWidget {
  const _OutroOverlay({
    required this.controller,
    required this.title,
    required this.spotCount,
    required this.dayCount,
    required this.totalDistanceKm,
    required this.onReplay,
    required this.onClose,
  });

  final AnimationController controller;
  final String title;
  final int spotCount;
  final int dayCount;
  final double totalDistanceKm;
  final VoidCallback onReplay;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    final statsFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    );

    // 距離の表示フォーマット
    final distanceLabel =
        totalDistanceKm >= 10
            ? '${totalDistanceKm.round()}km'
            : '${totalDistanceKm.toStringAsFixed(1)}km';

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
                const SizedBox(height: 20),

                // 旅のサマリー統計
                FadeTransition(
                  opacity: statsFade,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatChip(
                        icon: Icons.place_rounded,
                        label: '$spotCountスポット',
                      ),
                      const SizedBox(width: 12),
                      if (dayCount > 0) ...[
                        _StatChip(
                          icon: Icons.calendar_today_rounded,
                          label: '$dayCount日間',
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (totalDistanceKm > 0)
                        _StatChip(
                          icon: Icons.straighten_rounded,
                          label: distanceLabel,
                        ),
                    ],
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

/// 統計チップ（アウトロ用）
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accent, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 日程トランジションオーバーレイ（Day切り替え演出 - アニメーション付き）
class _DayTransitionOverlay extends StatefulWidget {
  const _DayTransitionOverlay({required this.day});

  final int day;

  @override
  State<_DayTransitionOverlay> createState() => _DayTransitionOverlayState();
}

class _DayTransitionOverlayState extends State<_DayTransitionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _lineController;
  late Animation<double> _fadeIn;
  late Animation<double> _scale;
  late Animation<double> _lineWidth;
  late Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _lineController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _subtitleFade = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _lineWidth = Tween<double>(begin: 0.0, end: 48.0).animate(
      CurvedAnimation(parent: _lineController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _lineController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _lineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeIn,
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Day ${widget.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 8,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _lineWidth,
                    builder: (context, child) {
                      return Container(
                        width: _lineWidth.value,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: Text(
                      '${widget.day}日目',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// トランジット情報ピル（上部に小さく表示 - 地図上のvehicleアニメーションを遮らない）
class _TransitInfoPill extends StatelessWidget {
  const _TransitInfoPill({
    required this.controller,
    required this.transitLabel,
    required this.toName,
    required this.topPadding,
  });

  final AnimationController controller;
  final String transitLabel; // 例: "車 約5分"
  final String toName;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final opacity = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );

    return Positioned(
      top: topPadding + 56,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: opacity,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    transitLabel,
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    toName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
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
        ),
      ),
    );
  }
}

/// パルスグロー付き再生ボタン（イントロ用）
class _PulsePlayButton extends StatefulWidget {
  const _PulsePlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PulsePlayButton> createState() => _PulsePlayButtonState();
}

class _PulsePlayButtonState extends State<_PulsePlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // パルスリング
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.25);
                final opacity = 0.4 - (_pulseController.value * 0.35);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent.withValues(
                          alpha: opacity.clamp(0.0, 1.0),
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),
            // メインボタン
            Container(
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
          ],
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

/// スポット名からタイプアイコン情報を推定
({IconData icon, Color color}) _spotIcon(String location) {
  final l = location.toLowerCase();
  if (RegExp(r'神社|寺|temple|shrine').hasMatch(l)) {
    return (
      icon: Icons.temple_buddhist_rounded,
      color: const Color(0xFFE57373),
    );
  }
  if (RegExp(r'城|castle').hasMatch(l)) {
    return (icon: Icons.fort_rounded, color: const Color(0xFFBA68C8));
  }
  if (RegExp(r'公園|山|自然|garden|park|森|滝|湖').hasMatch(l)) {
    return (icon: Icons.park_rounded, color: const Color(0xFF81C784));
  }
  if (RegExp(r'海|ビーチ|beach|港').hasMatch(l)) {
    return (icon: Icons.beach_access_rounded, color: const Color(0xFF4FC3F7));
  }
  if (RegExp(r'レストラン|カフェ|食|グルメ|cafe|restaurant|ラーメン|寿司|焼').hasMatch(l)) {
    return (icon: Icons.restaurant_rounded, color: const Color(0xFFFFB74D));
  }
  if (RegExp(r'ホテル|旅館|inn|hotel|宿').hasMatch(l)) {
    return (icon: Icons.hotel_rounded, color: const Color(0xFF9575CD));
  }
  if (RegExp(r'駅|station').hasMatch(l)) {
    return (icon: Icons.train_rounded, color: const Color(0xFF4DB6AC));
  }
  if (RegExp(r'空港|airport').hasMatch(l)) {
    return (icon: Icons.flight_rounded, color: const Color(0xFF7986CB));
  }
  if (RegExp(r'美術館|博物館|museum|水族館|動物園').hasMatch(l)) {
    return (icon: Icons.museum_rounded, color: const Color(0xFFA1887F));
  }
  if (RegExp(r'温泉|spa|風呂').hasMatch(l)) {
    return (icon: Icons.hot_tub_rounded, color: const Color(0xFFEF5350));
  }
  if (RegExp(r'買|ショッピング|モール|shop|market|商店').hasMatch(l)) {
    return (icon: Icons.shopping_bag_rounded, color: const Color(0xFFFF8A65));
  }
  return (icon: Icons.place_rounded, color: AppColors.accent);
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

/// 距離に応じた移動手段ラベル
String _transitLabel(PlanItem from, PlanItem to) {
  final dist = _haversineDistance(from, to);
  if (dist < 1.0) return '徒歩';
  if (dist < 15.0) return '車';
  if (dist < 100.0) return '電車';
  return '飛行機';
}

/// 距離に応じた乗り物アイコンデータ
({IconData icon, Color color}) _vehicleIconData(PlanItem from, PlanItem to) {
  final dist = _haversineDistance(from, to);
  if (dist < 1.0) {
    return (
      icon: Icons.directions_walk_rounded,
      color: const Color(0xFF81C784),
    );
  }
  if (dist < 15.0) {
    return (icon: Icons.directions_car_rounded, color: const Color(0xFF4FC3F7));
  }
  if (dist < 100.0) {
    return (icon: Icons.train_rounded, color: const Color(0xFF4DB6AC));
  }
  return (icon: Icons.flight_rounded, color: const Color(0xFF7986CB));
}

/// Material IconをPNG Uint8Listにレンダリング
Future<Uint8List> _renderVehicleIcon(
  IconData icon,
  Color color, {
  double size = 80,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

  // 外側グロー
  final glowPaint =
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 4, glowPaint);

  // メイン円
  final fillPaint = Paint()..color = color;
  canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 8, fillPaint);

  // 白い内円
  final innerPaint = Paint()..color = Colors.white;
  canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 14, innerPaint);

  // アイコン描画
  final textPainter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.4,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  textPainter.paint(
    canvas,
    Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// 地理座標の線形補間
Position _interpolatePosition(Position from, Position to, double t) {
  return Position(
    from.lng + (to.lng - from.lng) * t,
    from.lat + (to.lat - from.lat) * t,
  );
}

/// easeInOutCubicカーブ
double _easeInOutCubic(double t) {
  return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
}

/// 2つのPositionからベアリング計算
double _bearingBetween(Position from, Position to) {
  final lat1 = from.lat * math.pi / 180;
  final lon1 = from.lng * math.pi / 180;
  final lat2 = to.lat * math.pi / 180;
  final lon2 = to.lng * math.pi / 180;
  final y = math.sin(lon2 - lon1) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(lon2 - lon1);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// スポットLottieアセットパス（デフォルトフォールバック）
String _spotLottieAssetFor(String location) {
  // TODO: スポットタイプ別Lottieファイルが追加されたらここで分岐
  return 'assets/lottie/spot_default.json';
}

/// 地域の特徴・名産タグ（桃鉄風）
class _AreaSpecialty {
  const _AreaSpecialty({required this.emoji, required this.label, required this.color});
  final String emoji;
  final String label;
  final Color color;
}

List<_AreaSpecialty> _getAreaSpecialties(String location) {
  final l = location.toLowerCase();
  final tags = <_AreaSpecialty>[];

  // スポットタイプに基づくタグ
  if (RegExp(r'神社|寺|temple|shrine').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '⛩️', label: '歴史', color: Color(0xFFE57373)));
  }
  if (RegExp(r'城|castle').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🏯', label: '名城', color: Color(0xFFBA68C8)));
  }
  if (RegExp(r'公園|garden|park|森').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🌿', label: '自然', color: Color(0xFF81C784)));
  }
  if (RegExp(r'山|岳|峠').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '⛰️', label: '絶景', color: Color(0xFF66BB6A)));
  }
  if (RegExp(r'海|ビーチ|beach|港|島').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🏖️', label: '海', color: Color(0xFF4FC3F7)));
  }
  if (RegExp(r'温泉|spa|風呂').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '♨️', label: '温泉', color: Color(0xFFEF5350)));
  }
  if (RegExp(r'レストラン|カフェ|食|グルメ|cafe|restaurant').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🍽️', label: 'グルメ', color: Color(0xFFFFB74D)));
  }
  if (RegExp(r'ラーメン').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🍜', label: 'ラーメン', color: Color(0xFFFF8A65)));
  }
  if (RegExp(r'寿司|鮨').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🍣', label: '寿司', color: Color(0xFFFF7043)));
  }
  if (RegExp(r'美術館|博物館|museum').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🎨', label: 'アート', color: Color(0xFFA1887F)));
  }
  if (RegExp(r'水族館').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🐠', label: '水族館', color: Color(0xFF29B6F6)));
  }
  if (RegExp(r'動物園').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🦁', label: '動物園', color: Color(0xFFA5D6A7)));
  }
  if (RegExp(r'買|ショッピング|モール|shop|market|商店|通り').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🛍️', label: 'お買物', color: Color(0xFFFF8A65)));
  }
  if (RegExp(r'ホテル|旅館|inn|hotel|宿').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🏨', label: '宿泊', color: Color(0xFF9575CD)));
  }
  if (RegExp(r'駅|station').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🚉', label: '駅', color: Color(0xFF4DB6AC)));
  }
  if (RegExp(r'空港|airport').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '✈️', label: '空港', color: Color(0xFF7986CB)));
  }
  if (RegExp(r'湖|滝|渓谷|川').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '💧', label: '水辺', color: Color(0xFF4FC3F7)));
  }
  if (RegExp(r'展望|タワー|tower|スカイ').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🗼', label: '展望', color: Color(0xFFFFD54F)));
  }
  if (RegExp(r'遊園地|テーマパーク|ランド|ワールド').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🎢', label: 'テーマパーク', color: Color(0xFFE040FB)));
  }
  if (RegExp(r'酒|ワイン|ビール|brewery|蔵').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🍶', label: '名酒', color: Color(0xFFBCAAA4)));
  }

  // 地域名に基づくタグ（名産品）
  if (RegExp(r'京都|嵐山|祇園|清水').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🍵', label: '抹茶', color: Color(0xFF66BB6A)));
  }
  if (RegExp(r'大阪|道頓堀|心斎橋|新世界').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🐙', label: 'たこ焼き', color: Color(0xFFFF7043)));
  }
  if (RegExp(r'北海道|札幌|小樽|函館|旭川|富良野').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🦀', label: '海鮮', color: Color(0xFFEF5350)));
  }
  if (RegExp(r'沖縄|那覇|石垣|宮古').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🌺', label: '南国', color: Color(0xFFFF8A80)));
  }
  if (RegExp(r'福岡|博多|天神').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🍜', label: '博多ラーメン', color: Color(0xFFFF8A65)));
  }
  if (RegExp(r'広島|宮島').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🦪', label: '牡蠣', color: Color(0xFFBCAAA4)));
  }
  if (RegExp(r'金沢|兼六').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🍱', label: '加賀料理', color: Color(0xFFFFD54F)));
  }
  if (RegExp(r'名古屋|栄|大須').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🍤', label: 'えびふりゃー', color: Color(0xFFFF8A65)));
  }
  if (RegExp(r'奈良').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🦌', label: '鹿', color: Color(0xFFA1887F)));
  }
  if (RegExp(r'神戸|三宮|元町').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🥩', label: '神戸牛', color: Color(0xFFE57373)));
  }
  if (RegExp(r'長崎').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🍝', label: 'ちゃんぽん', color: Color(0xFFFFB74D)));
  }
  if (RegExp(r'仙台').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '👅', label: '牛タン', color: Color(0xFFE57373)));
  }
  if (RegExp(r'浅草|東京|渋谷|新宿|秋葉原|銀座').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🗼', label: '都会', color: Color(0xFF7986CB)));
  }
  if (RegExp(r'鎌倉|江ノ島').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🏄', label: '湘南', color: Color(0xFF4FC3F7)));
  }
  if (RegExp(r'富士|河口湖').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🗻', label: '富士山', color: Color(0xFF90CAF9)));
  }
  if (RegExp(r'日光').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🐒', label: '世界遺産', color: Color(0xFFA5D6A7)));
  }
  if (RegExp(r'熊本').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🐴', label: '馬刺し', color: Color(0xFFEF5350)));
  }
  if (RegExp(r'青森|弘前').hasMatch(l)) {
    tags.add(const _AreaSpecialty(emoji: '🍎', label: 'りんご', color: Color(0xFFEF5350)));
  }

  // 最大3つまで
  if (tags.length > 3) return tags.sublist(0, 3);
  return tags;
}

/// 距離に応じたカメラ設定
({double zoom, double pitch}) _cameraForTransit(PlanItem? from, PlanItem to) {
  if (from == null) return (zoom: 14.0, pitch: 45.0);
  final dist = _haversineDistance(from, to);
  if (dist < 1.0) return (zoom: 16.0, pitch: 60.0);
  if (dist < 15.0) return (zoom: 15.0, pitch: 50.0);
  if (dist < 100.0) return (zoom: 13.5, pitch: 40.0);
  return (zoom: 11.0, pitch: 30.0);
}

/// 推定移動時間（分）
String _estimatedTravelTime(PlanItem from, PlanItem to) {
  final dist = _haversineDistance(from, to);
  int minutes;
  if (dist < 1.0) {
    minutes = (dist * 1000 / 80).round(); // 徒歩 80m/min
  } else if (dist < 15.0) {
    minutes = (dist / 0.5).round(); // 車 30km/h市街地
  } else if (dist < 100.0) {
    minutes = (dist / 1.5).round(); // 電車 90km/h
  } else {
    minutes = (dist / 8).round(); // 飛行機 480km/h
  }
  if (minutes < 1) minutes = 1;
  return '約$minutes分';
}
