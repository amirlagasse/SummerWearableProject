import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  IconData? icon,
  Color? backgroundColor,
  Color? foregroundColor,
  Duration duration = const Duration(seconds: 3),
}) {
  final theme = Theme.of(context);
  final Color baseBackground = backgroundColor ?? const Color(0xFF1E1E1E);
  final Color baseForeground = foregroundColor ?? Colors.white;

  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        backgroundColor: baseBackground.withAlpha((0.94 * 255).round()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: baseForeground),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: baseForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        duration: duration,
      ),
    );
}
