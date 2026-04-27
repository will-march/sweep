# Sweep · 90-day Marketing Plan

A standalone playbook for taking Sweep from "code on a private fork" to "$30–80k/yr indie macOS app on no ad budget." Two halves:

1. **[Pre-launch software readiness](#pre-launch-software-readiness)** — what to fix in the app *before* the first public push. Don't market a v1.0 that hits Gatekeeper warnings.
2. **[The 90-day plan](#the-90-day-plan)** — week-by-week schedule for the launch itself.

---

## Positioning

> **Sweep is the open-source macOS cleaner that puts every deletion in a restorable archive. Free for one Mac. MIT-licensed. No telemetry. No upsell ads. The threat feed is public.**

Three differentiators MacPaw can't credibly claim:

1. **Restorable deletes.** Every clean / uninstall / quarantine zips to `~/.Trash` with a manifest; one click restores. CleanMyMac's "delete" is a one-way trip to `rm -rf`.
2. **Open-source threat feed.** Hashes from `abuse.ch`'s public MalwareBazaar. Anyone can audit. CleanMyMac's malware DB is proprietary and uninspectable.
3. **MIT-licensed and `brew install`-able.** Read the code. Fork it. Audit it. Ship your own variant. CleanMyMac's source is closed and they actively pursue clones.

Every piece of marketing copy should land on one of those three. Stop trying to compete on "more features" — they have a $25M/yr team, you don't.

---

## Target audience

- **Primary**: macOS power users / developers / sysadmins. People who have ever typed `rm -rf` in anger. They post on r/MacOS, lurk on HN, and pay for things like Tower, BetterTouchTool, Kaleidoscope.
- **Secondary**: privacy-cautious users who specifically distrust closed-source cleaners. Smaller pool but they shout about products they like.
- **Not your audience yet**: non-technical users who Google "clean mac". They'll go to MacPaw via paid ads forever. Don't try to compete there until year 3+.

The first 1,000 paying customers will all come from the primary group. Plan around them.

---

## Pricing model — phased

| Phase | When | Tier(s) | Why |
| --- | --- | --- | --- |
| **Phase 0** | Today → v1.1 ship | Free, OSS, no ads | Build trust + reputation. Charging now is a unforced error. |
| **Phase 1** | v1.1 (notarized + Sparkle) | **Free** + **Pro $19 one-time** | Pro = cloud-synced exclusions, premium full-corpus threat feed, priority signature updates, family license (up to 5 Macs). Free stays full-featured for one Mac. |
| **Phase 2** | ~6 months later | + **Setapp listing** | Independent income stream. ~$0.50–2/active-user/mo passive. |
| **Phase 3** | Year 2+ | Maybe a $39 lifetime license | Once you have proof of demand. |

**Rule:** the free tier is never crippleware. Anyone who downloads the free build can use every cleaning feature without limits on one Mac. Pro is a *convenience + cloud* upsell, not a feature gate. This is the Sublime/Tower/Vivaldi pattern and it works.

---

## Pre-launch software readiness

Don't fire the marketing cannon until these are done. Marketing-driven traffic is one-shot — burning HN's front page on a v1.0 that crashes is worse than not posting at all.

### P0 — blocks marketing entirely

These have to ship *before* you tell anyone outside your inner circle.

- [ ] **Apple Developer Program enrolment** ($99/yr). The prerequisite to everything else.
- [ ] **Developer ID Application code-signing.** Set `CODE_SIGN_IDENTITY` in Xcode. Every release artefact must be signed.
- [ ] **Notarization in the release pipeline.** `xcrun notarytool submit … --wait && xcrun stapler staple <dmg>`. Bake it into the GitHub Actions release workflow so cutting v1.x.y is one git tag.
- [ ] **Sparkle auto-update.** Add the [Sparkle 2 Swift package](https://sparkle-project.org/), generate Ed25519 keys, host the appcast on `sweep.app/appcast.xml`. Without this, every release requires users to manually re-download — Reddit will roast you for it.
- [ ] **`LICENSE` file at repo root.** README claims MIT but the file is missing. Legal hygiene; a few prosumers will refuse to install OSS without one.
- [ ] **Privacy policy.** Plain English, hosted at `sweep.app/privacy`. Even with zero telemetry you need it; payment processors and Setapp require one.
- [ ] **Crash reporting (opt-in)**. Sentry free tier. Without it you'll have no idea when v1.1.0 broke for a class of users.

### P1 — strongly recommended before launch

These won't block the post but they double conversion when present.

- [ ] **Real app icon.** The current sparkle gradient icon is a placeholder. Spend $200–500 with a designer (Dribbble, [Noun Project](https://thenounproject.com/), or use [App Icon Generator](https://appiconmaker.co/)) for a proper rounded-square macOS icon with optical adjustments. The icon is the Twitter avatar, the Dock face, the App Store thumbnail, the Finder preview. It works very hard.
- [ ] **DMG background art.** Current DMG opens to a blank window. CleanMyMac, Sketch, Tower etc all show a styled background with an arrow pointing from the app to the Applications shortcut. Use [`create-dmg`](https://github.com/sindresorhus/create-dmg) instead of plain `hdiutil`.
- [ ] **Landing page** at `sweep.app` (or whatever domain you grab). One page. Hero shot + 90s screencast + three-bullet differentiator + Download button + "what's new" + footer. Use [Astro](https://astro.build) or [Framer](https://www.framer.com/) — neither needs ad spend.
- [ ] **Window size memory.** Most macOS apps remember last position. Currently Sweep spawns at default size every launch. Small detail; users notice.
- [ ] **Keyboard shortcuts.** ⌘R rescan, ⌘, preferences, ⌘W close window (keeps menu bar alive), ⌘Q quit. Match macOS conventions.
- [ ] **Onboarding skip-on-already-shown.** Verify that `walkthrough_seen` actually prevents the live coachmark from firing again. If a user hits Skip then re-launches, do they see it again?
- [ ] **Hero screenshots that aren't the cleaner screen.** Tree Map drilled into Library/Caches with the detail panel populated → far more visual punch than a list.

### P2 — nice-to-have, won't block but worth the polish

- [ ] **Preferences screen.** Currently no central settings panel. Users want a place to flip theme, change default cleaning level, manage Sparkle channels.
- [ ] **App Store sandboxed variant.** Smaller feature set; secondary discovery channel. Plan for v1.2.
- [ ] **Localization completeness.** Scaffolding is there, most strings are still English. Push at least Spanish / Japanese / German to 80% — the Setapp Asia-Pacific audience cares.
- [ ] **Comparison table page.** "Sweep vs CleanMyMac vs OnyX" — honest, fair, three columns. Power users reference this when recommending you on Reddit.
- [ ] **Email capture on the landing page.** Even just "tell me when v1.1 ships." 200 emails on launch day → 200 first-day downloads.

### Marketing-specific assets

These don't ship in the app but they do ship in the launch.

- [ ] **90-second product screencast.** Show the splash → Light Scrub → reclaim 2 GB → restore from History. No voiceover needed; just background music + on-screen captions. ScreenStudio or QuickTime + iMovie. Upload to YouTube unlisted; embed in the landing page; gif version for Twitter.
- [ ] **Before/after hero shot.** Standard macOS marketing trope. "Before Sweep: 18 GB of caches you forgot existed. After: clean."
- [ ] **One-pager PDF / press kit.** App icon, three screenshots, two-paragraph description, key facts (size, requirements, license, price), founder quote, contact email. Email this to reviewers.
- [ ] **Reviewer outreach list.** 30–50 people. YouTubers (Snazzy Labs, MacRumors, Mac Sources, Stephen Robles), bloggers (MacStories, AppAddict, Mac Power Users podcast), newsletters (TLDR Mac, Mac.AppStorm), Twitter accounts (@parkerortolani, @rene), redditors who post mac apps regularly.

---

## The 90-day plan

### Days 1–30 — Build the launch foundation

**Goal: every P0 done, P1 ≥ 80% done.**

Week 1:
- Apple Developer enrolment, signing certs in Xcode keychain, sign the v1.0.1 build manually, verify Gatekeeper acceptance.
- Set up `sweep.app` domain ($12/yr Cloudflare or Porkbun). Park it.
- Write the privacy policy (steal Tot's structure, change the names).

Week 2:
- Sparkle 2 integration. Ship v1.0.2 with Sparkle wired up, no other changes — proves the auto-update path.
- Notarization wired into release script.
- LICENSE file committed.

Week 3:
- Designer brief for app icon. Pay the $300, accept on first round, ship with v1.1.
- Landing page first draft. Just hero + screenshot + download. Iterate next week.
- Sentry integration with opt-in toggle in the (new) Preferences screen.

Week 4:
- Preferences screen.
- Window size memory + keyboard shortcuts.
- Record the 90s screencast. Edit. Compress to GIF. Embed in README and landing page.
- Cut **v1.1.0** — signed, notarized, Sparkle-enabled, new icon, refined onboarding. **This is the version you market.**

### Days 31–45 — Soft launch / "validate the message"

**Goal: 50 real users, 5 honest reviews, zero "your app crashed" emails.**

Week 5:
- Submit to Setapp. Independent track; takes 4–8 weeks for a decision. Good to start the clock now.
- Post on r/macapps with a one-paragraph "I built this, would love feedback." Be unselfish — don't link a marketing page, link the GitHub release. Engage every comment.
- Email the 5 closest fellow indie macOS devs in your network. "I made this, can you try it and tell me what's broken." Free pro keys for them.
- Iterate based on what breaks. There will be things. Patch v1.1.x.

Week 6:
- Show HN dry run on a Sunday morning (lowest traffic day). Title: "Sweep – open-source CleanMyMac alternative with restorable deletes." Don't expect front page; gauge response.
- Tweet/Mastodon thread: "I built an open-source mac cleaner. Here's why every commercial cleaner is dishonest about what they delete." Real opinion, not marketing fluff.
- Reach out to 5 reviewers from the press kit list. *Personal* emails. "Hey [name], I've been reading your work for years. I built X for [reason]. Would you take a look?" No template-mailing.

### Days 46–60 — The big push

**Goal: ride the wave for two weeks. After that, normalise.**

Week 7 — coordinated launch week:
- **Monday 9am ET**: Show HN with the now-refined title. Reply to every top comment within 30 minutes for the first 4 hours. Have a 90s screencast ready to paste.
- **Tuesday**: Product Hunt launch. Pre-recruit 10 friends to upvote in the first hour (against PH rules to ask but everyone does it; just be quiet). Engage every commenter.
- **Wednesday**: r/MacOS post — but make it about a *story*, not the app. "I got tired of CleanMyMac's renewal tactics, so I built an open alternative. Here's what I learned about how mac cleaners actually work." Link to GitHub at the bottom.
- **Thursday**: blog post on your domain — "Building a macOS cleaner: what I learned about launchd, ditto, and the threat-detection ecosystem." Post to Hacker News separately.
- **Friday**: thank-you email to everyone who downloaded. Ask for honest feedback. Answer every reply.

Week 8 — sustain:
- Reply to every review/mention/issue. People will write things. Respond.
- Patch any bugs the launch surfaced. Cut v1.1.1 fast.
- Reach out to 5 more reviewers, this time linking to the launch coverage you already have.

### Days 61–90 — Compound effects

**Goal: convert launch attention into a sustainable trickle.**

Weeks 9–10:
- Write follow-up content. "v1.1 ships notarized — here's what changed." "Real-world numbers from 1,000 cleans." "How Sweep's restore log actually works." Each post is fuel for the SEO + Reddit ecosystem.
- Set up GitHub Sponsors. Modest income, but visible "support" button matters psychologically to OSS users.
- Submit to MacUpdate, AlternativeTo, Mac.AppStorm round-up requests.

Weeks 11–12:
- Pro SKU launches. Gumroad page, $19 one-time, three benefits (cloud sync, premium feed, priority Sparkle channel). Email the v1.0 free downloads list — *not* with a hard sell, with a "v1.1 is here, free version still works forever, here's what Pro adds."
- Take stock. How many free downloads? How many Pro purchases? What's your conversion rate? (Industry rule of thumb for open-core Mac apps: 0.5–3% of free → paid in year 1.)

---

## Channels and cadence after the launch window

Once the 90 days end, switch to **maintenance marketing** — sustainable forever:

| Cadence | Channel | What |
| --- | --- | --- |
| Weekly | Twitter/Mastodon | One useful thread or screenshot. "How Sweep found 3 GB of orphan launch agents on my Mac." |
| Bi-weekly | Blog | One short technical post. SEO compounds for years. |
| Monthly | Newsletter | Updates to existing users. Build the list. |
| Per release | All channels | "v1.x ships with [feature]." Coordinate Twitter + Mastodon + r/macapps + HN if interesting enough. |
| Quarterly | YouTube reviewers | Re-pitch with the latest version. |

**Total time investment:** 5–10 hours/week, sustained. The reason most indie apps fail at month 4 is the founder stops doing this.

---

## Metrics to track

Set these up *before* launch. Use Plausible / Fathom for the landing page (privacy-respecting, no ads), GitHub release-asset download counts for the app itself, Gumroad/Paddle dashboards for paid conversions, Sentry for crashes.

- **DAU / WAU**: how many opens per week. Goal end-of-year-1: 1,000 WAU.
- **Free-to-pro conversion**: % of free users who upgrade. Goal: 1–2%.
- **Crash-free sessions**: %. Goal: 99.5%+.
- **Setapp activations**: per month, once accepted. Goal: 200 by month 6.
- **GitHub stars**: vanity but real for OSS credibility. Goal: 1,000 by end of year 1.
- **Inbound mentions**: weekly count of "Sweep" appearing in posts you didn't write. This is the *real* signal that organic marketing is compounding.

---

## Year-1 milestones (realistic, not optimistic)

| Month | Where you should be |
| --- | --- |
| 1 | v1.1 shipped notarized. 50 downloads. |
| 3 | Setapp accepted (or rejected — both useful info). 500 downloads. First Pro sale. |
| 6 | $500–2,000 cumulative. 5,000 downloads. Some YouTube coverage. r/macapps regular mention. |
| 9 | $2,000–8,000. 15,000 downloads. Setapp generating $200–500/mo passive. |
| 12 | $5,000–15,000 total revenue. Decision point: keep going (year 2 is where it pays) or shelve. |

**If by month 9 you're below $1,000 cumulative and have <2,000 downloads, the messaging is wrong, not the app.** Rewrite the positioning, ship a fresh launch, repeat. Don't conclude the project is dead — conclude the *current message* didn't land.

---

## Budget — total cash out for year 1

| Item | Cost |
| --- | --- |
| Apple Developer Program | $99 |
| Domain `sweep.app` | $24/yr |
| Designer for app icon | $300 (one-time) |
| Sparkle / Sentry / Plausible | $0 (free tiers cover ≥1k users) |
| Cloudflare / Netlify hosting | $0 |
| Gumroad/Paddle fees | 5–7% of each sale |
| Reviewer outreach (free copies, swag) | $50–100 |
| **Total cash out** | **~$500** |
| **Total time investment** | **300–500 hours** |

Hours is the real currency. Cash is rounding error.

---

## What to do *this* week

The marketing plan is useless without the v1.1 build to market. So:

1. **Today**: enrol in the Apple Developer Program. The 24-hour provisioning window is the bottleneck — start it before anything else.
2. **Tomorrow**: order the icon. The designer is your bottleneck for week 4. Email a brief now.
3. **This week**: Sparkle integration. Cut v1.0.2 with Sparkle wired up, no other changes — proves the channel works for the next release.
4. **Next week**: notarization in the release script + landing page first draft + LICENSE + privacy policy.

Don't overthink the marketing copy yet — that gets a week of focused effort once the software is ready. Get the foundation done first.
