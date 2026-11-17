# The People: roadmap

Written 2026-11-17. Covers six requests: a town overview as the first screen, creating a
household, buying an empty lot and building on a starting budget, customising appearance
and traits, renting pre-made homes, a better About pane, and thumbnails in the Buy and
Build menus.

Every chunk below is sized to be built and tested on its own. Chunks are grouped into
branches, and the branch map says which branches can run at the same time.

## Where the game is today

- One scene. `scripts/main.gd` builds everything in `_ready()` and drops you straight
  onto your lot.
- Your household is id 0 with a drawn `World` (36 x 30 tiles). Three neighbour households
  each have their own `World` that is simulated but never drawn. There is no town: lots
  have no position relative to each other.
- A new household is rolled at random (`_new_household`, `Person.setup`) and is handed a
  generated, furnished house for free plus $2,500.
- `World.save_state()` / `load_state()` already turn a whole lot into data. Looks and
  traits are already saved per person.
- The HUD is built in code in `scripts/ui.gd`. The About pane is one text label
  (`info_l`); the Buy and Build lists are text rows (`_row`).
- Tests are driven by environment variables: `TP_TEST` (headless sim plus balance
  report), `TP_SHOT` (screenshot), `TP_SELFTEST` (scripted clicks), `TP_UI`, `TP_MODE`,
  `TP_SEED`, `TP_FRESH`, `TP_SAVE`.

## Rules for every chunk

1. **Regression gate.** This must run with no `SCRIPT ERROR`, `STUCK` or `LOST` lines:

   ```bash
   TP_TEST=3 TP_SEED=100 TP_AGE=0 godot --headless --path /home/jimbo/the-people
   ```

   Same-seed runs are repeatable (checked: two runs give byte-identical output), so a
   chunk marked **no behaviour change** passes when its output matches the output from
   before the change.
2. **Screens and screenshots need a display.** `TP_SHOT` saves nothing under
   `--headless`. Chunks tested by screenshot are run without that flag.
3. **Save keys are optional.** New data goes into the save as keys read with a default
   (`d.get("town", ...)`), so the save stays version 2, old saves keep loading, and
   branches do not fight over a version number.
4. **New screens go in new files.** Town and creator code lives in its own scripts, not
   in `ui.gd` or `main.gd`, which every branch touches.
5. **Each new start option gets a `TP_` switch** so it can be tested before the menus
   that lead to it exist. The switches named below are added by the chunk that needs
   them.

## Branch map

```
            about-pane ─────────────────────────────────────┐
            thumbnails ─────────────────────────────────────┤
main ──┬──                                                  ├── main
       └─ foundations ─┬─ town-view ────────┐               │
                       ├─ lots-and-homes ───┼─ new-game-flow┘
                       └─ create-household ─┘
```

| Branch | Can start | Runs alongside | Mostly touches |
|---|---|---|---|
| `about-pane` | now | everything | `ui.gd` (card, `_refresh_card`) |
| `thumbnails` | now | everything | new `thumbs.gd`; `ui.gd` (`build_side`, `_row`) |
| `foundations` | now | `about-pane`, `thumbnails` | `main.gd` (`_ready`, start-up), `person.gd` (`setup`), new `town.gd` |
| `town-view` | after `foundations` | `lots-and-homes`, `create-household`, both UI branches | new `town_view.gd`, `ui_town.gd`; `main.gd` (boot, input) |
| `lots-and-homes` | after `foundations` | `town-view`, `create-household`, both UI branches | `world.gd`, `household.gd`, `defs.gd`; `main.gd` (`_new_day`, build clicks) |
| `create-household` | after `foundations` | `town-view`, `lots-and-homes`, both UI branches | new `ui_create.gd`; `person.gd` (look), `defs.gd` (look lists) |
| `new-game-flow` | after the three above | both UI branches | `main.gd`, `ui_town.gd`, `ui_create.gd` |

So: three branches can start today, and at the widest point five run at once.

**Where merges can collide**

- `about-pane` and `thumbnails` both edit `ui.gd`, but in different functions. They
  merge cleanly as long as neither reformats the file or reorders `_ready()`.
- `town-view` and `lots-and-homes` both edit `main.gd`. Town edits start-up and input;
  lots edits `_new_day` and the build clicks. Keep to those areas.
- `lots-and-homes` and `create-household` both add constants to `defs.gd`. Add them in
  separate blocks, not at the same line.
- `foundations` rewrites start-up in `main.gd`, which is why the three branches behind
  it wait for it. It is four small chunks; land it first and quickly.
