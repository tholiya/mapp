import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Icon + "Bedn" + gradient "Bite" lockup, matching react/app/login/page.tsx.
class BrandLockup extends StatelessWidget {
  final double iconSize;
  final double textSize;
  const BrandLockup({super.key, this.iconSize = 64, this.textSize = 24});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/logo/logo_icon.png',
          width: iconSize,
          height: iconSize,
        ),
        const SizedBox(height: 12),
        DefaultTextStyle(
          style: TextStyle(
            fontSize: textSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: BrandColors.textPrimary,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bedn'),
              ShaderMask(
                shaderCallback: (bounds) =>
                    BrandColors.wordmark.createShader(bounds),
                child: const Text(
                  'Bite',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
