# Progress: town-view, lots-and-homes, create-household

Second batch from `docs/ROADMAP.md`, started 2026-11-18 from `main` at `37f576e`. The
first batch's log is `docs/PROGRESS.md`.

- Worktrees: `/home/jimbo/the-people-worktrees/<branch>`, each cut from `main` at `37f576e`
  and imported.
- Workers: Sonnet 5.5 for `town-view` and `create-household`, Opus 5.5 for
  `lots-and-homes`, as you chose.
- Baselines (outside the repo):
  `/home/jimbo/.config/Claude/side-session-notes/local_14332ac8-8549-489a-ba07-1757f71cdb63/baselines2/`
  - `gate-main-s100.txt`, `-s101`, `-s102`: `TP_TEST=3 TP_AGE=0` at each seed. Seed 100
    ran twice, byte-identical, and equals the first batch's `gate-foundations-F4.txt`.
  - `selftest-main.txt` / `.png`: `TP_SELFTEST=1 TP_SEED=100 TP_FRESH=1`; its 10
    `selftest` lines equal the first batch's.
- Shared worker brief: `brief-batch2.md` in the same notes folder.

## Status

| Branch | Chunk | Status | Commit | Verified by |
|---|---|---|---|---|
| town-view | T1 Ground | verified | `3bc8310` | Gate byte-identical. My own `TP_SCREEN=town` shot: street and 10 plates for 10 lots (7 lawn, 3 bare). Clock pause on town read in code, not yet run (T6 tests the round trip). |
| town-view | T2 Houses | verified | `5e798e5`, `870bb7a`, `fd03ec6` | Gate byte-identical. My own seed-102 shot: 7 houses for 7 home and vacant lots, empty lots bare; south houses mirrored about the plate centre (checked in code after I misread the shot). Follow-up from the trial merge: a home lot with no house draws no house (checked in the merged game on an empty lot). |
| town-view | T3 Labels | verified | `0bf46eb` | Gate byte-identical. My own seed-101 run: the 10 label lines match the lot report's kinds and families (the report's lot 10 is a household that moved in later). Label contrast to be tuned in T4. |
| town-view | T4 Lot card | verified | `41b1d09` | Gate byte-identical. My own scripted clicks, seed 100: lot 2 "Holson", lot 6 "To let", lot 9 "For sale". Holson card screenshot (members with stage chips) looked at. |
| town-view | T5 Boot into town | verified | `13d03a5` | Gate byte-identical; click-test lines unchanged. My own seed-101 `TP_BOOT` run: town with the player's lot framed in gold, card with Play; `TP_TOWN_PLAY` printed `screen lot, speed 3` and showed the lot. A real normal launch was not run (it would load the real save). |
| town-view | T6 Back to town | verified | `221c5d2` | Gate byte-identical; click-test lines unchanged. My own seed-102 `TP_TOWN_TRIP` run: clock, money and three people's tiles identical before and after; speed 0 in town; save file written. |
| town-view | T7 No household yet | verified | `8448837`, `d419983` | Gate byte-identical. My own seed-101 and 102 runs on a missing save: prompt shown; Create enters the lot; no save file created. After the fix: no hover tint under the prompt, player label in INK. Existing-save boot unchanged (worker). |
| town-view | T8 Time of day | verified | `8caa861` | Gate byte-identical; click-test lines unchanged. My own seed-101 town at 23:00: dark sky (shared sun), 4 of 4 homes lit with warm windows, vacant and bare lots dark, labels switched to light colours. |
| lots-and-homes | L1 Empty lot | verified | `e86f84e` | Gate byte-identical at seeds 100 to 102. My own `TP_LOT=empty TP_TEST=2`: no `SCRIPT ERROR` or `STUCK`; three LOST lines, all starvation deaths (see Deviations). My screenshot: bare lot, stone entry, household at the kerb. |
| lots-and-homes | L2 Front door follows building | verified | `e15b9bf`, `1abd362` | Gates s100, s102 byte-identical. My own `TP_LOT=empty TP_ROOM=1 TP_TEST=2` at seed 101: visitor arrived at the built door; second door, window and erase fell back correctly to the west door, then the kerb. Worker checked 1000 generated houses: recomputed door equals the generator's. |
| lots-and-homes | L3 Starting funds | verified | `4512a0c` | Gates byte-identical at seeds 100 to 102. My own `TP_LOT=empty TP_TEST=1` at seed 103 printed `START money $15000` (provisional `START_FUNDS`; L4 sets it). |
| lots-and-homes | L4 Lot price | verified | `e5d2e9f` | Gates s100, s101 byte-identical. My own runs: seed-104 PRICES line (cheapest $10,446, dearest $13,171); empty lot at seed 105 starts with $11,750 = $13,750 − $2,000. |
| lots-and-homes | L5 Build session | verified | `a411291` | Gate s102 byte-identical. My own seed-103 runs: clock and needs identical at frames 2, 100, 190 while paused; Space (`TP_UNPAUSE=60`) resumed at speed 1 and needs moved; screenshot shows the Build panel with the hint. |
| lots-and-homes | L6 Vacant home | verified | `52f248a` | Plain gate byte-identical. My own seed-102 `TP_LOT=vacant:1436970540` gate: household took vacant lot 4, lot 0 became vacant (seed 102); player's house and a fresh `World.setup(seed)` printed identical (`HOME identical: true`); no `SCRIPT ERROR`, `STUCK` or `LOST`. |
| lots-and-homes | L7 Tenure and rent | verified | `d45cdae` | Gate s101 byte-identical. My own seed-103 `TP_LOT=vacant:7 TP_RENT=1 TP_TEST=7`: days 3 and 6 each charged bills $365 + rent $113, and the message named both. Save and load of tenure checked by the worker. |
| lots-and-homes | L8 Deposit | verified | `fc39b08` | Gate s102 byte-identical. My own seed-104 rental start: "Paid a deposit of $113.", starting money $13,637 = $13,750 − $113. Owner and empty-lot starts unchanged (worker's table). |
| lots-and-homes | L9 Renter limits | verified | `231ab21` | Gate byte-identical; click-test lines unchanged. My own seed-105 `TP_LIMITS` run: Build, wall, floor and selling the landlord's fridge refused with money unchanged; buying and selling a plant allowed. Landlord marks survive save and load (worker). |
| lots-and-homes | L10 Arrears warning | verified | `dc34802` | Gate s101 byte-identical. My own seed-102 runs: renter at $0 before the bill ends at −$478 and gets "You're $478 behind on the rent…"; at $478 it ends at $0 with no warning. |
| create-household | C1 Look lists | verified | `ca0a85a` | Pure move of three lists from `Person.roll()` into `Defs` (draw order unchanged). Gate byte-identical at seeds 100, 101, 102. |
| create-household | C2 Creator shell | verified | `7b8dddb` | Gate byte-identical. My own seed-101 `TP_CREATE_DONE` run: identical `CREATE spec` and `CREATE game` lines. Creator and after-Done screenshots looked at. |
| create-household | C3 Names | verified | `97a5b2a` | Gate byte-identical. My own seed-103 run with typed names (one with a trailing space): spec, game and save all read "Ottoline Brackenmoor" / family "Brackenmoor". Blank family name: Done greyed, `CREATE refused`, no save written. |
| create-household | C4 Members | verified | `d3084e3`, `4144b28` | Gate byte-identical. My own seed-104 "elder,child,adult" run: three spec and game lines match; refusals for the last adult printed; screenshot looked at. Guard commit: one-line diff; gate s101 byte-identical; my own `TP_TEST=2` on "child,adult,child" has no errors. |
| create-household | C5 Skin and hair colour | verified | `0808d76` | Gate s102 byte-identical. My own seed-105 run: chosen skin 0 and hair 3 equal in spec, game and a second launch that loaded the save (`f5ccad`, `99401f`). Screenshot with skin 4 and hair 2: rings and model match. Worker's montage of all 10 options. |
| create-household | C6 Hair style | verified | `b16893b` | Gate s101 byte-identical. My own seed-106 run: style 1 equal in spec, game and loaded save. Four-member screenshot (a 1261x508 window) fits, scaled with the window. Worker's montage of the four styles. |
| create-household | C7 Clothes | verified | `925498b` | Gate s102 byte-identical. My own seed-107 run: shirt 2 and trousers 0 equal in spec, game and loaded save, and equal to the HSV values computed independently. Chips already used the shirt colour (no `ui.gd` change). |
| create-household | C8 Build | verified | `bf19a3d` | Gate byte-identical (`roll()` reads the ranges, same draws). My own seed-108 shots at h 0.9 and 1.08: height difference plain. Save and load checked by the worker. |
| create-household | C9 Traits | verified | `9b5feaa` | Gate s101 byte-identical. My own seed-109 run: "2,8,8,8,8" clamped to [2,8,8,6,1] = 25; game traits identical. Screenshot of the new Traits tab. |
| create-household | C10 Trait hints | verified | `787085e` | Gate byte-identical. I read each tooltip against `_decay()`, `_score()`, the social success line, the insult rule and the socials table: all correct. One number ("3 or less") to drop in the next commit. |
| create-household | C11 Starting relationships | verified | `9a4e41e` | Gate s102 byte-identical (draw kept for every pair). My own seed-110 "adult,elder,child" run: family 55 and housemates 20 matched in the game; partners with the child refused and fell back to family. Worker's People-tab screenshot looked at. Nice tooltip number dropped. |

## Needs me

- **Rent share and the cost of living (a balance question, not blocking).** L7 set rent at
  1% of the home's value per three-day bill period ($104 to $131). Measured: two adults on
  starting jobs earn about $386 per period, and today's bills alone (3% of furniture value
  plus $25 a person) already take $301 to $357 of that, so a renting couple runs about $20 to
  $100 short per period until a promotion. Options: keep 1%; use 0.5%; or lower the existing
  bills. Changing the share is one constant (`Defs.RENT_SHARE`).
