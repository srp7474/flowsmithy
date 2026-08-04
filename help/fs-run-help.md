
# FS Run — User Guide

## Road Map

This guide covers the **FS Run** window (built by `fs-run.tcl`), which is used to execute
and monitor Workflow steps.

- [Introduction](#introduction)
- [Starting the Runner](#starting-the-runner)
- [Left Panel — Workflow Steps](#left-panel-workflow-steps)
  - [Step Icons](#step-icons)
  - [Welcome and Help Links](#welcome-and-help-links)
- [Right Panel — Current Step Detail](#right-panel-current-step-detail)
  - [View Log](#view-log)
  - [Run Task](#run-task)
  - [Task Help](#task-help)
  - [Actions Menu](#actions-menu)
  - [Globs](#globs)
  - [Task, Description, Status](#task-description-status)
  - [Options](#options)
  - [Parms](#parms)
- [Log Panel](#log-panel)
- [Brief File](#brief-file)

---

## Introduction

The **FS Run** window is used to run Workflows (also called *flows*). A Workflow is an
ordered series of steps (tasks) that are executed in sequence to accomplish a larger goal.

The window is divided into three major areas:

- The **Left Panel** shows the sequence of steps and the status icon for each.
- The **Right Panel** shows the details and controls for the currently selected step.
- The **Log Panel** at the bottom records session activity.

*(A "Workflow Architecture" background link used to point here at
`file:c:/psec/gui/psecdocs/index.html` — a hardcoded local Windows path from
an earlier project layout. It's almost certainly stale/unreachable now and
has been dropped rather than guessed at. Flag me the right replacement link,
or the architectural background content itself, and I'll fold it back in.)*

---

## Starting the Runner

Enter `run <flow>` from the fs-shell, where `<flow>` is the workflow name
(the base name of its `<flow>-cfg.json`). Running `run` with no argument
shows the runner's format help and the list of available flows.

---

## Left Panel — Workflow Steps

The left panel lists every step in the workflow. Each row shows:

- An **icon** representing the current state of the step (see [Step Icons](#step-icons) below).
- The **step number** (hover to reveal the internal step name).
- The **step title**.

Clicking a step makes it the **Current Step** and updates the right panel accordingly.

Hovering over the icon displays the internal flag values used to determine the icon.

### Step Icons

Each step icon communicates both the *freshness* of the step's last run and its *completion
outcome*. Freshness is relative: a step is considered **stale** if any earlier step has run
more recently than this one (determined by comparing `brief.json` modification timestamps).

The table below lists every icon, its image, and what it means.

| Icon                                                                   | Name                                  | Meaning                                                                                                                         |
|------------------------------------------------------------------------|---------------------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| ![Blocked Stale](img:state_blocked_stale.png)                          | Blocked / Stale                       | The step cannot run — a required prior step has not completed successfully. No previous run of this step is on record.          |
| ![Blocked Stale — Prev Failed](img:state_blocked_stale_prev_fail.png)  | Blocked / Stale — Last Run Failed     | Step is blocked and needs to be re-run. The last time this step ran it **failed**.                                              |
| ![Blocked Stale — Prev Good](img:state_blocked_stale_prev_good.png)    | Blocked / Stale — Last Run Good       | Step is blocked and needs to be re-run. The last time this step ran it **succeeded**, but something upstream has changed since. |
| ![Blocked Stale — Prev Trapped](img:state_blocked_stale_prev_trap.png) | Blocked / Stale — Last Run Trapped    | Step is blocked and needs to be re-run. The last time this step ran it **trapped** (terminated abnormally).                     |
| ![Blocked — DependsOn not GOOD](img:blocked_dependson_blocked.png)  | Blocked — DependsOn Failed or Trapped | Step is blocked waiting for dependsOn task to succeed.                                                                          |
| ![Ready Stale](img:state_ready_stale.png)                              | Ready / Stale                         | The step is eligible to run but needs to be re-run. No previous run of this step is on record.                                  |
| ![Ready Stale — Prev Failed](img:state_ready_stale_prev_fail.png)      | Ready / Stale — Last Run Failed       | Step is ready and needs to be re-run. The last time this step ran it **failed**.                                                |
| ![Ready Stale — Prev Good](img:state_ready_stale_prev_good.png)        | Ready / Stale — Last Run Good         | Step is ready and needs to be re-run. The last time this step ran it **succeeded**, but an upstream step has since run again.   |
| ![Ready Stale — Prev Trapped](img:state_ready_stale_prev_trap.png)     | Ready / Stale — Last Run Trapped      | Step is ready and needs to be re-run. The last time this step ran it **trapped** (terminated abnormally).                       |
| ![Good / Fresh](img:state_good_fresh.png)                              | Good / Fresh                          | The step ran successfully and its result is current — no upstream step has run since.                                           |
| ![Failed / Fresh](img:state_fail_fresh.png)                            | Failed / Fresh                        | The step ran recently and **failed**.                                                                                           |
| ![Trapped / Fresh](img:state_trap_fresh.png)                           | Trapped / Fresh                       | The step ran recently but **trapped** — it terminated abnormally without producing a valid `brief.json`.                        |
| ![Halted](img:state_halted.png)                                        | Halted                                | A **manual** step is paused, waiting for user action before the workflow can continue.                                          |
| ![Running](img:state_running.png)                                      | Running                               | The step is currently executing.                                                                                                |

**Staleness** is determined by comparing `brief.json` file modification timestamps across
steps. A step becomes stale whenever any earlier step runs — even if that earlier step
produces the same result as before.

The `prev_good`, `prev_fail`, and `prev_trap` variants indicate the outcome of the **last
run of that same step**. This gives you at a glance whether the step was previously working
before it went stale, previously broken, or previously crashed — useful context when
deciding whether to run it again or investigate first.

**Blocked** steps are those that declare a dependency on a prior step (via the `dependsOn`
field in the Configurator, not `whenFail` — see the Task Configuration help). They cannot
be run until their dependency step has completed successfully and is not stale.

**Remedial / notification steps** are tasks named as another step's `whenFail` target.

*(One item worth double-checking against current behaviour: this doc states remedial steps
are only shown in the list once the step they're attached to has failed. An old header
comment in `fs-run.tcl` says "show ALL steps (including whenFail steps)" — dated back to an
early patch (v21, 2026-mar-15). It's unclear whether that's stale itself or whether the
filtering described here was added later and the comment just never got updated. Left as-is
rather than guessing — worth a quick behavioural check before release.)*

### Welcome and Help Links

Two links appear at the top of the left panel:

- **Welcome** — opens the help file specific to this flow (the flow's own `*-help.md`).
- **Help** — opens this user guide.

---

## Right Panel — Current Step Detail

The right panel shows the full detail of the step currently selected in the left panel.
The available links at the top change depending on the step type and its current status.

### View Log

Opens a window displaying the output log from the step's most recent execution (the task
log file, `runlog.txt`). Only one log view window is kept open at a time — opening a new
one closes any previously open log window for the same task.

### Run Task

Executes the current step. The link is disabled (greyed out) while the step is running or
while any other step is busy. Clicking **Run Task** also closes any open log view window
for this step so the new log is picked up cleanly after the run completes.

### Task Help

Opens the help file specific to this task, if one has been configured.

### Actions Menu

The three-bar (≡) icon at the top right of the panel opens a pop-up menu with the
following items:

- **View Globs** — displays all key/value pairs currently in the Globs table (including hidden keys).
- **Arg Values** — shows the internal Args table for the current step.
- **View Task** — shows the internal Task object details.
- **Java Props** — shows the resolved Java classpath and main class (only shown for Java task types).
- **Run Props** — shows the run properties for the current step (only shown when run properties are defined).
- **< Restart >** — restarts the entire Workflow runner process to pick up configuration or code changes.

### Globs

The **Globs** panel displays the visible key/value pairs from the Globs table — a
persistent dictionary of workflow-wide values. Visibility and persistence are controlled
via the prefix character.Keys prefixed with `~` are session-only

| Prefix | Visibility | Persistence |
| none | visible | persisted |
| ~ | hidden | not persisted |
| + | hidden | persisted |

The **View Globs** in the Actions Menu allows every glob key/pair to be viewed.

The following TCL code is used to obtain a glob value
```
    set form  [$ctx form]
    set globs [$form globs]
    set cycleNo [$globs dget cycleNo]
```


The following TCL code is used to update a glob value
```
   $ctx setGlob month "January"
```


### Task, Description, Status

- **Task** — the step title. Hovering over it shows the internal task name.
- **Description** — a more detailed explanation of what the step does. This field can
  reference Globs values using `${key}` substitution.
- **Status** — the outcome of the most recent run, together with the timestamp taken from
  the step's `brief.json` file.

### Options

Options are settings that can be adjusted before running a step. They influence parameters
or run properties (for example, whether Excel should be launched as part of the run).
When the **Parm** column is populated for an option, the selected value is passed to the
program as a command-line parameter.

### Parms

Parameters are values passed directly to the task program. They may carry literal values
or calculated values. Refer to the FS Configurator documentation for details on how
parameters are defined and resolved.

---

## Log Panel

The log panel at the bottom of the window records all major session activity — task starts,
task completions, errors, and other significant events. It does **not** persist beyond the
current session. Use the **Clear Log** link to clear the panel contents.

---

## Brief File

Every task is expected to produce a `brief.json` file in its task folder upon completion.
This is a JSON file whose top-level keys populate the Brief property grid shown in the
right panel. The key `sCondCode` determines the run outcome:

- `GOOD` — the run is deemed successful.
- `FAIL` — the run failed; `sReason` provides an explanation.
- Any other value (including absence of `brief.json`) is treated as a **TRAP** — the step
  terminated abnormally.

The modification timestamp on `brief.json` is used to determine step freshness relative to
other steps in the workflow.
