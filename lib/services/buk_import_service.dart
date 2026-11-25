import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../models/buk_models.dart';
import '../models/job_model.dart';

/// Talks to a fulservice import source's endpoints (BUK, GeoVictoria):
/// status, history, logs and "import now".
class BukImportService extends ChangeNotifier {
  static const String bukJobId = 'buk_sync';
  static const String geoVictoriaJobId = 'geovictoria_sync';
  static const String sclJobId = 'scl_sync';

  /// URL segment under agentjob/ (e.g. 'buk', 'geovictoria').
  final String source;
  final String jobId;

  /// How the import shows up as a job in the monitor.
  final String title;
  final String summary;
  final String agentName;
  final String agentRole;
  final String stepName;
  final IconData icon;

  final http.Client _client;
  final Future<Map<String, String>> Function()? _authHeaders;
  final Future<void> Function()? _onUnauthorized;
  final String _root;
  final String? _token;
  final Duration idlePoll;
  final Duration runningPoll;

  SchedulerStatus? status;
  List<ImportRun> runs = [];
  List<ImportLogLine> logs = [];
  String? error;
  bool isLoading = false;
  bool isTriggering = false;

  Timer? _timer;
  bool _disposed = false;
  bool _polling = false;
  String? _pendingRunAfter; // last run id when Run was clicked
  DateTime _fastPollUntil = DateTime.fromMillisecondsSinceEpoch(0);

  BukImportService({
    this.source = 'buk',
    this.jobId = bukJobId,
    this.title = 'BUK Import',
    this.summary = 'Reads all employees from BUK and updates the database.',
    this.agentName = 'BUK',
    this.agentRole = 'Employee import',
    this.stepName = 'Import employees',
    this.icon = Icons.cloud_download,
    http.Client? client,
    String? root,
    String? authToken,
    Future<Map<String, String>> Function()? authHeaders,
    Future<void> Function()? onUnauthorized,
    this.idlePoll = const Duration(seconds: 60),
    this.runningPoll = const Duration(seconds: 5),
    bool autoStart = true,
  }) : _client = client ?? http.Client(),
       _authHeaders = authHeaders,
       _onUnauthorized = onUnauthorized,
       _root =
           root ??
           '${AppConfig.emeBaseUrl}${AppConfig.emeAppPath}/services/module/agentjob',
       _token =
           authToken ??
           (AppConfig.emeToken.isEmpty ? null : AppConfig.emeToken) {
    if (autoStart) refresh();
  }

  Future<Map<String, String>> _headers() async => {
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
    ...?await _authHeaders?.call(),
  };

