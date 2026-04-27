import 'package:flutter_test/flutter_test.dart';
import 'package:iMaculate/utils/byte_formatter.dart';

void main() {
  group('formatBytes', () {
    test('shows raw bytes under 1 KB', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('rolls over to KB at 1024', () {
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1024 * 500), '500.0 KB');
    });

    test('rolls over to MB at 1024 KB', () {
      expect(formatBytes(1024 * 1024), '1.0 MB');
      expect(formatBytes(1024 * 1024 * 100), '100.0 MB');
    });

    test('rolls over to GB at 1024 MB', () {
      expect(formatBytes(1024 * 1024 * 1024), '1.00 GB');
      expect(formatBytes(1024 * 1024 * 1024 * 12), '12.00 GB');
    });

    test('uses two decimals for GB', () {
      // 1.5 GB exactly
      final bytes = (1.5 * 1024 * 1024 * 1024).round();
      expect(formatBytes(bytes), '1.50 GB');
    });
  });
}
