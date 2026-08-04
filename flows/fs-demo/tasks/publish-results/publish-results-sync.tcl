# remedial-action-sync.tcl
#
# This script runs whenever the Task Run is clicked.

puts stderr "==> Loading remedial-action-sync.tcl (v1)"
namespace eval ::wb::exec::sync {}


proc ::wb::exec::sync::execSyncTask {ctx} {
  set task [$ctx task]

  hilite -magenta "execSyncTask called for [$task name]"

  set form  [$ctx form]
   set globs [$form globs]

  $ctx brief sCondCode "GOOD"
  $ctx brief "pub.on" "published on computer [$globs dget computer-name]"
  $ctx brief "pub.cycle" "[$globs dget cycle]"
  $ctx brief "pub.event" "[$globs dget event]"
  $ctx brief "pub.runId" "[$globs dget cycle].[$globs dget event]."
  $ctx log "================= published data from [$globs dget computer-name] ===================="
  $ctx log "cycle-no: [$globs dget cycle]"
  $ctx log "event-no: [$globs dget event]"
  $ctx log "   runId: [$globs dget cycle].[$globs dget event]"
  $ctx log "================= end-of-report ===================="


}