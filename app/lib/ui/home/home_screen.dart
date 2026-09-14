import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/models/service_item.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../settings/settings_screen.dart';
import 'service_actions.dart';
import 'widgets/add_service_card.dart';
import 'widgets/service_card.dart';
import 'widgets/tailscale_banner.dart';

/// Screen 1 — `docs/UI_SPEC.md` §2.
///
/// A fixed 2 x 5 grid that fills the available height exactly and never
/// scrolls, so the ten slots always land in the same place.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: K.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(
              onSettings: () => unawaited(
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ),
            const TailscaleBanner(),
            const SizedBox(height: K.gridGap),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: services.isEmpty
                    ? const _EmptyState()
                    : _ServiceGrid(services: services),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'TailDeck',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Your private services, anywhere',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            onPressed: onSettings,
            tooltip: 'Settings',
            icon: const Icon(
              Icons.settings_outlined,
              size: 22,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Sizes each card so [K.gridRows] rows and [K.gridColumns] columns exactly fill
/// the space between the header and the navigation bar.
///
/// If that space is too short for a legible card — a very short screen, or a
/// large text scale — the cards keep a minimum height and the grid is allowed to
/// scroll instead of clipping. Ten fixed slots is the goal; clipping content to
/// preserve it would not be.
class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.services});

  /// Below this, a card can no longer show an icon, a name and an address.
  static const double _minCardHeight = 96;

  final List<ServiceItem> services;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = K.gridGap;
      final cardWidth =
          (constraints.maxWidth - gap * (K.gridColumns - 1)) / K.gridColumns;
      final fittedHeight =
          (constraints.maxHeight - gap * (K.gridRows - 1)) / K.gridRows;
      final fits = fittedHeight >= _minCardHeight;
      final cardHeight = fits ? fittedHeight : _minCardHeight;

      return GridView.count(
        crossAxisCount: K.gridColumns,
        // Only lock the grid when it genuinely fills the screen.
        physics: fits
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        childAspectRatio: cardWidth / cardHeight,
        children: <Widget>[
          for (var index = 0; index < K.maxServices; index++) _slot(index),
        ],
      );
    },
  );

  Widget _slot(int index) {
    if (index < services.length) {
      final service = services[index];
      return ServiceCard(key: ValueKey<String>(service.id), service: service);
    }
    // Only the first free slot invites a new service; the rest keep the rhythm.
    if (index == services.length && services.length < K.maxServices) {
      return const AddServiceCard();
    }
    return const GhostSlot();
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.add,
              size: 30,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Add your first service',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use your Tailscale address, for example\n100.114.10.5:3000',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => unawaited(editService(context, ref, null)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Add Service',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}