- **Merge order and how:** `lots-and-homes`, then `create-household`, then `town-view` merged
  onto `main` with no conflicts in the trial. Merging locally and pushing `main` skips
  GitHub's pull requests; to review them there, push each branch and open one PR each.
- **Fixed on `main` after merging (uncommitted):** two things the merged game needed (found
  in the trial merge; neither is a conflict):
  1. *An empty lot's build session is undone by Play.* With `TP_LOT=empty` and a normal boot,
     the game opens on the town (T5), which remembers the speed from before; L5's pause comes
     after, and Play then restores the old speed, so the household starts unpaused. Fix: call
     `_start_build_session()` when Play first enters an empty lot, or set
     `speed_before_town = 0` inside it.
  2. *The town is drawn before a vacant move-in.* L6 moves the household into a vacant lot in a
     deferred call, after the town view is built, so the town shows the household on its old
     lot and the new lot as "To let" (in gold) until the first trip to town refreshes it. Fix:
     call `town_view.refresh()` at the end of `_move_into_vacant()`. N3 replaces this path anyway.
- **Debt means hunger (a balance question, not blocking).** A meal costs $6 and a household
  with less cannot pay for one, so a household in debt stops eating; in L10's forced-$0 test
  one adult starved about a day later. This rule predates these branches.

