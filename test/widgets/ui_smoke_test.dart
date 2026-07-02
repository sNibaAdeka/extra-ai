import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_ai/app/app_state.dart' show VerificationStatus;
import 'package:extra_ai/features/loading_view.dart';
import 'package:extra_ai/features/onboarding/onboarding_flow.dart';
import 'package:extra_ai/features/prompt_input.dart';
import 'package:extra_ai/features/results_view.dart';
import 'package:extra_ai/models/extra_ai_response.dart';
import 'package:extra_ai/models/user_profile.dart';
import 'package:extra_ai/widgets/logo_mark.dart';
import 'package:extra_ai/widgets/pill_widget.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 380, height: 580, child: child)),
    );

void main() {
  testWidgets('LogoMark and PillWidget render', (tester) async {
    await tester.pumpWidget(_host(const Column(
      children: [LogoMark(), PillWidget()],
    )));
    expect(find.byType(LogoMark), findsWidgets);
    expect(find.text('Extra AI'), findsOneWidget);
    expect(find.text('⌘⇧E'), findsOneWidget);
  });

  testWidgets('PromptInput blocks analyze on empty prompt', (tester) async {
    var analyzed = false;
    await tester.pumpWidget(_host(PromptInput(
      onAnalyze: (_) => analyzed = true,
      onPickFiles: () {},
    )));
    await tester.tap(find.text('Analyze'));
    await tester.pump();
    expect(analyzed, isFalse);
    expect(find.text('Write what you want to change first.'), findsOneWidget);
  });

  testWidgets('PromptInput forwards a valid prompt', (tester) async {
    String? captured;
    await tester.pumpWidget(_host(PromptInput(
      onAnalyze: (p) => captured = p,
      onPickFiles: () {},
    )));
    await tester.enterText(
        find.byType(TextField), 'make the hero responsive on mobile');
    await tester.tap(find.text('Analyze'));
    await tester.pump();
    expect(captured, 'make the hero responsive on mobile');
  });

  testWidgets('PromptInput shows the broad-prompt hint for a vague prompt',
      (tester) async {
    await tester.pumpWidget(_host(PromptInput(
      onAnalyze: (_) {},
      onPickFiles: () {},
    )));
    await tester.enterText(find.byType(TextField), 'fix');
    await tester.pump();
    expect(find.textContaining('pretty broad'), findsOneWidget);
  });

  testWidgets('LoadingView renders its title', (tester) async {
    await tester.pumpWidget(_host(const LoadingView(
      title: 'Reading your screen...',
      subtitle: 'and 4 project files',
    )));
    await tester.pump();
    expect(find.text('Reading your screen...'), findsOneWidget);
    expect(find.text('and 4 project files'), findsOneWidget);
  });

  testWidgets('ResultsView shows improved prompt and issues', (tester) async {
    const response = ExtraAIResponse(
      improvedPrompt: 'Update the .cta button in style.css to purple.',
      issues: ['Missing alt text', 'No mobile breakpoint'],
    );
    await tester.pumpWidget(_host(ResultsView(
      response: response,
      onCopyInsert: () {},
      onEdit: () {},
    )));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('.cta button'), findsOneWidget);
    expect(find.text('Missing alt text'), findsOneWidget);
    expect(find.text('Copy & Insert'), findsOneWidget);
  });

  testWidgets('ResultsView shows locked issues + Unlock on free tier',
      (tester) async {
    const response = ExtraAIResponse(
      improvedPrompt: 'Do the thing.',
      issues: ['Add rate limiting', 'Improve query perf', 'Validate input'],
    );
    await tester.pumpWidget(_host(ResultsView(
      response: response,
      issuesLocked: true,
      onUnlock: () {},
      onCopyInsert: () {},
      onEdit: () {},
    )));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Unlock'), findsOneWidget);
  });

  testWidgets('ResultsView shows a Verified chip when the critic passed',
      (tester) async {
    const response = ExtraAIResponse(improvedPrompt: 'Do X.', issues: ['a']);
    await tester.pumpWidget(_host(ResultsView(
      response: response,
      verificationStatus: VerificationStatus.verified,
      onCopyInsert: () {},
      onEdit: () {},
    )));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('ResultsView shows the honest note when the check was unavailable',
      (tester) async {
    const response = ExtraAIResponse(improvedPrompt: 'Do X.', issues: ['a']);
    await tester.pumpWidget(_host(ResultsView(
      response: response,
      verificationStatus: VerificationStatus.unavailable,
      onCopyInsert: () {},
      onEdit: () {},
    )));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Quality check unavailable'), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
  });

  testWidgets('Onboarding walks 3 steps and gates the final CTA',
      (tester) async {
    UserProfile? completed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 980,
          height: 640,
          child: OnboardingFlow(onComplete: (p) => completed = p),
        ),
      ),
    ));
    // Step 1 — welcome.
    expect(find.text('Welcome to Extra AI'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    // Step 2 — hotkey.
    expect(find.text('Set your hotkey'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    // Step 3 — questions; CTA disabled until required selections made.
    expect(find.text('A few quick questions'), findsOneWidget);
    Future<void> tapVisible(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pump();
    }

    await tapVisible('Start using Extra AI');
    expect(completed, isNull); // gated

    await tapVisible('I vibe-code');
    await tapVisible('Cursor');
    await tapVisible('SaaS');
    await tapVisible('Start using Extra AI');
    expect(completed, isNotNull);
    expect(completed!.primaryTools, contains('Cursor'));
    expect(completed!.tonePreference, ToneLevel.explained); // default kept
  });
}
