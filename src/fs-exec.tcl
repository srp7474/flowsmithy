# fs-exec.tcl (v6)
# Changelog (skinny; full detail in CHANGELOG.md):
#   v6 (2026-aug-03): prepTaskExec now calls ::wb::run::checkTaskRuntime (fs-run.tcl v117) as a safety net before routing to a handler -- java's $env(JAVA_HOME) was previously used unchecked (line ~547), a raw Tcl error if unset; now a clean FAIL brief + setupErr + hilite, same error-reporting shape as the existing "type not implemented" path
#   v5 (2026-jul-28): REVERT of v4 -- expandJavaPath's directory-only
#      contract was correct all along (confirmed against a proven-working
#      setup script); the bug was in fs-real-setup.tcl passing individual
#      files instead of a directory, fixed there instead -- see that file
#   v4 (2026-jul-28): [reverted above] had made expandJavaPath also accept
#      pre-resolved individual jar/zip files, based on a misdiagnosis
#   v3 (2026-jul-28): version bump only -- no other changelog history
#      exists for this file (header below is architecture/design doc)
# Code generated on 2026-Feb-22 06:29 courtesy of chatGPT
#
# Execution engine of wb system
#
#  Design of Execution Engine
#  --------------------------
#
#  task contains
#     type - execution type such as jave | tcl-int | ... see below
#     setupErr - a flag displayed by the ui as to the execution status
#
#  wb-run
#     when a task exection is requested calls ::wb::exec::prepTaskExec
#
#     This validates whether it can run. Such validation includes:
#       - ensuring we support type
#       - if reqd, that the exec script exists
#       - it iterates thru the arguments looking for bad formats or conflicting arguments
#
#     if an error is found, the error string gets posted to SetupErr
#     
#     a return of "" means the execution can proceed. An execution handler will have been
#     posted to task.execHand
# 
#     If the execution can proceed, ::wb::exec::fireTaskExec will next be called.
#
#  ::wb::exec::fireTaskExec processing
#
#     - An ExecResp object is populated
#     - The appropriate handler is called
#     - ::wb::run::signalTaskStart will be called
#     - if sync mode
#       the tcl-int script will be called
#       The ExecResp obj will be updated
#       ::wb::run::signalTaskEnd will be called
#     - if async mode
#       the execution will be started with sme mechanism to know when it is finished
#       The ExecResp obj will be updated when task completes
#       ::wb::run::signalTaskEnd will be called when it finishes
#

namespace eval ::wb::exec {
  variable VERSION 6

  # Current run file paths (sync mode single-run for now)
  variable curRunDir ""
  variable curRunlogPath ""
  variable curBriefPath ""
}
puts stderr "==> Loading fs-exec.tcl (v$::wb::exec::VERSION)"

# ---- public entry -----------------------------------------------------------
# taskExec taskObj
# Prepares a task for execution of a task based on its type.
# Returns "" if OK, else reason for failure
# 
# for now we check for existence of required files. Later we will check args for consistency etc.

