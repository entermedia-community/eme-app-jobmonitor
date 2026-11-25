import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'key_store.dart';

class AuthUser {
  const AuthUser({required this.id, this.name, this.email});
  final String id;
  final String? name;
  final String? email;

  String get initials {
    final src = (name?.trim().isNotEmpty ?? false) ? name! : id;
    final parts = src.trim().split(RegExp(r'\s+'));
    final s = parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'
        : src.substring(0, src.length.clamp(0, 2));
    return s.toUpperCase();
  }
}

enum AuthError { noUser, sendFailed, noSecureKeys, badCode }

/// Auth failure as a code; the UI turns it into localized text (see LoginPage). [detail] is a server-provided
/// message or HTTP status when there is one.
class AuthException implements Exception {
  AuthException(this.error, {this.detail});
  final AuthError error;
  final String? detail;
  @override
  String toString() =>
      'AuthException($error${detail == null ? '' : ', $detail'})';
}

/// Key-signature login against EME (`/services/authentication/*`).
///
///   sendusercode.json  email            -> emails a 6-digit code
///   token.json         grant_type=otp + publickey -> redeems the code AND registers this device's public key
///   (every later request)  X-tokentype: signature + X-token: {username,key_id,timestamp,nonce,signature}
///
/// No password, no cookie, no stored bearer token: the private key stays in the browser (see web/emekey.js).
class AuthService extends ChangeNotifier {
  AuthService({
    KeyStore? keys,
    http.Client? client,
    String? baseUrl,
    String? appPath,
  }) : keys = keys ?? createKeyStore(),
       _client = client ?? http.Client(),
       _root =
           '${baseUrl ?? AppConfig.emeBaseUrl}${appPath ?? AppConfig.emeAppPath}';

  final KeyStore keys;
  final http.Client _client;
  final String _root;

  AuthUser? user;
  bool restoring = true;
  bool get signedIn => user != null;

  Uri _url(String path) => Uri.parse('$_root/services/$path');

  /// Called once at start: a stored key counts as signed in if the server still accepts its signature.
  Future<void> restore() async {
    try {
      final cur = await keys.current();
      if (cur != null) {
        final res = await signedGet('authentication/user.json');
        if (res.statusCode == 200) {
          final j = _json(res.body);
          user = _userFrom(j['user'] ?? j) ?? AuthUser(id: cur.userId);
        } else if (res.statusCode == 401 || res.statusCode == 403) {
          await keys.clear();
        }
      }
    } catch (_) {
      // Server down or CORS not open yet: stay on the login form, keep the key for the next try.
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> requestCode(String email) async {
    final res = await _client.post(
      _url('authentication/sendusercode.json'),
      headers: {'Accept': 'application/json'},
      body: {'email': email.trim()},
    );
    final r = (_json(res.body)['response'] as Map?) ?? const {};
    switch (r['status']) {
      case 'ok':
        return;
      case 'nouser':
        throw AuthException(AuthError.noUser);
      default:
        throw AuthException(
          AuthError.sendFailed,
          detail: r['error']?.toString() ?? '${res.statusCode}',
        );
    }
  }

  Future<void> loginWithCode(String email, String code) async {
    if (!keys.supported) {
      throw AuthException(AuthError.noSecureKeys);
    }
    final key = await keys.createKey();
    final res = await _client.post(
      _url('authentication/token.json'),
      headers: {'Accept': 'application/json'},
      body: {
        'grant_type': 'otp',
        'email': email.trim(),
        'code': code.trim(),
        'publickey': key.publicKey,
        'label': 'Fulservice app',
      },
    );
    final j = _json(res.body);
    final u = _userFrom(j['user']);
    final keyId = j['key_id']?.toString();
    if (res.statusCode != 200 || u == null || keyId == null) {
      throw AuthException(
        AuthError.badCode,
        detail: (j['error_description'] ?? j['error'])?.toString(),
      );
    }
    await keys.commit(u.id, keyId);
    user = u;
    notifyListeners();
  }

  /// Headers (X-tokentype / X-token) to attach to any EME request; {} when signed out.
  Future<Map<String, String>> authHeaders() => keys.headers();

  /// Another service got a 401: the server no longer accepts our key.
  Future<void> handleUnauthorized() async {
    if (user == null) return;
    await keys.clear();
    user = null;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      final cur = await keys.current();
      if (cur != null) {
        await signedPost('authentication/revokekey.json', {'keyid': cur.keyId});
      }
    } catch (_) {}
    await keys.clear();
    user = null;
    notifyListeners();
  }

  /// Signed requests. A 401 means the server no longer accepts our key: sign out.
  Future<http.Response> signedGet(String path, {Map<String, String>? query}) =>
      _send(
        () async => _client.get(
          _url(path).replace(queryParameters: query),
          headers: {'Accept': 'application/json', ...await keys.headers()},
        ),
      );

  Future<http.Response> signedPost(
    String path,
    Object body, {
    bool json = false,
  }) => _send(
    () async => _client.post(
      _url(path),
      headers: {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        ...await keys.headers(),
      },
      body: json ? jsonEncode(body) : body,
    ),
  );

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    final res = await call();
    if (res.statusCode == 401 && user != null) {
      await keys.clear();
      user = null;
      notifyListeners();
    }
    return res;
  }

  Map<String, dynamic> _json(String body) {
    try {
      final d = jsonDecode(body);
      return d is Map<String, dynamic> ? d : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  AuthUser? _userFrom(Object? o) {
    if (o is! Map || o['id'] == null) return null;
    final name = [
      o['firstname'],
      o['lastname'],
    ].where((x) => x != null && '$x'.isNotEmpty).join(' ');
    return AuthUser(
      id: '${o['id']}',
      name: name.isEmpty ? o['screenname']?.toString() : name,
      email: o['email']?.toString(),
    );
  }
}
