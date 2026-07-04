import 'package:flutter_test/flutter_test.dart';

import 'package:extra_ai/models/project_context.dart';

void main() {
  test('pathHash is deterministic and not Dart String.hashCode', () {
    const path = '/Users/me/project';
    final first = ProjectContext.stablePathHash(path);
    final second = ProjectContext.stablePathHash(path);

    expect(first, second);
    expect(first, hasLength(40));
    expect(first, isNot(path.hashCode.toString()));
  });

  test('pathHash normalizes slash direction', () {
    expect(
      ProjectContext.stablePathHash(r'C:\Users\me\project'),
      ProjectContext.stablePathHash('C:/Users/me/project'),
    );
  });
}
