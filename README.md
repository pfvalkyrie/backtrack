# Backtrack — Podcast Player

Single-file iPhone Safari podcast player. Dark theme, hosted on GitHub Pages.

## Purpose

Backtrack is a mobile-first podcast player built around recovery-oriented listening. The sleep timer saves a waypoint when it starts, so it is easy to return to the point where listening drifted off. Manual waypoints, persistent positions, queue controls, and quick scrubbing make it easy to retrace and resume.

**Source file:** `index.html` (inline HTML, CSS, JS; no build step)

---

## Development workflow

Edit `index.html` directly.

```bash
git status --short
```

## Deploy

```bash
git status --short
git add index.html README.md
git commit -m "update"
git push
```

GitHub Pages usually updates in about a minute.

---

## Features

### Browsing & Discovery
- **Podcast search** via iTunes Search API; tapping a result opens episodes immediately
- **Browse without subscribing**; feeds are cached temporarily and become part of the library on subscribe
- **Podcast info header** shows artwork, episode count, channel description, and Subscribe/Subscribed state
- **Library** keeps subscribed shows with episode counts and restores your last open show
- **Episode filter** searches within a show’s episode list
- **Pull-to-refresh** re-fetches the current feed for subscribed and unsubscribed shows
- **Swipe-to-go-back** returns from the episode view to Library or Search

### Episodes
- **Episode detail sheet** shows notes, date, duration, and episode number
  - **▶ Play** adds to queue, starts playback, and opens the full player
  - **+ Queue** opens a Play Next / Add to End sheet and disables itself when already queued
- **+ button on episode row** adds to queue and turns into an orange ✓ when queued
- **No duplicate queue entries** are allowed
- **Listened indicator** marks episodes played past 80% and persists across sessions

### Playback
- **Continuous queue** supports tap-to-play, drag reordering, and delete
- **Queue edit mode** supports multi-select, batch remove, and Clear All
- **Waypoints** are removed when an episode leaves the queue
- **Persistent position** remembers where you left off per episode
- **Playback speed**: 0.75×, 1×, 1.25×, 1.5×, 2×
- **Skip**: ±30s in full player, ±13s in mini player
- **Prev/Next track** buttons live in the full player

### Full Player
- **Artwork ↔ show notes carousel** swaps between artwork and episode notes
- **Show notes** are parsed from `content:encoded`, then `itunes:summary`, then `description`
- **Swipe down on artwork** dismisses the player; the topbar drag handle does the same
- **Progress scrubber** responds to deliberate horizontal drags and taps
- **Waypoints** are listed oldest to newest and resolve by episode ID
- **Sleep timer** cycles 15/30/45/60 minutes, then off, and saves a waypoint when started

### Mini Player
- Stays visible whenever something is queued and expands on tap
- Includes ±13s skip buttons and play/pause
- Shows a progress bar along the bottom edge

### System
- **Lock screen / Control Center** exposes artwork, title, skip, and track controls
- **Accessibility** adds `aria-label` text and updates the play/pause label dynamically
- **Safe area handling** clears the home indicator and Dynamic Island
- **Tab order** is Library · Queue · Waypoints · Search

---

## Architecture

| Key | Value |
|-----|-------|
| Storage key | `backtrack_v1` in localStorage |
| State object | `S` — `{ subs, lib, queue, qi, pos, positions, speed, waypoints, listened }` |
| Browse cache | `browseCache` — in-memory only, not persisted; promoted to `S.lib` on subscribe |
| Audio | `<audio id="audio-el">` — HTML5, no Web Audio API |
| Full player | `position:fixed; transform:translateY(100%)` hidden, `.on` shows it; non-scrolling layout |
| CORS proxies | Direct fetch first, then `Promise.any()` racing: allorigins.win/raw, corsproxy.io, codetabs.com, thingproxy.freeboard.io, allorigins.win/get |
| Episode IDs | Stable hash from RSS `guid` → enclosure URL → title+pubDate fallback |
| Waypoints | Stored with `epId` (not queue index); jump resolves by finding episode in queue by ID |
| Listened | `S.listened[epId] = true` when playback passes 80% of duration |
| Position save | Throttled by 5-second bucket (`lastSavedBucket`) — saves once per interval, not multiple times |

---

## Bugs fixed

- **Script crash on load** — `fp-topbar` was a class not an id; `getElementById` returned null, crashing before listeners registered
- **Buttons clipped at bottom** — `overflow:hidden` on fixed player clipped content; fixed with `flex:1 1 0; min-height:0` on `#fp-inner`
- **Full player controls clipped on small screens** — `#fp-inner` changed from `overflow:hidden` to `overflow-y:auto` so controls scroll into view
- **Tab bar / home indicator overlap** — `padding-bottom: max(calc(env(safe-area-inset-bottom) + 12px), 34px)`
- **100vh includes Safari toolbar** — use `height:100dvh` (with `100vh` fallback)
- **Scrubber too sensitive** — requires dx > dy × 1.5 and min 6px horizontal before activating
- **Pinch zoom** — disabled via `maximum-scale=1.0, user-scalable=no` in viewport meta
- **Mini player click not firing** — removed touchstart/touchend handlers that were eating clicks; single `click` listener only
- **Lock screen playback boundary clarified** — episode auto-advance works while locked; play/resume after pausing from the lock screen remains an iOS web limitation
- **Carousel freezes mid-animation** — touching during a CSS transition froze the slider; fixed by snapping to correct position on touchstart
- **Show notes not appearing for some feeds** — iTunes RSS uses `content:encoded` for full notes; now checked first before `itunes:summary` and `description`
- **iOS keyboard not appearing on filter inputs** — `type="search"` + dynamically shown views don't trigger keyboard; use `type="text" inputmode="search"`
- **Mini player progress bar not visible** — `overflow:hidden` + `border-radius` doesn't clip correctly on iOS Safari without `-webkit-transform:translateZ(0)`
- **Long URLs overflowing episode detail sheet** — `.eps-desc` now has `word-break:break-word; overflow-wrap:break-word`
- **Show notes scroll conflicting with swipe-to-dismiss** — `touch-action:pan-y` on notes panel restores native scroll; `onNotes` flag routes gesture correctly
- **Waypoint jump going to wrong episode** — was using queue index (which drifts); now stores and resolves by episode ID
- **Duplicate episodes in queue** — detail sheet and queue action sheet both guard against adding the same episode twice
- **Unsubscribe leaving stale data** — `delete S.lib[id]` on unsubscribe; episode data no longer lingers in localStorage
- **Back button from library episode view broken** — `nav()` early-return blocked explicit back navigation; fixed by checking `libSubView` before returning
- **Position saving too frequently** — `timeupdate` fired multiple saves per 5-second mark; now uses bucket comparison to save exactly once per interval
- **Episode IDs shifting after feed refresh** — IDs now use RSS `guid`, then enclosure URL, then title+pubDate hash as fallback
- **Queue removal paths drifting apart** — row delete, add-button removal, and edit-mode batch removal now share one removal path
- **Raw HTML entities in feed text** — feed titles and descriptions are decoded after XML extraction

---

## Known iOS limitations (not fixable for web apps)

- **Lock screen play/resume after pausing is unreliable** — `audio.play()` from a background JS context may be blocked by iOS. Episode auto-advance while locked works; full play/resume control requires `AVAudioSession` (native app only).
- **Background audio** — works while screen is on; may cut on lock depending on iOS version. Add to home screen for best behaviour.

---

## Adding to iPhone home screen

Safari → Share → "Add to Home Screen" — gives better audio session handling than running in browser tab.

---

## License

© 2026 Apollo13th. All rights reserved.