  Future<void> _check(http.Response res) async {
    if (res.statusCode == 401) await _onUnauthorized?.call();
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await _client
        .get(Uri.parse('$_root/$path'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    await _check(res);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} for $path');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  /// Reloads status, history and logs, then schedules the next poll
  /// (fast while an import is running, slow otherwise).
  Future<void> refresh() async {
    if (_polling) return;
    _polling = true;
    isLoading = true;
    _notify();
    try {
      final s = SchedulerStatus.fromJson(await _get('$source/status.json'));
      final r = await _get('$source/runs.json');
      final l = await _get('logs.json?jobid=$jobId');
      status = s;
      runs = [
        for (final e in (r['results'] as List? ?? []))
          ImportRun.fromJson(e as Map<String, dynamic>),
      ];
      logs = [
        for (final e in (l['results'] as List? ?? []))
          ImportLogLine.fromJson(e as Map<String, dynamic>),
      ];
      error = null;
    } catch (e) {
      error = 'Could not reach the server: $e';
    } finally {
      isLoading = false;
      _polling = false;
      _notify();
      _timer?.cancel();
      if (!_disposed) {
        _timer = Timer(
          ((status?.running ?? false) || _fastPollUntil.isAfter(DateTime.now()))
              ? runningPoll
              : idlePoll,
          refresh,
        );
      }
    }
  }

  /// Starts an import now. Returns a user-facing message on failure, null on success.
  Future<String?> importNow() async {
    isTriggering = true;
    _notify();
    try {
      final res = await _client
          .post(
            Uri.parse('$_root/$source/import.json'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 15));
      await _check(res);
      if (res.statusCode == 409) return 'An import is already running.';
      if (res.statusCode == 412) {
        return '$source is not configured on the server.';
      }
      if (res.statusCode == 401) return 'Please sign in first.';
      if (res.statusCode != 200) {
        return 'Import failed (HTTP ${res.statusCode}).';
      }
      // The job starts asynchronously: show Running and poll fast until the
      // server reports a new run (or 30s pass).
      _pendingRunAfter = status?.lastRun?.id;
      _fastPollUntil = DateTime.now().add(const Duration(seconds: 30));
      return null;
    } catch (e) {
      return 'Could not start import: $e';
    } finally {
      isTriggering = false;
      _notify();
      // Look again shortly so the running state shows up.
      Future<void>.delayed(const Duration(seconds: 2), refresh);
    }
  }

  // Don't trust a "running" flag from before a failed poll: the import may have
  // finished since, and we'd show Running forever.
  bool get isRunning =>
      ((status?.running ?? false) && error == null) ||
      isTriggering ||
      _awaitingStart;

  /// Run was accepted but the server hasn't started (or finished) a new run yet.
  bool get _awaitingStart =>
      _fastPollUntil.isAfter(DateTime.now()) &&
      _pendingRunAfter != null &&
      status?.lastRun?.id == _pendingRunAfter &&
      !(status?.running ?? false);

  /// The SCL portal import (same server endpoints, under agentjob/scl).
  factory BukImportService.scl({
    http.Client? client,
    String? root,
    String? authToken,
    Future<Map<String, String>> Function()? authHeaders,
    Future<void> Function()? onUnauthorized,
    Duration idlePoll = const Duration(seconds: 60),
    Duration runningPoll = const Duration(seconds: 5),
    bool autoStart = true,
  }) => BukImportService(
    source: 'scl',
    jobId: sclJobId,
    title: 'SCL Portal Import',
    summary: 'Captures and parses the SCL contractor page.',
    agentName: 'SCL',
    agentRole: 'Portal import',
    stepName: 'Import SCL portal',
    icon: Icons.fact_check,
    client: client,
    root: root,
    authToken: authToken,
    authHeaders: authHeaders,
    onUnauthorized: onUnauthorized,
    idlePoll: idlePoll,
    runningPoll: runningPoll,
    autoStart: autoStart,
  );

  /// The import as a monitor job, so it shows up in the jobs sidebar with
  /// its run logs under a single step.
  AgentJob toJob() {
    final last = status?.lastRun;
    final JobStatus jobStatus;
    final StepStatus stepStatus;
    if (isRunning) {
      jobStatus = JobStatus.running;
      stepStatus = StepStatus.active;
    } else if (last == null) {
      jobStatus = JobStatus.newStatus;
      stepStatus = StepStatus.pending;
    } else if (last.isFailed || last.status == 'running') {
      // 'running' row but the server lock is free: the run died mid-way.
      jobStatus = JobStatus.error;
      stepStatus = StepStatus.failed;
    } else {
      jobStatus = JobStatus.complete;
      stepStatus = StepStatus.succeeded;
    }
    final started = last?.startedAt;
    final finished = isRunning ? null : last?.finishedAt;
    final stepLogs = [
      for (var i = 0; i < logs.length; i++)
        StepLog(
          id: '$jobId-log-$i',
          timestamp: logs[i].time,
          level: LogLevel.values.firstWhere(
            (l) => l.name == logs[i].type,
            orElse: () => LogLevel.info,
          ),
          message: logs[i].message,
        ),
    ];
    return AgentJob(
      id: jobId,
      title: title,
      description:
          '$summary '
          'Schedule: ${status?.scheduleLabel ?? '—'}.',
      agentName: agentName,
      agentRole: agentRole,
      agentIcon: icon,
      status: jobStatus,
      createdAt: started ?? DateTime.fromMillisecondsSinceEpoch(0),
      startedAt: started,
      finishedAt: finished,
      repeatPeriod: status?.repeatPeriod,
      steps: [
        JobStep(
          id: '$jobId-import',
          order: 1,
          name: stepName,
          description: 'Run the $source import and save the results.',
          status: stepStatus,
          startedAt: started,
          finishedAt: finished,
          logs: stepLogs,
          errorMessage: last?.errorCode == null
              ? null
              : '${last!.errorCode} — ${last.errorDetail ?? ''}',
        ),
      ],
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _client.close();
    super.dispose();
  }
}