- Suggested merge order: `foundations`, then `about-pane` and `thumbnails` whenever they
  are ready, then `lots-and-homes`, `create-household`, `town-view`, and last
  `new-game-flow`.

## Chunks

Each row is one chunk. "Done when" is the test.

### `foundations` (no visible change; makes the other branches possible)

| # | Chunk | Done when |
|---|---|---|
| F1 | **Screen switch.** `main.gd` gets a current screen (`lot` or `town`) and `set_screen()`, which shows or hides the lot, its HUD and its camera. Lot input is ignored on other screens. `town` is an empty placeholder for now. `TP_SCREEN` picks the starting screen. | Default start is unchanged. `TP_SCREEN=town TP_SHOT=town.png` shows the placeholder with no lot HUD. |
| F2 | **Household spec.** Split `_new_household()` into `random_spec()`, which returns `{family, money, members: [{name, age, look, traits}]}`, and `start_household(spec)`, which builds the people. `Person.setup` takes look and traits from the spec instead of rolling them inline. | No behaviour change: gate output is identical. |
| F3 | **Town record.** New `scripts/town.gd`, data only: a list of lots, each `{id, kind: home / vacant / empty, household, seed, slot}`. A new game makes one lot per household plus a few vacant homes and empty lots. Vacant and empty lots are stored as a seed only. Saved under an optional `town` key; an older save gets a town built around its existing households. | The test report prints one line per lot. Save, load, and the list is the same. An existing save still loads. |
| F4 | **Home value.** `World.value()` adds up walls, doors, windows, floors and objects. The test report prints it per household. | Values print for seeds 100 to 105. These numbers set the prices in L4 and L7. |

### `about-pane`

Today the pane is five lines of text. The plan is a tab strip on the person card, so one
block is open at a time and the card stays compact.

| # | Chunk | Done when |
|---|---|---|
| A1 | **Tabs.** Replace the Needs and About toggles with a tab strip: Needs, Work, Skills, Traits, People. Only Needs has content; the others still show the old text for now. `TP_UI=tab:<name>` opens a tab for screenshots. | Screenshot per tab. Needs looks as it does today. |
| A2 | **Header.** Life stage and age move out of the text into a chip beside the name, always visible ("Adult, day 12", "Child, grows up in 3 days"). | Screenshot of an adult, a child and an elder. |
| A3 | **Work tab.** Job title and career, pay, hours, a performance bar, and what the next promotion needs ("Next: Line Cook, needs Cooking 4"). Separate wording for school, retired and no job. | Screenshot of each of the four cases. |
| A4 | **Skills tab.** One row per skill: name, level, and a bar for progress through the current level. The career skill is marked. Untouched skills are greyed, not hidden. | Screenshot. A bar visibly moves during one study session. |
| A5 | **Traits tab.** Five rows with a word at each end ("Messy" to "Neat") and a marker, replacing the list that only named extremes. | Screenshot. Marker positions match the saved trait values. |
| A6 | **People tab.** One row per person known: coloured initial, name, a bar centred on zero, and the word from `_rel_word`. Household first, then neighbours; scrolls past six rows. | Screenshot with at least one negative relationship. |
| A7 | **Clean-up.** Remove `info_l` and the old `TP_UI=info` path; retake `docs/screenshot-*.png`. | No reference to `info_l` remains. Gate passes. |

### `thumbnails`

| # | Chunk | Done when |
|---|---|---|
| H1 | **Renderer.** New `scripts/thumbs.gd`: a small off-screen viewport that builds any object with `Meshes.build_object`, frames it by its size, and returns a cached texture. Renders one per frame so the menu never stalls. `TP_THUMBS=<folder>` writes one PNG per object. | A PNG exists for every entry in `Defs.OBJECTS`, each framed and recognisable. |
| H2 | **Buy rows.** Each Buy row shows its thumbnail left of the name and price. Items you cannot afford are greyed. | `TP_MODE=buy TP_SHOT=buy.png` for two categories. |
| H3 | **Buy grid.** Switch the list to two-column tiles (picture, name, price) and widen the panel to fit. | Screenshot. Selecting, placing and rotating still work (`TP_SELFTEST`). |
| H4 | **Item details.** Hovering a tile shows what the object is for, taken from its interaction labels, plus comfort and room score where it has them. | Tooltip text is right for bed, fridge, bookshelf and plant. |
| H5 | **Floor swatches.** Floor rows show the real floor texture (`Meshes.make_tex`) in place of the flat colour square. | `TP_MODE=build TP_UI=floors TP_SHOT=floors.png`. |
| H6 | **Wall tools.** Wall, door, window and remove get a rendered picture of a short wall section through H1. | Screenshot of the Walls tab. |
| H7 | **Regression.** Sell mode, the placement ghost and the disabled state all still behave. | `TP_SELFTEST` output matches the output from before H1. |

