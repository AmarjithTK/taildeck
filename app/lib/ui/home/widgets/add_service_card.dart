import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../common/dashed_border.dart';
import '../service_actions.dart';

/// The first free grid slot — `docs/UI_SPEC.md` §2.4.
class AddServiceCard extends ConsumerWidget {
  const AddServiceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DashedRRectBorder(
    color: AppColors.borderDashed,
    child: InkWell(
      onTap: () => unawaited(editService(context, ref, null)),
      borderRadius: BorderRadius.circular(18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                size: 24,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Add Service',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Tap to configure',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}
