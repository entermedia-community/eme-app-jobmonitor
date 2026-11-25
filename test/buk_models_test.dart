import 'package:flutter_test/flutter_test.dart';
import 'package:agent_job_monitor/models/buk_models.dart';

void main() {
  test('SchedulerStatus parses status.json', () {
    final s = SchedulerStatus.fromJson({
      'configured': true,
      'jobExists': true,
      'running': false,
      'repeatPeriod': 'daily',
      'repeatTime': '03:00',
      'nextRun': '2026-11-20T03:00:00+00:00',
      'lastRun': {
        'id': 'buk-1',
        'type': 'full',
        'status': 'partial',
        'startedAt': '2026-11-19T03:00:00+00:00',
        'finishedAt': '2026-11-19T03:02:00+00:00',
        'recordsRead': 120,
        'recordsWritten': 118,
        'recordsRejected': 2,
        'errorCode': null,
      },
      'lastSuccess': null,
    });
    expect(s.scheduleLabel, 'Daily at 03:00');
    expect(s.lastRun!.recordsWritten, 118);
    expect(s.lastRun!.duration, const Duration(minutes: 2));
    expect(s.lastRun!.errorCode, isNull);
    expect(s.lastSuccess, isNull);
    expect(s.nextRun, isNotNull);
  });

  test('ImportLogLine parses epoch millis', () {
    final l = ImportLogLine.fromJson({
      'type': 'error',
      'log': 'boom',
      'timestamp': '1763500000000',
    });
    expect(l.timestampMs, 1763500000000);
    expect(l.message, 'boom');
  });

  test('empty status is safe', () {
    final s = SchedulerStatus.fromJson({});
    expect(s.configured, isFalse);
    expect(s.scheduleLabel, 'Not scheduled');
  });
}
