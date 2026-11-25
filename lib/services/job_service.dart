import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../models/job_model.dart';
import 'buk_import_service.dart';

class JobFilterState {
  String searchQuery;
  Set<JobStatus> selectedStatuses;
  Set<String> selectedAgents;
  DateRangeFilter dateRange;
  String? environment;
  bool onlyWithErrors;

  JobFilterState({
    this.searchQuery = '',
    Set<JobStatus>? selectedStatuses,
    Set<String>? selectedAgents,
    this.dateRange = DateRangeFilter.all,
    this.environment,
    this.onlyWithErrors = false,
  }) : selectedStatuses = selectedStatuses ?? {},
       selectedAgents = selectedAgents ?? {};

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      selectedStatuses.isNotEmpty ||
      selectedAgents.isNotEmpty ||
      dateRange != DateRangeFilter.all ||
      (environment != null && environment != 'All') ||
      onlyWithErrors;

  int get activeFiltersCount {
    int count = 0;
    if (searchQuery.trim().isNotEmpty) count++;
    if (selectedStatuses.isNotEmpty) count += selectedStatuses.length;
    if (selectedAgents.isNotEmpty) count += selectedAgents.length;
    if (dateRange != DateRangeFilter.all) count++;
    if (environment != null && environment != 'All') count++;
    if (onlyWithErrors) count++;
    return count;
  }

  void reset() {
    searchQuery = '';
    selectedStatuses.clear();
    selectedAgents.clear();
    dateRange = DateRangeFilter.all;
    environment = null;
    onlyWithErrors = false;
  }
}

class JobService extends ChangeNotifier {
  static const String apiBase =
      '${AppConfig.emeBaseUrl}${AppConfig.emeAppPath}';
  static const String defaultApiUrl =
      '$apiBase/services/module/agentjob/jobs.json';
  // Never commit a token: pass it with --dart-define=EME_TOKEN=...
  static const String defaultAuthToken = AppConfig.emeToken;

  String _apiUrl = defaultApiUrl;
  String? _authToken = defaultAuthToken;
  List<AgentJob> _jobs = [];
  AgentJob? _selectedJob;
  String? _selectedStepId;

  JobSortOption _sortOption = JobSortOption.submittedDate;
  SortDirection _sortDirection = SortDirection.descending;

  final JobFilterState _filter = JobFilterState();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isUsingMockFallback = false;

  bool _isLiveSimulationRunning = false;
  Timer? _simulationTimer;
  Timer? _debounceTimer;
  final Random _random = Random();
  bool _isDisposed = false;

  /// Signature headers from the login key; null in tests / dev-token mode.
  final Future<Map<String, String>> Function()? authHeaders;

  /// Called when the server answers 401 (key revoked or expired).
  final Future<void> Function()? onUnauthorized;

  final http.Client _client;

  JobService({
    bool autoFetch = true,
    this.authHeaders,
    this.onUnauthorized,
    http.Client? client,
  }) : _client = client ?? http.Client() {
    if (_jobs.isNotEmpty) {
      _selectedJob = _jobs.first;
      _selectedStepId =
          _selectedJob!.currentActiveStep?.id ?? _selectedJob!.steps.first.id;
    }
    // Fetch initial data from API
    if (autoFetch) {
      fetchJobs();
    }
  }

  final Map<String, BukImportService> _imports = {};

  /// Shows an import source (BUK, SCL, ...) as a job in the list; running it
  /// goes through [runImport].
  void attachImport(BukImportService svc) {
    _imports[svc.jobId]?.removeListener(_mergeImports);
    _imports[svc.jobId] = svc..addListener(_mergeImports);
    _mergeImports();
  }

  /// Kept for existing callers; same as [attachImport].
  void attachBuk(BukImportService buk) => attachImport(buk);

  bool isImportJob(String jobId) => _imports.containsKey(jobId);

  /// Starts an import. Returns an error message, or null on success.
  Future<String?> runImport(String jobId) async {
    final svc = _imports[jobId];
    if (svc == null) return 'Import is not available.';
    return svc.importNow();
  }

