import '../models/cache_target.dart';
import '../models/cleaning_level.dart';

const _lightScrub = <CacheTarget>[
  CacheTarget(
    path: '~/Library/Caches',
    name: 'User Application Caches',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/Library/Logs',
    name: 'User Log Files',
    risk: RiskLevel.safe,
  ),
];

const _boilwash = <CacheTarget>[
  ..._lightScrub,
  CacheTarget(
    path: '~/Library/Developer/Xcode/DerivedData',
    name: 'Xcode Derived Data',
    risk: RiskLevel.moderate,
  ),
  CacheTarget(
    path: '~/Library/Developer/CoreSimulator/Caches',
    name: 'iOS Simulator Caches',
    risk: RiskLevel.moderate,
  ),
  CacheTarget(
    path: '/Library/Caches',
    name: 'System Application Caches',
    risk: RiskLevel.moderate,
  ),
];

const _sandblast = <CacheTarget>[
  ..._boilwash,
  CacheTarget(
    path: '/Library/Updates',
    name: 'macOS Update Cache',
    risk: RiskLevel.higher,
  ),
  CacheTarget(
    path: '~/Library/Caches/com.apple.SoftwareUpdate',
    name: 'Software Update Cache',
    risk: RiskLevel.higher,
  ),
  CacheTarget(
    path: '~/Library/Developer/Xcode/iOS DeviceSupport',
    name: 'Xcode Device Support Files',
    risk: RiskLevel.higher,
  ),
  CacheTarget(
    path: '~/Library/Developer/Xcode/Archives',
    name: 'Xcode Archives',
    risk: RiskLevel.higher,
  ),
  CacheTarget(
    path: '/var/log',
    name: 'System Log Files',
    risk: RiskLevel.higher,
  ),
  CacheTarget(
    path: '~/Library/Application Support/MobileSync/Backup',
    name: 'iOS Device Backups (irreversible)',
    risk: RiskLevel.higher,
  ),
];

const _development = <CacheTarget>[
  CacheTarget(
    path: '~/Library/Caches/Homebrew',
    name: 'Homebrew Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/Library/Caches/pip',
    name: 'Python pip Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/.npm/_cacache',
    name: 'npm Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/.gradle/caches',
    name: 'Gradle Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/.cargo/registry/cache',
    name: 'Rust Cargo Registry Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/.cache',
    name: 'User Cache Directory',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/Library/Caches/com.apple.dt.Xcode',
    name: 'Xcode App Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/.android/build-cache',
    name: 'Android Build Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/.m2/repository',
    name: 'Maven Repository',
    risk: RiskLevel.moderate,
  ),
  CacheTarget(
    path: '~/Library/Developer/Xcode/DerivedData',
    name: 'Xcode Derived Data',
    risk: RiskLevel.moderate,
  ),
  CacheTarget(
    path: '~/Library/Developer/Xcode/iOS DeviceSupport',
    name: 'Xcode Device Support',
    risk: RiskLevel.moderate,
  ),
  CacheTarget(
    path: '~/Library/Developer/Xcode/Archives',
    name: 'Xcode Archives',
    risk: RiskLevel.higher,
  ),
  CacheTarget(
    path: '~/Library/Developer/CoreSimulator/Devices',
    name: 'iOS Simulator Devices',
    risk: RiskLevel.higher,
  ),
  CacheTarget(
    path: '~/.android/avd',
    name: 'Android Emulators',
    risk: RiskLevel.higher,
  ),
  CacheTarget(
    path: '~/Library/Containers/com.docker.docker/Data/vms',
    name: 'Docker VM Disk Images',
    risk: RiskLevel.higher,
  ),
  // ----- Browser caches (granular) -----
  CacheTarget(
    path: '~/Library/Caches/com.apple.Safari',
    name: 'Safari Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/Library/Caches/com.apple.WebKit.GPU',
    name: 'Safari WebKit GPU Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/Library/Caches/Google/Chrome',
    name: 'Chrome Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/Library/Application Support/Google/Chrome/Default/Service Worker',
    name: 'Chrome Service Workers',
    risk: RiskLevel.moderate,
  ),
  CacheTarget(
    path: '~/Library/Caches/com.google.Chrome.helper',
    name: 'Chrome Helper Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/Library/Caches/Firefox',
    name: 'Firefox Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/Library/Caches/Microsoft Edge',
    name: 'Microsoft Edge Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/Library/Caches/BraveSoftware',
    name: 'Brave Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/Library/Caches/com.operasoftware.Opera',
    name: 'Opera Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/Library/Caches/com.vivaldi.Vivaldi',
    name: 'Vivaldi Cache',
    risk: RiskLevel.safe,
  ),
  // ----- Toolchain caches (granular) -----
  CacheTarget(
    path: '~/Library/pnpm/store',
    name: 'pnpm Store',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/.yarn/cache',
    name: 'Yarn Berry Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/.deno/cache',
    name: 'Deno Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/.bun/install/cache',
    name: 'Bun Install Cache',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/.pub-cache/hosted',
    name: 'Dart pub cache (hosted)',
    risk: RiskLevel.safe,
  ),
  CacheTarget(
    path: '~/.rustup/toolchains',
    name: 'rustup toolchains',
    risk: RiskLevel.moderate,
  ),
  CacheTarget(
    path: '~/Library/Caches/CocoaPods',
    name: 'CocoaPods Cache',
    risk: RiskLevel.safe,
  ),
];

List<CacheTarget> targetsFor(CleaningLevel level) => switch (level) {
      CleaningLevel.lightScrub => _lightScrub,
      CleaningLevel.boilwash => _boilwash,
      CleaningLevel.sandblast => _sandblast,
      CleaningLevel.development => _development,
    };
