// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Sweep';

  @override
  String get navCleaning => 'クリーニング';

  @override
  String get navUsage => '使用状況';

  @override
  String get navTools => 'ツール';

  @override
  String get treeMap => 'ツリーマップ';

  @override
  String get history => '履歴';

  @override
  String get exclusions => '除外';

  @override
  String get schedule => 'スケジュール';

  @override
  String get uninstaller => 'アンインストーラ';

  @override
  String get rescan => '再スキャン';

  @override
  String get cleanAll => 'すべてクリーン';

  @override
  String get moveToTrash => 'ゴミ箱に移動';

  @override
  String get cancel => 'キャンセル';

  @override
  String get uninstall => 'アンインストール';

  @override
  String get runNow => '今すぐ実行';

  @override
  String get running => '実行中…';

  @override
  String get scanning => 'スキャン中…';

  @override
  String get noCleansYet => 'クリーン履歴なし';

  @override
  String get noCleansYetSubtitle => '実行したクリーンがここに表示されます。';

  @override
  String get noExclusions => '除外項目なし';

  @override
  String get noExclusionsSubtitle => '上にパスを追加して保護できます。';

  @override
  String get openTrash => 'ゴミ箱を開く';

  @override
  String get clearLog => 'ログを消去';

  @override
  String get restore => '復元';

  @override
  String get scheduleOff => 'オフ';

  @override
  String get scheduleDaily => '毎日';

  @override
  String get scheduleWeekly => '毎週';

  @override
  String get scheduleMonthly => '毎月';
}
