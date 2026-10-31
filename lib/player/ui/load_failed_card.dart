import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rume/core/theme/app_colors.dart';

/// Shown over the poster when an episode's video could not load. The pool
/// keeps retrying behind it; [onRetry] just does it now.
class LoadFailedCard extends StatelessWidget {
  const LoadFailedCard({required this.onRetry, super.key});

  final VoidCallback onRetry;

  static const ValueKey<String> retryKey = ValueKey('load-failed-retry');

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: AppColors.ink.withValues(alpha: 0.72),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.18),
                  border: Border.all(
                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 30,
                  color: AppColors.primaryLighter,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "Couldn't load this episode",
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                "Check your connection. We'll keep trying and start it the "
                'moment it loads.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                key: retryKey,
                onPressed: () {
                  unawaited(HapticFeedback.selectionClick());
                  onRetry();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.primaryLight),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
