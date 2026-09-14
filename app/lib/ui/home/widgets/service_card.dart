import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/service_item.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';
import '../../common/icon_tile.dart';
import '../../common/status_dot.dart';
import '../service_actions.dart';

/// One service in the grid — `docs/UI_SPEC.md` §2.3.
///
/// Watches only its own slice of the probe map, so a status change on card 3
/// cannot rebuild the other nine.
class ServiceCard extends ConsumerStatefulWidget {
  const ServiceCard({super.key, required this.service});

  final ServiceItem service;

  @override
  ConsumerState<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends ConsumerState<ServiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final configured = service.isConfigured;
    final status = configured
        ? ref.watch(
            probeProvider.select((map) => map[service.id]),
          )
        : null;
    final dot = dotStateFor(status, probeEnabled: service.probeEnabled);

    return RepaintBoundary(
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openService(context, ref, service),
            onLongPress: () =>
                unawaited(showServiceOverflowSheet(context, ref, service)),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconTile(
                          icon: service.icon,
                          opacity: dot == ProbeDotState.offline ? 0.4 : 1,
                        ),
                        const Spacer(),
                        _OverflowButton(
                          onTap: () => unawaited(
                            showServiceOverflowSheet(context, ref, service),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            service.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (status?.summary != null) ...<Widget>[
                          Text(
                            '${status!.latencyMs} ms',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ] else
                          const SizedBox(width: 6),
                        StatusDot(state: dot),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      service.displayHost,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.mono.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverflowButton extends StatelessWidget {
  const _OverflowButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 48,
    child: Align(
      alignment: Alignment.topRight,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(
            Icons.more_vert,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}

/// Keeps the ten-slot rhythm visible when fewer than ten services exist.
class GhostSlot extends StatelessWidget {
  const GhostSlot({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(18),
    ),
  );
}
