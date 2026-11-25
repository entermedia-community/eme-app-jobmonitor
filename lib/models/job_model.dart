import 'package:flutter/material.dart';

enum JobStatus {
  newStatus('new', 'New', Color(0xFF64748B), Icons.fiber_new_rounded),
  queued('queued', 'Queued', Color(0xFFFFA000), Icons.hourglass_top_rounded),
  running(
    'running',
    'Running',
    Color(0xFF00C853),
    Icons.play_circle_fill_rounded,
  ),
  complete(
    'complete',
    'Complete',
    Color(0xFF0288D1),
    Icons.check_circle_rounded,
  ),
  error('error', 'Error', Color(0xFFE53935), Icons.error_rounded);

  final String value;
  final String label;
  final Color color;
  final IconData icon;

  const JobStatus(this.value, this.label, this.color, this.icon);

  static JobStatus fromString(String? val) {
    if (val == null) return JobStatus.newStatus;
    switch (val.toLowerCase().trim()) {
      case 'new':
        return JobStatus.newStatus;
      case 'queued':
      case 'pending':
        return JobStatus.queued;
      case 'running':
      case 'active':
        return JobStatus.running;
      case 'complete':
      case 'completed':
      case 'succeeded':
        return JobStatus.complete;
      case 'error':
      case 'failed':
        return JobStatus.error;
      default:
        return JobStatus.newStatus;
    }
  }
}

enum StepStatus {
  active,
  succeeded,
  failed,
  pending,
  skipped;

  String get label {
    switch (this) {
      case StepStatus.active:
        return 'Active';
      case StepStatus.succeeded:
        return 'Succeeded';
      case StepStatus.failed:
        return 'Failed';
      case StepStatus.pending:
        return 'Pending';
      case StepStatus.skipped:
        return 'Skipped';
    }
  }

  Color get color {
    switch (this) {
      case StepStatus.active:
        return const Color(0xFF00C853);
      case StepStatus.succeeded:
        return const Color(0xFF0288D1);
      case StepStatus.failed:
        return const Color(0xFFE53935);
      case StepStatus.pending:
        return const Color(0xFF9E9E9E);
      case StepStatus.skipped:
        return const Color(0xFF757575);
    }
  }

  IconData get icon {
    switch (this) {
      case StepStatus.active:
        return Icons.sync_rounded;
      case StepStatus.succeeded:
        return Icons.check_circle_outline_rounded;
      case StepStatus.failed:
        return Icons.highlight_off_rounded;
      case StepStatus.pending:
        return Icons.radio_button_unchecked_rounded;
      case StepStatus.skipped:
        return Icons.remove_circle_outline_rounded;
    }
  }
}

enum LogLevel {
  info,
  success,
  warning,
  error,
  debug;

  String get label => name.toUpperCase();

  Color get color {
    switch (this) {
      case LogLevel.info:
        return const Color(0xFF38BDF8); // Sky blue
      case LogLevel.success:
        return const Color(0xFF4ADE80); // Green
      case LogLevel.warning:
        return const Color(0xFFFBBF24); // Amber
      case LogLevel.error:
        return const Color(0xFFF87171); // Red
      case LogLevel.debug:
        return const Color(0xFFA78BFA); // Violet
    }
  }
}

enum JobSortOption {
  submittedDate('submitteddate', 'Creation Date', Icons.calendar_today_rounded),
  startDate('startdate', 'Start Date', Icons.play_arrow_rounded),
  endDate('enddate', 'End Date', Icons.event_available_rounded);

  final String value;
  final String label;
  final IconData icon;

  const JobSortOption(this.value, this.label, this.icon);

  static JobSortOption fromString(String? val) {
    if (val == null) return JobSortOption.submittedDate;
    switch (val.toLowerCase().trim()) {
      case 'submitteddate':
      case 'createdate':
      case 'createddate':
        return JobSortOption.submittedDate;
      case 'startdate':
        return JobSortOption.startDate;
      case 'enddate':
        return JobSortOption.endDate;
      default:
        return JobSortOption.submittedDate;
    }
  }
}

enum SortDirection {
  descending('desc', 'Descending (Z-A / Newest)', Icons.arrow_downward_rounded),
  ascending('asc', 'Ascending (A-Z / Oldest)', Icons.arrow_upward_rounded);

  final String value;
  final String label;
  final IconData icon;

  const SortDirection(this.value, this.label, this.icon);
}

enum DateRangeFilter {
  all('', 'All Time'),
  last24Hours('last24hours', 'Last 24 Hours'),
  lastWeek('lastweek', 'Last Week'),
  lastMonth('lastmonth', 'Last Month');

