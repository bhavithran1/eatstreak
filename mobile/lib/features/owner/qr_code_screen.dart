import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/qr_codec.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/empty_state.dart';

/// The shop's check-in code, sized to be printed and stuck on a table.
class OwnerQrCodeScreen extends ConsumerWidget {
  const OwnerQrCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              subtitle: 'Register your shop before printing or sharing a '
                  'check-in QR code.',
              actionLabel: 'Register shop',
              onAction: () => context.push(Routes.registerShop),
            ),
          ),
        ),
      );
    }

    final link = encodeQr(shop.id);

    return AppScreen(
      title: 'Your QR code',
      subtitle: 'Customers scan this to check in.',
      children: [
        Center(
          child: Column(
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
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: Radii.lgAll,
                  ),
                  child: QrImageView(
                    data: link,
                    size: 220,
                    backgroundColor: Colors.white,
                    // High correction so a scuffed or partly covered printout
                    // still scans.
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.primaryInk,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.primaryInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(shop.name, style: AppText.heading(size: 20)),
              const SizedBox(height: 2),
              Text('Scan to earn rewards', style: AppText.body(size: 14)),
              const SizedBox(height: Spacing.md),
              _shareButton(context, shop.name, link),
            ],
          ),
        ),
        const SizedBox(height: Spacing.xl),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tips for placement', style: AppText.heading(size: 15)),
              const SizedBox(height: Spacing.md),
              _tip(Icons.restaurant_outlined, 'Place at every table and counter'),
              const SizedBox(height: Spacing.md),
              _tip(Icons.print_outlined, 'Print on table tents or stickers'),
              const SizedBox(height: Spacing.md),
              _tip(Icons.visibility_outlined, 'Keep it visible and well-lit'),
              const SizedBox(height: Spacing.md),
              _tip(
                Icons.chat_bubble_outline,
                'Train staff to encourage scanning',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shareButton(BuildContext context, String shopName, String link) =>
      GestureDetector(
        onTap: () => SharePlus.instance.share(
          ShareParams(
            title: '$shopName check-in code',
            text: 'Check in at $shopName on EatStreak and keep your streak '
                'going: $link',
          ),
        ),
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: Radii.mdAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.ios_share,
                size: 18,
                color: AppColors.primaryInk,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                'Share check-in code',
                style: AppText.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.primaryInk,
                ),
              ),
            ],
          ),
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
