# Options Configuration

**Cfg Mode: options**

Options are the user-facing input controls rendered by the WB Runner when a
task is selected. They let the user supply values — checkboxes, text fields,
radio buttons, dropdowns, file pickers — before running the task.

Each option can pass its value directly to the program as a named argument,
or it can be used indirectly by the parms processor.

---

## Option Fields

### type *(required)*

| Type | Control rendered | Notes |
|---|---|---|
| `check` | Checkbox | Value is true/false; parm receives the label name when checked |
| `text` | Text entry field | Free text; supports regex validation |
| `radio` | Row of radio buttons | Mutually exclusive; one value selected |
| `select` | Combo box (dropdown) | Same semantics as radio, more compact |
| `file` | File picker button | Stores an absolute file path |
| `directory` | Directory picker button | Stores an absolute directory path |

### label *(required)*

The text displayed next to the control in the Runner. Also used as the key
when the option's value is referenced in parms (`tern:`, etc.).

**Examples:** `server`, `refresh`, `year`, `apply`, `prod-mode`

### hint

Tooltip text shown when the user hovers over the control. Use this to explain
what the option does and when to use it.

**Example:**
```
When activated, connects and downloads the Stripe records on the Stripe server
```

### parm

The argument name passed to the program when this option has a value. If
omitted the option affects runtime behaviour only (e.g. used by a parms
`tern:` expression) and nothing is passed directly.

**Example** — `refresh` checkbox in `fmt-etrans-dons` passes `--refresh`:
```json
{ "type": "check", "label": "refresh", "parm": "refresh" }
```

### place

Short description of the control's purpose, shown in the options grid in the
Configurator and as the placeholder/label in the Runner.

**Examples:** `Backup local_db.bin`, `Apply to server`, `Refresh GMAIL cache`

### reqd

Set to `true` to prevent the task from running until the field has a value.
Applicable to `text` and `select` types.

**Example** — year selector in `cit-fin-set-context`:
```json
{ "type": "select", "label": "year", "reqd": true }
```

### values / places

Used by `radio` and `select` types. `values` is the list of program-facing
values; `places` is the parallel list of human-readable descriptions shown
in the UI. Prefix a value with `*` to make it the default selection.

**Example** — month selector with named places:
```json
{
  "type"  : "select",
  "label" : "month",
  "reqd"  : true,
  "values": [1,2,3,4,5,6,7,8,9,10,11,12],
  "places": ["January","February","March","April","May","June",
             "July","August","September","October","November","December"]
}
```

**Example** — radio with default value (100):
```json
{
  "type"  : "radio",
  "label" : "radio1",
  "parm"  : "radio1",
  "values": ["*100", 200, 300],
  "places": ["value 100 (default)", "value 200", "value 300"]
}
```

### regexPat / regexMsg

Validates a `text` field against a regular expression before the task can
run. `regexMsg` is the error shown when validation fails (defaults to a
generic message if omitted).

**Example** — integer-only field:
```json
{
  "type"     : "text",
  "label"    : "gen",
  "parm"     : "gen",
  "reqd"     : true,
  "regexPat" : "^[0-9]*$"
}
```

### custVal


`custVal` names a **custom validation hook**: a Tcl proc invoked at
option-validation time, after `reqd` and `regexPat`/`regexMsg` checks
have already run.

**How it's wired up:**

1. The hook proc must live in the `::wb::opt::hook::` namespace, under
   exactly the name given as `custVal`'s value -- e.g.
   `"custVal": "my-hook"` invokes `::wb::opt::hook::my-hook`.
2. It must accept a single argument, `ctx`:
   ```tcl
   proc ::wb::opt::hook::my-hook {ctx} { ... }
   ```
   `[$ctx task]` and `[$ctx arg]` give you the current Task and Arg
   objects inside the hook.
3. Hook procs are hot-loaded from a file named `<taskname>-hooks.tcl`,
   sitting in that task's own folder (`<flow>/tasks/<taskname>/`). It's
   reloaded automatically whenever its modification time changes -- no
   restart needed while developing a hook.
4. If *any* opt on a task has `custVal` set, that task's
   `<taskname>-hooks.tcl` is required to exist; a missing file surfaces
   as an error on every opt using `custVal`. Tasks with no `custVal`
   anywhere never look for a hooks file at all.
5. Inside the hook, `$arg set optErr "..."` reports a validation problem
   (shown the same way as a `reqd`/`regexPat` failure), and
   `$arg set value "..."` programmatically changes the field's own
   displayed value. A hook is also free to inspect *other* opts on the
   same task via `[$task findArg <label>]` (matched by **label**, not
   `parm`) -- this is a choice a given hook can make for its own
   validation logic, not a requirement of `custVal` itself; plenty of
   hooks won't need to look at any other field at all.

**Example** -- a field whose value depends on a companion checkbox:

```json
{ "type": "check", "label": "noparm" },
{
  "type"    : "text",
  "label"   : "CustValDemo",
  "parm"    : "custvaldemo",
  "custVal" : "val-custreq"
}
```

```tcl
# <taskname>-hooks.tcl
proc ::wb::opt::hook::val-custreq {ctx} {
  set task [$ctx task]
  set arg  [$ctx arg]
  set mate [$task findArg noparm]
  if {$mate eq ""} {
    $arg set optErr "mate 'noparm' MIA"
  } elseif {[$mate value] == 1} {
    $arg set optErr "'noparm' value 1"
    $arg set value "noparm checked"
  } else {
    $arg set value "noparm unchecked"
  }
}
```

### readonly

`readonly: true` makes the field non-editable by the user. Often paired
with `custVal` for a field whose value is entirely computed by a hook and
was never meant to be typed into directly.

**Example:**
```json
{
  "type"    : "text",
  "label"   : "custfld",
  "readonly": true,
  "parm"    : "custfld",
  "custVal" : "my-hook"
}
```

### fileType

For `file` controls — restricts the file picker dialog to matching patterns.
Separate multiple patterns with `;`.

**Examples:** `*.exe`, `wb*.tcl;*.png`

### histTag

For `file` and `directory` controls — enables a pick history dropdown so
previously used paths are quickly accessible. The tag groups histories across
tasks that share the same tag.

**Example:**
```json
{ "type": "file", "label": "file3", "fileType": "wb*.tcl;*.png", "histTag": "demo-tag" }
```

---

## Options Grid

In the Configurator the options for the selected task are shown as a grid
with columns: **Label**, **Type**, **Parm**, **Place**. Hover any row to see
the full hint and other fields in a tooltip.

Use **Add Option...**, **Edit Option...**, **Remove Option**, and **Move Up** to manage the list.

---

#