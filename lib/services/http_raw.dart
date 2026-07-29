import 'package:http/http.dart' as http;

/// 按 method 分发原始请求（从 http_client 抽取）。
/// 不注入认证头，由调用方（rawRequest）自行处理 401；
/// 复用统一重试与超时能力。行为与原 _sendRaw 完全一致。
Future<http.Response> sendRawRequest(
  http.Client client,
  String method,
  String url,
  Map<String, String>? headers,
  String? body,
) {
  final uri = Uri.parse(url);
  switch (method.toUpperCase()) {
    case 'POST':
      return client.post(uri, headers: headers, body: body);
    case 'PUT':
      return client.put(uri, headers: headers, body: body);
    case 'PATCH':
      return client.patch(uri, headers: headers, body: body);
    case 'DELETE':
      return client.delete(uri, headers: headers);
    default:
      return client.get(uri, headers: headers);
  }
}
