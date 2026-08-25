import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/firebase_config.dart';
import 'firestore_rest.dart';

class AppUser {
  final String slug; // Firestore doc id, also used to scope entries
  final String name;
  final String gender;
  final String birthday; // as entered, e.g. "18/05/2001"

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

/// Handles account creation/login against Firestore, and remembers the
/// logged-in user locally so they don't have to log in every launch.
class AuthService {
  static const _sessionSlugKey = 'life_grid_session_slug';

  final FirestoreRest _db =
      FirestoreRest(projectId: FirebaseConfig.projectId, apiKey: FirebaseConfig.apiKey);

  String _slugify(String name) {
    final lower = name.trim().toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _hash(String passcode) {
    return sha256.convert(utf8.encode(passcode)).toString();
  }

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
    final existing = await _db.getDocument('users/$slug');
    if (existing != null) {
      return AuthResult.fail(
        'That name is already taken — try logging in instead, or pick a different name.',
      );
    }
    await _db.setDocument('users/$slug', {
      'name': name.trim(),
      'gender': gender,
      'birthday': birthday,
      'passcodeHash': _hash(passcode),
      'createdAt': DateTime.now().toIso8601String(),
    });
    final user = AppUser(slug: slug, name: name.trim(), gender: gender, birthday: birthday);
    await _saveSession(slug);
    return AuthResult.ok(user);
  }

  Future<AuthResult> logIn({required String name, required String passcode}) async {
    final slug = _slugify(name);
    final doc = await _db.getDocument('users/$slug');
    if (doc == null) {
      return AuthResult.fail('No account with that name yet — sign up instead.');
    }
    if (doc['passcodeHash'] != _hash(passcode)) {
      return AuthResult.fail('Wrong passcode.');
    }
    final user = AppUser(
      slug: slug,
      name: doc['name'] as String? ?? name,
      gender: doc['gender'] as String? ?? '',
      birthday: doc['birthday'] as String? ?? '',
    );
    await _saveSession(slug);
    return AuthResult.ok(user);
  }

  Future<void> _saveSession(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionSlugKey, slug);
  }

  Future<void> logOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionSlugKey);
  }

  /// Restores the logged-in user from a previous session, if any.
  Future<AppUser?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final slug = prefs.getString(_sessionSlugKey);
    if (slug == null) return null;
    final doc = await _db.getDocument('users/$slug');
    if (doc == null) return null;
    return AppUser(
      slug: slug,
      name: doc['name'] as String? ?? slug,
      gender: doc['gender'] as String? ?? '',
      birthday: doc['birthday'] as String? ?? '',
    );
  }

  /// All known users (for computing the "everyone" average). Small
  /// personal-scale app, so a full list is fine.
  Future<List<String>> allUserSlugs() async {
    final docs = await _db.listDocuments('users');
    return docs.keys.toList();
  }
}