  void _mergeImports() {
    if (_isDisposed) return;
    for (final svc in _imports.values) {
      final job = svc.toJob();
      final i = _jobs.indexWhere((j) => j.id == job.id);
      if (i == -1) {
        _jobs = [job, ..._jobs];
      } else {
        _jobs[i] = job;
      }
      if (_selectedJob?.id == job.id) {
        _selectedJob = job;
        _selectedStepId ??= job.steps.first.id;
      } else if (_selectedJob == null) {
        _selectedJob = job;
        _selectedStepId = job.steps.first.id;
      }
    }
    notifyListeners();
  }

  // Getters
  String get apiUrl => _apiUrl;
  String? get authToken => _authToken;
  List<AgentJob> get allJobs => _jobs;
  AgentJob? get selectedJob => _selectedJob;
  String? get selectedStepId => _selectedStepId;
  JobSortOption get sortOption => _sortOption;
  SortDirection get sortDirection => _sortDirection;
  JobFilterState get filter => _filter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isUsingMockFallback => _isUsingMockFallback;
  bool get isLiveSimulationRunning => _isLiveSimulationRunning;

  // Distinct agent names for filter dropdown
  List<String> get availableAgents {
    final set = _jobs.map((j) => j.agentName).toSet();
    return set.toList()..sort();
  }

  void setApiUrl(String url) {
    _apiUrl = url;
    fetchJobs();
  }

  void setAuthToken(String? token) {
    _authToken = token;
    fetchJobs();
  }

  Map<String, String> get requestHeaders {
    final headers = <String, String>{'Accept': 'application/json'};
    if (_authToken != null && _authToken!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${_authToken!.trim()}';
    }
    return headers;
  }

  /// Builds API URI with query parameters: search, status, timerange, sortby, sortorder
  Uri buildRequestUri() {
    final baseUri = Uri.parse(_apiUrl);
    final Map<String, String> params = Map.from(baseUri.queryParameters);

    if (_filter.searchQuery.trim().isNotEmpty) {
      params['search'] = _filter.searchQuery.trim();
    }

    // Status is filtered client-side (filteredAndSortedJobs): repeating jobs
    // are idle as complete/new on the server but belong under Queued.

    if (_filter.dateRange != DateRangeFilter.all) {
      params['timerange'] = _filter.dateRange.value;
    }

    params['sortby'] = _sortOption.value;
    params['sortorder'] = _sortDirection.value;

    return baseUri.replace(queryParameters: params);
  }

