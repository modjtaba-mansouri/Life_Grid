import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _kRequestTimeout = Duration(seconds: 12);

/// A minimal client for Firestore's REST API. Deliberately avoids the
/// official firebase_core/cloud_firestore SDKs, which require native
/// Android/iOS project configuration (google-services.json, Gradle
/// plugins, flutterfire CLI). Plain HTTPS + an API key works identically
/// on web and Android with zero platform setup.
///
/// Fill in your own values in lib/config/firebase_config.dart.
class FirestoreRest {
  final String projectId;
  final String apiKey;

  FirestoreRest({required this.projectId, required this.apiKey});

  String get _base =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  /// Fetches a single document by path (e.g. "users/john").
  /// Returns null if it doesn't exist.
  Future<Map<String, dynamic>?> getDocument(String path) async {
    final uri = Uri.parse('$_base/$path?key=$apiKey');
    final res = await http.get(uri).timeout(_kRequestTimeout);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('Firestore GET failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return _decodeFields(decoded['fields'] as Map<String, dynamic>? ?? {});
  }

  /// Creates or fully overwrites a document's fields.
  Future<void> setDocument(String path, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_base/$path?key=$apiKey');
    final body = jsonEncode({'fields': _encodeFields(data)});
    final res = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(_kRequestTimeout);
    if (res.statusCode != 200) {
      throw Exception('Firestore PATCH failed (${res.statusCode}): ${res.body}');
    }
  }

  /// Deletes a document. Succeeds silently if it didn't exist.
  Future<void> deleteDocument(String path) async {
    final uri = Uri.parse('$_base/$path?key=$apiKey');
    final res = await http.delete(uri).timeout(_kRequestTimeout);
    if (res.statusCode != 200 && res.statusCode != 404) {
      throw Exception('Firestore DELETE failed (${res.statusCode}): ${res.body}');
    }
  }

  /// Lists all documents directly in a collection (e.g. "users").
  /// Fine for small collections; paginates internally if needed.
  Future<Map<String, Map<String, dynamic>>> listDocuments(
    String collectionPath,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    String? pageToken;
    do {
      final uri = Uri.parse('$_base/$collectionPath?key=$apiKey'
          '${pageToken != null ? '&pageToken=$pageToken' : ''}&pageSize=200');
      final res = await http.get(uri).timeout(_kRequestTimeout);
      if (res.statusCode != 200) {
        throw Exception(
            'Firestore LIST failed (${res.statusCode}): ${res.body}');
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final docs = (decoded['documents'] as List<dynamic>? ?? []);
      for (final d in docs) {
        final map = d as Map<String, dynamic>;
        final name = map['name'] as String; // full resource path
        final id = name.split('/').last;
        result[id] = _decodeFields(map['fields'] as Map<String, dynamic>? ?? {});
      }
      pageToken = decoded['nextPageToken'] as String?;
    } while (pageToken != null);
    return result;
  }

  /// Fetches many documents by exact path in one request. Missing
  /// documents are simply absent from the returned map.
  Future<Map<String, Map<String, dynamic>>> batchGet(
    List<String> paths,
  ) async {
    if (paths.isEmpty) return {};
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:batchGet?key=$apiKey',
    );
    final fullPaths = paths
        .map((p) => 'projects/$projectId/databases/(default)/documents/$p')
        .toList();
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'documents': fullPaths}),
    ).timeout(_kRequestTimeout);
    if (res.statusCode != 200) {
      throw Exception(
          'Firestore batchGet failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(res.body) as List<dynamic>;
    final result = <String, Map<String, dynamic>>{};
    for (final entry in decoded) {
      final map = entry as Map<String, dynamic>;
      final found = map['found'] as Map<String, dynamic>?;
      if (found == null) continue;
      final name = found['name'] as String;
      final id = name.split('/').last;
      result[id] = _decodeFields(found['fields'] as Map<String, dynamic>? ?? {});
    }
    return result;
  }

  // ---- Firestore's typed-value encoding ----

  Map<String, dynamic> _encodeFields(Map<String, dynamic> data) {
    return data.map((k, v) => MapEntry(k, _encodeValue(v)));
  }

  Map<String, dynamic> _encodeValue(dynamic v) {
    if (v == null) return {'nullValue': null};
    if (v is String) return {'stringValue': v};
    if (v is int) return {'integerValue': v.toString()};
    if (v is double) return {'doubleValue': v};
    if (v is bool) return {'booleanValue': v};
    if (v is Map) {
      return {
        'mapValue': {
          'fields': v.map((k, val) => MapEntry(k as String, _encodeValue(val)))
        }
      };
    }
    if (v is List) {
      return {
        'arrayValue': {'values': v.map(_encodeValue).toList()}
      };
    }
    throw ArgumentError('Unsupported Firestore value type: ${v.runtimeType}');
  }

  Map<String, dynamic> _decodeFields(Map<String, dynamic> fields) {
    return fields.map((k, v) => MapEntry(k, _decodeValue(v as Map<String, dynamic>)));
  }

  dynamic _decodeValue(Map<String, dynamic> v) {
    if (v.containsKey('stringValue')) return v['stringValue'] as String;
    if (v.containsKey('integerValue')) {
      return int.parse(v['integerValue'] as String);
    }
    if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
    if (v.containsKey('booleanValue')) return v['booleanValue'] as bool;
    if (v.containsKey('nullValue')) return null;
    if (v.containsKey('mapValue')) {
      final inner = (v['mapValue'] as Map<String, dynamic>)['fields']
              as Map<String, dynamic>? ??
          {};
      return _decodeFields(inner);
    }
    if (v.containsKey('arrayValue')) {
      final values =
          (v['arrayValue'] as Map<String, dynamic>)['values'] as List<dynamic>? ??
              [];
      return values.map((e) => _decodeValue(e as Map<String, dynamic>)).toList();
    }
    return null;
  }
}
