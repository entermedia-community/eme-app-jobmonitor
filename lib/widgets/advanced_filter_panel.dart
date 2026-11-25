import 'package:flutter/material.dart';

import '../models/job_model.dart';
import '../services/job_service.dart';

class AdvancedFilterPanel extends StatefulWidget {
  final JobService jobService;

  const AdvancedFilterPanel({super.key, required this.jobService});

  @override
  State<AdvancedFilterPanel> createState() => _AdvancedFilterPanelState();
}

class _AdvancedFilterPanelState extends State<AdvancedFilterPanel> {
  final TextEditingController _searchController = TextEditingController();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.jobService.filter.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final service = widget.jobService;
    final filter = service.filter;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF262C3D) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary Search & Sort Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2433) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF333E54)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search jobs (param: search)...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  service.setSearchQuery('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                      onChanged: (val) {
                        service.setSearchQuery(val);
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Refresh API Button
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    tooltip: 'Refresh jobs from API endpoint',
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF1E2433)
                          : Colors.white,
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF333E54)
                            : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: service.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0288D1),
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: Color(0xFF0288D1),
                          ),
                    onPressed: service.isLoading
                        ? null
                        : () => service.fetchJobs(),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Toggle Advanced Filters Button
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: filter.hasActiveFilters
                        ? const Color(0xFF0288D1).withValues(alpha: 0.12)
                        : (isDark ? const Color(0xFF1E2433) : Colors.white),
                    foregroundColor: filter.hasActiveFilters
                        ? const Color(0xFF0288D1)
                        : (isDark ? Colors.white : Colors.black87),
                    side: BorderSide(
                      color: filter.hasActiveFilters
                          ? const Color(0xFF0288D1)
                          : (isDark
                                ? const Color(0xFF333E54)
                                : const Color(0xFFCBD5E1)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: filter.hasActiveFilters
                        ? const Color(0xFF0288D1)
                        : null,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Filters', style: TextStyle(fontSize: 11.5)),
                      if (filter.activeFiltersCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0288D1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${filter.activeFiltersCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 2),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 14,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'SORT:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<JobSortOption>(
                      tooltip: 'Select sort option',
                      initialValue: service.sortOption,
                      onSelected: (option) => service.setSortOption(option),
                      color: isDark ? const Color(0xFF1E2433) : Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF333E54)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      offset: const Offset(0, 36),
                      itemBuilder: (context) {
                        return JobSortOption.values.map((option) {
                          final isSelected = service.sortOption == option;
                          return PopupMenuItem<JobSortOption>(
                            value: option,
                            height: 38,
                            child: Row(
                              children: [
                                Icon(
                                  option.icon,
                                  size: 15,
                                  color: isSelected
                                      ? const Color(0xFF0288D1)
                                      : (isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark
                                              ? Colors.white
                                              : const Color(0xFF0288D1))
                                        : (isDark
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF334155)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E2433)
                              : const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF333E54)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              service.sortOption.icon,
                              size: 13,
                              color: const Color(0xFF0288D1),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              service.sortOption.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 15,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Sort Direction Button
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        tooltip:
                            service.sortDirection == SortDirection.descending
                            ? 'Descending (Click to sort Ascending)'
                            : 'Ascending (Click to sort Descending)',
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF1E2433)
                              : Colors.white,
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF333E54)
                                : const Color(0xFFCBD5E1),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          service.sortDirection == SortDirection.descending
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size: 13,
                          color: const Color(0xFF38BDF8),
                        ),
                        onPressed: () {
                          service.setSortDirection(
                            service.sortDirection == SortDirection.descending
                                ? SortDirection.ascending
                                : SortDirection.descending,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Quick Sorting Preset Chips Bar
          if (_isExpanded)
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF121620)
                    : const Color(0xFFF1F5F9),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF262C3D)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF121620)
                          : const Color(0xFFF1F5F9),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Filter Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ...JobStatus.values.map((status) {
                              final isSelected = filter.selectedStatuses
                                  .contains(status);
                              return FilterChip(
                                selected: isSelected,
                                avatar: Icon(
                                  status.icon,
                                  size: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : status.color,
                                ),
                                label: Text(
                                  status.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                  ),
                                ),
                                selectedColor: status.color,
                                backgroundColor: isDark
                                    ? const Color(0xFF1E2433)
                                    : Colors.white,
                                showCheckmark: false,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isSelected
                                        ? status.color
                                        : (isDark
                                              ? const Color(0xFF333E54)
                                              : const Color(0xFFCBD5E1)),
                                  ),
                                ),
                                onSelected: (_) =>
                                    service.toggleStatusFilter(status),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Date Range & Checkboxes
                        Row(
                          spacing: 16,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Date Range
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'TIME RANGE:',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E2433)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF333E54)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<DateRangeFilter>(
                                      value: filter.dateRange,
                                      isDense: true,
                                      dropdownColor: isDark
                                          ? const Color(0xFF1E2433)
                                          : Colors.white,
                                      items: DateRangeFilter.values.map((
                                        range,
                                      ) {
                                        return DropdownMenuItem(
                                          value: range,
                                          child: Text(
                                            range.label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          service.setDateRange(val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (filter.hasActiveFilters) ...[
                              ActionChip(
                                avatar: const Icon(
                                  Icons.refresh_rounded,
                                  size: 14,
                                  color: Color(0xFFEF4444),
                                ),
                                label: const Text(
                                  'Reset Filters',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.1),
                                side: const BorderSide(
                                  color: Color(0xFFEF4444),
                                  width: 0.8,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 0,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  service.resetFilters();
                                  setState(() {});
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Expanded Filter Details Section
            ),
        ],
      ),
    );
  }
}
