import 'package:equatable/equatable.dart';

import '../../../domain/entities/lead.dart';

sealed class SourcesEvent extends Equatable {
  const SourcesEvent();

  @override
  List<Object?> get props => [];
}

/// Chargement initial des préférences et des statistiques de l'index.
final class SourcesRequested extends SourcesEvent {
  const SourcesRequested();
}

final class SourceToggled extends SourcesEvent {
  const SourceToggled(this.source, {required this.enabled});

  final LeadSource source;
  final bool enabled;

  @override
  List<Object?> get props => [source, enabled];
}

/// Lance l'ingestion côté serveur pour les sources actives.
final class SourcesSyncRequested extends SourcesEvent {
  const SourcesSyncRequested();
}
