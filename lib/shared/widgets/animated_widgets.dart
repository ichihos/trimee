import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// シマーローディングエフェクト
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(1.0 + 2.0 * _controller.value, 0),
              colors: [
                AppColors.cardBackground,
                AppColors.background,
                AppColors.cardBackground,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// パルスアニメーション（注目を引くボタン用）
class PulseAnimation extends StatefulWidget {
  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });

  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scaleAnimation, child: widget.child);
  }
}

/// バウンスインアニメーション
class BounceIn extends StatefulWidget {
  const BounceIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;

  @override
  State<BounceIn> createState() => _BounceInState();
}

class _BounceInState extends State<BounceIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(scale: _scaleAnimation.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// スライドフェードイン
class SlideFadeIn extends StatefulWidget {
  const SlideFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 20),
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;

  @override
  State<SlideFadeIn> createState() => _SlideFadeInState();
}

class _SlideFadeInState extends State<SlideFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 成功時のチェックマークアニメーション
class AnimatedCheckmark extends StatefulWidget {
  const AnimatedCheckmark({
    super.key,
    this.size = 80,
    this.color = AppColors.subAccent,
    this.strokeWidth = 4,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _circleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _circleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _CheckmarkPainter(
              circleProgress: _circleAnimation.value,
              checkProgress: _checkAnimation.value,
              color: widget.color,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({
    required this.circleProgress,
    required this.checkProgress,
    required this.color,
    required this.strokeWidth,
  });

  final double circleProgress;
  final double checkProgress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw circle
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * circleProgress,
      false,
      paint,
    );

    // Draw checkmark
    if (checkProgress > 0) {
      final checkPath = Path();
      final startPoint = Offset(size.width * 0.25, size.height * 0.5);
      final midPoint = Offset(size.width * 0.45, size.height * 0.7);
      final endPoint = Offset(size.width * 0.75, size.height * 0.35);

      checkPath.moveTo(startPoint.dx, startPoint.dy);

      if (checkProgress <= 0.5) {
        final progress = checkProgress * 2;
        checkPath.lineTo(
          startPoint.dx + (midPoint.dx - startPoint.dx) * progress,
          startPoint.dy + (midPoint.dy - startPoint.dy) * progress,
        );
      } else {
        checkPath.lineTo(midPoint.dx, midPoint.dy);
        final progress = (checkProgress - 0.5) * 2;
        checkPath.lineTo(
          midPoint.dx + (endPoint.dx - midPoint.dx) * progress,
          midPoint.dy + (endPoint.dy - midPoint.dy) * progress,
        );
      }

      canvas.drawPath(checkPath, paint);
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) {
    return oldDelegate.circleProgress != circleProgress ||
        oldDelegate.checkProgress != checkProgress;
  }
}

/// 浮遊アニメーション（仕様書: いいね押すとカードが少し浮く）
class FloatOnTap extends StatefulWidget {
  const FloatOnTap({
    super.key,
    required this.child,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 200),
    this.onTap,
  });

  final Widget child;
  final double floatDistance;
  final Duration duration;
  final VoidCallback? onTap;

  @override
  State<FloatOnTap> createState() => FloatOnTapState();
}

class FloatOnTapState extends State<FloatOnTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _floatAnimation = Tween<double>(
      begin: 0,
      end: -widget.floatDistance,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void triggerFloat() {
    _controller.forward().then((_) => _controller.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        triggerFloat();
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// カスケードアニメーションリスト
class CascadeAnimationList extends StatelessWidget {
  const CascadeAnimationList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.delayBetweenItems = const Duration(milliseconds: 80),
    this.padding,
    this.physics,
    this.controller,
  });

  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final Duration delayBetweenItems;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      physics: physics,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return SlideFadeIn(
          delay: Duration(
            milliseconds: delayBetweenItems.inMilliseconds * index,
          ),
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

/// タップ時のスケールフィードバック
class ScaleTapFeedback extends StatefulWidget {
  const ScaleTapFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.95,
    this.duration = const Duration(milliseconds: 100),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;

  @override
  State<ScaleTapFeedback> createState() => _ScaleTapFeedbackState();
}

class _ScaleTapFeedbackState extends State<ScaleTapFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// ローテーションアニメーション（ローディング用）
class SpinAnimation extends StatefulWidget {
  const SpinAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
  });

  final Widget child;
  final Duration duration;

  @override
  State<SpinAnimation> createState() => _SpinAnimationState();
}

class _SpinAnimationState extends State<SpinAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}

/// グラデーションボーダーアニメーション
class AnimatedGradientBorder extends StatefulWidget {
  const AnimatedGradientBorder({
    super.key,
    required this.child,
    this.borderWidth = 2,
    this.borderRadius = 12,
    this.colors = const [AppColors.accent, AppColors.subAccent],
    this.duration = const Duration(seconds: 2),
  });

