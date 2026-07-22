import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/errors.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../shared/widgets/brand_mark.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  String? _busy;
  bool _appleAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkApple();
  }

  Future<void> _checkApple() async {
    final available =
        await ref.read(authControllerProvider.notifier).isAppleSignInAvailable();
    if (mounted) setState(() => _appleAvailable = available);
  }

  Future<void> _signIn(String provider, Future<void> Function() action) async {
    if (_busy != null) return;
    setState(() => _busy = provider);

    try {
      await action();
      // The router's redirect takes it from here.
    } catch (error) {
      if (!mounted) return;
      // A cancelled sign-in isn't a failure worth shouting about.
      if (!_isCancellation(error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  static bool _isCancellation(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('cancel') || text.contains('aborted');
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(isDemoModeProvider);
    final auth = ref.read(authControllerProvider.notifier);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment(0, -0.1),
            colors: [Color(0x2479A7FF), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const BrandMark(size: 64),
                      const SizedBox(height: Spacing.md),
                      Text('EatStreak',
                          style: AppText.heading(size: 34, weight: FontWeight.w700)),
                      const SizedBox(height: Spacing.md),
                      Text(
                        'Keep your streaks alive and unlock rewards at your '
                        'favourite restaurants.',
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 16, height: 1.5),
                      ),
                    ],
                  ),
                ),
                _PrimarySignInButton(
                  label: isDemo ? 'Explore the demo' : 'Continue with Google',
                  icon: isDemo ? Icons.auto_awesome : Icons.g_mobiledata,
                  busy: _busy == 'google',
                  onPressed: () => _signIn('google', auth.signInWithGoogle),
                ),
                if (_appleAvailable) ...[
                  const SizedBox(height: Spacing.md),
                  _PrimarySignInButton(
                    label: 'Continue with Apple',
                    icon: Icons.apple,
                    busy: _busy == 'apple',
                    onPressed: () => _signIn('apple', auth.signInWithApple),
                  ),
                ],
                const SizedBox(height: Spacing.md),
                Text(
                  isDemo
                      ? 'Demo mode — sample data lives on this device only. '
                          'Nothing is sent anywhere.'
                      : 'By continuing you agree to our Terms and acknowledge '
                          'our Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 12, color: AppColors.muted2, height: 1.5),
                ),
                const SizedBox(height: Spacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White pill matching the Google/Apple button treatment in the Expo app.
class _PrimarySignInButton extends StatelessWidget {
  const _PrimarySignInButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.white,
        borderRadius: Radii.mdAll,
        child: InkWell(
          borderRadius: Radii.mdAll,
          onTap: busy ? null : onPressed,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1F1F1F),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 22, color: const Color(0xFF1F1F1F)),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        label,
                        style: AppText.heading(
                          size: 16,
                          weight: FontWeight.w600,
                          color: const Color(0xFF1F1F1F),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
