import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Inline error shown directly below an input — matches the React app's
/// inline-validation convention (never a toast for field-level errors).
class FieldError extends StatelessWidget {
  final String? message;
  const FieldError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message!,
        style: const TextStyle(color: BrandColors.danger, fontSize: 12),
      ),
    );
  }
}
