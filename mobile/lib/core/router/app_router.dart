import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/customer/check_in_screen.dart';
import '../../features/customer/customer_shell.dart';
import '../../features/customer/home_screen.dart';
import '../../features/customer/profile_screen.dart';
import '../../features/customer/scan_success_screen.dart';
import '../../features/customer/scanner_screen.dart';
import '../../features/customer/shop_detail_screen.dart';
import '../../features/customer/shop_not_found_screen.dart';
import '../../features/customer/vouchers_screen.dart';
import '../../features/owner/choose_plan_screen.dart';
import '../../features/owner/customers_screen.dart';
import '../../features/owner/dashboard_screen.dart';
import '../../features/owner/owner_shell.dart';
import '../../features/owner/profile_screen.dart' as owner;
import '../../features/owner/qr_code_screen.dart';
import '../../features/owner/register_shop_screen.dart';
import '../../features/owner/rewards_screen.dart';
import '../../state/auth_controller.dart';
import '../theme/app_colors.dart';
import '../utils/pending_check_in.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Central routing, including the auth gate. The redirect below is the single
/// place that decides where a given auth state belongs — the Expo app spread
/// that across index.tsx and three _layout files.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => auth.value = next);
  ref.onDispose(auth.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: auth,
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const _SplashScreen()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),

      // ---- customer tabs ----------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => CustomerShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.customerHome,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.scanner,
                builder: (_, _) => const ScannerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.vouchers,
                builder: (_, _) => const VouchersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.customerProfile,
                builder: (_, _) => const CustomerProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---- owner tabs -------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => OwnerShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerDashboard,
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerQrCode,
                builder: (_, _) => const OwnerQrCodeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerRewards,
                builder: (_, _) => const RewardsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerCustomers,
                builder: (_, state) => CustomersScreen(
                  initialStatus: _customerStatus(
                    state.uri.queryParameters['status'],
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerProfile,
                builder: (_, _) => const owner.OwnerProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---- full-screen routes, outside both shells --------------------------
      GoRoute(
        path: Routes.shopDetailPattern,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            ShopDetailScreen(shopId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.scanSuccess,
        parentNavigatorKey: _rootKey,
        builder: (_, state) {
          final args = state.extra;
          // Only ever reached from a completed check-in; with no result there
          // is nothing to celebrate, so fall back to home.
          if (args is! ScanSuccessArgs) return const HomeScreen();
          return ScanSuccessScreen(args: args);
        },
      ),
      GoRoute(
        path: Routes.shopNotFound,
        parentNavigatorKey: _rootKey,
        builder: (_, state) {
          final args = state.extra;
          return ShopNotFoundScreen(
            args: args is ShopNotFoundArgs
                ? args
                : const ShopNotFoundArgs(qrData: ''),
          );
        },
      ),
      GoRoute(
        path: Routes.registerShop,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const RegisterShopScreen(),
      ),
      GoRoute(
        path: Routes.choosePlan,
        parentNavigatorKey: _rootKey,
        builder: (_, state) {
          final args = state.extra;
          // Reached only from register-shop, which always supplies the details.
          if (args is! ChoosePlanArgs) return const RegisterShopScreen();
          return ChoosePlanScreen(args: args);
        },
      ),
      GoRoute(
        path: Routes.checkIn,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            CheckInScreen(shopId: state.pathParameters['shopId']!),
      ),
    ],
    redirect: (context, state) async {
      final s = auth.value;
      final loc = state.matchedLocation;
      final shopId = state.pathParameters['shopId'];

      // Hold on the splash until the first auth event lands, so a signed-in
      // user never sees the sign-in screen flash by.
      if (s.initializing) {
        return loc == Routes.splash ? null : Routes.splash;
      }

      // A check-in link opened while signed out survives the sign-in round trip
      // and onboarding — including process death — and is resumed by
      // PendingCheckInResumer once the user can actually act on it.
      if (!s.isSignedIn || !s.isOnboarded) {
        if (shopId != null) await setPendingCheckIn(shopId);
        return s.isSignedIn ? Routes.onboarding : Routes.signIn;
      }

      // Signed in and onboarded: keep them out of the pre-auth screens.
      final home = s.role == UserRole.owner
          ? Routes.ownerDashboard
          : Routes.customerHome;
      if (loc == Routes.splash ||
          loc == Routes.signIn ||
          loc == Routes.onboarding) {
        return home;
      }

      return null;
    },
  );
});

CustomerStatus? _customerStatus(String? wire) => switch (wire) {
      'active' => CustomerStatus.active,
      'warning' => CustomerStatus.atRisk,
      'lapsed' => CustomerStatus.lapsed,
      _ => null,
    };

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
}
