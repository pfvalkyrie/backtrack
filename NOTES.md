# Backtrack Notes

## Player gesture follow-up

- Current smoothest build: artwork drag follows the finger horizontally and the release settles into the notes or chapters pane before the real page switches.
- Remaining issue: if the finger is released near the middle of the drag, the pane can still snap slightly while completing the transition.
- Keep `stable-player-gesture-baseline` as the reliable rollback point if future gesture work gets worse.
