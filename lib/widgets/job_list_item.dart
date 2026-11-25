import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/job_model.dart';
import 'status_badge.dart';

class JobListItem extends StatelessWidget {
  final AgentJob job;
  final bool isSelected;
  final VoidCallback onTap;

  const JobListItem({
    super.key,
    required this.job,
    required this.isSelected,
    required this.onTap,
  });

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return DateFormat('MMM d, HH:mm').format(dt);
    }
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes == 0) {
      return '${d.inSeconds}s';
    } else if (d.inHours == 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    } else {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isSelected
        ? const Color(0xFF0288D1)
        : (isDark ? const Color(0xFF262C3D) : const Color(0xFFE2E8F0));

    final backgroundColor = isSelected
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
        : (isDark ? const Color(0xFF161B26) : Colors.white);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0288D1).withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Agent info + Live indicator / Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Agent name & Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
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
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Status Badge or Live indicator
                StatusBadge.forJob(status: job.status, compact: true),
              ],
            ),

            const SizedBox(height: 10),

            // Job Title
            Text(
              job.title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF1E293B),
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),

            // Step Progress Bars / Dots
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: job.progressRatio,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? const Color(0xFF242C3F)
                          : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        job.isFailed
                            ? const Color(0xFFEF4444)
                            : (job.isActive
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFF0288D1)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${job.completedStepsCount}/${job.totalStepsCount} steps',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Footer info: Created time, Duration, Tags
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(job.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(job.duration),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
