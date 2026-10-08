import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/result.dart';
import '../../../domain/entities/lead.dart';
import '../../../domain/repositories/lead_ingestion_repository.dart';
import '../../../domain/repositories/source_preferences_repository.dart';
import 'sources_event.dart';
import 'sources_state.dart';

class SourcesBloc extends Bloc<SourcesEvent, SourcesState> {
  SourcesBloc({
    required SourcePreferencesRepository sourcePreferences,
    required LeadIngestionRepository ingestion,
  })  : _sourcePreferences = sourcePreferences,
        _ingestion = ingestion,
        super(const SourcesState()) {
    on<SourcesRequested>(_onRequested, transformer: droppable());
    // `sequential` : chaque bascule fait une lecture-modification-écriture
    // des préférences ; deux bascules concurrentes perdraient l'une d'elles.
    on<SourceToggled>(_onToggled, transformer: sequential());
    // `droppable` : une synchronisation facturée ne doit pas être doublée.
    on<SourcesSyncRequested>(_onSyncRequested, transformer: droppable());
  }

  final SourcePreferencesRepository _sourcePreferences;
  final LeadIngestionRepository _ingestion;

  Future<void> _onRequested(SourcesRequested event, Emitter<SourcesState> emit) async {
    emit(state.copyWith(status: SourcesStatus.loading));

    try {
      final enabled = await _sourcePreferences.getEnabledSources();
      emit(state.copyWith(status: SourcesStatus.ready, enabledSources: enabled));
    } on Exception catch (error) {
      // Sans ce repli l'écran resterait bloqué sur le chargement.
      debugPrint('Préférences de sources illisibles : $error');
      emit(
        state.copyWith(
          status: SourcesStatus.ready,
          enabledSources: LeadSource.values.toSet(),
          errorMessage: () => 'Préférences illisibles : toutes les sources sont affichées comme actives.',
        ),
      );
    }

    await _refreshStats(emit);
  }

  Future<void> _onToggled(SourceToggled event, Emitter<SourcesState> emit) async {
    final previous = state.enabledSources;
    final next = {...previous};
    event.enabled ? next.add(event.source) : next.remove(event.source);

    // Mise à jour optimiste : l'interrupteur doit réagir instantanément.
    emit(state.copyWith(enabledSources: next, errorMessage: () => null));

    try {
      await _sourcePreferences.setSourceEnabled(event.source, enabled: event.enabled);
    } on Exception catch (error) {
      debugPrint('Préférence de source non enregistrée : $error');
      emit(
        state.copyWith(
          enabledSources: previous,
          errorMessage: () => 'Impossible d\'enregistrer la préférence. Réessayez.',
        ),
      );
    }
  }

  Future<void> _onSyncRequested(SourcesSyncRequested event, Emitter<SourcesState> emit) async {
    if (!state.canSync) return;

    emit(state.copyWith(isSyncing: true, errorMessage: () => null));

    switch (await _ingestion.synchronize(state.enabledSources)) {
      case Ok(value: final results):
        emit(
          state.copyWith(
            isSyncing: false,
            lastSyncResults: {for (final r in results) r.source: r},
          ),
        );
        await _refreshStats(emit);
      case Err(:final failure):
        emit(state.copyWith(isSyncing: false, errorMessage: () => failure.message));
    }
  }

  Future<void> _refreshStats(Emitter<SourcesState> emit) async {
    switch (await _ingestion.getSourceStats()) {
      case Ok(value: final stats):
        emit(
          state.copyWith(
            stats: {for (final s in stats) s.source: s},
            statsError: () => null,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(statsError: () => failure.message));
    }
  }
}
