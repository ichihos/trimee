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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingXL),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ロゴ
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(opacity: _logoOpacity.value, child: child),
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
                  return Opacity(opacity: _buttonsOpacity.value, child: child);
                },
                child: Column(
                  children: [
                    // 始めるボタン
                    ScaleTapFeedback(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref.read(guestSessionProvider.notifier).startAsGuest();
                        context.go('/profile-setup');
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.accent, Color(0xFFD4896E)],
                          ),
                          borderRadius: BorderRadius.circular(AppSizes.radiusL),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.3),
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
    );
  }
}