## Deviations

- **Edit zones.** All three branches edit `main.gd`, and two edit `ui.gd` and `defs.gd`.
  So that they merge cleanly, each worker was given its own functions and its own
  insertion points (listed in `brief-batch2.md`).
- **Town-view draws home lots from the household's own `World`**, not from the lot's
  seed. Every home lot has a household with a world in memory, loaded or new, so the
  seed of -1 that F3 records for old saves never has to be used. Vacant lots, which always
  have a real seed, are generated from it.

- **T1 edited `cam.gd`**, outside its zone: pan bounds and max zoom became variables
  (`min_pos`, `max_pos`, `max_dist`), defaulting to the old numbers, so the town camera can
  pan along the street. The lot camera behaves as before. No other branch's zone includes
  `cam.gd`.
- **L1's test is met with starvation deaths allowed.** A bare lot has no fridge, so in a
  two-day empty-lot run the household starves (LOST lines are the probe's record of a
  death). I ruled that an empty-lot run passes when it has no `SCRIPT ERROR` or `STUCK` and
  every LOST is a starvation death. In play, L5 starts the household paused in Build, so the
  player buys a fridge first. No food was added and hunger was not changed.
- **C2's creator shows a turntable**, which the worker added; the roadmap does not ask for
  it. Done is pressed in tests by `TP_CREATE_DONE=1`.
- **L1 puts the empty-lot camera on the front of the lot**, not its centre, so the
  household at the kerb is in view at the default zoom.
- **C4 counts elders as adults** for the "at least one adult" rule: the game already starts
  neighbour households with a lone elder, and nothing stops elders running a home. Stages
  offered are child, adult and elder, the only three `Person.stage()` knows (there is no teen).
