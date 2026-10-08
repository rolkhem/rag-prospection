import 'package:equatable/equatable.dart';

import '../../../domain/entities/lead.dart';
import '../../../domain/entities/source_sync.dart';

enum SourcesStatus { loading, ready }

/// Même approche que `ChatState` : un état unique, car préférences,
/// statistiques et résultat de synchronisation coexistent à l'écran et ne
/// doivent pas disparaître lors d'une transition.
class SourcesState extends Equatable {
  const SourcesState({
    this.status = SourcesStatus.loading,
    this.enabledSources = const <LeadSource>{},
    this.stats = const <LeadSource, SourceStats>{},
    this.statsError,
    this.isSyncing = false,
    this.lastSyncResults = const <LeadSource, SourceSyncResult>{},
    this.errorMessage,
  });

  final SourcesStatus status;
  final Set<LeadSource> enabledSources;
  final Map<LeadSource, SourceStats> stats;

  /// Les statistiques sont informatives : leur échec n'empêche pas de
  /// modifier les sources, d'où un champ distinct de [errorMessage].
  final String? statsError;
  final bool isSyncing;
  final Map<LeadSource, SourceSyncResult> lastSyncResults;

  /// Erreur ponctuelle (persistance, synchronisation) affichée en SnackBar.
  final String? errorMessage;

  bool get canSync => status == SourcesStatus.ready && !isSyncing && enabledSources.isNotEmpty;

  SourcesState copyWith({
    SourcesStatus? status,
    Set<LeadSource>? enabledSources,
    Map<LeadSource, SourceStats>? stats,
    String? Function()? statsError,
    bool? isSyncing,
    Map<LeadSource, SourceSyncResult>? lastSyncResults,
    String? Function()? errorMessage,
  }) {
    return SourcesState(
      status: status ?? this.status,
      enabledSources: enabledSources ?? this.enabledSources,
      stats: stats ?? this.stats,
      statsError: statsError != null ? statsError() : this.statsError,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncResults: lastSyncResults ?? this.lastSyncResults,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        enabledSources,
        stats,
        statsError,
        isSyncing,
        lastSyncResults,
        errorMessage,
      ];
}
