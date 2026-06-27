import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Native offline panel overlaid on the WebView when connectivity is lost or a
/// page load fails. [onRetry] re-attempts the load.
class OfflineView extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;

  const OfflineView({
    super.key,
    required this.onRetry,
    this.message = "You're offline. Check your connection and try again.",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BrandColors.page,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 56, color: BrandColors.textMuted),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BrandColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