- **C4's zone was extended by one statement**: the `TP_TEST` start loop in `_ready()` gave
  every non-first member a job, which crashes for a child (`SCHOOL` has no `pay`). This
  could not happen before the creator, since random households are all adults. Now guarded
  to adults; gate unaffected.
- **T4's labels have a thin outline**: the worker could not get a heavy backing to draw
  behind the text in this renderer. INK and MUTED text read fine; "Your home" moves to the
  T5 highlight.
- **T5 is tested through `TP_BOOT=1`**: a normal launch would load your real save. The switch
  joins the same `elif` a normal launch takes, so only that one term differs.
- **T6 may add one row to `CONTROLS` in `ui.gd`** (its `T` key), outside its zone. No other
  branch edits that list.
- **L2's follow-up extends its zone** to `_spawn_child()` in `main.gd` and the visitor's
  `face()` call in `person.gd`: with a side door as the front door, a new child would
  appear on the lawn beside it. A stored inside tile fixes both.
- **L3 may edit `random_spec()` and the `home.money` line** (no other branch does), so that
  `money` in a spec becomes optional.
- **For `new-game-flow`: money in a spec wins.** After L3, a spec's `money` is used as is,
  even on an empty lot, and `random_spec()` drops it only when the player's world (already
  built) has no house. The creator's spec carries `money` = $2,500, so a creator household
  on an empty lot would start on $2,500, not `START_FUNDS`. `new-game-flow` must leave
  `money` out of the creator's spec, or set it from `START_FUNDS` less the lot price.
- **L4: `LOT_PRICE` $2,000 and `START_FUNDS` $13,750**, from 42 generated homes over seeds
  100 to 105 (cheapest $10,446, median $11,531, dearest $13,171): 1.1 × (lot + cheapest)
  rounded. A `TP_LOT=empty` start pays the lot price and begins with $11,750. Within any one
  town the cheapest home is dearer, so the spare there is 4.4% to 10.5%; `START_FUNDS` of
  $14,250 would give about a tenth in a typical town. Kept $13,750 as the rule reads.
- **L5 and town-view after the merge:** T5 boots a normal launch into the town and restores
  the earlier speed on Play, which could undo L5's starting pause. L5 is asked to put its
  pause in one function so the merge (or `new-game-flow`) can re-apply it.
- **C9 split the creator panel into Look and Traits tabs**, which the roadmap does not ask for,
  to keep it inside the window. Rolled traits over 25 (46% of rolls) are trimmed in the
  creator, highest first; `Person.roll()` is unchanged.
- **For `new-game-flow`, from L5:** the welcome toast ("…or just watch") still shows during
  the build session, since it lives outside `lots-and-homes`' zone. A loaded bare lot does not
  re-enter the session by itself; `_start_build_session()` is the call to make.
- **C10: the roadmap's summary of the traits was incomplete**, and the tooltips follow the
  code: neat, outgoing and playful also change how fast their need runs down (neat slower,
  outgoing and playful faster); active also slows tiredness; a social's success depends on the
  listener's trait named in the socials table (outgoing for chats, playful for jokes, nice for
  compliments and hugs); only grumpy people (nice 3 or less) start insults. Nothing in the
  code makes neat people tidy the house, so the tooltip doesn't claim it.
- **L6: in a vacant start, the scenery across the street comes from the home's seed**, since
  `World.setup` draws both from one seed. Cosmetic only.
- **C11's starting values:** partners 80 ("close", and above the 70 the baby social needs),
  family 55 ("friend", above the hug minimum), housemates 20 ("friendly"). A third creator
  tab, People, holds the pair choices. Partners are refused for any pair with a child.

## Log

- 2026-11-18 10:52. Main clean at `37f576e`. Created the three worktrees from it and ran the
  Godot import in each (all exit 0).
- 2026-11-18 about 10:54. Captured gate baselines at seeds 100 to 102. Seed 100 twice,
  byte-identical, and equal to the first batch's F4 output. No `SCRIPT ERROR`, `STUCK` or
  `LOST` lines. Captured the seeded click test: same 10 `selftest` lines as the first batch.
- 2026-11-18 10:55. Handed T1 (Sonnet), L1 (Opus) and C1 (Sonnet) to the three workers.
  Each brief adds the T1 clock pause in town; L1's rule that nothing changes without
  `TP_LOT`; and C1's check on seeds 100 to 102 plus the click test.
