import 'package:equatable/equatable.dart';

import 'lead.dart';

/// État de l'index pour une source, affiché dans l'écran Sources.
class SourceStats extends Equatable {
  const SourceStats({
    required this.source,
    required this.leadCount,
    this.lastPublishedAt,
    this.lastSyncedAt,
  });

  final LeadSource source;
  final int leadCount;
  final DateTime? lastPublishedAt;
  final DateTime? lastSyncedAt;

  @override
  List<Object?> get props => [source, leadCount, lastPublishedAt, lastSyncedAt];
}

enum SourceSyncStatus {
  ok,

  /// Une partie seulement des avis a été vectorisée (budget ou quota
  /// d'embeddings atteint) : relancer pour continuer.
  partial,

  /// Synchronisée trop récemment : le serveur borne la fréquence pour
  /// limiter le coût des embeddings.
  cooldown,

  /// Aucun connecteur côté serveur (LinkedIn, X : pas d'API publique).
  unsupported,
  error,
}

class SourceSyncResult extends Equatable {
  const SourceSyncResult({
    required this.source,
    required this.status,
    required this.fetched,
    required this.inserted,
    this.remaining = 0,
    this.message,
  });

  final LeadSource source;
  final SourceSyncStatus status;
  final int fetched;
  final int inserted;
  final int remaining;
  final String? message;

  @override
  List<Object?> get props => [source, status, fetched, inserted, remaining, message];
}
