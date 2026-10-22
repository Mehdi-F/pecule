import 'dart:async';
import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

import '../text_utils.dart';

class EbException implements Exception {
  final String message;
  final int? status;
  const EbException(this.message, {this.status});

  /// Session expirée ou révoquée : il faut se reconnecter à la banque.
  bool get needsReconnect => status == 401 || status == 403 || status == 422;

  @override
  String toString() => message;
}

/// Client minimal de l'API Enable Banking (DSP2), appelé directement depuis le téléphone.
class EbClient {
  static const String baseUrl = 'https://api.enablebanking.com';
  final String appId;
  final String pem;

  EbClient(this.appId, this.pem);

  /// Vérifie que la clé privée est lisible (lève une EbException sinon).
  static void validateKey(String pem) {
    try {
      RSAPrivateKey(pem);
    } catch (_) {
      throw const EbException('Clé privée illisible : choisis le fichier .pem téléchargé à la création de l\'application.');
    }
  }

  String _token() {
    final jwt = JWT(
      {'iss': 'enablebanking.com', 'aud': 'api.enablebanking.com'},
      header: {'kid': appId},
    );
    return jwt.sign(RSAPrivateKey(pem), algorithm: JWTAlgorithm.RS256, expiresIn: const Duration(hours: 1));
  }

  Future<dynamic> _req(String method, String path, {Map<String, String>? query, Object? body}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = {
      'Authorization': 'Bearer ${_token()}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    http.Response r;
    try {
      final Future<http.Response> f;
      switch (method) {
        case 'POST':
          f = http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
        case 'DELETE':
          f = http.delete(uri, headers: headers);
        default:
          f = http.get(uri, headers: headers);
      }
      r = await f.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const EbException('La banque ne répond pas, réessaie dans un moment.');
    } catch (e) {
      throw EbException('Connexion impossible ($e).');
    }
    final text = utf8.decode(r.bodyBytes);
    if (r.statusCode >= 400) {
      var detail = text;
      try {
        final j = jsonDecode(text);
        if (j is Map) detail = (j['message'] ?? j['detail'] ?? j['error'] ?? text).toString();
      } catch (_) {}
      if (detail.length > 300) detail = '${detail.substring(0, 300)}…';
      throw EbException('Erreur ${r.statusCode} : $detail', status: r.statusCode);
    }
    if (text.trim().isEmpty) return null;
    return jsonDecode(text);
  }

  List<Map<String, dynamic>> _list(dynamic j, String key) =>
      j is Map && j[key] is List ? (j[key] as List).whereType<Map<String, dynamic>>().toList() : const [];

  Future<List<Map<String, dynamic>>> aspsps(String country) async =>
      _list(await _req('GET', '/aspsps', query: {'country': country}), 'aspsps');

  /// Démarre l'autorisation : renvoie l'URL de la banque à ouvrir.
  Future<String> startAuth({
    required String aspspName,
    required String country,
    required DateTime validUntil,
    required String redirectUrl,
    required String state,
  }) async {
    final j = await _req('POST', '/auth', body: {
      'access': {'valid_until': validUntil.toUtc().toIso8601String()},
      'aspsp': {'name': aspspName, 'country': country},
      'state': state,
      'redirect_url': redirectUrl,
      'psu_type': 'personal',
    });
    final url = j is Map ? j['url'] as String? : null;
    if (url == null) throw const EbException('Réponse inattendue de Enable Banking (pas d\'URL d\'autorisation).');
    return url;
  }

  Future<Map<String, dynamic>> createSession(String code) async {
    final j = await _req('POST', '/sessions', body: {'code': code});
    if (j is! Map<String, dynamic>) throw const EbException('Réponse inattendue à la création de session.');
    return j;
  }

  Future<void> deleteSession(String sessionId) async {
    await _req('DELETE', '/sessions/$sessionId');
  }

  Future<List<Map<String, dynamic>>> transactions(String accountUid, DateTime from) async {
    final out = <Map<String, dynamic>>[];
    String? cont;
    var pages = 0;
    do {
      final q = {'date_from': ymd(from)};
      if (cont != null) q['continuation_key'] = cont;
      final j = await _req('GET', '/accounts/$accountUid/transactions', query: q);
      out.addAll(_list(j, 'transactions'));
      cont = j is Map ? j['continuation_key'] as String? : null;
      if (cont != null && cont.isEmpty) cont = null;
    } while (cont != null && ++pages < 60);
    return out;
  }

  Future<List<Map<String, dynamic>>> balances(String accountUid) async =>
      _list(await _req('GET', '/accounts/$accountUid/balances'), 'balances');
}
