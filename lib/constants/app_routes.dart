import 'dart:async';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show immutable, ChangeNotifier;
import 'package:go_router/go_router.dart';

import '../presentation/screens/account_settings_screen.dart';
import '../presentation/screens/calendar_screen.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/insights_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/main_screen.dart';
import '../presentation/screens/notification_settings_screen.dart';
import '../presentation/screens/onboarding_screen.dart';
import '../presentation/screens/profile_screen.dart';
import '../presentation/screens/splash_screen.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

@immutable
class AppRoutes {
  const AppRoutes._();

  static final router = GoRouter(
    initialLocation: SplashScreen.routeName,
    refreshListenable:
        GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null;
      final matchedLocation = state.matchedLocation;

      final isLoggingIn = matchedLocation == LoginScreen.routeName;
      final isOnboarding = matchedLocation == OnboardingScreen.routeName;
      final isSplash = matchedLocation == SplashScreen.routeName;

      log('Router Redirect: isLoggedIn=$isLoggedIn, location=$matchedLocation');

      // If logged in, don't allow Onboarding or Login
      if (isLoggedIn && (isOnboarding || isLoggingIn)) {
        return MainScreen.routeName;
      }

      // If not logged in, allow Onboarding, Login, or Splash, otherwise redirect to Onboarding
      if (!isLoggedIn && !isLoggingIn && !isOnboarding && !isSplash) {
        return OnboardingScreen.routeName;
      }

      return null;
    },
    routes: [
      GoRoute(
        name: OnboardingScreen.routeName,
        path: OnboardingScreen.routeName,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        name: LoginScreen.routeName,
        path: LoginScreen.routeName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        name: MainScreen.routeName,
        path: MainScreen.routeName,
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        name: HomeScreen.routeName,
        path: HomeScreen.routeName,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        name: ProfileScreen.routeName,
        path: ProfileScreen.routeName,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        name: InsightsScreen.routeName,
        path: InsightsScreen.routeName,
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        name: AccountSettingsScreen.routeName,
        path: AccountSettingsScreen.routeName,
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        name: NotificationSettingsScreen.routeName,
        path: NotificationSettingsScreen.routeName,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        name: CalendarScreen.routeName,
        path: CalendarScreen.routeName,
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        name: SplashScreen.routeName,
        path: SplashScreen.routeName,
        builder: (context, state) => const SplashScreen(),
      ),
    ],
  );
}
