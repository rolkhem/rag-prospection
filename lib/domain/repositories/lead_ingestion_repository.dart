import '../../core/utils/result.dart';
import '../entities/lead.dart';
import '../entities/source_sync.dart';

/// Alimentation de l'index vectoriel.
///
/// L'ingestion s'exécute côté serveur : elle requiert des droits d'écriture
/// et la clé du modèle d'embedding, qui ne doivent pas être embarqués dans
/// l'application.
abstract interface class LeadIngestionRepository {
  Future<Result<List<SourceStats>>> getSourceStats();

  Future<Result<List<SourceSyncResult>>> synchronize(Set<LeadSource> sources);
}
