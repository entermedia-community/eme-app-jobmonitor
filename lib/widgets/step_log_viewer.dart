import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/job_model.dart';
import 'live_indicator.dart';

class StepLogViewer extends StatefulWidget {
  final JobStep step;
  final bool isLive;

  const StepLogViewer({super.key, required this.step, required this.isLive});

  @override
  State<StepLogViewer> createState() => _StepLogViewerState();
}

class _StepLogViewerState extends State<StepLogViewer> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _logSearchController = TextEditingController();
  LogLevel? _selectedLevel;
  final bool _autoScroll = true;

  @override
  void didUpdateWidget(covariant StepLogViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.step.logs.length != oldWidget.step.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _logSearchController.dispose();
    super.dispose();
  }

  void _copyLogsToClipboard(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln(
      '=== Logs for Step: ${widget.step.name} (${widget.step.id}) ===',
    );
    for (var l in widget.step.logs) {
      final timeStr = DateFormat('HH:mm:ss.SSS').format(l.timestamp);
      buffer.writeln('[$timeStr] [${l.level.label}] ${l.message}');
      if (l.details != null) {
        buffer.writeln('Details: ${l.details}');
      }
    }
    if (widget.step.errorMessage != null) {
      buffer.writeln('ERROR: ${widget.step.errorMessage}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent,
              size: 18,
            ),
            SizedBox(width: 8),
            Text('Logs copied to clipboard'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _logSearchController.text.trim().toLowerCase();

    final filteredLogs = widget.step.logs.where((log) {
      if (_selectedLevel != null && log.level != _selectedLevel) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesMsg = log.message.toLowerCase().contains(query);
        final matchesDetails =
            log.details?.toLowerCase().contains(query) ?? false;
        if (!matchesMsg && !matchesDetails) return false;
      }
      return true;
    }).toList();
    final p = _LogPalette(Theme.of(context).brightness == Brightness.dark);

    return Container(
      decoration: BoxDecoration(
        color: p.bg, // Slate 900 console background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Console Header Toolbar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.header,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              border: Border(bottom: BorderSide(color: p.border, width: 1)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Title and Tool indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.terminal_rounded, size: 18, color: p.accent),
                    SizedBox(width: 8),
                    Text(
                      'STEP LOGS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: p.text,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (widget.isLive) ...[
                      SizedBox(width: 8),
                      LiveIndicator(label: 'LIVE', compact: true),
                    ],
                    if (widget.step.toolName != null) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.chip,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.step.toolName!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            color: p.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Controls: Search, Log Level Filter, Copy, Auto-scroll
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Copy logs button
                    IconButton(
                      tooltip: 'Copy all logs to clipboard',
                      style: IconButton.styleFrom(
                        backgroundColor: p.bg,
                        side: BorderSide(color: p.border2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: EdgeInsets.all(6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(Icons.copy_rounded, size: 14, color: p.muted),
                      onPressed: () => _copyLogsToClipboard(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Error Banner if Step has Failed
          if (widget.step.errorMessage != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.errBg.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFEF4444), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STEP EXECUTION FAILURE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFFEF4444),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          widget.step.errorMessage!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: p.errText,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Log Content List
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.step.status == StepStatus.pending
                                ? Icons.hourglass_empty_rounded
                                : Icons.find_in_page_outlined,
                            size: 32,
                            color: p.faint,
                          ),
                          SizedBox(height: 8),
                          Text(
                            widget.step.status == StepStatus.pending
                                ? 'Step pending execution... Awaiting agent scheduler.'
                                : (widget.step.logs.isEmpty
                                      ? 'No log entries emitted for this step.'
                                      : 'No logs match current search/filter.'),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: p.dim,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      final timeStr = DateFormat('HH:mm:ss.SSS')
                          .format(log.timestamp);

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timestamp
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: p.dim,
                                fontSize: 11.5,
                              ),
                            ),
                            SizedBox(width: 8),

                            // Log Level Tag
                            Container(
                              width: 54,
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: log.level.color.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log.level.label,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: log.level.color,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),

                            // Log Message
                            Expanded(
                              child: SelectableText(
                                log.message,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: p.text,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Log Summary Footer
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: p.footer,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
              border: Border(top: BorderSide(color: p.border, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.step.logs.length} total events (${filteredLogs.length} shown)',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: p.dim,
                  ),
                ),
                if (widget.step.duration != null)
                  Text(
                    'Step duration: ${widget.step.duration!.inSeconds}s',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: p.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogPalette {
  final bool dark;
  const _LogPalette(this.dark);
  Color _c(int d, int l) => Color(dark ? d : l);
  Color get bg => _c(0xFF0F172A, 0xFFFFFFFF);
  Color get border => _c(0xFF1E293B, 0xFFE2E8F0);
  Color get border2 => _c(0xFF334155, 0xFFCBD5E1);
  Color get header => _c(0xFF161E2E, 0xFFF1F5F9);
  Color get footer => _c(0xFF0B1120, 0xFFF8FAFC);
  Color get accent => _c(0xFF38BDF8, 0xFF0288D1);
  Color get text => _c(0xFFE2E8F0, 0xFF0F172A);
  Color get chip => _c(0xFF2E384D, 0xFFE2E8F0);
  Color get muted => _c(0xFF94A3B8, 0xFF475569);
  Color get dim => const Color(0xFF64748B);
  Color get faint => _c(0xFF475569, 0xFF94A3B8);
  Color get errText => _c(0xFFFCA5A5, 0xFFB91C1C);
  Color get errBg => _c(0xFF7F1D1D, 0xFFEF4444);
}
