import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/admin/admin_locale_form_screen.dart';
import 'features/admin/admin_locales_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/favorites/favorites_screen.dart';
import 'features/friends/friends_screen.dart';
import 'features/locales/esplora_screen.dart';
import 'features/locales/locale_detail_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/outings/outing_detail_screen.dart';
import 'features/outings/outings_screen.dart';
import 'features/preferences/edit_preferences_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/splash/splash_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';

      if (authState is AuthUnknown) {
        return loc == '/' ? null : '/';
      }
      if (authState is AuthLoggedOut) {
        return isAuthRoute ? null : '/login';
      }
      if (authState is AuthLoggedIn) {
        if (!authState.user.onboarded) {
          return loc == '/onboarding' ? null : '/onboarding';
        }
        if (loc == '/' || isAuthRoute || loc == '/onboarding') {
          return '/esplora';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', name: 'splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', name: 'login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', name: 'register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),

      // Bottom-nav shell with 4 tabs.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/esplora',
                name: 'esplora',
                builder: (_, __) => const EsploraScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/amici',
                name: 'amici',
                builder: (_, __) => const FriendsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/uscite',
                name: 'uscite',
                builder: (_, __) => const OutingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profilo',
                name: 'profilo',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Full-screen routes (above the shell).
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/locales/:id',
        name: 'locale-detail',
        builder: (context, state) =>
            LocaleDetailScreen(localeId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/uscite/:id',
        name: 'uscita-detail',
        builder: (context, state) =>
            OutingDetailScreen(outingId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/me/preferences',
        name: 'edit-preferences',
        builder: (_, __) => const EditPreferencesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/me/favorites',
        name: 'my-favorites',
        builder: (_, __) => const FavoritesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/admin/locales',
        name: 'admin-locales',
        builder: (_, __) => const AdminLocalesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/admin/locales/new',
        name: 'admin-locale-new',
        builder: (_, __) => const AdminLocaleFormScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/admin/locales/:id',
        name: 'admin-locale-edit',
        builder: (context, state) =>
            AdminLocaleFormScreen(localeId: state.pathParameters['id']!),
      ),
    ],
  );
});

class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(this._ref) {
    _sub = _ref.listen<AuthState>(
      authControllerProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
