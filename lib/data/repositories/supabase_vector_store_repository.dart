import 'package:flutter/foundation.dart';

import '../../core/errors/exceptions.dart';
import '../../core/network/result_guard.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/lead.dart';
import '../../domain/repositories/vector_store_repository.dart';
import '../datasources/supabase_api.dart';
import '../models/lead_model.dart';

/// Recherche via la RPC `match_leads` (pgvector, distance cosinus), qui
/// applique le filtre de source pendant le parcours de l'index HNSW.
class SupabaseVectorStoreRepository implements VectorStoreRepository {
  const SupabaseVectorStoreRepository(this._api);

  final SupabaseApi _api;

  @override
  Future<Result<List<ScoredLead>>> searchSimilar({
    required List<double> vector,
    required Set<LeadSource> sources,
    required int topK,
  }) {
    return guardResult('Supabase', () async {
      final body = await _api.rpc('match_leads', {
        'query_embedding': vector,
        'match_count': topK,
        'filter_sources': [for (final source in sources) source.wireValue],
      });

      if (body is! List<Object?>) {
        throw const ParsingException('match_leads doit renvoyer une liste.');
      }

      final leads = <ScoredLead>[];
      for (final row in body) {
        if (row is! Map<String, dynamic>) continue;
        try {
          leads.add(LeadModel.fromVectorMatch(row));
        } on ParsingException catch (error) {
          // Une ligne corrompue ne doit pas faire échouer toute la réponse :
          // les autres leads restent exploitables.
          debugPrint('Lead ignoré : ${error.message}');
        }
      }
      return leads;
    });
  }
}
