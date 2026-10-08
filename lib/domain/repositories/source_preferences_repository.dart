import '../entities/lead.dart';

/// Préférences d'activation des sources, partagées entre l'écran Sources
/// (écriture) et le Chat (lecture) sans couplage direct entre leurs BLoCs.
abstract interface class SourcePreferencesRepository {
  Future<Set<LeadSource>> getEnabledSources();

  Future<void> setSourceEnabled(LeadSource source, {required bool enabled});
}
