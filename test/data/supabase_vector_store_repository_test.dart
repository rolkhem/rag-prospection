import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rag_prospection/core/network/json_http_client.dart';
import 'package:rag_prospection/core/utils/result.dart';
import 'package:rag_prospection/data/datasources/supabase_api.dart';
import 'package:rag_prospection/data/repositories/supabase_vector_store_repository.dart';
import 'package:rag_prospection/domain/entities/lead.dart';

void main() {
  late http.Request sent;

  SupabaseVectorStoreRepository repository(String anonKey, List<Object?> rows) {
    final client = MockClient((request) async {
      sent = request;
      return http.Response.bytes(utf8.encode(jsonEncode(rows)), 200);
    });
    return SupabaseVectorStoreRepository(
      SupabaseApi(
        baseUrl: Uri.parse('https://demo.supabase.co'),
        anonKey: anonKey,
        client: JsonHttpClient(client: client),
      ),
    );
  }

  final validRow = <String, Object?>{
    'id': 'boamp:26-96507',
    'source': 'boamp',
    'title': 'Audit de sécurité du SI',
    'organization': 'Mairie de Lyon',
    'summary': 'Audit',
    'content': 'Objet : audit',
    'source_url': 'https://www.boamp.fr/pages/avis/?q=idweb:26-96507',
    'published_at': '2026-10-08T00:00:00+00:00',
    'deadline': '2026-11-09T11:00:00+00:00',
    'similarity': 0.83,
  };

  test('appelle match_leads avec le filtre de sources au format wire', () async {
    final repo = repository('eyJhbGciOiJIUzI1NiJ9.test', [validRow]);

    final result = await repo.searchSimilar(
      vector: const [0.1, 0.2],
      sources: {LeadSource.boamp, LeadSource.linkedIn},
      topK: 6,
    );

    expect(sent.url.path, '/rest/v1/rpc/match_leads');
    expect(sent.headers['Authorization'], 'Bearer eyJhbGciOiJIUzI1NiJ9.test');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['match_count'], 6);
    expect(body['filter_sources'], unorderedEquals(['boamp', 'linkedin']));

    final leads = (result as Ok<List<ScoredLead>>).value;
    expect(leads.single.score, 0.83);
    expect(leads.single.lead.deadline, DateTime.utc(2026, 11, 9, 11));
  });

  test('n\'envoie pas de Bearer avec une clé publishable non-JWT', () async {
    final repo = repository('sb_publishable_abc', const []);

    await repo.searchSimilar(vector: const [0.1], sources: {LeadSource.ted}, topK: 3);

    expect(sent.headers['apikey'], 'sb_publishable_abc');
    expect(sent.headers, isNot(contains('Authorization')));
  });

  test('ignore une ligne invalide sans perdre les autres', () async {
    final repo = repository('sb_publishable_abc', [
      {...validRow, 'id': 'bad', 'source_url': 'javascript:alert(1)'},
      validRow,
    ]);

    final result = await repo.searchSimilar(vector: const [0.1], sources: {LeadSource.boamp}, topK: 3);

    expect((result as Ok<List<ScoredLead>>).value.map((l) => l.lead.id), ['boamp:26-96507']);
  });
}