### `town-view` (needs `foundations`)

Time is paused while you are in the town.

| # | Chunk | Done when |
|---|---|---|
| T1 | **Ground.** New `scripts/town_view.gd` draws a street and one plate per lot from the town record, with the existing camera controls. | `TP_SCREEN=town TP_SHOT=town.png` shows the street and the right number of lots. |
| T2 | **Houses.** Each home lot gets a simple block house sized from its `World.house` rectangle in its wall colour, with a roof. Empty lots stay bare. | Screenshot. House count equals home plus vacant lots. |
| T3 | **Labels.** A floating label per lot: the family name, "For sale" or "To let". | Screenshot. Labels match the report from F3. |
| T4 | **Lot card.** Hovering highlights a lot; clicking opens a card (new `scripts/ui_town.gd`) with the family and its members, or the lot's status. No prices or buttons yet. | A scripted click on lot 0 prints the right card title. |
| T5 | **Boot into town.** The game opens on the town with your household's lot highlighted and a Play button on its card. `TP_TEST` and `TP_SHOT` without `TP_SCREEN` still start on the lot. | Normal launch shows the town; Play enters the lot. Gate passes untouched. |
| T6 | **Back to town.** A Town button in the top-right bar, and a key, save and return to the overview. | Scripted lot, town, lot: clock, money and people are the same after the round trip. |
| T7 | **No household yet.** With no save, the town shows a "Create a household" prompt. Until `new-game-flow` lands, the button starts a random household as today. | Launch with `TP_SAVE` pointing at a missing file shows the prompt. |
| T8 | **Time of day.** The town is lit by the game clock and occupied homes show lights at night. | Screenshots at `TP_HOUR=12` and `TP_HOUR=22`. |

### `lots-and-homes` (needs `foundations`)

| # | Chunk | Done when |
|---|---|---|
| L1 | **Empty lot.** `World.setup` can skip the house: lawn and scenery only, with an entry tile at the kerb standing in for the front door. People with no living room to appear in start by the entry, and the camera centres on the lot. `TP_LOT=empty` starts there. | `TP_LOT=empty TP_TEST=2` passes the gate. A screenshot shows a bare lot with the household at the kerb. |
| L2 | **Front door follows building.** After any wall or door edit, the front door becomes the outside door nearest the street, or the kerb if there is none. Visitors and new children arrive there. | Scripted: build a room with a door on the empty lot; the printed door tile is that door; a visitor walks to it. |
| L3 | **Starting funds.** `Defs.START_FUNDS` replaces the fixed $2,500 for a household that has to house itself. A spec can carry its own figure. | `TP_LOT=empty` starts with exactly `START_FUNDS`. |
| L4 | **Lot price.** `Defs.LOT_PRICE` is taken off when a lot is bought. Set it and `START_FUNDS` from the F4 values so that a lot plus the cheapest generated home leaves about a tenth to spare. | Report shows funds, lot price, and the cheapest and dearest home values for seeds 100 to 105. |
| L5 | **Build session.** A household arriving on an empty lot starts paused in Build mode with a one-time hint. | Screenshot of the first frame. Needs do not move until the game is unpaused. |
| L6 | **Vacant home.** A household can be moved into a generated home it did not start in. `TP_LOT=vacant:<seed>`. | Gate passes with the switch. The home matches the same seed in the town view. |
| L7 | **Tenure and rent.** `Household.tenure` (own or rent) and `rent`, a share of the home's value from F4, charged with the three-day bills and named in the bills message. Saved as optional keys. | `TP_LOT=vacant:7 TP_RENT=1 TP_TEST=7`: money drops by the rent on days 3 and 6. |
| L8 | **Deposit.** Renting costs one rent period up front. | Starting money is `START_FUNDS` less the deposit. |
| L9 | **Renter limits.** Renters can buy and sell their own furniture but cannot change walls, doors or floors, or sell what came with the home. Build is greyed with a tooltip. | Scripted wall and sell attempts on a rented lot are refused and money is unchanged. |
| L10 | **Arrears warning.** A renter in debt at bill time gets a warning message. Eviction is left for later. | Scripted: with $0 at bill time the warning appears. |

### `create-household` (needs `foundations`)

