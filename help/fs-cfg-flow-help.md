# Flow Configuration

**Cfg Mode: flow**

Flow mode lets you view and edit the top-level properties of the flow itself.
Switch to this mode using the Cfg Mode selector. The task list on the left
is still visible but has no effect while in flow mode.

---

## Flow Fields

### title *(required)*

The human-readable name displayed in the WB Runner title bar and at the top
of the task list panel.

**Example** — from `cit-fin-cfg.json`:
```
CIT Financials 2026 TCL Version
```

**Example** — from `wb-demo-cfg.json`:
```
PSEC Workflow Demonstration and Examples
```

### name *(read-only)*

The flow base name is derived from the config filename. It cannot be changed
here — rename the file and its containing folder if you need a different name.

For `cit-fin-cfg.json` the base name is `cit-fin`.

---

## Flow-Level Help File

If `<flowName>-help.md` exists in the flow's directory, two buttons appear
next to Edit Setup:

- **Edit Help** — opens the file in your editor.
- **View Help** — opens it rendered in a help viewer window. That window
  watches the file's modified time while it has focus, so saving an edit in
  your editor and switching back to the viewer refreshes it automatically.

If the file doesn't exist yet, these buttons are not shown.

---

## Saving Flow Changes

After editing the title, click **Apply** to commit the change to the in-memory
config, then use **Save** on the global bar to write it to disk.

The **Save Final** checkbox only appears when dev mode is enabled
(`devp.enabled` in `flowsmithy.cfg`):

- Dev mode **on**: Save writes to `<base>-cfg-tmp.json` unless **Save Final**
  is checked, in which case it writes the real `<base>-cfg.json`.
- Dev mode **off**: the checkbox is hidden entirely, and every Save writes
  directly to the real `<base>-cfg.json`.

---

## What Flow Mode Does Not Cover

Task order, task names, and everything else about individual tasks are managed
in **task** mode (and the other modes). Flow mode is intentionally narrow —
it only owns the flow title and the flow-level help file.

---
