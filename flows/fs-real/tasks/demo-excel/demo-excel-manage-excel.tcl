# demo-excel-manage-excel.tcl
#
# Generated 2026-jul-22 courtesy of Claude (claude.ai). Adapted from
# cit-fin's start-excel.tcl (v8), which itself documents a hard-won
# lesson: detached "cmd /c start" launch + pidfile-based stop is the
# pattern that actually works from wish.exe -- synchronous exec/capture
# of a PowerShell child does not, reliably. This script follows the same
# proven shape rather than reinventing it.
#
# tcl-int call signature

puts stderr "==> Loading demo-excel-manage-excel.tcl (v1)"
namespace eval ::wb::exec::sync {}


proc ::wb::exec::sync::startApp {ctx} {
  set task [$ctx task]
  hilite -magenta "startApp called task=$task"

  set arg [$task findArg excel]
  hilite -magenta "startApp called arg=$arg"
  if {$arg ne "" && ![$arg value]} {return}

  # Sheet selected based on the "what" option, mirroring PSEC's
  # startApplicationProgram switch. UNVERIFIED against real output --
  # confirm these sheet names match DemoExcel.java's actual output.
  set whatObj [$task findArg "Run what"]
  set pidFile [file join [$task taskDir] "exec-pid-file.txt"]

  hilite -magenta "startApp called what=$whatObj pidFile=$pidFile"

  file delete -force $pidFile

  set sheet ""
  set what [[$task findArg "Run what"] value]
  switch -- $what {
    basic   { set sheet "formats" }
    cloner  { set sheet "cloned" }
    chart   { set sheet "chart" }
    regress { set sheet "index" }
    hello   { set sheet "sample-sales" }
    default { set sheet "" }
  }
  if {$sheet eq ""} {
    hilite -magenta "startApp rejected: no sheet mapping for what=$what sheet=$sheet"
    return ""
  }

  set name "[$ctx getGlob ~taskPath]/out-docs/demo-excel.xlsx"

  set scriptDir [$ctx scriptDir]


  set ps1 [file join $scriptDir ".." "shims" "excel-start.ps1"]
  hilite -magenta "startApp called for [$task name] $name shim=$ps1"

  if {[catch {
     exec cmd /c start powershell -NoProfile -ExecutionPolicy Bypass -File $ps1 -Path $name -Sheet $sheet -PidFile $pidFile
  } err opts]} {
    hilite -red "startApplicationProgram failed: $err"
    return ""
  }
}

# If the pidFile exists the function tries to stop the Excel program.

proc ::wb::exec::sync::stopApp {ctx} {
  set task [$ctx task]

  set pidFile [file join [$task taskDir] "exec-pid-file.txt"]
  hilite -magenta "stopApp called for [$task name] pidFile=$pidFile"

  if {[file exists $pidFile]} {
    set fh [open $pidFile r]
    set pid [string trim [read $fh]]
    close $fh

    if {$pid ne ""} {
    if {[catch {
        package require twapi

        if {![twapi::process_exists $pid -name "EXCEL.EXE"]} {
            hilite -red "Excel pid=$pid is not running"
        } else {
            set ended [twapi::end_process $pid -force -wait 5000 -exitcode 1]
            if {$ended} {
                hilite -cyan "Stopped Excel pid=$pid"
            } else {
                hilite -red "Excel pid=$pid did not stop"
            }
        }
    } err]} {
        hilite -red "Failed to stop Excel pid=$pid : $err"
    }
  }

    file delete -force $pidFile
  } else {
    hilite -red "Pid file not found: <$pidFile>"
  }
}

