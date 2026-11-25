/// Where the login key lives. On the web this is `web/emekey.js` (WebCrypto + IndexedDB, same scheme as the EME
/// pages). Anything else (tests, other platforms) uses an in-memory fake until native key storage is added.
abstract class KeyStore {
  bool get supported;

  /// Creates a key pair, keeps the private half, returns the base64url X.509 public key.
  Future<NewKey> createKey();

  /// The server accepted the public key: make the pending key the login key.
  Future<void> commit(String userId, String keyId);

  /// {userid, keyid} of the stored login key, or null.
  Future<({String userId, String keyId})?> current();

  /// Signature headers for a request: X-tokentype / X-token, or {} without a key.
  Future<Map<String, String>> headers();

  Future<void> forgetSignature();
  Future<void> clear();
}

class NewKey {
  const NewKey(this.alg, this.publicKey);
  final String alg;
  final String publicKey;
}
