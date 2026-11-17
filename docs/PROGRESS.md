# The People: build progress

Tracks the orchestrated build of three roadmap branches: `foundations`, `about-pane` and
`thumbnails`. Written only by the orchestrator, in the main checkout, and left uncommitted.
The plan is `docs/ROADMAP.md`; the instructions are `docs/ORCHESTRATOR_PROMPT.md`.

Where things are:

| Branch | Worktree |
|---|---|
| `foundations` | `/home/jimbo/the-people-worktrees/foundations` |
| `about-pane` | `/home/jimbo/the-people-worktrees/about-pane` |
| `thumbnails` | `/home/jimbo/the-people-worktrees/thumbnails` |

All three branches are complete, verified and local, with nothing pushed or merged into
`main`. A trial merge of all three combined cleanly (see the log, 23:58).

Baselines from `main` at `e95220c` are in
`/home/jimbo/.config/Claude/side-session-notes/local_14332ac8-8549-489a-ba07-1757f71cdb63/baselines/`:
`gate-main.txt` (regression gate), `selftest-main.txt` (click test as given, random seed)
and `selftest-main-seed100-1.txt` (click test with `TP_SEED=100`, repeatable).

## 1. Status

Status is one of: to do, in progress, reported (the worker says it is finished),
verified (the orchestrator checked it), blocked.

| Branch | Chunk | Status | Commit | How it was verified |
|---|---|---|---|---|
| foundations | F1 Screen switch | verified | `346b408` | Commit touches only `main.gd`. Gate byte-identical to baseline. My own screenshots: default start shows the lot and HUD as before; `TP_SCREEN=town` shows a bare placeholder with a small "Town" tag and no lot HUD. |
| foundations | F2 Household spec | verified | `144d68e` | Commit is `main.gd` + `person.gd` only. Gate byte-identical for seeds 100 to 103 (3 days, no ageing) and for seed 100 with ageing on (4 days), all against `main` baselines. Read the diff: draw order unchanged. |
| foundations | F3 Town record | verified | `35c5e73` | Adds `town.gd` + `.uid`; `main.gd` +18/-2. Gate for seeds 100-103 and ageing: only added lines, all `lot` lines; with them stripped, byte-identical to `main`. Loaded the pre-town save from `main`: town built around its households, saved, reloaded, lot list unchanged. |
| foundations | F4 Home value | verified | `2d6fc72` | `world.gd` +23, `main.gd` +2. Gate for seeds 100-103 and ageing: only added `home value` lines against the F3 baselines; stripped, byte-identical. Seeds 104-105 clean. My own Python recount of a seed-100 save matched all four printed values exactly. |
| about-pane | A1 Tabs | verified | `61e9bb8` | Commit is `ui.gd` only, inside the agreed zone. Gate byte-identical. My own screenshots (`tab:needs`, `tab:people`, none) side by side with the old card: Needs grid unchanged, strip fits the 300 px card, closed card stays quiet. |
| about-pane | A2 Header | verified | `ee18713` | `ui.gd` only, in zone. Gate byte-identical. My own screenshots from an edited save (adult, child, elder, a long name, Work tab): chip words right, long name wraps the chip to a second line, stage line gone from the old text. |
| about-pane | A3 Work tab | verified | `ec63378` | `ui.gd` only, in zone. Gate byte-identical. My own screenshots from edited saves: job (Dishwasher, perf bar, "Next: Line Cook / Needs Cooking 2 and full performance"), school, retired, no job. Promotion text checked against the rule in `person.gd`. |
| about-pane | A4 Skills tab | verified | `4a91e6c` | `ui.gd` only, in zone. Gate byte-identical. My own adult and child screenshots from an edited save: levels, progress bars, gold career/school dot, untouched skills greyed. The worker's study run printed Logic 1.24 -> 1.40 and its two screenshots show the bar move from about 24% to 40%. |
| about-pane | A5 Traits tab | verified | `5adbd1e` | `ui.gd` only, in zone. Gate byte-identical. My own screenshots of an adult and an elder from an edited save with values 1, 3, 5, 7, 9: every marker at the right place. The worker's script measured all 15 marker centres against `(v-1)/8` of the track: exact. |
| about-pane | A6 People tab | verified | `4e1b485` | `ui.gd` only, in zone. Gate byte-identical. My own screenshot from an edited save (7 known people, one at -35): household first, then a Neighbours divider, list cut at six rows with a scroll bar. Worker's scrolled-to-end shot shows the red "on bad terms" bar. The scroll bar's default grey look is restyled in A7. |
| about-pane | A7 Clean-up | verified | `7e24890` | `grep info_l scripts/` finds nothing; `TP_UI=info` path gone. Gate byte-identical. Looked at all three retaken `docs/screenshot-*.png` (1261x1030): same setups as before with the new card. People scroll bar now a slim 4 px grabber; card stays 300 px. Worker's selftest matched `main`. |
| thumbnails | H1 Renderer | verified | `abbef7b` | Adds `thumbs.gd` + `.uid`, 3 lines in `ui.gd` in zone. Gate byte-identical. My own `TP_THUMBS` run wrote 28 PNGs for 28 `Defs.OBJECTS`; on a contact sheet every one is framed, lit and recognisable. |
| thumbnails | H2 Buy rows | verified | `31e2257` | `ui.gd` + `thumbs.gd`, in zone. Gate byte-identical. My own Buy screenshots: Skills (all affordable) and Bathroom with money at $500 (Shower and Bathtub greyed, picture and name). Build tabs checked by the worker against the pre-H2 build. |
| thumbnails | H3 Buy grid | verified | `ae0a6d3` (+ `9532998` rename) | `ui.gd` only, in zone. Gate byte-identical. `TP_SELFTEST` (seed 100) run twice: all 10 `selftest` lines identical to `main`. My own screenshots: Bedroom at $500 (Double bed greyed), Skills with Standing mirror selected. Worker's real-click script showed a tile click selects, R rotates. |
| thumbnails | H4 Item details | verified | `520562e` | `ui.gd` only, in zone. Gate byte-identical; selftest identical. Tooltip text for both beds, fridge, bookshelf and plant checked line by line against `Defs.OBJECTS`. The worker's hover screenshot shows the Bookshelf tooltip in the ink style. |
| thumbnails | H5 Floor swatches | verified | `03b7eb1` | `thumbs.gd` + `ui.gd`, in zone. Gate byte-identical; selftest identical. My own `TP_MODE=build TP_UI=floors` screenshot: seven 40 px textured swatches; side by side with in-game patches, pattern and hue match (swatches slightly darker, unlit). |
| thumbnails | H6 Wall tools | verified | `a760b08` | `thumbs.gd` + `ui.gd`, in zone. Gate byte-identical; selftest identical. My own Walls screenshot with seed 102 (blue walls) and the four full-size pictures: plain wall, door, window, ghosted wall with a red cross, all readable at 40 px. |
| thumbnails | H7 Regression | verified | none needed (branch ends at `a760b08`) | No bug found, so no commit. My own selftest run on `a760b08` identical to `main`. Worker's real-input script ran 15 checks (sell mode, ghost colour/rotate/cancel, disabled tile click, re-enable and re-grey, build tools, floor laying, mode switching) on the branch and on a `main` copy: all PASS, same results apart from the expected grid/material differences. Branch diff touches only `thumbs.gd` and `ui.gd`, all hunks in zone. |

