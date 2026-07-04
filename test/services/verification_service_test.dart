import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/models/extra_ai_response.dart';
import 'package:extra_ai/models/user_profile.dart';
import 'package:extra_ai/services/verification_service.dart';

class _FakeCritic implements CriticModel {
  _FakeCritic({this.reply, this.error});
  final String? reply;
  final Object? error;
  String? lastPrompt;

  @override
  bool get isConfigured => true;

  @override
  Future<String?> chat(String prompt, {bool jsonMode = true}) async {
    lastPrompt = prompt;
    if (error != null) throw error!;
    return reply;
  }
}

UserProfile _profile() => UserProfile(
  experienceLevel: ExperienceLevel.vibeCoder,
  primaryTools: const ['Cursor'],
  projectFocus: ProjectFocus.clientSites,
  tonePreference: ToneLevel.explained,
  createdAt: DateTime(2026, 1, 1),
);

const _draft = ExtraAIResponse(
  improvedPrompt: 'In @style.css change .cta background to #B5E04A.',
  issues: ['Missing alt text on .hero img'],
);

void main() {
  group('VerificationService', () {
    test('parses a passing verdict', () async {
      final service = VerificationService(
        critic: _FakeCritic(
          reply:
              '{"passed": true, "failed_checks": [], "correction_instruction": null}',
        ),
      );
      final result = await service.verify(
        draft: _draft,
        originalFileContents: '--- style.css ---\n.cta { color: red; }',
        userProfile: _profile(),
      );
      expect(result, isNotNull);
      expect(result!.passed, isTrue);
      expect(result.correctionInstruction, isNull);
    });

    test('parses a failing verdict with a correction instruction', () async {
      final service = VerificationService(
        critic: _FakeCritic(
          reply:
              '{"passed": false, "failed_checks": ["1"], "correction_instruction": "Reference only class names present in style.css."}',
        ),
      );
      final result = await service.verify(
        draft: _draft,
        originalFileContents: '--- style.css ---\n.hero { }',
        userProfile: _profile(),
      );
      expect(result!.passed, isFalse);
      expect(result.failedChecks, contains('1'));
      expect(result.correctionInstruction, contains('style.css'));
    });

    test(
      'embeds the draft, ground-truth files, and experience level in the check prompt',
      () async {
        final critic = _FakeCritic(
          reply:
              '{"passed": true, "failed_checks": [], "correction_instruction": null}',
        );
        final service = VerificationService(critic: critic);
        await service.verify(
          draft: _draft,
          originalFileContents: 'GROUND_TRUTH_MARKER',
          userProfile: _profile(),
        );
        expect(critic.lastPrompt, contains('.cta background'));
        expect(critic.lastPrompt, contains('GROUND_TRUTH_MARKER'));
        expect(
          critic.lastPrompt,
          contains(_profile().experienceLevel.description),
        );
      },
    );

    test('returns null (unavailable) on malformed critic output', () async {
      final service = VerificationService(
        critic: _FakeCritic(reply: 'not json'),
      );
      final result = await service.verify(
        draft: _draft,
        originalFileContents: 'x',
        userProfile: _profile(),
      );
      expect(result, isNull);
    });

    test('returns null (unavailable) when the critic throws', () async {
      final service = VerificationService(
        critic: _FakeCritic(error: Exception('azure down')),
      );
      final result = await service.verify(
        draft: _draft,
        originalFileContents: 'x',
        userProfile: _profile(),
      );
      expect(result, isNull);
    });

    test('tolerates markdown fences around the critic JSON', () async {
      final service = VerificationService(
        critic: _FakeCritic(
          reply:
              '```json\n{"passed": true, "failed_checks": [], "correction_instruction": null}\n```',
        ),
      );
      final result = await service.verify(
        draft: _draft,
        originalFileContents: 'x',
        userProfile: _profile(),
      );
      expect(result!.passed, isTrue);
    });
  });
}
