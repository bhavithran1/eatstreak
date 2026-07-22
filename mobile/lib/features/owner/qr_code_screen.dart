import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/qr_codec.dart';
import '../../data/models/check_in_token.dart';
import '../../data/models/shop.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/gradient_button.dart';

/// The shop's check-in code — a single-use code the owner shows the customer at
/// checkout. Each code works once and refreshes on its own, so a screenshot
/// can't be reused and a saved code can't be scanned from home.
class OwnerQrCodeScreen extends ConsumerStatefulWidget {
  const OwnerQrCodeScreen({super.key});

  @override
  ConsumerState<OwnerQrCodeScreen> createState() => _OwnerQrCodeScreenState();
}

class _OwnerQrCodeScreenState extends ConsumerState<OwnerQrCodeScreen>
    with WidgetsBindingObserver {
  CheckInToken? _token;
  bool _loading = false;
  Object? _error;
  Timer? _ticker;

  /// Whether the app is foreground-active. Minting a code every 90s while the
  /// owner is in another app is a function call + a Firestore write for nothing,
  /// so rotation pauses whenever this is false.
  bool _foreground = true;

  /// Seconds until the current code auto-refreshes; drives the live countdown.
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    final shopId =
        _token?.shopId ?? ref.read(storeControllerProvider).value?.ownedShop?.id;
    if (shopId != null) _reconcile(shopId);
  }

  /// Bring the rotation in line with visibility: pause when the screen is out of
  /// view, mint the first (or a stale) code when it's back, otherwise just keep
  /// the countdown ticking. Called after every build and on lifecycle changes,
  /// and is idempotent.
  void _reconcile(String shopId) {
    if (!mounted) return;
    final active = _foreground && TickerMode.valuesOf(context).enabled;
    if (!active) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    if (_loading || _error != null) return;
    if (_token == null || _token!.isExpired) {
      unawaited(_generate(shopId));
      return;
    }
    _ensureTicker(shopId);
  }

  /// Mint a fresh single-use code and start the countdown to the next one.
  Future<void> _generate(String shopId) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token =
          await ref.read(storeControllerProvider.notifier).createCheckInToken(shopId);
      if (!mounted) return;
      setState(() {
        _token = token;
        _remaining = token.remaining.inSeconds;
        _loading = false;
      });
      _reconcile(shopId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _ensureTicker(String shopId) {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final token = _token;
      if (token == null) return;
      final left = token.remaining.inSeconds;
      if (left <= 0) {
        // Rotate automatically so an unused code never lingers on screen.
        unawaited(_generate(shopId));
      } else if (mounted) {
        setState(() => _remaining = left);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeControllerProvider).value ?? const StoreState();
    final shop = state.ownedShop;

    if (shop == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No shop yet',
              subtitle: 'Register your shop before showing a check-in code to '
                  'customers.',
              actionLabel: 'Register shop',
              onAction: () => context.push(Routes.registerShop),
            ),
          ),
        ),
      );
    }

    // Keep rotation in sync with visibility after this frame — mint the first
    // code, resume the countdown, or pause when the tab isn't in view.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconcile(shop.id));

    return AppScreen(
      title: 'Check-in code',
      subtitle: 'Show this at checkout — the customer scans it in their app.',
      children: [
        Center(child: _codePanel(shop)),
        const SizedBox(height: Spacing.xl),
        _howItWorks(),
      ],
    );
  }

  Widget _codePanel(Shop shop) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: Radii.xlAll,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.ember1.withValues(alpha: 0.19),
                AppColors.ember2.withValues(alpha: 0.13),
                AppColors.ember3.withValues(alpha: 0.06),
              ],
            ),
          ),
          child: Container(
            width: 252,
            height: 252,
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: Radii.lgAll,
            ),
            child: Center(child: _qrOrStatus(shop)),
          ),
        ),
        const SizedBox(height: Spacing.md),
        Text(shop.name, style: AppText.heading(size: 20)),
        const SizedBox(height: 2),
        if (_token != null && _error == null)
          Text(
            'Refreshes in ${_remaining}s · works once',
            style: AppText.body(size: 13),
          )
        else
          Text('Each code works once', style: AppText.body(size: 13)),
        const SizedBox(height: Spacing.md),
        GradientButton(
          label: 'New code',
          icon: Icons.refresh,
          busy: _loading,
          onPressed: () => unawaited(_generate(shop.id)),
        ),
      ],
    );
  }

  Widget _qrOrStatus(Shop shop) {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 30, color: AppColors.muted),
          const SizedBox(height: Spacing.sm),
          Text(
            friendlyErrorMessage(_error),
            textAlign: TextAlign.center,
            style: AppText.body(size: 13, color: AppColors.muted),
          ),
        ],
      );
    }

    final token = _token;
    if (token == null) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return QrImageView(
      data: buildCheckInLink(shop.id, token: token.token),
      size: 212,
      backgroundColor: Colors.white,
      // High correction so a slight glare on the owner's screen still scans.
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: AppColors.primaryInk,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: AppColors.primaryInk,
      ),
    );
  }

  Widget _howItWorks() => SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How it works', style: AppText.heading(size: 15)),
            const SizedBox(height: Spacing.md),
            _tip(Icons.point_of_sale_outlined,
                'Show this screen when the customer pays'),
            const SizedBox(height: Spacing.md),
            _tip(Icons.qr_code_scanner,
                'They open EatStreak and scan to log the visit'),
            const SizedBox(height: Spacing.md),
            _tip(Icons.lock_clock_outlined,
                'Each code works once and refreshes automatically'),
            const SizedBox(height: Spacing.md),
            _tip(Icons.refresh,
                'Tap "New code" for the next customer in line'),
          ],
        ),
      );

  Widget _tip(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.ember2),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text(text, style: AppText.body(size: 14))),
        ],
      );
}
