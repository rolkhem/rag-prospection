import '../../core/utils/result.dart';
import '../entities/lead.dart';

/// Recherche de similarité sur l'index vectoriel (Pinecone, Supabase pgvector
/// ou ObjectBox HNSW selon l'implémentation injectée).
abstract interface class VectorStoreRepository {
  /// [sources] doit être appliqué comme filtre de métadonnées côté serveur :
  /// filtrer après coup réduirait silencieusement le nombre de résultats sous
  /// [topK] quand une source désactivée domine l'index.
  Future<Result<List<ScoredLead>>> searchSimilar({
    required List<double> vector,
    required Set<LeadSource> sources,
    required int topK,
  });
}
