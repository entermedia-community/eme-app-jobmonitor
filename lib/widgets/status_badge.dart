import 'package:flutter/material.dart';

import '../models/job_model.dart';
import 'live_indicator.dart';

class StatusBadge extends StatelessWidget {
  final JobStatus? jobStatus;
  final StepStatus? stepStatus;
  final bool isLive;
  final bool compact;

  const StatusBadge.forJob({
    super.key,
    required JobStatus status,
    this.compact = false,
  }) : jobStatus = status,
       stepStatus = null,
       isLive = status == JobStatus.running;

  const StatusBadge.forStep({
    super.key,
    required StepStatus status,
    this.compact = false,
  }) : stepStatus = status,
       jobStatus = null,
       isLive = status == StepStatus.active;

  @override
  Widget build(BuildContext context) {
    if (isLive) {
      return LiveIndicator(
        label: jobStatus != null ? 'ACTIVE' : 'RUNNING',
        compact: compact,
      );
    }

    final color = jobStatus?.color ?? stepStatus?.color ?? Colors.grey;
    final icon = jobStatus?.icon ?? stepStatus?.icon ?? Icons.circle;
    final label = jobStatus?.label ?? stepStatus?.label ?? 'Unknown';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 10.5 : 11.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
