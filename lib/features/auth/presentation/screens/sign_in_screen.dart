import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../providers/auth_provider.dart';

/// サインイン画面
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AsyncLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/welcome'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.paddingXL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ロゴ
                  Text(
                    AppStrings.appName,
                    style: AppTypography.logoStyle.copyWith(
                      fontSize: 48,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.paddingS),
                  Text(
                    AppStrings.welcomeMessage,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.paddingXXL),

                  // サインアップ時は名前入力
                  if (_isSignUp) ...[
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '名前',
                        hintText: 'あなたの名前',
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingM),
                  ],

                  // メール入力
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: AppStrings.email,
                      hintText: 'example@email.com',
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingM),

                  // パスワード入力
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: AppStrings.password,
                      hintText: '••••••••',
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingL),

                  // サインイン/サインアップボタン
                  AccentButton(
                    label: _isSignUp ? AppStrings.signUp : AppStrings.signIn,
                    isLoading: isLoading,
                    onPressed: () => _handleEmailAuth(),
                  ),
                  const SizedBox(height: AppSizes.paddingM),

                  // 切り替えボタン
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                      });
                    },
                    child: Text(
                      _isSignUp
                          ? 'すでにアカウントをお持ちの方'
                          : 'アカウントを作成する',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSizes.paddingL),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
                        child: Text('または'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppSizes.paddingL),

                  // Googleサインイン
                  AppButton(
                    label: AppStrings.signInWithGoogle,
                    variant: AppButtonVariant.outlined,
                    icon: Icons.g_mobiledata,
                    isLoading: isLoading,
                    isFullWidth: true,
                    onPressed: () => _handleGoogleSignIn(),
                  ),

                  // Appleサインイン（iOS/Webのみ）
                  if (_showAppleSignIn) ...[
                    const SizedBox(height: AppSizes.paddingM),
                    AppButton(
                      label: 'Appleでサインイン',
                      variant: AppButtonVariant.outlined,
                      icon: Icons.apple,
                      isLoading: isLoading,
                      isFullWidth: true,
                      onPressed: () => _handleAppleSignIn(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleEmailAuth() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) return;
    if (_isSignUp && name.isEmpty) return;

    if (_isSignUp) {
      ref.read(authControllerProvider.notifier).signUpWithEmail(
            email: email,
            password: password,
            name: name,
          );
    } else {
      ref.read(authControllerProvider.notifier).signInWithEmail(
            email: email,
            password: password,
          );
    }
  }

  void _handleGoogleSignIn() {
    ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  void _handleAppleSignIn() {
    ref.read(authControllerProvider.notifier).signInWithApple();
  }

  /// Appleサインインを表示するかどうか（iOS/Webのみ）
  bool get _showAppleSignIn {
    if (kIsWeb) return true;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }
}
