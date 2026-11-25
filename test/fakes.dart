import 'package:agent_job_monitor/core/auth/key_store_base.dart';

/// In-memory KeyStore: records what the app asks of the browser key, signs nothing.
class FakeKeyStore implements KeyStore {
  FakeKeyStore({this.canSign = true});
  final bool canSign;
  ({String userId, String keyId})? stored;
  bool cleared = false;

  @override
  bool get supported => canSign;
  @override
  Future<NewKey> createKey() async => const NewKey('Ed25519', 'PUBKEY_B64URL');
  @override
  Future<void> commit(String userId, String keyId) async =>
      stored = (userId: userId, keyId: keyId);
  @override
  Future<({String userId, String keyId})?> current() async => stored;
  @override
  Future<Map<String, String>> headers() async => stored == null
      ? {}
      : {
          'X-tokentype': 'signature',
          'X-token':
              '{"username":"${stored!.userId}","key_id":"${stored!.keyId}"}',
        };
  @override
  Future<void> forgetSignature() async {}
  @override
  Future<void> clear() async {
    stored = null;
    cleared = true;
  }
}