  final Widget child;
  final double borderWidth;
  final double borderRadius;
  final List<Color> colors;
  final Duration duration;

  @override
  State<AnimatedGradientBorder> createState() => _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<AnimatedGradientBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.all(widget.borderWidth),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              center: Alignment.center,
              startAngle: 0,
              endAngle: 2 * math.pi,
              transform: GradientRotation(_controller.value * 2 * math.pi),
              colors: [...widget.colors, ...widget.colors],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(
                widget.borderRadius - widget.borderWidth,
              ),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// AI思考中のパルスウェーブアニメーション
class AIThinkingAnimation extends StatefulWidget {
  const AIThinkingAnimation({
    super.key,
    this.size = 120,
    this.duration = const Duration(milliseconds: 2000),
    this.colors,
    this.child,
  });

  final double size;
  final Duration duration;
  final List<Color>? colors;
  final Widget? child;

  @override
  State<AIThinkingAnimation> createState() => _AIThinkingAnimationState();
}

class _AIThinkingAnimationState extends State<AIThinkingAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(duration: widget.duration, vsync: this);
    });

    _scaleAnimations =
        _controllers.map((controller) {
          return Tween<double>(
            begin: 0.4,
            end: 1.0,
          ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
        }).toList();

    _opacityAnimations =
        _controllers.map((controller) {
          return Tween<double>(
            begin: 0.8,
            end: 0.0,
          ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
        }).toList();

    // 各ウェーブを順番に開始
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(
        Duration(milliseconds: (widget.duration.inMilliseconds ~/ 3) * i),
        () {
          if (mounted) {
            _controllers[i].repeat();
          }
        },
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? [AppColors.accent, AppColors.subAccent];

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // パルスウェーブ
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controllers[index],
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimations[index].value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          colors[index % colors.length].withValues(
                            alpha: _opacityAnimations[index].value * 0.3,
                          ),
                          colors[index % colors.length].withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          // 中央のコンテンツ
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

/// タイピングインジケーター（ChatGPT風）
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({
    super.key,
    this.color,
    this.dotSize = 8,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Color? color;
  final double dotSize;
  final Duration duration;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: Duration(milliseconds: widget.duration.inMilliseconds ~/ 2),
        vsync: this,
      );
    });

    _animations =
        _controllers.map((controller) {
          return Tween<double>(begin: 0, end: -8).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut),
          );
        }).toList();

    // 各ドットを順番にアニメーション
    _startAnimation();
  }

  void _startAnimation() async {
    while (mounted) {
      for (var i = 0; i < _controllers.length; i++) {
        if (!mounted) return;
        await _controllers[i].forward();
        await _controllers[i].reverse();
        if (i < _controllers.length - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.3),
              child: Transform.translate(
                offset: Offset(0, _animations[index].value),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// ストリーミングテキスト表示
class StreamingText extends StatefulWidget {
  const StreamingText({
    super.key,
    required this.text,
    this.style,
    this.charDuration = const Duration(milliseconds: 30),
    this.showCursor = true,
    this.onComplete,
  });

  final String text;
  final TextStyle? style;
  final Duration charDuration;
  final bool showCursor;
  final VoidCallback? onComplete;

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;
  int _charCount = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _animateText();
  }

  void _animateText() async {
    for (var i = 0; i <= widget.text.length; i++) {
      if (!mounted) return;
      await Future.delayed(widget.charDuration);
      if (mounted) {
        setState(() => _charCount = i);
      }
    }
    if (mounted) {
      setState(() => _isComplete = true);
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? AppTypography.bodyMedium;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.text.substring(0, _charCount), style: style),
        if (widget.showCursor && !_isComplete)
          FadeTransition(
            opacity: _cursorController,
            child: Container(
              width: 2,
              height: style.fontSize ?? 14,
              margin: const EdgeInsets.only(left: 1),
              color: style.color ?? AppColors.textPrimary,
            ),
          ),
      ],
    );
  }
}

/// 紙吹雪エフェクト
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    this.particleCount = 50,
    this.duration = const Duration(milliseconds: 2000),
    this.colors,
  });

  final int particleCount;
  final Duration duration;
  final List<Color>? colors;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    final colors =
        widget.colors ??
        [
          AppColors.accent,
          AppColors.subAccent,
          const Color(0xFFFFD700),
          const Color(0xFFFF69B4),
          const Color(0xFF87CEEB),
        ];

    final random = math.Random();
    _particles = List.generate(widget.particleCount, (index) {
      return _ConfettiParticle(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.5,
        speed: 0.5 + random.nextDouble() * 0.5,
        rotation: random.nextDouble() * math.pi * 2,
        rotationSpeed: (random.nextDouble() - 0.5) * 4,
        size: 6 + random.nextDouble() * 6,
        color: colors[random.nextInt(colors.length)],
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double delay;
  final double speed;
  final double rotation;
  final double rotationSpeed;
  final double size;
  final Color color;

  _ConfettiParticle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final adjustedProgress =
          (progress - particle.delay).clamp(0.0, 1.0) / (1 - particle.delay);
      if (adjustedProgress <= 0) continue;

      final x =
          particle.x * size.width +
          math.sin(adjustedProgress * math.pi * 2) * 30;
      final y = -20 + adjustedProgress * (size.height + 40) * particle.speed;
      final opacity =
          adjustedProgress < 0.7 ? 1.0 : 1.0 - ((adjustedProgress - 0.7) / 0.3);
      final rotation =
          particle.rotation + adjustedProgress * particle.rotationSpeed;

      final paint =
          Paint()
            ..color = particle.color.withValues(alpha: opacity)
            ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      // 長方形の紙吹雪
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.6,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 成功チェックアニメーション（パーティクルバースト付き）
class SuccessCheckAnimation extends StatefulWidget {
  const SuccessCheckAnimation({
    super.key,
    this.size = 80,
    this.color,
    this.showParticles = true,
  });

  final double size;
  final Color? color;
  final bool showParticles;

  @override
  State<SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<SuccessCheckAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;
  late List<_ParticleBurst> _particles;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    final random = math.Random();
    final color = widget.color ?? AppColors.subAccent;
    _particles = List.generate(12, (index) {
      final angle = (index / 12) * math.pi * 2;
      return _ParticleBurst(
        angle: angle,
        distance: 30 + random.nextDouble() * 20,
        size: 4 + random.nextDouble() * 4,
        color: color.withValues(alpha: 0.6 + random.nextDouble() * 0.4),
      );
    });

    _mainController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && widget.showParticles) {
        _particleController.forward();
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.5,
      height: widget.size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // パーティクルバースト
          if (widget.showParticles)
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ParticleBurstPainter(
                    particles: _particles,
                    progress: _particleController.value,
                    center: Offset(widget.size * 0.75, widget.size * 0.75),
                  ),
                  size: Size(widget.size * 1.5, widget.size * 1.5),
                );
              },
            ),
          // メインのチェックマーク
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value * _bounceAnimation.value,
                child: AnimatedCheckmark(
                  size: widget.size,
                  color: widget.color ?? AppColors.subAccent,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ParticleBurst {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  _ParticleBurst({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}

class _ParticleBurstPainter extends CustomPainter {
  final List<_ParticleBurst> particles;
  final double progress;
  final Offset center;

  _ParticleBurstPainter({
    required this.particles,
    required this.progress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final distance = particle.distance * Curves.easeOut.transform(progress);
      final x = center.dx + math.cos(particle.angle) * distance;
      final y = center.dy + math.sin(particle.angle) * distance;
      final opacity = 1.0 - progress;

      final paint =
          Paint()
            ..color = particle.color.withValues(alpha: opacity)
            ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        particle.size * (1 - progress * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticleBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// ステップインジケーター（AI生成プロセス用）
class AIGenerationSteps extends StatelessWidget {
  const AIGenerationSteps({
    super.key,
    required this.currentStep,
    this.steps = const ['希望分析', '場所検索', '経路設計', '時間調整', 'プラン作成', '最終確認'],
  });

  final int currentStep;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // 接続線
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < currentStep;
          return Container(
            width: 24,
            height: 2,
            color: isCompleted ? AppColors.subAccent : AppColors.border,
          );
        }

        final stepIndex = index ~/ 2;
        final isCompleted = stepIndex < currentStep;
        final isCurrent = stepIndex == currentStep;

        return _StepIndicatorItem(
          label: steps[stepIndex],
          isCompleted: isCompleted,
          isCurrent: isCurrent,
        );
      }),
    );
  }
}

class _StepIndicatorItem extends StatelessWidget {
  const _StepIndicatorItem({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
  });

  final String label;
  final bool isCompleted;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isCompleted
                    ? AppColors.subAccent
                    : isCurrent
                    ? AppColors.accent
                    : AppColors.border,
          ),
          child: Center(
            child:
                isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : isCurrent
                    ? const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color:
                isCompleted || isCurrent
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
