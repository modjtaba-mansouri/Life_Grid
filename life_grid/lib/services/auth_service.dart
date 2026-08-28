import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/firebase_config.dart';
import 'firestore_rest.dart';

class AppUser {
  final String slug;
  final String name;
  final String gender;
  final String birthday;

  AppUser({
    required this.slug,
    required this.name,
    required this.gender,
    required this.birthday,
  });
}

class AuthResult {
  final bool success;
  final String? error;
  final AppUser? user;
  AuthResult.ok(this.user)
      : success = true,
        error = null;
  AuthResult.fail(this.error)
      : success = false,
        user = null;
}

/// Handles account creation/login against Firestore. The logged-in
/// user's profile and passcode hash are cached locally so returning to
/// the app (and the "Lock After" re-entry screen) both work offline.
class AuthService {
  static const _sessionSlugKey = 'life_grid_session_slug';
  static const _sessionCacheKey = 'life_grid_session_cache';

  final FirestoreRest _db =
      FirestoreRest(projectId: FirebaseConfig.projectId, apiKey: FirebaseConfig.apiKey);

  String _slugify(String name) {
    final lower = name.trim().toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _hash(String passcode) => sha256.convert(utf8.encode(passcode)).toString();

  Future<AuthResult> signUp({
    required String name,
    required String gender,
    required String birthday,
    required String passcode,
  }) async {
    final slug = _slugify(name);
    if (slug.isEmpty) return AuthResult.fail('Enter a name.');
    if (passcode.length < 4) {
      return AuthResult.fail('Passcode must be at least 4 characters.');
    }
    Map<String, dynamic>? existing;
    try {
      existing = await _db.getDocument('users/$slug');
    } catch (_) {
      return AuthResult.fail('No internet connection — creating an account needs to be online once.');
    }
    if (existing != null) {
      return AuthResult.fail(
        'That name is already taken — try logging in instead, or pick a different name.',
      );
    }
    final passcodeHash = _hash(passcode);
    await _db.setDocument('users/$slug', {
      'name': name.trim(),
      'gender': gender,
      'birthday': birthday,
      'passcodeHash': passcodeHash,
      'createdAt': DateTime.now().toIso8601String(),
    });
    final user = AppUser(slug: slug, name: name.trim(), gender: gender, birthday: birthday);
    await _cacheSession(user, passcodeHash);
    return AuthResult.ok(user);
  }

  Future<AuthResult> logIn({required String name, required String passcode}) async {
    final slug = _slugify(name);
    final passcodeHash = _hash(passcode);

    // Offline-friendly: if this exact account is already cached on this
    // device (e.g. you logged out, or the lock screen), verify locally.
    final cached = await _readCache();
    if (cached != null && cached['slug'] == slug) {
      if (cached['passcodeHash'] == passcodeHash) {
        final user = AppUser(
          slug: slug,
          name: cached['name'] as String,
          gender: cached['gender'] as String,
          birthday: cached['birthday'] as String,
        );
        await _saveSessionSlug(slug);
        return AuthResult.ok(user);
      }
      return AuthResult.fail('Wrong passcode.');
    }

    Map<String, dynamic>? doc;
    try {
      doc = await _db.getDocument('users/$slug');
    } catch (_) {
      return AuthResult.fail('No internet connection, and no cached login on this device.');
    }
    if (doc == null) {
      return AuthResult.fail('No account with that name yet — sign up instead.');
    }
    if (doc['passcodeHash'] != passcodeHash) {
      return AuthResult.fail('Wrong passcode.');
    }
    final user = AppUser(
      slug: slug,
      name: doc['name'] as String? ?? name,
      gender: doc['gender'] as String? ?? '',
      birthday: doc['birthday'] as String? ?? '',
    );
    await _cacheSession(user, passcodeHash);
    return AuthResult.ok(user);
  }

  /// Verifies a passcode against the currently cached session, entirely
  /// offline. Used by the "Lock After" re-entry screen.
  Future<bool> verifyCurrentPasscode(String passcode) async {
    final cached = await _readCache();
    if (cached == null) return false;
    return cached['passcodeHash'] == _hash(passcode);
  }

  Future<void> _cacheSession(AppUser user, String passcodeHash) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionCacheKey,
      jsonEncode({
        'slug': user.slug,
        'name': user.name,
        'gender': user.gender,
        'birthday': user.birthday,
        'passcodeHash': passcodeHash,
      }),
    );
    await _saveSessionSlug(user.slug);
  }

  Future<void> _saveSessionSlug(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionSlugKey, slug);
  }

  Future<Map<String, dynamic>?> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionCacheKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> logOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionSlugKey);
    // Deliberately keep _sessionCacheKey so logging back in works offline.
  }

  /// Restores the logged-in user from a previous session — works
  /// offline via the local cache, no network required.
  Future<AppUser?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final slug = prefs.getString(_sessionSlugKey);
    if (slug == null) return null;
    final cached = await _readCache();
    if (cached != null && cached['slug'] == slug) {
      return AppUser(
        slug: slug,
        name: cached['name'] as String,
        gender: cached['gender'] as String,
        birthday: cached['birthday'] as String,
      );
    }
    // Cache missing but a session slug exists (shouldn't normally
    // happen) — fall back to a network fetch.
    try {
      final doc = await _db.getDocument('users/$slug');
      if (doc == null) return null;
      return AppUser(
        slug: slug,
        name: doc['name'] as String? ?? slug,
        gender: doc['gender'] as String? ?? '',
        birthday: doc['birthday'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> allUserSlugs() async {
    final docs = await _db.listDocuments('users');
    return docs.keys.toList();
  }
}