## 2. Needs me

- **Retake `docs/screenshot-furnish.png` after `about-pane` and `thumbnails` are both
  merged.** A7 retook it on `about-pane`, which has the old text-row Buy list. In the
  merged checkout, run:
  `TP_SEED=102 TP_FRESH=1 TP_SAVE=user://furnish-shot.json TP_MODE=buy TP_UI=tab:skills TP_SHOT=$PWD/docs/screenshot-furnish.png godot --path $PWD`
  The window must come out 1261x1030 (the desktop's default tile); check with
  `magick identify`. The day and night shots don't show the Buy panel; the night shot's
  Build Floors list will also look older than `thumbnails`' textured swatches, so retake it
  too: `TP_SEED=102 TP_FRESH=1 TP_SAVE=user://night-shot.json TP_MODE=build TP_HOUR=21 TP_UI="help floors" TP_SHOT=$PWD/docs/screenshot-night.png godot --path $PWD`.

## 3. Deviations

- **Click-test comparisons use `TP_SEED=100`.** The click test as written in the
  orchestrator prompt has no seed, so each run rolls a different household and the
  `selftest` lines differ between runs (money 2100 in one run, 2088 in another; a
  different queue). With `TP_SEED=100` two runs on `main` gave identical output, so H3,
  H7 and the trial merge compare against `selftest-main-seed100-1.txt`. The unseeded
  baseline was captured too, as asked.
- **Root screenshots were not ignored by git.** The prompt says `screenshot-<chunk>.png`
  in a worktree root is already ignored; `.gitignore` only lists `.godot/` and
  `/android/`. I added `/screenshot-*.png` to `.git/info/exclude`, which is local to this
  clone, shared by all worktrees and not committed. Remove that line to undo it.
  `docs/screenshot-*.png` are not affected.
- **`thumbnails` keeps out of `main.gd`.** `TP_THUMBS` and any screenshot switches it
  needs are read inside `thumbs.gd` / `ui.gd`, because `foundations` rewrites start-up in
  `main.gd` and the roadmap's branch table gives `thumbnails` only `thumbs.gd` and `ui.gd`.
  The same applies to `about-pane`: its screenshot switches go in `UI.debug_open`.
- **Edit zones inside `ui.gd`**, agreed with both UI workers so the branches merge:
  `about-pane` owns the card block of `_ready()` ("Household and the selected person"),
  the `needs`/`info` lines at the top of `debug_open`, `_refresh_card`, and adds new
  functions at the end of the file. `thumbnails` owns the side-panel block of `_ready()`
  ("Catalogue and build tools"), `build_side`, `_row`, the `side.visible` block of
  `refresh()`, adds `debug_open` lines only directly after the `floors` block, and adds
  new functions directly after `_row`.

- **F1 moved the drawn lot under one `lot` node.** People are children of `main` and set
  their own `visible`, so hiding the world alone would not hide them. The player's world,
  all people, the camera rig, the marker and the placement ghost are now children of
  `main.lot`. That changed one `add_child` line each in `_make_person` and `set_buy`,
  just outside the `_ready` area the roadmap names. Neighbour worlds are untouched.
- **F1: the town placeholder has its own camera and a small "Town" tag**, a little more
  than "empty", so a screenshot can tell a hidden lot from an undrawn one. About 15 lines
  in `_build_screens()` for `town-view` to replace.
- **F1: all of `main.gd`'s keys are ignored off the lot**, including F5 save, F9 load and
  M mute, not only the lot ones. **Time keeps running on the town screen** at the speed
  already set; the roadmap gives pausing to `town-view` (choice 2), so F1 left the clock
  alone. `town-view` needs to add the pause.

- **A1: the tab strip sits on its own row** below the mood bar, because five tabs do not
  fit beside the name in 300 px. The closed card is one short row taller than before.
  `TP_UI=info` opens the Work tab (which shows the old text) until A7 removes it.
- **The `about-pane` worker resized its own test window.** On this tiling desktop the
  game window opens 626 px wide, so it floated and resized only its own window to
  1440x900 with `hyprctl dispatch` to make screenshots comparable. No settings changed.
  My own checks use the window as the desktop gives it.

- **F2: `Person.setup` still rolls look and traits, then replaces them from the spec.**
  The roadmap says setup takes them from the spec "instead of rolling them inline". Each
  person's rng keeps running for the rest of the game, so skipping its draws would change
  every same-seed run. The draws moved unchanged into `static func Person.roll()`, which
  `random_spec()` also uses on a separate rng with the same seed, so the game rng is not
  touched. A spec may give only some look keys or traits; the rest stay as rolled (not
  asked for by the roadmap, added for the creator).
- **F2: the spec's `money` comes from `Household.money`'s default ($2,500)**, so there is
  still one place that sets the figure.
- **H1: `TP_THUMBS` runs with or without `TP_SHOT`**; on its own it quits when the last
  picture is written. It writes all 28 entries, including the unsold memorial and puddle.
  Under `--headless` it prints one line and writes nothing.

- **A2 wording:** "Adult, day 17", "Child, grows up in 3 days" (and "1 day"), and
  "Elder, day 33" for elders, which the roadmap left open. The chip is `MUTED` for every
  stage. The name row now wraps, so a long name keeps its line and the chip drops under it.
  `TP_UI=pick:<n>` selects the n-th household member for screenshots. Child and elder
  screenshots load a save edited by hand, not a code switch that changes ages.
- **A3 promotion wording follows the code, not the roadmap's example.** The roadmap's
  example is "Next: Line Cook, needs Cooking 4", but `Person` promotes at skill
  `(level + 1) * 2`, so going from Dishwasher to Line Cook needs Cooking 2.

- **H2: only the picture fades on an unaffordable row**; the name keeps the existing
  disabled grey (fading the whole row made names unreadable). `TP_UI` gains `cat:<Category>`
  to open a Buy category for screenshots.
- **`TP_UI=pick:` clash between the two UI branches, fixed in `thumbnails`.** `about-pane`
  (A2) uses `pick:<n>` to select a household member, and `thumbnails` (H2) used
  `pick:<kind>` to select a Buy item. They would not conflict as text, but after a merge
  each would misread the other's value. `thumbnails` renames its word to `buy:<kind>`
  in H3.

- **A3: the promotion step takes two lines**, "Next: <title>" and a muted line saying
  what is missing (skill, full performance, both, or "Due after the next workday"), because
  one sentence did not fit 300 px. The performance bar is plain `GOOD` green, not the needs
  colours, since a new hire starts at 0. The job, school, retired and no-job lines left the
  old About text, which the Skills, Traits and People tabs still show until their chunks.

- **A4: "untouched" means a skill at exactly 0.0**; a skill at 0.4 shows level 0 with a
  partly filled bar and is not greyed. A child's Logic gets the career dot, with the
  tooltip "Practised at school". At level 10 the bar is drawn full.

- **F3 decisions:** a new town has 3 vacant homes and 3 empty lots. All lots, the
  player's included, are shuffled into slots by the town's own rng (seeded from the game
  seed and saved), so the player's slot varies by seed. A household that dies out leaves
  its lot vacant with its seed; a family that moves in during play gets a new home lot at
  the end of the street (the street grows), because making it take a vacant lot would
  change which world it gets. That choice belongs to `lots-and-homes`.
- **F3: neighbour lots from an old save have seed -1 (unknown).** `World` does not keep its
  seed and old saves do not store it, so those houses exist only as saved world data.
  `town-view` must draw a home lot with seed -1 from that household's `World`. If such a
  household dies out, its vacant lot gets a fresh seed and so a different house.
- **The `foundations` gate baseline is now F3's output** (`gate-foundations-F3*.txt` in
  the baselines folder), as the orchestrator prompt says.
