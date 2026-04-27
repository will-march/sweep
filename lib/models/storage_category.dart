import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// Storage classification used by the tree-map. Categories are inferred from
/// path conventions on macOS — there's no reliable filesystem tag for "this is
/// a cache" or "this is media", so we approximate with prefix/keyword matching
/// against the canonical macOS layout.
enum StorageCategory {
  apps('Applications', Color(0xFF5B43D6), Color(0xFF8E7DF0)),
  lib('User Library', Color(0xFFA89AFA), Color(0xFFC5BCFF)),
  dev('Developer', Color(0xFF815CD0), Color(0xFFCABDFF)),
  media('Media', Color(0xFFAD6E00), Color(0xFFFFBA47)),
  sys('System', Color(0xFFD33B40), Color(0xFFFFB3B0)),
  docs('Documents', Color(0xFF1BA864), Color(0xFF71F2A6)),
  cache('Caches', Color(0xFF946A86), Color(0xFFCD9DBC)),
  other('Other', Color(0xFF615B78), Color(0xFFAFA7C8));

  final String label;

  /// Deeper hue used for the tile gradient bottom.
  final Color base;

  /// Lighter sibling used for the tile gradient top + legend swatch.
  final Color tone;

  const StorageCategory(this.label, this.base, this.tone);
}

/// A reclaimable directory is one we know we can wipe without rebuilding work
/// the user produced. The list mirrors the cleaning targets in
/// `lib/data/cleaning_targets.dart`.
const _reclaimableMatches = <String>[
  'Caches',
  'Logs',
  'DerivedData',
  '.npm',
  '.gradle',
  '.cargo',
  '/pip',
  '/Homebrew',
  'CoreSimulator/Caches',
  'iOS DeviceSupport',
  '/Library/Updates',
];

class CategoryClassifier {
  CategoryClassifier._();

  static String _home() => Platform.environment['HOME'] ?? '';

  /// Best-effort category from the absolute path. The order of matches matters
  /// — caches must beat the broader Library bucket, and `.app` must beat
  /// system before it gets misfiled.
  static StorageCategory categorize(String path) {
    final p = path;
    final home = _home();
    final lower = p.toLowerCase();

    if (p.endsWith('.app')) return StorageCategory.apps;
    if (p == '/Applications' || p.startsWith('/Applications/')) {
      return StorageCategory.apps;
    }

    if (lower.contains('/caches') ||
        lower.endsWith('/logs') ||
        lower.contains('/cache')) {
      return StorageCategory.cache;
    }

    if (p.startsWith('$home/Library/Developer') ||
        p.startsWith('$home/.npm') ||
        p.startsWith('$home/.gradle') ||
        p.startsWith('$home/.cargo') ||
        p.startsWith('$home/.m2') ||
        p.startsWith('$home/.android') ||
        p.startsWith('$home/Library/Containers/com.docker.docker')) {
      return StorageCategory.dev;
    }

    if (p.startsWith('$home/Movies') ||
        p.startsWith('$home/Pictures') ||
        p.startsWith('$home/Music')) {
      return StorageCategory.media;
    }

    if (p.startsWith('$home/Documents') ||
        p.startsWith('$home/Downloads') ||
        p.startsWith('$home/Desktop')) {
      return StorageCategory.docs;
    }

    if (p == '/System' ||
        p.startsWith('/System/') ||
        p == '/private' ||
        p.startsWith('/private/') ||
        p == '/var' ||
        p.startsWith('/var/') ||
        p == '/usr' ||
        p.startsWith('/usr/')) {
      return StorageCategory.sys;
    }

    if (p == '/Library' ||
        p.startsWith('/Library/') ||
        p.startsWith('$home/Library')) {
      return StorageCategory.lib;
    }

    return StorageCategory.other;
  }

  /// True when wiping the path is safe — caches, logs, and well-known build
  /// artifact dirs that the toolchain will rebuild on demand.
  static bool isReclaimable(String path) {
    for (final marker in _reclaimableMatches) {
      if (path.contains(marker)) return true;
    }
    return false;
  }
}
