import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/splash/aurora_backdrop.dart';

/// Multi-page guided tour shown after the splash and before the first
/// real session. Mirrors the "1-2-3" splash visually (Aurora backdrop +
/// glassmorphism cards) so the transition feels continuous rather than
/// cutting from a polished intro into a cold app.
class TourScreen extends StatefulWidget {
  /// Fired when the user finishes the tour or hits Skip.
  final VoidCallback onComplete;
  const TourScreen({super.key, required this.onComplete});

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = <_Page>[
    _Page(
      eyebrow: '01 · Welcome',
      title: 'Reclaim disk\nwithout the dread.',
      body: 'iMaculate finds the gigabytes hiding in caches, '
          'derived data and forgotten archives — and shows you '
          'every byte before it lifts a finger.',
      icon: CupertinoIcons.sparkles,
      bullets: [
        'Trash-first deletion. Recoverable until you empty it.',
        'No telemetry, no network, no auto-everything.',
      ],
      gradient: [
        Color(0xFFE3DDFF),
        Color(0xFFA89AFA),
        Color(0xFF5B43D6),
      ],
    ),
    _Page(
      eyebrow: '02 · Cleaning modes',
      title: 'Four levels,\nfour risk colours.',
      body: 'Light Scrub for daily safety, Boilwash for monthly '
          'depth, Sandblast when storage is critical, '
          'Development for build-tool caches.',
      icon: CupertinoIcons.flame_fill,
      bullets: [
        'Every entry shows path · size · risk before you act.',
        'Higher-risk targets need admin and confirm twice.',
      ],
      gradient: [
        Color(0xFF95FFC0),
        Color(0xFF1BA864),
        Color(0xFF006D3B),
      ],
    ),
    _Page(
      eyebrow: '03 · Tree Map',
      title: 'See where\nthe bytes live.',
      body: 'A squarified tree-map turns 500 GB into a clickable '
          'mosaic. Single-click any tile to inspect, double-click to '
          'drill in, breadcrumb back up.',
      icon: CupertinoIcons.square_grid_2x2_fill,
      bullets: [
        'Reclaim badges flag wipeable folders.',
        'Click a child row in the side panel to jump there.',
      ],
      gradient: [
        Color(0xFFC5BCFF),
        Color(0xFF7560E3),
        Color(0xFF462DB6),
      ],
    ),
    _Page(
      eyebrow: '04 · History & Undo',
      title: 'Every clean,\non the record.',
      body: 'Each clean is appended to a local history file. '
          'Files moved to Trash stay restorable from Finder until '
          'you empty it.',
      icon: CupertinoIcons.clock_fill,
      bullets: [
        'Inspect past cleans by mode, time and size.',
        'Restore opens ~/.Trash so you can pull anything back.',
      ],
      gradient: [
        Color(0xFFC5BCFF),
        Color(0xFF8E7DF0),
        Color(0xFF5B43D6),
      ],
    ),
    _Page(
      eyebrow: '05 · Exclusions',
      title: 'Protect what\nmatters.',
      body: 'Add any path to the exclusion list and the cleaner '
          'plus the tree-map will skip it forever — folder and '
          'everything inside it.',
      icon: CupertinoIcons.shield_fill,
      bullets: [
        'Use ~/ shorthand to point at your home folder.',
        'Edits take effect on the next scan, no restart.',
      ],
      gradient: [
        Color(0xFFCABDFF),
        Color(0xFF815CD0),
        Color(0xFF4E2A8E),
      ],
    ),
    _Page(
      eyebrow: '06 · Schedule',
      title: 'Set it,\nforget it.',
      body: 'Auto-run Light Scrub daily, weekly or monthly. '
          'Anything more aggressive stays manual — auto-running '
          'a deep clean is how cleaners eat user data.',
      icon: CupertinoIcons.calendar,
      bullets: [
        'Schedule fires while iMaculate is open.',
        'Background scheduling lands with the launchd helper.',
      ],
      gradient: [
        Color(0xFFFFDDAE),
        Color(0xFFFFBA47),
        Color(0xFFAD6E00),
      ],
    ),
    _Page(
      eyebrow: '07 · Uninstaller',
      title: 'Apps + their\nleftovers.',
      body: 'Drag-to-Trash leaves caches, preferences and '
          'containers behind. iMaculate trashes the bundle and '
          'every file matched by bundle ID.',
      icon: CupertinoIcons.app_badge_fill,
      bullets: [
        'Sorted by total disk impact (bundle + leftovers).',
        'Confirmation lists every leftover before anything moves.',
      ],
      gradient: [
        Color(0xFFFFB3B0),
        Color(0xFFD33B40),
        Color(0xFF8C0D20),
      ],
    ),
    _Page(
      eyebrow: '08 · Ready',
      title: "You're all set.",
      body: 'Your first scan is one click away. Light Scrub is the '
          'safest place to start — find a quick gigabyte, then '
          'graduate to Boilwash when you want more.',
      icon: CupertinoIcons.checkmark_seal_fill,
      bullets: [
        'Find every feature in the sidebar.',
        'Right-click anything for a path / size / reveal menu.',
      ],
      gradient: [
        Color(0xFFE3DDFF),
        Color(0xFFA89AFA),
        Color(0xFF5B43D6),
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      widget.onComplete();
      return;
    }
    _controller.nextPage(
      duration: AuroraTokens.dMedium2,
      curve: AuroraTokens.standardEasing,
    );
  }

  void _back() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: AuroraTokens.dMedium2,
      curve: AuroraTokens.standardEasing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFF08060F),
      body: Stack(
        children: [
          // Reuse the splash backdrop so the transition reads as one
          // continuous moment. t=1 picks up the settled "finale" pose
          // — saves a ticker just to power a background gradient.
          const Positioned.fill(child: AuroraBackdrop(t: 1)),

          // Top bar — Skip + page progress.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    _PageIndicator(index: _index, total: _pages.length),
                    const Spacer(),
                    if (!isLast)
                      TextButton(
                        onPressed: widget.onComplete,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.7),
                        ),
                        child: const Text('Skip tour'),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Page carousel.
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _TourCard(page: _pages[i]),
            ),
          ),

          // Bottom controls — Back / Next (or Get started on last page).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    AnimatedOpacity(
                      duration: AuroraTokens.dShort2,
                      opacity: _index == 0 ? 0 : 1,
                      child: TextButton.icon(
                        onPressed: _index == 0 ? null : _back,
                        icon:
                            const Icon(CupertinoIcons.chevron_left, size: 14),
                        label: const Text('Back'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _PrimaryAction(
                      label: isLast ? 'Get started' : 'Next',
                      icon: isLast
                          ? CupertinoIcons.sparkles
                          : CupertinoIcons.chevron_right,
                      onTap: _next,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Page {
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final List<String> bullets;
  final List<Color> gradient;
  const _Page({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
    required this.bullets,
    required this.gradient,
  });
}

class _TourCard extends StatelessWidget {
  final _Page page;
  const _TourCard({required this.page});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 80, 32, 96),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient icon plate.
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: page.gradient,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: page.gradient.last.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(page.icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 28),
              // Eyebrow — mono, tracked uppercase.
              Text(
                page.eyebrow.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'SF Mono',
                  fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.4,
                  color: Color(0xFFA89AFA),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                page.title,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.1,
                  height: 1.05,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                page.body,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.55,
                  color: Color(0xCCFFFFFF),
                ),
              ),
              const SizedBox(height: 24),
              // Glassmorphism bullet list.
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < page.bullets.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFA89AFA),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              page.bullets[i],
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xE6FFFFFF),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _PageIndicator extends StatelessWidget {
  final int index;
  final int total;
  const _PageIndicator({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: AuroraTokens.dShort2,
            width: i == index ? 24 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index
                  ? const Color(0xFFA89AFA)
                  : const Color(0x59FFFFFF),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}

class _PrimaryAction extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_PrimaryAction> createState() => _PrimaryActionState();
}

class _PrimaryActionState extends State<_PrimaryAction> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AuroraTokens.dShort2,
          padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AuroraTokens.p50, AuroraTokens.p40],
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: AuroraTokens.p40
                    .withValues(alpha: _hover ? 0.55 : 0.4),
                blurRadius: _hover ? 24 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Icon(widget.icon, color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