proc ::wb::exec::prepTaskExec {task} {
  $task set setupErr ""
  $task set execHand ""
  $task set execMode "ASYNC"
  set ttype [$task type]
  #hilite -cyan "taskExecPrep [$task name] $ttype"

  # Safety net: renderTask (fs-run.tcl) already runs this same check at
  # task-selection time so it shows up as a setup error before Play is
  # ever clicked, but check again here too -- this is the actual moment
  # execution would otherwise crash ungracefully (e.g. $env(JAVA_HOME)
  # unset raises a raw Tcl error, not a clean failure). One check
  # (::wb::run::checkTaskRuntime), two call sites. Mirrors the "type not
  # implemented" error-reporting pattern below (writeBrief, not just
  # setupErr) so Status/Brief panels show a proper failure record.
  set runtimeErr [::wb::run::checkTaskRuntime $task]
  if {$runtimeErr ne ""} {
    $task set setupErr $runtimeErr
    set ctx [::wbobj::buildCtx $task]
    $ctx brief sCondCode FAIL
    $ctx brief sReason $runtimeErr
    $ctx brief result "execution did not happen"
    ::wb::exec::writeBrief $ctx

    hilite -red $runtimeErr
    return $runtimeErr
  }

  if {[$task runprops] ne ""} {
    set runprops [$task runprops]
    set manageApp [expr {[dict exists $runprops manageApp] ? [dict get $runprops manageApp] : ""}]
    if {$manageApp ne ""} {
      ::wb::exec::manageApp false $task $manageApp ;# stop previous application
    }
  }


  # routing table --> execHandplease
  if {$ttype eq "tcl-int"} {
    $task set execPath [file join [$task taskDir] "[$task name]-sync.tcl"]
    $task set execHand ::wb::exec::handleTclIntSync
    $task set execMode "SYNC"
  } elseif {$ttype eq "tcl-ext"} {
    $task set execPath [file join [$task taskDir] "[$task name]-sync.tcl"]
    $task set execHand ::wb::exec::handleTclExtASync
    $task set execMode "ASYNC"
  } elseif {$ttype eq "java"} {
    $task set execHand ::wb::exec::handleJavaASync
    $task set execMode "ASYNC"
  } elseif {$ttype eq "manual"} {
    $task set execHand ::wb::exec::handleManualSync
    $task set execMode "SYNC"
  } else {
     set errMsg "Task execution type $ttype not implemented"
     set ctx [::wbobj::buildCtx $task]
     $ctx brief sCondCode FAIL
     $ctx brief sReason $errMsg
     $ctx brief result "execution did not happen"
     ::wb::exec::writeBrief $ctx
     set resp [::wbobj::ExecResp new]

     hilite -red $errMsg
     return $errMsg
  }
  return "" ;# all is good

}

# ---- public entry -----------------------------------------------------------
# taskExec taskObj
# Executes a task based on its type.
# Returns an ExecResp object.
# assumes taskExecPrep ran OK 

proc ::wb::exec::fireTaskExec {task} {

  if {[$task setupErr] ne ""} {error "Task [$task name] cannot call taskExec with hot setup error [$task setupErr]"}
  set execHand [$task execHand] 
  if {$execHand eq ""} {error "Task [$task name] has no execHand"}
  set execMode [$task execMode]

  hilite -cyan "fireTaskExec $execHand $execMode [$task briefPath]"


  # Build response shell
  set resp [::wbobj::ExecResp new]
  $resp set engine [$task type]
  $resp set mode   $execMode
  $resp set task   $task
  $resp set runDir [$task taskDir]

  # Clear expected run files - not present indicates run failure
  file delete [$task briefPath]
  file delete [$task logPath]


  # Notify UI we're starting (soft lock)
  ::wb::run::signalTaskStart $resp
  $resp markStarted
  ::wb::exec::logRun "" "Run Task [$task name] type [$task type] started"

  # call handler
  set execHand [$task execHand]

  if {$execMode eq "SYNC"} {
    $execHand $task $resp
    ::wb::run::signalTaskEnd $resp
  } elseif {$execMode eq "ASYNC"} {
    # async process are expected to return a pipe.
    set pipe [$execHand $task $resp]
    if {$pipe eq ""} {
      set logRun "did not get pipe"
      $resp markEnded 7000 $logRun
    } else {
      ::wb::exec::waitForPipeProcess $task $resp $pipe
    }
  } else {
    error "execMode $execMode not valid"
  }
  return $resp
}

proc ::wb::exec::waitForPipeProcess {task resp pipe} {
  fconfigure $pipe -blocking 0 -buffering none

  # keep state by pipe
  set ::wb::exec::asyncState($pipe) [dict create \
      task   $task \
      resp   $resp \
      logRun ""]

  fileevent $pipe readable [list ::wb::exec::onAsyncPipeReadable $pipe]
}

