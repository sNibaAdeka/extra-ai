import 'analysis_trace.dart';
import 'project_audit_report.dart';

/// One past analysis for a project. Session memory (Layer 3) — the last 5 per
/// project are kept (FIFO), and the last 3 are fed back into each new request
/// so Gemini isn't amnesiac between iterations.
class PromptHistoryEntry {
  const PromptHistoryEntry({
    required this.projectPathHash,
    required this.roughPrompt,
    required this.improvedPrompt,
    required this.issuesFound,
    required this.timestamp,
    this.qualityStatus,
    this.qualitySummary,
    this.auditStatus,
    this.auditSummary,
    this.auditReport,
    this.trace,
  });

  final String projectPathHash;
  final String roughPrompt;
  final String improvedPrompt;
  final List<String> issuesFound;
  final DateTime timestamp;

  /// Local deterministic quality gate outcome at the time of generation.
  /// Nullable for older history rows created before this feature existed.
  final String? qualityStatus;
  final String? qualitySummary;
  final String? auditStatus;
  final String? auditSummary;
  final ProjectAuditReport? auditReport;
  final AnalysisTrace? trace;

  Map<String, dynamic> toMap() => {
    'projectPathHash': projectPathHash,
    'roughPrompt': roughPrompt,
    'improvedPrompt': improvedPrompt,
    'issuesFound': issuesFound,
    'timestamp': timestamp.toIso8601String(),
    'qualityStatus': qualityStatus,
    'qualitySummary': qualitySummary,
    'auditStatus': auditStatus,
    'auditSummary': auditSummary,
    'auditReport': auditReport?.toMap(),
    'trace': trace?.toMap(),
  };

  factory PromptHistoryEntry.fromMap(Map<String, dynamic> map) =>
      PromptHistoryEntry(
        projectPathHash: map['projectPathHash'] as String? ?? '',
        roughPrompt: map['roughPrompt'] as String? ?? '',
        improvedPrompt: map['improvedPrompt'] as String? ?? '',
        issuesFound: (map['issuesFound'] as List?)?.cast<String>() ?? const [],
        timestamp:
            DateTime.tryParse(map['timestamp'] as String? ?? '') ??
            DateTime.now(),
        qualityStatus: map['qualityStatus'] as String?,
        qualitySummary: map['qualitySummary'] as String?,
        auditStatus: map['auditStatus'] as String?,
        auditSummary: map['auditSummary'] as String?,
        auditReport: map['auditReport'] is Map
            ? ProjectAuditReport.fromMap(
                Map<String, dynamic>.from(map['auditReport']),
              )
            : null,
        trace: map['trace'] is Map
            ? AnalysisTrace.fromMap(Map<String, dynamic>.from(map['trace']))
            : null,
      );
}
