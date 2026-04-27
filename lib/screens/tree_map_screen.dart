import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/directory_info.dart';
import '../models/storage_category.dart';
import '../services/disk_scanner.dart';
import '../services/disk_stats_service.dart';
import '../services/exclusion_service.dart';
import '../services/trash_service.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';
import '../widgets/treemap_view.dart';

// Style constants ported 1:1 from `iMaculate Treemap.html` (Aurora design
// bundle). Names mirror the CSS variables / inline values so the design and
// the code can be diffed by eye.

// Page surface (always dark, matches `body { background: #08060f }`).
const _kPageBg = Color(0xFF08060F);
// Window surface (`.tm-window { background: var(--n-6) }`).
const _kWindowBg = AuroraTokens.n6;
// Detail panel surface (`.tm-detail { background: var(--n-4) }`).
const _kDetailBg = AuroraTokens.n4;
// Borders / dividers between window sections.
const _kBorderSubtle = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
const _kBorderHairline = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
// Eyebrow / accent purple (`var(--p-70)`).
const _kAccent = AuroraTokens.p70;
// Whites at the alphas the design uses.
const _kWhite100 = Color(0xFFFFFFFF);
const _kWhite85 = Color(0xD9FFFFFF);
const _kWhite70 = Color(0xB3FFFFFF);
const _kWhite60 = Color(0x99FFFFFF);
const _kWhite45 = Color(0x73FFFFFF);
const _kWhite40 = Color(0x66FFFFFF);
const _kWhite30 = Color(0x4DFFFFFF);
const _kWhite8 = Color(0x14FFFFFF);
const _kWhite4 = Color(0x0AFFFFFF);

// Reclaim badge text & swatch (`#71f2a6`, the scrub80 emerald sibling).
const _kReclaim = Color(0xFF71F2A6);

class TreeMapScreen extends StatefulWidget {
  final bool privileged;
  const TreeMapScreen({super.key, required this.privileged});

  @override
  State<TreeMapScreen> createState() => _TreeMapScreenState();
}

class _TreeMapScreenState extends State<TreeMapScreen> {
  DiskScanner _scanner = DiskScanner();
  final _trash = TrashService();
  final _diskStats = DiskStatsService();
  final _exclusions = ExclusionService();

  late final List<String> _stack = [Platform.environment['HOME'] ?? '/'];

  List<DirectoryInfo> _entries = const [];
  bool _scanning = true;
  String _scanCurrent = '';
  int _scanDone = 0;
  int _scanTotal = 0;
  StreamSubscription<ScanProgress>? _sub;

  DirectoryInfo? _focused;
  DiskStats? _stats;