proc ::wb::exec::onAsyncPipeReadable {pipe} {
    if {![info exists ::wb::exec::asyncState($pipe)]} {
        catch {fileevent $pipe readable {}}
        catch {close $pipe}
        return
    }

    set st   $::wb::exec::asyncState($pipe)
    set task [dict get $st task]
    set resp [dict get $st resp]
    set logRun [dict get $st logRun]

    # read whatever is available right now, non-blocking
    set chunk [read $pipe]
    if {$chunk ne ""} {
        append logRun $chunk
        dict set st logRun $logRun
        set ::wb::exec::asyncState($pipe) $st
        set msg "read chunk of [string length $chunk] bytes, logRun now [string length $logRun] bytes"
        #log $msg
        ::wb::run::renderStatusUpdate $task "RUNNING" $msg
    }

    # not done yet
    if {![eof $pipe]} {
        return
    }

    # done: stop watching before close
    fileevent $pipe readable {}

    set rc 0renderStatusUpdate
    set msg "good ending"

    if {[catch {close $pipe} err opts]} {
        set rc -1
        set msg $err
        if {[dict exists $opts -errorcode]} {
            set ec [dict get $opts -errorcode]
            if {[lindex $ec 0] eq "CHILDSTATUS"} {
                set rc [lindex $ec 2]
            }
        }
    }

    # final accumulated log
    set logRun [dict get $::wb::exec::asyncState($pipe) logRun]
    unset ::wb::exec::asyncState($pipe)

    if {$rc == 0} {
      $resp markEnded 0 $msg
    } else {
      $resp markEnded $rc $msg
    }
    hilite -cyan "pipe completed $rc logRun size [string length $logRun]"
    set pathLogRun [$task logPath]
    ::wb::exec::writeLogRun $pathLogRun $logRun
    ::wb::run::signalTaskEnd $resp

}

# ---- routing targets --------------------------------------------------------

# tcl-int sync:
# - script: <task.execlocn>/<task.name>-sync.tcl
# - script must define ::wb::exec::sync::execSyncTask ctx
proc ::wb::exec::handleTclIntSync {task resp} {

  # Build ctx
  set ctx [::wbobj::buildCtx $task]

  # Source and invoke
  if {[catch {
    namespace eval ::wb::exec::sync {}  ;# ensure exists
    set tclPath [$task execPath]
    log "handleTclIntSync $tclPath"
    source $tclPath
  } err]} {
    set msg "tcl-int source failed: $err"
    ::wb::exec::logRun $ctx $msg
    $resp markEnded 1 $msg
    ::wb::exec::writeBrief $ctx
    ::wb::exec::writeLogLines $ctx
    return
  }

  if {![llength [info commands ::wb::exec::sync::execSyncTask]]} {
    set msg "tcl-int missing proc ::wb::exec::sync::execSyncTask"
    ::wb::exec::logRun $ctx $msg
    $resp markEnded 1 $msg
    ::wb::exec::writeBrief $ctx
    ::wb::exec::writeLogLines $ctx
    return
  }

  if {[catch {
    ::wb::exec::sync::execSyncTask $ctx
  } err opts]} {

    set msg "tcl-int runtime error: $err"

    set callStack ""
    if {[dict exists $opts -errorinfo]} {
      set callStack [dict get $opts -errorinfo]
    }

    ::wb::exec::logRun $ctx $msg
    if {$callStack ne ""} {
      hilite -red $callStack
    }

    $resp markEnded 1 $msg
    ::wb::exec::writeBrief $ctx
    ::wb::exec::writeLogLines $ctx
    return
  }

  ::wb::exec::logRun $ctx "tcl-int completed OK"
  $resp markEnded 0
  ::wb::exec::writeBrief $ctx
  ::wb::exec::writeLogLines $ctx
  return
}

