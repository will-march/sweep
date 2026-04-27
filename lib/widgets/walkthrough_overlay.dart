import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/walkthrough_controller.dart';
import '../theme/tokens.dart';

/// Live coachmark overlay. Listens to the [WalkthroughController] passed
/// in and on each rebuild:
///   1. Reads the GlobalKey for the current step's target.
///   2. Computes that target's rect in screen coordinates.
///   3. Paints a dark scrim everywhere except a rounded "spotlight"
///      around the target.
///   4. Anchors a tooltip card next to the spotlight (or centred for
///      no-target steps like the final "done" message).
///
/// The scrim is wrapped in [IgnorePointer] so the user can still
/// interact with the underlying app — the overlay annotates rather
/// than gating. The tooltip card itself catches taps for Back / Next /
/// Skip controls.
class WalkthroughOverlay extends StatefulWidget {
  final WalkthroughController controller;
  const WalkthroughOverlay({super.key, required this.controller});

  @override
  State<WalkthroughOverlay> createState() => _WalkthroughOverlayState();
}

class _WalkthroughOverlayState extends State<WalkthroughOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    widget.controller.addListener(_onController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _pulse.dispose();
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  /// Reads the target rect in the overlay's coordinate space. Returns
  /// null if the key isn't currently mounted (e.g. mid-navigation).
  Rect? _targetRect(BuildContext context) {
    final key = widget.controller.keyFor(widget.controller.current.step);
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final overlayBox = context.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    return topLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.active) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Defer one frame after a step change so target widgets have a
        // chance to lay out — a step that just navigated to a new
        // screen needs a frame for the new key to mount.
        final overlaySize = Size(constraints.maxWidth, constraints.maxHeight);
        return _OverlayBody(
          controller: widget.controller,
          overlaySize: overlaySize,
          rectResolver: () => _targetRect(context),
          pulse: _pulse,
        );
      },
    );
  }
}

class _OverlayBody extends StatelessWidget {
  final WalkthroughController controller;
  final Size overlaySize;
  final Rect? Function() rectResolver;
  final Animation<double> pulse;
  const _OverlayBody({
    required this.controller,
    required this.overlaySize,
    required this.rectResolver,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final rect = rectResolver();
        final inflated = rect?.inflate(8);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Scrim with a hole — pointer-passes-through so the user
            // can still click the highlighted control.
            IgnorePointer(
              child: CustomPaint(
                size: overlaySize,
                painter: _SpotlightPainter(
                  hole: inflated,
                  pulse: pulse.value,
                ),
              ),
            ),
            // Pulsing border around the spotlight to draw the eye.
            if (inflated != null)
              Positioned.fromRect(
                rect: inflated,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFA89AFA).withValues(
                          alpha: 0.45 + 0.35 * pulse.value,
                        ),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFA89AFA).withValues(
                            alpha: 0.25 * pulse.value,
                          ),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Tooltip card.
            _TooltipPositioner(
              spotlight: inflated,
              overlaySize: overlaySize,
              child: _TooltipCard(controller: controller),
            ),
          ],
        );
      },
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  final double pulse;
  const _SpotlightPainter({required this.hole, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()
      // Slightly lighter than a solid scrim so app chrome remains
      // legible underneath; the spotlight + tooltip do the focus work.
      ..color = const Color(0xFF08060F).withValues(alpha: 0.62);
    final fullPath = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      final holePath = Path()
        ..addRRect(
          RRect.fromRectAndRadius(hole!, const Radius.circular(12)),
        );
      // Punch the spotlight out of the scrim.
      final cut = Path.combine(PathOperation.difference, fullPath, holePath);
      canvas.drawPath(cut, scrim);
    } else {
      canvas.drawPath(fullPath, scrim);
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.pulse != pulse;
}

class _TooltipPositioner extends StatelessWidget {
  final Rect? spotlight;
  final Size overlaySize;
  final Widget child;
  const _TooltipPositioner({
    required this.spotlight,
    required this.overlaySize,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const cardW = 360.0;
    const cardH = 220.0;
    const gap = 16.0;

    if (spotlight == null) {
      // Centred tooltip — used for the final "you're set" step.
      return Center(child: SizedBox(width: cardW, child: child));
    }

    // Try to place the card to the right of the spotlight; flip below /
    // above / left as space requires.
    var left = spotlight!.right + gap;
    var top = spotlight!.center.dy - cardH / 2;

    if (left + cardW > overlaySize.width - 16) {
      // No room on the right — try below.
      left = spotlight!.center.dx - cardW / 2;
      top = spotlight!.bottom + gap;
      if (top + cardH > overlaySize.height - 16) {
        // Fall back to above.
        top = spotlight!.top - cardH - gap;
      }
    }

    // Clamp.
    left = left.clamp(16.0, overlaySize.width - cardW - 16.0);
    top = top.clamp(16.0, overlaySize.height - cardH - 16.0);

    return Positioned(
      left: left,
      top: top,
      width: cardW,
      child: child,
    );
  }
}

class _TooltipCard extends StatelessWidget {
  final WalkthroughController controller;
  const _TooltipCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final spec = controller.current;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A172A),
          border: Border.all(color: const Color(0x33A89AFA)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 40,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AuroraTokens.p70, AuroraTokens.p40],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    walkthroughIcon(spec.step),
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'STEP ${controller.index + 1} OF ${controller.total}',
                    style: const TextStyle(
                      fontFamily: 'SF Mono',
                      fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: Color(0xFFA89AFA),
                    ),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: controller.skip,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 14,
                        color: Color(0x80FFFFFF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              spec.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              spec.body,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xCCFFFFFF),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (controller.index > 0)
                  TextButton(
                    onPressed: controller.back,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xCCFFFFFF),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                _NextButton(
                  label: spec.cta ??
                      (controller.isLast ? 'Finish' : 'Next'),
                  onTap: controller.next,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NextButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NextButton({required this.label, required this.onTap});

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton> {
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
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AuroraTokens.p50, AuroraTokens.p40],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AuroraTokens.p40
                    .withValues(alpha: _hover ? 0.55 : 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 12,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
