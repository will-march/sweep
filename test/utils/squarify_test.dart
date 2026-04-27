import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/utils/squarify.dart';

({double value, String ref}) item(double v, String r) =>
    (value: v, ref: r);

double _intersectionArea(Rect a, Rect b) {
  final l = math.max(a.left, b.left);
  final t = math.max(a.top, b.top);
  final r = math.min(a.right, b.right);
  final btm = math.min(a.bottom, b.bottom);
  if (r <= l || btm <= t) return 0;
  return (r - l) * (btm - t);
}

void main() {
  const eps = 1e-6;

  group('squarify', () {
    test('returns empty when items list is empty', () {
      final out = squarify<String>(
        items: const [],
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(out, isEmpty);
    });

    test('drops zero/negative values', () {
      final out = squarify<String>(
        items: [item(0, 'a'), item(-2, 'b'), item(4, 'c')],
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(out, hasLength(1));
      expect(out.first.ref, 'c');
      expect(out.first.rect.width * out.first.rect.height,
          closeTo(100 * 100, eps));
    });

    test('single item fills the bounds', () {
      final out = squarify<String>(
        items: [item(7, 'only')],
        bounds: const Rect.fromLTWH(10, 20, 80, 60),
      );
      expect(out, hasLength(1));
      expect(out.first.rect, const Rect.fromLTWH(10, 20, 80, 60));
    });

    test('total area of tiles equals bounds area', () {
      final out = squarify<String>(
        items: [
          item(40, 'a'),
          item(20, 'b'),
          item(15, 'c'),
          item(10, 'd'),
          item(8, 'e'),
          item(7, 'f'),
        ],
        bounds: const Rect.fromLTWH(0, 0, 1140, 720),
      );
      final sum = out.fold<double>(
          0, (acc, t) => acc + t.rect.width * t.rect.height);
      expect(sum, closeTo(1140 * 720, 1e-3));
    });

    test('tiles do not overlap', () {
      final out = squarify<String>(
        items: List.generate(12, (i) => item((12 - i).toDouble(), 'x$i')),
        bounds: const Rect.fromLTWH(0, 0, 600, 400),
      );
      expect(out, hasLength(12));
      for (var i = 0; i < out.length; i++) {
        for (var j = i + 1; j < out.length; j++) {
          final overlap = _intersectionArea(out[i].rect, out[j].rect);
          expect(overlap, lessThan(0.5),
              reason: 'tiles $i and $j overlap by $overlap');
        }
      }
    });

    test('every tile stays inside the bounds (with float tolerance)', () {
      const bounds = Rect.fromLTWH(0, 0, 1140, 720);
      final out = squarify<String>(
        items: [
          item(78.4, 'apps'),
          item(64.2, 'lib'),
          item(88.6, 'dev'),
          item(64.0, 'movies'),
          item(28.4, 'pics'),
          item(18.2, 'music'),
          item(22.4, 'docs'),
          item(8.6, 'downloads'),
          item(14.2, 'system'),
          item(6.2, 'private'),
          item(1.4, 'npm'),
        ],
        bounds: bounds,
      );
      for (final t in out) {
        expect(t.rect.left, greaterThanOrEqualTo(bounds.left - eps));
        expect(t.rect.top, greaterThanOrEqualTo(bounds.top - eps));
        expect(t.rect.right, lessThanOrEqualTo(bounds.right + eps));
        expect(t.rect.bottom, lessThanOrEqualTo(bounds.bottom + eps));
        expect(t.rect.width, greaterThan(0));
        expect(t.rect.height, greaterThan(0));
      }
    });

    test('biggest item gets the biggest tile', () {
      final out = squarify<String>(
        items: [
          item(1, 'small'),
          item(2, 'mid'),
          item(50, 'huge'),
          item(3, 'mid2'),
        ],
        bounds: const Rect.fromLTWH(0, 0, 400, 300),
      );
      out.sort((a, b) =>
          (b.rect.width * b.rect.height).compareTo(a.rect.width * a.rect.height));
      expect(out.first.ref, 'huge');
    });

    test('handles degenerate zero-size bounds gracefully', () {
      final out = squarify<String>(
        items: [item(1, 'a'), item(2, 'b')],
        bounds: const Rect.fromLTWH(10, 10, 0, 0),
      );
      // With zero area every value scales to zero — the algorithm shouldn't
      // throw, even if no useful tiles come out.
      expect(out, isA<List<SquarifiedTile<String>>>());
    });
  });
}
