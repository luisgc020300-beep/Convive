// lib/widgets/convive_sheet.dart
//
// Reemplaza los AlertDialog centrados: un panel que sube desde abajo, con
// tirador, para que crear algo se sienta como abrir un cajón, no como una
// interrupción modal.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

Future<T?> showConviveSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context, StateSetter setState) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.cork,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.colors.paperMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            builder(ctx, setState),
          ],
        ),
      ),
    ),
  );
}