- **Local ignore rule widened** to `/screenshot-*.import` and `/screenshot-*/` in
  `.git/info/exclude`, because Godot's import writes `.import` files beside root
  screenshots and the thumbnail worker writes a folder of PNGs.
- **H3: the side panel is 32 px wider in both Buy and Build** (236 to 268 px), so its left
  edge does not jump between modes. Tiles are 64 px pictures, two columns.
- **H3 look note:** on the selected (ink) tile, the `MUTED` price is low-contrast. The old
  rows had the same; left as is.

- **A5 end words:** Messy–Neat, Shy–Outgoing, Laid-back–Active, Serious–Playful,
  Grumpy–Nice ("Laid-back" rather than "Lazy", to keep it kind). They are one const,
  `TRAIT_ENDS`, at the end of `ui.gd`, ready to move to `Defs` when `create-household`
  builds its trait sliders (C9, C10).

- **F4: a door or window counts its wall as well** ($15 + $40 for a door), because the
  build tools only put a door into an existing wall and charge for both. The value
  includes the garden objects (trees, bushes, flower beds outside the house) and every
  floor tile, including the path. Scenery (lawn, hedges, road) is not counted. The
  three-day bills still use object prices only, as before; basing them on `value()` would
  raise their value-based part by 22 to 32%.
