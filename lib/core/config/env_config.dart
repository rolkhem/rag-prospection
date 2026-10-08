import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../errors/exceptions.dart';

/// Configuration runtime chargée depuis `.env` via `flutter_dotenv`.
///
/// Le chargement échoue immédiatement au démarrage si une variable obligatoire
/// manque : mieux vaut un crash explicite qu'un 401 opaque au premier message.
///
/// Le `.env` est embarqué dans l'APK : il ne doit contenir que des clés
/// conçues pour être publiques (clé anon / publishable Supabase). La clé
/// Gemini l'est pour le prototype uniquement, voir README.
final class EnvConfig {
  const EnvConfig._({
    required this.geminiApiKey,
    required this.geminiChatModel,
    required this.geminiEmbeddingModel,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final String geminiApiKey;
  final String geminiChatModel;
  final String geminiEmbeddingModel;
  final Uri supabaseUrl;
  final String supabaseAnonKey;

  static Future<EnvConfig> load({String fileName = '.env'}) async {
    try {
      await dotenv.load(fileName: fileName);
    } catch (_) {
      // flutter_dotenv lève des `Error` (fichier absent, vide) et non des
      // `Exception` : on les ramène au type géré par l'écran d'erreur.
      throw ConfigurationException(
        'Fichier $fileName introuvable ou vide. Copiez .env.example en .env et renseignez-le.',
      );
    }

    final rawUrl = _require('SUPABASE_URL');
    final supabaseUrl = Uri.tryParse(rawUrl);
    if (supabaseUrl == null || supabaseUrl.scheme != 'https' || supabaseUrl.host.isEmpty) {
      throw const ConfigurationException(
        'SUPABASE_URL doit être une URL https valide.',
      );
    }

    return EnvConfig._(
      geminiApiKey: _require('GEMINI_API_KEY'),
      geminiChatModel: _optional('GEMINI_CHAT_MODEL', 'gemini-3.5-flash'),
      geminiEmbeddingModel: _optional('GEMINI_EMBEDDING_MODEL', 'gemini-embedding-001'),
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: _require('SUPABASE_ANON_KEY'),
    );
  }

  static String _require(String key) {
    final value = dotenv.maybeGet(key)?.trim();
    if (value == null || value.isEmpty) {
      throw ConfigurationException('Variable d\'environnement manquante : $key');
    }
    return value;
  }

  static String _optional(String key, String fallback) {
    final value = dotenv.maybeGet(key)?.trim();
    return (value == null || value.isEmpty) ? fallback : value;
  }
}
