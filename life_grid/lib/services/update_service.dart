import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_version.dart';

class UpdateCheckResult {
  final bool checkFailed;
  final bool updateAvailable;
  final String currentVersion;
  final String? latestVersion;
  UpdateCheckResult({
    required this.checkFailed,
    required this.updateAvailable,
    required this.currentVersion,
    this.latestVersion,
  });
}

/// Checks a small version.json file published alongside the web build
/// (so it's always in sync with whatever CI last deployed) against the
/// version baked into this running app.
class UpdateService {
  static const _versionUrl = 'https://modjtaba-mansouri.github.io/Life_Grid/version.json';
  static const _releasesUrl = 'https://github.com/modjtaba-mansouri/Life_Grid/releases/latest';

  String get releasesUrl => _releasesUrl;

  Future<UpdateCheckResult> check() async {
    try {
      final res = await http.get(Uri.parse(_versionUrl)).timeout(Duration(seconds: 10));
      if (res.statusCode != 200) {
        return UpdateCheckResult(checkFailed: true, updateAvailable: false, currentVersion: kAppVersion);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = data['version'] as String?;
      if (latest == null) {
        return UpdateCheckResult(checkFailed: true, updateAvailable: false, currentVersion: kAppVersion);
      }
      return UpdateCheckResult(
        checkFailed: false,
        updateAvailable: _isNewer(latest, kAppVersion),
        currentVersion: kAppVersion,
        latestVersion: latest,
      );
    } catch (_) {
      return UpdateCheckResult(checkFailed: true, updateAvailable: false, currentVersion: kAppVersion);
    }
  }

  /// Simple numeric version comparison (e.g. "2.10.0" > "2.9.4").
  bool _isNewer(String a, String b) {
    final partsA = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final partsB = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final len = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (var i = 0; i < len; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va > vb;
    }
    return false;
  }
}