  final String value;
  final String label;

  const DateRangeFilter(this.value, this.label);

  static DateRangeFilter fromString(String? val) {
    if (val == null || val.isEmpty) return DateRangeFilter.all;
    switch (val.toLowerCase().trim()) {
      case 'last24hours':
        return DateRangeFilter.last24Hours;
      case 'lastweek':
        return DateRangeFilter.lastWeek;
      case 'lastmonth':
        return DateRangeFilter.lastMonth;
      default:
        return DateRangeFilter.all;
    }
  }
}

class StepLog {
  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? details;

  StepLog({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    this.details,
  });

  StepLog copyWith({
    String? id,
    DateTime? timestamp,
    LogLevel? level,
    String? message,
    String? details,
  }) {
    return StepLog(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      level: level ?? this.level,
      message: message ?? this.message,
      details: details ?? this.details,
    );
  }
}

class JobStep {
  final String id;
  final int order;
  final String name;
  final String description;
  final String? toolName;
  StepStatus status;
  DateTime? startedAt;
  DateTime? finishedAt;
  final List<StepLog> logs;
  String? errorMessage;

  JobStep({
    required this.id,
    required this.order,
    required this.name,
    required this.description,
    this.toolName,
    required this.status,
    this.startedAt,
    this.finishedAt,
    List<StepLog>? logs,
    this.errorMessage,
  }) : logs = logs ?? [];

