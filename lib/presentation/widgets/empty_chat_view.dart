import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class EmptyChatView extends StatelessWidget {
  const EmptyChatView({super.key, required this.onSuggestionSelected});

  final ValueChanged<String> onSuggestionSelected;

  static const List<String> _suggestions = [
    'Trouve-moi des PME qui cherchent des prestataires en cybersécurité en Île-de-France',
    'Appels d\'offres ouverts pour la refonte de SI hospitaliers en Occitanie',
    'Entreprises qui recrutent un DSI ou annoncent une migration cloud ce mois-ci',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.userBubble,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: const Icon(Icons.radar_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              'Interrogez vos gisements d\'opportunités',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Appels d\'offres publics et signaux sociaux, analysés et qualifiés par l\'IA.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            for (final suggestion in _suggestions)
              _SuggestionTile(
                text: suggestion,
                onTap: () => onSuggestionSelected(suggestion),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.north_east_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
