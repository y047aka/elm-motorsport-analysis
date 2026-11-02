---
name: vrt
description: "Run, judge and land the Playwright visual baselines: which platform a baseline is CI's, why local runs differ by tens of pixels and when that is believed, which shots need a serve, and how a re-baseline is dispatched and approved. Use when a VRT snapshot fails or needs updating, when changing rendering, geometry bytes or anything else that can move pixels, and when `update-snapshots-*` is named."
---

# The VRT

The snapshots in `/app/tests/` are the rendering's fence.
`AGENTS.md`'s Testing section names the suite; this says how a shot is run, judged, and landed.

## Running and judging

The suite runs against the export rather than the server: with nothing listening on 8080 the dev server answers `/api` from `static/`, and those are the same bytes.
It drives the rounds a checkout keeps — `AGENTS.md` names them — and a test reaching for a third needs `nix run .#serve-api` behind it.

Local runs allow a pixel-ratio tolerance for cross-platform diffs — `maxDiffPixelRatio: 0.001`, and `position-tab` alone at 0.0015 — and CI is strict 0. The tolerance is a ratio, so a smaller snapshot gets a smaller budget while the platform gap does not shrink with it.
The tightest shots, measured from one-worker runs as CI has:

| shot | differs | budget |
| --- | --- | --- |
| `position-tab` (the Comparison section alone, 328x162) | 55 | 53 — hence its own 0.0015 |
| `selected-car-with-rivals` (the one shot of a panel whole) | 221 | 246 |
| `lap-180` | 738 | 1,296 |

Eight runs gave the same counts but once, when `lap-180` fell to 102 — a count that moves is worth a second run before it is taken for a rendering that moved.

What no tolerance can absorb is a change smaller than itself: a digit redrawn is tens of pixels.
So a local pass is not a promise, and a local failure on `position-tab` or `selected-car-with-rivals` is worth measuring before it is believed.
CI stays strict for both reasons.

Two ways a round loses its drawing without failing anything are told apart in the suite without a baseline to compare pixels to: `helpers.ts` reads a kept round's summary for the moment to stop at and refuses one naming no `track.circuit`, and `expectSurveyedLap` asserts the tracker drew a polygon where the ring draws a circle.

## Landing a baseline

The baselines are CI's: rendered on Linux, and what a merge is judged against.

`nix run .#update-snapshots-ci` refreshes them: it dispatches the workflow on the checked-out branch, waits for it, pulls the commit it pushes back, and approves the runs GitHub holds because a bot pushed them.
This is the way to land any baseline.

`nix run .#update-snapshots-vrt` writes macOS renderings, which CI rejects: reach for it to see what a change did, never to land a baseline with it.

## Why the two platforms differ

What separates them is the rasteriser — CoreText against FreeType — which no Chromium flag touches.
`tests/screenshot.css` narrows the gap by asking for greyscale antialiasing, and the tolerance absorbs the rest, barely.

The circuits' tracker shots are pixel baselines no more: the bytes they rendered are held by the geometry project's fences, and a circuit is strokes whose pixels only follow those bytes — leaving one baseline-free polygon assertion per circuit as the whole E2E of a drawing.
A survey that moved a circuit's bytes takes a re-baseline with it, and `/skill:add-circuit` says where the move is measured in metres before anyone reads the pixels.
