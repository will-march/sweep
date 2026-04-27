import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iMaculate/models/directory_info.dart';
import 'package:iMaculate/widgets/treemap_view.dart';

DirectoryInfo dir(String name, int sizeMb) => DirectoryInfo(
      path: '/tmp/$name',
      name: name,
      size: sizeMb * 1024 * 1024,
      isDirectory: true,
    );

Widget _harness({
  required List<DirectoryInfo> entries,
  required ValueChanged<DirectoryInfo?> onHover,
  required ValueChanged<DirectoryInfo> onTap,
  ValueChanged<DirectoryInfo>? onDoubleTap,
  DirectoryInfo? focused,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 600,
        height: 400,
        child: TreemapView(
          entries: entries,
          parentSize:
              entries.fold<int>(0, (acc, e) => acc + e.size),
          parentName: 'tmp',
          focused: focused,
          onHover: onHover,
          onTap: onTap,
          onDoubleTap: onDoubleTap ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders without errors for a typical entry list',
      (tester) async {
    await tester.pumpWidget(_harness(
      entries: [
        dir('apps', 4096),
        dir('library', 2048),
        dir('documents', 1024),
        dir('downloads', 512),
      ],
      onHover: (_) {},
      onTap: (_) {},
    ));
    expect(find.byType(TreemapView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap inside the canvas reports the tapped DirectoryInfo',
      (tester) async {
    DirectoryInfo? tapped;
    final entries = [
      dir('apps', 4096),
      dir('library', 2048),
      dir('documents', 1024),
    ];
    await tester.pumpWidget(_harness(
      entries: entries,
      onHover: (_) {},
      onTap: (d) => tapped = d,
    ));

    // Centre of the largest tile (apps) — squarify lays the biggest tile
    // first, occupying the dominant region of the bounds, so a tap near
    // (50, 50) of a 600x400 canvas hits it.
    await tester.tapAt(const Offset(80, 80));
    // With onDoubleTap also wired, the gesture arena waits for the
    // double-tap window before declaring onTap the winner. Pump past it.
    await tester.pump(const Duration(milliseconds: 600));
    expect(tapped, isNotNull);
    // Whichever specific tile got hit, it must be one of the entries we
    // passed in — never null and never a stranger.
    expect(entries.contains(tapped), isTrue);
  });

  testWidgets('empty entries still renders and does not crash',
      (tester) async {
    await tester.pumpWidget(_harness(
      entries: const [],
      onHover: (_) {},
      onTap: (_) {},
    ));
    expect(find.byType(TreemapView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hover near an edge does not throw and may report null',
      (tester) async {
    DirectoryInfo? hovered;
    var hoverCalls = 0;
    await tester.pumpWidget(_harness(
      entries: [dir('alpha', 1024), dir('beta', 512)],
      onHover: (d) {
        hoverCalls++;
        hovered = d;
      },
      onTap: (_) {},
    ));

    final gesture = await tester
        .createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(const Offset(120, 120));
    await tester.pump();

    expect(hoverCalls, greaterThan(0));
    expect(tester.takeException(), isNull);
    // Sanity: hovered is either one of the entries or null when we
    // happen to land in an inset gap — both are valid.
    if (hovered != null) {
      expect(['alpha', 'beta'], contains(hovered!.name));
    }
  });

  testWidgets(
      'double tap fires onDoubleTap and not just onTap',
      (tester) async {
    DirectoryInfo? singleTapped;
    DirectoryInfo? doubleTapped;
    final entries = [dir('apps', 4096), dir('library', 2048)];
    await tester.pumpWidget(_harness(
      entries: entries,
      onHover: (_) {},
      onTap: (d) => singleTapped = d,
      onDoubleTap: (d) => doubleTapped = d,
    ));

    // Two consecutive taps within Flutter's double-tap window.
    await tester.tapAt(const Offset(80, 80));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(80, 80));
    // Flush the gesture arena timeout so the onDoubleTap callback resolves.
    await tester.pump(const Duration(milliseconds: 600));

    expect(doubleTapped, isNotNull,
        reason: 'a fast second tap should trigger onDoubleTap');
    // The single-tap callback may or may not fire on the first half of a
    // double tap depending on gesture arena resolution; we only assert that
    // double-tap won.
    expect(entries.contains(doubleTapped), isTrue);
    if (singleTapped != null) {
      expect(entries.contains(singleTapped), isTrue);
    }
  });

  testWidgets('focused tile renders without errors', (tester) async {
    final entries = [dir('apps', 4096), dir('library', 2048)];
    await tester.pumpWidget(_harness(
      entries: entries,
      focused: entries.first,
      onHover: (_) {},
      onTap: (_) {},
    ));
    expect(tester.takeException(), isNull);
  });
}