# manual sync:
# - handles manual execution. Alsways succeeds
proc ::wb::exec::handleManualSync {task resp} {

  # Build ctx
  set ctx [::wbobj::buildCtx $task]

  # Source and invoke

  $ctx brief sCondCode GOOD
  foreach arg [$task getTypedArgs opt] {

    if {[$arg uiType] eq "check"} {
      set lab [$arg label]
      set txt [$arg place]
      $ctx brief $lab "Marked Completed: $txt"
      $ctx log "$lab $txt has been marked completed"
    }
  }
  $ctx log "---- all manual steps for [$task name] completed"


  ::wb::exec::logRun $ctx "manual task completed OK"
  $resp markEnded 0
  ::wb::exec::writeBrief $ctx
  ::wb::exec::writeLogLines $ctx
  return
}

# Code generated on 2026-Mar-05 06:28  courtesy of chatGPT
# -------------------------------------------------------------------------------
# TCL-EXT async runner (ExecResp-aware)
# This handler assumes we are communication with wb-wrap.tcl which wraps the
# real tcl script target so that there is a standard way to unravel the
# parms.
#
# Parms directed at wb-wrap are prefixed with a -@ such as -@runDir
#
# Parms for the target script are prefixed with just a - and are always paired
#
#

namespace eval ::wb::exec {
  variable TCL_EXT
  array set TCL_EXT {}
}

proc ::wb::exec::handleTclExtASync {task resp} {
  # resp is ::wbobj::ExecResp
  set runDir [$resp runDir]
  if {[string trim $runDir] eq ""} {
    $resp set status "START_FAILED"
    $resp set errMsg "TCL-EXT: resp.runDir is empty"
    hilite -red "TCL-EXT: resp.runDir is empty"
    return ""
  }

  set scriptDir [::wb::run::fetchScriptDir]

  #hilite -cyan "handleTclExtASync $scriptDir"


  set wrapPath [file normalize [file join $scriptDir wb-wrap.tcl]]

  # External interpreter - what we are using
  set tclsh [info nameofexecutable]
  if {$tclsh eq ""} {
    # Works if you started wb-run under a Tclsh already; else it’s still a safe fallback.
    hilite -red "lost TCL interpreter"
    $resp set status "START_FAILED"
    $resp set errMsg "TCL-EXT: resp.runDir is empty"
    return
  }
  #hilite -cyan "handleTclExtASync $tclsh $wrapPath"


  # Build cmd line (wrapper args kept simple)
  # Optionally add -main ::your::proc later; wb-wrap.tcl v1 supports it.

  set tod [clock format [clock seconds] -format "%H:%M:%S"]
  set taskName [$task name]
  set targTcl "$taskName-async.tcl"

  set optList {}
  foreach arg [$task getTypedArgs opt] {
    set parm  [$arg parm]
    set value [$arg value]
    if {$parm ne "" && $value ne ""} {lappend optList "-$parm"; lappend optList "$value"}
  }


  set cmd [list $tclsh $wrapPath -@task $taskName -@runDir $runDir -@targTcl $targTcl -tod $tod {*}$optList]
  hilite -cyan "tcl-ext cmd: $cmd OPTLIST $optList"

  # Mark resp started (engine-level)
  $resp set engine "tcl-ext"
  $resp set mode   "async"
  $resp set task   $task
  $resp set status "RUNNING"
  $resp markStarted

  # Start external process and merge stderr into stdout so we capture everything
  set pipe ""
  if {[catch {
    set pipe [open [list | {*}$cmd 2>@1] r]
  } err]} {
    $resp set status "START_FAILED"
    $resp set errMsg "TCL-EXT: failed to start: $err"
    $resp set exitCode ""
    $resp markEnded -1 $err
    hilite -red "start error $err"
    return ""
  }
  return $pipe

}

