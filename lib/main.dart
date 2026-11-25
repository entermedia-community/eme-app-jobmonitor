import 'package:flutter/material.dart';

import 'core/auth/auth_service.dart';
import 'features/auth/login_page.dart';
import 'models/job_model.dart';
import 'services/buk_import_service.dart';
import 'services/job_service.dart';
import 'widgets/advanced_filter_panel.dart';
import 'widgets/job_detail_view.dart';
import 'widgets/job_list_item.dart';
import 'widgets/stats_overview_bar.dart';
import 'widgets/status_badge.dart';

void main() {
  runApp(AgentJobMonitorApp(auth: AuthService()..restore()));
}

class AgentJobMonitorApp extends StatefulWidget {
  const AgentJobMonitorApp({super.key, required this.auth});
  final AuthService auth;

  @override
  State<AgentJobMonitorApp> createState() => _AgentJobMonitorAppState();
}

class _AgentJobMonitorAppState extends State<AgentJobMonitorApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agent Job Monitor Dashboard',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0288D1),
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0288D1),
          brightness: Brightness.dark,
          surface: const Color(0xFF131722),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: AnimatedBuilder(
        animation: widget.auth,
        builder: (context, _) {
          final auth = widget.auth;
          if (auth.restoring) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!auth.signedIn) return LoginPage(auth: auth);
          return DashboardScreen(
            key: ValueKey(auth.user!.id),
            auth: auth,
            onToggleTheme: _toggleTheme,
            isDarkMode: _themeMode == ThemeMode.dark,
          );
        },
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final JobService? jobService;
  final BukImportService? bukService;
  final BukImportService? sclService;
  final AuthService? auth;

  const DashboardScreen({
    super.key,
    this.auth,
    required this.onToggleTheme,
    required this.isDarkMode,
    this.jobService,
    this.bukService,
    this.sclService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final JobService _jobService;
  late final BukImportService _bukService;
  late final BukImportService _sclService;

  @override
  void initState() {
    super.initState();
    final auth = widget.auth;
    _jobService =
        widget.jobService ??
        JobService(
          authHeaders: auth?.authHeaders,
          onUnauthorized: auth?.handleUnauthorized,
        );
    _bukService =
        widget.bukService ??
        BukImportService(
          authHeaders: auth?.authHeaders,
          onUnauthorized: auth?.handleUnauthorized,
        );
    _sclService =
        widget.sclService ??
        BukImportService.scl(
          authHeaders: auth?.authHeaders,
          onUnauthorized: auth?.handleUnauthorized,
        );
    _jobService.attachImport(_bukService);
    _jobService.attachImport(_sclService);
  }

  @override
  void dispose() {
    _jobService.dispose();
    _bukService.dispose();
    _sclService.dispose();
    super.dispose();
  }

  /// Shows why the job list is empty instead of failing silently.
  Widget _buildErrorBanner(BuildContext context) {
    final msg = _jobService.errorMessage;
    if (msg == null) return const SizedBox.shrink();
    return Container(
      key: const Key('jobs-error-banner'),
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Could not load jobs: $msg',
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _jobService,
      builder: (context, _) {
        final filteredJobs = _jobService.filteredAndSortedJobs;

        return Scaffold(
          appBar: _buildAppBar(context),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              if (isWide) {
                // Wide Screen Split-View Layout
                return Column(
                  children: [
                    // Top Stats Bar
                    StatsOverviewBar(jobService: _jobService),
                    _buildErrorBanner(context),

                    // Main Split Pane
                    Expanded(
                      child: Row(
                        children: [
                          // Left Pane: Filters & Job List
                          SizedBox(
                            width: 440,
                            child: Column(
                              children: [
                                AdvancedFilterPanel(jobService: _jobService),
                                _buildJobListHeader(filteredJobs.length),
                                Expanded(child: _buildJobsList(filteredJobs)),
                              ],
                            ),
                          ),

                          // Vertical Divider
                          Container(
                            width: 1,
                            color: widget.isDarkMode
                                ? const Color(0xFF262C3D)
                                : const Color(0xFFE2E8F0),
                          ),

                          // Right Pane: Job Detail View with Stepper and Logs
                          Expanded(
                            child: JobDetailView(jobService: _jobService),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                // Mobile / Compact Layout
                return Column(
                  children: [
                    StatsOverviewBar(jobService: _jobService),
                    _buildErrorBanner(context),
                    AdvancedFilterPanel(jobService: _jobService),
                    _buildJobListHeader(filteredJobs.length),
                    Expanded(
                      child: _buildJobsList(
                        filteredJobs,
                        onJobTap: (job) {
                          _jobService.selectJob(job);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                  title: Text(job.title),
                                  actions: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: StatusBadge.forJob(
                                        status: job.status,
                                      ),
                                    ),
                                  ],
                                ),
                                body: JobDetailView(jobService: _jobService),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isDark = widget.isDarkMode;

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF131722) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDark ? const Color(0xFF262C3D) : const Color(0xFFE2E8F0),
          height: 1,
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0288D1), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.hub_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AGENT JOB MONITOR',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Agent Orchestration & Real-time Step Logs',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Trigger New Agent Job
        FilledButton.icon(
          onPressed: () => _jobService.triggerNewAgentJob(),
          icon: const Icon(Icons.add_task_rounded, size: 16),
          label: const Text('Trigger New Job', style: TextStyle(fontSize: 12)),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0288D1),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Dark/Light toggle
        IconButton(
          tooltip: widget.isDarkMode ? 'Light Mode' : 'Dark Mode',
          icon: Icon(
            widget.isDarkMode
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            size: 19,
          ),
          onPressed: widget.onToggleTheme,
        ),

        if (widget.auth != null) ...[
          IconButton(
            key: const Key('sign-out'),
            tooltip:
                'Sign out ${widget.auth!.user?.email ?? widget.auth!.user?.id ?? ''}',
            icon: const Icon(Icons.logout_rounded, size: 19),
            onPressed: widget.auth!.logout,
          ),
        ],

        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildJobListHeader(int count) {
    final isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF131722) : const Color(0xFFF1F5F9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'JOBS ($count)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 6),
              if (_jobService.activeJobsCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_jobService.activeJobsCount} LIVE',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Sorted by: ${_jobService.sortOption.label} (${_jobService.sortDirection == SortDirection.descending ? 'Desc' : 'Asc'})',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsList(List<AgentJob> jobs, {Function(AgentJob)? onJobTap}) {
    if (jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list_off_rounded,
                size: 40,
                color: widget.isDarkMode
                    ? const Color(0xFF475569)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              const Text(
                'No jobs match the specified criteria',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Try clearing search query or adjusting status filters',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDarkMode
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _jobService.resetFilters(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset All Filters'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final isSelected = _jobService.selectedJob?.id == job.id;

        return JobListItem(
          job: job,
          isSelected: isSelected,
          onTap: () {
            _jobService.selectJob(job);
            if (onJobTap != null) {
              onJobTap(job);
            }
          },
        );
      },
    );
  }
}