- 2026-11-18 10:56. C1 reported (`ca0a85a`) and verified: `defs.gd` +5 and `person.gd` -4/+2, a pure
  move. Draw order is unchanged, and the gate is byte-identical at seeds 100, 101 and 102. The
  hair-style names ("Cropped", "Long", "Bun", "Flat top") are the worker's labels for the
  four existing shapes. Handed C2 over with the screen registration point, the clock pause
  and a `TP_` switch for Done.
- 2026-11-18 10:58. T1 reported (`3bc8310`) and verified: the gate is byte-identical, and my own screenshot
  shows the street and 10 plates (7 lawn, 3 bare earth for empty lots). The `cam.gd` edit is accepted
  (Deviations). Handed T2 over: houses from each household's own world, vacant lots from a
  throwaway headless world, south plates turned to face the road, and the camera tilted.
- 2026-11-18 about 11:02. C2 reported (`7b8dddb`) and verified: gate byte-identical; my own seed-101 Done run
  gave matching spec and game lines; screenshots looked at. Handed C3 over.
- 2026-11-18 about 11:03. T2 reported (`5e798e5`). I sent it back, reading the south houses as sitting by the road.
  The worker measured both sides (front to road 10 to 15 tiles on each) and added a check print
  (`870bb7a`). I confirmed in the code that the house group is turned about the plate centre. My
  misread, so this is not counted as a failure. T2 verified.
- 2026-11-18 about 11:03. L1 reported (`e86f84e`). Its empty-lot run starves the household. I verified everything
  else (gates at 3 seeds, my own empty-lot run and screenshot) and ruled starvation acceptable
  (Deviations). Handed L2 over, noting that the click test's free-standing wall and door must not
  become the front door.
