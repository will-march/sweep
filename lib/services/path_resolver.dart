import 'dart:io';

String expandPath(String input) {
  final home = Platform.environment['HOME'] ?? '';
  final user = Platform.environment['USER'] ?? '';
  var p = input.replaceAll(r'$USER', user);
  if (p.startsWith('~/')) {
    p = '$home${p.substring(1)}';
  } else if (p == '~') {
    p = home;
  }
  return p;
}
