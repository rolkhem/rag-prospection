abstract final class AppRoutes {
  static const String chat = '/';
  static const String sources = '/sources';
}

/// Paramètres par défaut du pipeline RAG.
///
/// `minSimilarity` à 0.65 : en dessous, les embeddings Gemini remontent
/// surtout du bruit thématique (même secteur, besoin différent), ce qui pousse
/// le LLM à « qualifier » des leads hors sujet.
abstract final class RagDefaults {
  static const int topK = 6;
  static const double minSimilarity = 0.65;
  static const int maxQuestionLength = 1000;
  static const int maxContextChars = 12000;
  static const int maxCharsPerDocument = 3000;
}

/// Doit rester identique à la colonne `vector(768)` de la migration Supabase
/// et à `EMBEDDING_DIMENSIONS` de l'Edge Function `sync-leads`.
abstract final class EmbeddingDefaults {
  static const int dimensions = 768;
}

abstract final class NetworkDefaults {
  /// Une génération Gemini sur 12 000 caractères de contexte dépasse
  /// régulièrement 20 s : un délai plus court produirait de faux échecs.
  static const Duration requestTimeout = Duration(seconds: 45);

  /// La synchronisation enchaîne appels aux API publiques et embeddings.
  static const Duration syncTimeout = Duration(seconds: 150);
}
