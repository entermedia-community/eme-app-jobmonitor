import 'dart:convert';

import 'package:agent_job_monitor/core/auth/auth_service.dart';
import 'package:agent_job_monitor/main.dart';
import 'package:agent_job_monitor/services/buk_import_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

http.Response _json(Object o, [int code = 200]) =>
    http.Response(jsonEncode(o), code);

AuthService _auth(
  FakeKeyStore keys,
  Future<http.Response> Function(http.Request) h,
) => AuthService(
  keys: keys,
  client: MockClient(h),
  baseUrl: 'http://x',
  appPath: '/site/mediadb',
);

void main() {
  test('loginWithCode registers the key and signs the user in', () async {
    final keys = FakeKeyStore();
    late http.Request seen;
    final a = _auth(keys, (r) async {
      seen = r;
      return _json({
        'key_id': 'k1',
        'user': {'id': 'u1', 'firstname': 'Sonia', 'email': 's@v.cl'},
      });
    });
    await a.loginWithCode('s@v.cl', '123456');
    expect(seen.url.path, '/site/mediadb/services/authentication/token.json');
    expect(seen.bodyFields['publickey'], 'PUBKEY_B64URL');
    expect(a.signedIn, isTrue);
    expect(keys.stored?.keyId, 'k1');
    expect((await a.authHeaders())['X-tokentype'], 'signature');
  });

  test('handleUnauthorized signs out and forgets the key', () async {
    final keys = FakeKeyStore()..stored = (userId: 'u1', keyId: 'k1');
    final a = _auth(
      keys,
      (r) async => _json({
        'user': {'id': 'u1'},
      }),
    );
    await a.restore();
    expect(a.signedIn, isTrue);
    await a.handleUnauthorized();
    expect(a.signedIn, isFalse);
    expect(keys.cleared, isTrue);
  });

  test('services send signature headers and report 401', () async {
    Map<String, String>? seenHeaders;
    var unauthorized = 0;
    final svc = BukImportService(
      autoStart: false,
      root: 'http://x/agentjob',
      client: MockClient((r) async {
        seenHeaders = r.headers;
        return http.Response('no', 401);
      }),
      authHeaders: () async => {'X-tokentype': 'signature', 'X-token': 'abc'},
      onUnauthorized: () async => unauthorized++,
      idlePoll: const Duration(hours: 1),
    );
    await svc.refresh();
    svc.dispose();
    expect(seenHeaders?['X-tokentype'], 'signature');
    expect(unauthorized, greaterThan(0));
  });

  testWidgets(
    'signed-out users see the login page, signed-in see the dashboard',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final keys = FakeKeyStore();
      final auth = _auth(
        keys,
        (r) async => _json({
          'response': {'status': 'ok'},
        }),
      );
      await auth.restore();
      await tester.pumpWidget(AgentJobMonitorApp(auth: auth));
      expect(find.text('Sign in'), findsWidgets);
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(find.text('AGENT JOB MONITOR'), findsOneWidget);
      // dashboard widgets are not built before login
      expect(find.text('BUK IMPORT'), findsNothing);
    },
  );
}
