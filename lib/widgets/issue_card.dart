import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One issue found in the code. A dark card with an orange dot indicator and
/// the issue text. Code fragments inside the text stay legible via mono where
/// appropriate — here the whole line uses the UI face for readability, matching
/// the tone-adjusted descriptions coming from Gemini.
class IssueCard extends StatelessWidget {
  const IssueCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5, right: 10),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.signalOrange,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTheme.ui(size: 13, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Locked issue placeholder for the free tier — a lock glyph + blurred label,
/// shown instead of the real card until the user unlocks.
class LockedIssueCard extends StatelessWidget {
  const LockedIssueCard({super.key, required this.hint});

  /// A short teaser label (e.g. "Add rate limiting to API routes").
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 16,
            color: AppTheme.textDim.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.ui(size: 13, color: AppTheme.textDim),
            ),
          ),
        ],
      ),
    );
  }
}
