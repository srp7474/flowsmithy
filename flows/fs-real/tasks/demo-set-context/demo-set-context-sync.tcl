# demo-set-context-sync.tcl
#
# Generated 2026-jul-22 courtesy of Claude (claude.ai).
#
# ============================================================================
# THIS IS A REFERENCE SAMPLE.
#
# It shows the recommended pattern for a context-setting task: an
# ordinary tcl-int task, run first in the flow, that reads a value from
# the flow's shared context dictionary (the "globs" table), updates it,
# and writes it back -- so every task later in this run, and every
# future run of the flow, can see the current value. brief.json is
# written normally on completion, as it is for any task -- each run's
# own timestamped record of what happened.
# ============================================================================

puts stderr "==> Loading demo-set-context-sync.tcl (v4)"
namespace eval ::wb::exec::sync {}

proc ::wb::exec::sync::execSyncTask {ctx} {
  set task [$ctx task]
  hilite -magenta "execSyncTask called for [$task name]"

  $ctx brief sCondCode GOOD

  set form  [$ctx form]
  set globs [$form globs]

  # cycleNo lives in the context dictionary, so it persists across runs
  # of the flow. If it isn't set yet (the first time this task has ever
  # run), start at 1; otherwise increment.
  if {[catch {set cycleNo [$globs dget cycleNo]}]} {
    set cycleNo 1
  } else {
    incr cycleNo
  }
  $ctx setGlob cycleNo $cycleNo
  $ctx brief cycleNo $cycleNo

  # month comes from this task's own "month" option (must exist in this
  # task's cfg.json opts -- a select, values jan..dec). The opts config
  # should guarantee a value is always present -- this check exists
  # anyway, because a missing month here means something about the
  # environment itself is broken, not that the user made a bad choice.
  set month ""
  set argList [$task getTypedArgs opt]
  foreach a $argList {
    set label [$a label]
    set value [$a value]
    $ctx brief "opt.$label" $value
    if {$label eq "month"} {
      set month $value
    }
  }
  if {$month eq ""} {
    error "FS system failure - month not set"
  }
  $ctx setGlob month $month
  $ctx brief month $month

  hilite -magenta "execSyncTask called for [$task name] cycleNo=$cycleNo month=$month"
}
