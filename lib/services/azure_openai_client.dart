import 'dart:convert';

import 'package:http/http.dart' as http;

import '../reliability/reliable_api_caller.dart';
import 'verification_service.dart';

/// Minimal Azure OpenAI chat-completions client used as the critic model
/// (GPT-4o-mini deployment). Text-only, JSON-mode, small prompts — fast
/// (~1-2s) and cheap (~\$0.0003-0.0005 per verification).
///
/// Credentials come from --dart-define, never committed:
///   AZURE_OPENAI_ENDPOINT   e.g. https://myresource.openai.azure.com
///   AZURE_OPENAI_KEY
///   AZURE_OPENAI_DEPLOYMENT defaults to gpt-4o-mini
class AzureOpenAIClient implements CriticModel {
  AzureOpenAIClient({
    required this.endpoint,
    required this.apiKey,
    this.deployment = 'gpt-4o-mini',
    this.apiVersion = '2024-06-01',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String endpoint;
  final String apiKey;
  final String deployment;
  final String apiVersion;
  final http.Client _http;

  @override
  bool get isConfigured => endpoint.isNotEmpty && apiKey.isNotEmpty;

  Uri get _chatUri => Uri.parse(
      '$endpoint/openai/deployments/$deployment/chat/completions?api-version=$apiVersion');

  @override
  Future<String?> chat(String prompt, {bool jsonMode = true}) async {
    final response = await ReliableApiCaller.callWithRetry(() async {
      final res = await _http.post(
        _chatUri,
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
        },
        body: jsonEncode({
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          if (jsonMode) 'response_format': {'type': 'json_object'},
          'temperature': 0,
          'max_tokens': 300,
        }),
      );
      if (res.statusCode != 200) {
        throw http.ClientException(
            'Azure OpenAI returned ${res.statusCode}', _chatUri);
      }
      return res;
    });

    final decoded = jsonDecode(response.body);
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    return choices.first['message']?['content'] as String?;
  }

  /// Lightweight connectivity/auth probe for the launch health check —
  /// a 1-token completion, not a full analysis.
  Future<bool> healthCheck() async {
    try {
      final res = await _http
          .post(
            _chatUri,
            headers: {'Content-Type': 'application/json', 'api-key': apiKey},
            body: jsonEncode({
              'messages': [
                {'role': 'user', 'content': 'ping'},
              ],
              'max_tokens': 1,
            }),
          )
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
