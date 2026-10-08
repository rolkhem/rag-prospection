import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/source_sync.dart';
import '../blocs/sources/sources_bloc.dart';
import '../blocs/sources/sources_event.dart';
import '../blocs/sources/sources_state.dart';
import '../widgets/source_style.dart';

/// Écran B — Activation des sources et synchronisation de l'index.
///
/// Le [SourcesBloc] est créé à l'ouverture de l'écran (voir `app.dart`) :
/// contrairement à l'historique du chat, son état se recharge à chaque visite
/// depuis les préférences et le serveur.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SourcesBloc, SourcesState>(
      listenWhen: (previous, current) =>
          current.errorMessage != null && previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Sources & filtres')),
        body: BlocBuilder<SourcesBloc, SourcesState>(
          builder: (context, state) {
            if (state.status == SourcesStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return _SourcesList(state: state);
          },
        ),
        bottomNavigationBar: const _SyncBar(),
      ),
    );
  }
}

class _SourcesList extends StatelessWidget {
  const _SourcesList({required this.state});

  final SourcesState state;

  @override
  Widget build(BuildContext context) {
    final statsError = state.statsError;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'Les sources désactivées sont exclues des recherches du chat.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        if (state.enabledSources.isEmpty) ...[
          const SizedBox(height: 12),
          const _Notice(
            icon: Icons.warning_amber_rounded,
            color: AppColors.warning,
            text: 'Aucune source active : le chat ne pourra rien rechercher.',
          ),
        ],
        if (statsError != null) ...[
          const SizedBox(height: 12),
          _Notice(
            icon: Icons.cloud_off_rounded,
            color: AppColors.error,
            text: 'Statistiques indisponibles. $statsError',
          ),
        ],
        for (final category in LeadCategory.values) ...[
          _SectionHeader(label: category.label),
          for (final source in LeadSource.values.where((s) => s.category == category))
            _SourceTile(
              source: source,
              enabled: state.enabledSources.contains(source),
              stats: state.stats[source],
              syncResult: state.lastSyncResults[source],
            ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8, left: 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.enabled,
    required this.stats,
    required this.syncResult,
  });

  final LeadSource source;
  final bool enabled;
  final SourceStats? stats;
  final SourceSyncResult? syncResult;

  @override
  Widget build(BuildContext context) {
    final result = syncResult;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _toggle(context, !enabled),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled ? source.color.withValues(alpha: 0.55) : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                _SourceAvatar(source: source, enabled: enabled),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.label,
                        style: TextStyle(
                          color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statsLabel(stats),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      if (result != null) ...[
                        const SizedBox(height: 4),
                        _SyncResultLine(result: result),
                      ],
                    ],
                  ),
                ),
                Switch(
                  key: Key('source_switch_${source.name}'),
                  value: enabled,
                  activeTrackColor: source.color,
                  onChanged: (value) => _toggle(context, value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggle(BuildContext context, bool value) {
    context.read<SourcesBloc>().add(SourceToggled(source, enabled: value));
  }

  static String _statsLabel(SourceStats? stats) {
    if (stats == null) return 'Index : —';
    final count = stats.leadCount == 0
        ? 'Index vide'
        : '${_formatCount(stats.leadCount)} lead${stats.leadCount > 1 ? 's' : ''}';
    final synced = stats.lastSyncedAt;
    return synced == null ? '$count · jamais synchronisée' : '$count · synchro ${_formatDateTime(synced)}';
  }

  /// Séparateur de milliers à l'espace insécable, sans dépendre de `intl`.
  static String _formatCount(int value) {
    return value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  }

  static String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} à ${two(local.hour)}:${two(local.minute)}';
  }
}

class _SourceAvatar extends StatelessWidget {
  const _SourceAvatar({required this.source, required this.enabled});

  final LeadSource source;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: (enabled ? source.color : AppColors.textMuted).withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(
        source.icon,
        size: 20,
        color: enabled ? AppColors.textPrimary : AppColors.textMuted,
      ),
    );
  }
}

class _SyncResultLine extends StatelessWidget {
  const _SyncResultLine({required this.result});

  final SourceSyncResult result;

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = switch (result.status) {
      SourceSyncStatus.ok => (
          AppColors.success,
          Icons.check_circle_rounded,
          result.inserted == 0
              ? 'À jour (${result.fetched} avis vérifiés)'
              : '+${result.inserted} nouveau${result.inserted > 1 ? 'x' : ''} lead${result.inserted > 1 ? 's' : ''}',
        ),
      SourceSyncStatus.partial => (
          AppColors.warning,
          Icons.timelapse_rounded,
          '+${result.inserted} · ${result.remaining} restant${result.remaining > 1 ? 's' : ''}. '
              '${result.message ?? 'Relancez dans une minute.'}',
        ),
      SourceSyncStatus.cooldown => (
          AppColors.textSecondary,
          Icons.schedule_rounded,
          result.message ?? 'Synchronisée récemment.',
        ),
      SourceSyncStatus.unsupported => (
          AppColors.warning,
          Icons.info_outline_rounded,
          result.message ?? 'Connecteur non disponible.',
        ),
      SourceSyncStatus.error => (
          AppColors.error,
          Icons.error_outline_rounded,
          result.message ?? 'Échec de la synchronisation.',
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontSize: 11.5)),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SyncBar extends StatelessWidget {
  const _SyncBar();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: BlocBuilder<SourcesBloc, SourcesState>(
            buildWhen: (previous, current) =>
                previous.isSyncing != current.isSyncing || previous.canSync != current.canSync,
            builder: (context, state) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('sources_sync_button'),
                    // Pendant la synchro, le bouton reste désactivé mais garde
                    // sa couleur : le gris par défaut rendait l'indicateur
                    // blanc illisible et faisait croire à un bouton inactif.
                    style: state.isSyncing
                        ? FilledButton.styleFrom(
                            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                            disabledForegroundColor: Colors.white,
                          )
                        : null,
                    onPressed: state.canSync
                        ? () => context.read<SourcesBloc>().add(const SourcesSyncRequested())
                        : null,
                    icon: state.isSyncing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(
                      state.isSyncing ? 'Synchronisation en cours…' : 'Synchroniser les sources actives',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Récupère les publications des 30 derniers jours. Peut prendre jusqu\'à une minute.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
