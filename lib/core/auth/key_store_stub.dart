import 'key_store_base.dart';

export 'key_store_base.dart';

/// Non-web fallback: no real signing. Used by tests (inject a fake) and keeps the app compiling off the web.
KeyStore createKeyStore() => _UnsupportedKeyStore();

class _UnsupportedKeyStore implements KeyStore {
  @override
  bool get supported => false;
  @override
  Future<NewKey> createKey() => Future.error(
    UnsupportedError('Key login needs the web build (WebCrypto).'),
  );
  @override
  Future<void> commit(String userId, String keyId) async {}
  @override
  Future<({String userId, String keyId})?> current() async => null;
  @override
  Future<Map<String, String>> headers() async => {};
  @override
  Future<void> forgetSignature() async {}
  @override
  Future<void> clear() async {}
}
