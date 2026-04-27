import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iMaculate/services/path_resolver.dart';

void main() {
  // Pin to whatever the test process actually has — that's what the resolver
  // reads at call time, so the assertions can use the same value.
  final home = Platform.environment['HOME'] ?? '';
  final user = Platform.environment['USER'] ?? '';

  group('expandPath', () {
    test('absolute paths pass through untouched', () {
      expect(expandPath('/Library/Caches'), '/Library/Caches');
      expect(expandPath('/var/log'), '/var/log');
    });

    test('"~" alone resolves to \$HOME', () {
      expect(expandPath('~'), home);
    });

    test('"~/Library/Caches" expands to \$HOME/Library/Caches', () {
      expect(expandPath('~/Library/Caches'), '$home/Library/Caches');
    });

    test('"\$USER" anywhere in path is replaced', () {
      expect(
        expandPath('/Users/\$USER/Documents'),
        '/Users/$user/Documents',
      );
    });

    test('"~user" (no slash) is left alone — only "~/" expands', () {
      // "~something" without a slash is rare on macOS; the resolver only
      // touches "~/" and bare "~".
      expect(expandPath('~something'), '~something');
    });
  });
}