  @override
  void initState() {
    super.initState();
    _scan();
    _diskStats.read().then((s) {
      if (mounted) setState(() => _stats = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String get _currentPath => _stack.last;

  void _scan() async {
    _sub?.cancel();
    setState(() {
      _scanning = true;
      _scanCurrent = '';
      _scanDone = 0;
      _scanTotal = 0;
      _entries = const [];
      _focused = null;
    });
    // Refresh excluded set on every scan so user edits in the
    // Exclusions screen take effect on the next rescan without app
    // restart.
    final excluded = (await _exclusions.readAll()).toSet();
    _scanner = DiskScanner(excludedPaths: excluded);
    _sub = _scanner.scan(_currentPath).listen((p) {
      if (!mounted) return;
      setState(() {
        _scanCurrent = p.currentPath;
        _scanDone = p.done;
        _scanTotal = p.total;
        _entries = p.entries;
        _scanning = !p.finished;
      });
    });
  }

  void _drillInto(DirectoryInfo info) {
    if (info.isDirectory) {
      setState(() => _stack.add(info.path));
      _scan();
    } else {
      Process.run('open', ['-R', info.path]);
    }
  }

  void _up() {
    if (_stack.length <= 1) return;
    setState(_stack.removeLast);
    _scan();
  }

  void _home() {
    final home = Platform.environment['HOME'] ?? '/';
    setState(() {
      _stack
        ..clear()
        ..add(home);
    });
    _scan();
  }

  void _crumbTap(int index) {
    if (index >= _stack.length - 1) return;
    setState(() {
      _stack.removeRange(index + 1, _stack.length);
    });
    _scan();
  }

  Future<void> _trashFocused() async {
    final f = _focused;
    if (f == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Move ${f.name} to Trash?'),
        content: Text(
          'You can restore from the Trash until you empty it.\n\n${f.path}',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _trash.moveToTrash(f.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved ${f.name} to Trash')),
      );
      _scan();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not move to Trash: $e')),
      );
    }
  }

  void _reveal(DirectoryInfo info) {
    Process.run('open', ['-R', info.path]);
  }

  int get _viewSize => _entries.fold<int>(0, (a, e) => a + e.size);
  int get _viewReclaim => _entries
      .where((e) => CategoryClassifier.isReclaimable(e.path))
      .fold<int>(0, (a, e) => a + e.size);

  @override
  Widget build(BuildContext context) {
    final selected = _focused;
    return ColoredBox(
      // `body { background: #08060f }`.
      color: _kPageBg,
      child: Padding(
        // `.tm-page { padding: 32px }`.
        padding: const EdgeInsets.all(32),
        child: Container(
          // `.tm-window { background: var(--n-6); border: 1px solid
          // rgba(255,255,255,0.06); border-radius: 14px;
          // box-shadow: 0 30px 80px rgba(0,0,0,0.6); }`.
          decoration: BoxDecoration(
            color: _kWindowBg,
            border: Border.all(color: _kBorderSubtle),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 80,
                offset: Offset(0, 30),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // .tm-header
              _Header(
                stack: _stack,
                viewSize: _viewSize,
                viewItems: _entries.length,
                viewReclaim: _viewReclaim,
                totalDiskBytes: _stats?.totalBytes,
                usedDiskBytes: _stats?.usedBytes,
                onCrumbTap: _crumbTap,
                onUp: _stack.length > 1 ? _up : null,
                onHome: _home,
                onRescan: _scanning ? null : _scan,
              ),
              // `.tm-header { border-bottom: 1px solid rgba(255,255,255,0.05) }`.
              const Divider(height: 1, thickness: 1, color: _kBorderHairline),
              // .tm-body — `grid-template-columns: 1fr 320px; height: 720px`.
              Expanded(
                child: _entries.isEmpty && !_scanning
                    ? const _EmptyState()
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _Canvas(
                              entries: _entries,
                              parentSize: _viewSize,
                              parentName: _stack.last
                                  .split('/')
                                  .where((s) => s.isNotEmpty)
                                  .lastOrNull ??
                                  'Root',
                              focused: _focused,
                              scanning: _scanning,
                              scanPath: _scanCurrent,
                              scanDone: _scanDone,
                              scanTotal: _scanTotal,
                              onSelect: (f) =>
                                  setState(() => _focused = f),
                              onDrill: _drillInto,
                              onUp: _stack.length > 1 ? _up : null,
                              onHome: _home,
                            ),
                          ),
                          _DetailPanel(
                            focused: selected,
                            current: _viewSize,
                            currentItems: _entries.length,
                            totalDiskBytes: _stats?.totalBytes,
                            entries: _entries,
                            onChildSelect: (f) =>
                                setState(() => _focused = f),
                            onChildDrill: _drillInto,
                            onReveal: _reveal,
                            onTrash: _trashFocused,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header — `.tm-header { padding: 24px 28px 18px; }`
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final List<String> stack;
  final int viewSize;
  final int viewItems;
  final int viewReclaim;
  final int? totalDiskBytes;
  final int? usedDiskBytes;
  final ValueChanged<int> onCrumbTap;
  final VoidCallback? onUp;
  final VoidCallback onHome;
  final VoidCallback? onRescan;
  const _Header({
    required this.stack,
    required this.viewSize,
    required this.viewItems,
    required this.viewReclaim,
    required this.totalDiskBytes,
    required this.usedDiskBytes,
    required this.onCrumbTap,
    required this.onUp,
    required this.onHome,
    required this.onRescan,
  });

  static String _displayPath(String path) {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return path;
    if (path == home) return '~';
    if (path.startsWith('$home/')) return '~${path.substring(home.length)}';
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final used = usedDiskBytes ?? viewSize;
    final currentPath = stack.isEmpty ? '/' : stack.last;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
      child: LayoutBuilder(
        builder: (context, c) {
          final tight = c.maxWidth < 920;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // .tm-eyebrow — mono 10px / 0.22em / uppercase / var(--p-70)
              const Text(
                'STORAGE TREE MAP · CLICK TO INSPECT · DOUBLE-CLICK TO DRILL',
                style: TextStyle(
                  fontFamily: 'SF Mono',
                  fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2, // 0.22em on 10px
                  color: _kAccent,
                ),
              ),
              // .tm-title { margin: 8px 0 12px }
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.9, // -0.025em on 36px
                    color: _kWhite100,
                    height: 1, // line-height: 1
                  ),
                  children: [
                    TextSpan(text: '${formatBytes(used)} used'),
                    if (viewReclaim > 0) ...[
                      const TextSpan(text: '  ·  '),
                      TextSpan(
                        text: '${formatBytes(viewReclaim)} reclaimable',
                        style: const TextStyle(color: _kAccent),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Current path (selectable so it's copy-pasteable).
              SelectableText(
                _displayPath(currentPath),
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'SF Mono',
                  fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
                  fontSize: 11,
                  color: _kWhite45,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 12),
              // Crumbs + actions on the left, stats on the right.
              if (tight)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Breadcrumbs(
                    stack: stack,
                    onTap: onCrumbTap,
                    onUp: onUp,
                    onHome: onHome,
                    onRescan: onRescan,
                  ),
                ),
              if (tight)
                _Stats(
                  totalDisk: totalDiskBytes,
                  inViewSize: viewSize,
                  inViewItems: viewItems,
                  reclaim: viewReclaim,
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _Breadcrumbs(
                        stack: stack,
                        onTap: onCrumbTap,
                        onUp: onUp,
                        onHome: onHome,
                        onRescan: onRescan,
                      ),
                    ),
                    _Stats(
                      totalDisk: totalDiskBytes,
                      inViewSize: viewSize,
                      inViewItems: viewItems,
                      reclaim: viewReclaim,
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Breadcrumbs — `.tm-crumbs`
// ---------------------------------------------------------------------------

class _Breadcrumbs extends StatelessWidget {
  final List<String> stack;
  final ValueChanged<int> onTap;
  final VoidCallback? onUp;
  final VoidCallback onHome;
  final VoidCallback? onRescan;
  const _Breadcrumbs({
    required this.stack,
    required this.onTap,
    required this.onUp,
    required this.onHome,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      // Leading home glyph — `.ic { width: 12px; opacity: 0.5 }`. The
      // parent text colour is rgba(255,255,255,0.7), so the icon ends up
      // around 0.35 alpha. Matches design tone.
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          CupertinoIcons.house_fill,
          size: 12,
          color: Color(0x59FFFFFF), // 70% × 50% ≈ 35%
        ),
      ),
    ];
    for (var i = 0; i < stack.length; i++) {
      if (i > 0) {
        // .sep { opacity: 0.4 } on parent rgba(255,255,255,0.7) → ≈0.28α.
        children.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '›',
            style: TextStyle(color: Color(0x47FFFFFF), fontSize: 12),
          ),
        ));
      }
      final isLast = i == stack.length - 1;
      final label = i == 0
          ? (stack[0] == (Platform.environment['HOME'] ?? '/')
              ? '~'
              : stack[0])
          : stack[i].split('/').where((p) => p.isNotEmpty).lastOrNull ??
              stack[i];
      children.add(_CrumbButton(
        label: label,
        active: isLast,
        onTap: isLast ? null : () => onTap(i),
      ));
    }
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          // `.tm-crumbs { padding: 6px 8px 6px 10px; bg: rgba(255,255,255,0.04);
          //   border: 1px solid rgba(255,255,255,0.06); border-radius: 8px }`.
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          decoration: BoxDecoration(
            color: _kWhite4,
            border: Border.all(color: _kBorderSubtle),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
        _IconButton(
          icon: CupertinoIcons.arrow_up,
          tooltip: 'Up one level',
          onTap: onUp,
        ),
        _IconButton(
          icon: CupertinoIcons.house_fill,
          tooltip: 'Home',
          onTap: onHome,
        ),
        _IconButton(
          icon: CupertinoIcons.refresh,
          tooltip: 'Rescan',
          onTap: onRescan,
        ),
      ],
    );
  }
}

class _CrumbButton extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _CrumbButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_CrumbButton> createState() => _CrumbButtonState();
}

class _CrumbButtonState extends State<_CrumbButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'SF Mono',
      fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
      fontSize: 12,
      fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
      color: widget.active ? _kAccent : _kWhite70,
    );
    final inner = Container(
      // `.tm-crumbs button { padding: 2px 4px; border-radius: 4px }`,
      // hover bg `rgba(255,255,255,0.08)`.
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: _hover && widget.onTap != null
            ? const Color(0x14FFFFFF)
            : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(widget.label, style: style),
    );
    if (widget.onTap == null) return inner;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onTap, child: inner),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass icon button used in the header and the floating zoom panel.
// `.tm-zoom button { 28×28; bg transparent; hover bg rgba(255,255,255,0.08) }`.
// ---------------------------------------------------------------------------

class _IconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final fg = widget.onTap == null ? _kWhite30 : _kWhite70;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AuroraTokens.dShort2,
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hover && widget.onTap != null ? _kWhite8 : _kWhite4,
              border: Border.all(color: _kBorderSubtle),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 13, color: fg),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats — `.tm-stats { gap: 28px }`. Cells are mono-label + numeric value;
// dividers stretch to the cell height (`align-items: stretch`).
// ---------------------------------------------------------------------------

class _Stats extends StatelessWidget {
  final int? totalDisk;
  final int inViewSize;
  final int inViewItems;
  final int reclaim;
  const _Stats({
    required this.totalDisk,
    required this.inViewSize,
    required this.inViewItems,
    required this.reclaim,
  });

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      _StatCell(
        label: 'Total disk',
        value: totalDisk == null ? '—' : formatBytes(totalDisk!),
      ),
      _StatCell(label: 'In view', value: formatBytes(inViewSize)),
      _StatCell(label: 'Items', value: '$inViewItems'),
      _StatCell(
        label: 'Reclaimable',
        value: formatBytes(reclaim),
        accent: true,
      ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: _StatDivider(),
            ),
          cells[i],
        ],
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  const _StatCell({
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // .tm-stat .lab — mono 9px / 0.2em / uppercase / rgba(255,255,255,0.45).
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'SF Mono',
            fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
            fontSize: 9,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w600,
            color: _kWhite45,
          ),
        ),
        const SizedBox(height: 2),
        // .tm-stat .val — 22px / weight 700 / -0.02em / #fff (or var(--p-70)).
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.44,
            color: accent ? _kAccent : _kWhite100,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) =>
      // `.tm-stat-divider { width: 1px; bg: rgba(255,255,255,0.08) }` —
      // 38px matches a stat cell (9px label + 2px gap + 22px value with
      // small visual padding). Cheaper than IntrinsicHeight, which can't
      // co-exist with a Row that has a stretch child.
      Container(width: 1, height: 38, color: _kWhite8);
}

// ---------------------------------------------------------------------------
// Canvas — radial-gradient backdrop + treemap + overlays.
// ---------------------------------------------------------------------------

class _Canvas extends StatelessWidget {
  final List<DirectoryInfo> entries;
  final int parentSize;
  final String parentName;
  final DirectoryInfo? focused;
  final bool scanning;
  final String scanPath;
  final int scanDone;
  final int scanTotal;
  final ValueChanged<DirectoryInfo> onSelect;
  final ValueChanged<DirectoryInfo> onDrill;
  final VoidCallback? onUp;
  final VoidCallback onHome;
  const _Canvas({
    required this.entries,
    required this.parentSize,
    required this.parentName,
    required this.focused,
    required this.scanning,
    required this.scanPath,
    required this.scanDone,
    required this.scanTotal,
    required this.onSelect,
    required this.onDrill,
    required this.onUp,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base — `#0a0814`.
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFF0A0814)),
        ),
        // First radial — purple seed @ 6%, centred at 30%/20%.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.4, -0.6),
                radius: 0.7,
                colors: [Color(0x0F5B43D6), Color(0x005B43D6)],
              ),
            ),
          ),
        ),
        // Second radial — emerald @ 4%, centred at 70%/80%.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.4, 0.6),
                radius: 0.7,
                colors: [Color(0x0A1BA864), Color(0x001BA864)],
              ),
            ),
          ),
        ),
        // .tm-canvas { padding: 16px }.
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TreemapView(
              entries: entries,
              parentSize: parentSize,
              parentName: parentName,
              focused: focused,
              onHover: (_) {},
              onTap: onSelect,
              onDoubleTap: onDrill,
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 16,
          child: _ZoomControls(onUp: onUp, onHome: onHome),
        ),
        const Positioned(
          left: 24,
          bottom: 24,
          child: _LegendOverlay(),
        ),
        if (scanning)
          Positioned(
            left: 24,
            right: 24,
            top: 16,
            child: _ScanStrip(
              currentPath: scanPath,
              done: scanDone,
              total: scanTotal,
            ),
          ),
      ],
    );
  }
}

