# Task Configuration

**Cfg Mode: task**

Task mode is where you create and edit the core identity of each task: its
name, title, description, type, and its dependency relationships to other
tasks in the flow.

---

## Task Fields

### name *(required)*

The internal identifier for the task. Used in file paths, dependency
references, and log entries. Must be unique within the flow.

- Lowercase, hyphen-separated by convention.
- Locked in the task panel once the task exists — you cannot type a new value
  directly into the Name field. To rename a task after creation, use the
  **Rename** button next to the Name field (see below).

**Examples:** `cit-fin-set-context`, `recycle-server`, `gen-don-anal-dec2021`

### title *(required)*

The label shown in the task list and the Runner UI.

**Examples:** `Set Financials Context`, `Recycle Server`, `Gen Donor Reports`

### desc

A one-line description shown in the Runner below the task title. Supports
glob interpolation — `[glob year]` will be expanded at run time.

**Example:**
```
This transforms the [glob year] etran transactions into stub DonateRec records.
```

### type *(required)*

Controls how the Runner executes the task.

| Type | Behaviour |
|---|---|
| `tcl-int` | Runs a built-in TCL procedure |
| `tcl-ext` | Runs an external `.tcl` script from the task folder |
| `java` | Invokes a Java main class — requires `runprops` |
| `manual` | Presents a checklist gate — user marks steps done before proceeding |

**Examples from `cit-fin-cfg.json`:**
- `cit-fin-set-context` — `tcl-int`
- `recycle-server` — `java`
- `reconcile-trans` — `manual`

### dependsOn

Task names that must have completed successfully before this task is
eligible to run. The Runner enforces this at execution time. Always stored
as a JSON array, even for a single dependency.

**Example** — `demo-depends` requires `demo-options` to have passed:
```json
"dependsOn": ["demo-options"]
```

In the configurator UI these are shown as checkboxes — tick every task this
one depends on. Only tasks that appear earlier in the flow are offered.

### whenFail

Names of an earlier task (or tasks) this task is a remedial/notification
step *for*. This task itself is hidden from the Runner's step list — and
therefore not selectable or runnable — until one of the named tasks
reports a FAIL or TRAP status. Recovers back to hidden if the watched task
returns to GOOD on a later run. Always a JSON array, even for a single
watched task.

**Example** — `demo-whenfail` is a remedial step that stays hidden until
`demo-status` fails or traps:
```json
"whenFail": ["demo-status"]
```

*(Note: as of the Configurator's earlier revisions, `whenFail` was stored
here but had no actual effect on visibility — it only showed up in a hover
tooltip. Real hide/reveal gating, as described above, was only just
implemented in the Runner.)*

---

## Adding a Task

1. Set Cfg Mode to **task**.
2. Click **Add Task...**.
3. Fill in name, title, desc, and type. Name can only be set here, at
   creation.
4. Tick any `dependsOn` or `whenFail` tasks from the checklists (only tasks
   that appear earlier in the flow are offered).
5. Click **Apply**.

The task is appended to the bottom of the flow.

## Editing a Task

Select the task in the list — its edit form opens directly (there is no
separate Edit button). Title, desc, type, and dependency selections are all
editable. Click **Apply** to commit.

## Renaming a Task

Click **Rename** next to the (read-only) Name field. The rename dialog
validates the new name and checks it isn't already used by another task in
this flow. Confirming it:

- Updates the task's `name` immediately in memory, and rewrites every other
  task's `dependsOn`/`whenFail` so nothing is left pointing at the old name.
- Does **not** move anything on disk right away — the actual task folder
  rename is queued and only applied when you do a *final* Save (i.e. with
  **Save Final** checked, or always, if dev mode is off). A working-copy
  (`-tmp.json`) save never touches folders on disk.

---
