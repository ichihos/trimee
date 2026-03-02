import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/providers/guest_session_provider.dart';
import '../../../../shared/widgets/animated_widgets.dart';

/// ウェルカム画面（初回起動時）
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _contentController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _taglineOpacity;
  late Animation<double> _buttonsOpacity;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();

    // ロゴアニメーション
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // コンテンツアニメーション
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 20),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _buttonsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // パーティクル背景アニメーション
    _particleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // アニメーション開始
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 浮遊パーティクル背景
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FloatingParticlesPainter(
                    progress: _particleController.value,
                    color: AppColors.accent,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingXL,
              ),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // ロゴ
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScale.value,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      AppStrings.appName,
                      style: AppTypography.logoStyle.copyWith(
                        fontSize: 48,
                        color: AppColors.accent,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSizes.paddingXL),

                  // タグライン
                  AnimatedBuilder(
                    animation: _contentController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: _taglineSlide.value,
                        child: Opacity(
                          opacity: _taglineOpacity.value,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      '計画から、旅は始まる',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  const Spacer(flex: 4),

                  // ボタン
                  AnimatedBuilder(
                    animation: _contentController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _buttonsOpacity.value,
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        // 始めるボタン
                        ScaleTapFeedback(
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            await ref
                                .read(guestSessionProvider.notifier)
                                .startAsGuest();
                            if (context.mounted) {
                              context.go('/profile-setup');
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.accent, Color(0xFFD4896E)],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusL,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '始める',
                                style: AppTypography.labelLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSizes.paddingL),

                        // ログインリンク
                        ScaleTapFeedback(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.go('/sign-in');
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSizes.paddingS,
                            ),
                            child: Text(
                              'ログイン/アカウント作成',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSizes.paddingXXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 浮遊パーティクル背景（CustomPainter）
class _FloatingParticlesPainter extends CustomPainter {
  _FloatingParticlesPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _particleCount = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < _particleCount; i++) {
      // 各パーティクルに固有のオフセットを持たせる
      final seed = i * 1.618; // 黄金比で分散
      final phase = (progress + seed) % 1.0;

      // ゆっくりした上下・左右の漂い
      final x =
          size.width * (0.1 + (i * 0.15) % 0.9) +
          math.sin(phase * 2 * math.pi + i) * 30;
      final y =
          size.height * (0.15 + (i * 0.13) % 0.75) +
          math.cos(phase * 2 * math.pi + i * 0.7) * 25;

      final radius = 3.0 + (i % 3) * 2.0;
      final opacity = 0.06 + (math.sin(phase * 2 * math.pi) * 0.04);

      paint.color = color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_FloatingParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
