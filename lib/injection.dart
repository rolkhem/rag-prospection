import 'package:get_it/get_it.dart';

import 'core/config/env_config.dart';
import 'core/network/json_http_client.dart';
import 'data/datasources/supabase_api.dart';
import 'data/repositories/gemini_embedding_repository.dart';
import 'data/repositories/gemini_llm_repository.dart';
import 'data/repositories/shared_prefs_source_preferences_repository.dart';
import 'data/repositories/supabase_lead_ingestion_repository.dart';
import 'data/repositories/supabase_vector_store_repository.dart';
import 'domain/repositories/embedding_repository.dart';
import 'domain/repositories/lead_ingestion_repository.dart';
import 'domain/repositories/llm_repository.dart';
import 'domain/repositories/source_preferences_repository.dart';
import 'domain/repositories/vector_store_repository.dart';
import 'domain/usecases/query_rag_usecase.dart';
import 'presentation/blocs/chat/chat_bloc.dart';
import 'presentation/blocs/sources/sources_bloc.dart';

final GetIt getIt = GetIt.instance;

/// Seul endroit où les implémentations concrètes sont choisies : passer de
/// Supabase à un autre vector store ne touche que ce fichier et `data/`.
void configureDependencies(EnvConfig config) {
  getIt
    // Un seul client HTTP : réutilise les connexions keep-alive entre les
    // appels Gemini et Supabase d'une même requête RAG.
    ..registerLazySingleton<JsonHttpClient>(JsonHttpClient.new, dispose: (c) => c.close())
    ..registerLazySingleton<SupabaseApi>(
      () => SupabaseApi(
        baseUrl: config.supabaseUrl,
        anonKey: config.supabaseAnonKey,
        client: getIt(),
      ),
    )
    ..registerLazySingleton<EmbeddingRepository>(
      () => GeminiEmbeddingRepository(
        client: getIt(),
        apiKey: config.geminiApiKey,
        model: config.geminiEmbeddingModel,
      ),
    )
    ..registerLazySingleton<LlmRepository>(
      () => GeminiLlmRepository(
        client: getIt(),
        apiKey: config.geminiApiKey,
        model: config.geminiChatModel,
      ),
    )
    ..registerLazySingleton<VectorStoreRepository>(() => SupabaseVectorStoreRepository(getIt()))
    ..registerLazySingleton<LeadIngestionRepository>(() => SupabaseLeadIngestionRepository(getIt()))
    ..registerLazySingleton<SourcePreferencesRepository>(SharedPrefsSourcePreferencesRepository.new)
    ..registerLazySingleton<QueryRagUseCase>(
      () => QueryRagUseCase(
        embeddingRepository: getIt(),
        vectorStoreRepository: getIt(),
        llmRepository: getIt(),
      ),
    )
    // Factories : la durée de vie des BLoCs est gérée par leur BlocProvider.
    ..registerFactory<ChatBloc>(
      () => ChatBloc(queryRag: getIt(), sourcePreferences: getIt()),
    )
    ..registerFactory<SourcesBloc>(
      () => SourcesBloc(sourcePreferences: getIt(), ingestion: getIt()),
    );
}
