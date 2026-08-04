# demo-options-hooks.tcl
#
# Generated 2026-jul-29 courtesy of Claude (claude.ai) -- extracted from
# the original test-opt-ctls-hooks.tcl (an early PSEC-era draft of this
# mechanism), keeping only the one proc whose signature matches how
# FlowSmithy actually calls hooks today. The other two procs in that
# original file (identity, globsLookup) used an older two-argument
# signature and called into ::wb::parmhook::, a namespace that was never
# implemented anywhere in FlowSmithy -- they were an abandoned earlier
# design and are not carried forward here.
#
# v01: initial stub, extracted as-is from the original demo logic.
#      Intended for further modification -- Steve.
#
# ---------------------------------------------------------------------------
# How this file gets loaded:
#   - Lives in this task's own folder: <flow>/tasks/demo-options/
#   - Hot-loaded by ::wb::run::loadTaskHooks whenever any opt on this
#     task has a "custVal" key set, and reloaded automatically if this
#     file's mtime changes -- no restart needed while iterating on a hook.
#   - Every proc referenced by a "custVal" value must live in the
#     ::wb::opt::hook:: namespace and accept exactly one argument, ctx.
#     See fs-cfg-task-options-help.md's "custVal" section for the full
#     contract.
# ---------------------------------------------------------------------------

puts stderr "==> Loading demo-options-hooks.tcl (v01)"
namespace eval ::wb::opt::hook {}

# ------------------------------------------------------------------------
# val-custreq
#
# Demonstrates a hook that reads a companion opt on the SAME task and
# sets its own field's value based on it. Wired up via demo-options'
# "CustValDemo" opt ("custVal": "val-custreq"), which has a "noparm"
# checkbox as its companion:
#
#   { "type": "check", "label": "noparm" },
#   { "type": "text", "label": "CustValDemo", "parm": "custvaldemo",
#     "custVal": "val-custreq" }
#
# The cross-reference to "noparm" here is this hook's OWN choice of
# validation logic -- custVal itself has no opinion about it, and a
# different hook could just as easily ignore every other opt on the task.
# ------------------------------------------------------------------------
proc ::wb::opt::hook::val-custreq {ctx} {
  set task [$ctx task]
  set arg  [$ctx arg]

  set mate [$task findArg noparm]
  if {$mate eq ""} {
    $arg set optErr "mate 'noparm' MIA"
  } else {
    if {[$mate value] == 1} {
      $arg set optErr "'noparm' value 1"
      $arg set value "noparm checked"
    } else {
      $arg set value "noparm unchecked"
    }
  }
  hilite -magenta "val-custreq called for [$task name] [$arg label] $mate [$arg optErr]"
}

# shows how to set a computed value into a option that can be passed to the program. Typically option s/b readonly
proc ::wb::opt::hook::set-run-time {ctx} {
  set task [$ctx task]
  set arg  [$ctx arg]

  $arg set value [clock format [clock seconds] -format "%H:%M:%S"]
  hilite -magenta "set-run-time for [$task name] [$arg label]"
}

# shows how to construct a complex value from other arguments and global values
proc ::wb::opt::hook::build-head {ctx} {
  set task [$ctx task]
  set arg  [$ctx arg]
  set runCtl [$task findArg runtime]
  set runStr [$runCtl value]
  set dateStr [$ctx getGlob run-date]

  $arg set value "=== Report Heading for $dateStr at $runStr ==="
  hilite -magenta "build-head [$arg get value] for [$task name] [$arg label]"
}

# shows how to construct a custom validator
proc ::wb::opt::hook::str2-custval {ctx} {
  set task [$ctx task]
  set arg  [$ctx arg]
  set argStr [$arg get value]

  $arg set optErr ""
  set argStr [$arg get value]
  if {![string match {[Aa]*} $argStr]} {
    $arg set optErr "must start with A or a"
  }
  ::wb::run::persistOptsNow $task
}
