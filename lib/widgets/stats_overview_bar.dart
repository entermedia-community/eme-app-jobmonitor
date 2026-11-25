import 'package:flutter/material.dart';

import '../models/job_model.dart';
import '../services/job_service.dart';

class StatsOverviewBar extends StatelessWidget {
  final JobService jobService;

  const StatsOverviewBar({super.key, required this.jobService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final running = jobService.runningJobsCount;
    final complete = jobService.completeJobsCount;
    final error = jobService.errorJobsCount;
    final queued = jobService.queuedJobsCount;

    final activeFilterSet = jobService.filter.selectedStatuses;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        return Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131722) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF262C3D)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildStatCard(
                title: 'Running',
                value: '$running',
                icon: Icons.play_circle_fill_rounded,
                iconColor: const Color(0xFF00C853),
                isSelected: activeFilterSet.contains(JobStatus.running),
                onTap: () => jobService.toggleStatusFilter(JobStatus.running),
                compact: isNarrow,
              ),
              _buildStatCard(
                title: 'Complete',
                value: '$complete',
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF0288D1),
                isSelected: activeFilterSet.contains(JobStatus.complete),
                onTap: () => jobService.toggleStatusFilter(JobStatus.complete),
                compact: isNarrow,
              ),
              _buildStatCard(
                title: 'Error',
                value: '$error',
                icon: Icons.error_rounded,
                iconColor: const Color(0xFFE53935),
                isSelected: activeFilterSet.contains(JobStatus.error),
                onTap: () => jobService.toggleStatusFilter(JobStatus.error),
                compact: isNarrow,
              ),
              _buildStatCard(
                title: 'Queued',
                value: '$queued',
                icon: Icons.hourglass_top_rounded,
                iconColor: const Color(0xFFFFA000),
                isSelected: activeFilterSet.contains(JobStatus.queued),
                onTap: () => jobService.toggleStatusFilter(JobStatus.queued),
                compact: isNarrow,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    VoidCallback? onTap,
    required bool compact,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? iconColor.withValues(alpha: isDark ? 0.22 : 0.12)
                  : (isDark
                        ? const Color(0xFF1E2433)
                        : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? iconColor.withValues(alpha: 0.8)
                    : (isDark
                          ? const Color(0xFF2E384D)
                          : const Color(0xFFE2E8F0)),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: compact ? 13 : 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: iconColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: compact ? 10 : 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
