import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Indicateur animé affiché pendant le pipeline RAG (souvent 3 à 8 s) pour
/// signaler que l'app travaille et éviter les renvois impatients.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  children: List.generate(3, (index) {
                    // Déphasage de chaque point pour l'effet « vague ».
                    final phase = (_controller.value - index * 0.2) * 2 * math.pi;
                    final opacity = 0.35 + 0.65 * ((math.sin(phase) + 1) / 2);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: opacity,
                        child: const _Dot(),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Recherche et analyse des opportunités…',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 7,
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
      ),
    );
  }
}
