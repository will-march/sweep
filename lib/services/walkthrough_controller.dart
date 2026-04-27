import 'package:flutter/cupertino.dart';

import '../models/cleaning_level.dart';
import '../models/nav_selection.dart';

/// Each step of the live coachmark walkthrough. Names match the rough
/// concept rather than a specific widget so we can re-target if the UI
/// is rearranged later.
enum WalkthroughStep {
  sidebar,
  hero,
  cacheRow,
  cleanAll,
  treeMap,
  tools,
  done,
}

/// Visual + content spec for one step. Targets are looked up by
/// [GlobalKey] held on the controller — registering keys is the
/// caller's responsibility (see AuroraSidebar / CleanerScreen).
class WalkthroughStepSpec {
  final WalkthroughStep step;
  final String title;
  final String body;
  final String? cta;

  /// Where the tooltip card prefers to anchor relative to the spotlight.
  /// Right of the target by default; we flip if there isn't room.
  final WalkthroughAnchor anchor;
  const WalkthroughStepSpec({
    required this.step,
    required this.title,
    required this.body,
    this.cta,
    this.anchor = WalkthroughAnchor.right,
  });
}

enum WalkthroughAnchor { right, below, above, centre }

/// Holds the shared GlobalKeys, the active step, and the script. Widgets
/// register the keys (they're just plain GlobalKeys); the overlay reads
/// the rect of the current step's key on every build.
class WalkthroughController extends ChangeNotifier {
  // Spotlight target keys. These are attached to widgets in their
  // build methods — the controller doesn't own the widgets, just the
  // shared identity.
  final GlobalKey sidebarKey = GlobalKey(debugLabel: 'walkthrough.sidebar');
  final GlobalKey heroKey = GlobalKey(debugLabel: 'walkthrough.hero');
  final GlobalKey cacheRowKey = GlobalKey(debugLabel: 'walkthrough.row');
  final GlobalKey cleanAllKey = GlobalKey(debugLabel: 'walkthrough.cleanAll');
  final GlobalKey treeMapNavKey =
      GlobalKey(debugLabel: 'walkthrough.treeMap');
  final GlobalKey toolsHeaderKey =
      GlobalKey(debugLabel: 'walkthrough.tools');

  static const _script = <WalkthroughStepSpec>[
    WalkthroughStepSpec(
      step: WalkthroughStep.sidebar,
      title: 'Your toolbox',
      body:
          "Cleaning modes up top, Tree Map for visualisation, Tools for "
          "history, exclusions, schedule and the uninstaller. Light Scrub "
          "is selected — it's the safest mode.",
      anchor: WalkthroughAnchor.right,
    ),
    WalkthroughStepSpec(
      step: WalkthroughStep.hero,
      title: "What you'll reclaim",
      body:
          'After every scan this card shows total reclaimable bytes and '
          'scan progress. Watch the number climb as Sweep measures '
          'each cache.',
      anchor: WalkthroughAnchor.below,
    ),
    WalkthroughStepSpec(
      step: WalkthroughStep.cacheRow,
      title: 'Each row is a finding',
      body:
          'Path, size, and risk colour. Click any row for the safety '
          "dialog with the full path before anything's removed.",
      anchor: WalkthroughAnchor.below,
    ),
    WalkthroughStepSpec(
      step: WalkthroughStep.cleanAll,
      title: 'Your first cleanup',
      body:
          'Light Scrub only empties app caches and logs — apps rebuild '
          "what they need next launch. Click Clean all when you're "
          "ready (it logs to History either way).",
      cta: 'I will',
      anchor: WalkthroughAnchor.below,
    ),
    WalkthroughStepSpec(
      step: WalkthroughStep.treeMap,
      title: 'See where the bytes live',
      body:
          'Tree Map renders your disk as a clickable mosaic. Single-click '
          'inspects, double-click drills in, breadcrumb gets you back.',
      anchor: WalkthroughAnchor.right,
    ),
    WalkthroughStepSpec(
      step: WalkthroughStep.tools,
      title: 'Tools',
      body:
          'History records every clean (Restore opens Trash). Exclusions '
          "protect folders. Schedule auto-runs Light Scrub on a cadence. "
          'Uninstaller removes apps + every leftover.',
      anchor: WalkthroughAnchor.right,
    ),
    WalkthroughStepSpec(
      step: WalkthroughStep.done,
      title: "You're all set",
      body:
          "Right-click anything for shortcuts. Press ⌘R to rescan. "
          "Restart the walkthrough anytime from the History screen.",
      cta: 'Finish',
      anchor: WalkthroughAnchor.centre,
    ),
  ];

