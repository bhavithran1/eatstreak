import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/errors.dart';
import '../../data/models/enums.dart';
import '../../state/auth_controller.dart';
import '../shared/widgets/brand_mark.dart';
import '../shared/widgets/gradient_button.dart';

/// Three intro pages, then the name + role form that writes users/{uid} and
/// completes onboarding.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pages = [
    (
      eyebrow: 'FAST CHECK-INS',
      title: 'One scan. Visit logged.',
      body: 'Check in at partner restaurants in seconds. No paper cards, no '
          'account numbers to remember.',
    ),
    (
      eyebrow: 'VISIBLE PROGRESS',
      title: 'Know exactly where you stand.',
      body: 'See active streaks, deadlines, and the next reward across every '
          'place you visit.',
    ),
    (
      eyebrow: 'USEFUL REWARDS',
      title: 'Loyalty that pays off.',
      body: 'Unlock clear, redeemable discounts for repeat visits and '
          'consistent streaks.',
    ),
  ];

  final _controller = PageController();
  final _nameController = TextEditingController();

  int _page = 0;
  UserRole _role = UserRole.customer;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _onSetupPage => _page == _pages.length;

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeOnboarding(_nameController.text, _role);
      // Redirect sends us into the app.
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: _onSetupPage
                    ? const SizedBox(height: 20)
                    : TextButton(
                        onPressed: () => _goTo(_pages.length),
                        child: Text('Skip', style: AppText.body(size: 15)),
                      ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final page in _pages)
                    _IntroPage(
                      eyebrow: page.eyebrow,
                      title: page.title,
                      body: page.body,
                    ),
                  _SetupPage(
                    nameController: _nameController,
                    role: _role,
                    onRoleChanged: (r) => setState(() => _role = r),
                  ),
                ],
              ),
            ),
            _PageDots(count: _pages.length + 1, active: _page),
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: GradientButton(
                label: _onSetupPage ? 'Continue' : 'Next',
                size: GradientButtonSize.lg,
                expand: true,
                busy: _submitting,
                onPressed: _onSetupPage ? _finish : () => _goTo(_page + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.eyebrow, required this.title, required this.body});

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandMark(size: 56),
            const SizedBox(height: Spacing.xl),
            Text(eyebrow, style: AppText.eyebrow),
            const SizedBox(height: Spacing.sm),
            Text(title, style: AppText.heading(size: 30, weight: FontWeight.w700)),
            const SizedBox(height: Spacing.md),
            Text(body, style: AppText.body(size: 16, height: 1.6)),
          ],
        ),
      );
}

class _SetupPage extends StatelessWidget {
  const _SetupPage({
    required this.nameController,
    required this.role,
    required this.onRoleChanged,
  });

  final TextEditingController nameController;
  final UserRole role;
  final ValueChanged<UserRole> onRoleChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Spacing.xl),
            const BrandMark(size: 56),
            const SizedBox(height: Spacing.xl),
            Text('Make it yours',
                style: AppText.heading(size: 30, weight: FontWeight.w700)),
            const SizedBox(height: Spacing.sm),
            Text('Tell us how you plan to use EatStreak.',
                style: AppText.body(size: 16)),
            const SizedBox(height: Spacing.xl),
            Text('Name', style: AppText.eyebrow),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Your first name'),
              style: AppText.body(size: 16, color: AppColors.ink),
            ),
            const SizedBox(height: Spacing.lg),
            Text('Use EatStreak as', style: AppText.eyebrow),
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                Expanded(
                  child: _RoleCard(
                    label: 'Customer',
                    icon: Icons.local_fire_department_outlined,
                    selected: role == UserRole.customer,
                    onTap: () => onRoleChanged(UserRole.customer),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: _RoleCard(
                    label: 'Shop Owner',
                    icon: Icons.storefront_outlined,
                    selected: role == UserRole.owner,
                    onTap: () => onRoleChanged(UserRole.owner),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            vertical: Spacing.lg,
            horizontal: Spacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.card,
            borderRadius: Radii.mdAll,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 26, color: selected ? AppColors.primary : AppColors.muted),
              const SizedBox(height: Spacing.sm),
              Text(
                label,
                style: AppText.heading(
                  size: 15,
                  weight: FontWeight.w600,
                  color: selected ? AppColors.ink : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: i == active ? 22 : 6,
              decoration: BoxDecoration(
                color: i == active ? AppColors.primary : AppColors.line2,
                borderRadius: Radii.pillAll,
              ),
            ),
        ],
      );
}
