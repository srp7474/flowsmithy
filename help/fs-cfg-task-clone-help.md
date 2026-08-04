# Clone Task

**Available in: Cfg Mode: task** (the Clone button only appears in task mode
— every other Cfg Mode hides it)

Clone Task lets you pull a task from any flow — this one or another — into
the flow you currently have open, instead of building a similar task from
scratch. It searches across every flow under `flows.dir`, shows you what a
candidate task actually contains (its saved option values, parms, and
runprops), and copies it in with a fresh name once you're happy with it.

This replaced an older single-flow-dropdown Clone Task dialog
(`::wb::cfg::cloneTaskDialog` and friends), which has since been removed
from `fs-cfg.tcl`.

---

## Opening the Search Window

Click **Clone Task...** on the global bar (task mode only). The **Clone Task
— Search Existing Flows** window opens and immediately runs an unfiltered
scan of every flow, so you see full results before typing anything.

## Search Criteria

| Field | Behaviour |
|---|---|
| **Search text** | Regex, case-insensitive, matched against each task's Title *or* Desc. Blank = match any. |
| **Flow name** | Regex, case-insensitive, matched against flow folder names. Blank = search all flows. |
| **Type** | Checkboxes for `java` / `tcl-int` / `tcl-ext` / `manual`. None checked = any type. |
| **Recipes only** | Only show tasks whose `recipe` field is non-empty. |

Click **Search** to re-run with the current criteria; **Close** dismisses
the window. An invalid regex in either text field shows an error dialog
rather than silently matching nothing.

**Note on "recipe" here:** this is a plain `recipe` string field on a task
(used purely as a searchable tag in this dialog) — it's unrelated to the
old Recipe Task browser system that was removed from the Configurator
entirely. Same word, different, much smaller feature.

---

## Results

Each match is shown as a clickable card with: **Src Flow**, **Src Task**,
**Title**, **Desc**, **Type**, and — only if set — **Recipe** and
**runprops.javaMain**.

Two behaviours worth knowing:

- **Deduplication**: if two tasks (anywhere in the scan) have identical
  Desc *and* Type, only the first one found is kept — flow order is
  alphabetical, task order follows each flow's `cfg.json`. This is silent;
  there's no "N duplicates hidden" count. If you're hunting for a specific
  task and it doesn't show up, a same-desc/same-type task earlier in scan
  order may have suppressed it.
- Flows or `cfg.json` files that fail to parse are skipped and logged, not
  fatal to the scan.

Clicking a card opens the **Task Detail** window rather than cloning
immediately.

## Task Detail Window

Opens once and stays open — clicking a different result card repopulates it
in place rather than spawning a new window, so you can compare candidates
without windows piling up. It's non-modal and docks to the right side of
the screen so it doesn't fully cover the search window.

Shows, top to bottom:

1. **Header** — Src Flow, Src Task, Title, Type, Desc (fixed, doesn't scroll).
2. **Options** — the task's *actual saved values* from its
   `tasks/<task>/options.json`, not just the option definitions.
3. **Parms** — the parm definitions from `cfg.json`.
4. **Runprops** — the runprops definitions from `cfg.json`.

Buttons at the bottom: **Clone This Task** and **Close**.

---

## What Actually Happens When You Click "Clone This Task"

1. **Name**: the source task's own name is kept if it's free in the
   destination flow (the flow currently open in the Configurator);
   otherwise it's uniquified as `<name>-copy1`, `<name>-copy2`, etc.
2. **Task entry**: the full source task dict is inserted into the
   destination flow's in-memory `cfgDict`, immediately after whichever
   task is currently selected in the Configurator's task list. This
   follows the same dirty-until-Save convention as every other edit — it's
   not written to disk until you Save.
3. **Files**: `<destFlow>/tasks/<chosenName>/` is created, and every file
   from the source task's folder is copied in. `<srcTask>-help.md` and any
   `<srcTask>-*.tcl` file (e.g. `-sync.tcl`, `-async.tcl`) are renamed to
   the new task name on the way in. **Everything else is copied
   unchanged** — including `options.json`, `brief.json`, and
   `runlog.txt`. That means a freshly cloned task starts out carrying the
   *source* task's last saved option values and its last run's brief/log,
   until you edit options or actually run it yourself. Worth knowing if
   you clone a task and see what looks like stale results sitting there.
4. **Refresh**: the Configurator's task list reloads and the new task is
   selected automatically.
5. **Cleanup**: both the Task Detail window and the search window close.

Any file-copy failures show a warning listing which files didn't make it
across, but the task entry itself is still added.

---