proc ::wb::exec::_tclExtOnReadable {pipe} {
  hilite -cyan "reading $pipe"
  variable TCL_EXT
  if {![info exists TCL_EXT($pipe,resp)]} {
    catch {fileevent $pipe readable ""}
    catch {close $pipe}
    return
  }

  set resp  $TCL_EXT($pipe,resp)

  # Drain available bytes
  #set data [read $pipe]
  #if {$data ne ""} {
  #  puts -nonewline $logFd $data
  #  flush $logFd
  #}

  if {[eof $pipe]} {
    hilite -cyan "eof $pipe"
    catch {fileevent $pipe readable ""}

    set rc 0
    set closeErr ""
    if {[catch {close $pipe} closeErr opts]} {
      set rc -1
      if {[dict exists $opts -errorcode]} {
        set ec [dict get $opts -errorcode]
        if {[llength $ec] >= 3 && [lindex $ec 0] eq "CHILDSTATUS"} {
          set rc [lindex $ec 2]
        } elseif {[llength $ec] >= 2 && [lindex $ec 0] eq "CHILDKILLED"} {
          set rc -2
        }
      }
    }

    # Update resp
    $resp set exitCode $rc
    if {$closeErr ne ""} { $resp set errMsg $closeErr }
    $resp set status "DONE"
    $resp markEnded $rc $closeErr

    if {0} {
      set elapsedMs [expr {[clock milliseconds] - $TCL_EXT($pipe,startMs)}]
      puts $logFd "\n==> TCL-EXT end: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] rc=$rc elapsedMs=$elapsedMs"
      if {$closeErr ne ""} {
        puts $logFd "==> close() error: $closeErr"
      }
      flush $logFd
      close $logFd

    }

    # TODO: re-enter your engine lifecycle here if needed (render refresh / next step)

    foreach k [array names TCL_EXT "$pipe,*"] { unset TCL_EXT($k) }
    ::wb::run::signalTaskEnd $resp
  }
}



proc ::wb::exec::handleJavaASync {task resp} {
  # resp is ::wbobj::ExecResp
  set runDir [$resp runDir]
  if {[string trim $runDir] eq ""} {
    $resp set status "START_FAILED"
    $resp set errMsg "TCL-EXT: resp.runDir is empty"
    hilite -red "TCL-EXT: resp.runDir is empty"
    return ""
  }


  set optList {}
  set briefPath [$task briefPath]
  lappend optList "-brief"; lappend optList "$briefPath"
  # add option values with parm
  foreach arg [$task getTypedArgs opt] {
    set uiType  [$arg uiType]
    set parm    [$arg parm]
    set value   [$arg value]
    if {$parm ne "" && $value ne ""} {
      if {$uiType eq "check"} {
        if {[string is true -strict $value]} {
          lappend optList "-$parm" ;#booleans go as single arg
        }
      } else {
        if {$value ne ""} {
          lappend optList "-$parm"; lappend optList "$value"
        }
      }
    }
  }

  # add parm values with value
  foreach arg [$task getTypedArgs parm] {
    set parm    [$arg parm]
    set value   [$arg value]
    if {$value ne "" && $parm ne ""} {
      lappend optList "-$parm"; lappend optList "$value"
    }
  }

  set runprops [$task runprops]
  set javaMain [dict get $runprops javaMain]
  set cpTag    [dict get $runprops cpTag]
  set form  [$task form]
  set pathDict [$form paths]
  set paths [dict get $pathDict $cpTag]
  set cpStr [::wb::exec::expandJavaPath $paths]

  set javaExe [file join $::env(JAVA_HOME) bin java]
  set cmd [list $javaExe -cp $cpStr $javaMain {*}$optList]
  #hilite -cyan "java cmd: $cmd"

  # Mark resp started (engine-level)
  $resp set engine "tcl-ext"
  $resp set mode   "async"
  $resp set task   $task
  $resp set status "RUNNING"
  $resp markStarted


  # Start external process and merge stderr into stdout so we capture everything
  set pipe ""
  if {[catch {
    set pipe [open [list | {*}$cmd 2>@1] r]
  } err]} {
    $resp set status "START_FAILED"
    $resp set errMsg "TCL-EXT: failed to start: $err"
    $resp set exitCode ""
    $resp markEnded -1 $err
    hilite -red "start error $err"
    return ""
  }
  return $pipe

}