// `.tm-zoom { … padding: 4px; bg: rgba(8,6,15,0.7); border 1px
// rgba(255,255,255,0.08); border-radius: 8px }`.
class _ZoomControls extends StatelessWidget {
  final VoidCallback? onUp;
  final VoidCallback onHome;
  const _ZoomControls({required this.onUp, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xB308060F),
        border: Border.all(color: _kWhite8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconButton(
            icon: CupertinoIcons.arrow_up,
            tooltip: 'Up one level',
            onTap: onUp,
          ),
          const SizedBox(height: 4),
          _IconButton(
            icon: CupertinoIcons.house_fill,
            tooltip: 'Back to root',
            onTap: onHome,
          ),
        ],
      ),
    );
  }
}

// `.tm-legend { padding: 10px 12px; bg: rgba(8,6,15,0.7); border 1px
// rgba(255,255,255,0.08); border-radius: 8px; max-width: 540px }`.
class _LegendOverlay extends StatelessWidget {
  const _LegendOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 540),
      decoration: BoxDecoration(
        color: const Color(0xB308060F),
        border: Border.all(color: _kWhite8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          for (final c in StorageCategory.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  // `.swatch { border-radius: 2px }`.
                  decoration: BoxDecoration(
                    color: c.base,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  c.label,
                  // `.tm-legend-item { 11px / weight 500 /
                  // rgba(255,255,255,0.75) }`.
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xBFFFFFFF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail panel — fixed width 320, `bg: var(--n-4); border-left: 1px
// rgba(255,255,255,0.06)`.
// ---------------------------------------------------------------------------

class _DetailPanel extends StatelessWidget {
  final DirectoryInfo? focused;
  final int current;
  final int currentItems;
  final int? totalDiskBytes;
  final List<DirectoryInfo> entries;
  final ValueChanged<DirectoryInfo> onChildSelect;
  final ValueChanged<DirectoryInfo> onChildDrill;
  final ValueChanged<DirectoryInfo> onReveal;
  final VoidCallback onTrash;
  const _DetailPanel({
    required this.focused,
    required this.current,
    required this.currentItems,
    required this.totalDiskBytes,
    required this.entries,
    required this.onChildSelect,
    required this.onChildDrill,
    required this.onReveal,
    required this.onTrash,
  });

  @override
  Widget build(BuildContext context) {
    final hasFocus = focused != null;
    final node = focused;

    final cat = node == null
        ? StorageCategory.other
        : CategoryClassifier.categorize(node.path);
    final pct =
        current > 0 && node != null ? (node.size / current * 100) : 0.0;
    final pctText = pct.toStringAsFixed(pct < 10 ? 1 : 0);
    final reclaimable =
        node != null ? CategoryClassifier.isReclaimable(node.path) : false;

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: _kDetailBg,
        border: Border(left: BorderSide(color: _kBorderSubtle)),
      ),
      child: hasFocus
          ? _DetailBody(
              node: node!,
              cat: cat,
              pctText: pctText,
              pct: pct,
              reclaimable: reclaimable,
              entries: entries,
              totalDiskBytes: totalDiskBytes,
              currentItems: currentItems,
              onChildSelect: onChildSelect,
              onChildDrill: onChildDrill,
              onReveal: () => onReveal(node),
              onTrash: onTrash,
            )
          : _DetailHint(currentItems: currentItems),
    );
  }
}

class _DetailHint extends StatelessWidget {
  final int currentItems;
  const _DetailHint({required this.currentItems});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AuroraTokens.p70, AuroraTokens.p40],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              CupertinoIcons.cursor_rays,
              color: _kWhite100,
              size: 18,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Click any tile',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _kWhite100,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            currentItems == 0
                ? 'Scanning…'
                : 'Single-click a tile to inspect it here. '
                    'Double-click a folder to drill in.',
            style: const TextStyle(
              fontSize: 13,
              color: _kWhite60,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final DirectoryInfo node;
  final StorageCategory cat;
  final String pctText;
  final double pct;
  final bool reclaimable;
  final List<DirectoryInfo> entries;
  final int? totalDiskBytes;
  final int currentItems;
  final ValueChanged<DirectoryInfo> onChildSelect;
  final ValueChanged<DirectoryInfo> onChildDrill;
  final VoidCallback onReveal;
  final VoidCallback onTrash;
  const _DetailBody({
    required this.node,
    required this.cat,
    required this.pctText,
    required this.pct,
    required this.reclaimable,
    required this.entries,
    required this.totalDiskBytes,
    required this.currentItems,
    required this.onChildSelect,
    required this.onChildDrill,
    required this.onReveal,
    required this.onTrash,
  });

  @override
  Widget build(BuildContext context) {
    final sizeText = formatBytes(node.size);
    final sizeNum = sizeText.split(' ').first;
    final sizeUnit = sizeText.split(' ').skip(1).join(' ');
    final pctOfDisk = (totalDiskBytes != null && totalDiskBytes! > 0)
        ? (node.size / totalDiskBytes! * 100).toStringAsFixed(2)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .tm-detail-head — `padding: 22px 22px 16px;
        // border-bottom: 1px rgba(255,255,255,0.05)`.
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // .tm-detail-icon — 44×44, border-radius 10px, gradient 135°.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cat.tone, cat.base],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  node.isDirectory
                      ? CupertinoIcons.folder_fill
                      : CupertinoIcons.doc_fill,
                  color: _kWhite100,
                  size: 20,
                ),
              ),
              // .tm-detail-icon { margin-bottom: 14px }.
              const SizedBox(height: 14),
              // .tm-detail-name — 20px / weight 700 / -0.01em / #fff /
              // line-height 1.15 / margin 0 0 6px.
              Text(
                node.name.isEmpty ? '/' : node.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: _kWhite100,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              // .tm-detail-path — mono 11px / rgba(255,255,255,0.45) /
              // line-height 1.5.
              Text(
                node.path,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'SF Mono',
                  fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
                  fontSize: 11,
                  color: _kWhite45,
                  height: 1.5,
                ),
              ),
              // .tm-detail-size { margin-top: 18px }.
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // num — 36px / weight 700 / -0.025em / #fff.
                  Text(
                    sizeNum,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.9,
                      color: _kWhite100,
                      height: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // unit — 16px / weight 500 / rgba(255,255,255,0.6).
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      sizeUnit,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _kWhite60,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // pct pill — bg rgba(168,154,250,0.12) / mono 11px /
                  // weight 600 / 0.04em / var(--p-70) / radius 5.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AuroraTokens.p70.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '$pctText% of parent',
                      style: const TextStyle(
                        fontFamily: 'SF Mono',
                        fontFamilyFallback: [
                          'Menlo',
                          'Consolas',
                          'monospace',
                        ],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.44,
                        color: _kAccent,
                      ),
                    ),
                  ),
                ],
              ),
              // .tm-mini-bar { margin-top: 10px; height: 4px;
              // bg: rgba(255,255,255,0.06); border-radius: 2px }
              // fill linear-gradient 90deg var(--p-50) → var(--p-70).
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  children: [
                    Container(height: 4, color: const Color(0x0FFFFFFF)),
                    FractionallySizedBox(
                      widthFactor: (pct / 100).clamp(0, 1).toDouble(),
                      child: Container(
                        height: 4,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AuroraTokens.p50, AuroraTokens.p70],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _kBorderHairline),
        // .tm-detail-section — `padding: 18px 22px`, border-bottom hairline.
        _Section(
          label: 'Classification',
          child: _CategoryPill(cat: cat),
        ),
        const Divider(height: 1, thickness: 1, color: _kBorderHairline),
        _Section(
          label: 'Metadata',
          child: _MetaGrid(
            type: node.isDirectory ? 'Folder' : 'File',
            reclaim: reclaimable ? formatBytes(node.size) : null,
            pctOfDisk: pctOfDisk,
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _kBorderHairline),
        Expanded(
          child: _ChildrenList(
            entries: entries,
            focusedPath: node.path,
            onSelect: onChildSelect,
            onDrill: onChildDrill,
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _kBorderHairline),
        // .tm-actions { padding: 18px 22px; gap: 8px }.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Row(
            children: [
              if (reclaimable) ...[
                Expanded(
                  child: _ActionButton.danger(
                    icon: CupertinoIcons.delete,
                    label: 'Reclaim ${formatBytes(node.size)}',
                    onTap: onTrash,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _ActionButton.ghost(
                  icon: CupertinoIcons.search,
                  label: 'Reveal',
                  onTap: onReveal,
                ),
              ),
              if (node.isDirectory) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton.primary(
                    icon: CupertinoIcons.arrow_right,
                    label: 'Drill in',
                    onTap: () => onChildDrill(node),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            // `.tm-section-label { mono 9px / 0.2em / uppercase /
            // rgba(255,255,255,0.4) / weight 600 / margin-bottom 12px }`.
            style: const TextStyle(
              fontFamily: 'SF Mono',
              fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
              fontSize: 9,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w600,
              color: _kWhite40,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final StorageCategory cat;
  const _CategoryPill({required this.cat});

  @override
  Widget build(BuildContext context) {
    // `.tm-cat-pill { padding: 4px 9px; border-radius: 5px; font-size: 11px;
    // weight 600; letter-spacing 0.02em }`. bg = cat.color + "22" (~13%).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: cat.base.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: cat.tone,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            cat.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.22, // 0.02em on 11px
              color: cat.tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaGrid extends StatelessWidget {
  final String type;
  final String? reclaim;
  final String? pctOfDisk;
  const _MetaGrid({
    required this.type,
    required this.reclaim,
    required this.pctOfDisk,
  });

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      _MetaCell(k: 'Type', v: type),
      const _MetaCell(k: 'Items', v: '—'),
      _MetaCell(
        k: 'Reclaimable',
        v: reclaim ?? 'None',
        accent: reclaim != null,
      ),
      _MetaCell(
        k: 'Of total disk',
        v: pctOfDisk == null ? '—' : '$pctOfDisk%',
      ),
    ];
    // .tm-meta-grid { gap: 12px 16px } — 12 row, 16 col.
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 12,
      childAspectRatio: 3.6,
      children: cells,
    );
  }
}

class _MetaCell extends StatelessWidget {
  final String k;
  final String v;
  final bool accent;
  const _MetaCell({required this.k, required this.v, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // .tm-meta-grid .k — mono 9px / 0.18em / uppercase /
        // rgba(255,255,255,0.4) / weight 600.
        Text(
          k.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'SF Mono',
            fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
            fontSize: 9,
            letterSpacing: 1.62, // 0.18em on 9px
            fontWeight: FontWeight.w600,
            color: _kWhite40,
          ),
        ),
        const SizedBox(height: 2),
        // .v — 13px / weight 500 / #fff / tabular-nums. Reclaimable accent
        // turns it #71f2a6.
        Text(
          v,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: accent ? _kReclaim : _kWhite100,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ChildrenList extends StatelessWidget {
  final List<DirectoryInfo> entries;
  final String focusedPath;
  final ValueChanged<DirectoryInfo> onSelect;
  final ValueChanged<DirectoryInfo> onDrill;
  const _ChildrenList({
    required this.entries,
    required this.focusedPath,
    required this.onSelect,
    required this.onDrill,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) => b.size.compareTo(a.size));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP CHILDREN · CLICK TO INSPECT · DOUBLE-CLICK TO DRILL',
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
              fontSize: 9,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w600,
              color: _kWhite40,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: sorted.isEmpty
                ? const Text(
                    'No children',
                    style: TextStyle(fontSize: 12, color: _kWhite40),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: sorted.length,
                    itemBuilder: (context, i) {
                      final c = sorted[i];
                      final cat = CategoryClassifier.categorize(c.path);
                      final active = c.path == focusedPath;
                      return _ChildRow(
                        info: c,
                        cat: cat,
                        active: active,
                        onTap: () => onSelect(c),
                        onDoubleTap: () => onDrill(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChildRow extends StatefulWidget {
  final DirectoryInfo info;
  final StorageCategory cat;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  const _ChildRow({
    required this.info,
    required this.cat,
    required this.active,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  State<_ChildRow> createState() => _ChildRowState();
}

class _ChildRowState extends State<_ChildRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    // .tm-child-row.active { bg: rgba(91,67,214,0.18) }
    // .tm-child-row:hover { bg: rgba(255,255,255,0.04) }.
    final bg = widget.active
        ? AuroraTokens.p40.withValues(alpha: 0.18)
        : _hover
            ? _kWhite4
            : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedContainer(
          duration: AuroraTokens.dShort2,
          // .tm-child-row { padding: 8px 14px 8px 0; border-radius: 6px;
          // grid: 4px 1fr auto, gap 10px }.
          padding: const EdgeInsets.fromLTRB(0, 8, 14, 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // .accent { width: 3px; height: 28px; margin-left: 10px }.
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 3,
                height: 28,
                decoration: BoxDecoration(
                  color: widget.cat.tone,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  widget.info.name.isEmpty ? '/' : widget.info.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // .name — 12.5px / weight 500 / #fff.
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: _kWhite100,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  formatBytes(widget.info.size),
                  // .size — mono 11px / weight 500 /
                  // rgba(255,255,255,0.6) / tabular-nums.
                  style: const TextStyle(
                    fontFamily: 'SF Mono',
                    fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
                    fontSize: 11,
                    color: _kWhite60,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons — `.tm-btn` variants.
// ---------------------------------------------------------------------------

enum _ActionVariant { primary, ghost, danger }

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _ActionVariant variant;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.variant,
  });

  factory _ActionButton.primary({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      _ActionButton(
        icon: icon,
        label: label,
        onTap: onTap,
        variant: _ActionVariant.primary,
      );

  factory _ActionButton.ghost({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      _ActionButton(
        icon: icon,
        label: label,
        onTap: onTap,
        variant: _ActionVariant.ghost,
      );

  factory _ActionButton.danger({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      _ActionButton(
        icon: icon,
        label: label,
        onTap: onTap,
        variant: _ActionVariant.danger,
      );

  @override
  Widget build(BuildContext context) {
    BoxDecoration deco;
    Color fg;
    List<BoxShadow>? shadow;
    switch (variant) {
      case _ActionVariant.primary:
        deco = BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AuroraTokens.p50, AuroraTokens.p40],
          ),
          borderRadius: BorderRadius.circular(7),
        );
        fg = _kWhite100;
        shadow = [
          BoxShadow(
            color: AuroraTokens.p40.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];
      case _ActionVariant.ghost:
        deco = BoxDecoration(
          color: _kWhite4,
          border: Border.all(color: _kWhite8),
          borderRadius: BorderRadius.circular(7),
        );
        fg = _kWhite85;
      case _ActionVariant.danger:
        deco = BoxDecoration(
          color: const Color(0x24FF5449),
          border: Border.all(color: const Color(0x40FF5449)),
          borderRadius: BorderRadius.circular(7),
        );
        fg = const Color(0xFFFF897D);
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          decoration: deco.copyWith(boxShadow: shadow),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scan strip (overlay during initial / re-scans). Glass treatment so it sits
// on the canvas without occluding content underneath.
// ---------------------------------------------------------------------------

class _ScanStrip extends StatelessWidget {
  final String currentPath;
  final int done;
  final int total;
  const _ScanStrip({
    required this.currentPath,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? null : (done / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xB308060F),
        border: Border.all(color: _kBorderSubtle),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kAccent,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'SCANNING',
                style: TextStyle(
                  fontFamily: 'SF Mono',
                  fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                  color: _kWhite70,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AuroraTokens.dShort2,
                  child: Text(
                    currentPath.isEmpty ? '…' : currentPath,
                    key: ValueKey(currentPath),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'SF Mono',
                      fontFamilyFallback: [
                        'Menlo',
                        'Consolas',
                        'monospace',
                      ],
                      fontSize: 12,
                      color: _kWhite85,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                total == 0 ? '—' : '$done / $total',
                style: const TextStyle(
                  fontFamily: 'SF Mono',
                  fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kWhite60,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: _kWhite8,
              valueColor: const AlwaysStoppedAnimation(_kAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.square_grid_2x2,
            size: 36,
            color: _kWhite40,
          ),
          SizedBox(height: 12),
          Text(
            'Nothing to map',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kWhite100,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Empty folder or no read permission.',
            style: TextStyle(fontSize: 12, color: _kWhite60),
          ),
        ],
      ),
    );
  }
}
