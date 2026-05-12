# Backtrack — Podcast Player

Single-file iPhone Safari web app. Dark theme (black + orange). Hosted on GitHub Pages.

## Purpose

Backtrack is a mobile-first podcast player built around recovery-oriented listening. The sleep timer saves a waypoint when it starts, making it easy to return to the point where listening drifted off. Manual waypoints, persistent positions, queue controls, and quick scrubbing are designed for listeners who often need to retrace and resume.

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
- **Library** — subscribed shows with episode count; filter bar to search within subscriptions; tapping Library tab restores your last open show rather than always returning to the list
- **Episode filter** — search within a show's episode list
- **Pull-to-refresh** — pull down in episode list to re-fetch the feed (works for both subscribed and unsubscribed)
- **Swipe-to-go-back** — left-edge right-swipe on episode view returns to Library or Search depending on where you came from

### Episodes
- **Episode detail sheet** — tapping an episode row slides up a sheet showing full show notes, date, duration, episode number
  - **▶ Play** — adds to queue and starts immediately, opens full player
  - **+ Queue** — shows Play Next / Add to End action sheet; shows "✓ In Queue" and is disabled if already queued
- **+ button on episode row** — add to queue (Play Next / Add to End); turns orange ✓ when in queue; tap ✓ to remove
- **No duplicate queue entries** — Play Next and Add to End both guard against adding the same episode twice
- **Listened indicator** — episodes played past 80% show `✓ listened` in light orange in the meta line; persists across sessions

### Playback
- **Continuous queue** — tap episode in queue to play; drag ⠿ to reorder (ghost + placeholder); × to delete
- **Queue edit mode** — Edit button enters multi-select; tap rows to select; Remove (N) batch-deletes selected; Clear All wipes queue and waypoints; Done exits
- **Waypoints auto-deleted** — removing an episode from the queue (any method) deletes its waypoints
- **Persistent position** — remembers where you left off per episode
- **Playback speed** — 0.75×, 1×, 1.25×, 1.5×, 2×
- **Skip** — ±30s in full player, ±13s in mini player
- **Prev/Next track** buttons in full player

### Full Player
- **Artwork ↔ show notes carousel** — swipe left on artwork to see episode show notes; right to go back
- **Show notes** — parsed from `content:encoded` → `itunes:summary` → `description` (handles AppStories, Relay FM, Megaphone, etc.)
- **Swipe down on artwork to dismiss** — or use the topbar drag handle; player is a fixed non-scrolling layout
- **Progress scrubber** — tap or drag; requires deliberate horizontal intent to avoid conflicts with vertical swipes
- **Waypoints** — tap ⚑ to bookmark a moment; listed oldest→newest; tab auto-scrolls to most recent; jump resolves by episode ID not queue position
- **Sleep timer** — ⏾ cycles 15/30/45/60 min then off; saves a waypoint when started so you can find where you fell asleep

### Mini Player
- Always visible when something is queued; tap body to expand full player
- ±13s skip buttons, play/pause
- Progress bar along the bottom edge

### System
- **Lock screen / Control Center** — artwork, title, skip ±30s, prev/next track; play/pause handled natively by iOS
- **Accessibility** — all media controls have `aria-label`; play/pause label updates dynamically between "Play" and "Pause"
- **Safe area handling** — home indicator and Dynamic Island clearance
- **Tab order** — Library · Queue · Waypoints · Search

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
| Episode IDs | `${podId}_${index}` — position-based, not stable across feed refreshes |
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
- **Lock screen play unreliable** — removed JS play/pause handlers from Media Session; let iOS drive natively
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

---

## Known iOS limitations (not fixable for web apps)

- **Lock screen play button unreliable** — `audio.play()` from JS context is blocked by iOS. Requires `AVAudioSession` (native app only).
- **Background audio** — works while screen is on; may cut on lock depending on iOS version. Add to home screen for best behaviour.

---

## Known bugs / open issues

- **Episode IDs are position-based** — `${podId}_0` always refers to the first item in the feed slice. After a feed refresh, a new episode shifts all IDs, making saved positions and queue entries stale. Fix: use RSS `guid`, then enclosure URL, then title+pubDate hash as fallback.
- **Mini player title shows raw HTML entities** — feeds that wrap titles in CDATA (e.g. `<![CDATA[OpenAI&#8217;s Episode]]>`) pass `&#8217;` as literal text rather than the decoded character. Needs HTML entity decoding after `textContent` extraction.

---

## Adding to iPhone home screen

Safari → Share → "Add to Home Screen" — gives better audio session handling than running in browser tab.
