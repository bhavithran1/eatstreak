import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../data/models/voucher.dart';
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
import '../../features/customer/show_voucher_screen.dart';
import '../../features/customer/vouchers_screen.dart';
import '../../features/owner/choose_plan_screen.dart';
import '../../features/owner/counter_code_screen.dart';
import '../../features/owner/edit_shop_screen.dart';
import '../../features/owner/customers_screen.dart';
import '../../features/owner/dashboard_screen.dart';
import '../../features/owner/owner_shell.dart';
import '../../features/owner/profile_screen.dart' as owner;
import '../../features/owner/qr_code_screen.dart';
import '../../features/owner/register_shop_screen.dart';
import '../../features/owner/verify_voucher_screen.dart';
import '../../features/owner/rewards_screen.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../../features/shared/widgets/gradient_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/e2e_scan.dart';
import '../utils/errors.dart';
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

  // Screen views come from the router rather than from each screen, so a new
  // screen is measured the moment it has a route.
  final observer = ref.read(analyticsProvider).navigatorObserver;

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: auth,
    observers: [if (observer is NavigatorObserver) observer],
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
                // `inject` is read only in a debug build: it replays a scanned
                // payload for the end-to-end harness (tool/e2e/), and a release
                // build must not accept a scan result from a URL.
                builder: (_, state) => ScannerScreen(
                  injectedPayload:
                      kDebugMode ? state.uri.queryParameters['inject'] : null,
                ),
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
        path: Routes.counterCode,
        parentNavigatorKey: _rootKey,
        builder: (_, state) {
          final args = state.extra;
          // Only reachable from the QR screen, which already has today's code
          // in hand. Without one there is nothing to display, so go back to the
          // screen that fetches it.
          if (args is! CounterCodeArgs) return const OwnerQrCodeScreen();
          return CounterCodeScreen(args: args);
        },
      ),
      GoRoute(
        path: Routes.showVoucher,
        parentNavigatorKey: _rootKey,
        builder: (_, state) {
          final voucher = state.extra;
          // Only ever opened from a voucher card. Without one there is nothing
          // to show, so send them back to the list rather than an empty screen.
          if (voucher is! Voucher) return const VouchersScreen();
          return ShowVoucherScreen(voucher: voucher);
        },
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
        path: Routes.editShop,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const EditShopScreen(),
      ),
      GoRoute(
        path: Routes.verifyVoucher,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const VerifyVoucherScreen(),
      ),
      GoRoute(
        path: Routes.checkIn,
        parentNavigatorKey: _rootKey,
        builder: (_, state) => CheckInScreen(
          shopId: state.pathParameters['shopId']!,
          token: state.uri.queryParameters['t'],
        ),
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

      // Signed in, but the profile could not be read. Stay on the splash, which
      // renders the failure and a retry. Falling through would treat "couldn't
      // load" as "not onboarded" and walk an existing account back through
      // onboarding — the same mistake as rendering a failed load as an empty
      // state.
      if (s.profileError != null) {
        return loc == Routes.splash ? null : Routes.splash;
      }

      // A check-in link opened while signed out survives the sign-in round trip
      // and onboarding — including process death — and is resumed by
      // PendingCheckInResumer once the user can actually act on it.
      if (!s.isSignedIn || !s.isOnboarded) {
        if (shopId != null) {
          await setPendingCheckIn(
            shopId,
            token: state.uri.queryParameters['t'],
          );
        }
        return s.isSignedIn ? Routes.onboarding : Routes.signIn;
      }

      // Signed in and onboarded: keep them out of the pre-auth screens.
      final home = s.role == UserRole.owner
          ? Routes.ownerDashboard
          : Routes.customerHome;
      if (loc == Routes.splash ||
          loc == Routes.signIn ||
          loc == Routes.onboarding) {
        // The end-to-end harness (tool/e2e/) replays one scanned payload per
        // launch. Redirecting here rather than listening for the auth
        // transition, because this is the one bounce a cold start always makes
        // and it happens after the account is ready — the listener misses the
        // transition whenever auth resolves before the first frame. Debug-only:
        // consumeE2eScanPayload() is a compile-time null in release builds, so
        // this whole branch is tree-shaken away.
        final injected = await consumeE2eScanPayload();
        if (injected != null) return Routes.scannerInject(injected);
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

/// The pre-auth holding screen: a spinner while the session resolves, and the
/// failure plus a retry when the profile cannot be read. The second half exists
/// because this screen used to spin forever on any backend failure.
class _SplashScreen extends ConsumerWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.profileError == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(
                "Couldn't load your account",
                textAlign: TextAlign.center,
                style: AppText.heading(size: 19),
              ),
              const SizedBox(height: 8),
              Text(
                friendlyErrorMessage(auth.profileError!),
                textAlign: TextAlign.center,
                style: AppText.body(size: 14, height: 1.45),
              ),
              const SizedBox(height: 4),
              // The code behind the sentence, for the same reason the store's
              // failure screen carries one: "something went wrong" is not a
              // diagnosis, and this phone's logs are unreachable.
              Text(
                errorCode(auth.profileError!),
                textAlign: TextAlign.center,
                style: AppText.body(size: 12, color: AppColors.muted2),
              ),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Try again',
                icon: Icons.refresh,
                onPressed: () => unawaited(
                  ref.read(authControllerProvider.notifier).retryProfileLoad(),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => unawaited(
                  ref.read(authControllerProvider.notifier).signOut(),
                ),
                child: Text('Sign out', style: AppText.body(size: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
