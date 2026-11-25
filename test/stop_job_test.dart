import 'dart:convert';

import 'package:agent_job_monitor/models/job_model.dart';
import 'package:agent_job_monitor/services/job_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  http.Response stopReply(bool stopped) => http.Response(
    jsonEncode({
      'response': {'status': stopped ? 'ok' : 'error', 'stopped': stopped},
    }),
    200,
  );

  test('stopJob calls stop.json and marks the job stopped', () async {
    final requests = <Uri>[];
    final svc = JobService(
      autoFetch: false,
      client: MockClient((req) async {
        requests.add(req.url);
        return stopReply(true);
      }),
    );
    svc.triggerNewAgentJob();
    final job = svc.selectedJob!;
    expect(svc.canStop(job), isTrue);

    final error = await svc.stopJob(job.id);

    expect(error, isNull);
    expect(requests.single.path, endsWith('/agentjob/stop.json'));
    expect(requests.single.queryParameters['jobid'], job.id);
    expect(job.status, JobStatus.error);
    expect(job.finishedAt, isNotNull);
    expect(job.steps.every((s) => s.status == StepStatus.failed), isTrue);
    expect(job.steps.first.errorMessage, JobService.stoppedByUser);
    expect(svc.canStop(job), isFalse);
    svc.dispose();
  });

  test('stopJob leaves the job alone when the server did not stop it', () async {
    final svc = JobService(
      autoFetch: false,
      client: MockClient((req) async => stopReply(false)),
    );
    svc.triggerNewAgentJob();
    final job = svc.selectedJob!;

    final error = await svc.stopJob(job.id);

    expect(error, contains('no longer running'));
    expect(job.status, JobStatus.running);
    svc.dispose();
  });

  test('stopJob reports HTTP errors', () async {
    final svc = JobService(
      autoFetch: false,
      client: MockClient((req) async => http.Response('nope', 500)),
    );
    svc.triggerNewAgentJob();
    final job = svc.selectedJob!;

    final error = await svc.stopJob(job.id);

    expect(error, contains('HTTP 500'));
    expect(job.status, JobStatus.running);
    expect(svc.isStopping(job.id), isFalse);
    svc.dispose();
  });

  test('stopJob refuses jobs that are not running', () async {
    final svc = JobService(
      autoFetch: false,
      client: MockClient((req) async => fail('should not call the server')),
    );
    svc.triggerNewAgentJob();
    final job = svc.selectedJob!..status = JobStatus.complete;

    expect(await svc.stopJob(job.id), contains('not running'));
    svc.dispose();
  });
}
