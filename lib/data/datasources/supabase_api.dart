import '../../core/constants/app_constants.dart';
import '../../core/network/json_http_client.dart';

/// Accès REST à Supabase (RPC PostgREST et Edge Functions) sans le SDK
/// `supabase_flutter` : l'app n'utilise ni l'auth ni le realtime, et le
/// client HTTP partagé suffit.
class SupabaseApi {
  SupabaseApi({
    required Uri baseUrl,
    required String anonKey,
    required JsonHttpClient client,
  })  : _baseUrl = baseUrl,
        _client = client,
        _headers = {
          'apikey': anonKey,
          // Les anciennes clés anon sont des JWT et doivent aussi être
          // passées en Bearer ; les nouvelles clés publishable
          // (`sb_publishable_…`) ne sont pas des JWT et y seraient rejetées.
          if (anonKey.startsWith('eyJ')) 'Authorization': 'Bearer $anonKey',
        };

  final Uri _baseUrl;
  final JsonHttpClient _client;
  final Map<String, String> _headers;

  Future<Object?> rpc(String function, Map<String, Object?> params) {
    return _client.postJson(
      _baseUrl.resolve('/rest/v1/rpc/$function'),
      body: params,
      headers: _headers,
    );
  }

  Future<Object?> invokeFunction(
    String function,
    Map<String, Object?> body, {
    Duration timeout = NetworkDefaults.requestTimeout,
  }) {
    return _client.postJson(
      _baseUrl.resolve('/functions/v1/$function'),
      body: body,
      headers: _headers,
      timeout: timeout,
    );
  }
}