- 2026-11-18 11:01. Handed T3 over (labels; print one line per label to compare with the gate's lot lines).
- 2026-11-18 about 11:12. C3 reported (`97a5b2a`) and verified: gate byte-identical; my own typed-name run checked
  in the game, the spec line and the save JSON; blank name refused. Handed C4 over.
- 2026-11-18 11:04. T3 reported (`0bf46eb`) and verified: gate byte-identical; my seed-101 labels match the lots. The
  labels read pale (heavy light outline, faint gold), so the contrast fix is folded into T4. Handed T4 over.
- 2026-11-18 11:08. C4 reported (`d3084e3`) and verified. The report flagged that the `TP_TEST` start loop gives children jobs
  (2 `SCRIPT ERROR`s in a 2-day run with a child). I extended C4's zone by that statement and asked for a
  separate commit. T4 reported (`41b1d09`) and verified. Handed T5 over: a `TP_BOOT` switch stands in for a normal launch, since
  a real one would load the user's save.
- 2026-11-18 11:09. C4's guard (`4144b28`) verified: one-line diff, gate at seed 101 byte-identical, my two-child `TP_TEST=2` run
  clean. Handed C5 over (swatches, a screenshot per option as a montage, save-and-load check).
- 2026-11-18 11:10. T5 reported (`13d03a5`) and verified: gate and click-test lines unchanged; my `TP_BOOT` and Play runs at
  seed 101 looked right. Handed T6 over (Town button and `T` key, quiet save, refresh the town on entry, scripted round trip).
- 2026-11-18 11:11. L2 reported (`e15b9bf`) and verified: gates byte-identical; my own scripted room run at seed 101 matched the
  worker's sequence. Asked for the side-door follow-up (the stored inside tile) and L3 as two commits.
- 2026-11-18 11:14. T6 reported (`221c5d2`) and verified: my own round trip at seed 102 left the clock, money and people
  identical. Handed T7 over. C5 reported (`0808d76`) and verified: my save-and-load check matched the chosen colours exactly.
  Handed C6 over.
- 2026-11-18 11:15. T7 reported (`8448837`). Gate byte-identical; my own missing-save runs showed the prompt, and Create went to
  the lot. Sent back for polish: hover still tints a plate under the prompt, and the player's label is gold before
  there is a household. Failure 1 of 2.
- 2026-11-18 11:16. C6 reported (`b16893b`) and verified: style through save and load matched; the panel fits even a 508 px high window.
  Handed C7 over (creator-only palettes; the generator keeps random hues).
- 2026-11-18 11:17. L2 follow-up (`1abd362`) and L3 (`4512a0c`) verified: gates byte-identical; `START money $15000` on an empty lot.
  Handed L4 over. T7's fix (`d419983`) verified on my own screenshot. Handed T8 over.
- 2026-11-18 11:19. T8 reported (`8caa861`) and verified: `town-view` is complete (T1 to T8). C7 reported (`925498b`) and verified.
  Handed C8 over.
- 2026-11-18 11:21. L4 reported (`e5d2e9f`) and verified. Handed L5 over, with the pause in one function because of T5's restore on Play.
- 2026-11-18 11:22. C8 reported (`bf19a3d`) and verified. Handed C9 over (traits with a 25-point budget; rolled people often total over 25,
  so the creator trims to the budget without touching `roll()`).
- 2026-11-18 11:25. L5 reported (`a411291`) and verified. Handed L6 over. C9 reported (`9b5feaa`) and verified. Handed C10 over
  (tooltips checked against the code, quoted side by side).
- 2026-11-18 11:27. C10 reported (`787085e`) and verified against the code. Handed C11 over (no partner flag exists, so a choice only
  sets the starting value; the random draw is kept for every pair so the gate is unchanged).
- 2026-11-18 11:29. L6 reported (`52f248a`) and verified with my own seed-102 vacant start. Handed L7 over (rent share chosen from
  measured income per bill period; rent fixed at move-in).
- 2026-11-18 11:29. C11 reported (`9a4e41e`) and verified. `create-household` is complete (C1 to C11).
- 2026-11-18 11:32. L7 reported (`d45cdae`) and verified. The worker found that existing bills take 78 to 92% of a starting couple's
  pay, so no rent share meets the "about half" target I had suggested. Kept 1% and put the balance question under Needs me.
  Handed L8 over (a renting start begins from `START_FUNDS` less one period's rent).
- 2026-11-18 about 11:33. A dry-run merge (`git merge-tree`) of town-view, lots-and-homes (to L7) and create-household onto main: no conflicts.
- 2026-11-18 11:35. L8 reported (`fc39b08`) and verified. Handed L9 over.
- 2026-11-18 11:39. L9 reported (`231ab21`) and verified. Handed L10 over.
- 2026-11-18 11:41. L10 reported (`dc34802`) and verified. All 29 chunks verified. Starting the trial merge.
- 2026-11-18 about 11:40. Trial merge in a throwaway worktree (`trial-merge-2`): `lots-and-homes`, then `create-household`, then
  `town-view` onto `main`. No conflicts (git auto-merged `defs.gd`, `main.gd`, `person.gd`, `ui.gd`). Import clean. Gate byte-identical
  to `main` at seeds 100, 101, 102. Click-test lines identical. Cross-branch runs: creator household in the merged game
  (relationships 80/55/55 as chosen); rented vacant start with a town trip (clock, money, people unchanged; town card on lot 6
  "Garley"); empty and vacant lots in the town view. Found three integration issues: two under Needs me, and one in
  `town-view` (a zero-size house drawn for an empty player lot).
- 2026-11-18 11:42. Sent the zero-size-house fix back to the `town-view` worker (a T2 follow-up), since T2 says empty lots stay bare.
- 2026-11-18 11:44. `town-view` follow-up (`fd03ec6`) verified: merged into the trial branch, gate byte-identical at seeds 100 to 102,
  click-test lines identical, and an empty player lot at 22:00 shows a bare plate with its label (6 houses drawn, 3 of 3 lit).
  Deleted the throwaway worktree and branch `trial-merge-2`. Your real save was last written at 10:44, before this batch
  started at 10:52. Workers are idle; branches are local and unpushed.
- 2026-11-18 about 11:50. You chose to merge locally: `lots-and-homes` (3e64b28), `create-household` (a130e90) and `town-view`
  (3b5baf4) merged into `main` with no conflicts. Import clean; gate byte-identical at seeds 100 to 102; click test unchanged.
- 2026-11-18 12:10. Applied the two integration fixes on `main` (uncommitted): `_start_build_session()` sets `speed_before_town = 0`,
  and `_move_into_vacant()` calls `town_view.refresh()`, which keeps the create prompt's look when it is up. Checked: an empty
  lot stays paused after Play (and after Create on the prompt) until Space; a vacant move shows the household on its new lot
  and the old lot as "To let" from the first frame. Gate, click test and the empty-lot run unchanged.
