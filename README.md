# iMaculate

> A native macOS cache cleaner built in Flutter — four cleanup modes, a live disk tree-map, and a Trash-first deletion policy so you never lose anything you didn't mean to.

<p align="center">
  <img src="docs/screenshots/hero.png" alt="iMaculate hero shot" width="820"/>
</p>

<p align="center">
  <a href="https://github.com/will-march/imaculate/releases/latest">
    <img alt="Download for macOS" src="https://img.shields.io/badge/Download-macOS%20.dmg-7f5af0?style=for-the-badge&logo=apple&logoColor=white"/>
  </a>
  &nbsp;
  <a href="https://github.com/will-march/imaculate/releases/latest">
    <img alt="GitHub release" src="https://img.shields.io/github/v/release/will-march/imaculate?style=for-the-badge&color=1d1d1f"/>
  </a>
  &nbsp;
  <img alt="brew tap" src="https://img.shields.io/badge/brew-will--march%2Ftap-fbb040?style=for-the-badge&logo=homebrew&logoColor=white"/>
</p>

<p align="center">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS%2010.15%2B-1d1d1f?style=flat-square"/>
  <img alt="flutter" src="https://img.shields.io/badge/flutter-3.0%2B-02569B?style=flat-square&logo=flutter&logoColor=white"/>
  <img alt="dart"    src="https://img.shields.io/badge/dart-3.0%2B-0175C2?style=flat-square&logo=dart&logoColor=white"/>
  <img alt="status"  src="https://img.shields.io/badge/status-actively%20developed-7f5af0?style=flat-square"/>
</p>

