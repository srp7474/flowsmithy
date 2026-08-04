# Parms Configuration

**Cfg Mode: parms**

Parms are the program arguments assembled automatically at run time, before
the task executes. Unlike options (which the user fills in), parms are
computed — from glob values, option states, environment variables, or literal
strings — and passed directly to the program without user interaction.

Each parm entry produces one named argument: `--<parm> <value>`.

---

## Parm Fields

### parm *(required)*

The argument name passed to the program. Becomes `--<parm>` on the command
line. Letters, digits, underscore, and hyphen only — no spaces.

**Examples:** `year`, `gaetok`, `gaeurl`, `signal`, `ns`, `cache`

### parmExec *(required)*

The expression that produces the parm's value at run time. Its prefix is one
of four types — `lit:`, `copy:`, `eval:`, `tern:` — described below.

### hint

Describes what this parm is for. Shown as a tooltip in the parms list in
the Configurator.

**Example:** `Production token`, `Signal file for local server restart criteria`

---

## ParmExec Types

There are exactly four types, selected from a Type combo box in the Add/Edit
Parm dialog: `lit`, `copy`, `eval`, `tern`.

### copy:\<glob-key\>

Copies the current value of a named glob directly into the parm.

Use `~` prefix on the key for hidden globs (credentials, tokens).

**Examples:**
```json
{ "parm": "year",   "parmExec": "copy:year" }
{ "parm": "gaetok", "parmExec": "copy:~prod-tok" }
{ "parm": "gaetok", "parmExec": "copy:~devp-tok" }
```

From `cit-fin` — `fetch-prod-people` passes the production token:
```json
{ "parm": "gaetok", "hint": "Production token", "parmExec": "copy:~prod-tok" }
```

### tern:\<opt\>?\<val-true\>:\<val-false\>

Conditional expression. If the named option is checked/truthy, the parm
receives `val-true`; otherwise `val-false`. Values starting with `~` are
treated as glob keys (the `~` is stripped and the glob is resolved).

**Examples:**
```json
{ "parm": "tok", "parmExec": "tern:server?~prod-tok:~devp-tok" }
```

This passes the production token when the `server` checkbox is checked,
otherwise the development token. From `wb-devp` — `test-parm-ctls`:
```json
{
  "parm"    : "tok",
  "hint"    : "Ternary choice for glob value depending on opt.server",
  "parmExec": "tern:server?~prod-tok:~devp-tok"
}
```

### eval:\<string with \[glob x\] interpolation\>

Evaluates a string that can contain `[glob <key>]` and `[env-vbl <VAR>]`
expressions. Used to build paths, URLs, and filenames from multiple parts.

Note: `env-vbl` is **not** its own top-level parmExec type — it only appears
nested inside an `eval:` expression, as `[env-vbl VAR]`.

**Examples:**
```json
{ "parm": "gaeurl", "parmExec": "eval:http://localhost:[glob gael-port]" }
{ "parm": "gaeurl", "parmExec": "eval:https://[glob ~gael-proj].appspot.com" }
{ "parm": "out",    "parmExec": "eval:[glob curDir]/don-cache" }
{ "parm": "fixes",  "parmExec": "eval:[glob curDir]/don-cache/gmail-fixes-[glob year].json" }
{ "parm": "signal", "parmExec": "eval:[glob ~gael-base]/restart.txt" }
```

From `cit-fin` — `fmt-chq-trans` builds a year-specific output path:
```json
{ "parm": "out", "parmExec": "eval:[glob curDir]/trans/chqs-[glob year].json" }
```

**Reading an OS environment variable** — from `cit-fin` — `fmt-chq-trans`:
```json
{
  "parm"    : "besuv3",
  "parmExec": "eval:[env-vbl CIT_FIN_BESU_V3]"
}
```

### lit:\<literal value\>

Passes a fixed string verbatim. No glob resolution. Useful for constants,
namespaces, and multi-value slash-delimited lists.

**Examples:**
```json
{ "parm": "ns",   "hint": "Name space", "parmExec": "lit:cit" }
{ "parm": "bank", "hint": "Name of bank", "parmExec": "lit:bmo" }
```

Multi-value literal (slash-separated, used by program to split):
```json
{
  "parm"    : "pat",
  "hint"    : "files we process",
  "parmExec": "lit:054.323.ofx/1054.331.ofx/4608.095.ofx"
}
```

---

## Complete Task Example

From `cit-fin` — `recycle-server` uses `eval:` for URL construction and a
`tern:` is used in other tasks for environment switching:

```json
"parms": [{
    "parm"    : "signal",
    "hint"    : "Signal file for local server restart criteria",
    "parmExec": "eval:[glob ~gael-base]/restart.txt"
},{
    "parm"    : "url",
    "hint"    : "Access local server",
    "parmExec": "eval:http://localhost:[glob gael-port]"
}]
```

From `cit-fin` — `fetch-prod-people` uses `copy:` for token and `eval:` for
URL and path:
```json
"parms": [{
    "parm"    : "gaetok",
    "hint"    : "Production token",
    "parmExec": "copy:~prod-tok"
},{
    "parm"    : "gaeurl",
    "hint"    : "Access production server",
    "parmExec": "eval:https://[glob ~gael-proj].appspot.com"
},{
    "parm"    : "cache",
    "hint"    : "Pointer to local production cache",
    "parmExec": "eval:[glob curDir]/don-cache/people"
}]
```

---

## Managing Parms in the Configurator

**Add Parm...** opens a dialog with:

- A **Type** combo box (`lit` / `copy` / `eval` / `tern`), defaulting to `lit`.
  Selecting a type pre-fills `parmExec` with a labelled placeholder to edit
  (`lit:<value>`, `copy:<glob-key>`, `eval:[glob <key>]`,
  `tern:<opt>?<val-true>:<val-false>`).
- `parm` name and optional `hint` fields.
- A scrollable examples panel of real patterns mined from production flows,
  grouped by type — click one to copy its `parmExec` (and hint, if any) into
  the form.
- Live validation on every keystroke: empty name, a duplicate name against
  this task's existing parms, and an unresolved placeholder all disable the
  Add Parm button with an inline message.

**Edit Parm...** reuses the same dialog: the parm name is locked (renaming a
parm isn't supported — remove and re-add instead), and the type/parmExec/hint
fields preload from the existing entry.

There is no parm "registry" or "builder" list to pick from — the dialog and
its examples panel are the whole workflow now.

**Move Up** reorders parms — order matters because the program receives them
in sequence.

---