  Duration? get duration {
    if (startedAt == null) return null;
    final end = finishedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  JobStep copyWith({
    String? id,
    int? order,
    String? name,
    String? description,
    String? toolName,
    StepStatus? status,
    DateTime? startedAt,
    DateTime? finishedAt,
    List<StepLog>? logs,
    String? errorMessage,
  }) {
    return JobStep(
      id: id ?? this.id,
      order: order ?? this.order,
      name: name ?? this.name,
      description: description ?? this.description,
      toolName: toolName ?? this.toolName,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      logs: logs ?? List.from(this.logs),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AgentJob {
  final String id;
  final String title;
  final String description;
  final String agentName;
  final String agentRole;
  final IconData agentIcon;
  JobStatus status;
  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? finishedAt;
  final List<JobStep> steps;

  /// Repeat period (e.g. daily) for scheduled jobs; null for one-off jobs.
  final String? repeatPeriod;

  AgentJob({
    required this.id,
    required this.title,
    required this.description,
    required this.agentName,
    required this.agentRole,
    required this.agentIcon,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    required this.steps,
    this.repeatPeriod,
  });

  bool get isRepeating => repeatPeriod != null && repeatPeriod!.isNotEmpty;

  /// Repeating jobs idle between runs (complete/new) are waiting for their
  /// next run, so they count as queued as well as their own status.
  bool matchesStatus(JobStatus s) =>
      status == s ||
      (s == JobStatus.queued &&
          isRepeating &&
          (status == JobStatus.complete || status == JobStatus.newStatus));

  bool get isActive => status == JobStatus.running;
  bool get isFailed => status == JobStatus.error;
  bool get isSucceeded => status == JobStatus.complete;
  bool get isQueued => status == JobStatus.queued;
  bool get isNew => status == JobStatus.newStatus;

  int get completedStepsCount =>
      steps.where((s) => s.status == StepStatus.succeeded).length;

  int get totalStepsCount => steps.length;

  double get progressRatio {
    if (steps.isEmpty) {
      if (status == JobStatus.complete) return 1.0;
      if (status == JobStatus.running) return 0.5;
      return 0.0;
    }
    return completedStepsCount / steps.length;
  }

  JobStep? get currentActiveStep {
    try {
      return steps.firstWhere((s) => s.status == StepStatus.active);
    } catch (_) {
      return null;
    }
  }

  Duration get duration {
    final start = startedAt ?? createdAt;
    final end = finishedAt ?? DateTime.now();
    return end.difference(start);
  }

  factory AgentJob.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String && val.trim().isNotEmpty) {
        final str = val.trim();
        final standardParsed = DateTime.tryParse(str);
        if (standardParsed != null) return standardParsed;

        // EnterMedia format: 'yyyy-MM-dd HH:mm:ss Z' (e.g. '2026-10-17 00:58:09 +0600')
        try {
          final parts = str.split(' ');
          if (parts.length >= 2) {
            String isoStr = '${parts[0]}T${parts[1]}';
            if (parts.length >= 3) {
              isoStr += parts[2];
            }
            return DateTime.tryParse(isoStr);
          }
        } catch (_) {}
      }
      return null;
    }

    final id =
        json['id']?.toString() ??
        json['jobid']?.toString() ??
        json['agentjobid']?.toString() ??
        'JOB-${DateTime.now().millisecondsSinceEpoch}';

    final title =
        json['title']?.toString() ??
        json['name']?.toString() ??
        json['jobname']?.toString() ??
        json['description']?.toString() ??
        'Job $id';

    final description =
        json['description']?.toString() ??
        json['details']?.toString() ??
        json['errordetails']?.toString() ??
        '';

    final agentName =
        json['agentname']?.toString() ??
        json['agent']?.toString() ??
        json['runner']?.toString() ??
        'EnterMedia Agent';

    final agentRole =
        json['agentrole']?.toString() ??
        json['role']?.toString() ??
        'Background Repeating Job';

    final rp = (json['repeatperiod'] ?? json['repeatPeriod'])?.toString().trim();
    final repeatPeriod = (rp == null || rp.isEmpty || rp == 'null') ? null : rp;

    final statusStr =
        json['status']?.toString() ?? json['jobstatus']?.toString() ?? 'new';
    final status = JobStatus.fromString(statusStr);

    final createdAt =
        parseDate(json['submitteddate']) ??
        parseDate(json['createddate']) ??
        parseDate(json['created']) ??
        parseDate(json['date']) ??
        DateTime.now();

    final startedAt =
        parseDate(json['startdate']) ??
        parseDate(json['started']) ??
        parseDate(json['starteddate']);

    final finishedAt =
        parseDate(json['enddate']) ??
        parseDate(json['finisheddate']) ??
        parseDate(json['completeddate']);

    List<JobStep> steps = [];
    if (json['steps'] is List) {
      int idx = 1;
      for (var s in json['steps']) {
        if (s is Map<String, dynamic>) {
          steps.add(
            JobStep(
              id: s['id']?.toString() ?? 'step-$idx',
              order: (s['order'] is int) ? s['order'] as int : idx,
              name: s['name']?.toString() ?? 'Step $idx',
              description: s['description']?.toString() ?? '',
              toolName: s['toolname']?.toString() ?? s['tool']?.toString(),
              status: StepStatus.values.firstWhere(
                (e) =>
                    e.name.toLowerCase() ==
                    s['status']?.toString().toLowerCase(),
                orElse: () => StepStatus.succeeded,
              ),
              startedAt: parseDate(s['startdate']),
              finishedAt: parseDate(s['enddate']),
            ),
          );
        }
        idx++;
      }
    }

    if (steps.isEmpty) {
      // Create a default single step reflecting overall job state
      StepStatus defaultStepStatus = StepStatus.pending;
      if (status == JobStatus.running) defaultStepStatus = StepStatus.active;
      if (status == JobStatus.complete)
        defaultStepStatus = StepStatus.succeeded;
      if (status == JobStatus.error) defaultStepStatus = StepStatus.failed;

      steps = [
        JobStep(
          id: '$id-step-1',
          order: 1,
          name: title,
          description: description.isNotEmpty ? description : 'Execution phase',
          status: defaultStepStatus,
          startedAt: startedAt,
          finishedAt: finishedAt,
          errorMessage: status == JobStatus.error ? description : null,
          logs: [
            StepLog(
              id: '$id-log-1',
              timestamp: startedAt ?? createdAt,
              level: status == JobStatus.error ? LogLevel.error : LogLevel.info,
              message: description.isNotEmpty
                  ? description
                  : 'Job state: ${status.label}',
            ),
          ],
        ),
      ];
    }

    return AgentJob(
      id: id,
      title: title,
      description: description,
      agentName: agentName,
      agentRole: agentRole,
      agentIcon: Icons.smart_toy_rounded,
      status: status,
      createdAt: createdAt,
      startedAt: startedAt,
      finishedAt: finishedAt,
      steps: steps,
      repeatPeriod: repeatPeriod,
    );
  }

  AgentJob copyWith({
    String? id,
    String? title,
    String? description,
    String? agentName,
    String? agentRole,
    IconData? agentIcon,
    JobStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    List<JobStep>? steps,
  }) {
    return AgentJob(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      agentName: agentName ?? this.agentName,
      agentRole: agentRole ?? this.agentRole,
      agentIcon: agentIcon ?? this.agentIcon,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      steps: steps ?? List.from(this.steps),
      repeatPeriod: repeatPeriod,
    );
  }
}
