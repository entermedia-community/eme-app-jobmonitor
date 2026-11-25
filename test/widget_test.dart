import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:agent_job_monitor/main.dart';
import 'package:agent_job_monitor/models/job_model.dart';
import 'package:agent_job_monitor/services/buk_import_service.dart';
import 'package:agent_job_monitor/services/job_service.dart';

MockClient _client({
  bool running = false,
  int importStatus = 200,
  String source = 'buk',
}) {
  return MockClient((http.Request req) async {
    final p = req.url.path;
    if (p.endsWith('$source/import.json')) {
      return http.Response(
        json.encode({'ok': importStatus == 200}),
        importStatus,
      );
    }
    if (p.endsWith('$source/status.json')) {
      return http.Response(
        json.encode({
          'configured': true,
          'jobExists': true,
          'running': running,
          'repeatPeriod': 'daily',
          'repeatTime': '03:00',
          'lastRun': {
            'id': '$source-1',
            'status': 'success',
            'startedAt': '2026-11-19T03:00:00+00:00',
            'recordsRead': 10,
            'recordsWritten': 10,
            'recordsRejected': 0,
          },
        }),
        200,
      );
    }
    if (p.endsWith('$source/runs.json')) {
      return http.Response(json.encode({'results': []}), 200);
    }
    return http.Response(
      json.encode({
        'results': [
          {
            'type': 'info',
            'log': 'Page 1 imported',
            'timestamp': '1763500000000',
          },
        ],
      }),
      200,
    );
  });
}

Future<void> _pump(WidgetTester tester, MockClient client) async {
  tester.view.physicalSize = const Size(1280, 1100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: DashboardScreen(
        onToggleTheme: () {},
        isDarkMode: true,
        jobService: JobService(autoFetch: false),
        bukService: BukImportService(
          client: client,
          root: 'http://test/site/mediadb/services/module/agentjob',
          authToken: 't',
          idlePoll: const Duration(hours: 1),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  _staleTests();
  testWidgets('BUK Import is listed in the jobs sidebar and selected', (
    tester,
  ) async {
    await _pump(tester, _client());
    expect(find.text('BUK Import'), findsWidgets);
    expect(find.byKey(const Key('run-job')), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
  });

  testWidgets('Run kicks off the import (no confirm card)', (tester) async {
    var posted = false;
    final inner = _client();
    await _pump(
      tester,
      MockClient((req) async {
        if (req.method == 'POST') posted = true;
        return inner.send(req).then(http.Response.fromStream);
      }),
    );
    await tester.tap(find.byKey(const Key('run-job')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(posted, isTrue);
  });

  testWidgets('Run is disabled and says Running while active', (tester) async {
    await _pump(tester, _client(running: true));
    expect(find.text('Running'), findsWidgets);
    final ink = tester.widget<InkWell>(find.byKey(const Key('run-job')));
    expect(ink.onTap, isNull);
  });

  testWidgets('Step logs show the import logs', (tester) async {
    await _pump(tester, _client());
    expect(find.textContaining('Page 1 imported'), findsOneWidget);
  });
}

void _staleTests() {
  test(
    'BUK job is not Running when the lock is free and the run row is stale',
    () async {
      final svc = BukImportService(
        client: MockClient((req) async {
          final p = req.url.path;
          if (p.endsWith('status.json')) {
            return http.Response(
              json.encode({
                'configured': true,
                'running': false,
                'lastRun': {'id': 'r1', 'status': 'running'},
              }),
              200,
            );
          }
          return http.Response(json.encode({'results': []}), 200);
        }),
        root: 'http://test',
        autoStart: false,
      );
      await svc.refresh();
      expect(svc.toJob().status, JobStatus.error);
      svc.dispose();
    },
  );
}