# ---- run artifacts ----------------------------------------------------------


# ----------------- defunct code kept for refernce ------------------

proc ::wb::exec::writeBrief {ctx} {
  set dict [$ctx briefDict]
  set task [$ctx task]
  set path [$task briefPath]
  #hilite -cyan "writeBrief $path $dict"
  dictAsJsonFile $path $dict ""
}

proc ::wb::exec::writeLogLines {ctx} {
  set task [$ctx task]
  set logPath [$task logPath]
  set logLines [$ctx logLines]
  set fh [open $logPath w]
  try {
    foreach line $logLines {
      puts $fh $line
    }
  } finally {
    close $fh
  }
}

proc ::wb::exec::writeLogRun {path logRun} {
  set fh [open $path w]
  try {
    puts $fh $logRun
  } finally {
    close $fh
  }
}


# logRun ctxOrEmpty msg
# Appends to runlog.txt and mirrors to UI log panel.
proc ::wb::exec::logRun {ctx msg} {

  set ts [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
  set line "$ts  $msg"

  if {$ctx ne ""} {
    $ctx log $line
  }

  # mirror to UI
  if {[llength [info commands ::wb::run::logMsg]]} {
    ::wb::run::logMsg $msg
  }
  return
}


# ----------------------- java helpers -----------------------

proc ::wb::exec::pathSep {} {
  if {$::tcl_platform(platform) eq "windows"} {return "\;"}
  return ":"
}

proc ::wb::exec::expandJavaPath {folders} {
  set sep [::wb::exec::pathSep]
  set cpEntries {}

  #hilite -red "safe=[interp issafe]"
  #hilite -red  "glob cmds=[info commands glob]"
  #hilite -red  "::glob cmds=[info commands ::glob]"

  foreach folder $folders {
    if {$folder eq ""} { continue }
    if {![file exists $folder]} { continue }
    if {![file isdirectory $folder]} { continue }

    set jarFiles {}
    foreach pat {*.jar *.zip} {
      foreach f [glob -nocomplain -directory $folder $pat] {
        if {[file isfile $f]} {
          lappend jarFiles $f
        }
      }
    }

    if {[llength $jarFiles] == 0} {
      lappend cpEntries $folder
      continue
    }

    set jarFiles [lsort -unique $jarFiles]

    set sortable {}
    foreach f $jarFiles {
      lappend sortable [list [file mtime $f] $f]
    }

    set sortable [lsort -command ::wb::exec::_compareMtimePathPairs $sortable]

    foreach item $sortable {
      lappend cpEntries [lindex $item 1]
    }
  }

  return [join $cpEntries $sep]
}

proc ::wb::exec::_compareMtimePathPairs {a b} {
  set ta [lindex $a 0]
  set tb [lindex $b 0]
  if {$ta > $tb} { return -1 }
  if {$ta < $tb} { return 1 }

  set pa [lindex $a 1]
  set pb [lindex $b 1]
  return [string compare $pa $pb]
}


# -------------- external program management
proc ::wb::exec::manageApp {bStart task str} {
  set path [file join [$task taskDir] $str]
  hilite -cyan "manageApp $str $path"
  if (!$bStart) {source $path} ;# We try to stop previous load. Will still be loaded for startApp
  set ctx [::wbobj::buildCtx $task]
  if {$bStart} {
     ::wb::exec::sync::startApp $ctx
    } else {
     ::wb::exec::sync::stopApp $ctx
    }
}

