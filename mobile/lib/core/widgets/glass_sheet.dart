import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shows a modal bottom sheet with a frosted-glass background.
///
/// The barrier is dimmed but transparent, and the sheet itself uses
/// `BackdropFilter` so the content underneath blurs through it. Matches the
/// rest of the app: rounded top corners, ergonomic drag handle, safe-area
/// aware padding.
Future<T?> showGlassBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    isScrollControlled: isScrollControlled,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.78),
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
            padding: EdgeInsets.only(
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).padding.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppTheme.space3),
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Flexible(child: builder(ctx)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
