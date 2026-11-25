/// One BUK import run (an fsejecucionfuente row on the server).
class ImportRun {
  final String id;
  final String type;
  final String status; // running, success, partial, failed
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int recordsRead;
  final int recordsWritten;
  final int recordsRejected;
  final String? errorCode;
  final String? errorDetail;

  const ImportRun({
    required this.id,
    required this.type,
    required this.status,
    this.startedAt,
    this.finishedAt,
    this.recordsRead = 0,
    this.recordsWritten = 0,
    this.recordsRejected = 0,
    this.errorCode,
    this.errorDetail,
  });

  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed';

  Duration? get duration => (startedAt != null && finishedAt != null)
      ? finishedAt!.difference(startedAt!)
      : null;

  factory ImportRun.fromJson(Map<String, dynamic> j) => ImportRun(
    id: (j['id'] ?? '').toString(),
    type: (j['type'] ?? '').toString(),
    status: (j['status'] ?? 'unknown').toString(),
    startedAt: _date(j['startedAt']),
    finishedAt: _date(j['finishedAt']),
    recordsRead: _int(j['recordsRead']),
    recordsWritten: _int(j['recordsWritten']),
    recordsRejected: _int(j['recordsRejected']),
    errorCode: _str(j['errorCode']),
    errorDetail: _str(j['errorDetail']),
  );
}

/// Scheduler state for the repeating BUK import job.
class SchedulerStatus {
  final bool configured;
  final bool jobExists;
  final bool running;
  final String? repeatPeriod;
  final String? repeatTime;
  final DateTime? nextRun;
  final ImportRun? lastRun;
  final ImportRun? lastSuccess;

  const SchedulerStatus({
    required this.configured,
    required this.jobExists,
    required this.running,
    this.repeatPeriod,
    this.repeatTime,
    this.nextRun,
    this.lastRun,
    this.lastSuccess,
  });

  String get scheduleLabel {
    if (repeatPeriod == null) return 'Not scheduled';
    final t = (repeatTime == null || repeatTime!.isEmpty)
        ? ''
        : ' at $repeatTime';
    return '${repeatPeriod![0].toUpperCase()}${repeatPeriod!.substring(1)}$t';
  }

  factory SchedulerStatus.fromJson(Map<String, dynamic> j) => SchedulerStatus(
    configured: j['configured'] == true,
    jobExists: j['jobExists'] == true,
    running: j['running'] == true,
    repeatPeriod: _str(j['repeatPeriod']),
    repeatTime: _str(j['repeatTime']),
    nextRun: _date(j['nextRun']),
    lastRun: j['lastRun'] is Map<String, dynamic>
        ? ImportRun.fromJson(j['lastRun'] as Map<String, dynamic>)
        : null,
    lastSuccess: j['lastSuccess'] is Map<String, dynamic>
        ? ImportRun.fromJson(j['lastSuccess'] as Map<String, dynamic>)
        : null,
  );
}

/// One line of the job run log: {step, type, log, timestamp(epoch ms)}.
class ImportLogLine {
  final String type; // info, success, warning, error
  final String message;
  final int timestampMs;

  const ImportLogLine({
    required this.type,
    required this.message,
    required this.timestampMs,
  });

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timestampMs);

  factory ImportLogLine.fromJson(Map<String, dynamic> j) => ImportLogLine(
    type: (j['type'] ?? 'info').toString(),
    message: (j['log'] ?? '').toString(),
    timestampMs: _int(j['timestamp']),
  );
}

String? _str(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty || s == 'null') ? null : s;
}

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

DateTime? _date(dynamic v) {
  final s = _str(v);
  return s == null ? null : DateTime.tryParse(s)?.toLocal();
}
