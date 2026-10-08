import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/lead.dart';
import '../../domain/repositories/source_preferences_repository.dart';
import '../models/lead_model.dart';

/// Persiste les sources DÉSACTIVÉES plutôt que les sources actives : une
/// source ajoutée dans une future version sera ainsi active par défaut.
class SharedPrefsSourcePreferencesRepository implements SourcePreferencesRepository {
  SharedPrefsSourcePreferencesRepository({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const String _disabledKey = 'sources.disabled';

  @override
  Future<Set<LeadSource>> getEnabledSources() async {
    final disabled = await _readDisabled();
    return LeadSource.values.where((source) => !disabled.contains(source)).toSet();
  }

  @override
  Future<void> setSourceEnabled(LeadSource source, {required bool enabled}) async {
    final disabled = await _readDisabled();
    if (enabled) {
      disabled.remove(source);
    } else {
      disabled.add(source);
    }
    await _preferences.setStringList(
      _disabledKey,
      [for (final s in disabled) s.wireValue],
    );
  }

  Future<Set<LeadSource>> _readDisabled() async {
    final raw = await _preferences.getStringList(_disabledKey) ?? const <String>[];
    final disabled = <LeadSource>{};
    for (final value in raw) {
      // Une valeur inconnue (source retirée) est ignorée plutôt que de
      // bloquer la lecture des préférences.
      for (final source in LeadSource.values) {
        if (source.wireValue == value) disabled.add(source);
      }
    }
    return disabled;
  }
}
