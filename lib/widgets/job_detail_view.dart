import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/job_model.dart';
import '../services/job_service.dart';
import 'live_indicator.dart';
import 'status_badge.dart';
import 'step_log_viewer.dart';

class JobDetailView extends StatelessWidget {
  final JobService jobService;

  const JobDetailView({super.key, required this.jobService});

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('MMM d, yyyy • HH:mm:ss').format(dt);
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes == 0) {
      return '${d.inSeconds} seconds';
    } else if (d.inHours == 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    } else {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
  }

  Future<void> _handleRunJob(BuildContext context, AgentJob job) async {
    if (jobService.isImportJob(job.id)) {
      final msg = await jobService.runImport(job.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg ?? '${job.agentName} import started.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (job.status == JobStatus.running) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final shouldRestart = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2433) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF59E0B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Job Already Running',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Job "${job.id}" is currently in progress. Do you want to stop it and restart execution from the beginning?',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Stop & Restart'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldRestart == true) {
        jobService.runJob(job.id, restart: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Job "${job.id}" stopped and restarted.'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      jobService.runJob(job.id, restart: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Job "${job.id}" started.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildStopButton(BuildContext context, AgentJob job) {
    final stopping = jobService.isStopping(job.id);
    return InkWell(
      key: const Key('stop-job'),
      onTap: stopping ? null : () => _handleStopJob(context, job),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 18, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: stopping ? Colors.grey : const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              stopping ? Icons.hourglass_top_rounded : Icons.stop_rounded,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              stopping ? 'Stopping' : 'Stop',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStopJob(BuildContext context, AgentJob job) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2433) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        title: Text(
          'Stop job?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Job "${job.id}" will stop after the step that is running now. '
          'The remaining steps will not run.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep running',
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          FilledButton.icon(
            key: const Key('confirm-stop-job'),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.stop_rounded, size: 16),
            label: const Text('Stop job'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await jobService.stopJob(job.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Job "${job.id}" stopped.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final job = jobService.selectedJob;

    if (job == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 48,
              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Text(
              'Select a job to inspect orchestrated steps & logs',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final selectedStep = job.steps.firstWhere(
      (s) => s.id == jobService.selectedStepId,
      orElse: () => job.steps.isNotEmpty ? job.steps.first : job.steps.first,
    );

    // Imports can't be restarted mid-import: the button waits until it finishes.
    final disableRun =
        jobService.isImportJob(job.id) && job.status == JobStatus.running;

    return Container(
      color: isDark ? const Color(0xFF0F141E) : const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Job Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B26) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF262C3D)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Agent info, status, actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Agent Name & Role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF262C3D)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  job.id,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  job.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            job.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF475569),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const SizedBox(height: 2),
                          Text(
                            job.agentRole,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusBadge.forJob(status: job.status),
                        const SizedBox(width: 8),
                        // RUN button
                        //                   padding: EdgeInsets.symmetric(
                        //   horizontal: compact ? 7 : 9,
                        //   vertical: compact ? 3 : 4,
                        // ),
                        // decoration: BoxDecoration(
                        //   color: color.withValues(alpha: 0.12),
                        //   borderRadius: BorderRadius.circular(compact ? 12 : 16),
                        //   border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
                        // ),
                        InkWell(
                          key: const Key('run-job'),
                          onTap: disableRun
                              ? null
                              : () => _handleRunJob(context, job),
                          child: Container(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 18,
                              top: 6,
                              bottom: 6,
                            ),
                            decoration: BoxDecoration(
                              color: disableRun ? Colors.grey : Colors.green,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  disableRun
                                      ? Icons.sync_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  disableRun ? 'Running' : 'Run',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (jobService.canStop(job)) ...[
                          const SizedBox(width: 8),
                          _buildStopButton(context, job),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Metadata Chips Bar
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildMetaItem(
                      icon: Icons.calendar_today_rounded,
                      label: 'Created',
                      value: _formatDateTime(job.createdAt),
                      isDark: isDark,
                    ),
                    _buildMetaItem(
                      icon: Icons.timelapse_rounded,
                      label: 'Elapsed',
                      value: _formatDuration(job.duration),
                      isDark: isDark,
                    ),
                    _buildMetaItem(
                      icon: Icons.account_tree_outlined,
                      label: 'Steps',
                      value:
                          '${job.completedStepsCount}/${job.totalStepsCount} completed',
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Orchestrated Steps Navigation Stepper
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131722) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF262C3D)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ORCHESTRATED STEPS TIMELINE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Click step to inspect stream logs',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Horizontal Stepper Bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < job.steps.length; i++) ...[
                        _buildStepNode(
                          step: job.steps[i],
                          isSelected: job.steps[i].id == selectedStep.id,
                          onTap: () => jobService.selectStep(job.steps[i].id),
                          isDark: isDark,
                        ),
                        if (i < job.steps.length - 1)
                          Container(
                            width: 24,
                            height: 2,
                            color: isDark
                                ? const Color(0xFF2E384D)
                                : const Color(0xFFCBD5E1),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Log Viewer Container
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: StepLogViewer(
                step: selectedStep,
                isLive: selectedStep.status == StepStatus.active,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required JobStep step,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    Color nodeColor;
    IconData nodeIcon;

    switch (step.status) {
      case StepStatus.succeeded:
        nodeColor = const Color(0xFF0288D1);
        nodeIcon = Icons.check_rounded;
        break;
      case StepStatus.failed:
        nodeColor = const Color(0xFFEF4444);
        nodeIcon = Icons.close_rounded;
        break;
      case StepStatus.active:
        nodeColor = const Color(0xFF00E676);
        nodeIcon = Icons.sync_rounded;
        break;
      case StepStatus.pending:
        nodeColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
        nodeIcon = Icons.more_horiz_rounded;
        break;
      case StepStatus.skipped:
        nodeColor = const Color(0xFF757575);
        nodeIcon = Icons.redo_rounded;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
              : (isDark ? const Color(0xFF161B26) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0288D1)
                : (isDark ? const Color(0xFF262C3D) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Circle Icon
            if (step.status == StepStatus.active)
              const LiveIndicator(size: 6, showLabel: false)
            else
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: nodeColor.withValues(alpha: 0.18),
                  border: Border.all(color: nodeColor, width: 1.2),
                ),
                child: Icon(nodeIcon, size: 11, color: nodeColor),
              ),

            const SizedBox(width: 8),

            // Step info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Step ${step.order}: ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      step.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (step.status == StepStatus.active) ...[
                      const SizedBox(width: 6),
                      const LiveIndicator(size: 5, compact: true),
                    ],
                  ],
                ),
                if (step.toolName != null)
                  Text(
                    'Tool: ${step.toolName}',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}