- **F4 numbers for L4 and L7.** Freshly generated homes for seeds 100 to 105 (42 houses,
  including vacant ones): min $10,446, median $11,531, max $13,171. The players' starting
  homes: $11,312 to $12,631. Day-3 gate values equal the day-0 values; nothing is built in
  three days.
- **H4 tooltips:** the first line lists what the click menu offers (act labels, with
  "with a stove" for acts that need one); the stove, whose only act is hidden, reads
  "Needed to cook a meal at the refrigerator". Comfort and room effect are in words, using
  thresholds the worker chose (comfort 45+/25+/>0; room 5+/2+/>0/<0). Garden items say
  "(indoors only)" because outdoors has a fixed room score. The table reads "Decoration",
  which is true to the code (nothing uses it but its room score) but may surprise a
  player. The selected tile's price is now light on ink.

- **A6:** known people are found by the old rule (all household members, plus anyone at
  `|r| >= 5`), household first then neighbours, warmest first in each group. The list
  shows six rows and scrolls. With the scroll bar showing, the card grows from 300 to
  312 px. The scroll bar's default heavy grey look is restyled in A7.
- **The docs Furnish screenshot will be stale after merging.** A7 retakes
  `docs/screenshot-*.png` on `about-pane`, so the Furnish shot shows the old text-row Buy
  list, not `thumbnails`' tile grid. Retake it after both branches are merged (listed
  under Needs me).