  /// Fetch jobs from jobs.json endpoint
  Future<void> fetchJobs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = buildRequestUri();
      final response = await http
          .get(uri, headers: {...requestHeaders, ...?await authHeaders?.call()})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 401) await onUnauthorized?.call();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        List<dynamic> listData = [];

        if (decoded is List) {
          listData = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['response'] is Map &&
              decoded['response']['list'] is List) {
            listData = decoded['response']['list'];
          } else if (decoded['results'] is List) {
            listData = decoded['results'];
          } else if (decoded['data'] is List) {
            listData = decoded['data'];
          } else if (decoded['jobs'] is List) {
            listData = decoded['jobs'];
          } else if (decoded['rows'] is List) {
            listData = decoded['rows'];
          }
        }

        final parsedJobs = listData
            .map((item) => AgentJob.fromJson(item as Map<String, dynamic>))
            .toList();

        _jobs = parsedJobs;
        _isUsingMockFallback = false;
        _errorMessage = null;

        if (_jobs.isNotEmpty) {
          if (_selectedJob == null ||
              !_jobs.any((j) => j.id == _selectedJob!.id)) {
            _selectedJob = _jobs.first;
            _selectedStepId = _selectedJob!.steps.isNotEmpty
                ? _selectedJob!.steps.first.id
                : null;
          }
        } else {
          _selectedJob = null;
          _selectedStepId = null;
        }
      } else {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }
    } catch (e) {
      // In local dev/testing where backend server may not be reachable or 404s,
      // fallback gracefully to mock jobs while logging status
      _isUsingMockFallback = true;
      _errorMessage = e.toString();

      if (_selectedJob == null && _jobs.isNotEmpty) {
        _selectedJob = _jobs.first;
        _selectedStepId = _selectedJob!.steps.isNotEmpty
            ? _selectedJob!.steps.first.id
            : null;
      }
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        if (_imports.isNotEmpty) _mergeImports();
        notifyListeners();
      }
    }
  }

  void _debounceFetch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      fetchJobs();
    });
  }

  // Filtered and Sorted Jobs
  List<AgentJob> get filteredAndSortedJobs {
    final now = DateTime.now();

    var result = _jobs.where((job) {
      // 1. Search Query (also applied client-side for immediate responsive UI)
      if (_filter.searchQuery.trim().isNotEmpty) {
        final query = _filter.searchQuery.trim().toLowerCase();
        final matchesTitle = job.title.toLowerCase().contains(query);
        final matchesDesc = job.description.toLowerCase().contains(query);
        final matchesId = job.id.toLowerCase().contains(query);
        final matchesAgent = job.agentName.toLowerCase().contains(query);
        final matchesStep = job.steps.any(
          (s) =>
              s.name.toLowerCase().contains(query) ||
              s.description.toLowerCase().contains(query) ||
              s.logs.any((l) => l.message.toLowerCase().contains(query)),
        );

        if (!matchesTitle &&
            !matchesDesc &&
            !matchesId &&
            !matchesAgent &&
            !matchesStep) {
          return false;
        }
      }

      // 2. Status Filter
      if (_filter.selectedStatuses.isNotEmpty) {
        if (!_filter.selectedStatuses.any(job.matchesStatus)) {
          return false;
        }
      }

      // 3. Agent Filter
      if (_filter.selectedAgents.isNotEmpty) {
        if (!_filter.selectedAgents.contains(job.agentName)) {
          return false;
        }
      }

      // 4. Only with errors
      if (_filter.onlyWithErrors) {
        final hasErrorStep = job.steps.any(
          (s) => s.status == StepStatus.failed,
        );
        if (!job.isFailed && !hasErrorStep) {
          return false;
        }
      }

      // 5. Date Range Filter
      switch (_filter.dateRange) {
        case DateRangeFilter.all:
          break;
        case DateRangeFilter.last24Hours:
          if (job.createdAt.isBefore(now.subtract(const Duration(hours: 24)))) {
            return false;
          }
          break;
        case DateRangeFilter.lastWeek:
          if (job.createdAt.isBefore(now.subtract(const Duration(days: 7)))) {
            return false;
          }
          break;
        case DateRangeFilter.lastMonth:
          if (job.createdAt.isBefore(now.subtract(const Duration(days: 30)))) {
            return false;
          }
          break;
      }

      return true;
    }).toList();

    // Sorting
    result.sort((a, b) {
      int comparison = 0;
      switch (_sortOption) {
        case JobSortOption.submittedDate:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case JobSortOption.startDate:
          final aDate = a.startedAt ?? a.createdAt;
          final bDate = b.startedAt ?? b.createdAt;
          comparison = aDate.compareTo(bDate);
          break;
        case JobSortOption.endDate:
          final aDate = a.finishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.finishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          comparison = aDate.compareTo(bDate);
          break;
      }

      if (_sortDirection == SortDirection.descending) {
        return -comparison;
      }
      return comparison;
    });

    return result;
  }

  // Summary statistics
  int get totalJobsCount => _jobs.length;
  int get runningJobsCount =>
      _jobs.where((j) => j.status == JobStatus.running).length;
  int get completeJobsCount =>
      _jobs.where((j) => j.status == JobStatus.complete).length;
  int get errorJobsCount =>
      _jobs.where((j) => j.status == JobStatus.error).length;
  int get queuedJobsCount =>
      _jobs.where((j) => j.matchesStatus(JobStatus.queued)).length;
  int get newJobsCount =>
      _jobs.where((j) => j.status == JobStatus.newStatus).length;

  // Legacy compatibility getters
  int get activeJobsCount => runningJobsCount;
  int get succeededJobsCount => completeJobsCount;
  int get failedJobsCount => errorJobsCount;
  int get pendingJobsCount => queuedJobsCount;

  double get successRate {
    final completed = completeJobsCount + errorJobsCount;
    if (completed == 0) return 0.0;
    return (completeJobsCount / completed) * 100.0;
  }

  // Actions
  void setSortOption(JobSortOption option) {
    if (_sortOption == option) {
      // Toggle direction if clicking same option
      _sortDirection = _sortDirection == SortDirection.descending
          ? SortDirection.ascending
          : SortDirection.descending;
    } else {
      _sortOption = option;
      _sortDirection = SortDirection.descending;
    }
    notifyListeners();
    _debounceFetch();
  }

  void setSortDirection(SortDirection direction) {
    _sortDirection = direction;
    notifyListeners();
    _debounceFetch();
  }

  void setSearchQuery(String query) {
    _filter.searchQuery = query;
    notifyListeners();
    _debounceFetch();
  }

  void toggleStatusFilter(JobStatus status) {
    if (_filter.selectedStatuses.contains(status)) {
      _filter.selectedStatuses.remove(status);
    } else {
      _filter.selectedStatuses.add(status);
    }
    notifyListeners();
    _debounceFetch();
  }

  void toggleAgentFilter(String agentName) {
    if (_filter.selectedAgents.contains(agentName)) {
      _filter.selectedAgents.remove(agentName);
    } else {
      _filter.selectedAgents.add(agentName);
    }
    notifyListeners();
  }

  void setDateRange(DateRangeFilter range) {
    _filter.dateRange = range;
    notifyListeners();
    _debounceFetch();
  }

  void setEnvironment(String? env) {
    _filter.environment = env;
    notifyListeners();
  }

  void toggleOnlyWithErrors() {
    _filter.onlyWithErrors = !_filter.onlyWithErrors;
    notifyListeners();
  }

  void resetFilters() {
    _filter.reset();
    notifyListeners();
    fetchJobs();
  }

  void selectJob(AgentJob job) {
    _selectedJob = job;
    _selectedStepId =
        job.currentActiveStep?.id ??
        (job.steps.isNotEmpty ? job.steps.first.id : null);
    notifyListeners();
  }

  void selectStep(String stepId) {
    _selectedStepId = stepId;
    notifyListeners();
  }

  void toggleLiveSimulation() {
    _isLiveSimulationRunning = !_isLiveSimulationRunning;
    if (_isLiveSimulationRunning) {
      _startLiveSimulation();
    } else {
      _simulationTimer?.cancel();
      _simulationTimer = null;
    }
    notifyListeners();
  }

  void _startLiveSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isLiveSimulationRunning) return;
      _simulateStepActivity();
    });
  }

  void _simulateStepActivity() {
    final runningJobs = _jobs
        .where((j) => j.status == JobStatus.running)
        .toList();
    if (runningJobs.isEmpty) return;

    final job = runningJobs[_random.nextInt(runningJobs.length)];
    final activeStep = job.currentActiveStep;

    if (activeStep != null) {
      final now = DateTime.now();
      final sampleLogs = [
        'Inspecting execution trace telemetry: delta latency -4.2ms.',
        'Synthesizing sandbox environment state verification checkpoint.',
        'Emitting stream heartbeats to orchestration coordinator node.',
        'Memory buffer occupancy: 42.1% (allocations bounded within safe limits).',
        'Validating step invariant preconditions against agent policy guardrail.',
        'Running downstream mock dependency probe: HTTP 200 OK.',
        'Incremental checkpoint saved with SHA-256 digest.',
      ];

      final randomLogMsg = sampleLogs[_random.nextInt(sampleLogs.length)];
      final newLog = StepLog(
        id: 'L-SIM-${now.millisecondsSinceEpoch}',
        timestamp: now,
        level: _random.nextInt(10) > 8 ? LogLevel.debug : LogLevel.info,
        message: randomLogMsg,
      );

      activeStep.logs.add(newLog);

      if (activeStep.logs.length >= 7 && _random.nextBool()) {
        activeStep.status = StepStatus.succeeded;
        activeStep.finishedAt = now;

        final nextStepIndex = job.steps.indexOf(activeStep) + 1;
        if (nextStepIndex < job.steps.length) {
          final nextStep = job.steps[nextStepIndex];
          nextStep.status = StepStatus.active;
          nextStep.startedAt = now;
          nextStep.logs.add(
            StepLog(
              id: 'L-SIM-START-${now.millisecondsSinceEpoch}',
              timestamp: now,
              level: LogLevel.info,
              message: 'Step initiated by ${job.agentName} executor daemon.',
            ),
          );
          if (_selectedJob?.id == job.id) {
            _selectedStepId = nextStep.id;
          }
        } else {
          job.status = JobStatus.complete;
          job.finishedAt = now;
        }
      }

      notifyListeners();
    }
  }

  void triggerNewAgentJob() {
    final now = DateTime.now();
    final randomId = 9410 + _random.nextInt(500);
    final agentNames = [
      'CodeArchitect AI',
      'SecOps Sentinel',
      'EvalPilot Benchmark AI',
      'AutoRefactor Agent',
      'CloudDeploy Orchestrator',
      'DataStream Agent',
    ];
    final selectedAgent = agentNames[_random.nextInt(agentNames.length)];

    final newJob = AgentJob(
      id: 'JOB-$randomId',
      title: 'Dynamic Agent Task: Orchestrated Subgraph #$randomId',
      description:
          'Autonomous multi-step execution initiated from dashboard monitor.',
      agentName: selectedAgent,
      agentRole: 'Autonomous Agent Worker',
      agentIcon: Icons.auto_awesome_rounded,
      status: JobStatus.running,
      createdAt: now,
      startedAt: now,
      steps: [
        JobStep(
          id: 'STEP-$randomId-1',
          order: 1,
          name: 'Context Gathering & Dependency Scoping',
          description: 'Fetch remote branch commits and index file symbols.',
          toolName: 'context_scanner',
          status: StepStatus.active,
          startedAt: now,
          logs: [
            StepLog(
              id: 'L-INIT-$randomId',
              timestamp: now,
              level: LogLevel.info,
              message: 'Job dispatched to agent worker pool cluster.',
            ),
            StepLog(
              id: 'L-INIT2-$randomId',
              timestamp: now.add(const Duration(milliseconds: 200)),
              level: LogLevel.info,
              message:
                  'Context token window initialized: 38,400 tokens reserved.',
            ),
          ],
        ),
        JobStep(
          id: 'STEP-$randomId-2',
          order: 2,
          name: 'Core Transformation & Synthesis',
          description: 'Execute prompt-driven logic transformation.',
          toolName: 'agent_core_engine',
          status: StepStatus.pending,
          logs: [],
        ),
        JobStep(
          id: 'STEP-$randomId-3',
          order: 3,
          name: 'Automated Verification & Artifact Export',
          description:
              'Validate output against test fixtures and persist report.',
          toolName: 'artifact_exporter',
          status: StepStatus.pending,
          logs: [],
        ),
      ],
    );

    _jobs.insert(0, newJob);
    _selectedJob = newJob;
    _selectedStepId = newJob.steps.first.id;
    notifyListeners();
  }

  void retryJob(String jobId) {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index != -1) {
      final job = _jobs[index];
      final now = DateTime.now();
      job.status = JobStatus.running;
      job.finishedAt = null;

      for (var s in job.steps) {
        if (s.status == StepStatus.failed || s.status == StepStatus.skipped) {
          s.status = StepStatus.pending;
          s.errorMessage = null;
        }
      }

      final nextStep = job.steps.firstWhere(
        (s) => s.status == StepStatus.pending,
        orElse: () => job.steps.first,
      );
      nextStep.status = StepStatus.active;
      nextStep.startedAt = now;
      nextStep.logs.add(
        StepLog(
          id: 'L-RETRY-${now.millisecondsSinceEpoch}',
          timestamp: now,
          level: LogLevel.info,
          message: 'Retry initiated by user. Restarting step execution.',
        ),
      );

      _selectedJob = job;
      _selectedStepId = nextStep.id;
      notifyListeners();
    }
  }

  void runJob(String jobId, {bool restart = false}) {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index != -1) {
      final job = _jobs[index];
      final now = DateTime.now();

      job.status = JobStatus.running;
      job.startedAt = now;
      job.finishedAt = null;

      if (job.steps.isNotEmpty) {
        for (var i = 0; i < job.steps.length; i++) {
          final s = job.steps[i];
          if (i == 0) {
            s.status = StepStatus.active;
            s.startedAt = now;
            s.finishedAt = null;
            s.errorMessage = null;
            s.logs.add(
              StepLog(
                id: 'L-RUN-${now.millisecondsSinceEpoch}',
                timestamp: now,
                level: LogLevel.info,
                message: restart
                    ? 'Job manually stopped and restarted.'
                    : 'Job execution manually initiated.',
              ),
            );
          } else {
            s.status = StepStatus.pending;
            s.startedAt = null;
            s.finishedAt = null;
            s.errorMessage = null;
          }
        }
        _selectedStepId = job.steps.first.id;
      }

      _selectedJob = job;
      notifyListeners();
    }
  }

  static const String stoppedByUser = 'Stopped by user';

  final Set<String> _stopping = {};

  /// True while a stop request for [jobId] is waiting on the server.
  bool isStopping(String jobId) => _stopping.contains(jobId);

  /// Imports have no cancel endpoint, so only agent jobs can be stopped.
  bool canStop(AgentJob job) =>
      job.status == JobStatus.running && !isImportJob(job.id);

  /// Asks the server (stop.json) to stop a running job: the step running now
  /// finishes and the rest are skipped. Returns an error message, or null on
  /// success. With no server (mock fallback) the job is only stopped locally.
  Future<String?> stopJob(String jobId) async {
    if (_stopping.contains(jobId)) return null;
    final job = _jobs.where((j) => j.id == jobId).firstOrNull;
    if (job == null) return 'Job "$jobId" was not found.';
    if (!canStop(job)) return 'Job "$jobId" is not running.';

    if (!_isUsingMockFallback) {
      _stopping.add(jobId);
      notifyListeners();
      try {
        final uri = Uri.parse(
          _apiUrl,
        ).resolve('stop.json').replace(queryParameters: {'jobid': jobId});
        final response = await _client
            .get(
              uri,
              headers: {...requestHeaders, ...?await authHeaders?.call()},
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 401) {
          await onUnauthorized?.call();
          return 'Not signed in.';
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return 'Could not stop job: HTTP ${response.statusCode}';
        }
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        final stopped =
            decoded is Map && (decoded['response'] as Map?)?['stopped'] == true;
        if (!stopped) {
          fetchJobs(); // It probably finished on its own; show the real state
          return 'Job "$jobId" is no longer running.';
        }
      } catch (e) {
        return 'Could not stop job: $e';
      } finally {
        _stopping.remove(jobId);
        if (!_isDisposed) notifyListeners();
      }
    }

    if (_isDisposed) return null;
    _markStopped(job);
    notifyListeners();
    if (!_isUsingMockFallback) fetchJobs();
    return null;
  }

  /// Mirrors what the server saves for a stopped job.
  void _markStopped(AgentJob job) {
    final now = DateTime.now();
    final active = job.currentActiveStep;
    for (final s in job.steps) {
      if (s.status == StepStatus.active || s.status == StepStatus.pending) {
        s.status = StepStatus.failed;
        s.errorMessage = stoppedByUser;
        if (s.startedAt != null) s.finishedAt = now;
      }
    }
    active?.logs.add(
      StepLog(
        id: 'L-STOP-${now.millisecondsSinceEpoch}',
        timestamp: now,
        level: LogLevel.warning,
        message: 'Job stopped by user.',
      ),
    );
    job.status = JobStatus.error;
    job.finishedAt = now;
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final svc in _imports.values) {
      svc.removeListener(_mergeImports);
    }
    _debounceTimer?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }
}
