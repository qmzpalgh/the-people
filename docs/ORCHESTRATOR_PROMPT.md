# Orchestrator prompt: the first three branches

Paste everything below the line into a new session opened in `/home/jimbo/the-people`.

---

You are coordinating work on The People, a life-simulation game written in GDScript for
Godot 4.7, in the repository at `/home/jimbo/the-people`. The plan is in
`docs/ROADMAP.md`. Read all of it before doing anything else: it describes the code as
it stands, the rules every chunk follows, and the chunks themselves.

Your job is to get three of its branches built, each chunk verified, and the whole thing
written up as you go: `foundations` (chunks F1 to F4), `about-pane` (A1 to A7) and
`thumbnails` (H1 to H7). These three were chosen because they do not depend on each
other, so they can be built at the same time. The other four branches in the roadmap are
out of scope here; they wait for `foundations` to be merged.

You coordinate and verify. Workers write the code. Use one worker per branch at a time,
each in its own git worktree with the branch checked out there, and run the three
branches in parallel. Within a branch, chunks go in roadmap order, one at a time,
because later chunks build on earlier ones. I am asking you to use subagents for this.

## Before you start

Check that `docs/ROADMAP.md` is committed on `main` and that `git status` there is
clean. When this prompt was written, the roadmap and a skills-balance fix were still
uncommitted. Worktrees are cut from the last commit, so workers would not see either.
If `main` is not clean, stop and ask me to commit; do not commit to `main` yourself.

If `docs/PROGRESS.md` already exists, an earlier run got part of the way. Read it,
check its claims against the branches' commits, and carry on from where it stopped
instead of starting again.

Then capture two baselines from `main`, saved outside the repository, because several
chunks are tested by comparing against them:

- The regression gate: `TP_TEST=3 TP_SEED=100 TP_AGE=0 godot --headless --path <checkout>`.
  Same-seed runs are byte-identical, so a chunk marked "no behaviour change" passes when
  its output matches this file.
- The scripted click test, which needs a display, so no `--headless`:
  `TP_FRESH=1 TP_SAVE=user://baseline-test.json TP_SHOT=<file>.png TP_SELFTEST=1 godot --path <checkout>`.
  H3 and H7 compare against its `selftest` lines.

F3 and F4 add lines to the test report on purpose. For those, the check is that the new
lines are the only difference; after that, the `foundations` baseline is the new output.

## Things that are not obvious about this repository

These have each been checked. Pass them on to every worker, since workers start with no
context.

- **A fresh worktree does not run until Godot has imported it.** Without that, every
  script fails with `Could not find type "World"`. Run
  `godot --headless --import --path <worktree>` once after creating it.
- **The gate command in the roadmap names the main checkout.** A worker who copies it
  as written tests `main`, not their own branch. Every test must use `--path` with the
  worker's own worktree.
- **New scripts need their `.gd.uid` file committed.** The repository tracks them.
  Running the import command again after adding a script creates the file.
- **All worktrees share one `user://` folder**, so parallel tests can overwrite each
  other's saves. Any test that saves or loads sets `TP_SAVE=user://<branch>-test.json`,
  with `TP_FRESH=1` when it should start from nothing. Nothing may read or write
  `user://the_people_save_v2.json`; that is my real save.
- **Screenshot tests open a real window** on my desktop for a few seconds and close
  themselves. That is expected. Save screenshots as `screenshot-<chunk>.png` in the
  worktree root, where they are already ignored by git.
- **`about-pane` and `thumbnails` both edit `scripts/ui.gd`**, in different functions.
  They merge cleanly only if neither reformats the file or reorders `_ready()`. Tell
  both workers to keep their edits inside the areas the roadmap's branch table names.
- **The HUD has a house style.** `ui.gd` builds everything from a few helpers (`_sb`,
  `_seg`, `_chip`, `_bar`, `_label`) and five colours, and its header comment states the
  principle: quiet by default, detail on demand. New UI should look like it belongs.
- GDScript here is indented with tabs.

## Briefing a worker

A worker knows only what you tell it. Each brief should give the worktree path and
branch, the chunk's row from the roadmap word for word, the roadmap's "Rules for every
chunk", the points above that apply, and which files and functions the chunk should
stay within. Ask for one commit per chunk with the chunk id at the start of the message,
for example `F1: Add screen switch`.

Ask the worker to report back with: the commit hash, each command it ran and what the
output showed, anything it did differently from the roadmap and why, and anything it
could not test. If the roadmap turns out to be wrong about the code, the worker should
say so and stop, not improvise around it.

## Verifying a chunk

A worker's report is a claim, not a result. Before you record a chunk as done, check it
yourself in that worktree: confirm the commit exists and contains only what the chunk
called for, run the regression gate, and run the chunk's own "Done when" test. Where
that test is a screenshot, open the image and look at it. Judge it as I would: is the
content right, is anything clipped or overlapping, does it match the rest of the HUD?

If a chunk fails, send it back to the worker with what you saw. If it fails a second
time, mark it blocked, stop that branch, and keep the other branches going.

## Documenting progress

Keep `docs/PROGRESS.md` in the main checkout. You are the only one who writes to it;
workers never touch it, which is what keeps it free of merge conflicts. Leave it
uncommitted for me to commit. Update it at each of these moments, not in a batch at the
end, so that it is accurate if the session is interrupted: when a chunk is handed to a
worker, when you have verified it, when it fails a check, and when you make a decision.

It should have four parts:

1. **Status table.** One row for each of the 18 chunks: branch, chunk, status (to do, in
   progress, reported, verified, blocked), commit hash, and one line on how it was
   verified. "Reported" means the worker says it is finished; "verified" means you
   checked. Keep those apart.
2. **Needs me.** Anything waiting on a decision or a look from me, newest first. Empty
   when there is nothing.
3. **Deviations.** Every place the work differs from the roadmap, with the reason.
4. **Log.** Dated entries, newest last, with the time taken from the `date` command
   rather than estimated. Record failed checks and their cause as well as successes.

Small decisions inside a chunk are yours to make; log them under Deviations. Anything
that changes the roadmap's "Choices made in this plan", or changes a chunk belonging to
a branch outside these three, is mine: put it under "Needs me" and carry on with
whatever does not depend on the answer.

## Finishing

When all three branches are through, or blocked, do a trial merge to prove they
combine: on a throwaway branch in a throwaway worktree, merge `foundations`, then
`about-pane`, then `thumbnails`, run the import, run the gate and the scripted click
test, and record the result in the log. Then delete the throwaway branch and worktree.
If the merge conflicts, record which files and hunks, and do not resolve it by editing
the real branches without telling me.

Do not push, open pull requests, or merge anything into `main`. Leave the three
branches local and ready for me to review.

Your final message should tell me: which chunks are verified and which are not, what is
under "Needs me", the result of the trial merge, where each branch and its worktree is,
and what you were unable to check. Lead with whatever I most need to act on.