| # | Chunk | Done when |
|---|---|---|
| C1 | **Look lists.** Move the skin tones, hair colours and hair styles out of `Person.setup` into `Defs`. | No behaviour change: gate output is identical. |
| C2 | **Creator shell.** New `scripts/ui_create.gd`, opened with `TP_SCREEN=create`: one rolled person on a stand, with Reroll and Done. Done prints the spec and, until `new-game-flow` lands, starts the game with it in a random home. | Screenshot. The printed spec matches the person who appears in the game. |
| C3 | **Names.** Family name and first name fields, each with a random-name button. Blank names are refused. | The names typed are the names in the game and in the save. |
| C4 | **Members.** Add and remove members (one to four), switch between them, and set each one's life stage. At least one adult is required. | Scripted: two adults and a child come through; removing the last adult is refused. |
| C5 | **Skin and hair colour.** Swatches; the preview updates as you click. | Screenshot per option. Choice survives save and load. |
| C6 | **Hair style.** Pick from the four existing styles. | As C5. |
| C7 | **Clothes.** Shirt and trouser colours. | As C5. The household chip takes the shirt colour. |
| C8 | **Build.** Height and width sliders, limited to the ranges the generator uses now. | Screenshot at both ends of each slider. |
| C9 | **Traits.** Five sliders from 1 to 9 with a word at each end and a shared budget of 25 points, which is the current average. Reroll keeps to the budget. | Cannot go over budget. Trait values in the game match the sliders. |
| C10 | **Trait hints.** Each slider's tooltip says what it changes, taken from the real rules: playful, outgoing and neat weight fun, social and hygiene; active weights skill practice; nice affects how socials land. | Tooltips read correctly against `_score` and the socials table. |
| C11 | **Starting relationships.** For each pair choose partners, family or housemates, which sets where their relationship starts. | Relationship values at game start match the choices. |

### `new-game-flow` (needs `town-view`, `lots-and-homes`, `create-household`)

| # | Chunk | Done when |
|---|---|---|
| N1 | **Create from the town.** The "Create a household" prompt opens the creator. Done returns to the town in a "find a home" state with the household's funds on show. Nothing is simulated yet. | Scripted: create, then the town shows the funds and no lot is taken. |
| N2 | **Buy an empty lot.** An empty lot's card shows its price and a Buy button, greyed when unaffordable. Buying takes the money, assigns the lot and opens the build session (L5). | Scripted purchase: money is funds less the lot price, and the lot opens paused in Build mode. |
| N3 | **Rent a home.** A vacant home's card shows rent and deposit and a Rent button. Renting moves the household in and starts play. | Scripted rental: tenure is rent, the deposit is taken, and renter limits apply. |
| N4 | **Buy a home outright.** The same card offers Buy at the home's value when the household can afford it. | Scripted purchase: tenure is own and no rent is charged on day 3. |
| N5 | **Menu routes.** "Start a new household" in the menu and on the game-over panel go to N1 with a new town. | Both routes reach the creator. |
| N6 | **Test starts kept.** `TP_TEST`, `TP_SHOT` and `TP_FRESH` still skip the flow and start a random household in a home. | Gate and the balance probe run exactly as before. |
| N7 | **End to end.** One scripted run: create, buy a lot, build a room, unpause, pass a day, save, load. | The script finishes with no errors and the loaded game matches the saved one. |

## Choices made in this plan

These are defaults I picked so the chunks could be written. Changing one moves a few
chunks, not the whole plan.

1. **The town is a 3D street of lots**, in the game's existing style, not a flat map.
2. **Time is paused in the town.**
3. **One played household at a time.** Starting another makes a new town, as "Start a
   new household" does today.
4. **All lots are the same size**, 36 x 30 tiles, with one lot price.
5. **Pre-made homes come from the existing house generator.** Hand-designed homes are
   listed under Later.
6. **Renters can furnish but not rebuild.**
7. **Traits use a 25-point budget** instead of free sliders.
8. **The About pane becomes tabs on the existing card**, not a separate window.
9. **Voice pitch is left out of the creator** while audio is switched off.

## Later

Not broken down yet; each needs the work above first.

- Keep the same town when starting another household, with the old one carrying on as
  neighbours.
- Switch which household you play from the town.
- Move house: leave a lot and take another.
- Eviction after repeated arrears; buying the home you rent.
- Hand-designed homes: export a lot to a file and offer it as a vacant home.
- Lots of different sizes and prices.
- Portraits from the thumbnail renderer on household chips, the People tab and town
  cards.
- More hair styles and outfits.

## Done

- **Skills climbed too fast** (people reached level 10 in about a week). Each level now
  takes longer than the one before: `Defs.SKILL_SLOWDOWN` and `Person.learn()`. The
  balance report has a SKILLS section that shows the pace.
