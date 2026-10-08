import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import 'source_style.dart';

/// Carte cliquable d'une source citée sous une réponse de l'IA.
class LeadSourceCard extends StatelessWidget {
  const LeadSourceCard({
    super.key,
    required this.scoredLead,
    required this.reference,
  });

  final ScoredLead scoredLead;

  /// Numéro du document dans le prompt, identique aux citations `[n]` du LLM,
  /// pour que l'utilisateur relie la phrase à sa source.
  final int reference;

  static const double width = 264;

  Future<void> _openSource(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        scoredLead.lead.sourceUrl,
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException catch (error) {
      debugPrint('Ouverture de ${scoredLead.lead.sourceUrl} impossible : ${error.message}');
    }
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir le lien de la source.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = scoredLead.lead;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Ouvrir la source ${lead.source.label} : ${lead.title}',
      child: Material(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openSource(context),
          child: Container(
            width: width,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ReferenceChip(reference: reference),
                    const SizedBox(width: 6),
                    _SourceBadge(source: lead.source),
                    const Spacer(),
                    _ScoreLabel(score: scoredLead.score),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  lead.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lead.organization,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const Spacer(),
                _LeadMetaRow(lead: lead),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceChip extends StatelessWidget {
  const _ReferenceChip({required this.reference});

  final int reference;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '[$reference]',
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final LeadSource source;

  @override
  Widget build(BuildContext context) {
    final color = source.color;
    final icon = source.icon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textPrimary),
          const SizedBox(width: 4),
          Text(
            source.label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreLabel extends StatelessWidget {
  const _ScoreLabel({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 0.8
        ? AppColors.success
        : score >= 0.7
            ? AppColors.warning
            : AppColors.textSecondary;

    return Text(
      '${(score * 100).round()} %',
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    );
  }
}

class _LeadMetaRow extends StatelessWidget {
  const _LeadMetaRow({required this.lead});

  final Lead lead;

  static String _formatBudget(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)} M€';
    if (amount >= 1000) return '${(amount / 1000).round()} k€';
    return '${amount.round()} €';
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final budget = lead.estimatedBudget;
    final deadline = lead.deadline;

    return Row(
      children: [
        if (budget != null) ...[
          const Icon(Icons.euro_rounded, size: 13, color: AppColors.warning),
          const SizedBox(width: 3),
          Text(
            _formatBudget(budget),
            style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
        ],
        if (deadline != null) ...[
          const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(
            _formatDate(deadline),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
        const Spacer(),
        const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.accent),
      ],
    );
  }
}
