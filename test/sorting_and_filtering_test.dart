import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_job_monitor/models/job_model.dart';
import 'package:agent_job_monitor/services/job_service.dart';

void main() {
  group('JobService Sorting & Filtering Tests', () {
    late JobService service;

    setUp(() {
      service = JobService(autoFetch: false);
      service.allJobs.addAll([
        AgentJob(
          id: 'TEST-1',
          title: 'Kubernetes Cluster Deployment',
          description: 'Deploy pods and configure ingress',
          agentName: 'CloudDeploy Agent',
          agentRole: 'DevOps Worker',
          agentIcon: Icons.cloud_circle_rounded,
          status: JobStatus.running,
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
          startedAt: DateTime.now().subtract(const Duration(minutes: 9)),
          steps: [
            JobStep(
              id: 'T1-S1',
              order: 1,
              name: 'Apply manifests',
              description:
                  'Render Kubernetes templates and check RBAC permissions.',
              status: StepStatus.active,
            ),
          ],
        ),
        AgentJob(
          id: 'TEST-2',
          title: 'Data Migration Pipeline',
          description: 'Batch process database tables',
          agentName: 'DataStream Agent',
          agentRole: 'Pipeline Worker',
          agentIcon: Icons.hub_rounded,
          status: JobStatus.error,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          startedAt: DateTime.now().subtract(const Duration(minutes: 50)),
          finishedAt: DateTime.now().subtract(const Duration(minutes: 40)),
          steps: [
            JobStep(
              id: 'T2-S1',
              order: 1,
              name: 'Ingest source data',
              description: 'Read source data batch',
              status: StepStatus.failed,
              errorMessage: 'Connection reset by peer',
            ),
          ],
        ),
      ]);
    });

    tearDown(() {
      service.dispose();
    });

    test('Sort by submittedDate descending (newest first)', () {
      service.setSortOption(JobSortOption.submittedDate);
      service.setSortDirection(SortDirection.descending);

      final list = service.filteredAndSortedJobs;
      expect(list.isNotEmpty, true);

      for (int i = 0; i < list.length - 1; i++) {
        expect(
          list[i].createdAt.isAfter(list[i + 1].createdAt) ||
              list[i].createdAt.isAtSameMomentAs(list[i + 1].createdAt),
          true,
        );
      }
    });

    test('Sort by startDate descending', () {
      service.setSortOption(JobSortOption.startDate);
      service.setSortDirection(SortDirection.descending);

      final list = service.filteredAndSortedJobs;
      expect(list.isNotEmpty, true);
    });

    test('Sort by endDate descending', () {
      service.setSortOption(JobSortOption.endDate);
      service.setSortDirection(SortDirection.descending);

      final list = service.filteredAndSortedJobs;
      expect(list.isNotEmpty, true);
    });

    test('Filter by search query matches title and steps', () {
      service.setSearchQuery('Kubernetes');
      final list = service.filteredAndSortedJobs;
      expect(list.isNotEmpty, true);
      for (final job in list) {
        final matches =
            job.title.contains('Kubernetes') ||
            job.description.contains('Kubernetes') ||
            job.steps.any(
              (s) =>
                  s.name.contains('Kubernetes') ||
                  s.description.contains('Kubernetes') ||
                  s.logs.any((l) => l.message.contains('Kubernetes')),
            );
        expect(matches, true);
      }
    });

    test('Filter by status only includes matching status', () {
      service.toggleStatusFilter(JobStatus.running);
      final list = service.filteredAndSortedJobs;
      expect(list.isNotEmpty, true);
      for (final job in list) {
        expect(job.status, JobStatus.running);
      }
    });

    test('Filter by only with errors', () {
      service.toggleOnlyWithErrors();
      final list = service.filteredAndSortedJobs;
      expect(list.isNotEmpty, true);
      for (final job in list) {
        final hasErrorStep = job.steps.any(
          (s) => s.status == StepStatus.failed,
        );
        expect(job.isFailed || hasErrorStep, true);
      }
    });

    test('Builds correct API URL query parameters', () {
      service.setSearchQuery('agent');
      service.toggleStatusFilter(JobStatus.running);
      service.toggleStatusFilter(JobStatus.queued);
      service.setDateRange(DateRangeFilter.last24Hours);
      service.setSortOption(JobSortOption.startDate);
      service.setSortDirection(SortDirection.ascending);

      final uri = service.buildRequestUri();
      expect(uri.queryParameters['search'], 'agent');
      // Status is filtered client-side so repeating jobs can count as queued.
      expect(uri.queryParameters.containsKey('status'), false);
      expect(uri.queryParameters['timerange'], 'last24hours');
      expect(uri.queryParameters['sortby'], 'startdate');
      expect(uri.queryParameters['sortorder'], 'asc');
    });

    test('Repeating idle jobs are listed under Queued', () {
      final repeating = AgentJob.fromJson({
        'id': 'scl_sync',
        'name': 'SCL',
        'status': 'complete',
        'repeatperiod': 'daily',
      });
      expect(repeating.matchesStatus(JobStatus.queued), true);
      expect(repeating.matchesStatus(JobStatus.complete), true);
      expect(repeating.matchesStatus(JobStatus.running), false);
      final oneOff = AgentJob.fromJson({'id': 'x', 'status': 'complete'});
      expect(oneOff.matchesStatus(JobStatus.queued), false);
    });

    test('Trigger new job inserts active job and selects it', () {
      final initialCount = service.totalJobsCount;
      service.triggerNewAgentJob();
      expect(service.totalJobsCount, initialCount + 1);
      expect(service.selectedJob?.isActive, true);
      expect(service.selectedJob?.steps.isNotEmpty, true);
    });
  });
}
