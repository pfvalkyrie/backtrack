# Backtrack Notes

## Player gesture follow-up

- Current smoothest build: artwork drag follows the finger horizontally and the release settles into the notes or chapters pane before the real page switches.
- Current gesture experiment removes the built-in pager from underneath the artwork pane and syncs the artwork to the final finger position before completing or canceling the drag.
- Remaining issue: short fast swipes on the artwork are improved, but the pane can still flicker sometimes when canceling back.
- Keep `stable-player-gesture-baseline` as the reliable rollback point if future gesture work gets worse.
