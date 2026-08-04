# fs-run.tcl
# Code generated on 2026-Mar-15 19:33  courtesy of chatGPT
#
# Parse a flow config JSON and populate the GUI with specified steps.
#
# Changelog (skinny; full detail in CHANGELOG.md):
#   v117 (2026-aug-03): new checkTaskRuntime -- verifies a task's engine runtime is present before the task is run, surfaced as a setupErr at selection time (renderTask), same mechanism as the existing "hooks required but not found" check; java branch checks $env(JAVA_HOME)/bin/java(.exe), same lookup ::wb::exec::handleJavaASync already uses to launch it (fs-exec.tcl v6); designed as an $ttype routing table for future python/csharp/node branches, mirroring prepTaskExec's own routing table
#   v116 (2026-aug-01): added ~flowPath (flow load) and ~taskPath (task switch) to the live Globs object (not dynData, which eval:[glob ...] never actually reads) -- makes eval:[glob ~flowPath]/... and eval:[glob ~taskPath]/... work in any parm; "~" prefix keeps both out of persistence and the user-facing globs list
#   v115 (2026-aug-01): disabled applyOptsDictToTask's pre-existing forceOff mechanism -- it silently zeroed a just-clicked manual-task checkbox on every visit, since ANY click through the UI (not just hand-editing options.json) makes it newer than brief.json; superseded by the staleRefTS-based reset (v113/v114)
#   v114 (2026-aug-01): stale-manual-checkbox reset (v113) now guarded by staleRefTS -- won't clobber a user's in-progress re-checking; uses refreshStepStates' actual freshness high-water mark, not "the immediately preceding task", since flows can skip steps
#   v113 (2026-aug-01): manual tasks' checkboxes auto-reset (live control + options.json) when the task becomes current while STALE -- completes a stub that was previously scaffolded but disabled ("&& 0") in refreshStepStates
#   v112 (2026-jul-29): renamed bindVal -> custVal (needHooks scan, hook invocation, error messages) -- see CHANGELOG.md for why
#   v111 (2026-jul-29): corrected v110 -- fsCfgLoad is now mandatory/hard-fail (v110 wrongly made it soft/best-effort); one source of truth, no silent degradation
#   v110 (2026-jul-29): fixed the Runner never calling fsCfgLoad at boot -- every fsCfgGet lookup here (home.dir included) has always silently returned ""
#   v109 (2026-jul-28): added tipAttachDynamic/tipOnEnterDynamic -- a live-value tooltip variant, used by fs-objs.tcl's file/directory controls
#   v108 (2026-jul-28): fixed onViewArgValues ("Arg Values" 3-bar viewer) joining lines with a space instead of "\n" -- everything ran onto one line
#   v107 (2026-jul-28): changelog moved to CHANGELOG.md; this header now a skinny per-version log
#   v106 (2026-jul-21): removed a dead duplicate ::wb::run::onRunTaskClick -- a bare, older definition with none of the v99+ dependsOn-aware...
#   v105 (2026-jul-20): fixed staleAfter (v104) not propagating -- task 1 correctly flipped STALE, but task 2 onward kept coming out fresh anyway
#   v104 (2026-jul-20): added staleAfter -- optional per-task "nnn[unit]" cfg.json field, enforced on task 1 only
#   v103 (2026-jul-20): logs window pixel size on resize (debounced, size-change-only, not on pure moves) into the same console panel "Switched to...
#   v102 (2026-jul-18): package require Tk 8.6 -> Tk 8.6 9, so this loads under either Tcl/Tk 8.6 or 9.x
#   v101 (2026-jul-18): "blocked" formalized as its own named state: a task cannot be run because a task it names in dependsOn is not currently GOOD ...
#   v100 (2026-jul-18): added a dedicated "blocked" icon for a dependsOn-gated task whose dependency isn't satisfied
#   v99 (2026-jul-18): added dependsOn runnability gating -- mirror image of v96/v97's whenFail visibility gating, using the same watcher/watched...
#   v98 (2026-jul-18): fixed a real bug Steve hit testing v97's whenFail gating -- remedial-action stayed visible after check-status recovered to GOOD
#   v97 (2026-jul-18): CORRECTED v96 -- had the gating direction backwards. whenFail holds the name of an earlier "watched" task
#   v96 (2026-jul-18): implemented real whenFail gating -- this was previously just tooltip metadata (see the removed "For now: show ALL steps...
#   v95 (2026-jul-17): main window icon lookup switched from $::env(TCL_HOME) to [fsCfgGet home.dir], matching the path-resolution convention used...
#   v36: replace treeview with grid rows; icon-only coloring; widen icon column
#   v21: first working config loader + GUI populate + XBM icons embedded correctly as strings
#
# Usage:
#   tclsh fs-run.tcl  <cfgPath>
#
# Example:
#   tclsh fs-run.tcl  $::env(TCL_FLOWS)/psec-demo/psec-demo-cfg.json

# ================================================================
# WORKBENCH FILE SYSTEM CONTRACT
#
# ALL runtime files are rooted at $env(TCL_FLOWS)
#
# 1) Global files (shared across all flows):
#    $env(TCL_FLOWS)/
#        wb-parms-palate.json
#        wb-parms-palate-tmp.json
#
# 2) Flow files:
#    $env(TCL_FLOWS)/flows/<flow-name>/
#        <flow-name>-cfg.json
#
# 3) Step (task) files:
#    $env(TCL_FLOWS)/flows/<flow-name>/tasks/<task-name>/
#        options.json
#        parms.json
#        brief.json
#
# "flows" and "tasks" are constant directory names.
#
# No WB file logic may assume runtime paths relative to script location.
# Everything derives from $env(TCL_FLOWS).
# ================================================================


set ::FS_RUN_VERSION 117
# wb-run: runtime procs live in ::wb::run
puts stderr "==> Loading fs-run.tcl (v$::FS_RUN_VERSION)"


package require Tk 8.6 9
set __fs_objs [file join [file dirname [info script]] fs-objs.tcl]
puts stderr "==> Sourcing [file tail $__fs_objs]"
source $__fs_objs

# Optional: option/ExecArg helpers
catch {source [file join [file dirname [info script]] fs-opts.tcl]}
# Additional modules (options + json pretty helpers)
set __fs_opts [file join [file dirname [info script]] fs-opts.tcl]
if {[file exists $__fs_opts]} {
  puts stderr "==> Sourcing [file tail $__fs_opts]"
  source $__fs_opts
}
set __fs_lib [file join [file dirname [info script]] tcl-lib.tcl]
if {[file exists $__fs_lib]} {
  puts stderr "==> Sourcing [file tail $__fs_lib]"
  source $__fs_lib

  # Load flowsmithy.cfg -- mandatory, blows up if not found. Matches
  # fs-cfg.tcl and fs-new.tcl exactly: flowsmithy.cfg is the ONE source
  # of truth for FlowSmithy settings (home.dir, flows.dir, ...); there is
  # no fallback to environment variables or any other source if it can't
  # be located. fs-run.tcl never called fsCfgLoad at all until this fix,
  # which meant every fsCfgGet lookup in the Runner (home.dir included)
  # always silently returned "" -- see CHANGELOG.md v110. An earlier
  # version of this fix made the call soft (catch + warning, keep running
  # without it) on the theory that this file already tolerates a missing
  # tcl-lib.tcl gracefully; that was wrong -- degrading silently is
  # exactly the multiple-sources-of-truth problem this is meant to close.
  # Hard call, no catch: if flowsmithy.cfg can't be found or read, the
  # Runner fails immediately and says so, the same way the Configurator
  # already does.
  fsCfgLoad
}

set __fs_help [file join [file dirname [info script]] fs-help.tcl]
if {[file exists $__fs_help]} {
  puts stderr "==> Sourcing [file tail $__fs_help]"
  source $__fs_help
}

set __fs_exec [file join [file dirname [info script]] fs-exec.tcl]
if {[file exists $__fs_exec]} {
  puts stderr "==> Sourcing [file tail $__fs_exec]"
  source $__fs_exec
}


# ===============================================================================
#-=vars                      Variables Used in fs-run.tcl
# ===============================================================================
namespace eval ::wb::run {
  variable UI_BUILDING 0
  variable RENDERING 0

  variable genDir ""
  variable fileDateRegSys 0
  variable dynSaveAfterId ""
  variable dynSections
  array set dynSections {}
  variable tipAfterId ""
  variable tipWin ""
  variable tipText ""
  variable tipXY {0 0}

  variable runBusy 0
  variable curIndex 0
  variable oldTask ""

  variable bKillRun false

  variable scriptDir;
  variable iconCache {}
}

proc ::wb::run::dynPathForCfg {cfgPath} {
  set dir [file dirname $cfgPath]
  set base [file tail $cfgPath]
  if {[string match "*-cfg.json" $base]} {
    set stem [string range $base 0 [expr {[string length $base]-[string length "-cfg.json"]-1}]]
  } else {
    set stem [file rootname $base]
  }
  return [file join $dir "${stem}-dyn.json"]
}

# Return the current run-mode value of an option UI control.
# In run-mode, wb-run stores control state in ::wb::ui(optVar,$seq,$label).
proc ::wb::run::uiCtlValue {seq label} {
  set vname "::wb::run::ui(optVar,$seq,$label)"
  if {[info exists $vname]} {
    return [set $vname]
  }
  return ""
}

proc ::wb::run::addDynSection {sectName d} {
  variable dynData
  variable dynSections
  set dynSections($sectName) $d
  if {$dynData eq ""} { set dynData [dict create] }
  dict set dynData $sectName $d
  return $d
}

proc ::wb::run::fetchDynData {} {
  variable dynData
  if {$dynData eq ""} { return [dict create] }
  return $dynData
}

proc ::wb::run::argPathModeVar {argObj} {
  return "::wb::argPathMode([$argObj hash])"
}

proc ::wb::run::argHistoryKey {argObj} {
  set uiType ""
  set histTag ""
  catch { set uiType [$argObj uiType] }
  catch { set histTag [$argObj histTag] }
  if {$histTag eq ""} { return "" }
  return "${uiType}:${histTag}"
}

proc ::wb::run::argHistoryValues {argObj} {
  set key [::wb::run::argHistoryKey $argObj]
  if {$key eq ""} { return {} }
  set d [::wb::run::fetchDynData]
  if {![dict exists $d uiHistory $key]} { return {} }
  set vals [dict get $d uiHistory $key]
  if {[catch {llength $vals}]} { return {} }
  return $vals
}

proc ::wb::run::_argHistoryDepth {argObj} {
  set depth 20
  catch { set depth [$argObj histDepth] }
  if {![string is integer -strict $depth] || $depth < 1} { set depth 20 }
  return $depth
}

proc ::wb::run::_argHistoryRemember {argObj value} {
  set value [string trim $value]
  if {$value eq ""} { return {} }

  set key [::wb::run::argHistoryKey $argObj]
  if {$key eq ""} { return {} }

  set depth [::wb::run::_argHistoryDepth $argObj]
  set hist [::wb::run::argHistoryValues $argObj]

  set out [list $value]
  foreach item $hist {
    if {$item eq ""} { continue }
    if {$item ne $value} { lappend out $item }
  }
  set out [lrange $out 0 [expr {$depth - 1}]]

  set dyn [::wb::run::fetchDynData]
  set sect [expr {[dict exists $dyn uiHistory] ? [dict get $dyn uiHistory] : [dict create]}]
  dict set sect $key $out
  ::wb::run::addDynSection uiHistory $sect
  return $out
}

proc ::wb::run::_argFileTypes {argObj} {
  set spec ""
  catch { set spec [$argObj fileType] }
  set spec [string trim $spec]
  if {$spec eq ""} { return {} }

  set pats {}
  foreach raw [split $spec ";"] {
    set pat [string trim $raw]
    if {$pat ne ""} { lappend pats $pat }
  }
  if {![llength $pats]} { return {} }

  return [list [list "Selected Files" $pats] [list "All Files" *]]
}

proc ::wb::run::_updateCombosForVar {root vname vals} {
  foreach child [winfo children $root] {
    if {[winfo class $child] eq "TCombobox"} {
      if {![catch {$child cget -textvariable} tv] && $tv eq $vname} {
        set cur [set $vname]
        set comboVals {}
        if {$cur ne ""} { lappend comboVals $cur }
        foreach item $vals {
          if {$item eq ""} { continue }
          if {[lsearch -exact $comboVals $item] < 0} { lappend comboVals $item }
        }
        $child configure -values $comboVals
      }
    }
    ::wb::run::_updateCombosForVar $child $vname $vals
  }
}

