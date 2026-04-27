import 'cleaning_level.dart';

enum UsageView { treeMap }

extension UsageViewInfo on UsageView {
  String get title => switch (this) {
        UsageView.treeMap => 'Tree Map',
      };
}

enum ToolView { history, exclusions, schedule, uninstaller }

extension ToolViewInfo on ToolView {
  String get title => switch (this) {
        ToolView.history => 'History',
        ToolView.exclusions => 'Exclusions',
        ToolView.schedule => 'Schedule',
        ToolView.uninstaller => 'Uninstaller',
      };
}

sealed class NavSelection {
  const NavSelection();
  String get pageTitle;
}

class CleaningNav extends NavSelection {
  final CleaningLevel level;
  const CleaningNav(this.level);
  @override
  String get pageTitle => level.title;
}

class UsageNav extends NavSelection {
  final UsageView view;
  const UsageNav(this.view);
  @override
  String get pageTitle => view.title;
}

class ToolNav extends NavSelection {
  final ToolView view;
  const ToolNav(this.view);
  @override
  String get pageTitle => view.title;
}
