import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rag_prospection/core/errors/failures.dart';
import 'package:rag_prospection/core/utils/result.dart';
import 'package:rag_prospection/domain/entities/lead.dart';
import 'package:rag_prospection/domain/entities/source_sync.dart';
import 'package:rag_prospection/domain/repositories/lead_ingestion_repository.dart';
import 'package:rag_prospection/domain/repositories/source_preferences_repository.dart';
import 'package:rag_prospection/presentation/blocs/sources/sources_bloc.dart';
import 'package:rag_prospection/presentation/blocs/sources/sources_event.dart';
import 'package:rag_prospection/presentation/blocs/sources/sources_state.dart';

class _MockPreferences extends Mock implements SourcePreferencesRepository {}

class _MockIngestion extends Mock implements LeadIngestionRepository {}

const _boampStats = SourceStats(source: LeadSource.boamp, leadCount: 12);

void main() {
  late _MockPreferences preferences;
  late _MockIngestion ingestion;

  setUpAll(() => registerFallbackValue(LeadSource.boamp));

  setUp(() {
    preferences = _MockPreferences();
    ingestion = _MockIngestion();
    when(() => preferences.getEnabledSources())
        .thenAnswer((_) async => {LeadSource.boamp, LeadSource.ted});
    when(() => ingestion.getSourceStats()).thenAnswer((_) async => const Ok([_boampStats]));
  });

  SourcesBloc build() => SourcesBloc(sourcePreferences: preferences, ingestion: ingestion);

  blocTest<SourcesBloc, SourcesState>(
    'charge les préférences puis les statistiques',
    build: build,
    act: (bloc) => bloc.add(const SourcesRequested()),
    expect: () => [
      const SourcesState(),
      const SourcesState(
        status: SourcesStatus.ready,
        enabledSources: {LeadSource.boamp, LeadSource.ted},
      ),
      const SourcesState(
        status: SourcesStatus.ready,
        enabledSources: {LeadSource.boamp, LeadSource.ted},
        stats: {LeadSource.boamp: _boampStats},
      ),
    ],
  );

  blocTest<SourcesBloc, SourcesState>(
    'un échec des statistiques n\'empêche pas l\'écran d\'être utilisable',
    build: () {
      when(() => ingestion.getSourceStats()).thenAnswer((_) async => const Err(NetworkFailure()));
      return build();
    },
    act: (bloc) => bloc.add(const SourcesRequested()),
    skip: 2,
    expect: () => [
      isA<SourcesState>()
          .having((s) => s.status, 'status', SourcesStatus.ready)
          .having((s) => s.statsError, 'statsError', isNotNull),
    ],
  );

  blocTest<SourcesBloc, SourcesState>(
    'annule la bascule optimiste si la persistance échoue',
    build: () {
      when(() => preferences.setSourceEnabled(any(), enabled: any(named: 'enabled')))
          .thenThrow(Exception('disque plein'));
      return build();
    },
    seed: () => const SourcesState(
      status: SourcesStatus.ready,
      enabledSources: {LeadSource.boamp},
    ),
    act: (bloc) => bloc.add(const SourceToggled(LeadSource.x, enabled: true)),
    expect: () => [
      isA<SourcesState>().having((s) => s.enabledSources, 'optimiste', {LeadSource.boamp, LeadSource.x}),
      isA<SourcesState>()
          .having((s) => s.enabledSources, 'restauré', {LeadSource.boamp})
          .having((s) => s.errorMessage, 'errorMessage', isNotNull),
    ],
  );

  blocTest<SourcesBloc, SourcesState>(
    'synchronise uniquement les sources actives et rafraîchit les statistiques',
    build: () {
      when(() => ingestion.synchronize(any())).thenAnswer(
        (_) async => const Ok([
          SourceSyncResult(
            source: LeadSource.boamp,
            status: SourceSyncStatus.ok,
            fetched: 40,
            inserted: 3,
          ),
        ]),
      );
      return build();
    },
    seed: () => const SourcesState(
      status: SourcesStatus.ready,
      enabledSources: {LeadSource.boamp},
    ),
    act: (bloc) => bloc.add(const SourcesSyncRequested()),
    verify: (bloc) {
      verify(() => ingestion.synchronize({LeadSource.boamp})).called(1);
      verify(() => ingestion.getSourceStats()).called(1);
      expect(bloc.state.isSyncing, isFalse);
      expect(bloc.state.lastSyncResults[LeadSource.boamp]?.inserted, 3);
    },
  );

  blocTest<SourcesBloc, SourcesState>(
    'ne synchronise pas sans source active',
    build: build,
    seed: () => const SourcesState(status: SourcesStatus.ready),
    act: (bloc) => bloc.add(const SourcesSyncRequested()),
    expect: () => <SourcesState>[],
    verify: (_) => verifyNever(() => ingestion.synchronize(any())),
  );
}
