import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/sign_in_screen.dart';
import 'features/cards/presentation/screens/cards_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/onboarding/presentation/screens/profile_setup_screen.dart';
import 'features/onboarding/presentation/screens/welcome_screen.dart';
import 'features/plan/presentation/screens/plan_screen.dart';
import 'features/trip/presentation/screens/join_screen.dart';
import 'features/trip/presentation/screens/member_lobby_screen.dart';
import 'shared/providers/firebase_providers.dart';
import 'shared/providers/guest_session_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/user_profile_provider.dart';

/// カスタムページトランジション
CustomTransitionPage<void> _buildPageWithTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  TransitionType type = TransitionType.slideRight,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (type) {
        case TransitionType.fade:
          return FadeTransition(
            opacity: CurveTween(curve: Curves.easeOut).animate(animation),
            child: child,
          );
        case TransitionType.slideRight:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
            child: FadeTransition(
              opacity: Tween<double>(
                begin: 0.5,
                end: 1.0,
              ).chain(CurveTween(curve: Curves.easeOut)).animate(animation),
              child: child,
            ),
          );
        case TransitionType.slideUp:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.3),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
            child: FadeTransition(
              opacity: CurveTween(curve: Curves.easeOut).animate(animation),
              child: child,
            ),
          );
        case TransitionType.scale:
          return ScaleTransition(
            scale: Tween<double>(
              begin: 0.9,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
            child: FadeTransition(
              opacity: CurveTween(curve: Curves.easeOut).animate(animation),
              child: child,
            ),
          );
      }
    },
  );
}

enum TransitionType { fade, slideRight, slideUp, scale }

/// アプリのルートウィジェット
class TrimeeApp extends ConsumerWidget {
  const TrimeeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // AppColorsのダークモードフラグを同期
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };
    AppColors.updateBrightness(isDark);

    return MaterialApp.router(
      title: AppStrings.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 認証状態変更をGoRouterに通知するNotifier
class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final _authChangeNotifierProvider = Provider<_AuthChangeNotifier>((ref) {
  final notifier = _AuthChangeNotifier();
  ref.listen(isAuthenticatedProvider, (_, __) => notifier.notify());
  ref.listen(isGuestModeProvider, (_, __) => notifier.notify());
  ref.listen(isProfileCompleteProvider, (_, __) => notifier.notify());
  return notifier;
});

/// ルーター設定プロバイダー
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(_authChangeNotifierProvider);

  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final isGuest = ref.read(isGuestModeProvider);
      final hasSession = isAuthenticated || isGuest;
      final isProfileComplete = ref.read(isProfileCompleteProvider);

      final isWelcomeRoute = state.matchedLocation == '/welcome';
      final isAuthRoute = state.matchedLocation == '/sign-in';
      final isJoinRoute = state.matchedLocation.startsWith('/join/');
      final isProfileSetupRoute = state.matchedLocation == '/profile-setup';

      // 招待リンクとトリップ画面は認証不要でアクセス可能（名前はjoin時に収集済み）
      if (isJoinRoute) {
        return null;
      }

      // セッションがなく、welcomeでもsign-inでもなければwelcomeへ
      if (!hasSession && !isWelcomeRoute && !isAuthRoute) {
        return '/welcome';
      }

      // トリップ関連のルート
      final isTripRoute =
          state.matchedLocation.startsWith('/trip/') ||
          state.uri.path.startsWith('/trip/');

      // セッションがあり、プロフィール未完了なら設定画面へ
      // ただし、トリップ/プラン/ホーム関連ルートはスキップ（join経由で名前のみ入力済みの場合）
      final isHomeRoute = state.matchedLocation == '/';
      final isPlanRoute =
          state.matchedLocation.startsWith('/plan/') ||
          state.uri.path.startsWith('/plan/');
      if (hasSession &&
          !isProfileComplete &&
          !isProfileSetupRoute &&
          !isAuthRoute &&
          !isTripRoute &&
          !isHomeRoute &&
          !isPlanRoute) {
        final from = state.uri.toString();
        // カード画面などでリダイレクトループを防ぐため、fromがtripを含む場合はリダイレクトしない
        if (from.contains('/trip/')) {
          return null;
        }
        return '/profile-setup?from=${Uri.encodeComponent(from)}';
      }

      // プロフィール完了済みでprofile-setupにいる場合はホームへ
      if (hasSession && isProfileComplete && isProfileSetupRoute) {
        return '/';
      }

      // 認証済みユーザーでプロフィール完了済みなら、welcomeとsign-inからホームにリダイレクト
      // ゲストユーザーはsign-inにアクセス可能、welcomeからはホームにリダイレクト
      if (hasSession && isProfileComplete && isWelcomeRoute) {
        return '/';
      }
      if (isAuthenticated && isProfileComplete && isAuthRoute) {
        return '/';
      }
      return null;
    },
    routes: [
      // ウェルカム画面
      GoRoute(
        path: '/welcome',
        pageBuilder:
            (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const WelcomeScreen(),
              type: TransitionType.fade,
            ),
      ),

      // サインイン
      GoRoute(
        path: '/sign-in',
        pageBuilder:
            (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const SignInScreen(),
              type: TransitionType.fade,
            ),
      ),

      // プロフィール設定
      GoRoute(
        path: '/profile-setup',
        pageBuilder: (context, state) {
          final from = state.uri.queryParameters['from'];
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: ProfileSetupScreen(from: from),
            type: TransitionType.slideUp,
          );
        },
      ),

      // 招待リンクから参加
      GoRoute(
        path: '/join/:tripId',
        pageBuilder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: JoinScreen(tripId: tripId),
            type: TransitionType.fade,
          );
        },
        routes: [
          // 個別招待リンク（手動メンバー用）
          GoRoute(
            path: ':memberId',
            pageBuilder: (context, state) {
              final tripId = state.pathParameters['tripId']!;
              final memberId = state.pathParameters['memberId']!;
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: JoinScreen(tripId: tripId, personalLinkId: memberId),
                type: TransitionType.fade,
              );
            },
          ),
        ],
      ),

      // ホーム
      GoRoute(
        path: '/',
        pageBuilder:
            (context, state) => _buildPageWithTransition(
              context: context,
              state: state,
              child: const HomeScreen(),
              type: TransitionType.fade,
            ),
        routes: [
          // 旅行詳細（カード一覧）
          GoRoute(
            path: 'trip/:tripId',
            pageBuilder: (context, state) {
              final tripId = state.pathParameters['tripId']!;
              return _buildPageWithTransition(
                context: context,
                state: state,
                child: CardsScreen(tripId: tripId),
                type: TransitionType.slideRight,
              );
            },
            routes: [
              // メンバー待機画面
              GoRoute(
                path: 'lobby',
                pageBuilder: (context, state) {
                  final tripId = state.pathParameters['tripId']!;
                  return _buildPageWithTransition(
                    context: context,
                    state: state,
                    child: MemberLobbyScreen(tripId: tripId),
                    type: TransitionType.slideUp,
                  );
                },
              ),
              // プラン
              GoRoute(
                path: 'plan',
                pageBuilder: (context, state) {
                  final tripId = state.pathParameters['tripId']!;
                  return _buildPageWithTransition(
                    context: context,
                    state: state,
                    child: PlanScreen(tripId: tripId),
                    type: TransitionType.slideUp,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder:
        (context, state) =>
            Scaffold(body: Center(child: Text('ページが見つかりません: ${state.error}'))),
  );
});