  bool _active = false;
  int _index = 0;

  /// On step changes that imply navigation, the controller can ask the
  /// HomeShell to switch sidebar selection (e.g. ensure Light Scrub is
  /// active when explaining the cache row).
  ValueChanged<NavSelection>? onNavigationRequest;

  bool get active => _active;
  int get index => _index;
  WalkthroughStepSpec get current => _script[_index];
  int get total => _script.length;
  bool get isLast => _index >= _script.length - 1;

  void start() {
    if (_active) return;
    _active = true;
    _index = 0;
    // Make sure Light Scrub is showing — first three steps presume it.
    onNavigationRequest?.call(const CleaningNav(CleaningLevel.lightScrub));
    notifyListeners();
  }

  void next() {
    if (!_active) return;
    if (_index >= _script.length - 1) {
      finish();
      return;
    }
    _index++;
    notifyListeners();
  }

  void back() {
    if (!_active) return;
    if (_index == 0) return;
    _index--;
    notifyListeners();
  }

  void skip() => finish();

  void finish() {
    _active = false;
    notifyListeners();
  }

  /// Called by widgets that the spotlight targets, when the user
  /// interacts with that widget directly. Lets us auto-advance instead
  /// of forcing the user to click "Next" after they did the right thing.
  void notifyTargetUsed(WalkthroughStep step) {
    if (!_active) return;
    if (current.step != step) return;
    next();
  }

  /// Resolve the GlobalKey for a step. Returns null for steps that
  /// don't paint a spotlight (e.g. centre dialog).
  GlobalKey? keyFor(WalkthroughStep step) => switch (step) {
        WalkthroughStep.sidebar => sidebarKey,
        WalkthroughStep.hero => heroKey,
        WalkthroughStep.cacheRow => cacheRowKey,
        WalkthroughStep.cleanAll => cleanAllKey,
        WalkthroughStep.treeMap => treeMapNavKey,
        WalkthroughStep.tools => toolsHeaderKey,
        WalkthroughStep.done => null,
      };
}

/// InheritedNotifier so any descendant widget can read the controller
/// (and the overlay rebuilds on every step change). Widgets that only
/// need the GlobalKeys can call [Walkthrough.read] which doesn't
/// register a dependency.
class Walkthrough extends InheritedNotifier<WalkthroughController> {
  const Walkthrough({
    super.key,
    required WalkthroughController controller,
    required super.child,
  }) : super(notifier: controller);

  static WalkthroughController of(BuildContext context) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<Walkthrough>();
    assert(widget != null,
        'No Walkthrough ancestor found. Wrap your subtree in Walkthrough.');
    return widget!.notifier!;
  }

  /// Read without subscribing to changes. Use when you only need the
  /// stable keys (e.g. attaching to a widget) and don't want to rebuild
  /// when the step changes.
  static WalkthroughController read(BuildContext context) {
    final widget =
        context.getInheritedWidgetOfExactType<Walkthrough>();
    assert(widget != null,
        'No Walkthrough ancestor found. Wrap your subtree in Walkthrough.');
    return widget!.notifier!;
  }
}

/// Convenience for widgets that only need an icon for the current step
/// (used in the tooltip header).
IconData walkthroughIcon(WalkthroughStep s) => switch (s) {
      WalkthroughStep.sidebar => CupertinoIcons.square_grid_2x2_fill,
      WalkthroughStep.hero => CupertinoIcons.gauge,
      WalkthroughStep.cacheRow => CupertinoIcons.list_bullet,
      WalkthroughStep.cleanAll => CupertinoIcons.sparkles,
      WalkthroughStep.treeMap => CupertinoIcons.chart_pie_fill,
      WalkthroughStep.tools => CupertinoIcons.wrench_fill,
      WalkthroughStep.done => CupertinoIcons.checkmark_seal_fill,
    };
