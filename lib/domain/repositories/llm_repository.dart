import '../../core/utils/result.dart';

/// Génération de texte par un LLM (Gemini, OpenAI, Anthropic…).
///
/// Instruction système et prompt utilisateur sont séparés pour exploiter le
/// canal `system` natif des fournisseurs : les consignes y sont moins
/// sensibles aux injections contenues dans les documents récupérés.
abstract interface class LlmRepository {
  Future<Result<String>> generate({
    required String systemInstruction,
    required String userPrompt,
  });
}
