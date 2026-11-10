# LivePaper Follow

**macOS live wallpaper that mirrors Apple Aerials on your desktop — and can sync the same video to Lock Screen.**

Menu-bar app for macOS Tahoe (Apple Silicon). Built on the original LivePaper idea (MIT), focused on one thing: your desktop should match what you already choose in **System Settings → Wallpaper**.

---

## Why it’s useful

Apple’s Landscape aerials (Golden Gate, Tahoe, Sequoia, etc.) look great on the lock screen, but the **desktop** often stays a still image. LivePaper Follow fixes that:

| Without LivePaper | With LivePaper Follow |
|-------------------|------------------------|
| Lock may show aerial video; desktop is static | Desktop plays the same aerial pack as video |
| You juggle separate wallpaper apps | One app that **follows** Apple’s downloads |
| Day / night packs don’t match the desktop | **Time of day** or **manual** pick, optional **system sync** |

You download clips once in Wallpaper Settings. LivePaper does the rest.

---

## What you can do

### Follow Apple Aerials
- Reads the pack you use in System Settings (e.g. Golden Gate Day / Evening / Night / Sunset)
- Plays those videos as a live desktop wallpaper
- Works under open apps; built to avoid flicker on minimize/restore

### Playback modes
- **Manual / Selected** — play the clip you pick (menu or Dashboard)
- **Time of day** — auto switch Morning / Day / Evening / Night / Sunset by clock

### System Wallpaper sync
- **Also set System Wallpaper** — writes the same aerial to **Desktop + Lock Screen** in System Settings
- Lock screen keeps showing **video** (not only a still)

### Menu bar control
- Original LivePaper menu icon
- Open Dashboard, pause/resume, choose wallpaper, refresh
- **Hide menu bar icon** — app keeps running in the background; reopen LivePaper to show Dashboard and turn the icon back on
- **Launch at Login** — start automatically after reboot

### Extra (from LivePaper)
- Local video library
- Download from YouTube (needs `yt-dlp` + `ffmpeg`)
- Optional Mond desktop clock
- Pause or lower quality on battery

---

## Requirements

- macOS **16+** (Tahoe)
- Apple Silicon
- Aerial videos downloaded in **System Settings → Wallpaper**

Optional for YouTube imports:

```bash
brew install yt-dlp ffmpeg
```

---

## Install

```bash
git clone https://github.com/itsdevzam/LivePaper-Follow.git
cd LivePaper-Follow
bash build3.sh
open /Applications/LivePaper.app
```

Or build from this folder with `bash build3.sh` — installs to `/Applications/LivePaper.app`.

---

## Quick start

1. In **System Settings → Wallpaper**, pick a Landscape aerial pack and download Day / Evening / Night / Sunset (as you like).
2. Open **LivePaper** (menu bar icon).
3. Turn on **Follow Apple Aerials**.
4. Choose **Manual** or **Time of day**.
5. Optionally enable **Also set System Wallpaper** so Lock Screen matches.
6. To hide the icon: Dashboard → **Show menu bar icon** off (wallpaper still runs).

---

## Author

**Zain** — [github.com/itsdevzam](https://github.com/itsdevzam)

Project: [github.com/itsdevzam/LivePaper-Follow](https://github.com/itsdevzam/LivePaper-Follow)

---

## License

MIT — see `LICENSE`.  
Based on LivePaper by Raunak Gupta; Follow / time / system-sync / UI changes by itsdevzam.
