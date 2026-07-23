import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../state/store_controller.dart';
import 'empty_state.dart';

/// Builds a screen body only once the store has actually loaded.
///
/// Screens used to read `ref.watch(storeControllerProvider).value ?? const
/// StoreState()`, which silently turns "still loading" and "the request failed"
/// into "you have no data". On the owner side that rendered as **"No shop yet —
/// Register shop"**, one tap away from registering a second shop over a flaky
/// connection. Inside [builder] an empty list genuinely means empty.
class StoreScope extends ConsumerWidget {
  const StoreScope({super.key, required this.builder});

  final Widget Function(BuildContext context, StoreState state) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(storeControllerProvider).when(
          loading: () => const _Frame(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (_, _) => _Frame(
            child: EmptyState(
              icon: Icons.cloud_off_outlined,
              title: "Couldn't load your data",
              subtitle: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () =>
                  ref.read(storeControllerProvider.notifier).refresh(),
            ),
          ),
          data: (state) => builder(context, state),
        );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(child: Center(child: child)),
      );
}
