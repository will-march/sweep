import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/models/storage_category.dart';

void main() {
  final home = Platform.environment['HOME'] ?? '/Users/test';

  group('CategoryClassifier.categorize', () {
    test('paths under /Applications classify as apps', () {
      expect(
        CategoryClassifier.categorize('/Applications'),
        StorageCategory.apps,
      );
      expect(
        CategoryClassifier.categorize('/Applications/Xcode.app'),
        StorageCategory.apps,
      );
    });

    test('any path ending in .app is apps', () {
      expect(
        CategoryClassifier.categorize('$home/Tools/Foo.app'),
        StorageCategory.apps,
      );
    });

    test('caches and logs route to cache', () {
      expect(
        CategoryClassifier.categorize('$home/Library/Caches'),
        StorageCategory.cache,
      );
      expect(
        CategoryClassifier.categorize('$home/Library/Logs'),
        StorageCategory.cache,
      );
      expect(
        CategoryClassifier.categorize('/Library/Caches/com.apple.Foo'),
        StorageCategory.cache,
      );
    });

    test('developer tooling routes to dev', () {
      expect(
        CategoryClassifier.categorize('$home/Library/Developer'),
        StorageCategory.dev,
      );
      expect(
        CategoryClassifier.categorize('$home/.npm'),
        StorageCategory.dev,
      );
      expect(
        CategoryClassifier.categorize('$home/.gradle/caches'),
        // .gradle is dev tooling; the substring "/caches" wins per ordering.
        StorageCategory.cache,
      );
    });

    test('system paths route to sys', () {
      expect(
        CategoryClassifier.categorize('/System'),
        StorageCategory.sys,
      );
      expect(
        CategoryClassifier.categorize('/private/var/log'),
        // /private/var/log contains "/log"? It does not contain "/logs" or
        // "/cache". Should route to sys.
        StorageCategory.sys,
      );
    });

    test('media folders route to media', () {
      expect(
        CategoryClassifier.categorize('$home/Movies'),
        StorageCategory.media,
      );
      expect(
        CategoryClassifier.categorize('$home/Pictures'),
        StorageCategory.media,
      );
      expect(
        CategoryClassifier.categorize('$home/Music/Library'),
        StorageCategory.media,
      );
    });

    test('docs folders route to docs', () {
      expect(
        CategoryClassifier.categorize('$home/Documents'),
        StorageCategory.docs,
      );
      expect(
        CategoryClassifier.categorize('$home/Downloads'),
        StorageCategory.docs,
      );
    });

    test('non-matching path falls back to other', () {
      expect(
        CategoryClassifier.categorize('/some/random/path'),
        StorageCategory.other,
      );
    });
  });

  group('CategoryClassifier.isReclaimable', () {
    test('cache directories are reclaimable', () {
      expect(
        CategoryClassifier.isReclaimable('$home/Library/Caches'),
        isTrue,
      );
      expect(
        CategoryClassifier.isReclaimable('$home/Library/Logs'),
        isTrue,
      );
    });

    test('Xcode DerivedData is reclaimable', () {
      expect(
        CategoryClassifier.isReclaimable(
          '$home/Library/Developer/Xcode/DerivedData',
        ),
        isTrue,
      );
    });

    test('build tool caches are reclaimable', () {
      expect(CategoryClassifier.isReclaimable('$home/.npm'), isTrue);
      expect(
        CategoryClassifier.isReclaimable('$home/.gradle/caches'),
        isTrue,
      );
      expect(
        CategoryClassifier.isReclaimable('$home/.cargo/registry'),
        isTrue,
      );
    });

    test('user data is NOT reclaimable', () {
      expect(
        CategoryClassifier.isReclaimable('$home/Documents'),
        isFalse,
      );
      expect(CategoryClassifier.isReclaimable('$home/Movies'), isFalse);
      expect(
        CategoryClassifier.isReclaimable('/Applications/Xcode.app'),
        isFalse,
      );
    });
  });
}
