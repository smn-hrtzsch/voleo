import 'package:flutter/material.dart';

enum AppToastType { info, success, error }

void showAppToast(
  BuildContext context,
  String message, {
  AppToastType type = AppToastType.info,
}) {
  final scheme = Theme.of(context).colorScheme;
  final (icon, background, foreground) = switch (type) {
    AppToastType.success => (
        Icons.check_circle_outline,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
    AppToastType.error => (
        Icons.error_outline,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    AppToastType.info => (
        Icons.info_outline,
        scheme.inverseSurface,
        scheme.onInverseSurface,
      ),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        backgroundColor: background,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
