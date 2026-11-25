import 'dart:convert';
import 'dart:js_interop';

import 'key_store_base.dart';

export 'key_store_base.dart';

@JS('emeKey')
extension type _EmeKey._(JSObject _) implements JSObject {
  external bool supported();
  external JSPromise<JSString> createKey();
  external JSPromise<JSBoolean> commit(String userId, String keyId);
  external JSPromise<JSString> current();
  external JSPromise<JSString> headers();
  external JSPromise<JSAny?> forgetSignature();
  external JSPromise<JSAny?> clear();
}

@JS('emeKey')
external _EmeKey? get _emeKey;

KeyStore createKeyStore() => _WebKeyStore();

class _WebKeyStore implements KeyStore {
  _EmeKey get _k {
    final k = _emeKey;
    if (k == null) {
      throw StateError('emekey.js is not loaded (see web/index.html)');
    }
    return k;
  }

  @override
  bool get supported => _emeKey?.supported() ?? false;

  @override
  Future<NewKey> createKey() async {
    final j = jsonDecode(
      (await _k.createKey().toDart).toDart,
    ) as Map<String, dynamic>;
    return NewKey(j['alg'] as String, j['publickey'] as String);
  }

  @override
  Future<void> commit(String userId, String keyId) async {
    await _k.commit(userId, keyId).toDart;
  }

  @override
  Future<({String userId, String keyId})?> current() async {
    final s = (await _k.current().toDart).toDart;
    if (s.isEmpty) return null;
    final j = jsonDecode(s) as Map<String, dynamic>;
    return (userId: j['userid'] as String, keyId: j['keyid'] as String);
  }

  @override
  Future<Map<String, String>> headers() async {
    final j =
        jsonDecode((await _k.headers().toDart).toDart) as Map<String, dynamic>;
    return j.map((k, v) => MapEntry(k, v as String));
  }

  @override
  Future<void> forgetSignature() async {
    await _k.forgetSignature().toDart;
  }

  @override
  Future<void> clear() async {
    await _k.clear().toDart;
  }
}
