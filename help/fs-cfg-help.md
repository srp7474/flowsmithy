# FS Configurator Help

The FS Configurator (`fs-cfg.tcl`) is the authoring tool for FlowSmithy flow
configuration files. A **flow** is a named, ordered set of **tasks** that the
FS Runner executes. Each task can carry options, parameters, and runprops
properties that control exactly how it runs.

---

## What the Configurator Does

- Opens an existing flow config (`*-cfg.json`) for editing.
- Lets you add, edit, and reorder tasks and their associated items.
- Clone (task mode only) copies a task from this flow or another flow into
  the currently open flow.
- Saves changes either to a working copy (`*-cfg-tmp.json`) (in development mode) or the final file.

---

## The Cfg Mode Selector

The **Cfg Mode** combo box controls which aspect of the selected task you are
working on. There are five modes:

- **flow** — Edit the flow title. 
- **task** — Add or edit a task: name, title, description, type, dependencies.
  The Clone button allows you to find and clone an existing task.
- **options** — Manage the user-facing input controls for the selected task.
  
- **parms** — Manage the program arguments that are assembled at run time.
  
- **runprop** — Manage invocation properties (`runprops`) for the task.
  

---

## Global Bar

| Control | Purpose                                                                                                                                                                                                                        |
|---|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Save** | Write changes to the working copy (`*-cfg-tmp.json`)                                                                                                                                                                           |
| **Save Final** | Only shown when dev mode is enabled (`devp.enabled` in `flowsmithy.cfg`). When checked, Save writes to the real cfg file instead. When dev mode is off, this checkbox is hidden entirely and Save always writes the real file. |
| **Clone X...** | Find and clone a task within or across flows and add to this flow (task mode only)                                                                                                                                             |
| **Enable Restart** | Unlocks the Restart button                                                                                                                                                                                                     |
| **Restart** | Exit with code 77 so the shell can reload cfg. Used to reload TCL code or external changes.                                                                                                                                    |
| **Help** | Open this help file                                                                                                                                                                                                            |

---

## Specific Configuration Operations

The links below open the help page for each Cfg Mode.

- [Flow configuration](help://fs-cfg-flow-help.md)
- [Task configuration](help://fs-cfg-task-help.md)
- [Task Clone configuration](help://fs-cfg-task-clone-help.md)
- [Options configuration](help://fs-cfg-task-options-help.md)
- [Parms configuration](help://fs-cfg-task-parms-help.md)
- [Runprops configuration](help://fs-cfg-task-runprops-help.md)

---

## Files and Locations

In the following `<base>` refers to the flow name.

Path roots  are resolved from `flowsmithy.cfg` at startup:

- **`flows.dir`** — a list of candidate root directories; the first one that
  exists on disk wins. Flow configs live under it.
- **`home.dir`** — the FlowSmithy installation root (help files, templates,
  icons).

Config files follow the naming convention `<base>-cfg.json` and live at:

```
<first-existing-flows.dir>/<base>/<base>-cfg.json
```

Task runtime files (options, brief, runlog) live under:

```
<first-existing-flows.dir>/<base>/tasks/<task-name>/
```

Help files (including this one) live at:

```
<home.dir>/help/
```

Source files live at:

```
<home.dir>/src/
```


