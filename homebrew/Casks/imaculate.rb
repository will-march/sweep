cask "imaculate" do
  version "1.0.1"
  sha256 "bb5678259765f276ff05f6b9cbdbaea1a8766acf83019da5b9d105d0a25be660"

  url "https://github.com/will-march/imaculate/releases/download/v#{version}/iMaculate-macos-v#{version}.dmg",
      verified: "github.com/will-march/imaculate"
  name "iMaculate"
  desc "Native macOS cache cleaner with tree-map, scheduled scans and uninstaller"
  homepage "https://github.com/will-march/imaculate"

  livecheck do
    url :url
    strategy :github_latest
  end

  # The macOS Sequoia (15) and Sonoma (14) builds are arm64 + x86_64
  # universal — the same .app runs on Apple Silicon and Intel.
  depends_on macos: ">= :catalina"

  app "iMaculate.app"

  # iMaculate persists state under ~/Library/Application Support/iMaculate
  # (history, exclusions, schedule, restore log, threat definitions,
  # icon cache, headless logs). Optional uninstall helpers below
  # surface that to anyone removing the cask cleanly.
  zap trash: [
    "~/Library/Application Support/iMaculate",
    "~/Library/Caches/com.example.imaculate",
    "~/Library/Preferences/com.example.imaculate.plist",
    "~/Library/Saved Application State/com.example.imaculate.savedState",
    "~/Library/LaunchAgents/com.imaculate.scheduler.plist",
  ]

  caveats <<~EOS
    iMaculate is not yet signed with an Apple Developer ID. The first
    launch will be blocked by Gatekeeper — right-click the app in
    Applications and choose "Open" to confirm. After that, normal
    double-click works.

    The launchd agent at ~/Library/LaunchAgents/com.imaculate.scheduler.plist
    runs `iMaculate --headless scheduled-job`. Disable it from the
    Schedule screen or with `iMaculate --headless agent uninstall`
    before removing the cask if you don't want orphan jobs.
  EOS
end
