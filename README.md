# Backtrack — Podcast Player

Single-file iPhone Safari web app. Dark theme (black + orange). Hosted on GitHub Pages.

**Source file:** `index.html` (everything inline — HTML, CSS, JS, no build step)  

---

## Deploy

```bash
```

GitHub Pages takes ~1 minute to go live after each push.

---

## Features

### Browsing & Discovery
- **Podcast search** via iTunes Search API — tapping a card opens episodes immediately, no subscription required
- **Browse without subscribing** — feed is fetched into a temp cache; episodes are fully playable; subscribing persists them to library
- **Podcast info header** — episode view shows artwork, episode count, channel description (from RSS), and a Subscribe/Subscribed toggle
- **Library** — subscribed shows with episode count; filter bar to search within subscriptions
- **Episode filter** — search within a show's episode list
- **Pull-to-refresh** — pull down in episode list to re-fetch the feed (works for both subscribed and unsubscribed)
- **Swipe-to-go-back** — left-edge right-swipe on episode view returns to Library or Search depending on where you came from

### Episodes
- **Episode detail sheet** — tapping an episode row slides up a sheet showing full show notes, date, duration, episode number
  - **▶ Play** — adds to queue and starts immediately, opens full player
  - **+ Queue** — shows Play Next / Add to End action sheet
- **+ button on episode row** — add to queue (Play Next / Add to End); turns orange ✓ when in queue; tap ✓ to remove
- **Queue action sheet** — Play Next (inserts after current) or Add to End

### Playback
- **Continuous queue** — tap episode in queue to play; drag ⠿ to reorder (ghost + placeholder); × to delete
- **Queue edit mode** — Edit button enters multi-select; tap rows to select; Remove (N) batch-deletes selected; Clear All wipes queue; Done exits
- **Persistent position** — remembers where you left off per episode
- **Playback speed** — 0.75×, 1×, 1.25×, 1.5×, 2×
- **Skip** — ±30s in full player, ±13s in mini player
- **Prev/Next track** buttons in full player

### Full Player
- **Artwork ↔ show notes carousel** — swipe left on artwork to see episode show notes; right to go back
- **Show notes** — parsed from `content:encoded` → `itunes:summary` → `description` (handles AppStories, Relay FM, Megaphone, etc.)
- **Swipe down on artwork to dismiss** — or use the topbar drag handle; player is a fixed non-scrolling layout
- **Progress scrubber** — tap or drag; requires deliberate horizontal intent to avoid conflicts with vertical swipes
- **Waypoints** — tap ⚑ to bookmark a moment; listed in Waypoints tab; tap to jump back
- **Sleep timer** — ⏾ cycles 15/30/45/60 min then off; saves a waypoint when started so you can find where you fell asleep

### Mini Player
- Always visible when something is queued; tap body to expand full player
- ±13s skip buttons, play/pause
- Progress bar along the bottom edge

### System
- **Lock screen / Control Center** — artwork, title, skip ±30s, prev/next track; play/pause handled natively by iOS
- **Safe area handling** — home indicator and Dynamic Island clearance
- **Tab order** — Library · Queue · Waypoints · Search

---

## Architecture

| Key | Value |
|-----|-------|
| Storage key | `backtrack_v1` in localStorage |
| State object | `S` — `{ subs, lib, queue, qi, pos, positions, speed, waypoints }` |
| Browse cache | `browseCache` — in-memory only, not persisted; promoted to `S.lib` on subscribe |
| Audio | `<audio id="audio-el">` — HTML5, no Web Audio API |
| Full player | `position:fixed; transform:translateY(100%)` hidden, `.on` shows it; `overflow:hidden` (non-scrolling) |
| CORS proxies | Direct fetch first, then `Promise.any()` racing: allorigins.win/raw, corsproxy.io, codetabs.com, thingproxy.freeboard.io, allorigins.win/get |
| Episode IDs | `${podId}_${index}` — position-based, not stable across feed refreshes |

---

## iOS Safari quirks resolved

- **Script crash:** `fp-topbar` was a class not an id — `getElementById` returned null, crashing before listeners registered.
- **Buttons clipped at bottom:** `overflow:hidden` on fixed player clipped content; fixed with `flex:1 1 0; min-height:0` on `#fp-inner`.
- **Tab bar / home indicator overlap:** `padding-bottom: max(calc(env(safe-area-inset-bottom) + 12px), 34px)`.
- **100vh includes Safari toolbar:** use `height:100dvh` (with `100vh` fallback before it).
- **Scrubber too sensitive:** requires dx > dy × 1.5 and min 6px horizontal before activating.
- **Pinch zoom disabled:** `maximum-scale=1.0, user-scalable=no` in viewport meta.
- **Mini player click not firing:** removed touchstart/touchend handlers that were eating clicks; single `click` listener only.
- **Lock screen play unreliable:** removed JS play/pause handlers from Media Session — let iOS drive natively.
- **Carousel freezes mid-animation:** touching during a CSS transition froze the slider; fixed by snapping to correct position on touchstart.
- **Show notes not appearing for some feeds:** iTunes RSS uses `content:encoded` for full notes; now checked first before `itunes:summary` and `description`.
- **iOS keyboard not appearing on filter inputs:** `type="search"` + dynamically shown views don't trigger keyboard; use `type="text" inputmode="search"`.

---

## Known iOS limitations (not fixable for web apps)

- **Lock screen play button unreliable** — `audio.play()` from JS context is blocked by iOS. Requires `AVAudioSession` (native app only).
- **Background audio** — works while screen is on; may cut on lock depending on iOS version. Add to home screen for best behaviour.

---

## Known bugs / open issues

- **`#fp-inner` is `overflow:hidden`** — controls may be clipped on very small screens (iPhone SE). A layout that shrinks gracefully would fix this.
- **Episode IDs are position-based** — `${podId}_0` always refers to the first item in the feed slice. After a feed refresh, a new episode shifts all IDs; queue entries become stale references.
- **Empty feed URL** — some iTunes search results have no `feedUrl`; episode view shows "Loading…" indefinitely.
- **Unsubscribe doesn't clean up `S.lib` cache** — episodes remain in memory and localStorage after unsubscribing.
- **`.eps-desc` missing word-break** — long URLs in the episode detail sheet can overflow horizontally (same fix needed as was applied to `#fp-notes`).

---

## Adding to iPhone home screen

Safari → Share → "Add to Home Screen" — gives better audio session handling than running in browser tab.
