import 'package:flutter/material.dart';

import '../models/directory_info.dart';
import '../models/storage_category.dart';
import '../utils/byte_formatter.dart';
import '../utils/squarify.dart';

/// Squarified treemap view of a list of children, each rendered as a tile
/// with a tonal gradient. Mirrors the visual treatment of
/// `iMaculate Treemap.html` (Aurora design bundle): adaptive labels, focus
/// stroke, and a reclaim badge for entries the cleaner can wipe.
///
/// Single tap selects a tile (sets focused, fires [onTap]); double tap
/// drills into a tile (fires [onDoubleTap]). The two callbacks are
/// independent so callers can wire them to "show details" / "navigate".
class TreemapView extends StatefulWidget {
  final List<DirectoryInfo> entries;
  final int parentSize;
  final String parentName;
  final DirectoryInfo? focused;
  final ValueChanged<DirectoryInfo?> onHover;
  final ValueChanged<DirectoryInfo> onTap;
  final ValueChanged<DirectoryInfo> onDoubleTap;

  const TreemapView({
    super.key,
    required this.entries,
    required this.parentSize,
    required this.parentName,
    required this.focused,
    required this.onHover,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  State<TreemapView> createState() => _TreemapViewState();
}

class _TreemapViewState extends State<TreemapView> {
  List<SquarifiedTile<DirectoryInfo>> _tiles = const [];
  Size _size = Size.zero;

  void _layout(Size size) {
    if (size == _size && _tiles.length == widget.entries.length) return;
    _size = size;
    const pad = 4.0;
    final bounds = Rect.fromLTWH(
      pad,
      pad,
      (size.width - pad * 2).clamp(0, double.infinity),
      (size.height - pad * 2).clamp(0, double.infinity),
    );
    _tiles = squarify<DirectoryInfo>(
      items: widget.entries
          .where((e) => e.size > 0)
          .map((e) => (value: e.size.toDouble(), ref: e))
          .toList(),
      bounds: bounds,
    );
  }

  DirectoryInfo? _hitTest(Offset local) {
    // Walk in reverse so smaller tiles drawn later (visually on top) win.
    for (var i = _tiles.length - 1; i >= 0; i--) {
      if (_tiles[i].rect.contains(local)) return _tiles[i].ref;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _layout(size);
        // We track the most recent tap location so the deferred onTap (which
        // doesn't carry coordinates) can hit-test against the same point.
        Offset? lastTapPos;
        return MouseRegion(
          onHover: (e) => widget.onHover(_hitTest(e.localPosition)),
          onExit: (_) => widget.onHover(null),
          child: GestureDetector(
            // onTap fires after the gesture arena disambiguates from
            // onDoubleTap (~300ms). That delay is acceptable for "show
            // details" and lets us split single vs. double cleanly.
            onTapDown: (d) => lastTapPos = d.localPosition,
            onTap: () {
              final pos = lastTapPos;
              if (pos == null) return;
              final hit = _hitTest(pos);
              if (hit != null) widget.onTap(hit);
            },
            onDoubleTapDown: (d) => lastTapPos = d.localPosition,
            onDoubleTap: () {
              final pos = lastTapPos;
              if (pos == null) return;
              final hit = _hitTest(pos);
              if (hit != null) widget.onDoubleTap(hit);
            },
            child: CustomPaint(
              size: size,
              painter: _TreemapPainter(
                tiles: _tiles,
                parentSize: widget.parentSize,
                parentName: widget.parentName,
                focused: widget.focused,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TreemapPainter extends CustomPainter {
  final List<SquarifiedTile<DirectoryInfo>> tiles;
  final int parentSize;
  final String parentName;
  final DirectoryInfo? focused;

  _TreemapPainter({
    required this.tiles,
    required this.parentSize,
    required this.parentName,
    required this.focused,
  });

  static const _innerPad = 2.0;
  static const _radius = Radius.circular(6);
  static const _innerRadius = Radius.circular(3);

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradients live on the canvas widget (dual radial purple +
    // emerald) so the painter only needs to render tiles.
    for (final t in tiles) {
      final cat = CategoryClassifier.categorize(t.ref.path);
      final inset = Rect.fromLTWH(
        t.rect.left + _innerPad / 2,
        t.rect.top + _innerPad / 2,
        (t.rect.width - _innerPad).clamp(0, double.infinity),
        (t.rect.height - _innerPad).clamp(0, double.infinity),
      );
      if (inset.width <= 0 || inset.height <= 0) continue;

      final isFocused = identical(focused, t.ref);
      final rrect = RRect.fromRectAndRadius(inset, _radius);

      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cat.tone.withValues(alpha: 0.95),
            cat.base.withValues(alpha: 0.92),
          ],
        ).createShader(inset);
      canvas.drawRRect(rrect, fill);

      // Outer stroke. Brightens to white at focus.
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..color = isFocused
            ? const Color(0xFFFFFFFF)
            : const Color(0x2EFFFFFF)
        ..strokeWidth = isFocused ? 2 : 1;
      canvas.drawRRect(rrect, stroke);

      // Mini sub-grid preview on big focused tiles — design calls for it
      // when w > 200 && h > 140, on hover. Here we use it as a focus affordance.
      if (isFocused &&
          t.ref.isDirectory &&
          inset.width > 200 &&
          inset.height > 140) {
        _drawMiniGrid(canvas, inset, cat);
      }

      _drawLabels(canvas, inset, t.ref, cat);
      _drawReclaimBadge(canvas, inset, t.ref);
    }
  }

  void _drawMiniGrid(Canvas canvas, Rect inset, StorageCategory cat) {
    // Lightweight 3×2 preview hint — we don't have child-of-child data here,
    // so the design's "real children" preview becomes a soft scaffold so the
    // big tile feels alive when focused.
    final gridLeft = inset.left + 8;
    final gridTop = inset.top + 32;
    final gridW = inset.width - 16;
    final gridH = inset.height - 40;
    if (gridW <= 0 || gridH <= 0) return;

    const cols = 3, rows = 2;
    final cellW = gridW / cols;
    final cellH = gridH / rows;
    final paint = Paint()
      ..color = cat.tone.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = const Color(0x40FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = Rect.fromLTWH(
          gridLeft + c * cellW + 1,
          gridTop + r * cellH + 1,
          cellW - 2,
          cellH - 2,
        );
        final rr = RRect.fromRectAndRadius(cell, _innerRadius);
        canvas.drawRRect(rr, paint);
        canvas.drawRRect(rr, outline);
      }
    }
  }

  void _drawLabels(
    Canvas canvas,
    Rect inset,
    DirectoryInfo ref,
    StorageCategory cat,
  ) {
    final showLabel = inset.width >= 60 && inset.height >= 40;
    if (!showLabel) return;
    final showPct = inset.width >= 120 && inset.height >= 80;

    // Approximate character budget so long folder names truncate cleanly.
    final maxNameLen = (inset.width / 8.5).floor().clamp(4, 60);
    var name = ref.name;
    if (name.isEmpty) name = '/';
    if (name.length > maxNameLen) {
      name = '${name.substring(0, maxNameLen - 1)}…';
    }

    // Design uses SVG <text> with baseline y=22 from the tile top for the
    // name and y=38 for the size. SVG `y` is the baseline; Flutter paints
    // text from the top. For a 13px label with a ~10px ascent the top of
    // the text sits at roughly baseline - 12, i.e. 10px from the tile top.
    final namePainter = TextPainter(
      text: TextSpan(
        text: name,
        // .tm-tile-name — 13px / weight 600 / -0.005em.
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.065, // -0.005em on 13px
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: (inset.width - 24).clamp(0, double.infinity));
    namePainter.paint(canvas, Offset(inset.left + 12, inset.top + 10));

    final sizePainter = TextPainter(
      text: TextSpan(
        text: formatBytes(ref.size),
        // .tm-tile-size — 11px / weight 500 / opacity 0.75.
        style: const TextStyle(
          color: Color(0xBFFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Baseline 38 → top ≈ 30 for an 11px label.
    sizePainter.paint(canvas, Offset(inset.left + 12, inset.top + 30));

    if (showPct && parentSize > 0) {
      final pct = (ref.size / parentSize * 100).toStringAsFixed(1);
      final pctPainter = TextPainter(
        text: TextSpan(
          text: '$pct% of ${parentName.toUpperCase()}',
          // .tm-tile-pct — mono 9.5px / 0.04em / opacity 0.55.
          style: const TextStyle(
            color: Color(0x8CFFFFFF),
            fontSize: 9.5,
            letterSpacing: 0.38, // 0.04em on 9.5px
            fontFamily: 'SF Mono',
            fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: (inset.width - 24).clamp(0, double.infinity));
      // Design: baseline at y = h - 12. Top of glyph ≈ baseline - 8 for
      // a 9.5px font, i.e. h - 20 from the tile top.
      pctPainter.paint(
        canvas,
        Offset(
          inset.left + 12,
          inset.bottom - pctPainter.height - 9,
        ),
      );
    }
  }

  void _drawReclaimBadge(Canvas canvas, Rect inset, DirectoryInfo ref) {
    if (!CategoryClassifier.isReclaimable(ref.path)) return;
    if (inset.width < 100 || inset.height < 60) return;

    // Design: bx = x + w - 12 (badge right edge 12px from tile right);
    // badgeW=56, badgeH=18; pill bg rgba(0,0,0,0.35); top at y+8.
    const badgeH = 18.0;
    const badgeW = 56.0;
    final right = inset.right - 12;
    final bx = right - badgeW;
    final by = inset.top + 8;
    final rect = Rect.fromLTWH(bx, by, badgeW, badgeH);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(
      rr,
      Paint()..color = const Color(0x59000000), // rgba(0,0,0,0.35)
    );

    // Emerald dot — `cx = bx-46, cy = by+5, r=3` → 10px from badge left.
    canvas.drawCircle(
      Offset(bx + 10, by + badgeH / 2),
      3,
      Paint()..color = const Color(0xFF71F2A6),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: formatBytes(ref.size),
        // mono 10px / weight 600 / 0.04em / #71f2a6.
        style: const TextStyle(
          color: Color(0xFF71F2A6),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          fontFamily: 'SF Mono',
          fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: badgeW - 20);
    // Text x = bx-38 in the design (8px after the dot's right edge).
    tp.paint(canvas, Offset(bx + 18, by + (badgeH - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_TreemapPainter old) =>
      old.tiles != tiles ||
      old.focused != focused ||
      old.parentSize != parentSize ||
      old.parentName != parentName;
}
