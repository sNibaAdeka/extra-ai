enum ProductHealthSeverity { ok, info, warning, critical }

enum ProductHealthArea { ai, project, sync, privacy, usage }

class ProductHealthItem {
  const ProductHealthItem({
    required this.area,
    required this.severity,
    required this.title,
    required this.detail,
    this.actionLabel,
  });

  final ProductHealthArea area;
  final ProductHealthSeverity severity;
  final String title;
  final String detail;
  final String? actionLabel;

  bool get needsAttention =>
      severity == ProductHealthSeverity.warning ||
      severity == ProductHealthSeverity.critical;
}

class ProductHealthReport {
  const ProductHealthReport({required this.generatedAt, required this.items});

  final DateTime generatedAt;
  final List<ProductHealthItem> items;

  ProductHealthSeverity get severity {
    if (items.any((item) => item.severity == ProductHealthSeverity.critical)) {
      return ProductHealthSeverity.critical;
    }
    if (items.any((item) => item.severity == ProductHealthSeverity.warning)) {
      return ProductHealthSeverity.warning;
    }
    if (items.any((item) => item.severity == ProductHealthSeverity.info)) {
      return ProductHealthSeverity.info;
    }
    return ProductHealthSeverity.ok;
  }

  List<ProductHealthItem> get attentionItems =>
      items.where((item) => item.needsAttention).toList(growable: false);

  int get criticalCount => items
      .where((item) => item.severity == ProductHealthSeverity.critical)
      .length;

  int get warningCount => items
      .where((item) => item.severity == ProductHealthSeverity.warning)
      .length;

  bool get readyForAnalysis => criticalCount == 0;

  String get label => switch (severity) {
    ProductHealthSeverity.ok => 'Ready',
    ProductHealthSeverity.info => 'Ready with notes',
    ProductHealthSeverity.warning => 'Needs attention',
    ProductHealthSeverity.critical => 'Blocked',
  };

  String get summary {
    if (criticalCount > 0) {
      return '$criticalCount blocking ${criticalCount == 1 ? 'issue' : 'issues'} before reliable analysis.';
    }
    if (warningCount > 0) {
      return '$warningCount warning ${warningCount == 1 ? 'needs' : 'need'} attention.';
    }
    final infoCount = items
        .where((item) => item.severity == ProductHealthSeverity.info)
        .length;
    if (infoCount > 0) {
      return 'Core flow is ready; $infoCount optional ${infoCount == 1 ? 'note' : 'notes'} available.';
    }
    return 'Gemini, project context, privacy, and sync checks look ready.';
  }

  // --- Jury-facing (dashboard strip) ------------------------------------------
  // Calm, plain language. No raw service names or error codes here — the
  // detailed, opt-in view lives in Settings.

  /// True when nothing needs the user's attention (calm state).
  bool get allClear => attentionItems.isEmpty;

  /// The single reassuring/alerting line for the dashboard.
  String get dashboardLine {
    if (allClear) return "Everything's running smoothly";
    // Surface the most severe item's plain-language consequence.
    final worst = attentionItems.first;
    switch (worst.area) {
      case ProductHealthArea.ai:
        return 'AI analysis is temporarily unavailable — check your connection';
      case ProductHealthArea.project:
        return 'No project linked yet — link one to get grounded results';
      case ProductHealthArea.usage:
        return "You've used this month's free analyses";
      case ProductHealthArea.privacy:
      case ProductHealthArea.sync:
        return 'Quality checks are temporarily limited — analysis still works';
    }
  }
}
