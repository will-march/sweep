# Capture guide

The README references these exact files. Drop matching images/gifs at the paths below and the README renders without further edits.

## Screenshots — `docs/screenshots/`

| Filename          | Shot                                                                                                  | Suggested size |
| ----------------- | ----------------------------------------------------------------------------------------------------- | -------------- |
| `hero.png`        | Cleaner screen post-scan with a healthy reclaim total visible. Window only, no shadow.                | 1640 × 1024    |
| `cleaner.png`     | Cleaner screen mid-scan, risk chips visible, at least one `higher`-risk row.                          | 1640 × 1024    |
| `tree_map.png`    | Tree Map screen drilled one level deep, with the breadcrumb showing.                                  | 1640 × 1024    |
| `splash.png`      | First-launch Aurora splash, "Continue" CTA visible.                                                   | 1640 × 1024    |
| `permission.png`  | macOS admin prompt overlay (Cmd+Shift+4 area-grab the dialog only).                                   | 800 × 600      |

### How to capture (macOS)

```bash
# Window grab (clean, with rounded corners and shadow on transparent bg)
# Press Cmd+Shift+4, then Space, then click the iMaculate window.

# Strip shadow and trim to window only:
# Hold Option while clicking — saves to ~/Desktop without the drop shadow.
```

If the window is already at retail size, you can also use:

```bash
screencapture -o -W docs/screenshots/cleaner.png
# -o : no shadow, -W : pick window with mouse
```

## Gifs — `docs/gifs/`

| Filename       | Demo                                                                              | Length        |
| -------------- | --------------------------------------------------------------------------------- | ------------- |
| `clean_run.gif`| Light Scrub end-to-end: open → scan → review → clean → empty state.               | 8–15s, ~720px wide |
| `tree_map.gif` | Tree Map: load → click into a hot directory → breadcrumb back up.                 | 6–12s, ~720px wide |

### Recording

Easiest path on macOS:

1. **Record screen** with QuickTime (File → New Screen Recording) and select the iMaculate window.
2. Convert `.mov` → `.gif` with `ffmpeg`:

    ```bash
    ffmpeg -i input.mov -vf "fps=18,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" \
      -loop 0 docs/gifs/clean_run.gif
    ```

    Tweak `fps` (12–20) and `max_colors` (96–192) to balance smoothness vs. file size. Aim under 4 MB so GitHub's preview doesn't lazy-load awkwardly.

Alternatively, use [Gifski](https://gif.ski/) or [Kap](https://getkap.co/) — both produce smaller, sharper gifs than ffmpeg defaults.

## Tips

- Run on a **clean Desktop** (hide other windows) so the screenshot doesn't leak unrelated app names.
- Use a **solid wallpaper** behind the window — busy wallpapers fight the Aurora gradient.
- For dark/light parity: capture each shot in **Dark Mode**, since that's where the Aurora theme reads strongest. The tree-map shot is the exception — light mode reads better there.
- Don't include a real Trash count or sensitive paths in screenshots. Empty Trash and reset to a clean home directory if you can.
