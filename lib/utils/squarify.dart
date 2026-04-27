import 'dart:math' as math;
import 'dart:ui';

/// One placed tile in the squarified layout.
class SquarifiedTile<T> {
  final T ref;
  final Rect rect;
  const SquarifiedTile({required this.ref, required this.rect});
}

class _Item<T> {
  final double value;
  final T ref;
  const _Item(this.value, this.ref);
}

/// Squarified treemap. Lays out [items] inside [bounds] so the resulting
/// rectangles minimise aspect-ratio variance — slivers are bad, near-squares
/// are good. Items with [value] <= 0 are dropped.
///
/// Ported from the JS reference in the Aurora design bundle's
/// `iMaculate Treemap.html` so behaviour matches the prototype.
List<SquarifiedTile<T>> squarify<T>({
  required List<({double value, T ref})> items,
  required Rect bounds,
}) {
  final positives = items
      .where((e) => e.value > 0)
      .map((e) => _Item<T>(e.value, e.ref))
      .toList();
  if (positives.isEmpty) return const [];

  final total = positives.fold<double>(0, (a, b) => a + b.value);
  if (total == 0) return const [];

  // Sort descending so big tiles get committed first.
  positives.sort((a, b) => b.value.compareTo(a.value));

  // Scale each value so its area equals the slice of the bounds rectangle.
  final area = bounds.width * bounds.height;
  final scaled = positives.map((i) => i.value * area / total).toList();
  final refs = positives.map((i) => i.ref).toList();

  final out = <SquarifiedTile<T>>[];
  var x = bounds.left;
  var y = bounds.top;
  var w = bounds.width;
  var h = bounds.height;
  final row = <double>[];
  final rowRefs = <T>[];
  var i = 0;

  void commitRow() {
    if (row.isEmpty) return;
    final length = math.min(w, h);
    final s = row.fold<double>(0, (a, b) => a + b);
    final isHoriz = w >= h;
    final thick = s / length;
    var off = 0.0;
    for (var k = 0; k < row.length; k++) {
      final sz = row[k] / s * length;
      final r = isHoriz
          ? Rect.fromLTWH(x, y + off, thick, sz)
          : Rect.fromLTWH(x + off, y, sz, thick);
      out.add(SquarifiedTile(ref: rowRefs[k], rect: r));
      off += sz;
    }
    if (isHoriz) {
      x += thick;
      w -= thick;
    } else {
      y += thick;
      h -= thick;
    }
    row.clear();
    rowRefs.clear();
  }

  double worst(List<double> r, double length) {
    if (r.isEmpty) return double.infinity;
    final s = r.fold<double>(0, (a, b) => a + b);
    final mx = r.reduce(math.max);
    final mn = r.reduce(math.min);
    return math.max(
      length * length * mx / (s * s),
      s * s / (length * length * mn),
    );
  }

  while (i < scaled.length) {
    final length = math.min(w, h);
    if (length <= 0) break;
    final v = scaled[i];
    final candidate = [...row, v];
    if (row.isEmpty || worst(candidate, length) <= worst(row, length)) {
      row.add(v);
      rowRefs.add(refs[i]);
      i++;
    } else {
      commitRow();
    }
  }
  commitRow();

  return out;
}