proc ::wb::run::argBrowsePath {argObj vname} {
  if {[info commands $argObj] eq ""} { return }
  set uiType ""
  catch { set uiType [$argObj uiType] }

  set current ""
  if {[info exists $vname]} { set current [string trim [set $vname]] }

  if {$uiType eq "file"} {
    set args [list]
    if {$current ne ""} {
      set currentDir [file dirname $current]
      if {[file isdirectory $currentDir]} {
        lappend args -initialdir $currentDir
      }
      if {[file tail $current] ne ""} {
        lappend args -initialfile [file tail $current]
      }
    }
    set ftypes [::wb::run::_argFileTypes $argObj]
    if {[llength $ftypes]} { lappend args -filetypes $ftypes }
    set chosen [uplevel #0 [list tk_getOpenFile {*}$args]]
  } elseif {$uiType eq "directory"} {
    set args [list]
    if {$current ne "" && [file isdirectory $current]} {
      lappend args -initialdir $current
    } elseif {$current ne ""} {
      set currentDir [file dirname $current]
      if {[file isdirectory $currentDir]} { lappend args -initialdir $currentDir }
    }
    set chosen [uplevel #0 [list tk_chooseDirectory {*}$args]]
  } else {
    return
  }

  if {$chosen eq ""} { return }

  set $vname $chosen
  ::wb::run::argPathAccept $argObj $vname
}

proc ::wb::run::argPathAccept {argObj vname} {
  if {[info commands $argObj] eq ""} { return }
  if {![info exists $vname]} { return }

  set value [string trim [set $vname]]
  set uiType ""
  catch { set uiType [$argObj uiType] }

  if {$value ne ""} {
    set okForHist 1
    if {$uiType eq "file"} {
      if {![file exists $value] || [file isdirectory $value]} { set okForHist 0 }
    } elseif {$uiType eq "directory"} {
      if {![file isdirectory $value]} { set okForHist 0 }
    }

    if {$okForHist} {
      set vals [::wb::run::_argHistoryRemember $argObj $value]
      ::wb::run::_updateCombosForVar . $vname $vals
    }
  }

  catch {$argObj setValue $value}
  set t ""; catch { set t [$argObj task] }
  ::wb::run::saveDynNow
  if {$t ne ""} { ::wb::run::persistOptsNow $t }
}

proc ::wb::run::argPathFocusOut {argObj vname} {
  after idle [list ::wb::run::argPathAccept $argObj $vname]
}



proc ::wb::run::loadDyn {} {
  variable form
  variable dynPath
  variable dynData
  variable dynSections
  catch {array unset dynSections *}
  array set dynSections {}

  set cfgPath [::wb::run::formCfgPath]
  set dynPath [::wb::run::dynPathForCfg $cfgPath]

  if {![file exists $dynPath]} {
    log "new $dynPath created"
    set dynData [dict create]
    ::wb::run::dynEnsureGlobs
    return $dynData
  }

  if {[catch {set d [jsonFileAsDict $dynPath]} perr]} {
    ::wb::run::logMsg "WARN: could not parse dyn JSON: $dynPath ($perr)"
    error "terminated because of malformed $dynpath"
  }
  set dynData $d
  if {[dict exists $dynData uiHistory]} {
    set dynSections(uiHistory) [dict get $dynData uiHistory]
  }
  ::wb::run::dynEnsureGlobs
  log "sucessfully loaded $dynPath"
  return $dynData
}


# Center a toplevel window on the screen.
proc ::wb::run::centerWindow {w} {
  update idletasks
  set sw [winfo screenwidth  $w]
  set sh [winfo screenheight $w]
  set ww [winfo width  $w]
  set wh [winfo height $w]
  if {$ww <= 1 || $wh <= 1} {
    # fallback to requested size if not yet mapped
    set ww [winfo reqwidth  $w]
    set wh [winfo reqheight $w]
  }
  set x [expr {($sw - $ww) / 2}]
  set y [expr {($sh - $wh) / 3}]
  wm geometry $w +$x+$y
}

proc ::wb::run::dynGetWinSize {} {
  variable dynData
  if {$dynData eq ""} { return "" }
  if {![dict exists $dynData winsize]} { return "" }
  return [dict get $dynData winsize]
}

proc ::wb::run::dynGetActiveTask {} {
  variable dynData
  if {$dynData eq ""} { return "" }
  if {![dict exists $dynData activeTask]} { return "" }
  return [dict get $dynData activeTask]
}

proc ::wb::run::dynGetSplitW {} {
  variable dynData
  if {$dynData eq ""} { return "" }
  if {![dict exists $dynData splitW]} { return "" }
  return [dict get $dynData splitW]
}


proc ::wb::run::dynEnsureGlobs {} {
  # Ensure dynData has a globs dict and always populate $flowLocn from cfgPath folder.
  variable form
  variable dynData

  if {$dynData eq ""} { set dynData [dict create] }
  if {![dict exists $dynData globs]} { dict set dynData globs [dict create] }

  set g [dict get $dynData globs]
  set flowPath [file dirname [::wb::run::formCfgPath]]
  dict set g "\~flowPath" $flowPath
  dict set dynData globs $g
  #log "globs initial $g"
}

# Expand (dollar-brace-key) tokens using dynData(globs). Missing keys become ?key?
# Note: evaluated at runtime whenever the task panel refreshes.
proc ::wb::run::expandGlobs {s} {
  ::wb::run::dynEnsureGlobs
  variable dynData

  # Simple, brace-safe scanner (no regexp); expands (dollar-brace-key)
  set out ""
  set i 0
  set n [string length $s]
  while {1} {
    set start [string first "\${" $s $i]
    if {$start < 0} {
      append out [string range $s $i end]
      break
    }
    # copy text before token
    append out [string range $s $i [expr {$start-1}]]
    set endb [string first "}" $s [expr {$start+2}]]
    if {$endb < 0} {
      # no closing brace; treat remainder literally
      append out [string range $s $start end]
      break
    }
    set key [string range $s [expr {$start+2}] [expr {$endb-1}]]
    if {$dynData ne "" && [dict exists $dynData globs $key]} {
      set rep [dict get $dynData globs $key]
    } else {
      set rep "?$key?"
    }
    append out $rep
    set i [expr {$endb+1}]
    if {$i >= $n} { break }
  }
  return $out
}





# --- simple tooltip ("hint") support ------------------------------------------
# Usage:
#   ::wb::run::tipAttach <widget> "text"

proc ::wb::run::tipAttach {w text} {
  bind $w <Enter>  [list ::wb::run::tipOnEnter $w $text %X %Y]
  bind $w <Leave>  [list ::wb::run::tipOnLeave]
  bind $w <Motion> [list ::wb::run::tipOnMotion %X %Y]
}

# Like tipAttach, but for a widget whose displayed text can change after
# the tooltip is attached (e.g. an editable combobox bound via
# -textvariable). Re-reads varName fresh on every <Enter> instead of
# baking in a snapshot at attach time, so the tooltip always reflects
# what's actually in the field right now -- e.g. a full untruncated path
# in a narrow file/directory combobox. varName must be a fully-qualified
# variable name (e.g. ::wb::argVal(hash)), same convention as -textvariable.
proc ::wb::run::tipAttachDynamic {w varName} {
  bind $w <Enter>  [list ::wb::run::tipOnEnterDynamic $w $varName %X %Y]
  bind $w <Leave>  [list ::wb::run::tipOnLeave]
  bind $w <Motion> [list ::wb::run::tipOnMotion %X %Y]
}

proc ::wb::run::tipOnEnterDynamic {w varName X Y} {
  set text ""
  catch { set text [set $varName] }
  if {$text eq ""} { return }
  ::wb::run::tipOnEnter $w $text $X $Y
}

proc ::wb::run::tipOnEnter {w text X Y} {
  variable tipAfterId
  variable tipText
  variable tipXY
  set tipText $text
  set tipXY [list $X $Y]
  catch {after cancel $tipAfterId}
  set tipAfterId [after 500 [list ::wb::run::tipShow]]
}

proc ::wb::run::tipOnLeave {} {
  variable tipAfterId
  catch {after cancel $tipAfterId}
  set tipAfterId ""
  ::wb::run::tipHide
}

proc ::wb::run::tipOnMotion {X Y} {
  variable tipXY
  set tipXY [list $X $Y]
}

proc ::wb::run::tipShow {} {
  variable tipWin
  variable tipText
  variable tipXY
  if {$tipText eq ""} { return }

  if {$tipWin eq "" || ![winfo exists $tipWin]} {
    set tipWin .wbTip
    catch {destroy $tipWin}
    toplevel $tipWin -bd 1 -relief solid
    wm overrideredirect $tipWin 1
    label $tipWin.l -text "" -background "#ffffe0" -foreground "black" -padx 6 -pady 3 -justify left
    pack $tipWin.l
  }

  $tipWin.l configure -text $tipText
  lassign $tipXY X Y
  set x [expr {$X + 12}]
  set y [expr {$Y + 18}]
  wm geometry $tipWin +$x+$y
  raise $tipWin
}

proc ::wb::run::tipHide {} {
  variable tipWin
  if {$tipWin ne "" && [winfo exists $tipWin]} {
    catch {destroy $tipWin}
  }
  set tipWin ""
}


proc ::wb::run::renderGlobsPanel {} {
  # Show non-$ globs in a one-line grid above Task:
  # - white background
  # - left label: "Globs:" in bold
  # - key in normal font, value in bold font
  variable ui
  variable form

  if {![info exists ui(globsFrame)]} { return }
  set f $ui(globsFrame)
  if {![winfo exists $f]} { return }

  # Clear previous cells
  foreach c [winfo children $f] { destroy $c }

  # Match Options panel background everywhere in this panel.
  set bg [ttk::style lookup WbOpts.TFrame -background]
  if {$bg eq ""} { set bg "#f3f5f7" }
  catch {$f configure -background $bg}

  set row 0
  set col 0

  # Left label
  label $f.hdr -text "Globs:" -anchor w -background $bg -font wbBold
  grid $f.hdr -row $row -column $col -sticky w -padx {8 10} -pady 4
  set col 1

  if {$form ne ""} {
    set globs [$form globs]
    set g [$globs dict]

    # Pleasant order: lexical by key (excluding $ keys)
    set keys {}
    foreach k [dict keys $g] {
      if {[string index $k 0] eq "~" || [string index $k 0] eq "+"} { continue }
      lappend keys $k
    }
    set keys [lsort -dictionary $keys]

    foreach k $keys {
      set v [dict get $g $k]

      # key/value pair in adjacent columns
      label $f.k$col -text "${k}:" -anchor w -background $bg
      label $f.v$col -text $v -anchor w -background $bg -font wbBold

      grid $f.k$col -row $row -column $col            -sticky w -padx {0 2}  -pady 4
      grid $f.v$col -row $row -column [expr {$col+1}] -sticky w -padx {0 14} -pady 4

      set col [expr {$col+2}]
    }
  } else {
    hilite -red "expected form object"
  }

  if {$col == 1} {
    # No visible globs: keep height but show nothing else
    label $f.ph -text "" -anchor w -background $bg
    grid $f.ph -row 0 -column 1 -sticky w -padx 0 -pady 4
    set col 2
  }

  for {set i 0} {$i < $col} {incr i} {
    grid columnconfigure $f $i -weight 0
  }
}

proc ::wb::run::rebuildMainMenu {} {
  variable ui

  if {[info exists ui(mainMenu)]} {
    catch {destroy $ui(mainMenu)}
    unset ui(mainMenu)
  }

  ::wb::run::ensureMainMenu
}

proc ::wb::run::ensureMainMenu {} {
  variable ui
  if {[info exists ui(mainMenu)] && [winfo exists $ui(mainMenu)]} { return }

  # Create a single shared menu
  set m .wbMainMenu
  catch {destroy $m}
  menu $m -tearoff 0
  $m add command -label "View Globs" -command {::wb::run::onViewGlobs}
  $m add command -label "Arg Values" -command {::wb::run::onViewArgValues}
  $m add command -label "View Task"  -command {::wb::run::onViewTask}
  set task [::wb::run::curTaskObj]
  if {$task ne ""} {
    set ttype [$task type]
    if {$ttype eq "java"} {
      $m add command -label "Java Props"  -command {::wb::run::onViewJavaProps}
    }

    set runprops [$task runprops]
    if {$runprops ne ""} {
      $m add command -label "Run Props"  -command {::wb::run::onViewRunProps}
    }

  }
  $m add command -label "-----------"
  #$m add command -label "< Restart >"  -command {exit 77}
  $m add command -label "< Restart >" -command {
    puts stderr "WB about to exit 77"
    flush stderr
    ::exit 77
  }
  set ui(mainMenu) $m
}

proc ::wb::run::onMenuClick {X Y} {
  ::wb::run::ensureMainMenu
  variable ui
  if {![info exists ui(mainMenu)]} { return }
  tk_popup $ui(mainMenu) $X $Y
}

proc ::wb::run::onViewGlobs {} {
  variable form
  ::wb::run::dynEnsureGlobs

  set w .wbGlobs
  if {[winfo exists $w]} {
    raise $w
    focus $w
  } else {
    toplevel $w
  }

  # Title: "xxx WorkBench Globs Table"
  set flowName ""
  if {[info exists ::wb::run::form] && $::wb::run::form ne "" && [dict exists $::wb::run::form flowName]} {
    set flowName [dict get $::wb::run::form flowName]
  }
  if {$flowName eq ""} { set flowName "Flow" }

  wm title $w "$flowName WorkBench Globs Table"

  set winW 960
  set winH 620
  wm geometry $w ${winW}x${winH}

  catch {destroy $w.outer}

  ttk::frame $w.outer -padding 10
  pack $w.outer -fill both -expand 1

  canvas $w.outer.c \
    -highlightthickness 0 \
    -yscrollcommand [list $w.outer.vsb set]

  ttk::scrollbar $w.outer.vsb \
    -orient vertical \
    -command [list $w.outer.c yview]

  grid $w.outer.c   -row 0 -column 0 -sticky nsew
  grid $w.outer.vsb -row 0 -column 1 -sticky ns

  grid rowconfigure    $w.outer 0 -weight 1
  grid columnconfigure $w.outer 0 -weight 1

  ttk::frame $w.outer.c.f
  set innerWin [$w.outer.c create window 0 0 -anchor nw -window $w.outer.c.f]

  bind $w.outer.c.f <Configure> [list ::wb::run::globsScrollConfigure $w.outer.c $innerWin]

  bind $w.outer.c <Configure> [list $w.outer.c itemconfigure $innerWin -width %w]

  bind $w.outer.c.f <Configure> [list ::wb::run::globsScrollConfigure $w.outer.c $innerWin]

  bind $w.outer.c <Configure> [list $w.outer.c itemconfigure $innerWin -width %w]

  bind $w.outer.c   <MouseWheel> [list ::wb::run::globsMouseWheel $w.outer.c %D]
  bind $w.outer.c.f <MouseWheel> [list ::wb::run::globsMouseWheel $w.outer.c %D]


  set f $w.outer.c.f

  # Headers
  ttk::label $f.h1 -text "Key"   -font wbBold -anchor w
  ttk::label $f.h2 -text "Value" -font wbBold -anchor w

  grid $f.h1 -row 0 -column 0 -sticky ew -padx {0 12} -pady {0 6}
  grid $f.h2 -row 0 -column 1 -sticky ew -pady {0 6}

  grid columnconfigure $f 0 -weight 0
  grid columnconfigure $f 1 -weight 1

  # Rows
  set g [dict create]
  if {$form ne ""} {
    set globs [$form globs]
    set g [$globs dict]
  }

  set keys [lsort -dictionary [dict keys $g]]
  set r 1

  foreach k $keys {
    set v [dict get $g $k]

    # Hidden keys ($...) still shown here; they are just hidden from the one-line panel.
    set keyStyle TLabel
    set valStyle TLabel

    if {[string match "\$*" $k]} {
      # Dim hidden keys
      catch {ttk::style configure Wb.Hidden.TLabel -foreground "#777777"}
      set keyStyle Wb.Hidden.TLabel
      set valStyle Wb.Hidden.TLabel
    }

    ttk::label $f.k$r -text $k -style $keyStyle -anchor w
    ttk::label $f.v$r -text $v -style $valStyle -anchor w

    grid $f.k$r -row $r -column 0 -sticky w  -padx {0 12} -pady 2
    grid $f.v$r -row $r -column 1 -sticky ew -pady 2

    incr r
  }

  if {$r == 1} {
    ttk::label $f.none -text "(no globs set yet)" -anchor w
    grid $f.none -row 1 -column 0 -columnspan 2 -sticky w
  }

  ::wb::run::centerWindow $w
}

proc ::wb::run::globsScrollConfigure {canvas innerWin} {
  $canvas configure -scrollregion [$canvas bbox all]
}

proc ::wb::run::globsMouseWheel {canvas delta} {
  $canvas yview scroll [expr {-$delta / 120}] units
}


proc ::wb::run::curTaskObj {} {
  variable curIndex
  set tasks [::wb::run::_tasks]
  if {$curIndex < 0 || $curIndex >= [llength $tasks]} { return "" }
  return [lindex $tasks $curIndex]
}

proc ::wb::run::curTaskTitle {} {
  set t [::wb::run::curTaskObj]
  if {$t eq ""} { return "Task" }

  set ttl [::wb::run::_taskField $t title ""]
  if {$ttl eq ""} { set ttl [::wb::run::_taskField $t name ""] }
  if {$ttl eq ""} { set ttl "Task" }
  return $ttl
}

proc ::wb::run::showTextWindow {w title textData {winW 980} {winH 640} {wrap word}} {
  catch {destroy $w}

  toplevel $w
  wm title $w $title
  wm geometry $w ${winW}x${winH}

  ttk::frame $w.top
  ttk::frame $w.mid
  ttk::frame $w.bot

  pack $w.top -side top -fill x -padx 10 -pady 10
  pack $w.bot -side bottom -fill x -padx 10 -pady {0 10}
  pack $w.mid -side top -fill both -expand 1 -padx 10 -pady {0 10}

  ttk::label $w.top.t -text $title
  pack $w.top.t -side left -anchor w

  text $w.mid.txt -wrap $wrap
  ttk::scrollbar $w.mid.vsb -orient vertical   -command [list $w.mid.txt yview]
  ttk::scrollbar $w.mid.hsb -orient horizontal -command [list $w.mid.txt xview]

  $w.mid.txt configure \
    -yscrollcommand [list $w.mid.vsb set] \
    -xscrollcommand [list $w.mid.hsb set]

  grid $w.mid.txt -row 0 -column 0 -sticky nsew
  grid $w.mid.vsb -row 0 -column 1 -sticky ns
  if {$wrap eq "none"} {
    grid $w.mid.hsb -row 1 -column 0 -sticky ew
  }

  grid rowconfigure    $w.mid 0 -weight 1
  grid columnconfigure $w.mid 0 -weight 1

  $w.mid.txt delete 1.0 end
  $w.mid.txt insert end $textData
  $w.mid.txt configure -state disabled

  ttk::button $w.bot.copy  -text "Copy"  -command [list clipboard clear; clipboard append $textData]
  ttk::button $w.bot.close -text "Close" -command [list destroy $w]
  pack $w.bot.close -side right
  pack $w.bot.copy  -side right -padx 6

  ::wb::run::centerWindow $w

  raise $w
  focus $w
}

proc ::wb::run::onViewTask {} {
  set t [::wb::run::curTaskObj]
  if {$t eq ""} {
    ::wb::run::popup "View Task" "No task selected."
    return
  }

  set details [$t dumpStr {args}]
  set title "Task objects for: [::wb::run::curTaskTitle]"
  ::wb::run::showTextWindow .viewTask $title $details 980 640 word
}

proc ::wb::run::onViewArgValues {} {
  set t [::wb::run::curTaskObj]
  if {$t eq ""} {
    ::wb::run::popup "Arg Values" "No task selected."
    return
  }

  set lines {}
  foreach arg [$t args] {
    lappend lines {*}[$arg viewStr]
  }
  if {![llength $lines]} {
    set lines [list "(no args for this task)"]
  }

  set textData [join $lines "\n"]
  ::wb::run::showTextWindow .wbArgValues "[::wb::run::curTaskTitle]: Arg Values" $textData 760 420 none
}

proc ::wb::run::onViewJavaProps {} {
  variable form
  set t [::wb::run::curTaskObj]
  if {$t eq ""} {
    ::wb::run::popup "Arg Values" "No task selected."
    return
  }

  set runprops [$t runprops]
  set javaMain [dict get $runprops javaMain]
  set cpTag    [dict get $runprops cpTag]

  set lines {}
  lappend lines ""
  lappend lines "main: $javaMain"
  lappend lines ""
  lappend lines "---------------- cpTag $cpTag resolved ---------------"
  set pathDict [$form paths]
  #log "paths $paths"
  set paths [dict get $pathDict $cpTag]
  set sep [::wb::exec::pathSep]
  set cpStr [::wb::exec::expandJavaPath $paths]
  hilite -cyan "paths $sep $cpStr"
  set parts [split $cpStr "$sep"]
  foreach path $parts {
    lappend lines "$path"
  }

  set textData [join $lines "\n"]
  ::wb::run::showTextWindow .wbArgValues "[::wb::run::curTaskTitle]: Java Path" $textData 760 420 none
}

proc ::wb::run::onViewRunProps {} {
  variable form
  set t [::wb::run::curTaskObj]
  if {$t eq ""} {
    ::wb::run::popup "RunProps" "No task selected."
    return
  }

  set runprops [$t runprops]
  set lines {}

  dict for {key value} $runprops {
    lappend lines "$key = $value"
  }


  set textData [join $lines "\n"]
  ::wb::run::showTextWindow .wbArgValues "[::wb::run::curTaskTitle]: Run Props" $textData 760 420 none
}


proc ::wb::run::dynCaptureFromUI {} {
  # Capture current window geometry + active task + split width
  variable form
  variable curIndex
  variable dynData

  # Window size
  update idletasks
  set w [winfo width .]
  set h [winfo height .]
  set x 100
  set y 100
  if {[winfo exists .]} {
    set x [winfo rootx .]
    set y [winfo rooty .]

    # TEMP bias to counter WM decoration offset. TODO - fix this later
    incr x -11
    incr y -45
  }

  if {$w <= 1 || $h <= 1} {
    # geometry not settled yet; fall back to req size
    set w [winfo reqwidth .]
    set h [winfo reqheight .]
  }

  # Ensure geometry is current


  set title [wm title .]

  # Set window icon from [fsCfgGet home.dir]/icons/fs-icon-R.ico
  set iconPath [file join [fsCfgGet home.dir] "icons" "fs-icon-R.ico"]
  log "Setting icon $iconPath $title"
  if {[file exists $iconPath]} {
    if {[catch {
      wm iconbitmap . $iconPath
    } err]} {
      log "set_icon failed: [lindex [split $err \n] 0]"
    }
  }


  dict set dynData winsize [dict create formW $w formH $h title $title topX $x topY $y]

  # Active task (by name)
  set tasks [::wb::run::_tasks]
  if {$curIndex >= 0 && $curIndex < [llength $tasks]} {
    set t [lindex $tasks $curIndex]
    dict set dynData activeTask [::wb::run::_taskField $t name ""]
  }

  # Split width (left pane width) from horizontal panedwindow sash
  if {[winfo exists .hpan]} {
    if {![catch {set sw [.hpan sashpos 0]}]} {
      dict set dynData splitW $sw
    }
  }
  return $dynData
}

proc ::wb::run::saveDynNow {} {
  variable dynPath
  variable dynData
  variable form

  if {$dynPath eq ""} { return }
  ::wb::run::dynCaptureFromUI

  # move globs table, drop those we do not persist
  set globs [$form globs];
  set dict [$globs dict]

  set newGlobs [dict create]

  dict for {k v} $dict {
    if {[string match "~*" $k]} { continue }
    dict set newGlobs $k $v
  }

  dict set dynData globs $newGlobs

  variable dynSections
  foreach sectName [array names dynSections] {
    dict set dynData $sectName $dynSections($sectName)
  }

  hilite -cyan "persist dynData ng=$newGlobs"

  # Use canonical JSON emitters from tcl-lib.tcl
  if {[catch {set json [dictToPrettyJsonStr $dynData wb-dyn]} jerr]} {
    error "dyn emit failed for $dynPath: $jerr"
  }
  # ensusaveDynNowre trailing newline
  append json "
"
  if {[catch {jsonStrAsFile $dynPath $json} err]} {
    ::wb::run::logMsg "WARN: could not write dyn file: $dynPath ($err)"
  }
}


proc ::wb::run::scheduleSaveDyn {} {
  variable dynSaveAfterId
  if {![info exists dynSaveAfterId]} { set dynSaveAfterId "" }

  variable dynSaveAfterId
  if {$dynSaveAfterId ne ""} { after cancel $dynSaveAfterId }
  # Debounce: coalesce rapid resize/sash motion into one write.
  set dynSaveAfterId [after 350 { set ::wb::run::dynSaveAfterId ""; ::wb::run::saveDynNow }]
}

# ---------------------------------------------------------------------------
# scheduleLogWindowSize / logWindowSizeNow
#
# Logs the window's pixel size (and how close it is to 16:9) into the same
# bottom console panel as "Switched to Step ..." -- via ::wb::run::logMsg,
# same timestamp format, same widget. Debounced the same way scheduleSaveDyn
# is, on its own separate timer -- a resize drag fires many <Configure>
# events per second, and without debouncing this would flood the log with
# one line per pixel of drag rather than one line once the drag settles.
#
# Only logs when the SIZE actually changed from what was last logged --
# <Configure> also fires on pure window MOVES (no size change), which
# would otherwise spam the log every time the window is merely dragged to
# a new position.
# ---------------------------------------------------------------------------
proc ::wb::run::scheduleLogWindowSize {} {
  variable logSizeAfterId
  if {![info exists logSizeAfterId]} { set logSizeAfterId "" }

  variable logSizeAfterId
  if {$logSizeAfterId ne ""} { after cancel $logSizeAfterId }
  set logSizeAfterId [after 350 { set ::wb::run::logSizeAfterId ""; ::wb::run::logWindowSizeNow }]
}

proc ::wb::run::logWindowSizeNow {} {
  variable lastLoggedW
  variable lastLoggedH
  if {![info exists lastLoggedW]} { set lastLoggedW -1 }
  if {![info exists lastLoggedH]} { set lastLoggedH -1 }

  set w [winfo width .]
  set h [winfo height .]

  # A pure move (no resize) also fires <Configure> -- skip logging if the
  # size itself didn't actually change.
  if {$w == $lastLoggedW && $h == $lastLoggedH} { return }
  set lastLoggedW $w
  set lastLoggedH $h

  if {$h == 0} { return } ;# guard divide-by-zero during initial window setup

  set ratio       [expr {double($w) / double($h)}]
  set targetRatio [expr {16.0 / 9.0}]
  set pctOff      [expr {abs($ratio - $targetRatio) / $targetRatio * 100.0}]

  ::wb::run::logMsg [format "Window resized: %dx%d (ratio %.3f:1, target 16:9=%.3f:1, %.1f%% off)" \
    $w $h $ratio $targetRatio $pctOff]
}

proc ::wb::run::applyDynToUI {} {
  variable form
  # window size & position
  set ws [::wb::run::dynGetWinSize]
  if {$ws ne ""} {
    if {[dict exists $ws formW] && [dict exists $ws formH]} {
      set w [dict get $ws formW]
      set h [dict get $ws formH]
      if {[string is integer -strict $w] && [string is integer -strict $h]} {
        wm geometry . "${w}x${h}"
      }
    }

    if {[dict exists $ws topX] && [dict exists $ws topY]} {
      set x [dict get $ws topX]
      set y [dict get $ws topY]
      if {[string is integer -strict $x] && [string is integer -strict $y]} {
        wm geometry . +$x+$y
      }
    }
  }

  # apply split width *after* geometry settles
  set sw [::wb::run::dynGetSplitW]
  if {$sw ne "" && [string is integer -strict $sw]} {
    after 25 [list ::wb::run::applySplitW $sw]
  }

  # active task selection is applied later (after step list is built)
}

proc ::wb::run::applySplitW {sw} {
  if {![winfo exists .hpan]} { return }
  if {![string is integer -strict $sw]} { return }
  catch {.hpan sashpos 0 $sw}
}

proc ::wb::run::dynSelectActiveTaskOrDefault {} {
  set nm [::wb::run::dynGetActiveTask]
  if {$nm ne ""} {
    set idx [::wb::run::findTaskIndexByName $nm]
    if {$idx >= 0} { ::wb::run::selectStep $idx; return }
  }
  # fallback: first task if any
  set tasks [::wb::run::_tasks]
  if {[llength $tasks] > 0} { ::wb::run::selectStep 0 }
}



proc ::wb::run::dynBindAutoSave {} {
  # Save on window resize and sash movement; also when selection changes (called in selectStep).
  bind . <Configure> { ::wb::run::scheduleSaveDyn; ::wb::run::scheduleLogWindowSize }

  if {[winfo exists .hpan]} {
    bind .hpan <ButtonRelease-1> { ::wb::run::scheduleSaveDyn }
    bind .hpan <B1-Motion>       { ::wb::run::scheduleSaveDyn }
  }
}

proc ::wb::run::logMsg {msg} {
  variable ui
  set ts [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
  set line "$ts  $msg"
  puts $line
  if {[info exists ui(logText)] && [winfo exists $ui(logText)]} {
    $ui(logText) configure -state normal
    $ui(logText) insert end $line\n
    $ui(logText) see end
    $ui(logText) configure -state disabled
  }
}


# Application Error window (always shows full details + Copy).
proc ::wb::run::appError {title details} {
  set w .appErr
  catch {destroy $w}
  toplevel $w
  wm title $w $title
  wm geometry $w 980x640

  ttk::frame $w.top
  pack $w.top -side top -fill x -padx 10 -pady 10
  ttk::label $w.top.t -text $title -font "TkDefaultFont 11 bold"
  pack $w.top.t -side left -anchor w

  ttk::frame $w.mid
  pack $w.mid -side top -fill both -expand 1 -padx 10 -pady {0 10}

  text $w.mid.txt -wrap word -height 24
  ttk::scrollbar $w.mid.sb -orient vertical -command [list $w.mid.txt yview]
  $w.mid.txt configure -yscrollcommand [list $w.mid.sb set]
  pack $w.mid.sb -side right -fill y
  pack $w.mid.txt -side left -fill both -expand 1

  $w.mid.txt insert end $details
  $w.mid.txt configure -state disabled

  ttk::frame $w.bot
  pack $w.bot -side bottom -fill x -padx 10 -pady {0 10}
  ttk::button $w.bot.copy -text "Copy" -command [list ::wb::run::copyToClipboard $details]
  ttk::button $w.bot.close -text "Close" -command [list destroy $w]
  pack $w.bot.close -side right
  pack $w.bot.copy  -side right -padx {0 8}
  ::wb::run::centerWindow $w
}

proc ::wb::run::copyToClipboard {s} {
  catch {clipboard clear}
  catch {clipboard append $s}
  log "copied error/details to clipboard"
}

# Route async Tk errors (eg, from 'after') into our error window.
proc ::bgerror {msg} {
  set details $msg
  catch {append details "\n\n[set ::errorInfo]"}
  ::wb::run::appError "Application Error" $details
}

proc ::wb::run::popup {title body} {
  variable popSeq
  set w .pop[incr popSeq]
  toplevel $w
  wm title $w $title
  ttk::frame $w.f -padding 10
  pack $w.f -fill both -expand 1
  ttk::label $w.f.l -text $body -justify left -wraplength 560
  pack $w.f.l -fill both -expand 1
  ttk::button $w.f.ok -text OK -command [list destroy $w]
  pack $w.f.ok -anchor e -pady 8
}

# Link hover + enabled/disabled (style-based)
proc ::wb::run::linkHover {w} {
  if {![winfo exists $w]} { return }
  bind $w <Enter> [list ::wb::run::onLinkEnter $w]
  bind $w <Leave> [list ::wb::run::onLinkLeave $w]
}

proc ::wb::run::linkSetEnabled {w enabled} {
  variable linkEnabled
  if {![winfo exists $w]} { return }
  set linkEnabled($w) $enabled
  if {$enabled} {
    $w configure -style Wb.Link.TLabel -cursor hand2
  } else {
    $w configure -style Wb.LinkDisabled.TLabel -cursor arrow
  }
}
proc ::wb::run::onLinkEnter {w} {
  variable linkEnabled
  if {![winfo exists $w]} { return }
  if {[info exists linkEnabled($w)] && !$linkEnabled($w)} { return }
  $w configure -style Wb.LinkHover.TLabel
}
proc ::wb::run::onLinkLeave {w} {
  variable linkEnabled
  if {![winfo exists $w]} { return }
  if {[info exists linkEnabled($w)] && !$linkEnabled($w)} { return }
  $w configure -style Wb.Link.TLabel
}


# Increase UI font sizes a bit so the left icons/text are easier to see.
proc ::wb::run::bumpUiFonts {{delta 2}} {
  # Derive from the default Tk font
  set base TkDefaultFont
  if {[catch {set fam [font actual $base -family]}]} { return }
  set sz [font actual $base -size]
  if {$sz < 0} { set sz [expr {-$sz}] } ;# handle negative sizes
  set newSz [expr {$sz + $delta}]
  catch {font create Wb.UiFont -family $fam -size $newSz}
  catch {ttk::style configure TLabel -font Wb.UiFont}
  catch {ttk::style configure TButton -font Wb.UiFont}
  catch {ttk::style configure TEntry -font Wb.UiFont}
  catch {ttk::style configure Treeview -font Wb.UiFont -rowheight [expr {($newSz*2)+6}]}
  catch {ttk::style configure Treeview.Heading -font Wb.UiFont}
}


proc ::wb::run::statusColor {status} {
  switch -exact -- $status {
    GOOD  { return "darkgreen" }
    STALE { return "darkgreen" }
    FAIL  { return "firebrick" }
    BLOCK { return "firebrick" }
    READY { return "darkorange3" }
    CONF  { return "darkorange3" }
    default { return "darkorange3" }
  }
}





# Update the stored task status (in ::wb::run::form) and refresh the step icon in the left tree.
proc ::wb::run::setTaskStatus {idx status} {
  variable ui

  set tasks [::wb::run::_tasks]
  if {$idx < 0 || $idx >= [llength $tasks]} { return }
  set t [lindex $tasks $idx]
  set seq [::wb::run::_taskField $t seq ""]
  if {$seq eq ""} { return }

  # Persist status in UI state (Form/Task objects remain SOT for config; status is runtime/UI state)
  if {![info exists ui(taskStatus)]} { set ui(taskStatus) [dict create] }
  dict set ui(taskStatus) $seq $status

}

# Config load
# Return a brief location string for a JSON parse error position
proc ::wb::run::jsonContext {raw pos} {
  if {$pos < 0} { set pos 0 }
  set n [string length $raw]
  if {$pos > $n} { set pos $n }

  set before ""
  if {$pos > 0} { set before [string range $raw 0 [expr {$pos-1}]] }

  set line [llength [split $before "\n"]]
  if {$line < 1} { set line 1 }

  set lastNL [string last "\n" $before]
  if {$lastNL < 0} { set col [expr {$pos+1}] } else { set col [expr {$pos-$lastNL}] }

  set s [expr {$pos-40}]
  if {$s < 0} { set s 0 }
  set e [expr {$pos+40}]
  if {$e > $n} { set e $n }

  set snippet [string range $raw $s $e]
  set snippet [string map [list "\n" " " "\r" " " "\t" " "] $snippet]
  return "line $line col $col near \"$snippet\""
}

proc ::wb::run::loadFlowConfig {cfgPath} {

  if {![file exists $cfgPath]} { error "Config not found: $cfgPath" }
  if {[catch {set cfg [jsonFileAsDict $cfgPath]} jerr]} {
    error "JSON parse failed in $cfgPath: $jerr"
  }
  if {[catch {dict size $cfg}]} {
    error "Config JSON top-level is not an object in $cfgPath"
  }
  return $cfg
}

proc ::wb::run::canRunCurrent {} {
  variable form
  variable curIndex
  variable runBusy
  variable bKillRun
  set tasks [::wb::run::_tasks]
  set t [lindex $tasks $curIndex]
  if {$bKillRun} {return 0}
  set seq [::wb::run::_taskField $t seq 0]
  if {$runBusy} { return 0 }
  # v96/v97: a gated whenFail-remedial task can't be run while hidden --
  # this should be unreachable via the UI (hidden tasks have no row/
  # binding to click), but guards against curIndex being left pointing at
  # one, e.g. right after the task it watches recovers to GOOD on a later
  # run, before refreshStepList's own reselect-fallback has run.
  if {![::wb::run::_taskIsVisible $t]} { return 0 }
  # v99: dependsOn gates RUNNABILITY (task stays visible/selectable) --
  # mirror of the whenFail visibility gate above, but for the opposite
  # direction: blocked until every named dependency is GOOD, not hidden.
  if {![::wb::run::_taskDependsSatisfied $t]} { return 0 }
  # manual tasks can only run under specific circumstances
  if {[$t type] eq "manual"} {return [$t canTaskRun]}
  return 1
}

proc ::wb::run::updateRunTaskLink {} {
  variable ui
  if {![info exists ui(runLink)]} { return }
  ::wb::run::linkSetEnabled $ui(runLink) [::wb::run::canRunCurrent]
}

# v105: removed a dead duplicate ::wb::run::onRunTaskClick that used to
# sit here -- a bare, older version (no dependsOn-aware disabled-reason
# messaging, no SR&ED _powLogAppend hook) that Tcl's "last definition
# wins" rule silently overrode with the real, maintained one further
# down in this file. Zero runtime effect either way, but a source
# reviewer finding two definitions of the same proc is a legitimate
# "does this codebase know what it's doing" red flag worth not shipping.

# View Log enable rule: enabled only if runlog.txt exists for current task
proc ::wb::run::canViewLogCurrent {} {
  variable curIndex
  variable ui

  set tasks [::wb::run::_tasks]
  if {![info exists curIndex]} { return 0 }
  if {$curIndex < 0 || $curIndex >= [llength $tasks]} { return 0 }
  set t [lindex $tasks $curIndex]

  set taskDir [::wb::run::_taskField $t taskDir ""]
  if {$taskDir eq ""} { return 0 }

  set logPath [::wb::run::_taskField $t logPath ""]
  if {$logPath eq "" || ![file exists $logPath]} { return 0 }

  return 1
}


proc ::wb::run::updateViewLogLink {} {
  variable ui
  if {![info exists ui(viewLogLink)]} { return }
  ::wb::run::linkSetEnabled $ui(viewLogLink) [::wb::run::canViewLogCurrent]
}

# --- Log window tracking per-task --------------------------------------------
# We store the current log window name in the task dict under key 'logWin'.
# This prevents duplicate windows and lets Run Task close any open log view.
proc ::wb::run::_isTclOOObj {v} {
  # True if $v is a TclOO object command
  if {$v eq ""} { return 0 }
  return [expr {![catch {info object class $v} _cls]}]
}

proc ::wb::run::formCfgPath {} {
  # Form is the single source of truth (SOT) and must be a TclOO object.
  variable form
  if {[catch {set p [$form cfgPath]} err]} {
    error "Form $form SOT missing required cfgPath method/value: $err"
  }
  if {$p eq ""} {
    error "Form SOT cfgPath is empty"
  }
  return $p
}


proc ::wb::run::_tasks {} {
  variable form
  if {[catch {set ts [$form tasks]} err]} {
    error "::wb::run::_tasks: form has no usable 'tasks' method: $err"
  }
  return $ts
}

proc ::wb::run::_taskField {t key {default ""}} {
  # Task objects are TclOO objects with per-field methods (seq/title/name/etc).
  if {0} {
    if {![::wb::run::_isTclOOObj $t]} {
      error "::wb::run::_taskField: task is not a TclOO object: <$t>"
    }
    if {![catch {$t $key} v]} { return $v }
    return $default
  }
  #log "taskField  $t $key"
  return [$t $key]
}


proc ::wb::run::taskStatusGet {seq {default "WAIT"}} {
  variable ui
  if {[info exists ui(taskStatus)] && [dict exists $ui(taskStatus) $seq]} {
    return [dict get $ui(taskStatus) $seq]
  }
  return $default
}

proc ::wb::run::findTaskIndexByName {taskName} {
  set tasks [::wb::run::_tasks]
  for {set i 0} {$i < [llength $tasks]} {incr i} {
    set t [lindex $tasks $i]
    if {[::wb::run::_taskField $t name ""] eq $taskName} { return $i }
  }
  return -1
}




proc ::wb::run::focusLogWinIfOpen {idx} {
  variable ui
  set tasks [::wb::run::_tasks]
  if {$idx < 0 || $idx >= [llength $tasks]} { return 0 }
  set t [lindex $tasks $idx]
  set seq [::wb::run::_taskField $t seq ""]
  if {$seq eq ""} { return 0 }

  if {[info exists ui(logWinBySeq)] && [dict exists $ui(logWinBySeq) $seq]} {
    set w [dict get $ui(logWinBySeq) $seq]
    if {$w ne "" && [winfo exists $w]} {
      catch {raise $w}
      catch {focus -force $w}
      return 1
    }
  }
  return 0
}


proc ::wb::run::closeLogWinIfOpen {idx} {
  variable ui
  set tasks [::wb::run::_tasks]
  if {$idx < 0 || $idx >= [llength $tasks]} { return }
  set t [lindex $tasks $idx]
  set seq [::wb::run::_taskField $t seq ""]
  if {$seq eq ""} { return }

  if {[info exists ui(logWinBySeq)] && [dict exists $ui(logWinBySeq) $seq]} {
    set w [dict get $ui(logWinBySeq) $seq]
    if {$w ne "" && [winfo exists $w]} { catch {destroy $w} }
    dict set ui(logWinBySeq) $seq ""
  }
}


proc ::wb::run::onLogWinClosed {taskName w} {
  variable ui
  set idx [::wb::run::findTaskIndexByName $taskName]
  if {$idx >= 0} {
    set tasks [::wb::run::_tasks]
    set t [lindex $tasks $idx]
    set seq [::wb::run::_taskField $t seq ""]
    if {$seq ne ""} {
      if {![info exists ui(logWinBySeq)]} { set ui(logWinBySeq) [dict create] }
      dict set ui(logWinBySeq) $seq ""
    }
    ::wb::run::updateViewLogLink
  }
  if {[winfo exists $w]} { destroy $w }
}



proc ::wb::run::onTaskHelpClick {} {

  set t [::wb::run::curTaskObj]
  if {$t eq ""} {
    ::wb::run::popup "Task Help" "No task selected."
    return
  }

  set title [::wb::run::_taskField $t title ""]
  if {$title eq ""} { set title [::wb::run::_taskField $t name ""] }

  set helpPath [::wb::run::_taskField $t helpPath ""]
  if {$helpPath eq "" } {
    ::wb::run::popup "Task Help Error" "No help location/name configured for this task.\n"
    return
  }

  if {![file exists $helpPath]} {
    ::wb::run::popup "Task Help Error" "No help file at $helpPath.\n"
    return;
  }
  variable iconCache
  ::wb::help::mdRender $title $helpPath -imagecache $iconCache
}

proc ::wb::run::onViewLogClick {} {
  variable curIndex
  variable ui

  set tasks [::wb::run::_tasks]
  if {$curIndex < 0 || $curIndex >= [llength $tasks]} { return }
  set t [lindex $tasks $curIndex]

  # Already open? Just bring it to the front.
  #if {[::wb::run::focusLogWinIfOpen $curIndex]} { return }

  if {![::wb::run::canViewLogCurrent]} {
    ::wb::run::logMsg "View Log clicked but is DISABLED (runlog.txt not present or already open)"
    return
  }

  # If already open for this task, close it so we can reopen with fresh content.
  ::wb::run::closeLogWinIfOpen $curIndex

  set logPath  [::wb::run::_taskField $t logPath ""]
  set taskName [::wb::run::_taskField $t name ""]
  set seq      [::wb::run::_taskField $t seq ""]
  set win      [::wb::run::openLogWindow $taskName $logPath]
  if {$win ne "" && $seq ne ""} {
    if {![info exists ui(logWinBySeq)]} { set ui(logWinBySeq) [dict create] }
    dict set ui(logWinBySeq) $seq $win
    ::wb::run::updateViewLogLink
  }
}


# Text log window with right-click menu + simple find
proc ::wb::run::openLogWindow {taskName logPath} {
  variable popSeq
  if {![file exists $logPath]} {
    ::wb::run::popup "View Log" "Log not found:
$logPath"
    return
  }

  # Read file, compute max line length (chars)
  set f [open $logPath r]
  set data [read $f]
  close $f

  set maxLen 0
  set lineCount 0
  foreach line [split $data "
"] {
    incr lineCount
    set L [string length $line]
    if {$L > $maxLen} { set maxLen $L }
  }

  # Window sizing (chars); cap width at 200 chars
  set wchars [expr {$maxLen + 2}]
  if {$wchars < 60} { set wchars 60 }
  if {$wchars > 200} { set wchars 200 }

  set hlines $lineCount
  if {$hlines < 12} { set hlines 12 }
  if {$hlines > 45} { set hlines 45 }

  set w .logwin[incr popSeq]
  toplevel $w
  wm title $w "View Log - [file tail [file dirname $logPath]]/[file tail $logPath]"

  ttk::frame $w.f -padding {6 6 6 6}
  pack $w.f -fill both -expand 1

  # top mini-toolbar (use grid consistently within $w.f)
  ttk::frame $w.f.tb
  ttk::label $w.f.tb.p -text $logPath -font "TkDefaultFont 9" -foreground "gray35"
  grid $w.f.tb.p -row 0 -column 0 -sticky ew
  grid columnconfigure $w.f.tb 0 -weight 1

  grid $w.f.tb -row 0 -column 0 -columnspan 2 -sticky ew -pady {0 6}

  # text + scrollbars
  text $w.f.t -wrap none -width $wchars -height $hlines -undo 1
  ttk::scrollbar $w.f.vsb -orient vertical -command [list $w.f.t yview]
  ttk::scrollbar $w.f.hsb -orient horizontal -command [list $w.f.t xview]
  $w.f.t configure -yscrollcommand [list $w.f.vsb set] -xscrollcommand [list $w.f.hsb set]

  grid $w.f.t   -row 1 -column 0 -sticky nsew
  grid $w.f.vsb -row 1 -column 1 -sticky ns
  grid $w.f.hsb -row 2 -column 0 -sticky ew
  grid columnconfigure $w.f 0 -weight 1
  grid rowconfigure    $w.f 1 -weight 1

  $w.f.t insert end $data
  $w.f.t mark set insert 1.0
  $w.f.t configure -state normal

  # Right-click context menu (select/copy/find)
  menu $w.ctx -tearoff 0
  $w.ctx add command -label "Find..." -command [list ::wb::run::findInText $w.f.t]
  $w.ctx add separator
  $w.ctx add command -label "Select All" -command [list ::wb::run::textSelectAll $w.f.t]
  $w.ctx add command -label "Copy" -command [list ::wb::run::textCopySel $w.f.t]
  $w.ctx add separator
  $w.ctx add command -label "Close" -command [list ::wb::run::onLogWinClosed $taskName $w]

  bind $w.f.t <Button-3> [list tk_popup $w.ctx %X %Y]
  bind $w.f.t <Control-f> [list ::wb::run::findInText $w.f.t]

  # Make selection/copy feel native
  bind $w.f.t <Control-a> [list ::wb::run::textSelectAll $w.f.t]
  bind $w.f.t <Control-c> [list ::wb::run::textCopySel $w.f.t]

  # If user closes the window, clear task table entry
  wm protocol $w WM_DELETE_WINDOW [list ::wb::run::onLogWinClosed $taskName $w]

  return $w
}

proc ::wb::run::textSelectAll {tw} {
  if {![winfo exists $tw]} { return }
  $tw tag add sel 1.0 end
  focus -force $tw
}

proc ::wb::run::textCopySel {tw} {
  if {![winfo exists $tw]} { return }
  if {[$tw tag ranges sel] eq ""} { return }
  clipboard clear
  clipboard append [$tw get sel.first sel.last]
}

# Find dialog: search forward with highlight
proc ::wb::run::findInText {tw} {
  variable popSeq
  if {![winfo exists $tw]} { return }
  set w .find[incr popSeq]
  toplevel $w
  wm title $w "Find"
  wm resizable $w 0 0
  ttk::frame $w.f -padding 8
  pack $w.f -fill both -expand 1

  ttk::label $w.f.l -text "Find:"
  ttk::entry $w.f.e -width 40
  variable findState
  ttk::checkbutton $w.f.nc -text "Ignore case" -variable ::wb::run::findState($w,nocase)
  set findState($w,nocase) 1

  ttk::button $w.f.b -text "Next" -command [list ::wb::run::findNext $tw $w]
  ttk::button $w.f.c -text "Close" -command [list destroy $w]

  grid $w.f.l  -row 0 -column 0 -sticky w
  grid $w.f.e  -row 0 -column 1 -sticky we -padx {6 0}
  grid $w.f.nc -row 1 -column 0 -columnspan 2 -sticky w -pady {6 0}
  grid $w.f.b  -row 2 -column 0 -sticky w -pady {10 0}
  grid $w.f.c  -row 2 -column 1 -sticky e -pady {10 0}
  grid columnconfigure $w.f 1 -weight 1

  bind $w <Return> [list ::wb::run::findNext $tw $w]
  focus -force $w.f.e
}

proc ::wb::run::findNext {tw findWin} {
  if {![winfo exists $tw] || ![winfo exists $findWin]} { return }
  set pattern [$findWin.f.e get]
  if {$pattern eq ""} { bell; return }

  # Starting point: after current selection if any, else insert
  set start [$tw index insert]
  if {[$tw tag ranges sel] ne ""} { set start [$tw index "sel.last + 1c"] }

  # options
  set nocase 1
  if {[info exists ::wb::run::findState($findWin,nocase)]} { set nocase $::wb::run::findState($findWin,nocase) }

  set opts {}
  if {$nocase} { lappend opts -nocase }
  set idx [$tw search {*}$opts -- $pattern $start end]
  if {$idx eq ""} {
    bell
    # wrap once
    set idx [$tw search {*}$opts -- $pattern 1.0 end]
    if {$idx eq ""} { return }
  }
  set endIdx "$idx + [string length $pattern]c"
  $tw tag remove sel 1.0 end
  $tw tag add sel $idx $endIdx
  $tw see $idx
  $tw mark set insert $endIdx
  focus -force $tw
}

# UI

proc ::wb::run::_stepRowSetSelBg {row isSelected} {
  variable ui
  if {![winfo exists $row]} { return }
  set baseBg $ui(stepBg)
  set selBg  $ui(stepSelBg)
  set rowBg $baseBg
  set txtBg $baseBg
  if {$isSelected} {
    set rowBg $selBg
    set txtBg $selBg
  }
  catch {$row configure -background $rowBg}
  set txtf "$row.txt"
  set ico  "$row.i"
  if {[winfo exists $txtf]} {
    catch {$txtf configure -background $txtBg}
    foreach c [winfo children $txtf] { catch {$c configure -background $txtBg} }
  }
  if {[winfo exists $ico]} {
    catch {$ico configure -background $baseBg}
  }
}

# ---------------------------------------------------------------------------
# _taskIsVisible task
#
# whenFail holds the name(s) of an earlier task -- the "watched" task.
# The task that OWNS the whenFail field (this proc's argument) is the
# remedial/notification step -- hidden by default, and only revealed once
# the watched task it names has FAILed or TRAPped.
#
# If a task has no whenFail entries at all, it's an ordinary task and is
# always visible. If it names more than one watched task, it becomes
# visible as soon as ANY of them is currently FAIL/TRAP.
#
# (v96 had this backwards -- gated the task NAMED inside another task's
# whenFail list, rather than the task that owns the field. Fixed at v97.)
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# _taskDependsSatisfied task
#
# Mirror-image of _taskIsVisible, for dependsOn instead of whenFail:
# dependsOn holds the name(s) of an earlier "watched" task. The task that
# OWNS the dependsOn field (this proc's argument) stays VISIBLE regardless
# -- unlike a whenFail-gated task -- but is only RUNNABLE once every task
# it names has compState GOOD.
#
# A task with no dependsOn entries is always satisfied (ordinary task).
# A named watched task that hasn't run yet (compState blank) counts as
# NOT satisfied, same as an explicit FAIL/TRAP -- a dependent task can
# only run once its prerequisite has actually succeeded, not merely
# "hasn't explicitly failed yet". If that's too strict for how you want
# this used, this is the one line to loosen (change the eq "GOOD" check).
# ---------------------------------------------------------------------------
proc ::wb::run::_taskDependsSatisfied {task} {
  set dep [::wb::run::_taskField $task dependsOnNames {}]
  if {[llength $dep] == 0} { return 1 } ;# not gated -- ordinary task

  set tasks [::wb::run::_tasks]
  foreach watchedName $dep {
    set idx [::wb::run::findTaskIndexByName $watchedName]
    if {$idx < 0} { continue } ;# named task not found -- ignore, keep checking others
    set watched [lindex $tasks $idx]
    set cond ""
    catch {set cond [string toupper [$watched get compState]]}
    if {$cond ne "GOOD"} {
      return 0 ;# any unmet/failed/never-run dependency blocks the run
    }
  }
  return 1 ;# every named dependency is GOOD
}

proc ::wb::run::_taskIsVisible {task} {
  set wf [::wb::run::_taskField $task whenFailNames {}]
  if {[llength $wf] == 0} { return 1 } ;# not gated -- ordinary task

  set tasks [::wb::run::_tasks]
  foreach watchedName $wf {
    set idx [::wb::run::findTaskIndexByName $watchedName]
    if {$idx < 0} { continue } ;# named task not found -- ignore, keep checking others
    set watched [lindex $tasks $idx]
    set cond ""
    catch {set cond [string toupper [$watched get compState]]}
    if {$cond eq "FAIL" || $cond eq "TRAP"} {
      return 1
    }
  }
  return 0
}

proc ::wb::run::refreshStepList {} {
  variable ui
  variable iconCache
  variable curIndex

  if {![info exists ui(stepInner)] || ![winfo exists $ui(stepInner)]} { return }

  set tasks [::wb::run::_tasks]

  # v96/v97: compute visibility once per task -- gated whenFail-remedial
  # tasks are only visible once a task they watch is FAIL/TRAP. sig is
  # built from VISIBLE tasks only, so the existing rebuild-on-signature-
  # change mechanism below naturally adds/removes rows as visibility
  # flips, with no other changes needed to that mechanism.
  set visible {}
  set sig {}
  foreach t $tasks {
    set v [::wb::run::_taskIsVisible $t]
    lappend visible $v
    if {$v} { lappend sig [::wb::run::_taskField $t seq] }
  }

  set needsRebuild 0
  if {![info exists ui(stepRowSig)]} {
    set needsRebuild 1
  } elseif {$ui(stepRowSig) ne $sig} {
    set needsRebuild 1
  }

  if {$needsRebuild} {
    foreach w [winfo children $ui(stepInner)] { destroy $w }

    set ui(stepRowSig)   $sig
    set ui(stepRowFrm)   [dict create]
    set ui(stepIconLbl)  [dict create]
    set ui(stepStepLbl)  [dict create]
    set ui(stepTitleLbl) [dict create]

    for {set i 0} {$i < [llength $tasks]} {incr i} {
      if {![lindex $visible $i]} { continue } ;# hidden -- no row, no binding

      set t [lindex $tasks $i]
      set seq [::wb::run::_taskField $t seq]

      set row  [frame $ui(stepInner).r$seq -bd 0 -highlightthickness 0 -background $ui(stepBg)]
      set ico  [label $row.i -image "" -text "" -anchor center -background $ui(stepBg) -borderwidth 0 -highlightthickness 0]

      set txtf [frame $row.txt -bd 0 -highlightthickness 0 -background $ui(stepBg)]
      set stepl [label $txtf.s -text "" -anchor w -justify left -font "TkDefaultFont 11" -background $ui(stepBg)]
      set titlel [label $txtf.t -text "" -anchor w -justify left -font "TkDefaultFont 11" -background $ui(stepBg)]

      pack $stepl -side top -anchor w
      pack $titlel -side top -anchor w

      grid $ico  -row 0 -column 0 -sticky n  -padx {2 6} -pady 4
      grid $txtf -row 0 -column 1 -sticky ew
      grid columnconfigure $row 1 -weight 1

      # note: $i is the task's index in the FULL (unfiltered) task list --
      # curIndex and every other call site in this file index into that
      # same full list, so the click binding below must keep using it,
      # not a renumbered position among only the visible rows. Tk's grid
      # is fine with gaps in -row numbers (skipped rows just take no
      # space), so this doesn't affect layout.
      grid $row -row $i -column 0 -sticky ew -pady 1

      dict set ui(stepRowFrm)   $seq $row
      dict set ui(stepIconLbl)  $seq $ico
      dict set ui(stepStepLbl)  $seq $stepl
      dict set ui(stepTitleLbl) $seq $titlel

      foreach w [list $row $ico $txtf $stepl $titlel] {
        bind $w <Button-1> [list ::wb::run::selectStep $i]
      }
    }
  }

  set selSeqStillVisible 0
  for {set i 0} {$i < [llength $tasks]} {incr i} {
    if {![lindex $visible $i]} { continue } ;# hidden -- nothing to update

    set t [lindex $tasks $i]
    set seq   [::wb::run::_taskField $t seq]
    set title [::wb::run::_taskField $t title]
    if {$title eq ""} { set title [::wb::run::_taskField $t name] }

    set stepState [string toupper [::wb::run::_taskField $t stepState "STALE"]]
    set iconName  [::wb::run::_taskField $t stepIcon ""]

    set iconLbl  [dict get $ui(stepIconLbl)  $seq]
    set stepLbl  [dict get $ui(stepStepLbl)  $seq]
    set titleLbl [dict get $ui(stepTitleLbl) $seq]
    set rowFrm   [dict get $ui(stepRowFrm)   $seq]

    set iconImg ""
    if {$iconName ne "" && [dict exists $iconCache $iconName]} {
      set iconImg [dict get $iconCache $iconName]
    }

    set stepFg black
    if {$stepState eq "STALE"} {
      set stepFg "#777777"
    }

    set isSelected 0
    if {[info exists ui(selSeq)] && $ui(selSeq) eq $seq} {
      set isSelected 1
      set selSeqStillVisible 1
    }
    ::wb::run::_stepRowSetSelBg $rowFrm $isSelected

    $iconLbl configure -image $iconImg -text ""
    $stepLbl configure -text "Step $seq" -foreground $stepFg
    $titleLbl configure -text $title -foreground black
  }

  # v96/v97: if a task was selected and it just became hidden (a task it
  # watches recovered to GOOD, or -- edge case -- it watches more than one
  # task and none are FAIL/TRAP right now), fall back to the first visible
  # task rather than leaving curIndex/detail panel pointed at a row that
  # no longer exists.
  if {[info exists ui(selSeq)] && !$selSeqStillVisible} {
    for {set i 0} {$i < [llength $tasks]} {incr i} {
      if {[lindex $visible $i]} {
        ::wb::run::selectStep $i
        break
      }
    }
  }

  update idletasks
  catch { $ui(stepCanvas) configure -scrollregion [$ui(stepCanvas) bbox all] }
}



# --- Brief.json status parsing ------------------------------------------------
proc ::wb::run::readFileUtf8 {path} {
  set fh [open $path r]
  fconfigure $fh -encoding utf-8 -translation auto
  set data [read $fh]
  close $fh
  return $data
}

# Each task folder may contain brief.json describing the latest run status.
# Rules:
#   - If brief.json does NOT exist => FAIL, "TRAPPED during execution" (red)
#   - If brief.json exists:
#       sCondCode == GOOD => success
#       sCondCode == FAIL => failure; sReason explains
#   - Completed On uses the brief.json file timestamp
#   - The Brief property table shows all keys in brief.json EXCEPT sCondCode/sReason,
#     in the order they appear in the file.
proc ::wb::run::briefPathForTask {t} {
  # wb-objs v2 uses briefPath = brief.json.txt; we now prefer brief.json. No defunct.
  set briefPath [::wb::run::_taskField $t briefPath ""]
  return $briefPath
}

proc ::wb::run::briefKeyOrder {d} {
  # Preserve key appearance order from the parsed dict.
  # Tcl dicts preserve insertion order; jsonFileAsDict inserts keys in file order.
  if {[catch {dict size $d} _]} {
    error "briefKeyOrder: expected dict"
  }
  return [dict keys $d]
}

# Update task status/icon from brief.json WITHOUT touching the right-hand UI.
# Used at GUI build time so the step icons are correct immediately.
proc ::wb::run::refreshBriefStatusForTask {task {force 0}} {
  variable form
  set t $task

  set briefPath [$t briefPath]
  if {![file exists $briefPath]} {
    set d [dict create \
       sCondCode TRAP \
       sReason "Failed to complete"]
    $t set briefDict $d
    $t set briefTS 0
  } else {
    # Parse brief
    set ts [file mtime $briefPath]
    set oldTS [$t briefTS]
    # v97: $force bypasses the mtime-unchanged skip below. file mtime is
    # typically only second-resolution -- two runs of the same task
    # completing inside the same second (easy to do manually, e.g.
    # re-running check-status right after a FAIL to confirm it recovers)
    # can otherwise leave briefDict/compState stuck on the FIRST run's
    # result even though the file on disk has actually changed. The
    # post-run render path (renderTask, secs=post-run) knows a fresh
    # write just happened for exactly this task, so it passes force=1;
    # every other caller keeps the cheap mtime-check default.
    if {$force || $oldTS != $ts} {
      $t set briefTS [file mtime $briefPath]
      if {[catch {set d [jsonFileAsDict $briefPath]} jerr]} {
        hilite -red "Brief JSON parse failed in $briefPath: $jerr"
        set d [dict create \
          sCondCode FAIL \
          sReason "Failed to parse"]
        $t set briefDict $d
        $t set briefTS $ts
      } else {
        set briefDict [expandBriefDict $d {sDone apply}]
        $t set briefDict $briefDict
      }
    }
  }

  set ts [$t briefTS]
  set d [$t briefDict]
  #hilite -cyan "refreshBriefStatusForTask $ts $d"
  set cond "TRAP"
  if {[dict exists $d sCondCode]} { set cond [string toupper [dict get $d sCondCode]] }
  ::wb::run::setTaskStatus [$t seq] $cond
  $task set compState $cond
}

proc ::wb::run::expandBriefDict {d listKeys} {
  set out {}

  dict for {key value} $d {
    if {$key in $listKeys} {
      set i 0
      foreach item $value {
        dict set out ${key}.$i $item
        incr i
      }
    } else {
      dict set out $key $value
    }
  }

  return $out
}

# refresh the steps status so Icons are relevant
# The manual mode has special logic.  If the task just before it is fresh then
# manual mode is deemed to be HALTED.
# ---------------------------------------------------------------------------
# _parseStaleAfterSeconds spec
#
# Parses a staleAfter spec of the form "nnn[unit]" -- unit one of
# secs/mins/hours/days/weeks/months/years (singular forms accepted too),
# case-insensitive, defaulting to secs if omitted. Returns the equivalent
# number of seconds, or "" if $spec is empty or malformed (logging a
# warning in the malformed case, but never erroring -- a bad staleAfter
# spec should degrade to "feature not active for this task", not break
# status refresh for the whole flow).
#
# months/years use 30-day/365-day approximations, not calendar-accurate
# month/year lengths -- fine for a staleness heuristic, worth knowing if
# exact month-boundary behavior is ever expected.
# ---------------------------------------------------------------------------
proc ::wb::run::_parseStaleAfterSeconds {spec} {
  if {$spec eq ""} { return "" }
  if {![regexp {^\s*([0-9]+)\s*([a-zA-Z]*)\s*$} $spec -> num unit]} {
    hilite -red "staleAfter: couldn't parse '$spec' -- ignoring"
    return ""
  }
  if {$unit eq ""} { set unit "secs" }
  switch -- [string tolower $unit] {
    sec   - secs   { set mult 1 }
    min   - mins   { set mult 60 }
    hour  - hours  { set mult 3600 }
    day   - days   { set mult 86400 }
    week  - weeks  { set mult 604800 }
    month - months { set mult 2592000 } ;# 30 days, approximate
    year  - years  { set mult 31536000 } ;# 365 days, approximate
    default {
      hilite -red "staleAfter: unknown unit '$unit' in '$spec' -- ignoring"
      return ""
    }
  }
  return [expr {$num * $mult}]
}

proc ::wb::run::refreshStepStates {} {

  hilite -darkcyan "refreshStepStates"

  set taskList [::wb::run::_tasks]

  set lastFreshTS 0
  set now [clock seconds]
  set priorState ""
  set isFirstTask 1
  set forceStaleFromHereOn 0

  foreach task $taskList {
    set briefTS [$task get briefTS]
    set ttype [$task type]

    if {$lastFreshTS == 0} {
      set lastFreshTS [expr {($briefTS eq "" || $briefTS == 0) ? $now : $briefTS}]
    }

    # Capture the reference point BEFORE the FRESH branch below can
    # advance lastFreshTS -- this is "the timestamp of whichever earlier
    # task set the freshness high-water mark this task is being judged
    # against", stored on the task itself (staleRefTS) so later code
    # (selectStep's stale-manual-checkbox reset) can tell whether the
    # user has already touched this task's own options.json since that
    # point, without needing to re-walk the whole task list itself --
    # and, since flows can skip steps, without assuming "the task right
    # before this one" is necessarily the relevant one.
    set staleRefTSForThis $lastFreshTS

    # v105: forceStaleFromHereOn (set below, only ever by staleAfter on
    # task 1) takes priority over the normal relative-freshness compare.
    # Without this, a staleAfter-forced STALE on task 1 never touched
    # lastFreshTS (that only advances in the FRESH branch), so task 2
    # onward kept comparing against task 1's REAL timestamp and could
    # still come out fresh on their own -- task 1 flipped stale, nothing
    # after it did. This propagates the override forward explicitly
    # instead of relying on lastFreshTS to carry it, which it can't.
    if {$forceStaleFromHereOn} {
      set stepState STALE
    } elseif {$briefTS eq "" || $briefTS < $lastFreshTS} {
      set stepState STALE
    } else {
      set stepState FRESH
      set lastFreshTS $briefTS
    }

    # v103 (staleAfter): only checked for the FIRST task in the flow.
    # Reasoning (Steve's, agreed): if an earlier task's result is too
    # old to trust, everything after it is implicitly suspect too, so
    # there's no need to check this on every task individually -- just
    # the one nothing else depends on for its own freshness. Forces
    # STALE regardless of what the relative freshness comparison above
    # decided (which, by construction, always calls task 1 fresh, since
    # there's nothing earlier for it to be stale relative to).
    if {$isFirstTask} {
      set staleAfterSecs [::wb::run::_parseStaleAfterSeconds [$task staleAfter]]
      if {$staleAfterSecs ne "" && $briefTS ne "" && $briefTS != 0} {
        if {($now - $briefTS) > $staleAfterSecs} {
          set stepState STALE
          set forceStaleFromHereOn 1
        }
      }
    }

    $task set stepState $stepState
    $task set staleRefTS $staleRefTSForThis

    set cond [string tolower [$task get compState]]


    if {$stepState eq "FRESH"} {
      set icon "state_${cond}_fresh.png"
    } else {
      set icon "state_ready_stale_prev_${cond}.png"
      if {$ttype eq "manual" && $priorState eq "FRESH"} { ;# manual gets special treatment
        set icon "state_halted.png"
      }
    }

    # v99: a dependsOn-gated task whose dependency isn't satisfied yet
    # gets a dedicated "blocked" icon, overriding whatever its own
    # compState/stepState would otherwise have picked. This takes
    # priority over everything above -- the task's own last-run status is
    # irrelevant while it can't currently be run at all. Deliberately NOT
    # reusing state_halted.png (that means something specific -- a manual
    # task interrupted mid-flow -- and reusing it here would teach people
    # to misread both states).
    if {![::wb::run::_taskDependsSatisfied $task]} {
      set icon "blocked_dependson_blocked.png"
    }

    set isFirstTask 0

    if {$stepState eq "STALE" && $ttype eq "manual" && 0} { ;# t/off manual done indicators
      set needPersist false
      foreach arg [$task getTypedArgs opt] {
        hilite -darkcyan "inspect [$task name] [$arg label] v=/[$arg value]/"
        if {[isTrue [$arg value]]} {
          set needPersist true
          #$arg setValue 0
        }
      }
      if {$needPersist} {
        hilite -darkcyan "need persist [$task name]"
      }
    }

    $task set stepIcon $icon
    set priorState $stepState
  }
}

proc ::wb::run::renderStatusIntoUI {t} {
  variable ui
  variable curIndex


  # Completed On from file timestamp
  set ts [$t briefTS]
  if {$ts == 0} {
    .stat.status.dt configure -text "When not known - did not complete"
  } else {
    set dt [clock format $ts -format "%Y-%b-%d %H:%M:%S"]
    .stat.status.dt configure -text "Completed On: $dt"
  }

  set briefPath [$t briefPath]
  set d [$t briefDict]
  #hilite -cyan "renderStatusIntoUI $d"
  set condCode "TRAP"
  if {[dict exists $d sCondCode]} { set condCode [dict get $d sCondCode] }

  if {$condCode eq "GOOD"} {
    .stat.status.v configure -text "GOOD" -foreground "#0b6b0b"
    ::wb::run::setTaskStatus $curIndex GOOD
    $t set compState $condCode
  } else {
    set reason ""
    if {[dict exists $d sReason]} { set reason [dict get $d sReason] }
    if {$reason eq ""} { set reason "Failed - reason not specified" }
    .stat.status.v configure -text "$condCode: $reason" -foreground "#b00020"
    ::wb::run::setTaskStatus $curIndex $condCode
    $t set compState $condCode
  }

  return [list $briefPath $d]
}

proc ::wb::run::renderStatusUpdate {task status msg} {
  variable ui
  #hilite -cyan "renderStatusUpdate $status $msg"
  .stat.status.v configure -text "$status: $msg" -foreground "#008B8B" ;#"#b00020"
  .stat.status.dt configure -text "not yet completed"
}


proc ::wb::run::renderBriefIntoUI {t} {
  variable ui

  set tv $ui(briefTree)
  $tv delete [$tv children {}]

  set d [$t briefDict]
  # Fill brief property table in file order (excluding sCondCode/sReason)
  set order [::wb::run::briefKeyOrder $d]
  foreach k $order {
    if {$k eq "sCondCode" || $k eq "sReason"} { continue }
    if {![dict exists $d $k]} { continue }
    set v [dict get $d $k]
    $tv insert {} end -values [list $k $v]
  }
}



# Trace callback for Arg.uiRender-backed variables (::wb::argVal(hash)).
# Keeps Arg objects in sync with UI state and schedules opts persistence.
proc ::wb::run::updateArgUiVal {argObj name1 name2 op} {
  if {[info commands $argObj] eq ""} { return }

  # Ignore programmatic sets while building UI / re-rendering
  variable UI_BUILDING
  variable RENDERING

  #hilite -cyan "updateArgUiVal $argObj $UI_BUILDING $RENDERING"
  if {$UI_BUILDING || $RENDERING} { return }

  upvar #0 $name1 A
  if {![info exists A($name2)]} { return }
  set newVal $A($name2)

  set uiType ""
  catch { set uiType [$argObj uiType] }

  #log "opt change (argVal): arg=$argObj uiType=$uiType key=$name2 newVal=<$newVal>"

  catch {$argObj setValue $newVal}

  set t ""
  catch { set t [$argObj task] }
  if {$t eq ""} { return }

  if {[lsearch -exact {text file directory} $uiType] >= 0} {
    # Entry-like controls persist on FocusOut / Enter / Browse (not while typing)
    return
  } else {
    ::wb::run::persistOptsNow $t
  }
}

proc ::wb::run::updateExecArgVal {seq label name1 name2 op} {
  # Variable trace callback for opt UI controls.
  # Keeps Arg objects in sync with UI state and schedules persistence.
  # name1/name2/op are provided by 'trace add variable ... write ...'
  upvar #0 $name1 A
  if {![info exists A($name2)]} { return }
  set newVal $A($name2)

  # Find the task object by seq (do NOT assume it is the current task).
  set taskObj ""
  foreach t [::wb::run::_tasks] {
    if {[$t seq] == $seq} { set taskObj $t; break }
  }
  if {$taskObj eq ""} { return }

  # Find matching opt Arg by label and update its value.
  foreach a [$taskObj getTypedArgs opt] {
    if {[$a label] eq $label} {
      $a setValue $newVal
      break
    }
  }

  ::wb::run::persistOptsNow $taskObj
}



proc ::wb::run::loadOptsDict {taskObj} {
  if {$taskObj eq ""} { return [dict create] }
  set path [file join [$taskObj taskDir] "options.json"]
  if {![file exists $path]} { return [dict create] }
  if {[catch { set d [jsonFileAsDict $path] } err]} {
    hilite -red "options.json load failed: $path"
    hilite -red "  err: $err"
    return [dict create]
  }
  # json2dict returns a dict already
  return $d
}

proc ::wb::run::getFileDate {path} {
    if {[file exists $path]} {
        return [file mtime $path]
    } else {
        return 0
    }
}


# Apply persisted options dict to the task's opt Args (by label). Missing keys are ignored.
# For manual task we ignore persisted options while datestamp on options is > than brief (Options changed, task not run)
proc ::wb::run::applyOptsDictToTask {task d} {
  if {$task eq ""} { return }
  set forceOff 0
  if {[$task type] eq "manual" && 0} { ;# t/off: superseded by staleRefTS reset, see below
    # This was meant to catch "options.json was hand-edited outside the
    # app since the task last completed" (comparing options.json's mtime
    # against brief.json's). In practice it fired on completely ordinary
    # use instead: ANY checkbox click through the running UI also
    # updates options.json's mtime via persistOptsNow, so options.json
    # becomes newer than the static brief.json after the very first
    # completion and stays that way -- meaning this zeroed out a
    # legitimately just-clicked checkbox the next time the task's
    # options got reloaded (e.g. navigating away and back), with no
    # actual staleness involved at all. Reproduced directly: click a
    # box, don't re-run, reload the dict -- forceOff fired and the click
    # was silently discarded.
    #
    # The case this was actually trying to protect -- a stale manual
    # task's checkmarks no longer being trustworthy -- is now handled
    # properly by _resetStaleManualCheckboxes (fs-run.tcl v113/v114),
    # keyed off stepState/staleRefTS (whether a LATER task in the
    # sequence ran since this one completed) rather than this task's own
    # options.json-vs-brief.json mtimes, and it correctly leaves
    # in-progress re-checking alone instead of wiping it on every visit.
    set brfDate [::wb::run::getFileDate  [$task briefPath]]
    set optDate [::wb::run::getFileDate  [file join [$task taskDir] "options.json"]]
    if {$brfDate != 0 && $optDate != 0 && $optDate > $brfDate } {
      set forceOff 1
    }
    #hilite -darkcyan "applyOptsDictToTask [$task name] brf=$brfDate opt=$optDate $forceOff"
  }

  foreach a [$task getTypedArgs opt] {
    set lab [$a label]
    if {[dict exists $d $lab]} {
      set val [dict get $d $lab]
      if {$forceOff} {set val 0}
      hilite -darkcyan "applyOptsDictToTask $lab value [dict get $d $lab] val=$val f=$forceOff"
      catch { $a setValue $val }
    }
    if {[dict exists $d "${lab}-mode"]} { ;# file, directory
      set modeVal [dict get $d "${lab}-mode"]
      hilite -darkcyan "applyOptsDictToTask $lab modeVal $modeVal"
      catch { $a setModeVal $modeVal }
    }
  }
}

proc ::wb::run::persistOptsNow {taskObj} {
  if {$taskObj eq ""} { return }


  set d [dict create]
  foreach a [$taskObj getTypedArgs opt] {
    dict set d [$a label] [$a value]
    if {[$a uiType] in {file directory}} {
      set modeVar [::wb::run::argPathModeVar $a]
      set mode ""
      if {[info exists $modeVar]} { set mode [set $modeVar] }
      if {$mode ne ""} {
        dict set d "[$a label]-mode" "$mode"
      }
    }
  }

  set path [file join [$taskObj taskDir] "options.json"]
  set json [dictToPrettyJsonStr $d ""]
  set fh [open $path w]
  puts $fh $json
  close $fh

  hilite -cyan "persisted options for [$taskObj name] => $path"

  if {[catch {::wb::run::renderTask $taskObj "all"} err]} { hilite -red $err }
}

proc ::wb::run::renderOptsIntoUI {t} {
  variable ui
  hilite -cyan "access.0 $ts "
  if {![info exists ui(optsBody)] || ![winfo exists $ui(optsBody)]} { return }

  # Clear current rows
  foreach c [winfo children $ui(optsBody)] { catch {destroy $c} }

  # Must return a LIST of ::wbobj::Arg objects (no dicts)
  set args [::wb::run::taskArgs $t]

  # Filter only opt args; also enforce type
  set optArgs {}
  foreach a $args {
    if {![info object isa object $a] || ![info object isa typeof $a ::wbobj::Arg]} {
      error "::wb::run::renderOptsIntoUI: expected ::wbobj::Arg, got '$a'"
    }
    if {[$a isOpt]} { lappend optArgs $a }
  }

  if {![llength $optArgs]} {
    catch {pack forget .stat.opts}
    return
  }
  catch {pack .stat.opts -before .stat.brief -fill x -pady 6}

  set row 0
  set seq [dict get $t seq]

  foreach a $optArgs {
    # Only Arg methods (no dict fallback)
    set label [$a label]
    if {$label eq ""} { error "::wb::run::renderOptsIntoUI: opt Arg missing label/id: [$a toString]" }

    # The option control type *must* be in the Arg def (standardize on 'type')
    set d [$a def]
    if {![dict exists $d type]} { error "::wb::run::renderOptsIntoUI: opt Arg missing 'type': [$a toString]" }
    set type [dict get $d type]
    if {$type eq "text"} { set type "input" }

    set reqd  [$a required]
    set place [expr {[dict exists $d place] ? [dict get $d place] : ""}]
    set val   [$a value]

    # For radio/select these must exist in def (standardize now)
    set values {}
    set places {}
    if {$type in {radio select}} {
      if {![dict exists $d values]} { error "::wb::run::renderOptsIntoUI: '$type' opt missing values: [$a toString]" }
      set values [dict get $d values]
      set places [expr {[dict exists $d places] ? [dict get $d places] : $values}]
    }

    # ---- Row frame ----------------------------------------------------------
    ttk::frame $ui(optsBody).r$row
    grid $ui(optsBody).r$row -row $row -column 0 -sticky ew -pady 1
    grid columnconfigure $ui(optsBody) 0 -weight 1

    ttk::label $ui(optsBody).r$row.l -text [string totitle $label] -width 16 -anchor w
    grid $ui(optsBody).r$row.l -row 0 -column 0 -sticky w -padx {0 8}

    ttk::frame $ui(optsBody).r$row.c
    grid $ui(optsBody).r$row.c -row 0 -column 1 -sticky ew
    grid columnconfigure $ui(optsBody).r$row 1 -weight 1

    set vname "::wb::run::ui(optVar,$seq,$label)"
    catch {unset $vname}
    set $vname $val

    switch -- $type {
      check {
        ttk::checkbutton $ui(optsBody).r$row.c.cb -variable $vname -onvalue 1 -offvalue 0
        grid $ui(optsBody).r$row.c.cb -row 0 -column 0 -sticky w
        if {$place ne ""} {
          ttk::label $ui(optsBody).r$row.c.p -text $place -style Wb.Link.TLabel
          grid $ui(optsBody).r$row.c.p -row 0 -column 1 -sticky w -padx 6
          bind $ui(optsBody).r$row.c.p <Button-1> "set $vname \[expr {![set $vname]}]"
          ::wb::run::linkHover $ui(optsBody).r$row.c.p
        }
        trace add variable $vname write [list ::wb::run::updateExecArgVal $seq $label]
      }

      radio {
        set col 0
        foreach vv $values pp $places {
          ttk::radiobutton $ui(optsBody).r$row.c.rb$col -text $pp -value $vv -variable $vname
          grid $ui(optsBody).r$row.c.rb$col -row 0 -column $col -sticky w -padx {0 10}
          bind $ui(optsBody).r$row.c.rb$col <Shift-Button-1> [list set $vname ""]
          incr col
        }
        ::wb::run::tipAttach $ui(optsBody).r$row.c "Shift-click a radio to clear selection"
        trace add variable $vname write [list ::wb::run::updateExecArgVal $seq $label]
      }

      select {
        if {!$reqd} {
          set places [linsert $places 0 "--none--"]
          set values [linsert $values 0 ""]
        }

        set cv "::wb::run::ui(optCmb,$seq,$label)"
        set curPlace ""
        set idx [lsearch -exact $values [set $vname]]
        if {$idx >= 0} { set curPlace [lindex $places $idx] }

        set $cv $curPlace
        ttk::combobox $ui(optsBody).r$row.c.cb -state readonly -values $places -textvariable $cv -width 28
        grid $ui(optsBody).r$row.c.cb -row 0 -column 0 -sticky w
        bind $ui(optsBody).r$row.c.cb <<ComboboxSelected>> [list ::wb::run::onSelectCombo $seq $label $cv $values]
        if {$place ne ""} { ::wb::run::tipAttach $ui(optsBody).r$row.c.cb $place }
        trace add variable $vname write [list ::wb::run::updateExecArgVal $seq $label]
      }

      input - file - dir {
        ttk::entry $ui(optsBody).r$row.c.e -textvariable $vname -width 40
        grid $ui(optsBody).r$row.c.e -row 0 -column 0 -sticky ew
        grid columnconfigure $ui(optsBody).r$row.c 0 -weight 1
        if {$place ne ""} { ::wb::run::tipAttach $ui(optsBody).r$row.c.e $place }
        trace add variable $vname write [list ::wb::run::updateExecArgVal $seq $label]
      }

      default {
        error "::wb::run::renderOptsIntoUI: unsupported opt type '$type' in [$a toString]"
      }
    }

    # incr r (unused)ow
  }
}

proc ::wb::run::onSelectCombo {seq label cv values} {
  # cv is a variable name containing selected place string; values is list aligned to combobox values
  upvar #0 $cv selPlace
  # We can map by index from the combobox itself (the event widget), but easiest: re-find index in its -values.
  # So this helper is called from the widget bind with the right values list.
  # Find selected index:
  # Determine from current selection by searching combobox -values list (places).
  # We'll receive the places list via the widget itself, so use that if possible.
  # But here we only got values list, so do best-effort: assume combobox values aligned and get index from current selection in its list.
  # We'll store mapped value by scanning all combobox values from the widget via focus.
  set w [focus]
  if {[winfo exists $w] && [catch {set places [$w cget -values]}] == 0} {
    set idx [lsearch -exact $places $selPlace]
    if {$idx >= 0} {
      set newVal [lindex $values $idx]
      set vname "::wb::run::ui(optVar,$seq,$label)"
      set $vname $newVal
      ::wb::run::updateExecArgVal $seq $label $newVal
    }
  }
}

proc ::wb::run::taskArgs {t} {
  # Return list of ::wbobj::Arg objects
  # If no args present, return empty list

  if {[dict exists $t args]} {
    return [dict get $t args]
  }
  return {}
}

proc ::wb::run::showWelcomeHelp {form} {
  set cfgPath [$form cfgPath]
  set homeDir [file dirname $cfgPath]
  set wbName  [file tail $homeDir]
  set helpPath [file join $homeDir "$wbName-help.md"]
  set title "FS Flow $wbName Structure"
  log "showWelcomeHelp $helpPath"
  variable iconCache
  ::wb::help::mdRender $title $helpPath -imagecache $iconCache
}

proc ::wb::run::showHelpHelp {form} {
  variable scriptDir
  set cfgPath [$form cfgPath]
  set homeDir [file dirname $cfgPath]
  set flowDir [file dirname $homeDir]
  set helpPath [file join $scriptDir ".." "help" "fs-run-help.md"]
  set title "FS Workbench Runner User Guide"
  log "showHelpHelp $helpPath"
  variable iconCache
  ::wb::help::mdRender $title $helpPath -imagecache $iconCache
}



# ===============================================================================
#-=main                            Build Main Window
# ===============================================================================
# Code generated on 2026-Feb-27 05:01  courtesy of chatGPT 
proc ::wb::run::buildUI { formObj } {
  variable ui
  variable form

  # Auto-reload binds when window gains focus
  catch {bind . <FocusIn> {
    ::wb::run::loadRegSysBindCode
    }
  }
  variable curIndex
  variable runBusy
  catch {unset ui}
  array set ui {}
  # Form object is now the single source of truth (SOT)
  set ui(formObj) $formObj
  # Hard requirements: Form object is the single SOT
  if {![::wb::run::_isTclOOObj $formObj]} {
    error "::wb::run::buildUI: formObj is not a TclOO object: <$formObj>"
  }
  if {[catch {$formObj cfgPath} _cfg] || $_cfg eq ""} {
    error "::wb::run::buildUI: formObj missing required cfgPath"
  }
  if {[catch {$formObj title} _ttl] || $_ttl eq ""} {
    # title can be blank but prefer to crash per spec
    error "::wb::run::buildUI: formObj missing required title"
  }
  set ui(taskStatus) [dict create]  ;# seq -> WAIT/GOOD/FAIL
  set ui(logWinBySeq) [dict create]  ;# seq -> toplevel path (runtime)

  wm title . "[$formObj title] - FlowSmithy(r) Workflow"
  wm geometry . 1320x720
  ::wb::run::applyDynToUI
  ttk::style theme use clam
  # Options panel subtle background
  ttk::style configure WbOpts.TFrame      -background "#f3f5f7"
  ttk::style configure WbOpts.TLabel      -background "#f3f5f7"
  ttk::style configure WbOpts.TCheckbutton -background "#f3f5f7"
  ttk::style configure WbOpts.TRadiobutton -background "#f3f5f7"
  ttk::style configure WbOptTitle.TLabel -background [ttk::style lookup TLabel -background]
  ttk::style configure WbOptTitle.TFrame -background [ttk::style lookup TLabel -background]
  catch {font create Wb.BrowseFont -family [font actual TkDefaultFont -family] -size [expr {[font actual TkDefaultFont -size] - 1}]}
  catch {ttk::style configure WbBrowse.TButton -font Wb.BrowseFont -padding {4 1 4 1}}

  # Brief value area background (treeview field background). Keep headings unchanged.
  set _optBg [ttk::style lookup WbOpts.TFrame -background]
  if {$_optBg eq ""} { set _optBg "#f3f5f7" }
  ttk::style configure WbBrief.Treeview -background $_optBg -fieldbackground $_optBg

  ::wb::run::bumpUiFonts 2

  set _sz [font actual TkDefaultFont -size]
  if {$_sz < 0} { set _sz [expr { -$_sz }] }
  catch {font create wbMenuIcon -family [font actual TkDefaultFont -family] -size [expr {$_sz + 6}] -weight bold}
  catch {font create wbBold -family [font actual TkDefaultFont -family] -size [expr {$_sz}] -weight bold}

  ttk::style configure Wb.Link.TLabel -foreground "#1a5fb4" -padding {2 0 2 0}
  ttk::style configure Wb.MenuIcon.TLabel -foreground "#1a5fb4" -padding {4 0 4 0} -font wbMenuIcon
  ttk::style configure Wb.LinkHover.TLabel -foreground "black" -background "#d9f2ef" -padding {2 0 2 0}
  ttk::style configure Wb.LinkDisabled.TLabel -foreground "gray50" -padding {2 0 2 0}

  ttk::panedwindow .vpan -orient vertical
  pack .vpan -fill both -expand 1
  ttk::frame .top
  ttk::frame .log -padding {6 4 6 6}
  .vpan add .top -weight 5
  .vpan add .log -weight 1

  ttk::panedwindow .hpan -orient horizontal
  pack .hpan -in .top -fill both -expand 1 -padx 6 -pady 6
  ttk::frame .menu -padding 6
  ttk::frame .stat -padding 6
  .hpan add .menu -weight 1
  .hpan add .stat -weight 4

  # Make .stat content stretch to fill the right panel
  grid columnconfigure .stat 0 -weight 1
  grid rowconfigure    .stat 0 -weight 1

  # Menu header
  ttk::frame .menu.hdr
  pack .menu.hdr -fill x
  ttk::label .menu.hdr.l -text "Workflow Steps" -font "TkDefaultFont 10 bold"
  pack .menu.hdr.l -side left
  ttk::label .menu.hdr.welcome -text "Welcome" -style Wb.Link.TLabel
  ttk::label .menu.hdr.help    -text "Help"    -style Wb.Link.TLabel
  pack .menu.hdr.help -side right
  pack .menu.hdr.welcome -side right -padx 8
  bind .menu.hdr.welcome <Button-1> [list ::wb::run::showWelcomeHelp $form]
  bind .menu.hdr.help    <Button-1> [list ::wb::run::showHelpHelp $form]
  ::wb::run::linkHover .menu.hdr.welcome
  ::wb::run::linkHover .menu.hdr.help
  ::wb::run::linkSetEnabled .menu.hdr.welcome 1
  ::wb::run::linkSetEnabled .menu.hdr.help 1

  ttk::separator .menu.sep
  pack .menu.sep -fill x -pady 6

  ttk::frame .menu.list
  pack .menu.list -fill both -expand 1

  set ui(stepBg)    [ttk::style lookup TFrame -background]
  if {$ui(stepBg) eq ""} { set ui(stepBg) "SystemButtonFace" }
  set ui(stepSelBg) "#cfe8ff"

  canvas .menu.list.c -highlightthickness 0 -bd 0 -background $ui(stepBg)
  ttk::scrollbar .menu.list.vsb -orient vertical -command {.menu.list.c yview}
  .menu.list.c configure -yscrollcommand {.menu.list.vsb set}

  frame .menu.list.inner -background $ui(stepBg)
  .menu.list.c create window 0 0 -anchor nw -window .menu.list.inner

  pack .menu.list.vsb -side right -fill y
  pack .menu.list.c -side left -fill both -expand 1

  set ui(stepCanvas) .menu.list.c
  set ui(stepInner)  .menu.list.inner

  set tasks [::wb::run::_tasks]
  for {set i 0} {$i < [llength $tasks]} {incr i} {
    set task [lindex $tasks $i]
    ::wb::run::refreshBriefStatusForTask $task
  }
  ::wb::run::refreshStepStates
  ::wb::run::refreshStepList

  # Status topbar
  ttk::frame .stat.topbar
  pack .stat.topbar -fill x
  ttk::label .stat.topbar.viewlog -text "View Log" -style Wb.Link.TLabel
  ttk::label .stat.topbar.runtask -text "Run Task" -style Wb.Link.TLabel
  ttk::label .stat.topbar.taskhlp -text "Task Help" -style Wb.Link.TLabel

  canvas .stat.topbar.menuC -width 18 -height 14 -highlightthickness 0 -bd 0 -cursor hand2
  catch {.stat.topbar.menuC configure -background [ttk::style lookup TFrame -background]}
  .stat.topbar.menuC create line 3 3  15 3  -width 2 -fill "#1a5fb4"
  .stat.topbar.menuC create line 3 7  15 7  -width 2 -fill "#1a5fb4"
  .stat.topbar.menuC create line 3 11 15 11 -width 2 -fill "#1a5fb4"

  set ui(runLink) .stat.topbar.runtask
  set ui(viewLogLink) .stat.topbar.viewlog
  set ui(menuWidget) .stat.topbar.menuC
  pack .stat.topbar.menuC -side right -padx {4 0}
  pack .stat.topbar.taskhlp -side right -padx 10
  pack .stat.topbar.runtask -side right -padx 10
  pack .stat.topbar.viewlog -side right -padx 10

  bind .stat.topbar.viewlog <Button-1> {::wb::run::onViewLogClick}
  bind .stat.topbar.taskhlp <Button-1> {::wb::run::onTaskHelpClick}
  bind .stat.topbar.runtask <Button-1> {::wb::run::onRunTaskClick}
  bind .stat.topbar.menuC   <Button-1> {::wb::run::onMenuClick %X %Y}
  ::wb::run::tipAttach .stat.topbar.menuC "Click for more actions"

  ::wb::run::linkHover .stat.topbar.viewlog
  ::wb::run::linkHover .stat.topbar.runtask
  ::wb::run::linkHover .stat.topbar.taskhlp

  ::wb::run::updateViewLogLink
  ::wb::run::linkSetEnabled .stat.topbar.taskhlp 1

  ttk::separator .stat.sep
  pack .stat.sep -fill x -pady 6

    # Options panel body background (reuse for Globs/Brief value areas)
  set bg [ttk::style lookup WbOpts.TFrame -background]
  if {$bg eq ""} { set bg "#f3f5f7" }

  frame .stat.globs -bd 1 -relief groove -background $bg -padx 0 -pady 0
  pack .stat.globs -fill x -pady {0 6}
  set ui(globsFrame) .stat.globs
  ::wb::run::renderGlobsPanel

  # --- TWO COLUMN STATUS BODY ------------------------------------------------
  # Adjustable fixed pixel width for ALL left labels in the status area.
  set ui(statLeftPx) 140

  ttk::frame .stat.body
  pack .stat.body -fill both -expand 1

  grid columnconfigure .stat.body 0 -weight 0
  grid columnconfigure .stat.body 1 -weight 1

  # Task row (label left, value right) using same fixed left column width
  ttk::frame .stat.taskRow
  grid .stat.taskRow -in .stat.body -row 0 -column 0 -columnspan 2 -sticky ew -pady {0 6}

  grid columnconfigure .stat.taskRow 0 -weight 0 -minsize $ui(statLeftPx)
  grid columnconfigure .stat.taskRow 1 -weight 1

  ttk::label .stat.taskTitleL -text "Task:" -font "TkDefaultFont 11 bold"
  ttk::label .stat.taskTitleV -text ""     -font "TkDefaultFont 11 bold"

  grid .stat.taskTitleL -in .stat.taskRow -row 0 -column 0 -sticky e  -padx {0 10}
  grid .stat.taskTitleV -in .stat.taskRow -row 0 -column 1 -sticky w


  # ---------------- Description ----------------
  ttk::frame .stat.desc
  grid .stat.desc -in .stat.body -row 1 -column 0 -columnspan 2 -sticky ew

  set ui(descFrame) .stat.desc
  set ui(descGridSpec) [list -in .stat.body -row 1 -column 0 -columnspan 2 -sticky ew]

  grid columnconfigure .stat.desc 0 -weight 0 -minsize $ui(statLeftPx)
  grid columnconfigure .stat.desc 1 -weight 1

  ttk::label .stat.desc.l -text "Description:" -font "TkDefaultFont 10 bold"
  ttk::label .stat.desc.v -text "" -wraplength 860 -justify left
  grid .stat.desc.l -row 0 -column 0 -sticky ne -padx {0 10}
  grid .stat.desc.v -row 0 -column 1 -sticky new

  # ---------------- SetupErr ----------------
  ttk::frame .stat.setupErr
  set ui(setupErrFrame) .stat.setupErr
  set ui(setupErrGridSpec) [list -in .stat.body -row 2 -column 0 -columnspan 2 -sticky ew -pady 2]
  eval [list grid $ui(setupErrFrame)] $ui(setupErrGridSpec)

  grid columnconfigure .stat.setupErr 0 -weight 0 -minsize $ui(statLeftPx)
  grid columnconfigure .stat.setupErr 1 -weight 1

  ttk::label .stat.setupErr.l -text "SetupErr:" -font "TkDefaultFont 10 bold" -foreground "#b00020"
  ttk::label .stat.setupErr.v -text "" -wraplength 860 -justify left -foreground "#b00020"
  grid .stat.setupErr.l -row 0 -column 0 -sticky ne -padx {0 10}
  grid .stat.setupErr.v -row 0 -column 1 -sticky new

  grid remove $ui(setupErrFrame)


  # ---------------- Status ----------------
  ttk::frame .stat.status
  grid .stat.status -in .stat.body -row 3 -column 0 -columnspan 2 -sticky ew -pady 2

  set ui(statusFrame) .stat.status
  set ui(statusGridSpec) [list -in .stat.body -row 3 -column 0 -columnspan 2 -sticky ew -pady 2]

  grid columnconfigure .stat.status 0 -weight 0 -minsize $ui(statLeftPx)
  grid columnconfigure .stat.status 1 -weight 1

  ttk::label .stat.status.l  -text "Status:" -font "TkDefaultFont 10 bold"
  ttk::frame .stat.status.r
  ttk::label .stat.status.v  -text ""
  ttk::label .stat.status.dt -text ""

  grid .stat.status.l -row 0 -column 0 -sticky ne -padx {0 10}
  grid .stat.status.r -row 0 -column 1 -sticky ew

  pack .stat.status.v  -in .stat.status.r -side left
  pack .stat.status.dt -in .stat.status.r -side right

  # ---------------- Options ----------------
  ttk::frame .stat.opts
  set ui(optsFrame) .stat.opts
  set ui(optsGridSpec) [list -in .stat.body -row 4 -column 0 -columnspan 2 -sticky ew -pady {6 0}]
  eval [list grid $ui(optsFrame)] $ui(optsGridSpec)


  grid columnconfigure .stat.opts 0 -weight 0 -minsize $ui(statLeftPx)
  grid columnconfigure .stat.opts 1 -weight 1

  ttk::label .stat.opts.l -text "Options:" -font "TkDefaultFont 10 bold"
  ttk::frame .stat.opts.body -style WbOpts.TFrame

  set ui(optsBody) .stat.opts.body
  catch { $ui(optsBody) configure -takefocus 1 }
  catch { bind $ui(optsBody) <Button-1> {focus %W} }
  set ui(optsFrame) .stat.opts
  set ui(optsGridSpec) [list -in .stat.body -row 4 -column 0 -columnspan 2 -sticky ew -pady {6 0}]


  grid .stat.opts.l    -row 0 -column 0 -sticky ne -padx {0 10}
  grid .stat.opts.body -row 0 -column 1 -sticky ew

  grid remove $ui(optsFrame)



  # ---------------- Parms ----------------
  ttk::frame .stat.parms
  set ui(parmsFrame) .stat.parms
  set ui(parmsGridSpec) [list -in .stat.body -row 5 -column 0 -columnspan 2 -sticky ew -pady {6 0}]
  eval [list grid $ui(parmsFrame)] $ui(parmsGridSpec)

  grid columnconfigure .stat.parms 0 -weight 0 -minsize $ui(statLeftPx)
  grid columnconfigure .stat.parms 1 -weight 1

  ttk::label .stat.parms.l -text "Parms:" -font "TkDefaultFont 10 bold"
  ttk::frame .stat.parms.view -style WbOpts.TFrame
  canvas .stat.parms.view.c -highlightthickness 0 -borderwidth 0 -yscrollincrement 1
  ttk::scrollbar .stat.parms.view.vsb -orient vertical -command [list .stat.parms.view.c yview]
  ttk::frame .stat.parms.body -style WbOpts.TFrame
  .stat.parms.view.c configure -yscrollcommand [list ::wb::run::onParmsCanvasYScroll .stat.parms.view.vsb]
  .stat.parms.view.c create window 0 0 -anchor nw -window .stat.parms.body -tags body

  set ui(parmsView) .stat.parms.view
  set ui(parmsCanvas) .stat.parms.view.c
  set ui(parmsVsb) .stat.parms.view.vsb
  set ui(parmsBody) .stat.parms.body
  set ui(parmsFrame) .stat.parms
  set ui(parmsGridSpec) [list -in .stat.body -row 5 -column 0 -columnspan 2 -sticky ew -pady {6 0}]

  bind .stat.parms.view.c <Configure> {::wb::run::syncParmsCanvas %W}
  bind .stat.parms.body <Configure> {::wb::run::syncParmsCanvas .stat.parms.view.c}

  grid .stat.parms.l    -row 0 -column 0 -sticky ne -padx {0 10}
  grid .stat.parms.view -row 0 -column 1 -sticky ew
  grid columnconfigure .stat.parms.view 0 -weight 1
  grid rowconfigure .stat.parms.view 0 -weight 1

  grid remove $ui(parmsFrame)


# ---------------- Brief ----------------
  ttk::frame .stat.brief
  grid .stat.brief -in .stat.body -row 6 -column 0 -columnspan 2 -sticky nsew -pady {6 0}

  set ui(briefFrame) .stat.brief
  set ui(briefGridSpec) [list -in .stat.body -row 6 -column 0 -columnspan 2 -sticky nsew -pady {6 0}]

  grid columnconfigure .stat.brief 0 -weight 0 -minsize $ui(statLeftPx)
  grid columnconfigure .stat.brief 1 -weight 1
  grid rowconfigure    .stat.brief 0 -weight 1
  # Row weights in .stat.body are handled dynamically in ::wb::run::_layoutTaskBody

  ttk::label .stat.brief.l -text "Brief:" -font "TkDefaultFont 10 bold"
  ttk::treeview .stat.brief.tv -columns {Property Value} -show headings -style WbBrief.Treeview
  .stat.brief.tv heading Property -text "Property"
  .stat.brief.tv heading Value    -text "Value"
  .stat.brief.tv column  Property -width 180 -anchor w
  .stat.brief.tv column  Value    -width 780 -anchor w
  set ui(briefTree) .stat.brief.tv

  grid .stat.brief.l  -row 0 -column 0 -sticky ne -padx {0 10}
  grid .stat.brief.tv -row 0 -column 1 -sticky nsew

  # Log panel
  text .log.txt -height 6 -wrap none -state disabled
  ttk::scrollbar .log.vsb -orient vertical -command {.log.txt yview}
  .log.txt configure -yscrollcommand {.log.vsb set}
  pack .log.vsb -in .log -side right -fill y
  pack .log.txt -in .log -side left -fill both -expand 1
  set ui(logText) .log.txt

  ::wb::run::dynSelectActiveTaskOrDefault
  ::wb::run::updateRunTaskLink
  ::wb::run::updateViewLogLink

  ::wb::run::dynBindAutoSave
  ::wb::run::scheduleSaveDyn

  ::wb::run::logMsg "UI ready. Loaded: [::wb::run::_taskField $form title ""]"
  # Raise this window to the front on startup (Option 2 cooperative raise).
  # Called after the window is fully built so Windows sees an active Tk window.
  update idletasks
  wm deiconify .
  catch {wm attributes . -topmost 1}
  raise .
  focus -force .
  after 500 [list catch [list wm attributes . -topmost 0]]
}


# Loop all parm Args for the task and invoke bindName code if present.
# Uses registry mapping (gen/wb-reg-sys.json) to resolve bindName.
proc ::wb::run::loopAndCallBindCode {taskObj} {
  ::wb::run::dynEnsureGlobs
  variable dynData

  #openDebugWin "Debug Wndow" 400 600 [$taskObj dumpStr]

  #log "loopAndCallBindCode $taskObj [$taskObj name]"
  # ctx object
  set ctx [::wbobj::Ctx new]
  $ctx set task $taskObj
  $ctx set globs [dict get $dynData globs]

  # For each parm Arg, call its bind proc (if any)
  set args [$taskObj getTypedArgs parm]
  foreach a $args {
    $ctx set arg $a
    # resolve bindName: prefer Arg method if present, else registry by parmId
    set bindName ""
    if {![catch {$a bindName} bn]} {
      set bindName $bn
    } else {
      if {[info exists ::wb::run::regParmsById]} {
        catch {
          set pid [$a id]
          if {[dict exists $::wb::run::regParmsById $pid bindName]} {
            set bindName [dict get $::wb::run::regParmsById $pid bindName]
          }
        }
      }
    }

    if {[string trim $bindName] eq ""} { continue }

    # Map unqualified to ::wb::run::sys::bind::<name>
    if {[string first "::" $bindName] < 0} {
      set bindName "::wb::sys::bind::$bindName"
    }
    #log "loopAndCallBindCode.call $bindName"

    if {[info commands $bindName] eq ""} { continue }

    #catch { $bindName $ctx }
    wbTryCall "Bind Code Failed: $bindName" false $bindName $ctx
  }
  return
}

proc ::wb::run::_secsNorm {secs} {
  # Backward compat: "full"/"light"
  if {$secs eq ""} { set secs all }
  if {$secs eq "full"} { set secs all }
  if {$secs eq "light"} { set secs {globs desc setup status parms brief} }

  # Ensure list
  if {[catch {llength $secs}]} { set secs [list $secs] }

  # Expand "all"
  if {[lsearch -exact $secs all] >= 0} {
    return {globs desc setup status options parms brief}
  }
  return $secs
}

proc ::wb::run::_secHas {secs name} {
  expr {[lsearch -exact $secs $name] >= 0}
}

proc ::wb::run::_gridShow {w spec} {
  if {![winfo exists $w]} { return }
  eval [list grid $w] $spec
}

proc ::wb::run::_gridHide {w} {
  if {[winfo exists $w]} { grid remove $w }
}

proc ::wb::run::_packShow {w} {
  if {![winfo exists $w]} { return }
  # pack info throws if not packed
  if {[catch {pack info $w}]} {
    pack $w -fill x -pady {0 6}
  }
}

proc ::wb::run::_packHide {w} {
  if {![winfo exists $w]} { return }
  catch {pack forget $w}
}

proc ::wb::run::renderTaskSecGlobs {t} {
  variable ui
  if {![info exists ui(globsFrame)]} { return }
  set f $ui(globsFrame)
  if {![winfo exists $f]} { return }
  ::wb::run::_packShow $f
  ::wb::run::renderGlobsPanel
}

proc ::wb::run::hideTaskSecGlobs {} {
  variable ui
  if {[info exists ui(globsFrame)] && [winfo exists $ui(globsFrame)]} {
    ::wb::run::_packHide $ui(globsFrame)
  }
}

proc ::wb::run::unhideTaskSecGlobs {} {
  variable ui
  if {[info exists ui(globsFrame)] && [winfo exists $ui(globsFrame)]} {
    ::wb::run::_packShow $ui(globsFrame)
  }
}

proc ::wb::run::renderTaskSecDesc {t} {
  variable ui
  if {[info exists ui(descFrame)] && [winfo exists $ui(descFrame)]} {
    ::wb::run::_gridShow $ui(descFrame) $ui(descGridSpec)
  }
  .stat.taskTitleV configure -text "[::wb::run::_taskField $t title ""]"
  set d [::wb::run::_taskField $t desc ""]
  if {$d eq ""} { set d "missing description" }


  set task $t

  set d [::wb::run::evalCfgStr $t $d]

  .stat.desc.v configure -text [::wb::run::expandGlobs $d]

  # Tooltip on Task label (type/dir/depends)
  set typ  [::wb::run::_taskField $t type ""]
  set tdir [::wb::run::_taskField $t taskDir ""]
  set tip "Type: $typ\nFolder: $tdir"
  set dep [::wb::run::_taskField $t dependsOnNames {}]
  set wf  [::wb::run::_taskField $t whenFailNames {}]
  if {[llength $dep]} { append tip "\nDependsOn: $dep" }
  if {[llength $wf]}  { append tip "\nWhenFail:  $wf" }
  ::wb::run::tipAttach .stat.taskTitleL $tip
  ::wb::run::tipAttach .stat.desc.l "Task description (supports glob expansion)"
}

# This allows CFG strings to access glob and task objects
proc ::wb::run::evalCfgStr {task str} {
  set ::wb::run::templateTask $task

  proc ::wb::run::glob {key} {
    variable templateTask
    set globs [$templateTask globs]
    return [$globs dget $key]
  }

  #This maps an opt value to a prefixed glob value
  # if pref starts with tern:, alternate prefixes can be used
  proc ::wb::run::opt-map {key pref} {
    variable templateTask
    set arg [$templateTask findArg $key]
    if {$arg eq ""} {return "?${key}?"}
    if {[string match "tern:*" $pref]} {
        set rest [string range $pref 5 end]
        if {[regexp {^([^?]+)\?([^:]+):(.*)$} $rest -> testFld fld1 fld2]} {
          hilite -cyan "testFld=$testFld fld1=$fld1 fld2=$fld2"
          set a [$templateTask findArg $testFld]
          if {[$a uiType] eq "check" && [isTrue [$a value]]} {
            set prefStr $fld1
          } else {
            set prefStr $fld2
          }
          return [glob "~[$arg get value]$prefStr"]
        } else {
          set prefStr "?bad-parse?"
        }
    } else {
      set prefStr $pref
    }
    return [glob "${prefStr}[$arg get value]"]
  }

  set evalStr $str
  set hadRealGlob 0

  if {[llength [info commands ::glob]]} {
    rename ::glob ::wb::run::_real_glob
    set hadRealGlob 1
  }

  try {
    interp alias {} ::glob {} ::wb::run::glob
    interp alias {} ::opt-map {} ::wb::run::opt-map
    set evalStr [eval [list subst $str]]
  } on error {err opts} {
    set msg "tcl-int runtime error: $err"

    if {[dict exists $opts -errorinfo]} {
      hilite -red [dict get $opts -errorinfo]
    }
  } finally {
    catch {interp alias {} ::glob {}}       ;# remove alias cleanly
    catch {interp alias {} ::opt-map {}}    ;# remove alias cleanly
    catch {rename ::wb::run::opt-map ""}    ;# remove the proc
    if {$hadRealGlob} {
      catch {rename ::wb::run::_real_glob ::glob}
    }
    catch {unset ::wb::run::templateTask}
  }

  return $evalStr
}

proc ::wb::run::hideTaskSecDesc {} {
  variable ui
  if {[info exists ui(descFrame)] && [winfo exists $ui(descFrame)]} {
    ::wb::run::_gridHide $ui(descFrame)
  }
}

proc ::wb::run::unhideTaskSecDesc {} {
  variable ui
  if {[info exists ui(descFrame)] && [winfo exists $ui(descFrame)]} {
    ::wb::run::_gridShow $ui(descFrame) $ui(descGridSpec)
  }
}

proc ::wb::run::renderTaskSecSetup {t} {
  variable ui
  variable bKillRun

  set bKillRun false
  # SetupErr row (shown only when non-empty)
  #hilite -cyan "renderTaskSecSetup errs=[$t optErrCnt]"
  set seMsg [::wb::run::_taskField $t setupErr ""]
  if {$seMsg eq "" && [$t optErrCnt] > 0} {
    set seMsg "Task has option error(s): [$t optErrCnt]"
    #hilite -cyan "flagging errs=[$t optErrCnt]"
  }
  if {$seMsg eq ""} {
    if {[info exists ui(setupErrFrame)] && [winfo exists $ui(setupErrFrame)]} {
      grid remove $ui(setupErrFrame)
    }
  } else {
    if {[info exists ui(setupErrFrame)] && [winfo exists $ui(setupErrFrame)]} {
      #hilite -cyan "list grid $seMsg"
      ::wb::run::_gridShow $ui(setupErrFrame) $ui(setupErrGridSpec)
      raise $ui(setupErrFrame)
    }
    .stat.setupErr.v configure -text $seMsg
    update idletasks
    set bKillRun true

  }
}

proc ::wb::run::hideTaskSecSetup {} {
  variable ui
  if {[info exists ui(setupErrFrame)] && [winfo exists $ui(setupErrFrame)]} {
    grid remove $ui(setupErrFrame)
  }
}

proc ::wb::run::unhideTaskSecSetup {} {
  variable ui
  if {[info exists ui(setupErrFrame)] && [winfo exists $ui(setupErrFrame)]} {
    eval [list grid $ui(setupErrFrame)] $ui(setupErrGridSpec)
  }
}

proc ::wb::run::renderTaskSecStatus {t} {
  variable ui
  if {[info exists ui(statusFrame)] && [winfo exists $ui(statusFrame)]} {
    ::wb::run::_gridShow $ui(statusFrame) $ui(statusGridSpec)
  }
  ::wb::run::tipAttach .stat.status.l "Status of last run derived from brief.json contents"
  ::wb::run::renderStatusIntoUI $t
}

proc ::wb::run::hideTaskSecStatus {} {
  variable ui
  if {[info exists ui(statusFrame)] && [winfo exists $ui(statusFrame)]} {
    ::wb::run::_gridHide $ui(statusFrame)
  }
}

proc ::wb::run::unhideTaskSecStatus {} {
  variable ui
  if {[info exists ui(statusFrame)] && [winfo exists $ui(statusFrame)]} {
    ::wb::run::_gridShow $ui(statusFrame) $ui(statusGridSpec)
  }
}

proc ::wb::run::renderTaskSecOptions {t} {
  variable ui

  set args [$t getTypedArgs opt]
  set n [llength $args]

  set ui(secHas,options) [expr {$n > 0}]

  if {$n <= 0} {
    if {[info exists ui(optsFrame)] && [winfo exists $ui(optsFrame)]} {
      grid remove $ui(optsFrame)
    }
    return
  }

  if {[info exists ui(optsFrame)] && [winfo exists $ui(optsFrame)]} {
    eval [list grid $ui(optsFrame)] $ui(optsGridSpec)
  }

  set ob $ui(optsBody)
  foreach child [winfo children $ob] { destroy $child }

  # 2 columns: label + control slice
  grid columnconfigure $ob 0 -weight 0
  grid columnconfigure $ob 1 -weight 1

  # header row (only when options exist)
  ttk::label $ob.h_lab -text "Label" -style WbOptTitle.TLabel -padding {0 0 10 0} -anchor e -width $::wbobj::OPT_LABEL_CH
  grid $ob.h_lab -row 0 -column 0 -sticky nsew

  ttk::frame $ob.h_slice -style WbOptTitle.TFrame
  grid $ob.h_slice -row 0 -column 1 -sticky ew
  set hs $ob.h_slice

  ttk::label $hs.parm -text "Parm" -style WbOptTitle.TLabel -anchor w -width $::wbobj::OPT_PARM_CH -padding {0 0 10 0}
  ttk::label $hs.ctrl -text "Control Values" -style WbOptTitle.TLabel -anchor w
  ttk::label $hs.err  -text "Error Message" -style WbOptTitle.TLabel -anchor w -padding {10 0 0 0}

  grid $hs.parm -row 0 -column 0 -sticky nsew
  grid $hs.ctrl -row 0 -column 1 -sticky nsew
  grid $hs.err  -row 0 -column 2 -sticky nsew

  grid columnconfigure $hs 0 -minsize $::wbobj::OPT_PARM_PX -weight 0
  grid columnconfigure $hs 1 -minsize $::wbobj::OPT_CTRL_PX -weight 1
  grid columnconfigure $hs 2 -minsize $::wbobj::OPT_ERR_PX  -weight 0

  set row 1
  foreach a $args {
    # this primes initVal readonly text fields to a current value
    if {[$a argType] eq "opt" && [$a isReadOnly] && [$a initVal] ne ""} {
      set initVal [$a initVal]
      $a setValue [::wb::run::evalCfgStr $t $initVal]
    }
    set row [$a uiRender $ob $row]
  }

  ::wb::run::tipAttach .stat.opts.l "Set options and parms (args) for next run"

}



proc ::wb::run::hideTaskSecOptions {} {
  variable ui
  if {[info exists ui(optsFrame)] && [winfo exists $ui(optsFrame)]} { grid remove $ui(optsFrame) }
}

proc ::wb::run::unhideTaskSecOptions {} {
  if {[winfo exists .stat.opts]} { catch {pack .stat.opts -side top -fill x -padx 8 -pady {2 8}} }
}

proc ::wb::run::syncParmsCanvas {c} {
  variable ui
  if {![winfo exists $c]} { return }
  if {![info exists ui(parmsBody)] || ![winfo exists $ui(parmsBody)]} { return }

  set body $ui(parmsBody)
  set cw [winfo width $c]
  if {$cw <= 1} {
    set cw [winfo reqwidth $body]
  }
  $c itemconfigure body -width $cw
  $c configure -scrollregion [list 0 0 $cw [winfo reqheight $body]]
}

proc ::wb::run::onParmsCanvasYScroll {sb first last} {
  if {[winfo exists $sb]} {
    $sb set $first $last
  }
}

proc ::wb::run::updateParmsViewport {rowCount} {
  variable ui
  if {![info exists ui(parmsCanvas)] || ![winfo exists $ui(parmsCanvas)]} { return }
  if {![info exists ui(parmsBody)] || ![winfo exists $ui(parmsBody)]} { return }
  if {![info exists ui(parmsView)] || ![winfo exists $ui(parmsView)]} { return }
  if {![info exists ui(parmsVsb)] || ![winfo exists $ui(parmsVsb)]} { return }

  set maxRows 8
  update idletasks

  set body $ui(parmsBody)
  set c    $ui(parmsCanvas)
  set vsb  $ui(parmsVsb)

  if {$rowCount <= 0} {
    catch {grid remove $vsb}
    $c configure -height 1
    return
  }

  set rowH 24
  set bodyH [winfo reqheight $body]
  if {$bodyH > 0 && $rowCount > 0} {
    set rowH [expr {int(ceil(double($bodyH) / $rowCount))}]
  }

  set visibleRows [expr {$rowCount > $maxRows ? $maxRows : $rowCount}]
  set height [expr {$visibleRows * $rowH}]
  if {$height < 24} { set height 24 }
  $c configure -height $height

  if {$rowCount > $maxRows} {
    grid $c   -row 0 -column 0 -sticky nsew
    grid $vsb -row 0 -column 1 -sticky ns -padx {6 0}
  } else {
    grid $c -row 0 -column 0 -sticky nsew
    catch {grid remove $vsb}
    $c yview moveto 0
  }

  ::wb::run::syncParmsCanvas $c
}


proc ::wb::run::renderTaskSecParms {t} {
  variable ui

  set pargs [$t getTypedArgs parm]
  set pn [llength $pargs]

  set ui(secHas,parms) [expr {$pn > 0}]

  if {$pn <= 0} {
    if {[info exists ui(parmsFrame)] && [winfo exists $ui(parmsFrame)]} {
      grid remove $ui(parmsFrame)
    }
    return
  }

  if {[info exists ui(parmsFrame)] && [winfo exists $ui(parmsFrame)]} {
    eval [list grid $ui(parmsFrame)] $ui(parmsGridSpec)
  }

  set pb $ui(parmsBody)
  foreach child [winfo children $pb] { destroy $child }

  # Match the Options block geometry exactly:
  #   column 0 = label
  #   column 1 = parm/control/error slice
  grid columnconfigure $pb 0 -weight 0
  grid columnconfigure $pb 1 -weight 1

  if {![info exists ::wbobj::STYLE_INIT(ReadonlyEntry)]} {
    ttk::style configure WbReadonly.TEntry
    ttk::style map WbReadonly.TEntry -fieldbackground {disabled #e8e8e8} -foreground {disabled #000000}
    set ::wbobj::STYLE_INIT(ReadonlyEntry) 1
  }

  ::wb::run::populateParmValue $t $pargs

  set row 0
  foreach a $pargs {
    set key      [$a hash]
    set hint     [$a hint]
    set labTxt   [$a label]
    set parmTxt  [$a parm]
    set errTxt   [$a optErr]
    set valueTxt [$a value]

    ttk::label $pb.l_${key}_$row -text $labTxt -style WbOptTitle.TLabel -width $::wbobj::OPT_LABEL_CH -anchor e
    grid $pb.l_${key}_$row -row $row -column 0 -sticky ne -padx {0 10}

    ttk::frame $pb.r_${key}_$row -style WbOpts.TFrame
    grid $pb.r_${key}_$row -row $row -column 1 -sticky ew

    set slice $pb.r_${key}_$row
    grid columnconfigure $slice 0 -minsize $::wbobj::OPT_PARM_PX -weight 0
    grid columnconfigure $slice 1 -minsize $::wbobj::OPT_CTRL_PX -weight 1
    grid columnconfigure $slice 2 -minsize $::wbobj::OPT_ERR_PX  -weight 0

    ttk::label $slice.parm -text $parmTxt -style WbOpts.TLabel -width $::wbobj::OPT_PARM_CH -anchor w
    ttk::frame $slice.ctrl -style WbOpts.TFrame
    ttk::label $slice.err  -text $errTxt -style WbOpts.TLabel -foreground red -anchor e -justify right

    grid $slice.parm -row 0 -column 0 -sticky w -padx {0 10}
    grid $slice.ctrl -row 0 -column 1 -sticky ew
    grid $slice.err  -row 0 -column 2 -sticky e -padx {10 0}

    set ctrl $slice.ctrl
    grid columnconfigure $ctrl 0 -weight 1

    set vname ::wb::run::parmDisp($key)
    set $vname $valueTxt

    ttk::entry $ctrl.ent -textvariable $vname -style WbReadonly.TEntry
    $ctrl.ent state disabled
    grid $ctrl.ent -row 0 -column 0 -sticky ew

    if {$hint ne "" && [info commands ::wb::run::tipAttach] ne ""} {
      ::wb::run::tipAttach $slice $hint
      ::wb::run::tipAttach $pb.l_${key}_$row $hint
      ::wb::run::tipAttach $slice.parm $hint
      ::wb::run::tipAttach $slice.ctrl $hint
      ::wb::run::tipAttach $slice.err  $hint
    }

    incr row
  }

  ::wb::run::updateParmsViewport $row
  ::wb::run::tipAttach .stat.parms.l "Parms (args) passed to next program run"
}

proc ::wb::run::populateParmValue {task pargs} {
  foreach a $pargs {
    set verb [$a get parmVerb]
    set parmDict [$a get parmDict]
    hilite -cyan "$verb $parmDict"

    switch -- $verb {
      lit {
        set litStr [dict get $parmDict litStr]
        $a set value $litStr
        $a set optErr ""
      }
      copy {
        set globName [dict get $parmDict globName]
        $a set value [$task glob $globName]
        $a set optErr ""
      }
      tern {
        set optLab [dict get $parmDict optLab]
        set optArg [$task findArg $optLab]
        if {$optArg eq ""} {
          $a set optErr "lost opt.label $optLab"
          $a set value "?"
        } else {
          set optTrue [$optArg get value]
          set globWhat globFalse
          if {$optTrue ne "" && $optTrue} {set globWhat globTrue}
          set globName [dict get $parmDict $globWhat]
          $a set value [$task glob $globName]
          $a set optErr ""
        }
      }
      eval {
        set str [dict get $parmDict evalStr]
        set str [::wb::run::evalCfgStr $task $str]
        $a set value $str
        $a set optErr ""
      }
    }
  }
}

proc ::wb::run::hideTaskSecParms {} {
  variable ui
  if {[info exists ui(parmsFrame)] && [winfo exists $ui(parmsFrame)]} { grid remove $ui(parmsFrame) }
}

proc ::wb::run::unhideTaskSecParms {} {
  if {[winfo exists .stat.parms]} { catch {pack .stat.parms -side top -fill x -padx 8 -pady {2 8}} }
}

proc ::wb::run::renderTaskSecBrief {t} {
  variable ui
  if {[info exists ui(briefFrame)] && [winfo exists $ui(briefFrame)]} {
    ::wb::run::_gridShow $ui(briefFrame) $ui(briefGridSpec)
  }
  ::wb::run::tipAttach .stat.brief.l "Results of last program run"
  ::wb::run::renderBriefIntoUI $t
}

proc ::wb::run::hideTaskSecBrief {} {
  variable ui
  if {[info exists ui(briefFrame)] && [winfo exists $ui(briefFrame)]} {
    ::wb::run::_gridHide $ui(briefFrame)
  }
}

proc ::wb::run::unhideTaskSecBrief {} {
  variable ui
  if {[info exists ui(briefFrame)] && [winfo exists $ui(briefFrame)]} {
    ::wb::run::_gridShow $ui(briefFrame) $ui(briefGridSpec)
  }
}

# ===============================================================================
#-=step                        Task Switch Maneagement
# ===============================================================================

proc ::wb::run::selectStep {idx} {
  variable curIndex
  variable ui

  set curIndex $idx

  set tasks [::wb::run::_tasks]
  if {$idx < 0 || $idx >= [llength $tasks]} { return }
  set t [lindex $tasks $idx]
  set seq [::wb::run::_taskField $t seq ""]

  # ~taskPath: current task's own folder, available to any parm via
  # eval:[glob ~taskPath]/... . Reseeded on every task switch since it's
  # per-task; same "~" persistence/UI-hiding convention as ~flowPath.
  variable form
  [$form globs] dset ~taskPath [$t taskDir]

  # Highlight selection in left list
  if {$seq ne "" && [info exists ui(stepRowFrm)] && [dict exists $ui(stepRowFrm) $seq]} {
    # clear previous highlight
    if {[info exists ui(selSeq)] && [dict exists $ui(stepRowFrm) $ui(selSeq)]} {
      set prow [dict get $ui(stepRowFrm) $ui(selSeq)]
      if {[winfo exists $prow]} {
        ::wb::run::_stepRowSetSelBg $prow 0
      }
    }
    set ui(selSeq) $seq
    set row [dict get $ui(stepRowFrm) $seq]
    if {[winfo exists $row]} {
      ::wb::run::_stepRowSetSelBg $row 1
      # attempt to scroll into view
      if {[info exists ui(stepCanvas)] && [winfo exists $ui(stepCanvas)]} {
        update idletasks
        set c $ui(stepCanvas)
        set bbox [$c bbox $row]
        if {$bbox ne ""} {
          lassign $bbox x1 y1 x2 y2
          set h [winfo height $c]
          if {$h > 0} {
            set region [$c cget -scrollregion]
            if {$region ne ""} {
              lassign $region rx1 ry1 rx2 ry2
              set totalH [expr {$ry2 - $ry1}]
              if {$totalH > 0} {
                set frac [expr {double($y1)/double($totalH)}]
                $c yview moveto $frac
              }
            }
          }
        }
      }
    }
  }

  ::wb::run::logMsg "Switched to Step $seq: [::wb::run::_taskField $t title \"\"] ([::wb::run::_taskField $t name \"\"])"
  log "Sw task [$t name] seq [$t seq] log [$t logPath]"
  variable oldTask
  if {$oldTask ne ""} {
    ::wb::run::purgePrevTask $oldTask
    set oldTask ""
  }
  set d [::wb::run::loadOptsDict $t]
  ::wb::run::applyOptsDictToTask $t $d

  # A manual task's checkboxes are "did I do this?" confirmations tied to
  # its own last completion. If this task is now STALE (something later
  # in the sequence ran after it did, per refreshStepStates), those
  # checkmarks -- just loaded from options.json above -- are leftover
  # evidence from a run that's no longer trusted; showing them still
  # checked when the task becomes current again would silently claim
  # "already done" for steps that may need re-doing. Reset them here,
  # the moment the task becomes current, not proactively for every
  # stale manual task whenever anything anywhere re-renders -- this is
  # deliberately scoped to selectStep specifically.
  if {![::wb::run::_resetStaleManualCheckboxes $t]} {
    ::wb::run::renderTask $t
  }
  ::wb::run::updateRunTaskLink
  ::wb::run::updateViewLogLink
  ::wb::run::scheduleSaveDyn
  ::wb::run::rebuildMainMenu
}

# Reset a stale manual task's checkbox opts to unchecked, both the live
# control (so it's visible immediately) and options.json (so the reset
# survives a restart, or anything reading that file directly, instead of
# only being a cosmetic fix until the next real Run Task). Called from
# selectStep specifically -- when the task becomes current -- not from
# refreshStepStates, which runs on every render of every task and would
# reset a stale manual task's checkboxes as soon as it goes stale even
# while the user is looking at something else entirely.
#
# Guarded against clobbering in-progress work: if options.json is newer
# than staleRefTS (the point this task's staleness is judged against),
# the user has already started re-checking boxes since it went stale --
# stepState stays STALE until the task is actually re-run, so without
# this guard, simply navigating away and back while redoing the
# checkboxes would wipe them out on every visit.
#
# Returns 1 if a reset (and the persist + render it triggers via
# persistOptsNow) actually happened, so the caller can skip its own
# redundant render call; 0 if there was nothing to do.
proc ::wb::run::_resetStaleManualCheckboxes {t} {
  if {[$t type] ne "manual"} { return 0 }
  if {[$t stepState] ne "STALE"} { return 0 }

  # If options.json is already newer than the point this task's
  # staleness is being judged against (staleRefTS, set by
  # refreshStepStates), the user has already touched this task's
  # checkboxes since it went stale -- i.e. they're in the middle of
  # redoing the manual confirmation themselves. Don't wipe that out from
  # under them. staleRefTS is deliberately not "the immediately
  # preceding task's timestamp" -- flows can skip steps, so it's the
  # actual freshness high-water-mark refreshStepStates computed this
  # task against, which may be several tasks back.
  set refTS [$t staleRefTS]
  if {$refTS ne "" && $refTS > 0} {
    set optsPath [file join [$t taskDir] "options.json"]
    set optsTS [::wb::run::getFileDate $optsPath]
    if {$optsTS > $refTS} {
      hilite -darkcyan "skip stale-manual reset for [$t name] -- options.json ($optsTS) newer than staleRefTS ($refTS), user already redoing it"
      return 0
    }
  }

  set didReset 0
  foreach a [$t getTypedArgs opt] {
    if {[$a uiType] ne "check"} { continue }
    if {[isTrue [$a value]]} {
      $a setValue 0
      # Also update the live UI-bound variable directly: Arg's own
      # value and the checkbutton's -variable binding are two separate
      # things (see fs-objs.tcl's uiRender) -- setValue alone updates
      # only the former. Built directly from the public "hash" method
      # rather than calling _uiVarName: TclOO leaves leading-underscore
      # method names unexported by default, so _uiVarName is callable
      # via "my" from inside the Arg class but not as "$a _uiVarName"
      # from out here -- confirmed directly, not guessed. Same string
      # _uiVarName itself builds internally. If this task's panel
      # happens to already be rendered, this makes the box visibly
      # uncheck immediately; persistOptsNow's own re-render below
      # covers the general case regardless.
      catch {
        set vname "::wb::argVal([$a hash])"
        if {[info exists $vname]} { set $vname 0 }
      }
      set didReset 1
    }
  }

  if {$didReset} {
    hilite -darkcyan "reset stale manual checkboxes for [$t name]"
    ::wb::run::persistOptsNow $t
  }
  return $didReset
}

proc ::wb::run::purgePrevTask {t} {
  log "purge task [$t name]"
  $t set hooksTS 0
  ::wb::run::flushTaskHooks $t
}

# ---------------------------------------------------------------------------
# checkTaskRuntime t
# Verify the external runtime a task's engine type depends on is actually
# present, BEFORE the task is ever run. Returns "" if OK, else a short
# setup-error message (surfaced via the same setupErr field/UI as the
# "hooks required but not found" check below).
#
# Mirrors the $ttype routing table already in ::wb::exec::prepTaskExec --
# add a new branch here (and there) for each future engine type (python,
# csharp/dotnet, node, ...).
#
# java: consistent with how ::wb::exec::handleJavaASync actually launches
# Java today (fs-exec.tcl) -- $env(JAVA_HOME)/bin/java(.exe). Checked here
# the same way, not via PATH/auto_execok, so a task can't pass this check
# and still fail to launch for a different reason.
# ---------------------------------------------------------------------------
proc ::wb::run::checkTaskRuntime {t} {
  set ttype [$t type]

  if {$ttype eq "java"} {
    if {![info exists ::env(JAVA_HOME)] || $::env(JAVA_HOME) eq ""} {
      return "Java runtime not found"
    }
    set javaExe [file join $::env(JAVA_HOME) bin java]
    if {![file exists $javaExe] && ![file exists "${javaExe}.exe"]} {
      return "Java runtime not found"
    }
  }
  # Future engine types:
  #   elseif {$ttype eq "python"} { ... }
  #   elseif {$ttype eq "csharp"} { ... }
  #   elseif {$ttype eq "node"}   { ... }

  return ""
}

# Hot-load task option hook code from "<task-name>-hooks.tcl".
# Hooks are sourced into the ::wb::opt::hook:: namespace.
#
# Contract (assumed fields on Task object):
#   hooksTS   ;# 0 = unknown/not loaded, -1 = no hooks needed, >0 = file mtime loaded
#   bHooksOK  ;# boolean: last load OK
#   setupErr  ;# string: setup error message (used by Setup panel)
#
# NOTE: This is intentionally a "hot loader" so hook edits take effect without restarting WB.
proc ::wb::run::loadTaskHooks {t} {

  # Quick exit if we've already proven no hooks are needed.
  if {[$t hooksTS] == -1} {
    return
  }
  $t set setupErr "" ;# reset - assume this is start of task rebuild loop

  #hilite -cyan "loading task hooks [$t name] TS=[$t hooksTS]"
  # Determine whether hooks are required by examining option Args.
  # Policy: if any opt Arg has a non-empty bindName, hooks are required.
  set needHooks 0
  if {[$t hooksTS] == 0} {
    set optArgs [$t getTypedArgs opt]
    foreach a $optArgs {
      if {[string trim [$a custVal]] ne ""} {
        set needHooks 1
        break
      }
    }
    if {!$needHooks} {
      $t set hooksTS -1
      $t set bHooksOK 1
      return
    }
  }


  set taskName [$t name]
  set hooksPath [file join [$t taskDir] "${taskName}-hooks.tcl"]

  #hilite -cyan "reload hooks $taskName $hooksPath $needHooks"

  if {![file exists $hooksPath]} {
    $t set setupErr "Hooks required but not found: $hooksPath"
    $t set bHooksOK 0
    $t set hooksTS 0
    hilite -red "hooksErr: [$t setupErr]"
    return
  }

  set fts [file mtime $hooksPath]

  # If timestamp matches and last load was OK, we're current.
  if {[$t hooksTS] == $fts && [$t bHooksOK]} {
    return
  }

  # Reload needed (newer/older/different timestamp).
  ::wb::run::flushTaskHooks $t

  if {[catch { source $hooksPath } perr]} {
    $t set setupErr "Hook source failed ($hooksPath): $perr"
    $t set bHooksOK 0
    $t set hooksTS 0
    return
  }

  $t set bHooksOK 1
  $t set hooksTS $fts
  return
}

# Flush option hook procs from memory so task switches cannot collide on names.
# Current strategy: wipe the entire ::wb::opt::hook namespace.
proc ::wb::run::flushTaskHooks {t} {
  set ns ::wb::opt::hook
  if {![namespace exists $ns]} {
    namespace eval $ns {}
    return
  }

  foreach p [info procs ${ns}::*] {
    catch { rename $p "" }
  }
  return
}



# ===============================================================================
#-=task                            Render Task Panel
# ===============================================================================

# This is the workhorse of the system. Called when
# (1) We have changed task step. - called with all
# (2) We have updated a subpanel (such as options) that may affect layout
#
# Not that the globs panel is treated as part of this maneagement design.
#
#
#
#
#
#

set ::wb::run::RENDER_ORDER {globs desc setup status options parms brief}


proc ::wb::run::renderTask {t {secs "all"}} {
  variable ui
  variable curIndex
  variable oldTask

  variable RENDERING                ;#rentrancy lock
  if {$RENDERING} { return }
  set RENDERING 1

  set oldTask $t

  # Runtime-availability check takes precedence over the hooks check: if
  # the engine's runtime isn't even present, don't bother evaluating hook
  # wiring, and don't let loadTaskHooks's own setupErr reset (which it
  # skips on its cached fast-path, but not otherwise) clobber this.
  set runtimeErr [::wb::run::checkTaskRuntime $t]
  if {$runtimeErr ne ""} {
    $t set setupErr $runtimeErr
  } else {
    ::wb::run::loadTaskHooks $t
  }

  if {$secs eq "all"} {
    log "render [$t name] all"
  }

  try {

    if {$secs eq "all"} {
      ::wb::run::validateOptions $t
      ::wb::run::renderTaskSecGlobs $t
      ::wb::run::renderTaskSecDesc $t
      ::wb::run::renderTaskSecSetup $t
      ::wb::run::renderTaskSecStatus $t
      ::wb::run::renderTaskSecOptions $t
      ::wb::run::renderTaskSecParms $t
      ::wb::run::renderTaskSecBrief $t
      ::wb::run::_layoutTaskBody ;# pack stuff together
      ::wb::run::updateRunTaskLink ;# update links
    } elseif {$secs eq "post-run"} {
      ::wb::run::refreshBriefStatusForTask $t 1  ;# v97: force -- see proc header comment
      ::wb::run::renderTaskSecGlobs $t
      ::wb::run::renderTaskSecDesc $t
      ::wb::run::renderTaskSecStatus $t
      ::wb::run::renderTaskSecBrief $t
      ::wb::run::_layoutTaskBody ;# pack stuff together

      if {[$t runprops] ne ""} {
        set runprops [$t runprops]
        set manageApp [expr {[dict exists $runprops manageApp] ? [dict get $runprops manageApp] : ""}]
        if {$manageApp ne ""} {
          if {[$t compState] eq "GOOD"} {
              ::wb::exec::manageApp true $t $manageApp ;# start application
          } else {
             hilite -red "::wb::exec::manageApp $manageApp bypassed"
          }
        }
        set procExit [expr {[dict exists $runprops procExit] ? [dict get $runprops procExit] : ""}]
        if {$procExit eq "post" && [$t compState] eq "GOOD"} {
          set ctx [::wbobj::buildCtx $t]
          # Source and invoke exit
          if {[catch {
            namespace eval ::wb::exec::exit {}  ;# ensure exists
            set tclPath [file join [$t taskDir] "[$t name]-postproc.tcl"]
            log "::wb::exec::exit::procExit $tclPath"
            source $tclPath
            ::wb::exec::exit::postProc $ctx
          } err]} {
            set msg "procExit:post source failed: $err"
            hilite -red "::wb::exec::exit::procExit $procExit failed $msg"
          }
        }
      }
    } else {
      hilite -red "sections $secs not implemented in renderTask"
    }

    ::wb::run::refreshStepStates
    ::wb::run::refreshStepList

  } finally {
    set RENDERING 0
  }
}


proc ::wb::run::validateOptions {t} {
  set args [$t getTypedArgs opt]
  set optErrs 0
  hilite -darkcyan "validate options [$t name]"
  foreach a $args {
    $a set optErr ""
    switch -exact -- [$a uiType]  {
      text -
      file -
      directory {
        set noun [expr {[$a uiType] eq "directory" ? "folder" : "file"}]
        if {[$a bReqd] && [$a notVal value]} {
          $a set optErr "$noun is required"
        }
        if {[$a notVal optErr] && [lsearch -exact {file directory} [$a uiType]] >= 0 && [$a hasVal value]} {
          set modeVar [::wb::run::argPathModeVar $a]
          set mode old
          if {[info exists $modeVar]} { set mode [set $modeVar] }
          if {![::wb::run::_argPathValidateMode $a [$a value] $mode]} {
            switch -- $mode {
              old { $a set optErr "$noun must exist" }
              new { $a set optErr "$noun must not exist" }
              default { }
            }
          }
        }
        if {[$a notVal optErr] && [$a hasVal value] && [$a hasVal regexPat]} {
          set pat [string trim [$a regexPat]]
          set val [$a value]
          if {[catch {set ok [regexp -- $pat $val]} err]} {
            $a set optErr "malformed regex"
            hilite -red "malformed regex |$pat| err=|$err|"
          } elseif {!$ok} {
            set msg [$a regexMsg]
            $a set optErr [expr {$msg ne "" ? $msg : "regex failed"}]
          }
        }
        if {[$a notVal optErr] && [$a hasVal custVal]} {
           if {[$t bHooksOK]} {
             $a set hooksProc ""
             set fq "::wb::opt::hook::[$a custVal]"
             if {[llength [info procs $fq]]} {
               $a set hooksProc $fq
             } else {
               $a set optErr "Missing hook: $fq"
             }
          } else {
            $a set optErr "custVal [$a custVal] not available due to hooks load error"
          }
          if {[$a hasVal hooksProc]} {
            set cmd [$a hooksProc]
            set ctx [::wbobj::buildCtx $t $a]
            $cmd $ctx
          }
        }
        if {[$a optErr] ne ""} {incr optErrs}
      }
    }
    $t set optErrCnt $optErrs
  }
  # hilite -cyan "validate cycle completed [llength $args] optErrs=$optErrs";
}

# Re-stack the status-body section frames so hidden sections collapse upward.
# Brief is treated as the variable-sized section and is always shown (even if empty),
# so the UI remains stable and the user always has a "bottom" area.
proc ::wb::run::_layoutTaskBody {} {
  variable ui

  set body .stat.body
  if {![winfo exists $body]} { return }

  # Section order in the status body (row 0 is the Task: row)
  set order {desc setupErr status options parms brief}

  # Reset row weights (we will re-assign only brief to stretch)
  for {set r 0} {$r < 20} {incr r} {
    catch { grid rowconfigure $body $r -weight 0 }
  }

  set row 1
  set briefRow -1
  foreach n $order {
    set f ""
    switch -- $n {
      desc     { catch { set f $ui(descFrame) } }
      setupErr { catch { set f $ui(setupErrFrame) } }
      status   { catch { set f $ui(statusFrame) } }
      options  { catch { set f $ui(optsFrame) } }
      parms    { catch { set f $ui(parmsFrame) } }
      brief    { catch { set f $ui(briefFrame) } }
    }
    if {$f eq "" || ![winfo exists $f]} { continue }

    # Brief is always shown (stable UI + variable sized area)
    set show [expr {$n eq "brief" ? 1 : ([info exists ui(secHas,$n)] ? $ui(secHas,$n) : [winfo ismapped $f])}]

    if {!$show} {
      catch { grid remove $f }
      continue
    }

    # Match original look/spacing from buildUI while allowing dynamic re-rowing
    set sticky "ew"
    set pady ""
    if {$n eq "setupErr"} { set pady 2 }
    if {$n eq "status"}   { set pady 2 }
    if {$n eq "options"}  { set pady {6 0} }
    if {$n eq "parms"}    { set pady {6 0} }
    if {$n eq "brief"}    { set sticky "nsew"; set pady {6 0}; set briefRow $row }

    if {$pady eq ""} {
      grid $f -in $body -row $row -column 0 -columnspan 2 -sticky $sticky
    } else {
      grid $f -in $body -row $row -column 0 -columnspan 2 -sticky $sticky -pady $pady
    }

    incr row
  }

  # Let the brief section take remaining vertical space.
  if {$briefRow >= 0} {
    catch { grid rowconfigure $body $briefRow -weight 1 }
  }
}

# ===============================================================================
#-=int                              Task Run Interfaces
# ===============================================================================


proc ::wb::run::runTask {} {
  variable runBusy
  variable curIndex
  # Close any open log window for this task; runlog will become stale
  ::wb::run::closeLogWinIfOpen $curIndex
  ::wb::run::updateViewLogLink
  ::wb::run::logMsg "Run Task (dummy) started"
  set runBusy 1
  ::wb::run::updateRunTaskLink
  update idletasks
  after 450
  ::wb::run::logMsg "Run Task (dummy) completed"
  set runBusy 0
  ::wb::run::updateRunTaskLink
}

# Reload generated system binds if wb-reg-sys.tcl has changed.
# Tracks last reload time in ::wb::run::fileDateRegSys.
proc ::wb::run::loadRegSysBindCode {} {
  variable fileDateRegSys
  variable genDir
  if {![info exists fileDateRegSys]} { set fileDateRegSys 0 }

  # Load bind implementations (generated system binds)
  set sysBinds [file join $genDir wb-reg-sys.tcl]
  #log "checking $genDir $sysBinds"
  if {![file exists $sysBinds]} { return }

  set mtime [file mtime $sysBinds]
  if {$mtime <= $fileDateRegSys} { return }

  if {[catch {source $sysBinds} err]} {
    puts stderr "ERROR: failed to source $sysBinds : $err"
    return
  }

  set fileDateRegSys $mtime
  set ts [clock format $mtime -format "%Y-%b-%d %H:%M:%S"]
  hilite -cyan "Reloaded reg-sys bind code: $sysBinds  ($ts)"
}

proc ::wb::run::argEntryFocusIn {vname phFlag place} {
  if {[info exists $phFlag] && [set $phFlag] && [set $vname] eq $place} {
    set $vname ""
    set $phFlag 0
  }
}


proc ::wb::run::argEntryFocusOut {vname phFlag place} {
  if {[set $vname] eq "" && $place ne ""} {
    # Do not let placeholder writes trigger traces / persistence
    variable UI_BUILDING
    set _old $UI_BUILDING
    set UI_BUILDING 1
    set $vname $place
    set $phFlag 1
    set UI_BUILDING $_old
  }
}

proc ::wb::run::onTextFocusOut {taskObj vname phFlag place} {
  ::wb::run::argEntryFocusOut $vname $phFlag $place
  if {$taskObj ne ""} {
    ::wb::run::persistOptsNow $taskObj
  }
}

proc ::wb::run::onPathUiChange {argObj vname} {
  if {[info commands $argObj] eq ""} { return }
  set val ""
  if {[info exists $vname]} { set val [set $vname] }
  catch { $argObj set value $val }
  set t ""
  catch { set t [$argObj task] }
  if {$t ne ""} {
    ::wb::run::persistOptsNow $t
  }
}

proc ::wb::run::_fileTypeList {spec} {
  set out {}
  if {$spec eq "" || $spec eq "*"} { return [list [list "All Files" "*"]] }
  foreach pat [split $spec ";"] {
    set pat [string trim $pat]
    if {$pat eq ""} { continue }
    lappend out [list $pat [list $pat]]
  }
  if {![llength $out]} {
    lappend out [list "All Files" "*"]
  }
  return $out
}

proc ::wb::run::browsePath {argObj vname modeVar} {
  if {[info commands $argObj] eq ""} { return }
  set uiType [$argObj uiType]
  set mode "old"
  if {[info exists $modeVar] && [set $modeVar] ne ""} { set mode [set $modeVar] }

  set cur ""
  if {[info exists $vname]} { set cur [set $vname] }

  set opts [list -title "Select [string totitle $uiType]"]
  if {$cur ne ""} {
    set initDir ""
    if {$uiType eq "directory"} {
      if {[file exists $cur] && [file isdirectory $cur]} { set initDir $cur }
    } else {
      if {[file exists $cur]} {
        if {[file isdirectory $cur]} {
          set initDir $cur
        } else {
          set initDir [file dirname $cur]
        }
      }
    }
    if {$initDir ne ""} { lappend opts -initialdir $initDir }
  }

  if {$uiType eq "file"} {
    lappend opts -filetypes [::wb::run::_fileTypeList [$argObj fileType]]
    if {$mode eq "new"} {
      set picked [tk_getSaveFile {*}$opts]
    } else {
      set picked [tk_getOpenFile {*}$opts]
    }
  } else {
    set picked [tk_chooseDirectory {*}$opts]
  }

  if {$picked eq ""} { return }
  set $vname $picked
  ::wb::run::onPathUiChange $argObj $vname
}

proc ::wb::run::argComboSelected {dvar vname disp vals} {
  set sel [set $dvar]
  set idx [lsearch -exact $disp $sel]
  if {$idx < 0} {
    set $vname ""
  } else {
    set $vname [lindex $vals $idx]
  }
}

proc ::wb::run::argToggleBool {vname} {
  # Treat "", 0, false as false; anything else as true.
  set cur 0
  if {[info exists $vname]} {
    set cur [expr {[string is boolean -strict [set $vname]] ? [set $vname] : ([set $vname] ne "" && [set $vname] ne "0")}]
  }
  set $vname [expr {!$cur}]
}

proc ::wb::run::_argPathValidateMode {argObj path mode} {
  set path [string trim $path]
  if {$path eq "" || $mode eq "any"} { return 1 }
  set isDir [expr {[$argObj uiType] eq "directory"}]
  if {$mode eq "old"} {
    if {$isDir} { return [expr {[file exists $path] && [file isdirectory $path]}] }
    return [expr {[file exists $path] && ![file isdirectory $path]}]
  }
  if {$mode eq "new"} { return [expr {![file exists $path]}] }
  return 1
}

proc ::wb::run::_argPathRefreshHistory {argObj vname} {
  if {$vname eq "" || ![info exists $vname]} { return }
  if {![winfo exists .]} { return }
  set vals [::wb::run::argHistoryValues $argObj]
  ::wb::run::_updateCombosForVar . $vname $vals
}

proc ::wb::run::argPathAccept {argObj vname modeVar} {
  if {[info commands $argObj] eq ""} { return }
  set value [string trim [expr {[info exists $vname] ? [set $vname] : ""}]]
  if {[info exists $vname]} { set $vname $value }
  catch { $argObj setValue $value }
  set mode old
  if {[info exists $modeVar]} { set mode [set $modeVar] }
  if {[::wb::run::_argPathValidateMode $argObj $value $mode]} {
    catch { ::wb::run::_argHistoryRemember $argObj $value }
    catch { ::wb::run::_argPathRefreshHistory $argObj $vname }
  }
  set taskObj ""
  catch { set taskObj [$argObj task] }
  if {$taskObj ne ""} { ::wb::run::persistOptsNow $taskObj }
}

proc ::wb::run::argPathFocusOut {argObj vname modeVar} {
  ::wb::run::argPathAccept $argObj $vname $modeVar
}

proc ::wb::run::argBrowsePath {argObj vname modeVar} {
  if {[info commands $argObj] eq ""} { return }
  set uiType [$argObj uiType]
  set mode old
  if {[info exists $modeVar]} { set mode [set $modeVar] }
  set cur [expr {[info exists $vname] ? [string trim [set $vname]] : ""}]
  set initialdir ""
  if {$cur ne ""} {
    if {$uiType eq "directory"} {
      if {[file exists $cur] && [file isdirectory $cur]} { set initialdir $cur }
    } else {
      if {[file exists $cur]} {
        if {[file isdirectory $cur]} { set initialdir $cur } else { set initialdir [file dirname $cur] }
      } else {
        set parent [file dirname $cur]
        if {$parent ne "" && [file exists $parent] && [file isdirectory $parent]} { set initialdir $parent }
      }
    }
  }
  set picked ""
  if {$uiType eq "directory"} {
    set args [list tk_chooseDirectory -title "Select folder"]
    if {$initialdir ne ""} { lappend args -initialdir $initialdir }
    set picked [uplevel #0 $args]
  } else {
    set args [expr {$mode eq "new" ? [list tk_getSaveFile -title "Select file"] : [list tk_getOpenFile -title "Select file"]}]
    if {$initialdir ne ""} { lappend args -initialdir $initialdir }
    set ftypes [::wb::run::_argFileTypes $argObj]
    if {[llength $ftypes]} { lappend args -filetypes $ftypes }
    set picked [uplevel #0 $args]
  }
  if {$picked eq ""} { return }
  set $vname $picked
  ::wb::run::argPathAccept $argObj $vname $modeVar
}


# ===============================================================================
#-=lift                            Mainline - perform liftoff
# ===============================================================================

proc ::wb::run::fetchScriptDir {} {
  variable scriptDir
  return $scriptDir
}

proc ::wb::run::loadIconFolder {} {
  set srcDir [::wb::run::fetchScriptDir]
  set iconDir [file normalize [file join $srcDir ".." icons]]

  if {![file isdirectory $iconDir]} {
    error "Icon folder not found: $iconDir $srcDir"
  }

  set iconDict [dict create]

  foreach path [lsort [glob -nocomplain -directory $iconDir *.png]] {
    set fileName [file tail $path]
    set img [image create photo -file $path]
    dict set iconDict $fileName $img
  }

  return $iconDict
}

#---------------------------------------------------------------------
# ::wb::run::bootRuntime is used to get the engine running.
#
# (1) We load the cfg file
#
# (2) We load the dynamic file that holds window sizes, current task, etc
#
# (3) If it exists we load the <wb-name>-setup.tcl
#
proc ::wb::run::bootRuntime {cfgPath} {

  variable curIndex
  variable scriptDir
  variable runBusy
  variable dynData
  set curIndex 0
  set runBusy 0

  hilite -green "booting runtime using $cfgPath"


  set cfgDict [jsonFileAsDict $cfgPath]
  # Load bind implementations (generated system binds)
  if {![info exists ::wb::run::genDir] || $::wb::run::genDir eq ""} {
    set scriptDir [file dirname [file normalize [info script]]]
    set ::wb::run::genDir [file normalize [file join $scriptDir ".." "gen"]]
  }
  ::wb::run::loadRegSysBindCode

  # Load registry JSON for parmId -> bindName mapping
  set ::wb::run::regParmsById [dict create]
  set regJson [file join $::wb::run::genDir wb-reg-sys.json]
  if {[file exists $regJson]} {
    if {![catch {set regD [jsonFileAsDict $regJson]} _]} {
      if {[dict exists $regD parms]} {
        foreach e [dict get $regD parms] {
          catch {
            set pid [dict get $e parmId]
            dict set ::wb::run::regParmsById $pid $e
          }
        }
      }
    }
  }

  log "title [dict get $cfgDict title]"

  set formObj [::wbobj::Form new $cfgDict $cfgPath]

  

  hilite -green "Built: " -white [$formObj toString] "scriptDir $scriptDir"


  variable form
  set form $formObj
  ::wb::run::loadDyn

  set globs [$form globs]
  $globs set dict [dict get $dynData globs]
  dict unset dynData globs

  # ~flowPath: flow's own base directory, available to any parm via
  # eval:[glob ~flowPath]/... . Computed once here (doesn't change during
  # a run). "~" prefix keeps it out of persistence (Globs dset/unset skip
  # setDirty for "~" keys) and out of the user-facing globs list
  # (globsFrame render skips "~"/"+" keys) -- same convention as ~taskPath
  # below in selectStep.
  $globs dset ~flowPath [file dirname $cfgPath]

  # run setup
  set cfgDir [file dirname $cfgPath]
  set setupTCL [file join $cfgDir "[file tail $cfgDir]-setup.tcl"]
  hilite -cyan "setupTCL $setupTCL"

  if {[file exists $setupTCL]} {
    source $setupTCL
    set ctx [::wbobj::buildCtx $form]
    ::wb::setup::main $ctx
  }

  variable iconCache
  set iconCache [::wb::run::loadIconFolder]

  hilite -green "loaded [dict size $iconCache] icons"

  if {[isTrue [$form glob "+wb-objs-dump"]]} {
    set dfDir  "d:/1/tcl-devp"
    set dfPath "d:/1/tcl-devp/tcl-run-objs.txt"
    if {[file isdirectory $dfDir]} {
      set fh [open $dfPath w]
      puts $fh [$formObj dumpStr {tasks args places values paths}]
      flush $fh
      close $fh
      hilite -yellow "wrote $dfPath"
    } else {
      hilite -yellow " ObjDump NOT Written: directory does not exist $dfDir"
    }
  }

  if {0} {
    hilite -red "---- Doing Palate Test ----"
    hilite -black       "30        black       30"
    hilite -darkblue    "34        darkblue    34"
    hilite -darkgreen   "32        darkgreen   32"
    hilite -darkcyan    "36        darkcyan    36"
    hilite -darkred     "31        darkred     31"
    hilite -darkmagenta "35        darkmagenta 35"
    hilite -darkyellow  "33        darkyellow  33"
    hilite -gray        "37        gray        37"
    hilite -darkgray    "90        darkgray    90"
    hilite -blue        "94        blue        94"
    hilite -green       "92        green       92"
    hilite -cyan        "96        cyan        96"
    hilite -red         "91        red         91"
    hilite -magenta     "95        magenta     95"
    hilite -yellow      "93        yellow      93"
    hilite -white       "97        white       97"
    hilite -red "---- end palate test ----"
  }

  ::wb::run::buildUI $formObj

  #exit 0
}

if {$argc < 1} {
  # default to demo in current folder (/mnt/data) when running here
  #set cfgPath [file join [file dirname [info script]] "psec-demo-cfg.json"]
  hilite -red "fs-run.tcl requires cfg argument to define WB"
  exit 1
} else {
  set cfgPath [lindex $argv 0]
}


mainCatch {
  ::wb::run::bootRuntime $cfgPath
}


#set ::wb::form [::wb::run::loadFlowConfig $cfgPath]
#::wb::run::buildUI
#focus -force .



# ---- Execution Engine Wiring (v47) -----------------------------------------

# NOTE: fs-exec.tcl is loaded earlier in this file in v46 base; do not reload it here.

# Runner state while executing
namespace eval ::wb::run {
  variable runBusy 0
}

# Called by execution engine at the start of an execution.
proc ::wb::run::signalTaskStart {execResp} {
  variable runBusy
  set runBusy 1
  ::wb::run::updateRunTaskLink
  ::wb::run::updateViewLogLink

}

# Called by execution engine when an async execution ends (and may also be used for sync).
proc ::wb::run::signalTaskEnd {execResp} {
  variable runBusy
  variable form
  set runBusy 0

  set task [$execResp task]
  if {[$task type] eq "manual"} { # t/off check boxes
    foreach arg [$task getTypedArgs opt] {
      if {[$arg uiType] eq "check"} {
        $arg setValue ""
        hilite -red "t/off check box [$arg uiValue]"
      }
    }
  }


  ::wb::run::logMsg "Task [$task name] ended. Duration [$execResp duration]"
  ::wb::run::updateRunTaskLink
  ::wb::run::updateViewLogLink

  set globs [$form globs]
  if {[$globs needsPersist]} {
    $globs set needsPersist false
    hilite -cyan "persist on dirty"
    ::wb::run::saveDynNow
  }
  if {[catch {::wb::run::renderTask $task "post-run"} err]} { hilite -red $err }

}

proc ::wb::run::updateTaskListStates {task} {
}

# Generated 2026-jul-07 courtesy of Claude (claude.ai)
# Appends a single-line proof-of-work record to $::env(runlog), used for
# SR&ED activity evidence. Fails silently (with a logMsg note) if the
# runlog env var isn't set or the file can't be opened, so a missing/bad
# env(runlog) never blocks the actual Run Task action.
proc ::wb::run::_powLogAppend {task} {
  if {![info exists ::env(runlog)] || $::env(runlog) eq ""} { return }

  set sys "UNKNOWN"
  if {[info exists ::env(COMPUTERNAME)]} { set sys $::env(COMPUTERNAME) }

  set now      [clock seconds]
  set curDate  [clock format $now -format "%Y%m%d"]
  set curTime  [clock format $now -format "%H:%M:%S"]
  set pwdNow   [pwd]
  set app      "fs-run.tcl"
  set flow     [::wb::run::_taskField $task taskDir ""]
  set taskName [::wb::run::_taskField $task name ""]
  set taskType [::wb::run::_taskField $task type ""]

  set line "$sys $curDate $curTime $pwdNow $app $flow $taskName $taskType"

  if {[catch {
    set fd [open $::env(runlog) a]
    puts $fd $line
    close $fd
  } err]} {
    ::wb::run::logMsg "Proof-of-work log append failed: $err"
  }
}

# Run Task click handler: call execution engine with current task.
proc ::wb::run::onRunTaskClick {} {

  if {![::wb::run::canRunCurrent]} {
    # v99: distinguish an unmet dependsOn from the generic busy/other case
    # -- cheap, and it's exactly the kind of thing a confused successor
    # operator benefits from seeing spelled out rather than a flat "DISABLED".
    set reason "busy"
    catch {
      set tasks [::wb::run::_tasks]
      variable curIndex
      set t [lindex $tasks $curIndex]
      if {![::wb::run::_taskDependsSatisfied $t]} { set reason "unmet dependency" }
    }
    ::wb::run::logMsg "Run Task clicked but is DISABLED ($reason)"
    return
  }

  variable curIndex
  set tasks [::wb::run::_tasks]
  if {![info exists curIndex] || $curIndex < 0 || $curIndex >= [llength $tasks]} {
    ::wb::run::logMsg "Run Task: no task selected"
    return
  }
  set task [lindex $tasks $curIndex]
  ::wb::run::_powLogAppend $task
  ::wb::run::persistOptsNow $task

  if {![llength [info commands ::wb::exec::prepTaskExec]]} {
    ::wb::run::logMsg "Execution engine not loaded: ::wb::exec::prepTaskExec not found"
    return
  }

  set respStr [::wb::exec::prepTaskExec $task]
  if {$respStr eq ""} {
    set execResp [::wb::exec::fireTaskExec $task]
  } else {
    if {[catch {::wb::run::renderTask $task "post-run"} err]} { hilite -red $err }
  }

  # Now we update renderTask
  ##if {[catch {::wb::run::renderTask $task "mid-run"} err]} { hilite -red $err }

}
