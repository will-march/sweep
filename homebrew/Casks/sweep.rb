cask "sweep" do
  version "1.0.1"
  sha256 "bb5678259765f276ff05f6b9cbdbaea1a8766acf83019da5b9d105d0a25be660"

  url "https://github.com/will-march/sweep/releases/download/v#{version}/Sweep-macos-v#{version}.dmg",
      verified: "github.com/will-march/sweep"
  name "Sweep"
  desc "Native macOS cache cleaner with tree-map, scheduled scans and uninstaller"
  homepage "https://github.com/will-march/sweep"

  livecheck do
    url :url
    strategy :github_latest
  end

  # The macOS Sequoia (15) and Sonoma (14) builds are arm64 + x86_64
  # universal — the same .app runs on Apple Silicon and Intel.
  depends_on macos: ">= :catalina"

  app "Sweep.app"

  # Drop a CLI wrapper into the Homebrew bin so users can just type
  # `sweep <subcommand>` instead of `/Applications/Sweep.app/
  # Contents/MacOS/Sweep --headless <subcommand>`. The wrapper
  # itself is a small shell script — no admin needed because
  # HOMEBREW_PREFIX is owned by the user.
  postflight do
    bin = "#{HOMEBREW_PREFIX}/bin"
    FileUtils.mkdir_p(bin)
    wrapper = "#{bin}/sweep"
    File.write(wrapper, <<~SH)
      #!/bin/sh
      # Sweep CLI wrapper — installed by the Homebrew cask.
      for candidate in \\
        "/Applications/Sweep.app" \\
        "$HOME/Applications/Sweep.app"; do
        if [ -x "$candidate/Contents/MacOS/Sweep" ]; then
          exec "$candidate/Contents/MacOS/Sweep" --headless "$@"
        fi
      done
      echo "Sweep.app not found in /Applications or ~/Applications" >&2
      exit 127
    SH
    FileUtils.chmod 0755, wrapper
  end

  uninstall_postflight do
    FileUtils.rm_f("#{HOMEBREW_PREFIX}/bin/sweep")
  end

  # Sweep persists state under ~/Library/Application Support/Sweep
  # (history, exclusions, schedule, restore log, threat definitions,
  # icon cache, headless logs). Optional uninstall helpers below
  # surface that to anyone removing the cask cleanly.
  zap trash: [
    "~/Library/Application Support/Sweep",
    "~/Library/Caches/dev.willmarch.sweep",
    "~/Library/Preferences/dev.willmarch.sweep.plist",
    "~/Library/Saved Application State/dev.willmarch.sweep.savedState",
    "~/Library/LaunchAgents/dev.willmarch.sweep.scheduler.plist",
  ]

  caveats <<~EOS
    The CLI wrapper has been installed to:
        #{HOMEBREW_PREFIX}/bin/sweep

    Try `sweep help` to see every subcommand. The wrapper just
    forwards args to Sweep.app's binary in --headless mode, so
    `sweep light-scrub` runs the cleaner without opening the GUI.

    Sweep is not yet signed with an Apple Developer ID. The first
    launch will be blocked by Gatekeeper — right-click the app in
    Applications and choose "Open" to confirm. After that, normal
    double-click works.

    The launchd agent at ~/Library/LaunchAgents/dev.willmarch.sweep.scheduler.plist
    runs `sweep scheduled-job`. Disable it from the Schedule
    screen or with `sweep agent uninstall` before removing the
    cask if you don't want orphan jobs.
  EOS
end
