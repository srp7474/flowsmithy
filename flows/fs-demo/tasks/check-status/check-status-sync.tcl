# check-status-sync.tcl
#
# This script runs whenever the Task Run is clicked.

puts stderr "==> Loading step-1-sync.tcl (v1)"
namespace eval ::wb::exec::sync {}


proc ::wb::exec::sync::execSyncTask {ctx} {
  set task [$ctx task]

  $ctx log "-------------- starting check-status-sync.tcl -----"

  hilite -magenta "execSyncTask called for [$task name]"

  $ctx brief sCondCode "GOOD"

  
  set form [$ctx form]
  set globs [$form globs]

  $ctx brief sCondCode GOOD
   
  $ctx brief "computer-name" [$globs dget computer-name]
  set cn [$globs dget computer-name]
  set event [$globs dget "event" 0]
  incr event
  $globs dset "event" $event

  set runId "[$globs dget cycle].$event"

  $ctx brief "run-id" $runId


  set optResp ""
  set optGenStr ""
  set argList [$task getTypedArgs opt]
  foreach a $argList {
    set label [$a label]
    set value [$a value]
    $ctx brief "opt.$label" $value
    $ctx log "opt.$label  $value"
    set $label $value
    if {$label eq "resp"} { set optResp $value }
    if {$label eq "genstr"} { set optGenStr $value }
  }

  if {$optResp eq "FAIL"} {
    $ctx brief sCondCode FAIL
    $ctx brief sReason "opts.resp requested FAIL"
    $ctx log "opts.resp = FAIL -> sCondCode set to FAIL"
    return
  } elseif {$optResp eq "TRAP"} {
    $ctx brief sCondCode TRAP
    $ctx brief sReason "opts.resp requested TRAP"
    $ctx log "opts.resp = TRAP -> aborting: quit due to TRAP req"
    error "quit due to TRAP req"
  }

  for {set pass 0} {$pass < 5} {incr pass} {
    $ctx log "-------- pass [format %02d $pass] ----------"
    for {set loop 0} {$loop < 20} {incr loop} {
      $ctx log "[format %02d $pass].[format %02d $loop] computer-name $cn run-id $runId str:$optGenStr"
    }
    set lines [llength [$ctx logLines]]
    set bytes [expr {$lines * 61}]
    ::wb::run::renderStatusUpdate [$ctx task] "RUNNING:" "$lines generated occupying $bytes bytes"
    update idletasks
    after 1000
  }



}