- **H5: the catalogue list is 352 px tall instead of 300**, in every mode, so the eight
  floor rows with 40 px swatches fit without scrolling. Buy and Walls get a little more
  empty space below. A one-line revert if scrolling floors is preferred. Swatches are
  made with `Meshes.make_tex` at a fixed seed, cached per floor, and work headless.

- **A7:** `TP_UI=info` now opens nothing; `needs`, `tab:<name>` and `pick:<n>` remain.
  The docs shots use seed 102 (a larger household than 100). The night shot no longer
  has the "M Sound on or off" row in Controls, because sound is switched off in the
  current code. The day shot, like the old one, comes from a `TP_SELFTEST` run.

- **H6: wall pictures use the household's own wall colour**, so they match the walls on
  screen, and the colour is part of the cache key. The section is built from copies of the
  few mesh calls in `World.rebuild_walls()`; `world.gd` is untouched (it belongs to
  `lots-and-homes`). "Remove floor" stays a plain text row; the roadmap names only wall,
  door, window and remove (wall).

- **H7 made no commit:** every check passed, so there was nothing to fix. The worker's
  real-input check moved the desktop's mouse cursor briefly with `Input.warp_mouse`,
  because the placement ghost reads the real cursor position.

## 4. Log

- 2026-11-17 15:58. Read the roadmap. `main` is clean at `e95220c` and contains
  `docs/ROADMAP.md`. No earlier `docs/PROGRESS.md`, so this is a fresh start.
- 2026-11-17 15:58. Captured the gate baseline twice from `main`: 100 lines, byte-identical,
  no `SCRIPT ERROR`, `STUCK` or `LOST`.
- 2026-11-17 15:58. Captured the click-test baseline. Unseeded runs differ from each other;
  seeded runs (`TP_SEED=100`) are identical. Decision logged under Deviations.
- 2026-11-17 15:59. Created branches and worktrees for `foundations`, `about-pane` and
  `thumbnails` from `e95220c`, ran the Godot import in each, and confirmed each one's gate
  output is byte-identical to the baseline.
- 2026-11-17 16:01. Handed F1, A1 and H1 to one worker each.
- 2026-11-17 16:07. F1 reported by the worker (`346b408`).
- 2026-11-17 16:08. F1 verified: commit is `main.gd` only (+66 / -7); gate byte-identical;
  my own lot and town screenshots are right. The worker also ran a synthetic-input check
  (same keys and clicks change nothing on town, and do change the lot); I did not repeat
  that one. Handed F2 to the worker.
- 2026-11-17 ~16:15. All three workers stopped on the account's usage limit (HTTP 429)
  mid-chunk: F2 had made no edits; A1 had uncommitted changes to `ui.gd`; H1 had an
  uncommitted `thumbs.gd`, its `.uid`, a three-line `ui.gd` change and a folder of PNGs.
- 2026-11-17 23:18. Limit reset. The session now runs on Claude Opus 5.5 (switched by the
  user), so commits from here on carry an Opus 5.5 co-author trailer; `346b408` (F1)
  carries the Fable 5.2 one. Resumed all three workers from their saved state.
- 2026-11-17 about 23:20. A1 reported (`61e9bb8`) and verified: `ui.gd` only, inside the zone;
  gate byte-identical; my own screenshots look right. Handed A2 to the worker.
- 2026-11-17 about 23:23. H1 reported (`abbef7b`) and verified: gate byte-identical; my own
  `TP_THUMBS` run gave 28 of 28 PNGs, all recognisable on a contact sheet. Handed H2.
- 2026-11-17 about 23:23. F2 reported (`144d68e`) and verified: five gate runs (seeds 100 to
  103, and ageing on) byte-identical to `main`. The worker also checked a hand-made spec
  and loading the pre-town save from `main`. Handed F3.
- 2026-11-17 about 23:25. A2 reported (`ee18713`) and verified: gate byte-identical; my own
  four screenshots from the worker's edited saves look right. Handed A3.