> **Get it now:** the [latest release](https://github.com/will-march/imaculate/releases/latest) ships a `.dmg` (drag-to-Applications) and a `.zip` of the `iMaculate.app` bundle. macOS 10.15+, Apple Silicon and Intel.

---

## Showcase

<p align="center">
  <img src="docs/screenshots/cleaner.png" alt="Cleaner screen — Light Scrub" width="820"/>
  <br/>
  <em>Cleaner — Light Scrub mode. Risk-tagged caches, one-click reclaim, live total.</em>
</p>

> Additional screenshots (Tree Map, Splash, Permission prompt) and demo gifs go under [`docs/screenshots/`](docs/screenshots) and [`docs/gifs/`](docs/gifs). See [`docs/screenshots/CAPTURE.md`](docs/screenshots/CAPTURE.md) for the exact filenames + sizes the README will pick up — the showcase block expands automatically once they're committed.

---

## Why this exists

macOS quietly hoards gigabytes in caches, derived data, simulator runtimes, and old archives. The built-in tools don't show *where* the bytes went, and most third-party cleaners either delete too aggressively or hide what they're touching.

iMaculate's design rules:

1. **Show the path, the size, and the risk** before anything is touched.
2. **Trash first, delete second** — moves go to Finder's Trash by default; permanent removal is opt-in.
3. **Privilege only when needed** — system caches require admin; everything else runs as your user.
4. **No network. No telemetry.** Disk only.

---

## Cleaning modes

| Mode                | Icon | Targets                                        | Typical reclaim | Risk                          |
| ------------------- | ---- | ---------------------------------------------- | --------------- | ----------------------------- |
| **Light Scrub**  ✨  | ✨    | `~/Library/Caches`, `~/Library/Logs`           | 100 MB – 1 GB   | Safe for daily use            |
| **Boilwash**     🔥 | 🔥   | + Xcode DerivedData, iOS sim caches, `/Library/Caches` | 1 – 10 GB       | Generally safe                |
| **Sandblast**    💥 | 💥   | + `/Library/Updates`, `/var/log`, Xcode archives, iOS device backups | 5 – 30+ GB      | Advanced — admin required     |
| **Development**  🛠️ | 🛠️   | Homebrew, npm, pip, Gradle, Cargo, Maven, Docker VMs, AVDs, Xcode | 2 – 50+ GB      | Mixed — re-downloads on demand |

Exact paths live in [`lib/data/cleaning_targets.dart`](lib/data/cleaning_targets.dart). Each entry carries a `RiskLevel` (`safe`, `moderate`, `higher`) that drives the chip colour and the deletion path.

> **Boilwash** is named for the laundry cycle — hot enough to clean, not hot enough to ruin the fabric. **Sandblast** is the "I know what I'm doing" mode.

---

## How deletion actually works

Cache removal funnels through two services:

- [`TrashService`](lib/services/trash_service.dart) — default path. Calls Finder via `osascript` to move the entry to the Trash. Recoverable.
- [`CacheRemover`](lib/services/cache_remover.dart) — used for `RiskLevel.higher` items when the user has granted admin. Runs `find … -mindepth 1 -delete` under `osascript ... with administrator privileges` so the cache *parent* directory survives (apps that re-create their own cache get unhappy when the parent vanishes).

Sizes come from [`CacheScanner`](lib/services/cache_scanner.dart): privileged scans use `du -sk`; unprivileged scans walk the tree in Dart and skip what they can't read. Either way, scans are async and the UI stays interactive.

---

## Architecture at a glance

```
lib/
├── main.dart                 # Entry — runs IMaculateApp
├── app.dart                  # Theme + first-launch gate (splash vs. shell)
├── data/
│   └── cleaning_targets.dart # Hard-coded paths per cleaning mode
├── models/                   # CacheTarget, CacheEntry, CleaningLevel, NavSelection, …
├── screens/
│   ├── splash_screen.dart    # Aurora intro shown once per machine
│   ├── home_shell.dart       # Sidebar + app bar shell, holds NavSelection
│   ├── cleaner_screen.dart   # Per-mode cache list + reclaim flow
│   └── tree_map_screen.dart  # Live disk drill-down view
├── services/
│   ├── permission_service.dart   # osascript-based admin escalation
│   ├── path_resolver.dart        # `~`, `$USER`, absolute path expansion
│   ├── cache_scanner.dart        # du -sk / fallback walk
│   ├── cache_remover.dart        # Privileged empty-in-place
│   ├── trash_service.dart        # Default: send to Finder Trash
│   ├── disk_scanner.dart         # Tree-map streaming scan
│   ├── disk_stats_service.dart   # Total / free space lookup
│   └── first_launch_service.dart # Splash gate marker
├── theme/                    # AppTheme + Aurora colour tokens + risk palette
├── utils/                    # byte_formatter, splash animation curves
└── widgets/                  # Aurora sidebar/app-bar, donut, scan ring, splash bits
```

---

## Install

### Homebrew (recommended)

```sh
brew tap will-march/tap
brew install --cask imaculate
```

The cask pulls the `.dmg` from the latest GitHub release, drags `iMaculate.app` into `/Applications`, and prints the Gatekeeper override one-liner. Updates land via `brew upgrade --cask imaculate`. Clean uninstall with `brew uninstall --cask --zap imaculate` — the `--zap` flag also wipes `~/Library/Application Support/iMaculate` and the launchd agent plist.

### Direct download

Head to **[releases/latest](https://github.com/will-march/imaculate/releases/latest)** for the latest `.dmg` (drag-to-Applications, ~20 MB) or `.zip` (raw `.app`, ~50 MB). Drag `iMaculate.app` to `/Applications`.

**First launch** — macOS Gatekeeper will refuse to open it because the build isn't signed with an Apple Developer ID yet. Right-click `iMaculate.app` → **Open** → **Open** to override. Subsequent launches work normally.

iMaculate will request administrator privileges so it can read system caches under `/Library` and `/var`. Decline if you only want user-scope cleaning — everything else still works.

---

## Command-line interface

The `.app` ships a full CLI surface — every GUI feature is also reachable from a terminal, launchd, cron, or ssh. The binary inside the bundle does double duty: with no flags it opens the GUI, with `--headless` it runs a subcommand and exits.

### Getting `imaculate` on your `$PATH`

Three ways, in order of friction:

- **Homebrew install (recommended)** — the cask drops a wrapper at `$HOMEBREW_PREFIX/bin/imaculate` automatically. Just type `imaculate help` after `brew install --cask imaculate`.
- **DMG install** — open iMaculate, click the menu bar icon (sparkle in the system bar), pick **Install Command-Line Tool…**. The action probes `/opt/homebrew/bin` first (no admin needed on Apple Silicon Homebrew); falls back to `/usr/local/bin` with an admin prompt otherwise. The same menu item flips to "Uninstall" once installed.
- **Manual** — paste this if you'd rather skip the GUI step:
  ```sh
  sudo tee /usr/local/bin/imaculate >/dev/null <<'SH'
  #!/bin/sh
  for app in "/Applications/iMaculate.app" "$HOME/Applications/iMaculate.app"; do
    [ -x "$app/Contents/MacOS/iMaculate" ] && exec "$app/Contents/MacOS/iMaculate" --headless "$@"
  done
  echo "iMaculate.app not found" >&2; exit 127
  SH
  sudo chmod +x /usr/local/bin/imaculate
  ```

After install, `imaculate help` should print the full subcommand reference. (`/usr/bin` is SIP-protected on macOS; we install to `/usr/local/bin` or `/opt/homebrew/bin`, both of which are on the default `$PATH`.)

### Subcommand reference

| Subcommand | What it does |
| --- | --- |
| `help` | Print the full CLI help (the same content as below). |
| `light-scrub` | Empty user caches and logs. Safe for cron / scheduled runs. |
| `boilwash` | Light Scrub + Xcode DerivedData + iOS simulator caches + system app caches. |
| `sandblast [--admin]` | Deep clean — adds `/Library/Updates`, `/var/log`, Xcode archives, iOS device backups. Add `--admin` for `/Library` + `/var`. |
| `development` | Build-tool caches: npm, gradle, cargo, Maven, pip, Homebrew, Xcode DerivedData, Docker VMs, AVDs. |
| `update-defs` | Pull the latest threat signatures from abuse.ch MalwareBazaar. |
| `scan-threats` | Hash-match `/Applications`, `~/Downloads`, `~/Library/LaunchAgents` against local definitions; hits land in History. |
| `tree-map [path]` | Print the top-20 entries by size at `[path]` (defaults to `$HOME`). |
| `list-apps` | List every `.app` under `/Applications` + `~/Applications` with bundle ID and total disk impact (bundle + leftovers). |
| `uninstall <id\|name\|path>` | Archive the bundle plus every leftover (Caches, Application Support, Containers, etc.) to `~/.Trash` and record a restore id. |
| `exclusions list` / `add <path>` / `remove <path>` | Manage the prefix-match exclusion list. Honoured by both cleaner and tree-map. |
| `schedule status` | Print current schedule + last-run timestamp. |
| `schedule set <off\|daily\|weekly\|monthly> [--light-scrub] [--threat-scan] [--update-defs]` | Configure the scheduled job. Negate any task with the `--no-…` form. |
| `scheduled-job` | Run the configured schedule once — what launchd invokes. |
| `agent status` | Whether the launchd agent plist is installed. |
| `agent install` | Write `~/Library/LaunchAgents/com.imaculate.scheduler.plist` and bootstrap it via `launchctl bootstrap gui/$UID`. The plist runs `iMaculate --headless scheduled-job` at 03:30 local time on the configured cadence. |
| `agent uninstall` | `bootout` + delete the plist. |
| `launch-items list` / `remove <plist\|label>` | Inspect / disable launchd agents in `~/Library/LaunchAgents`, `/Library/LaunchAgents`, `/Library/LaunchDaemons`. Removed plists are archived to Trash so they're restorable. |
| `history [limit]` | Print the most recent History entries (default 20). |
| `restore` | List restorable archive entries from the local restore log. |
| `restore <id>` | Move every item inside that archive back to its original path. Refuses to overwrite. |
| `reset-onboarding` | Clear splash / tour / walkthrough markers — next GUI launch replays the full intro. |

### Recipes

**Reclaim user caches every night** (no GUI needed):

```sh
imaculate schedule set daily --light-scrub --no-threat-scan --no-update-defs
imaculate agent install
```

**Heavier weekly job** with threat scan and definitions refresh:

```sh
imaculate schedule set weekly --light-scrub --threat-scan --update-defs
imaculate agent install
```

**Run the configured job once, right now:**

```sh
imaculate scheduled-job
```

**Inspect what's about to happen** before scheduling: `imaculate schedule status`, `imaculate agent status`.

**Remove an app + every leftover** with one command:

```sh
imaculate uninstall com.tinyspeck.slackmacgap
# Note the restore id printed at the end. To put it back:
imaculate restore <id>
```

**Audit launch items** for adware:

```sh
imaculate launch-items list   # `!` prefix flags suspicious entries
imaculate launch-items remove com.adware.example.agent
```

### Logs

Every headless / launchd-driven run appends to `~/Library/Application Support/iMaculate/logs/headless.log` and (when launched by the agent) `scheduler.out.log` / `scheduler.err.log` in the same dir. The menu bar's **Reveal Logs in Finder** opens that folder.

---

## Run / rebuild from source

### Prerequisites

- macOS 10.15+
- Flutter SDK 3.0 or newer (`flutter --version`)
- Xcode + Command Line Tools (CocoaPods picks these up for the macOS shell)
- Optional: an admin password handy for the Sandblast / system-cache flows

### One-shot rebuild

```bash
git clone https://github.com/will-march/imaculate.git
cd imaculate
flutter pub get
flutter run -d macos
```

### Clean rebuild (when something feels off)

```bash
flutter clean
rm -rf macos/Pods macos/Flutter/ephemeral build .dart_tool
flutter pub get
flutter run -d macos
```

### Release build

```bash
flutter build macos --release
open build/macos/Build/Products/Release/iMaculate.app
```

The signed `.app` lands in `build/macos/Build/Products/Release/`. Drag it to `/Applications` to install.

### Tests

```bash
flutter test
```

Unit tests live under [`test/`](test). The cache/trash services are deliberately thin wrappers over `osascript` so they're easy to fake in tests.

---

## Permissions

On launch, [`PermissionService`](lib/services/permission_service.dart) fires a single `osascript … with administrator privileges` call. The macOS auth ticket lasts ~5 minutes, so subsequent privileged operations don't re-prompt during a normal session.

| Lock state | Meaning                              | What you can clean                   |
| ---------- | ------------------------------------ | ------------------------------------ |
| 🔓 Open    | Admin granted                        | Everything in the four modes         |
| 🔒 Closed  | Standard user                        | User-scope caches only — no `/Library`, no `/var` |

Decline the auth dialog and the app stays useful — just a smaller blast radius.

---

## Project status / roadmap

- [x] Light / Boilwash / Sandblast / Development modes
- [x] Trash-first deletion with admin opt-in
- [x] Live tree-map drill-down
- [x] First-launch splash with Aurora theme
- [ ] Scheduled / unattended cleans
- [ ] Per-app exclusion lists
- [ ] Cleaning history + before/after report
- [ ] Localisation

---

## Contributing

PRs are welcome. Two house rules:

1. **Don't add a path to `cleaning_targets.dart` without a `RiskLevel`.** The UI fans out from that field.
2. **Privileged operations must go through `osascript`** with quoted-form escaping — see `CacheRemover._privilegedEmpty` for the pattern. Don't shell out raw paths.

Run `flutter analyze` and `flutter test` before opening a PR.

---

## Privacy

iMaculate doesn't talk to the network. Ever. There's no analytics, no crash reporting, no auto-updater. The entire surface area is local disk + Finder + `osascript`.

---

## Licence

MIT. See [`LICENSE`](LICENSE) once added — until then, treat the source as MIT-licensed (see commit history for authorship).

---

<p align="center"><sub><em>iMaculate — keep your Mac clean, keep your data.</em></sub></p>
