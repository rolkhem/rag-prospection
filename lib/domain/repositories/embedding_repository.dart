import '../../core/utils/result.dart';

/// Transforme un texte en vecteur dense.
///
/// L'implémentation DOIT utiliser le même modèle d'embedding que le pipeline
/// d'ingestion : des vecteurs issus de modèles différents ne sont pas
/// comparables et la similarité cosinus devient aléatoire.
abstract interface class EmbeddingRepository {
  Future<Result<List<double>>> embedQuery(String text);
}