- 2026-11-17 about 23:28. H2 reported (`31e2257`) and verified: gate byte-identical; my own Buy
  panel screenshots are right. Spotted the `pick:` clash with `about-pane`; decided to
  rename in `thumbnails` (logged under Deviations). Handed H3.
- 2026-11-17 about 23:29. A3 reported (`ec63378`) and verified: gate byte-identical; my own
  four screenshots (job, school, retired, no job) are right. Handed A4.
- 2026-11-17 about 23:33. A4 reported (`4a91e6c`) and verified: gate byte-identical; my own
  screenshots right; the study-session bar movement confirmed from the worker's two
  screenshots and printed values (not rerun by me). Handed A5.
- 2026-11-17 about 23:35. F3 reported (`35c5e73`) and verified: five gates differ only by
  added `lot` lines; old save loads and keeps its town through a save and reload. F3's
  output saved as the new `foundations` baseline. Handed F4.
- 2026-11-17 about 23:35. H3 reported (`ae0a6d3`, plus `9532998` renaming `pick:` to `buy:`)
  and verified: gate identical; selftest identical twice; my own screenshots right.
  Handed H4.
- 2026-11-17 about 23:35. Handed F4 and H4.
- 2026-11-17 about 23:36. A5 reported (`5adbd1e`) and verified: gate identical; my own adult and
  elder screenshots put every marker where the saved values say. Handed A6.
- 2026-11-17 about 23:40. F4 reported (`2d6fc72`) and verified; `foundations` is complete
  (F1-F4). F4's seed-100 output saved as `gate-foundations-F4.txt`.
- 2026-11-17 about 23:40. A6 reported (`4e1b485`) and verified: gate identical; my own
  screenshot right. Handed A7, with a restyle of the scroll bar folded in.
- 2026-11-17 about 23:41. H4 reported (`520562e`) and verified: gate and selftest identical;
  tooltips checked against data. Handed H5.
- 2026-11-17 about 23:43. H5 reported (`03b7eb1`) and verified: gate and selftest identical;
  my own Floors screenshot right. Handed H6.
- 2026-11-17 about 23:45. A7 reported (`7e24890`) and verified; `about-pane` is complete
  (A1-A7). Added the retake commands for the docs screenshots to Needs me.
- 2026-11-17 23:45. Dry-run merge with `git merge-tree` (no branch, worktree or
  ref changed): `foundations` + `about-pane` + `thumbnails` (at H6, `a760b08`) merge
  with no conflicts. The full trial merge, with import, gate and click test, follows H7.
- 2026-11-17 about 23:46. H6 reported (`a760b08`) and verified: gate and selftest identical;
  my own screenshot and the full-size pictures look right. Handed H7.
- 2026-11-17 23:57. H7 reported (no commit) and verified: selftest identical; the
  worker's 15 real-input checks pass on the branch and on `main`. `thumbnails` complete
  (H1-H7). All 18 chunks verified. Starting the trial merge.
- 2026-11-17 23:57. Correction: the log entries from A1's verification up to H7 had
  times I estimated instead of taking from `date`, and they ran up to "00:46 on the 18th"
  when the real time was 23:57. I replaced them with times derived from real timestamps
  (each chunk's git commit time and the file times of my verification screenshots),
  marked "about", and put the entries back in time order. The "~16:15" time of the
  usage-limit stop is also an estimate.
- 2026-11-17 23:58. Trial merge on a throwaway branch `trial-merge` in a throwaway
  worktree cut from `main`: merged `foundations`, then `about-pane`, then `thumbnails`,
  each with `--no-ff`. **No conflicts.** Godot import: exit 0, no errors. Gate: exit 0,
  no `SCRIPT ERROR`/`STUCK`/`LOST`, byte-identical to `foundations`' F4 output, and with
  the `lot` and `home value` lines removed byte-identical to `main`. Scripted click test
  (`TP_SEED=100`) run twice: all 10 `selftest` lines identical to `main` both times.
  Screenshots of the merged game: Buy with the Skills tab open and the Bathroom tiles
  (Sink selected via `buy:`); Build/Floors at 21:00 with the People tab; `TP_SCREEN=town`.
  All right, and the `TP_UI` words from both branches applied together. Then removed the
  worktree, deleted `trial-merge`, and deleted its `user://trial-merge-test.json`.
- 2026-11-17 23:58. Checked `user://the_people_save_v2.json`: last modified 11:09, before
  this run started, so it was never touched.
