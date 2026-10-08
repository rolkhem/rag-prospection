import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/result_guard.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/source_sync.dart';
import '../../domain/repositories/lead_ingestion_repository.dart';
import '../datasources/supabase_api.dart';
import '../models/lead_model.dart';

/// Statistiques via la RPC `lead_source_stats`, synchronisation via l'Edge
/// Function `sync-leads` (qui détient les clés service_role et Gemini).
class SupabaseLeadIngestionRepository implements LeadIngestionRepository {
  const SupabaseLeadIngestionRepository(this._api);

  final SupabaseApi _api;

  @override
  Future<Result<List<SourceStats>>> getSourceStats() {
    return guardResult('Supabase', () async {
      final body = await _api.rpc('lead_source_stats', const {});
      return _rows(body)
          .map(
            (row) => SourceStats(
              source: LeadSourceWire.fromWire(row['source']),
              leadCount: _int(row['lead_count']),
              lastPublishedAt: _date(row['last_published_at']),
              lastSyncedAt: _date(row['last_synced_at']),
            ),
          )
          .toList();
    });
  }

  @override
  Future<Result<List<SourceSyncResult>>> synchronize(Set<LeadSource> sources) {
    return guardResult('la synchronisation', () async {
      final body = await _api.invokeFunction(
        'sync-leads',
        {
          'sources': [for (final source in sources) source.wireValue],
        },
        timeout: NetworkDefaults.syncTimeout,
      );

      final results = body is Map<String, dynamic> ? body['results'] : null;
      return _rows(results)
          .map(
            (row) => SourceSyncResult(
              source: LeadSourceWire.fromWire(row['source']),
              status: _status(row['status']),
              fetched: _int(row['fetched']),
              inserted: _int(row['inserted']),
              message: row['message'] is String ? row['message'] as String : null,
            ),
          )
          .toList();
    });
  }

  static List<Map<String, dynamic>> _rows(Object? body) {
    if (body is! List<Object?>) {
      throw const ParsingException('Liste attendue dans la réponse.');
    }
    return body.whereType<Map<String, dynamic>>().toList();
  }

  static SourceSyncStatus _status(Object? raw) => switch (raw) {
        'ok' => SourceSyncStatus.ok,
        'cooldown' => SourceSyncStatus.cooldown,
        'unsupported' => SourceSyncStatus.unsupported,
        _ => SourceSyncStatus.error,
      };

  /// PostgREST sérialise `bigint` en nombre, mais certains proxys le
  /// renvoient en chaîne pour préserver la précision.
  static int _int(Object? value) => switch (value) {
        final num n => n.toInt(),
        final String s => int.tryParse(s) ?? 0,
        _ => 0,
      };

  static DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;
}
