import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rag_prospection/core/theme/app_theme.dart';
import 'package:rag_prospection/core/utils/result.dart';
import 'package:rag_prospection/domain/entities/lead.dart';
import 'package:rag_prospection/domain/entities/source_sync.dart';
import 'package:rag_prospection/domain/repositories/lead_ingestion_repository.dart';
import 'package:rag_prospection/domain/repositories/source_preferences_repository.dart';
import 'package:rag_prospection/presentation/blocs/sources/sources_bloc.dart';
import 'package:rag_prospection/presentation/blocs/sources/sources_event.dart';
import 'package:rag_prospection/presentation/screens/sources_screen.dart';

class _MockPreferences extends Mock implements SourcePreferencesRepository {}

class _MockIngestion extends Mock implements LeadIngestionRepository {}

void main() {
  late _MockPreferences preferences;
  late _MockIngestion ingestion;

  setUpAll(() => registerFallbackValue(LeadSource.boamp));

  setUp(() {
    preferences = _MockPreferences();
    ingestion = _MockIngestion();
    when(() => preferences.getEnabledSources()).thenAnswer((_) async => {LeadSource.boamp});
    when(() => preferences.setSourceEnabled(any(), enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
    when(() => ingestion.getSourceStats()).thenAnswer(
      (_) async => Ok([
        SourceStats(
          source: LeadSource.boamp,
          leadCount: 1234,
          lastSyncedAt: DateTime(2026, 10, 8, 14, 32),
        ),
      ]),
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider(
          create: (_) => SourcesBloc(sourcePreferences: preferences, ingestion: ingestion)
            ..add(const SourcesRequested()),
          child: const SourcesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('affiche les statistiques et persiste une bascule', (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('1 234 leads'), findsOneWidget);
    expect(find.textContaining('synchro 08/10 à 14:32'), findsOneWidget);

    await tester.tap(find.byKey(const Key('source_switch_ted')));
    await tester.pumpAndSettle();

    verify(() => preferences.setSourceEnabled(LeadSource.ted, enabled: true)).called(1);
    final tedSwitch = tester.widget<Switch>(find.byKey(const Key('source_switch_ted')));
    expect(tedSwitch.value, isTrue);
  });

  testWidgets('affiche le résultat de synchronisation par source', (tester) async {
    when(() => ingestion.synchronize(any())).thenAnswer(
      (_) async => const Ok([
        SourceSyncResult(source: LeadSource.boamp, status: SourceSyncStatus.ok, fetched: 50, inserted: 4),
      ]),
    );
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('sources_sync_button')));
    await tester.pumpAndSettle();

    expect(find.text('+4 nouveaux leads'), findsOneWidget);
  });
}
