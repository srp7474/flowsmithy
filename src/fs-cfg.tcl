# Generated 2026-jul-29 courtesy of Claude (claude.ai)
# fs-cfg.tcl - v179
# Changelog (skinny; full detail in CHANGELOG.md):
#   v179 (2026-jul-29): removed the duplicate requireTclFlows definition -- canonical version now lives in tcl-lib.tcl (one source of truth: flowsmithy.cfg)
#   v178 (2026-jul-28): changelog moved to CHANGELOG.md; this header now a skinny per-version log
#   v177 (2026-jul-27): fixed Task/Flow Help showing stale content when re-opened for a different task/flow
#   v176 (2026-jul-27): close a gap in fs-help.tcl v33's cross-file help:/help-same: link tracking
#   v175 (2026-jul-21): fixed Apply never enabling after editing staleAfter -- Steve caught this immediately on testing v174
#   v174 (2026-jul-21): added Configurator UI for staleAfter (ISSUE-14), task mode, first task only
#   v173 (2026-jul-21): removed the dead registry-file load entirely from bootConfigurator -- regJsonPath/regDict (and the "variable regDict {}"...
#   v172 (2026-jul-17): package require Tk 8.6 -> Tk 8.6 9, so this loads under either Tcl/Tk 8.6 or 9.x (single-version pin was refusing to start at all...
#   v171: Removed cloneTaskFromSameFlow and cloneTaskFromOtherFlow -- confirmed dead code
#   v170: main window icon lookup switched from $::env(TCL_HOME) to [fsCfgGet home.dir]
#   v169: Labeling consistency: the mode identifier "runtime" renamed to "runprop" everywhere it's live code (the Cfg Mode select box's...
#   v168: REVERT of v167. v167 changed runprops from a plain dict to a list of {key,value} objects based on one non-conforming sample...
#   v166: Edit Runprop examples now filtered to the locked key's own group only -- the key is effectively a "type" once it's fixed (can't...
#   v165: Dropped the recipe examples from _runpropExamples -- recipes are a task-level concept only, not a useful runprops pattern
#   v164: Removed Clone from runtime mode too (added to the same hide-list as flow/options/parms in uiUpdateGlobalButtons)
#   v163: Edit Parm implemented by reusing the Add Parm dialog: openAddParmWin now takes an optional editIndex. Add mode is unchanged
#   v162: Removed Clone Parm: uiUpdateGlobalButtons now hides the global Clone button for parms mode too (same as flow/options)
#   v161: removed Clone Option entirely
#   v160: Rename Task dialog: buttons were getting clipped off the bottom whenever a validation error appeared
#   v159: Rename Task dialog: the error-message label had a hardcoded -height 2 (text lines), but the actual validation message needs 3 ...
#   v158: Fixed "invalid command name ::wb::new::validateFlowName" on Rename: fs-cfg.tcl doesn't source fs-new.tcl, so that proc was never...
#   v157: Task mode no longer has an Edit Task button -- selecting a task already opens the edit form, so it was always just re-entering...
#   v156: New proc insertTaskAfter (alongside appendTask): inserts a task dict into cfgDict's task list right after a named task, falling...
#   v155: openCfg still had a leftover "pack ${w}g.recipe" from the original global-bar build (separate from uiUpdateGlobalButtons, which...
#   v154: Fixed source line: deployed files are version-stripped (fs-clone.tcl, not fs-clone-v01.tcl), same convention as every other...
#   v153: Removed cloneTaskDialog, cloneOnFlowSelect, cloneOnTaskSelect, and cloneTaskCommit entirely -- dead code left over from v152's...
#   v152: Recipe Task browser removed entirely (button, packing logic, handler)
#   v151: Recipe button hidden for all non-task modes (options/parms/runtime)
#   v150: Global em-dash sweep: all 39 occurrences of the UTF-8 em-dash character (U+2014) replaced with -- throughout the file (comments...
#   v149: Em-dash replaced with -- in examples panel header label and in the per-example comment separator (both were rendering as garbage...
#   v148: parmExecPlaceholder eval case: use braces {eval:[glob <key>]} instead of double-quoted string so Tcl does not execute [glob...
#   v147: _addParmBuildExamples: Leave binding now uses [
#   v146: Add Parm dialog enlarged (680x520) with a scrollable examples panel below the input fields showing real patterns for the selected...
#   v145: Add Parm dialog restored as a proper parm builder
#   v144: uiAddItem parms branch: replaced dead openAddParmWin call with openRecipeBrowser -- parms are now added via recipes, consistent...
#   v143: Context help windows: FocusIn reload now uses a 300ms debounced after-callback to avoid mtime race with editor autosave
#   v142: Flow mode: Edit Help button added next to Edit Setup when <flowName>-help.md exists in the flow directory
#   v141: uiEditItem: fixed Edit Task button silence -- moved panelConfirmDiscard AFTER the task-mode branch so it is never called for task...
#   v140: Clone Task dialog reworked: direction corrected - Source flow combobox: OTHER flows to pull from (blank = same flow) - Source...
#   v139: Parms grid: Type column width fixed (narrow, left of Parm) (2) Parms grid tooltip: parmExec + hint (if present) on next line
#   v137: uiLoadParmsGrid: fixed field names to match actual JSON structure parm field (not parmId), type from parmExec prefix before colon
#   v136: uiLoadParmsGrid: fixed field reading (parmId/propStr/parmStr), added debug logging, fixed column widths
#   v135: Parms grid: treeview with Parm/Type columns
#   v134: fs-opts.tcl: commitOptAdd/commitOptEdit call itemPanelSetDirty (was itemPanelMarkDirty - wrong name) so Apply button now enables...
#   v133: WbOptsGrid.Treeview rowheight set to 26 (~30% taller) (2) commitOptAdd/commitOptEdit call itemPanelMarkDirty so Apply Options(s)...
#   v130: iconPath variable name matches user code; no tmp var cleanup needed
#   v129: Window icon: fs-icon-S.ico set via wm iconbitmap in openCfg. Resolved from $TCL_HOME/icons/. Silently skipped if not found
#   v128: panelApplyTask add mode: calls taskProvisionFiles to create task directory and copy/customise template files (2)...
#   v121: Flow mode panel: Edit Setup / Create Setup button added - Resolves <flows.dir>/<flow-name>/<flow-name>-setup.tcl - Edit Setup...
#   v120: fsCfgLoad called at startup - loads ~/flowsmithy/flowsmithy.cfg (2) devp flag: replaced -devp command line arg with devp.enabled...
#   v119: fixed uiUpdateGlobalButtons crash when devp=OFF (Recipe button positioned relative to an unpacked widget)
#   v118: devp mode controls Save Final behaviour: devp=ON : "Save Final" checkbox shown
#   v92: Help back-navigation: openHelpPage now tracks a one-deep back stack (helpBackStack variable)
#   v91: fs-help.tcl load moved to correct position (Steve's tweak preserved). Requires fs-help.tcl for table rendering support
#   v90: Help button wired: opens [fsCfgGet home.dir]/help/wb-cfg-help.md via wb-help mdRender with -linkhandler ::wb::cfg::helpLinkHandler
#   v88: Welcome link removed -- Help link only. (2) Global bar now truly spans the full window: packed into the top-level window (.)...
#   v87: Global bar now spans the full window width (packed directly under .main, not under .main.right). Left panel sits below it
#   v86: Recipe button added to global bar. - Label tracks Cfg Mode: "Recipe Task...", "Recipe Option...", etc
#   v85: uiLoadOptsGrid: reads scalar "place" for check/text/file/directory, list "places" for radio/select (grid Place column was always...
#   v84: uiCloneItem: wired for options mode -> openOptEditor $idx clone (all other Edit Option window changes are in fs-opts.tcl v9)
#   v80: Move Up button now also enables in options mode when row > 0 (2) Label and Parm columns reduced to ~1/3 prior width (3) Fixed...
#   v79: options mode uses treeview grid; clear selection on mode switch
#
# Launch:
#   tclsh fs-cfg.tcl <flow-cfg.json>

package require Tk 8.6 9
package require json

namespace eval ::wb::cfg {
  variable VERSION "v179"
  variable cfgPath ""
  variable cfgDict {}
  variable cfgIsDirty 0
  variable cfgSaveErrMsg ""

  variable taskListData
  array set taskListData {count 0 selIdx -1 rowH 26}
  variable curTaskName ""
  variable curMode "task"
  variable curItemIndex -1
  variable curItemKey ""
  variable curItemIndex -1
  variable optWin ""
  variable ui
  variable optUI
  array set optUI {}
  variable optErr ""

  variable enableRestart 0
  variable panelErrMsg ""
  variable panelMode "view"
  variable panelOrigTaskName ""
  variable panelIsDirty 0
  variable panelSnapshot {}
  variable panelGuardTaskSelect 0
  variable panel
  array set panel {}
  variable opts
  array set opts {}

  # Task rename: queue of {oldName newName} pairs whose folder rename on
  # disk is deferred until the next final Save (see commitTaskRename /
  # applyPendingRenames / saveCfg). The task's own name in cfgDict is
  # updated immediately when the rename is confirmed -- only the disk
  # side is deferred.
  variable pendingRenames {}
  variable renameDlg
  array set renameDlg {}

  # Help navigation back stack: list of {label mdFile} pairs (max depth 1)
  variable helpBackStack {}

  # Context help window state (flow/task help popups)
  variable contextHelpMtime
  array set contextHelpMtime {}
  variable contextHelpPath
  array set contextHelpPath {}
  variable contextHelpTitle
  array set contextHelpTitle {}
  variable contextHelpAfterID
  array set contextHelpAfterID {}

  # Item-level panel state (options / parms / runprops)
  variable itemErrMsg ""
  variable itemIsDirty 0

  puts stderr "==> Loading fs-cfg.tcl ($VERSION)"

}

source [file join [file dirname [info script]] fs-core.tcl]

# -------------------------
# Options module (UI + validation)
# -------------------------
set _wb_cfg_dir [file dirname [info script]]
set _wb_opts [file join $_wb_cfg_dir fs-opts.tcl]
if {![file exists $_wb_opts]} { error "Missing required file: $_wb_opts" }
source $_wb_opts
unset _wb_cfg_dir _wb_opts

# -------------------------
# Common library (shared helpers)
# -------------------------
set _wb_cfg_dir [file dirname [info script]]
set _wb_lib [file join $_wb_cfg_dir tcl-lib.tcl]
if {![file exists $_wb_lib]} { error "Missing required file: $_wb_lib" }
source $_wb_lib

# Load flowsmithy.cfg - mandatory, blows up if not found
fsCfgLoad

# ::wb::lib::requireTclFlows now lives in tcl-lib.tcl (the one canonical,
# flowsmithy.cfg-based definition, used by fs-cfg.tcl, fs-clone.tcl, and
# fs-new.tcl alike) -- this used to have its own separate copy here,
# which happened to redefine/override an older env(TCL_FLOWS)-based
# version in tcl-lib.tcl by load order, not by design. See tcl-lib.tcl's
# changelog.

unset _wb_cfg_dir _wb_lib

# -------------------------
# Common library (shared helpers)
# -------------------------
set _wb_cfg_dir [file dirname [info script]]
set _wb_lib [file join $_wb_cfg_dir fs-help.tcl]
if {![file exists $_wb_lib]} { error "Missing required file: $_wb_lib" }
source $_wb_lib
unset _wb_cfg_dir _wb_lib

# -------------------------
# Clone module (Clone Task search/select window)
# -------------------------
set _wb_cfg_dir [file dirname [info script]]
set _wb_lib [file join $_wb_cfg_dir fs-clone.tcl]
if {![file exists $_wb_lib]} { error "Missing required file: $_wb_lib" }
source $_wb_lib
unset _wb_cfg_dir _wb_lib

# -------------------------
# Logging
# -------------------------
proc ::wb::cfg::log {msg} {
  variable ui
  catch { puts stderr $msg }
  if {[info exists ui(log)] && [winfo exists $ui(log)]} {
    $ui(log) insert end "$msg\n"
    $ui(log) see end
  }
}

# -------------------------
# Validation stubs (v93)
# Level 2: task-level validation
#   Called: (1) when a task is selected, (2) when a task property changes,
#           (3) when an item change (option/parm/runprop) completes.
# -------------------------
# Shared task validation rule engine (v100)
# -------------------------

# checkOneTask: pure data check, no panel/UI involvement.
#   taskDict  - the task dict to check
#   priorNames - list of task names that precede this task in the flow
#   allNames   - list of ALL task names (for duplicate detection)
#   selfIdx    - index of this task in allNames (-1 for a new/unsaved task)
# Returns a list of error strings, empty = valid.
proc ::wb::cfg::checkOneTask {taskDict priorNames allNames {selfIdx -1}} {
  set errs {}

  set name  [string trim [expr {[dict exists $taskDict name]  ? [dict get $taskDict name]  : ""}]]
  set title [string trim [expr {[dict exists $taskDict title] ? [dict get $taskDict title] : ""}]]
  set desc  [string trim [expr {[dict exists $taskDict desc]  ? [dict get $taskDict desc]  : ""}]]
  set type  [string trim [expr {[dict exists $taskDict type]  ? [dict get $taskDict type]  : ""}]]
  set dependsOn [expr {[dict exists $taskDict dependsOn] ? [dict get $taskDict dependsOn] : {}}]
  set whenFail  [expr {[dict exists $taskDict whenFail]  ? [dict get $taskDict whenFail]  : {}}]

  if {$type ni {tcl-int tcl-ext manual java}} {
    lappend errs "type '$type' is not valid"
  }

  if {$title eq ""} { lappend errs "title is required" }
  if {$desc  eq ""} { lappend errs "desc is required"  }

  # Duplicate name check: skip own index
  set dupFound 0
  for {set i 0} {$i < [llength $allNames]} {incr i} {
    if {$i == $selfIdx} continue
    if {[lindex $allNames $i] eq $name} { set dupFound 1; break }
  }
  if {$dupFound} { lappend errs "name '$name' is a duplicate" }

  # Orphan checks
  foreach d $dependsOn {
    if {$d ni $priorNames} { lappend errs "dependsOn '$d' is not a prior task" }
  }
  foreach f $whenFail {
    if {$f ni $priorNames} { lappend errs "whenFail '$f' is not a prior task" }
  }

  return $errs
}

# validateAllTasks: walk every task in cfgDict, run checkOneTask for each.
# Returns a dict of {taskName -> errorMsg} for any task with errors.
# Tasks with no errors are absent from the dict.
proc ::wb::cfg::validateAllTasks {} {
  set allNames [::wb::cfg::taskNames]
  set tasks    [::wb::cfg::taskList]
  set errDict  {}
  set prior    {}

  set idx 0
  foreach taskDict $tasks {
    set name [expr {[dict exists $taskDict name] ? [dict get $taskDict name] : "?$idx"}]
    set errs [::wb::cfg::checkOneTask $taskDict $prior $allNames $idx]
    if {[llength $errs] > 0} {
      dict set errDict $name [join $errs " | "]
    }
    lappend prior $name
    incr idx
  }
  return $errDict
}

# cfgSaveGate: enable/disable Save based on dirty + all-tasks-valid.
# Updates cfgSaveErrMsg for display below the task list.
proc ::wb::cfg::cfgSaveGate {} {
  variable cfgIsDirty
  variable cfgSaveErrMsg
  variable ui

  set errDict [::wb::cfg::validateAllTasks]

  set fc [::wb::cfg::taskFolderConsistencyCheck]
  foreach n [dict get $fc missing] {
    set msg "task folder missing on disk"
    if {[dict exists $errDict $n]} {
      dict set errDict $n "[dict get $errDict $n] | $msg"
    } else {
      dict set errDict $n $msg
    }
  }

  if {[dict size $errDict] > 0} {
    set cfgSaveErrMsg "Save disabled due to above errors"
  } else {
    set cfgSaveErrMsg ""
  }

  if {[info exists ui(btnSave)] && [winfo exists $ui(btnSave)]} {
    if {$cfgIsDirty && [dict size $errDict] == 0} {
      $ui(btnSave) configure -state normal
    } else {
      $ui(btnSave) configure -state disabled
    }
  }

  # Refresh task list to show/clear error indicators
  ::wb::cfg::uiLoadTasks $errDict
}

# validateTask: panel-level check for the currently displayed task.
# Reads panel state into a transient dict and calls checkOneTask.
proc ::wb::cfg::validateTask {} {
  variable curTaskName
  variable panelErrMsg
  variable panelIsDirty
  variable panel

  set panelErrMsg ""

  # Guard: panel vars may not exist yet during startup
  if {![info exists panel(taskName)]} { return }

  set name      [string trim $panel(taskName)]
  set title     [string trim $panel(taskTitle)]
  set desc      [string trim $panel(taskDesc)]
  set type      [string trim $panel(taskType)]
  set dependsOn [::wb::cfg::panelReadMultiSelection taskDepends]
  set whenFail  [::wb::cfg::panelReadMultiSelection taskWhenFail]

  set taskDict [dict create \
    name $name title $title desc $desc type $type \
    dependsOn $dependsOn whenFail $whenFail]

  set allNames   [::wb::cfg::taskNames]
  set selfIdx    [::wb::cfg::taskIndexByName $curTaskName]
  set priorNames [::wb::cfg::priorTaskNames $curTaskName]

  set errs [::wb::cfg::checkOneTask $taskDict $priorNames $allNames $selfIdx]
  if {$name eq ""} {
    set errs [linsert $errs 0 "name is yesrequired"]
  }
  if {[llength $errs] > 0} {
    set panelErrMsg [join $errs " | "]
  }


  ::wb::cfg::panelApplyGate
  ::wb::cfg::cfgSaveGate
}

# Enable/disable the Apply button: dirty AND panel valid.
proc ::wb::cfg::panelApplyGate {} {
  variable panelIsDirty
  variable panelErrMsg
  variable ui
  if {![info exists ui(panelApply)] || ![winfo exists $ui(panelApply)]} { return }
  if {$panelIsDirty && $panelErrMsg eq ""} {
    $ui(panelApply) configure -state normal
  } else {
    $ui(panelApply) configure -state disabled
  }
}

# Level 3: item-level validators
#   Each is called when a change to that item type completes.
#   After each, validateTask is also called.
proc ::wb::cfg::validateOptions {} {
  variable curTaskName
  log "validateOptions: task='$curTaskName' (stub)"
  ::wb::cfg::validateTask
}

proc ::wb::cfg::validateParms {} {
  variable curTaskName
  log "validateParms: task='$curTaskName' (stub)"
  ::wb::cfg::validateTask
}

proc ::wb::cfg::validateRunprops {} {
  variable curTaskName
  log "validateRunprops: task='$curTaskName' (stub)"
  ::wb::cfg::validateTask
}

# -------------------------
# Item panel helpers (v93)
# -------------------------

# Mark the item panel dirty (enable Apply button) and clear/set error.
proc ::wb::cfg::itemPanelSetDirty {{errMsg ""}} {
  variable itemIsDirty
  variable itemErrMsg
  variable ui

  set itemIsDirty 1
  set itemErrMsg $errMsg

  if {[info exists ui(itemApply)] && [winfo exists $ui(itemApply)]} {
    $ui(itemApply) configure -state normal
  }
  update idletasks
}

# Mark the item panel clean (disable Apply button) and clear error.
proc ::wb::cfg::itemPanelMarkClean {} {
  variable itemIsDirty
  variable itemErrMsg
  variable ui

  set itemIsDirty 0
  set itemErrMsg ""

  if {[info exists ui(itemApply)] && [winfo exists $ui(itemApply)]} {
    $ui(itemApply) configure -state disabled
  }
  update idletasks
}

# Refresh the Apply button label to reflect current mode (called on mode change).
proc ::wb::cfg::itemPanelUpdateLabel {} {
  variable curMode
  variable ui
  if {![info exists ui(itemApply)] || ![winfo exists $ui(itemApply)]} { return }
  set cap [::wb::cfg::modeTitle $curMode]
  $ui(itemApply) configure -text "Apply ${cap}(s) Change"
}

# Dispatcher: called by the Apply X(s) Change button.
# Routes to the appropriate validator for the current mode,
# then marks the item panel clean.
proc ::wb::cfg::itemPanelApply {} {
  variable curMode
  switch -exact -- $curMode {
    options { ::wb::cfg::validateOptions  }
    parms   { ::wb::cfg::validateParms    }
    runprop { ::wb::cfg::validateRunprops }
    default {
      log "itemPanelApply: no handler for mode '$curMode'"
    }
  }
  ::wb::cfg::itemPanelMarkClean
}

proc ::wb::cfg::initButtonStyle {} {
  catch { ttk::style theme use vista }
  ttk::style configure WbRounded.TButton -padding {10 3}
  # Treeview heading: soft steel-blue background so header is visually distinct
  ttk::style configure WbOptsGrid.Treeview   -rowheight 26
  ttk::style configure WbParmsGrid.Treeview  -rowheight 26
  ttk::style configure WbRunGrid.Treeview    -rowheight 26
  foreach s {WbOptsGrid WbParmsGrid WbRunGrid} {
    ttk::style configure ${s}.Treeview.Heading \
      -background #4A7BA7 -foreground black \
      -font {TkDefaultFont 9 bold} -relief flat
    ttk::style map ${s}.Treeview.Heading \
      -background [list active #5A8FBF]
  }
  # Help link label styles (matching fs-run.tcl)
  ttk::style configure Wb.Link.TLabel      -foreground "#1a5fb4" -padding {2 0 2 0}
  ttk::style configure Wb.LinkHover.TLabel -foreground black -background "#d9f2ef" -padding {2 0 2 0}
}





proc ::wb::cfg::updateRestartBtn {} {
  variable ui
  variable enableRestart

  if {[info exists ui(btnRestart)] && [winfo exists $ui(btnRestart)]} {
    if {$enableRestart} {
      $ui(btnRestart) configure -state normal
    } else {
      $ui(btnRestart) configure -state disabled
    }
  }
}

proc ::wb::cfg::cfgMarkDirty {} {
  variable cfgIsDirty
  set cfgIsDirty 1
  ::wb::cfg::cfgSaveGate
}

proc ::wb::cfg::doRestart77 {} {
  puts stderr "WB about to exit 77"
  flush stderr
  ::exit 77
}

# -------------------------
# Task helpers
# -------------------------
proc ::wb::cfg::taskList {} {
  variable cfgDict
  return [dict get $cfgDict tasks]
}

proc ::wb::cfg::taskIndexByName {name} {
  set i 0
  foreach t [taskList] {
    if {[dict get $t name] eq $name} { return $i }
    incr i
  }
  return -1
}

proc ::wb::cfg::getTask {name} {
  set i [taskIndexByName $name]
  if {$i < 0} { return {} }
  return [lindex [taskList] $i]
}

proc ::wb::cfg::setTask {name newTask} {
  variable cfgDict
  set i [taskIndexByName $name]
  if {$i < 0} { return }
  set tasks [taskList]
  set tasks [lreplace $tasks $i $i $newTask]
  dict set cfgDict tasks $tasks
  ::wb::cfg::cfgMarkDirty
}


proc ::wb::cfg::appendTask {newTask} {
  variable cfgDict
  set tasks [taskList]
  lappend tasks $newTask
  dict set cfgDict tasks $tasks
  ::wb::cfg::cfgMarkDirty
}

# ---------------------------------------------------------------------------
# insertTaskAfter  afterName  newTask
#
# Inserts newTask into cfgDict's task list immediately after the task named
# afterName. If afterName isn't found (not selected, already gone, etc.),
# falls back to appending at the end. Used by fs-clone.tcl's real Clone
# action so a cloned task lands next to the task it was cloned "from
# beside", rather than always at the bottom of the list.
# ---------------------------------------------------------------------------
proc ::wb::cfg::insertTaskAfter {afterName newTask} {
  variable cfgDict
  set tasks [taskList]
  set idx [taskIndexByName $afterName]
  if {$idx < 0} {
    lappend tasks $newTask
  } else {
    set tasks [linsert $tasks [expr {$idx + 1}] $newTask]
  }
  dict set cfgDict tasks $tasks
  ::wb::cfg::cfgMarkDirty
}

proc ::wb::cfg::cfgBaseName {} {
  variable cfgPath
  set base [file rootname [file tail $cfgPath]]
  regsub -- {-cfg$} $base "" base
  return $base
}

proc ::wb::cfg::taskNames {} {
  set names {}
  foreach t [taskList] {
    if {[dict exists $t name]} {
      lappend names [dict get $t name]
    }
  }
  return $names
}

proc ::wb::cfg::priorTaskNames {{taskName ""}} {
  set names {}
  foreach t [taskList] {
    if {![dict exists $t name]} { continue }
    set name [dict get $t name]
    if {$taskName ne "" && $name eq $taskName} { break }
    lappend names $name
  }
  return $names
}

proc ::wb::cfg::panelReadMultiSelection {group} {
  variable panelChecks
  set vals {}
  if {![info exists panelChecks($group,names)]} { return $vals }
  foreach name $panelChecks($group,names) {
    if {[info exists panelChecks($group,$name)] && $panelChecks($group,$name)} {
      lappend vals $name
    }
  }
  return $vals
}

proc ::wb::cfg::panelSetMultiSelection {group selectedValues} {
  variable panelChecks
  set want [dict create]
  foreach v $selectedValues { dict set want $v 1 }
  if {![info exists panelChecks($group,names)]} { return }
  foreach name $panelChecks($group,names) {
    set panelChecks($group,$name) [expr {[dict exists $want $name] ? 1 : 0}]
  }
}

proc ::wb::cfg::panelBuildChecklist {group names {orphans {}}} {
  variable ui
  variable panelChecks

  if {![info exists ui($group)] || ![winfo exists $ui($group)]} { return }

  set host $ui($group)
  set canvas $host.c
  set inner  $host.c.f

  catch {unset panelChecks($group,names)}
  foreach name [array names panelChecks "$group,*"] {
    catch {unset panelChecks($name)}
  }

  # Build display list: normal names first, then orphans (plain name, red)
  set panelChecks($group,names) [concat $names $orphans]

  foreach child [winfo children $inner] {
    destroy $child
  }

  set row 0
  foreach name $names {
    set panelChecks($group,$name) 0
    checkbutton $inner.cb$row -text $name -anchor w \
      -variable ::wb::cfg::panelChecks($group,$name) \
      -command {::wb::cfg::panelUpdateDirty; after idle ::wb::cfg::validateTask}
    grid $inner.cb$row -row $row -column 0 -sticky we -padx 4 -pady 2
    incr row
  }

  # Orphaned entries: red foreground, pre-checked
  foreach o $orphans {
    set panelChecks($group,$o) 1
    checkbutton $inner.cb$row -text $o -anchor w \
      -foreground red \
      -variable ::wb::cfg::panelChecks($group,$o) \
      -command {::wb::cfg::panelUpdateDirty; after idle ::wb::cfg::validateTask}
    grid $inner.cb$row -row $row -column 0 -sticky we -padx 4 -pady 2
    incr row
  }

  if {$row == 0} {
    label $inner.empty -text "No prior steps." -anchor w -foreground gray40
    grid $inner.empty -row 0 -column 0 -sticky w -padx 4 -pady 2
  }

  grid columnconfigure $inner 0 -weight 1
  update idletasks
  $canvas configure -scrollregion [list 0 0 [winfo reqwidth $inner] [winfo reqheight $inner]]
}

proc ::wb::cfg::panelChecklistOnConfigure {canvas inner} {
  if {![winfo exists $canvas] || ![winfo exists $inner]} { return }
  $canvas itemconfigure inner -width [winfo width $canvas]
  $canvas configure -scrollregion [list 0 0 [winfo reqwidth $inner] [winfo reqheight $inner]]
}




proc ::wb::cfg::panelCurrentState {} {
  variable curMode
  variable panel
  variable ui

  set flowName  [expr {[info exists panel(flowName)]  ? $panel(flowName)  : ""}]
  set flowTitle [expr {[info exists panel(flowTitle)] ? $panel(flowTitle) : ""}]
  set taskName  [expr {[info exists panel(taskName)]  ? $panel(taskName)  : ""}]
  set taskTitle [expr {[info exists panel(taskTitle)] ? $panel(taskTitle) : ""}]
  set taskDesc  [expr {[info exists panel(taskDesc)]  ? $panel(taskDesc)  : ""}]
  set taskType  [expr {[info exists panel(taskType)]  ? $panel(taskType)  : "tcl-int"}]

  if {$curMode eq "flow"} {
    return [dict create flowName [string trim $flowName] flowTitle [string trim $flowTitle]]
  }

  if {$curMode eq "task"} {
    set dependsOn {}
    set whenFail {}
    if {[info exists ui(taskDepends)] && [winfo exists $ui(taskDepends)]} {
      set dependsOn [lsort [::wb::cfg::panelReadMultiSelection taskDepends]]
    }
    if {[info exists ui(taskWhenFail)] && [winfo exists $ui(taskWhenFail)]} {
      set whenFail [lsort [::wb::cfg::panelReadMultiSelection taskWhenFail]]
    }
    # v174 added staleAfterVal/staleAfterUnit as real panel fields, but
    # missed adding them here -- panelIsDirty is computed purely by
    # comparing this dict against a snapshot (see panelUpdateDirty),
    # so a field absent from THIS dict can never be detected as changed
    # no matter what the widget shows. That's what left Apply disabled
    # after editing staleAfter. Fixed by including both fields, same as
    # every other panel(...) value already is.
    set staleAfterVal  [expr {[info exists panel(staleAfterVal)]  ? [string trim $panel(staleAfterVal)] : ""}]
    set staleAfterUnit [expr {[info exists panel(staleAfterUnit)] ? $panel(staleAfterUnit) : "secs"}]
    return [dict create taskName [string trim $taskName] taskTitle [string trim $taskTitle] taskDesc [string trim $taskDesc] taskType [string trim $taskType] taskDepends $dependsOn taskWhenFail $whenFail staleAfterVal $staleAfterVal staleAfterUnit $staleAfterUnit]
  }

  return {}
}

proc ::wb::cfg::panelCaptureSnapshot {} {
  variable panelSnapshot
  set panelSnapshot [::wb::cfg::panelCurrentState]
}

proc ::wb::cfg::panelUpdateDirty {} {
  variable panelIsDirty
  variable panelSnapshot

  set panelIsDirty [expr {[::wb::cfg::panelCurrentState] ne $panelSnapshot}]
  ::wb::cfg::validateTask
  update idletasks
}

proc ::wb::cfg::panelConfirmDiscard {} {
  variable panelIsDirty
  variable curMode

  if {!$panelIsDirty} { return 1 }
  if {$curMode ne "flow" && $curMode ne "task"} { return 1 }

  set ans [tk_messageBox     -icon warning     -type yesno     -default no     -title "Discard changes?"     -message "You have unsaved panel changes. Lose those changes?"]
  return [expr {$ans eq "yes"}]
}

proc ::wb::cfg::panelMarkClean {} {
  variable panelErrMsg
  set panelErrMsg $panelErrMsg
  ::wb::cfg::panelCaptureSnapshot
  ::wb::cfg::panelUpdateDirty
}

proc ::wb::cfg::panelTrackVar {args} {
  after idle ::wb::cfg::panelUpdateDirty
}

proc ::wb::cfg::panelTrackListbox {args} {
  after idle ::wb::cfg::panelUpdateDirty
}

proc ::wb::cfg::panelErrRefresh {args} {
  variable ui
  variable panelErrMsg

  if {![info exists ui(panelErr)] || ![winfo exists $ui(panelErr)]} { return }

  set msg [string trim $panelErrMsg]
  if {$msg eq ""} {
    set panelErrMsg ""
  } else {
    set panelErrMsg $msg
  }
  update idletasks
}

proc ::wb::cfg::panelPopulatePriorTaskLists {{taskName ""} {depVals {}} {failVals {}}} {
  set priorNames [::wb::cfg::priorTaskNames $taskName]

  # Orphans: names in existing selections that are not in the prior list
  set depOrphans  {}
  set failOrphans {}
  foreach v $depVals  { if {$v ni $priorNames} { lappend depOrphans  $v } }
  foreach v $failVals { if {$v ni $priorNames} { lappend failOrphans $v } }

  ::wb::cfg::panelBuildChecklist taskDepends  $priorNames $depOrphans
  ::wb::cfg::panelBuildChecklist taskWhenFail $priorNames $failOrphans
}

proc ::wb::cfg::panelToggleTaskChecklists {showThem} {
  variable ui
  foreach key {taskDepLabel taskDepends taskFailLabel taskWhenFail} {
    if {![info exists ui($key)] || ![winfo exists $ui($key)]} { continue }
    if {$showThem} {
      grid $ui($key)
    } else {
      grid remove $ui($key)
    }
  }
}

# staleAfter only makes sense on the first task in a flow -- shares the
# same grid row DependsOn/WhenFail use, shown exactly when those are
# hidden. Known edge case, not solved for here: a task can have
# DependsOn/WhenFail checklists forced visible to show orphaned
# selections (see the "|| depVals/failVals" condition at the two call
# sites) even while it has no CURRENT prior tasks -- if that ever
# coincides with genuinely being the first task, both would want the
# same space. Accepted as rare/self-resolving (cleaning up the orphan
# selection removes the conflict) rather than engineered around.
proc ::wb::cfg::panelToggleStaleAfter {showIt} {
  variable ui
  foreach key {staleAfterLabel staleAfterFrame} {
    if {![info exists ui($key)] || ![winfo exists $ui($key)]} { continue }
    if {$showIt} {
      grid $ui($key)
    } else {
      grid remove $ui($key)
    }
  }
}

proc ::wb::cfg::panelShowMode {mode} {
  variable ui
  if {![info exists ui(itemsList)] || ![info exists ui(panelHost)]} { return }
  pack forget $ui(itemsList)
  foreach _g {optsGrid parmsGrid runpropsGrid} {
    if {[info exists ui($_g)] && [winfo exists $ui($_g)]} {
      pack forget $ui($_g)
    }
  }
  if {[info exists ui(itemPanel)] && [winfo exists $ui(itemPanel)]} {
    pack forget $ui(itemPanel)
  }
  foreach key {panelFlow panelTask panelApply panelErr panelBody} {
    if {[info exists ui($key)] && [winfo exists $ui($key)]} {
      pack forget $ui($key)
    }
  }

  if {$mode eq "flow"} {
    pack $ui(panelHost)  -fill both -expand 1 -padx 8 -pady 4
    pack $ui(panelBody)  -fill both -expand 1 -anchor nw
    pack $ui(panelFlow)  -in $ui(panelBody) -fill x -anchor nw
    pack $ui(panelErr)   -in $ui(panelHost) -fill x -anchor w -pady {10 4}
    pack $ui(panelApply) -in $ui(panelHost) -anchor e -padx 0 -pady {0 6}
    ::wb::cfg::flowRefreshSetupButton
    ::wb::cfg::panelUpdateDirty
    update idletasks
    return
  }

  if {$mode eq "task"} {
    pack $ui(panelHost)  -fill both -expand 1 -padx 8 -pady 4
    pack $ui(panelBody)  -fill both -expand 1 -anchor nw
    pack $ui(panelTask)  -in $ui(panelBody) -fill both -expand 1 -anchor nw
    pack $ui(panelErr)   -in $ui(panelHost) -fill x -anchor w -pady {10 4}
    pack $ui(panelApply) -in $ui(panelHost) -anchor e -padx 0 -pady {0 6}
    ::wb::cfg::taskRefreshScriptButton
    ::wb::cfg::panelUpdateDirty
    update idletasks
    return
  }

  pack forget $ui(panelHost)
  if {$mode eq "options" && [info exists ui(optsGrid)] && [winfo exists $ui(optsGrid)]} {
    pack $ui(optsGrid) -fill both -expand 1 -padx 8 -pady {4 0}
  } elseif {$mode eq "parms" && [info exists ui(parmsGrid)] && [winfo exists $ui(parmsGrid)]} {
    pack $ui(parmsGrid) -fill both -expand 1 -padx 8 -pady {4 0}
  } elseif {$mode eq "runprop" && [info exists ui(runpropsGrid)] && [winfo exists $ui(runpropsGrid)]} {
    pack $ui(runpropsGrid) -fill both -expand 1 -padx 8 -pady {4 0}
  } else {
    pack $ui(itemsList) -fill both -expand 1 -padx 8 -pady {4 0}
  }
  # Show the item-level error + apply panel below the list/grid
  if {[info exists ui(itemPanel)] && [winfo exists $ui(itemPanel)]} {
    pack $ui(itemPanel) -fill x -padx 8 -pady {2 6}
  }
}

proc ::wb::cfg::panelLoadFlow {} {
  variable panel
  variable panelMode
  variable panelErrMsg

  set panelMode "edit"
  set panelErrMsg ""
  set panel(flowName)  [::wb::cfg::cfgBaseName]
  set panel(flowTitle) [dict get $::wb::cfg::cfgDict title]
  ::wb::cfg::panelShowMode flow
  ::wb::cfg::panelMarkClean
}

# ---------------------------------------------------------------------------
# flowSetupPath
# Resolves the full path of the setup file for the current flow.
# Pattern: <first-valid-flows.dir>/<flow-name>/<flow-name>-setup.tcl
# ---------------------------------------------------------------------------
proc ::wb::cfg::flowSetupPath {} {
  set flowName [::wb::cfg::cfgBaseName]
  set flowsDir [::wb::lib::requireTclFlows]
  return [file normalize [file join $flowsDir $flowName "${flowName}-setup.tcl"]]
}

# ---------------------------------------------------------------------------
# flowHelpPath
# Resolves the full path of the help file for the current flow.
# Pattern: <first-valid-flows.dir>/<flow-name>/<flow-name>-help.md
# ---------------------------------------------------------------------------
proc ::wb::cfg::flowHelpPath {} {
  set flowName [::wb::cfg::cfgBaseName]
  set flowsDir [::wb::lib::requireTclFlows]
  return [file normalize [file join $flowsDir $flowName "${flowName}-help.md"]]
}

# ---------------------------------------------------------------------------
# flowRefreshSetupButton
# Called from panelShowMode when entering flow mode.
# Destroys and recreates the Edit Setup / Create Setup button so it
# always reflects current file existence.
# Also rebuilds Edit Help / View Help buttons when <flow>-help.md exists.
# ---------------------------------------------------------------------------
proc ::wb::cfg::flowRefreshSetupButton {} {
  variable ui

  if {![info exists ui(panelFlow)] || ![winfo exists $ui(panelFlow)]} { return }

  set setupPath [::wb::cfg::flowSetupPath]
  set w $ui(panelFlow)

  # Destroy prior instances so we always rebuild fresh
  catch { destroy ${w}.setupBtn }
  catch { destroy ${w}.helpEditBtn }
  catch { destroy ${w}.helpViewBtn }

  if {[file exists $setupPath]} {
    ttk::button ${w}.setupBtn \
      -style WbRounded.TButton \
      -text "Edit Setup" \
      -command [list ::wb::cfg::onEditSetup $setupPath]
  } else {
    ttk::button ${w}.setupBtn \
      -style WbRounded.TButton \
      -text "Create Setup" \
      -command [list ::wb::cfg::onCreateSetup $setupPath]
  }

  # Tooltip shows full path on hover
  ::wb::cfg::setTooltip ${w}.setupBtn $setupPath

  # Row 2, col 1 -- below Name (row 0) and Title (row 1)
  grid ${w}.setupBtn -row 2 -column 1 -sticky w -padx 4 -pady {8 4}

  # Help buttons -- only when help file exists
  set helpPath [::wb::cfg::flowHelpPath]
  if {[file exists $helpPath]} {
    ttk::button ${w}.helpEditBtn \
      -style WbRounded.TButton \
      -text "Edit Help" \
      -command [list ::wb::cfg::onEditFlowHelp $helpPath]
    ttk::button ${w}.helpViewBtn \
      -style WbRounded.TButton \
      -text "View Help" \
      -command [list ::wb::cfg::onViewFlowHelp $helpPath]
    ::wb::cfg::setTooltip ${w}.helpEditBtn $helpPath
    ::wb::cfg::setTooltip ${w}.helpViewBtn $helpPath
    # Row 2 -- same row as Edit Setup, cols 2 and 3
    grid ${w}.helpEditBtn -row 2 -column 2 -sticky w -padx 4 -pady {8 4}
    grid ${w}.helpViewBtn -row 2 -column 3 -sticky w -padx 4 -pady {8 4}
  }
}

# ---------------------------------------------------------------------------
# setTooltip  widget  text
# Lightweight tooltip -- no external package required.
# ---------------------------------------------------------------------------
proc ::wb::cfg::setTooltip {w text} {
  bind $w <Enter> [list ::wb::cfg::tooltipShow %W $text]
  bind $w <Leave> [list ::wb::cfg::tooltipHide]
}

proc ::wb::cfg::tooltipShow {w text} {
  set t .wbTooltip
  catch { destroy $t }
  toplevel $t -relief solid -bd 1
  wm overrideredirect $t 1
  wm attributes $t -topmost 1
  label $t.l -text $text -background "#ffffe0" -foreground black \
    -font {TkDefaultFont 9} -padx 4 -pady 2
  pack $t.l
  set x [expr {[winfo rootx $w] + 10}]
  set y [expr {[winfo rooty $w] + [winfo height $w] + 2}]
  wm geometry $t +${x}+${y}
}

proc ::wb::cfg::tooltipHide {} {
  catch { destroy .wbTooltip }
}

# ---------------------------------------------------------------------------
# onEditSetup  setupPath
# Opens the setup file in the configured editor via fsOpenInEditor.
# ---------------------------------------------------------------------------
proc ::wb::cfg::onEditSetup {setupPath} {
  log "onEditSetup: opening $setupPath"
  if {[catch {fsOpenInEditor $setupPath} err]} {
    log "ERROR onEditSetup: $err"
    tk_messageBox -icon error -title "Edit Setup" -message $err
  }
}

# ---------------------------------------------------------------------------
# onCreateSetup  setupPath  -- stub
# Logs intent to create the setup file.
# ---------------------------------------------------------------------------
proc ::wb::cfg::onCreateSetup {setupPath} {

  set flowName [::wb::cfg::cfgBaseName]
  set tplPath [file join [fsCfgGet home.dir] "templates" "flow-setup.tcl"]

  set fh [open $tplPath r]
  fconfigure $fh -encoding utf-8
  set tplStr [read $fh]
  close $fh

  set dic [dict create "flow-name" "$flowName" "date-stamp" [getDateStamp]]
  set outStr [::wb::lib::applyDictToTemplate $dic $tplStr]

  set fh [open $setupPath w]
  fconfigure $fh -encoding utf-8 -translation lf
  puts -nonewline $fh $outStr
  close $fh
  log "wrote initial setup template to $setupPath"
  ::wb::cfg::flowRefreshSetupButton
}

# ---------------------------------------------------------------------------
# onEditFlowHelp  helpPath
# Opens the flow help .md file in the configured editor.
# ---------------------------------------------------------------------------
proc ::wb::cfg::onEditFlowHelp {helpPath} {
  log "onEditFlowHelp: opening $helpPath"
  if {[catch {fsOpenInEditor $helpPath} err]} {
    log "ERROR onEditFlowHelp: $err"
    tk_messageBox -icon error -title "Edit Flow Help" -message $err
  }
}

# ---------------------------------------------------------------------------
# onViewFlowHelp  helpPath
# Opens (or refreshes) the flow help window (.wbFlowHelp).
# ---------------------------------------------------------------------------
proc ::wb::cfg::onViewFlowHelp {helpPath} {
  set flowName [::wb::cfg::cfgBaseName]
  ::wb::cfg::openContextHelpWin .wbFlowHelp "Flow Help -- $flowName" $helpPath
}

# ---------------------------------------------------------------------------
# taskScriptPath
# Returns {scriptPath templateName} for the current task based on type,
# or {} if the task type does not require a script (java, manual etc).
# ---------------------------------------------------------------------------
proc ::wb::cfg::taskScriptPath {} {
  variable curTaskName
  variable panel

  set taskName [string trim $panel(taskName)]
  set taskType [string trim $panel(taskType)]
  if {$taskName eq ""} { return {} }

  switch -- $taskType {
    "tcl-int" {
      set scriptFile "${taskName}-sync.tcl"
      set tplName    "task-sync.tcl"
    }
    "tcl-ext" {
      set scriptFile "${taskName}-async.tcl"
      set tplName    "task-async.tcl"
    }
    default {
      return {}
    }
  }

  set flowName   [::wb::cfg::cfgBaseName]
  set scriptPath [::wb::lib::pathTask $flowName $taskName $scriptFile]
  return [list [file normalize $scriptPath] $tplName]
}

# ---------------------------------------------------------------------------
# taskHelpPath
# Returns the full path to the task help file:
#   <taskDir>/<taskName>-help.md
# Returns "" if taskName is empty.
# ---------------------------------------------------------------------------
proc ::wb::cfg::taskHelpPath {} {
  variable panel

  set taskName [string trim $panel(taskName)]
  if {$taskName eq ""} { return "" }

  set flowName [::wb::cfg::cfgBaseName]
  set helpFile "${taskName}-help.md"
  return [file normalize [::wb::lib::pathTask $flowName $taskName $helpFile]]
}

# ---------------------------------------------------------------------------
# taskRefreshScriptButton
# Called from panelShowMode when entering task mode.
# Destroys and recreates the Edit Script / Create Script button.
# Hidden entirely for task types that need no script.
# Also rebuilds Edit Help / View Help buttons when <task>-help.md exists.
# ---------------------------------------------------------------------------
proc ::wb::cfg::taskRefreshScriptButton {} {
  variable ui

  if {![info exists ui(panelTask)] || ![winfo exists $ui(panelTask)]} { return }

  set w $ui(panelTask)
  catch { destroy ${w}.scriptBtn }
  catch { destroy ${w}.helpEditBtn }
  catch { destroy ${w}.helpViewBtn }

  set info [::wb::cfg::taskScriptPath]
  if {$info eq {}} {
    # Not a scriptable type -- no script button, but still show help buttons if applicable
  } else {
    lassign $info scriptPath tplName

    if {[file exists $scriptPath]} {
      ttk::button ${w}.scriptBtn \
        -style WbRounded.TButton \
        -text "Edit Script" \
        -command [list ::wb::cfg::onEditScript $scriptPath]
    } else {
      ttk::button ${w}.scriptBtn \
        -style WbRounded.TButton \
        -text "Create Script" \
        -command [list ::wb::cfg::onCreateScript $scriptPath $tplName]
    }

    ::wb::cfg::setTooltip ${w}.scriptBtn $scriptPath

    # Row 6, col 1 -- below Name(0) Title(1) Desc(2) Type(3) DependsOn(4) WhenFail(5)
    grid ${w}.scriptBtn -row 6 -column 1 -sticky w -padx 4 -pady {8 4}
  }

  # Help buttons -- only when help file exists
  set helpPath [::wb::cfg::taskHelpPath]
  if {$helpPath ne "" && [file exists $helpPath]} {
    ttk::button ${w}.helpEditBtn \
      -style WbRounded.TButton \
      -text "Edit Help" \
      -command [list ::wb::cfg::onEditTaskHelp $helpPath]
    ttk::button ${w}.helpViewBtn \
      -style WbRounded.TButton \
      -text "View Help" \
      -command [list ::wb::cfg::onViewTaskHelp $helpPath]
    ::wb::cfg::setTooltip ${w}.helpEditBtn $helpPath
    ::wb::cfg::setTooltip ${w}.helpViewBtn $helpPath
    # Same row 6: col 2 and col 3 (or col 1/2 if no script button)
    if {$info eq {}} {
      grid ${w}.helpEditBtn -row 6 -column 1 -sticky w -padx 4 -pady {8 4}
      grid ${w}.helpViewBtn -row 6 -column 2 -sticky w -padx 4 -pady {8 4}
    } else {
      grid ${w}.helpEditBtn -row 6 -column 2 -sticky w -padx 4 -pady {8 4}
      grid ${w}.helpViewBtn -row 6 -column 3 -sticky w -padx 4 -pady {8 4}
    }
  }
}

# ---------------------------------------------------------------------------
# onEditScript  scriptPath
# Opens the task script in the configured editor.
# ---------------------------------------------------------------------------
proc ::wb::cfg::onEditScript {scriptPath} {
  log "onEditScript: opening $scriptPath"
  if {[catch {fsOpenInEditor $scriptPath} err]} {
    log "ERROR onEditScript: $err"
    tk_messageBox -icon error -title "Edit Script" -message $err
  }
}

# ---------------------------------------------------------------------------
# onCreateScript  scriptPath  tplName
# Creates the task script from the named template then refreshes the button.
# Modelled on onCreateSetup.
# ---------------------------------------------------------------------------
proc ::wb::cfg::onCreateScript {scriptPath tplName} {
  variable panel

  set taskName [string trim $panel(taskName)]
  set flowName [::wb::cfg::cfgBaseName]
  set tplPath  [file join [fsCfgGet home.dir] "templates" $tplName]

  if {![file exists $tplPath]} {
    set msg "Template not found: $tplPath"
    log "ERROR onCreateScript: $msg"
    tk_messageBox -icon error -title "Create Script" -message $msg
    return
  }

  set fh [open $tplPath r]
  fconfigure $fh -encoding utf-8
  set tplStr [read $fh]
  close $fh

  set dic [dict create \
    "flow-name" $flowName \
    "task-name" $taskName \
    "date-stamp" [getDateStamp]]
  set outStr [::wb::lib::applyDictToTemplate $dic $tplStr]

  # Ensure task directory exists
  set taskDir [file dirname $scriptPath]
  file mkdir $taskDir

  set fh [open $scriptPath w]
  fconfigure $fh -encoding utf-8 -translation lf
  puts -nonewline $fh $outStr
  close $fh

  log "wrote $tplName template to $scriptPath"
  ::wb::cfg::taskRefreshScriptButton
}

# ---------------------------------------------------------------------------
# onEditTaskHelp  helpPath
# Opens the task help .md file in the configured editor.
# ---------------------------------------------------------------------------
proc ::wb::cfg::onEditTaskHelp {helpPath} {
  log "onEditTaskHelp: opening $helpPath"
  if {[catch {fsOpenInEditor $helpPath} err]} {
    log "ERROR onEditTaskHelp: $err"
    tk_messageBox -icon error -title "Edit Task Help" -message $err
  }
}

# ---------------------------------------------------------------------------
# onViewTaskHelp  helpPath
# Opens (or refreshes) the task help window (.wbTaskHelp).
# ---------------------------------------------------------------------------
proc ::wb::cfg::onViewTaskHelp {helpPath} {
  variable panel
  set taskName [string trim $panel(taskName)]
  ::wb::cfg::openContextHelpWin .wbTaskHelp "Task Help -- $taskName" $helpPath
}

# ---------------------------------------------------------------------------
# openContextHelpWin  winPath  title  helpPath
#
# Opens a dedicated help toplevel (winPath) for a context help file.
# Unlike the main help (.wbHelp), this window:
#   - Uses a fixed toplevel path so each context has exactly one window.
#   - On first open: renders the MD file via ::wb::help::mdRender internals.
#   - On FocusIn: checks file mtime; re-renders only if file has changed.
#
# We bypass mdRender (which always destroys/recreates .wbHelp) and build
# the window ourselves, calling the internal render helpers directly.
# ---------------------------------------------------------------------------
proc ::wb::cfg::openContextHelpWin {winPath title helpPath} {
  if {![file exists $helpPath]} {
    tk_messageBox -icon error -title $title \
      -message "Help file not found:\n$helpPath"
    return
  }

  # If window exists: if it's already showing this exact help file, just
  # raise it (FocusIn's mtime check handles on-disk edits on its own).
  # If a DIFFERENT file is now being requested -- e.g. Task Help re-opened
  # after selecting a different task, or Flow Help for a different flow --
  # update tracking and re-render before raising. Previously this branch
  # always just raised unconditionally, so switching tasks while Task
  # Help was already open kept showing the PREVIOUS task's content under
  # the new window title.
  if {[winfo exists $winPath]} {
    set curPath ""
    catch { set curPath [file normalize $::wb::cfg::contextHelpPath($winPath)] }
    if {$curPath ne [file normalize $helpPath]} {
      wm title $winPath $title
      catch { $winPath.top.path configure -text $helpPath }
      set ::wb::cfg::contextHelpMtime($winPath) [file mtime $helpPath]
      set ::wb::cfg::contextHelpPath($winPath)  $helpPath
      set ::wb::cfg::contextHelpTitle($winPath) $title
      ::wb::cfg::_contextHelpRender $winPath $helpPath
    }
    wm deiconify $winPath
    raise $winPath
    focus $winPath
    return
  }

  # Build the window
  toplevel $winPath
  wm title $winPath $title
  wm geometry $winPath 900x640

  # Store current mtime so FocusIn can detect changes
  set ::wb::cfg::contextHelpMtime($winPath) [file mtime $helpPath]
  set ::wb::cfg::contextHelpPath($winPath)  $helpPath
  set ::wb::cfg::contextHelpTitle($winPath) $title

  # Path label at top
  ttk::frame $winPath.top
  pack $winPath.top -side top -fill x -padx 10 -pady {10 6}
  ttk::label $winPath.top.path -text $helpPath
  pack $winPath.top.path -side left -fill x -expand 1

  # Scrollable text body
  ttk::frame $winPath.body
  pack $winPath.body -side top -fill both -expand 1 -padx 10 -pady {0 10}
  text $winPath.body.t -wrap word -undo 0 -takefocus 1
  ttk::scrollbar $winPath.body.sy -orient vertical \
    -command [list $winPath.body.t yview]
  $winPath.body.t configure -yscrollcommand [list $winPath.body.sy set]
  grid $winPath.body.t  -row 0 -column 0 -sticky nsew
  grid $winPath.body.sy -row 0 -column 1 -sticky ns
  grid rowconfigure    $winPath.body 0 -weight 1
  grid columnconfigure $winPath.body 0 -weight 1

  # Configure text tags (reuse fs-help.tcl helper)
  ::wb::help::_configureTags $winPath.body.t

  # Initial render
  ::wb::cfg::_contextHelpRender $winPath $helpPath

  # Escape closes
  bind $winPath <Escape> [list destroy $winPath]

  # FocusIn: debounced reload -- 300ms delay to let editor autosave flush to disk
  bind $winPath <FocusIn> [list ::wb::cfg::_contextHelpScheduleReload $winPath]

  # Clean up per-window tracking (ours and fs-help.tcl's curFileMap/
  # curTitleMap/linkHandlerMap) when the window closes.
  bind $winPath <Destroy> [list ::wb::cfg::_contextHelpCleanup $winPath]

  focus $winPath.body.t
}

# ---------------------------------------------------------------------------
# _contextHelpScheduleReload  winPath
# Called on every FocusIn event for the window (including child widgets).
# Cancels any pending after-callback before scheduling a fresh one at +300ms,
# so rapid focus flaps collapse into a single reload check.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_contextHelpScheduleReload {winPath} {
  variable contextHelpAfterID
  if {[info exists contextHelpAfterID($winPath)]} {
    catch { after cancel $contextHelpAfterID($winPath) }
  }
  set contextHelpAfterID($winPath) \
    [after 300 [list ::wb::cfg::_contextHelpFocusIn $winPath]]
}

# ---------------------------------------------------------------------------
# _contextHelpRender  winPath  helpPath
# (Re-)renders helpPath into the existing text widget inside winPath.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_contextHelpRender {winPath helpPath} {
  set t $winPath.body.t
  if {![winfo exists $t]} { return }

  if {[catch {
    set fh [open $helpPath r]
    fconfigure $fh -encoding utf-8
    set md [read $fh]
    close $fh
  } err]} {
    log "ERROR _contextHelpRender: $err"
    return
  }

  $t configure -state normal
  $t delete 1.0 end
  ::wb::help::_mdIntoText $t $md
  $t configure -state disabled
  $t see 1.0

  # This window is built directly rather than through ::wb::help::mdRender,
  # so mdRender's own curFileMap/curTitleMap tracking never runs for it.
  # Set it explicitly here (on every render, including FocusIn reloads) so
  # fs-help.tcl's help:/help-same: cross-file links -- and their
  # backlinks -- resolve relative to this file rather than the process cwd.
  set title ""
  catch { set title $::wb::cfg::contextHelpTitle($winPath) }
  set ::wb::help::curFileMap($winPath)  [file normalize $helpPath]
  set ::wb::help::curTitleMap($winPath) $title
}

# ---------------------------------------------------------------------------
# _contextHelpCleanup  winPath
# Bound to <Destroy> on context help windows (.wbFlowHelp / .wbTaskHelp).
# Clears this window's entries from fs-cfg.tcl's own tracking arrays
# (contextHelpMtime/Path/Title/AfterID -- previously left to leak on
# close) and, via ::wb::help::_cleanupWindow, from fs-help.tcl's
# curFileMap/curTitleMap/linkHandlerMap.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_contextHelpCleanup {winPath} {
  variable contextHelpMtime
  variable contextHelpPath
  variable contextHelpTitle
  variable contextHelpAfterID

  if {[info exists contextHelpAfterID($winPath)]} {
    catch { after cancel $contextHelpAfterID($winPath) }
  }
  catch { unset contextHelpMtime($winPath) }
  catch { unset contextHelpPath($winPath) }
  catch { unset contextHelpTitle($winPath) }
  catch { unset contextHelpAfterID($winPath) }

  catch { ::wb::help::_cleanupWindow $winPath }
}

# ---------------------------------------------------------------------------
# _contextHelpFocusIn  winPath
# Called when the context help window gains focus.
# Checks file mtime; re-renders only if changed since last load.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_contextHelpFocusIn {winPath} {
  if {![info exists ::wb::cfg::contextHelpPath($winPath)]} { return }
  set helpPath $::wb::cfg::contextHelpPath($winPath)
  if {![file exists $helpPath]} { return }

  set newMtime [file mtime $helpPath]
  set oldMtime $::wb::cfg::contextHelpMtime($winPath)

  if {$newMtime > $oldMtime} {
    log "_contextHelpFocusIn: $helpPath changed -- reloading"
    set ::wb::cfg::contextHelpMtime($winPath) $newMtime
    ::wb::cfg::_contextHelpRender $winPath $helpPath
  }
}

# ---------------------------------------------------------------------------
# taskProvisionFiles  taskName  taskType
# Called when a new task is added (Apply in add mode).
# Creates the task directory and copies template files into it.
# Files are processed through applyDictToTemplate for customisation.
# Prompts skip/overwrite if a file already exists.
# ---------------------------------------------------------------------------
proc ::wb::cfg::taskProvisionFiles {taskName taskType} {
  set flowName [::wb::cfg::cfgBaseName]
  set tplDir   [file join [fsCfgGet home.dir] "templates"]
  set taskDir  [::wb::lib::pathTask $flowName $taskName ""]
  set taskDir  [file normalize $taskDir]

  # Create task directory if needed
  if {![file isdirectory $taskDir]} {
    file mkdir $taskDir
    log "taskProvisionFiles: created $taskDir $taskType"
  }

  set dic [dict create \
    "task-name" $taskName \
    "date-stamp" [getDateStamp]]

  # Build file list: {tplFile destFile} pairs
  set files {}

  # Type-specific script
  switch -- $taskType {
    "tcl-int" { lappend files [list "task-sync.tcl"  "${taskName}-sync.tcl"  ] }
    "tcl-ext" { lappend files [list "task-async.tcl" "${taskName}-async.tcl" ] }
  }

  # Always-copied files
  lappend files [list "brief.json"  "brief.json"  ]
  lappend files [list "runlog.txt"  "runlog.txt"  ]

  foreach pair $files {
    lassign $pair tplFile destFile

    set tplPath  [file join $tplDir $tplFile]
    set destPath [file join $taskDir $destFile]

    if {![file exists $tplPath]} {
      log "WARNING taskProvisionFiles: template not found: $tplPath -- skipping"
      continue
    }

    # Prompt if destination already exists
    if {[file exists $destPath]} {
      set ans [tk_messageBox \
        -icon question -type yesno -default no \
        -title "File Exists" \
        -message "$destFile already exists in task directory.\nOverwrite?"]
      if {$ans ne "yes"} {
        log "taskProvisionFiles: skipped $destFile"
        continue
      }
    }

    # Read, customise, write
    set fh [open $tplPath r]
    fconfigure $fh -encoding utf-8
    set tplStr [read $fh]
    close $fh

    set outStr [::wb::lib::applyDictToTemplate $dic $tplStr]

    set fh [open $destPath w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $outStr
    close $fh

    log "taskProvisionFiles: wrote $destPath"
  }
}

proc ::wb::cfg::panelLoadTask {{mode "edit"}} {
  variable curTaskName
  variable panel
  variable panelMode
  variable panelOrigTaskName
  variable panelErrMsg

  set panelMode $mode
  set panelErrMsg ""

  if {$mode eq "add"} {
    set panelOrigTaskName ""
    set panel(taskName) ""
    set panel(taskTitle) ""
    set panel(taskDesc) ""
    set panel(taskType) "tcl-int"
    set panel(staleAfterVal) ""
    set panel(staleAfterUnit) "secs"
    ::wb::cfg::panelPopulatePriorTaskLists
    ::wb::cfg::panelSetMultiSelection taskDepends {}
    ::wb::cfg::panelSetMultiSelection taskWhenFail {}
    set isFirstTask [expr {[llength [::wb::cfg::priorTaskNames]] == 0}]
    ::wb::cfg::panelToggleTaskChecklists [expr {!$isFirstTask}]
    ::wb::cfg::panelToggleStaleAfter $isFirstTask
    $::wb::cfg::ui(taskNameEntry) configure -state normal
    if {[info exists ::wb::cfg::ui(taskRenameBtn)]} {
      $::wb::cfg::ui(taskRenameBtn) configure -state disabled
    }
    ::wb::cfg::panelShowMode task
    ::wb::cfg::panelMarkClean
    focus $::wb::cfg::ui(taskNameEntry)
    return
  }

  if {$curTaskName eq ""} { return }
  set task [getTask $curTaskName]
  if {$task eq ""} { return }

  set panelOrigTaskName $curTaskName
  set panel(taskName)  [dict get $task name]
  set panel(taskTitle) [expr {[dict exists $task title] ? [dict get $task title] : ""}]
  set panel(taskDesc)  [expr {[dict exists $task desc] ? [dict get $task desc] : ""}]
  set panel(taskType)  [expr {[dict exists $task type] ? [dict get $task type] : "tcl-int"}]
  set depVals  [expr {[dict exists $task dependsOn] ? [dict get $task dependsOn] : {}}]
  set failVals [expr {[dict exists $task whenFail]   ? [dict get $task whenFail]  : {}}]
  set priorNames [::wb::cfg::priorTaskNames $curTaskName]

  # staleAfter: parse the stored "nnn[unit]" string (if any) back into
  # the two panel fields. Blank/unparseable -> treat as unset (0/off),
  # same "degrade quietly" stance fs-run.tcl's own parser takes.
  set panel(staleAfterVal) ""
  set panel(staleAfterUnit) "secs"
  if {[dict exists $task staleAfter]} {
    set rawSA [dict get $task staleAfter]
    if {[regexp {^\s*([0-9]+)\s*([a-zA-Z]*)\s*$} $rawSA -> saNum saUnit]} {
      set panel(staleAfterVal) $saNum
      if {$saUnit ne ""} { set panel(staleAfterUnit) [string tolower $saUnit] }
    }
  }

  # Pass existing selections so orphans (no longer prior) are shown in red
  ::wb::cfg::panelPopulatePriorTaskLists $curTaskName $depVals $failVals
  ::wb::cfg::panelSetMultiSelection taskDepends  $depVals
  ::wb::cfg::panelSetMultiSelection taskWhenFail $failVals
  ::wb::cfg::panelToggleTaskChecklists [expr {[llength $priorNames] > 0 || [llength $depVals] > 0 || [llength $failVals] > 0}]
  # staleAfter visibility is deliberately just "true first task" (no
  # orphan-forced-visible nuance the checklist toggle has above) -- see
  # the comment on panelToggleStaleAfter for the known rare edge case.
  ::wb::cfg::panelToggleStaleAfter [expr {[llength $priorNames] == 0}]
  $::wb::cfg::ui(taskNameEntry) configure -state readonly
  if {[info exists ::wb::cfg::ui(taskRenameBtn)]} {
    $::wb::cfg::ui(taskRenameBtn) configure -state normal
  }
  ::wb::cfg::panelShowMode task
  ::wb::cfg::panelMarkClean
}

proc ::wb::cfg::panelApplyFlow {} {
  variable cfgDict
  variable panel
  variable panelErrMsg

  set title [string trim $panel(flowTitle)]
  if {$title eq ""} {
    set panelErrMsg "Flow Title is required."
    return
  }

  dict set cfgDict title $title
  set panelErrMsg ""
  ::wb::cfg::cfgMarkDirty
  ::wb::cfg::uiLoadTasks
  ::wb::cfg::panelMarkClean
  log "Flow updated: title=$title"
}

proc ::wb::cfg::panelApplyTask {} {
  variable panel
  variable panelMode
  variable panelOrigTaskName
  variable curTaskName
  variable ui

  set name      [string trim $panel(taskName)]
  set title     [string trim $panel(taskTitle)]
  set desc      [string trim $panel(taskDesc)]
  set type      [string trim $panel(taskType)]
  set dependsOn [::wb::cfg::panelReadMultiSelection taskDepends]
  set whenFail  [::wb::cfg::panelReadMultiSelection taskWhenFail]

  # staleAfter: build the "nnn[unit]" string from the two panel fields.
  # Blank or 0 -> "" (meaning: don't save the key at all, per spec).
  # A genuinely bad value (non-numeric, negative) is a real validation
  # error, not silently treated as off -- surfaced the same way other
  # panel errors are, via panelErrMsg, and blocks nothing else from
  # being applied (matches how this panel already handles other soft
  # validation -- see validateTask).
  set staleAfterStr ""
  set rawVal [string trim $panel(staleAfterVal)]
  if {$rawVal ne "" && $rawVal ne "0"} {
    if {![string is integer -strict $rawVal] || $rawVal < 0} {
      set ::wb::cfg::panelErrMsg "Stale After must be a whole number \u2265 0."
    } else {
      set staleAfterStr "${rawVal}${panel(staleAfterUnit)}"
    }
  }

  if {$panelMode eq "add"} {
    set task [dict create name $name title $title desc $desc type $type]
    if {[llength $dependsOn] > 0} { dict set task dependsOn $dependsOn }
    if {[llength $whenFail]  > 0} { dict set task whenFail  $whenFail  }
    if {$staleAfterStr ne ""}     { dict set task staleAfter $staleAfterStr }
    ::wb::cfg::appendTask $task
    ::wb::cfg::taskProvisionFiles $name $type
    set curTaskName $name
    set panelMode "edit"
    set panelOrigTaskName $name
    $ui(taskNameEntry) configure -state readonly
    ::wb::cfg::uiLoadTasks
    set idx [::wb::cfg::taskIndexByName $name]
    if {$idx >= 0} { ::wb::cfg::taskTvSelect $idx }
    ::wb::cfg::uiSelectTask
    ::wb::cfg::panelMarkClean
    log "Task added: $name"
    ::wb::cfg::validateTask
    return
  }

  # edit mode
  set task [getTask $panelOrigTaskName]
  dict set task title $title
  dict set task desc  $desc
  dict set task type  $type
  if {[llength $dependsOn] > 0} {
    dict set task dependsOn $dependsOn
  } elseif {[dict exists $task dependsOn]} {
    dict unset task dependsOn
  }
  if {[llength $whenFail] > 0} {
    dict set task whenFail $whenFail
  } elseif {[dict exists $task whenFail]} {
    dict unset task whenFail
  }
  if {$staleAfterStr ne ""} {
    dict set task staleAfter $staleAfterStr
  } elseif {[dict exists $task staleAfter]} {
    dict unset task staleAfter
  }
  ::wb::cfg::setTask $panelOrigTaskName $task
  ::wb::cfg::uiLoadTasks
  set idx [::wb::cfg::taskIndexByName $panelOrigTaskName]
  if {$idx >= 0} { ::wb::cfg::taskTvSelect $idx }
  ::wb::cfg::uiSelectTask
  ::wb::cfg::panelMarkClean
  log "Task updated: $panelOrigTaskName"
  ::wb::cfg::validateTask
}

# ---------------------------------------------------------------------------
# validateTaskName  name
#
# Same naming rule flow names already use (2-40 chars, lowercase
# letters/digits/hyphens, must start with a letter, must not end with a
# hyphen). Kept local rather than calling ::wb::new::validateFlowName --
# fs-cfg.tcl doesn't source fs-new.tcl, so that proc isn't actually
# loaded in this process.
# ---------------------------------------------------------------------------
proc ::wb::cfg::validateTaskName {name} {
  if {[string length $name] < 2 || [string length $name] > 40} {
    return "Task name must be 2-40 characters."
  }
  if {![regexp {^[a-z][a-z0-9-]*[a-z0-9]$} $name]} {
    return "Task name must be lowercase letters, digits, and hyphens only; must start with a letter and not end with a hyphen."
  }
  return ""
}

# ---------------------------------------------------------------------------
# uiRenameTask
#
# Opens a small modal dialog to rename the currently selected task. The
# name field itself is read-only in the main task panel (see
# panelLoadTask) -- this dialog is the only path to a rename, so the
# validation + queueing logic all lives in one place.
# ---------------------------------------------------------------------------
proc ::wb::cfg::uiRenameTask {} {
  variable curTaskName
  if {$curTaskName eq ""} { return }

  set w .wbRenameTaskDlg
  catch { destroy $w }
  toplevel $w
  wm title $w "Rename Task"
  wm transient $w .
  wm resizable $w 1 1
  wm protocol $w WM_DELETE_WINDOW [list destroy $w]

  set ::wb::cfg::renameDlg(newName) $curTaskName
  set ::wb::cfg::renameDlg(errMsg)  ""

  frame $w.f -padx 14 -pady 12
  pack  $w.f -fill both -expand 1

  label $w.f.curL -text "Current name:" -anchor e
  label $w.f.curV -text $curTaskName -anchor w -font TkBoldFont
  grid  $w.f.curL -row 0 -column 0 -sticky e -padx {0 8} -pady 4
  grid  $w.f.curV -row 0 -column 1 -sticky w -pady 4

  label $w.f.newL -text "New name:" -anchor e
  entry $w.f.newE -textvariable ::wb::cfg::renameDlg(newName) -width 40
  grid  $w.f.newL -row 1 -column 0 -sticky e -padx {0 8} -pady 4
  grid  $w.f.newE -row 1 -column 1 -sticky we -pady 4

  label $w.f.note -anchor w -justify left -wraplength 400 \
    -foreground "#666666" \
    -text "The task's on-disk folder isn't renamed until you Save (and, in development mode, only on a final Save)."
  grid  $w.f.note -row 2 -column 0 -columnspan 2 -sticky w -pady {6 0}

  label $w.f.err -textvariable ::wb::cfg::renameDlg(errMsg) \
    -foreground red -anchor w -justify left -wraplength 400
  grid  $w.f.err -row 3 -column 0 -columnspan 2 -sticky w -pady {4 0}

  frame $w.f.btns
  grid  $w.f.btns -row 4 -column 0 -columnspan 2 -sticky e -pady {10 0}
  ttk::button $w.f.btns.cancel -style WbRounded.TButton -text "Cancel" \
    -command [list destroy $w]
  ttk::button $w.f.btns.rename -style WbRounded.TButton -text "Rename" \
    -command [list ::wb::cfg::uiRenameTaskCommit $w $curTaskName]
  pack $w.f.btns.cancel -side left  -padx 4
  pack $w.f.btns.rename -side right -padx 4

  grid columnconfigure $w.f 1 -weight 1

  bind $w.f.newE <Return> [list ::wb::cfg::uiRenameTaskCommit $w $curTaskName]

  update idletasks
  ::wb::cfg::centerWin $w 480 260
  grab set $w
  focus $w.f.newE
  $w.f.newE selection range 0 end
}

# ---------------------------------------------------------------------------
# uiRenameTaskCommit  dlgWin  oldName
#
# Validates the new name (same rule as flow names: lowercase/digits/
# hyphens, 2-40 chars) and uniqueness against the live task list, then
# hands off to commitTaskRename. Renaming to the same name is a silent
# no-op close, not an error.
# ---------------------------------------------------------------------------
proc ::wb::cfg::uiRenameTaskCommit {dlgWin oldName} {
  set newName [string trim $::wb::cfg::renameDlg(newName)]

  if {$newName eq $oldName} {
    catch { grab release $dlgWin }
    destroy $dlgWin
    return
  }

  set nameErr [::wb::cfg::validateTaskName $newName]
  if {$nameErr ne ""} {
    set ::wb::cfg::renameDlg(errMsg) $nameErr
    ::wb::cfg::_resizeRenameDlgToFit $dlgWin
    return
  }

  if {[::wb::cfg::taskIndexByName $newName] >= 0} {
    set ::wb::cfg::renameDlg(errMsg) "Task '$newName' already exists."
    ::wb::cfg::_resizeRenameDlgToFit $dlgWin
    return
  }

  catch { grab release $dlgWin }
  destroy $dlgWin
  ::wb::cfg::commitTaskRename $oldName $newName
}

# ---------------------------------------------------------------------------
# _resizeRenameDlgToFit  dlgWin
#
# centerWin sets an explicit wm geometry string, which disables Tk's
# automatic content-based resizing for that window from then on -- so the
# dialog sizes correctly for whatever's in it at the moment centerWin is
# called, but never grows again on its own afterward. The error label's
# text only appears after a failed validation, so it needs a fresh resize
# each time it changes, not just once at dialog creation.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_resizeRenameDlgToFit {dlgWin} {
  if {![winfo exists $dlgWin]} { return }
  # Let geometry propagation compute the natural size for the new content
  # before centerWin measures it.
  wm geometry $dlgWin ""
  update idletasks
  ::wb::cfg::centerWin $dlgWin 480 260
}

# ---------------------------------------------------------------------------
# commitTaskRename  oldName  newName
#
# The in-memory side of a rename -- nothing touches disk here:
#   - rewrites dependsOn/whenFail references to oldName in every other
#     task (so a rename never produces an orphaned dependency)
#   - updates the task's own name in cfgDict
#   - updates curTaskName / panelOrigTaskName so the panel keeps tracking
#     the same task under its new name
#   - queues {oldName newName} for the actual folder/file rename, applied
#     later by applyPendingRenames on a final Save
# ---------------------------------------------------------------------------
proc ::wb::cfg::commitTaskRename {oldName newName} {
  variable curTaskName
  variable panelOrigTaskName

  set task [::wb::cfg::getTask $oldName]
  if {$task eq ""} { return }

  ::wb::cfg::rewriteTaskRefs $oldName $newName

  dict set task name $newName
  ::wb::cfg::setTask $oldName $task

  if {$curTaskName eq $oldName} { set curTaskName $newName }
  if {[info exists panelOrigTaskName] && $panelOrigTaskName eq $oldName} {
    set panelOrigTaskName $newName
  }

  ::wb::cfg::queuePendingRename $oldName $newName
  ::wb::cfg::cfgMarkDirty

  ::wb::cfg::uiLoadTasks
  set idx [::wb::cfg::taskIndexByName $newName]
  if {$idx >= 0} { ::wb::cfg::taskTvSelect $idx }
  ::wb::cfg::uiSelectTask

  log "Task renamed: '$oldName' -> '$newName' (folder rename queued for next final Save)"
}

# ---------------------------------------------------------------------------
# rewriteTaskRefs  oldName  newName
#
# Rewrites any dependsOn/whenFail entry equal to oldName, in every task,
# to newName. Called before the renamed task's own name field is updated.
# ---------------------------------------------------------------------------
proc ::wb::cfg::rewriteTaskRefs {oldName newName} {
  variable cfgDict

  set tasks [::wb::cfg::taskList]
  set changed 0
  set newTasks {}
  foreach t $tasks {
    if {[dict exists $t dependsOn]} {
      set dep [dict get $t dependsOn]
      set idx [lsearch -exact $dep $oldName]
      if {$idx >= 0} {
        dict set t dependsOn [lreplace $dep $idx $idx $newName]
        set changed 1
      }
    }
    if {[dict exists $t whenFail]} {
      set wf [dict get $t whenFail]
      set idx [lsearch -exact $wf $oldName]
      if {$idx >= 0} {
        dict set t whenFail [lreplace $wf $idx $idx $newName]
        set changed 1
      }
    }
    lappend newTasks $t
  }
  if {$changed} {
    dict set cfgDict tasks $newTasks
  }
  return $changed
}

# ---------------------------------------------------------------------------
# queuePendingRename  oldName  newName
#
# Adds {oldName newName} to pendingRenames, collapsing chains: if oldName
# is already the *target* of an earlier pending rename (task renamed
# twice before Save), that earlier entry's target is updated instead of
# adding a second hop -- so the disk only ever moves once, straight from
# the original on-disk folder name to the final chosen name. If the net
# result is a no-op (renamed right back to its original on-disk name),
# the entry is dropped entirely.
# ---------------------------------------------------------------------------
proc ::wb::cfg::queuePendingRename {oldName newName} {
  variable pendingRenames

  set foundIdx -1
  for {set i 0} {$i < [llength $pendingRenames]} {incr i} {
    lassign [lindex $pendingRenames $i] o n
    if {$n eq $oldName} { set foundIdx $i; break }
  }

  if {$foundIdx >= 0} {
    lassign [lindex $pendingRenames $foundIdx] origOld origNew
    if {$origOld eq $newName} {
      set pendingRenames [lreplace $pendingRenames $foundIdx $foundIdx]
    } else {
      set pendingRenames [lreplace $pendingRenames $foundIdx $foundIdx [list $origOld $newName]]
    }
  } else {
    lappend pendingRenames [list $oldName $newName]
  }
}

proc ::wb::cfg::panelApply {} {
  variable curMode
  if {$curMode eq "flow"} {
    ::wb::cfg::panelApplyFlow
    return
  }
  if {$curMode eq "task"} {
    ::wb::cfg::panelApplyTask
    return
  }
}

# -------------------------
# Option formatting (cfg window list)
# -------------------------
proc ::wb::cfg::trimJoin {lst {maxChars 60}} {
  set s [join $lst "|"]
  if {[string length $s] > $maxChars} {
    return "[string range $s 0 [expr {$maxChars-4}]]..."
  }
  return $s
}

proc ::wb::cfg::stripStar {v} {
  set x [string trim $v]
  if {[string index $x 0] eq "*"} { return [string range $x 1 end] }
  return $x
}

proc ::wb::cfg::findDefaultValue {vals} {
  foreach v $vals {
    set x [string trim $v]
    if {[string index $x 0] eq "*"} { return [string range $x 1 end] }
  }
  return ""
}

proc ::wb::cfg::uiLoadTasks {{errDict {}}} {
  variable ui
  variable curTaskName
  $ui(taskList) delete 0 end
  foreach t [taskList] {
    set name  [dict get $t name]
    set title [dict get $t title]
    if {[dict exists $errDict $name]} {
      $ui(taskList) insert end "$title  <<has error>>"
    } else {
      $ui(taskList) insert end $title
    }
  }
  # Restore selection if we have a current task
  if {$curTaskName ne ""} {
    set idx [::wb::cfg::taskIndexByName $curTaskName]
    if {$idx >= 0} {
      ::wb::cfg::taskTvSelect $idx
    }
  }
}

proc ::wb::cfg::taskTvSelect {idx} {
  variable ui
  set lb $ui(taskList)
  $lb selection clear 0 end
  $lb selection set $idx
  $lb activate $idx
  $lb see $idx
}

proc ::wb::cfg::taskTvSize {} {
  variable ui
  return [$ui(taskList) size]
}


proc ::wb::cfg::uiSelectTask {} {
  variable ui
  variable curTaskName
  variable curItemIndex
  variable panelGuardTaskSelect

  if {$panelGuardTaskSelect} { return }

  # Task selection has no meaning in flow mode
  if {$::wb::cfg::curMode eq "flow"} { return }

  set sel [$ui(taskList) curselection]
  if {$sel eq ""} { return }
  set idx [lindex $sel 0]
  set task [lindex [taskList] $idx]
  set newTaskName [dict get $task name]

  if {$::wb::cfg::curMode eq "task" && $curTaskName ne "" && $newTaskName ne $curTaskName && ![::wb::cfg::panelConfirmDiscard]} {
    set oldIdx [::wb::cfg::taskIndexByName $curTaskName]
    if {$oldIdx >= 0} {
      set panelGuardTaskSelect 1
      ::wb::cfg::taskTvSelect $oldIdx
      set panelGuardTaskSelect 0
    }
    return
  }

  set curTaskName $newTaskName
  set curItemIndex -1

  $ui(taskName) configure -text "[dict get $task title]  ([dict get $task name])"
  ::wb::cfg::uiLoadItems
  if {$::wb::cfg::curMode eq "task"} {
    ::wb::cfg::panelLoadTask edit
  }
  ::wb::cfg::uiUpdateItemButtons
  log "Selected task: $curTaskName (mode=$::wb::cfg::curMode)"
  switch -exact -- $::wb::cfg::curMode {
    options { ::wb::cfg::validateOptions  }
    parms   { ::wb::cfg::validateParms    }
    runprop { ::wb::cfg::validateRunprops }
    default { ::wb::cfg::validateTask     }
  }
}


proc ::wb::cfg::existingLabelsForCurrentTask {} {
  variable curTaskName
  set task [getTask $curTaskName]
  set labels {}
  if {[dict exists $task opts]} {
    foreach od [dict get $task opts] {
      if {[dict exists $od label]} { lappend labels [dict get $od label] }
    }
  }
  return $labels
}


proc ::wb::cfg::fieldForMode {mode} {
  switch -exact -- $mode {
    flow    { return "flow" }
    options { return "opts" }
    parms   { return "parms" }
    task    { return "task" }
    runprop { return "runprops" }
    default { return "task" }
  }
}

proc ::wb::cfg::modeTitle {mode} {
  # For button labels
  switch -exact -- $mode {
    flow    { return "Flow" }
    options { return "Option" }
    parms   { return "Parm" }
    task    { return "Task" }
    runprop { return "Runprop" }
    default { return "Item" }
  }
}

proc ::wb::cfg::getTaskFieldForMode {task mode} {
  variable cfgDict
  if {$mode eq "flow"} {
    if {[dict exists $cfgDict title]} { return [dict get $cfgDict title] }
    return ""
  }
  set f [::wb::cfg::fieldForMode $mode]
  if {![dict exists $task $f]} { return "" }
  return [dict get $task $f]
}

proc ::wb::cfg::normTaskFieldForMode {raw mode} {
  # If missing or "", treat as empty list (options/parms) or empty dict (hooks/runprop)
  if {$raw eq ""} {
    if {$mode eq "options" || $mode eq "parms"} { return {} }
    return [dict create]
  }

  if {$mode eq "options" || $mode eq "parms"} {
    # list modes
    return $raw
  }

  # dict modes
  if {![catch {dict size $raw}]} { return $raw }
  return [dict create]
}


proc ::wb::cfg::uiSetMode {mode} {
  variable ui
  variable curMode
  variable curItemIndex
  variable curItemKey

  if {$mode ne $curMode && ![::wb::cfg::panelConfirmDiscard]} {
    if {[info exists ui(modeCombo)] && [winfo exists $ui(modeCombo)]} {
      $ui(modeCombo) set $curMode
    }
    return
  }

  # Always re-enable task list -- flow mode disables it, all other modes need it active
  if {[info exists ui(taskList)] && [winfo exists $ui(taskList)]} {
    $ui(taskList) configure -state normal
  }

  set curMode $mode
  set curItemIndex -1
  set curItemKey ""

  ::wb::cfg::itemPanelMarkClean
  ::wb::cfg::itemPanelUpdateLabel
  ::wb::cfg::uiLoadItems

  if {$curMode eq "flow"} {
    # Deselect task list and disable selection binding -- flow mode has no
    # concept of a selected task and clicks would trigger spurious validation
    if {[info exists ui(taskList)] && [winfo exists $ui(taskList)]} {
      $ui(taskList) selection clear 0 end
      $ui(taskList) configure -state disabled
    }
    ::wb::cfg::panelLoadFlow
    ::wb::cfg::uiUpdateItemButtons
    return
  }

  if {$curMode eq "task"} {
    ::wb::cfg::panelLoadTask edit
    ::wb::cfg::uiUpdateItemButtons
    return
  }

  if {$curMode eq "parms"} {
    if {[info exists ui(parmsTv)] && [winfo exists $ui(parmsTv)]} {
      $ui(parmsTv) selection set {}
    }
    set curItemIndex -1
    ::wb::cfg::uiUpdateItemButtons
    ::wb::cfg::validateParms
    return
  }

  if {$curMode eq "runprop"} {
    if {[info exists ui(runpropsTv)] && [winfo exists $ui(runpropsTv)]} {
      $ui(runpropsTv) selection set {}
    }
    set curItemIndex -1
    ::wb::cfg::uiUpdateItemButtons
    ::wb::cfg::validateRunprops
    return
  }

  # v79: options mode uses treeview grid; clear selection on mode switch
  if {$curMode eq "options"} {
    if {[info exists ui(optsTv)] && [winfo exists $ui(optsTv)]} {
      $ui(optsTv) selection set {}
    }
    set curItemIndex -1
    ::wb::cfg::uiUpdateItemButtons
    return
  }

  ::wb::cfg::panelShowMode $curMode
  ::wb::cfg::uiUpdateItemButtons
}


proc ::wb::cfg::uiLoadItems {} {
  variable ui
  variable curTaskName
  variable curMode

  if {![info exists ui(itemsList)]} { return }

  if {$curMode eq "flow" || $curMode eq "task"} {
    ::wb::cfg::panelShowMode $curMode
    return
  }

  ::wb::cfg::panelShowMode $curMode
  $ui(itemsList) delete 0 end
  if {$curTaskName eq ""} { return }

  set task [getTask $curTaskName]
  set raw  [::wb::cfg::getTaskFieldForMode $task $curMode]
  set val  [::wb::cfg::normTaskFieldForMode $raw $curMode]

  if {$curMode eq "parms"} {
    ::wb::cfg::uiLoadParmsGrid
    return
  }

  # (leave your existing logic for other modes as-is)
  if {$curMode eq "options"} {
    # v79: use treeview grid
    if {[info commands ::wb::cfg::uiLoadOptsGrid] ne ""} {
      ::wb::cfg::uiLoadOptsGrid
      return
    }
    # fallback: legacy optsList (fs-opts.tcl override)
    if {[info commands ::wb::cfg::uiLoadOpts] ne "" && [info exists ui(optsList)]} {
      ::wb::cfg::uiLoadOpts
      return
    }
    foreach od $val {
      set label ""
      if {![catch {dict get $od label} _lab]} { set label $_lab }
      if {$label eq ""} { set label "<option>" }
      $ui(itemsList) insert end $label
    }
    return
  }

  if {$curMode eq "runprop"} {
    ::wb::cfg::uiLoadRunpropsGrid
    return
  }

  if {![catch {dict size $val}]} {
    foreach {k v} $val {
      $ui(itemsList) insert end "$k: $v"
    }
  }
}
# -------------------------
# Options grid (treeview) support - v79
# -------------------------

# Build tooltip text from an option dict (all "extra" fields beyond Label/Type/Parm/Place)
proc ::wb::cfg::optsTipText {od} {
  set parts {}
  foreach {key label} {hint Hint reqd Reqd dflt Default vals Values} {
    if {[dict exists $od $key]} {
      set v [dict get $od $key]
      if {$v ne "" && $v ne {}} {
        lappend parts "$label: $v"
      }
    }
  }
  return [join $parts "  |  "]
}

# Load all opts into the treeview grid
proc ::wb::cfg::uiLoadOptsGrid {} {
  variable ui
  variable curTaskName

  if {![info exists ui(optsTv)] || ![winfo exists $ui(optsTv)]} { return }
  set tv $ui(optsTv)

  # Clear existing rows and stored tooltip map
  $tv delete [$tv children {}]
  catch { unset ::wb::cfg::optsTipMap }
  array set ::wb::cfg::optsTipMap {}

  if {$curTaskName eq ""} { return }

  set task [::wb::cfg::getTask $curTaskName]
  set raw  [::wb::cfg::getTaskFieldForMode $task "options"]
  set val  [::wb::cfg::normTaskFieldForMode $raw "options"]

  set rowIdx 0
  foreach od $val {
    set label ""
    set type  ""
    set parm  ""
    set place ""

    catch { set label [dict get $od label] }
    catch { set type  [dict get $od type]  }
    catch { set parm  [dict get $od parm]  }

    # check/text/file/directory store scalar "place"; radio/select store list "places"
    if {$type in {"radio" "select"}} {
      if {[dict exists $od places]} {
        set pl [dict get $od places]
        if {[llength $pl] > 0} { set place [join $pl ", "] }
      }
    } else {
      catch { set place [dict get $od place] }
    }

    # rowId encodes the original index for selection mapping
    set rowId "opt_row_$rowIdx"
    $tv insert {} end -id $rowId -values [list $label $type $parm $place]

    # Store tooltip text keyed by rowId
    set tip [::wb::cfg::optsTipText $od]
    set ::wb::cfg::optsTipMap($rowId) $tip

    incr rowIdx
  }

  # Attach motion-based tooltip to the treeview
  ::wb::cfg::optsGridAttachTooltip $tv
}

# Motion tooltip for the options treeview
proc ::wb::cfg::optsGridAttachTooltip {tv} {
  bind $tv <Motion> [list ::wb::cfg::optsGridTipMotion %W %x %y %X %Y]
  bind $tv <Leave>  [list ::wb::cfg::tipHide]
}

proc ::wb::cfg::optsGridTipMotion {tv x y rx ry} {
  set item [$tv identify row $x $y]
  if {$item eq ""} { ::wb::cfg::tipHide; return }
  if {![info exists ::wb::cfg::optsTipMap($item)]} { ::wb::cfg::tipHide; return }
  set tip $::wb::cfg::optsTipMap($item)
  if {$tip eq ""} { ::wb::cfg::tipHide; return }
  ::wb::cfg::tipShow $rx $ry $tip
}

# Treeview selection handler - maps to curItemIndex and fires button update
proc ::wb::cfg::uiOptsGridSelect {} {
  variable ui
  variable curItemIndex

  if {![info exists ui(optsTv)] || ![winfo exists $ui(optsTv)]} { return }
  set tv $ui(optsTv)

  set sel [$tv selection]
  if {$sel eq ""} {
    set curItemIndex -1
    ::wb::cfg::uiUpdateItemButtons
    return
  }

  set rowId [lindex $sel 0]
  # rowId is "opt_row_N" - extract index
  if {[regexp {opt_row_(\d+)$} $rowId -> idx]} {
    set curItemIndex $idx
  } else {
    set curItemIndex -1
  }
  ::wb::cfg::uiUpdateItemButtons
}

# Select a row in the options treeview by index (mirrors uiSelectIndex for listbox)
proc ::wb::cfg::optsGridSelectIndex {idx} {
  variable ui
  variable curItemIndex
  if {![info exists ui(optsTv)] || ![winfo exists $ui(optsTv)]} { return }
  set tv $ui(optsTv)
  set rowId "opt_row_$idx"
  if {[$tv exists $rowId]} {
    $tv selection set $rowId
    $tv see $rowId
    set curItemIndex $idx
    ::wb::cfg::uiUpdateItemButtons
  }
}

# -------------------------
# Parms grid (treeview) support
# -------------------------

proc ::wb::cfg::uiLoadParmsGrid {} {
  variable ui
  variable curTaskName

  if {![info exists ui(parmsTv)] || ![winfo exists $ui(parmsTv)]} { return }
  set tv $ui(parmsTv)

  $tv delete [$tv children {}]
  catch { unset ::wb::cfg::parmsTipMap }
  array set ::wb::cfg::parmsTipMap {}

  if {$curTaskName eq ""} { return }

  set task [::wb::cfg::getTask $curTaskName]
  set raw  [::wb::cfg::getTaskFieldForMode $task "parms"]
  set val  [::wb::cfg::normTaskFieldForMode $raw "parms"]

  log "uiLoadParmsGrid: task=$curTaskName rowCount=[llength $val]"

  set rowIdx 0
  foreach pd $val {
    set parm     ""
    set parmExec ""
    set hint     ""
    catch { set parm     [dict get $pd parm]     }
    catch { set parmExec [dict get $pd parmExec] }
    catch { set hint     [dict get $pd hint]     }

    # Type: first token before : in parmExec (e.g. "eval:..." -> "eval", "copy:..." -> "copy")
    if {[string first ":" $parmExec] >= 0} {
      set typeCol [lindex [split $parmExec ":"] 0]
    } else {
      set typeCol $parmExec
    }

    set rowId "parm_row_$rowIdx"
    $tv insert {} end -id $rowId -values [list $parm $typeCol]

    # Tooltip: parmExec always shown, hint appended if present
    set tip $parmExec
    if {$hint ne ""} { append tip "\n$hint" }
    if {$tip ne ""} { set ::wb::cfg::parmsTipMap($rowId) $tip }
    incr rowIdx
  }

  ::wb::cfg::parmsGridAttachTooltip $tv
}

proc ::wb::cfg::parmsGridAttachTooltip {tv} {
  bind $tv <Motion> [list ::wb::cfg::parmsGridTipMotion %W %x %y %X %Y]
  bind $tv <Leave>  [list ::wb::cfg::tipHide]
}

proc ::wb::cfg::parmsGridTipMotion {tv x y rx ry} {
  set item [$tv identify row $x $y]
  if {$item eq ""} { ::wb::cfg::tipHide; return }
  if {![info exists ::wb::cfg::parmsTipMap($item)]} { ::wb::cfg::tipHide; return }
  set tip $::wb::cfg::parmsTipMap($item)
  if {$tip eq ""} { ::wb::cfg::tipHide; return }
  ::wb::cfg::tipShow $rx $ry $tip
}

proc ::wb::cfg::parmsGridSelect {} {
  variable ui
  variable curItemIndex
  if {![info exists ui(parmsTv)] || ![winfo exists $ui(parmsTv)]} { return }
  set tv $ui(parmsTv)
  set sel [$tv selection]
  if {$sel eq ""} { set curItemIndex -1; ::wb::cfg::uiUpdateItemButtons; return }
  set rowId [lindex $sel 0]
  if {[regexp {parm_row_(\d+)$} $rowId -> idx]} {
    set curItemIndex $idx
  } else {
    set curItemIndex -1
  }
  ::wb::cfg::uiUpdateItemButtons
}

# -------------------------
# Runprops grid (treeview) support
# -------------------------

proc ::wb::cfg::uiLoadRunpropsGrid {} {
  variable ui
  variable curTaskName

  if {![info exists ui(runpropsTv)] || ![winfo exists $ui(runpropsTv)]} { return }
  set tv $ui(runpropsTv)

  $tv delete [$tv children {}]

  if {$curTaskName eq ""} { return }

  set task [::wb::cfg::getTask $curTaskName]
  set raw  [::wb::cfg::getTaskFieldForMode $task "runprop"]
  set val  [::wb::cfg::normTaskFieldForMode $raw "runprop"]

  set rowIdx 0
  if {![catch {dict size $val}]} {
    foreach {k v} $val {
      set rowId "run_row_$rowIdx"
      $tv insert {} end -id $rowId -values [list $k $v]
      incr rowIdx
    }
  }
}

proc ::wb::cfg::runpropsGridSelect {} {
  variable ui
  variable curItemIndex
  if {![info exists ui(runpropsTv)] || ![winfo exists $ui(runpropsTv)]} { return }
  set tv $ui(runpropsTv)
  set sel [$tv selection]
  if {$sel eq ""} { set curItemIndex -1; ::wb::cfg::uiUpdateItemButtons; return }
  set rowId [lindex $sel 0]
  if {[regexp {run_row_(\d+)$} $rowId -> idx]} {
    set curItemIndex $idx
  } else {
    set curItemIndex -1
  }
  ::wb::cfg::uiUpdateItemButtons
}

proc ::wb::cfg::uiSelectItem {} {
  variable ui
  variable curMode
  variable curItemIndex
  variable curItemKey

  if {$curMode eq "flow" || $curMode eq "task"} {
    set curItemIndex -1
    set curItemKey ""
    ::wb::cfg::uiUpdateItemButtons
    return
  }

  # options mode uses the treeview; selection already handled by uiOptsGridSelect
  if {$curMode eq "options"} {
    ::wb::cfg::uiUpdateItemButtons
    return
  }

  set sel [$ui(itemsList) curselection]
  if {$sel eq ""} {
    set curItemIndex -1
    set curItemKey ""
    ::wb::cfg::uiUpdateItemButtons
    return
  }
  set curItemIndex [lindex $sel 0]
  set curItemKey ""

  if {$curMode eq "hooks" || $curMode eq "runprop"} {
    set line [$ui(itemsList) get $curItemIndex]
    set p [string first ":" $line]
    if {$p >= 0} {
      set curItemKey [string trim [string range $line 0 [expr {$p-1}]]]
    }
  }
  ::wb::cfg::uiUpdateItemButtons
}

# -------------------------
# Help system (v92)
# -------------------------

# Derive a human-readable title from a help md filename.
proc ::wb::cfg::helpTitleFromFile {mdFile} {
  set base [file rootname [file tail $mdFile]]
  # e.g. wb-cfg-help -> "WB Cfg Help", wb-cfg-task-parms -> "Parms Configuration"
  set map {
    "fs-cfg-help"               "FlowSmithy Configurator Help"
    "fs-cfg-flow-help"          "Flow Configuration"
    "fs-cfg-task-help"          "Task Configuration"
    "fs-cfg-task-options-help"  "Options Configuration"
    "fs-cfg-task-parms-help"    "Parms Configuration"
    "fs-cfg-task-runprops-help" "Runprops Configuration"
  }
  if {[dict exists $map $base]} { return [dict get $map $base] }
  return $base
}

# Open a help page by filename (relative to [fsCfgGet home.dir]/help).
# Open a help page by filename (relative to [fsCfgGet home.dir]/help).
# fromFile/fromLabel: if non-empty, passed as -backlink to the renderer.
# topFile/topLabel:   if non-empty (and distinct from back), passed as -backtop.
proc ::wb::cfg::openHelpPage {mdFile {fromLabel ""} {fromFile ""} {topLabel ""} {topFile ""}} {
  variable helpBackStack

  set helpDir ""
  set fsHome [fsCfgGet home.dir]
  if {$fsHome eq ""} {
    tk_messageBox -icon error -title "Help" \
      -message "home.dir is not defined in flowsmithy.cfg"
    return
  }
  set helpDir [file join $fsHome help]
  set mdPath [file join $helpDir $mdFile]
  if {![file exists $mdPath]} {
    tk_messageBox -icon error -title "Help" \
      -message "Help file not found:\n$mdPath"
    return
  }

  set title [::wb::cfg::helpTitleFromFile $mdFile]
  set args  [list -linkhandler ::wb::cfg::helpLinkHandler]
  if {$fromLabel ne "" && $fromFile ne ""} {
    lappend args -backlink [list $fromLabel "help://$fromFile"]
  }
  if {$topLabel ne "" && $topFile ne "" && $topFile ne $fromFile} {
    lappend args -backtop [list $topLabel "backtop://$topFile"]
  }

  # Update back stack: remember where we came from for the next navigate
  set helpBackStack [list $title $mdFile]

  catch { destroy .wbHelp }
  ::wb::help::mdRender $title $mdPath {*}$args
}

# Link handler for all help window clicks.
# help://    -> navigate one level deeper, pushing current page as back target
# backtop:// -> navigate to root page and clear the back stack
proc ::wb::cfg::helpLinkHandler {url} {
  variable helpBackStack

  if {[string match "help://*" $url]} {
    set mdFile [string range $url [string length "help://"] end]
    log "Help navigate: $mdFile"
    # Current page becomes the back target for the new page
    set fromLabel ""
    set fromFile  ""
    set topLabel  ""
    set topFile   ""
    if {[llength $helpBackStack] >= 2} {
      set fromLabel [lindex $helpBackStack 0]
      set fromFile  [lindex $helpBackStack 1]
      # Top is always the root entry point
      set topLabel  "FlowSmithy Help"
      set topFile   "fs-cfg-help.md"
    }
    ::wb::cfg::openHelpPage $mdFile $fromLabel $fromFile $topLabel $topFile
    return
  }

  if {[string match "backtop://*" $url]} {
    set mdFile [string range $url [string length "backtop://"] end]
    log "Help back-to-top: $mdFile"
    # Clear the stack -- we are back at root
    set helpBackStack {}
    ::wb::cfg::openHelpPage $mdFile
    return
  }

  log "Help: ignoring unrecognised link: $url"
}

# Called by the Help button on the global bar.
# Clears back stack -- top-level entry point.
proc ::wb::cfg::onHelpHelp {} {
  variable helpBackStack
  set helpBackStack {}
  ::wb::cfg::openHelpPage "fs-cfg-help.md"
}

# Update the Clone button on the global bar to reflect current mode.
# Called from uiUpdateItemButtons whenever mode or selection changes.
proc ::wb::cfg::uiUpdateGlobalButtons {} {
  variable ui
  variable curMode

  if {![info exists ui(btnGClone)] || ![winfo exists $ui(btnGClone)]} { return }

  if {$curMode eq "flow" || $curMode eq "options" || $curMode eq "parms" || $curMode eq "runprop"} {
    pack forget $ui(btnGClone)
    return
  }

  set cap [::wb::cfg::modeTitle $curMode]
  $ui(btnGClone) configure -text "Clone $cap..."
  pack $ui(btnGClone) -in [winfo parent $ui(btnGClone)] -side left -padx 4
}

proc ::wb::cfg::uiUpdateItemButtons {} {
  variable ui
  variable curMode
  variable curItemIndex

  if {![info exists ui(btnAdd)]} { return }

  # Always sync the global bar buttons first
  ::wb::cfg::uiUpdateGlobalButtons

  if {$curMode eq "flow"} {
    foreach key {btnRemove btnMoveUp btnEdit btnAdd} {
      if {[info exists ui($key)]} {
        pack forget $ui($key)
      }
    }
    return
  }

  if {[info exists ui(btnRemove)]} {
    pack $ui(btnRemove) -side right -padx 4
  }
  if {[info exists ui(btnMoveUp)]} {
    pack $ui(btnMoveUp) -side right -padx 4
    $ui(btnMoveUp) configure -state disabled
  }
  if {[info exists ui(btnEdit)]} {
    pack $ui(btnEdit) -side right -padx 4
  }
  if {[info exists ui(btnAdd)]} {
    pack $ui(btnAdd) -side right -padx 4
  }

  set cap [::wb::cfg::modeTitle $curMode]
  $ui(btnAdd)    configure -text "Add $cap..."    -state normal
  $ui(btnEdit)   configure -text "Edit $cap..."   -state disabled
  $ui(btnRemove) configure -text "Remove $cap"    -state disabled

  if {$curMode eq "task"} {
    set taskIdx [::wb::cfg::taskIndexByName $::wb::cfg::curTaskName]
    if {[info exists ui(btnEdit)]} {
      pack forget $ui(btnEdit)
    }
    $ui(btnRemove) configure -state normal
    if {$taskIdx > 0 && [info exists ui(btnMoveUp)]} {
      $ui(btnMoveUp) configure -state normal
    }
    return
  }

  if {$curItemIndex >= 0} {
    $ui(btnEdit)   configure -state normal
    $ui(btnRemove) configure -state normal

    if {$curItemIndex > 0 && [info exists ui(btnMoveUp)] && \
        ($curMode eq "parms" || $curMode eq "options")} {
      $ui(btnMoveUp) configure -state normal
    }
  }
}

proc ::wb::cfg::uiAddItem {} {
  variable curMode

  if {! [::wb::cfg::panelConfirmDiscard]} { return }

  if {$curMode eq "flow"} {
    ::wb::cfg::panelLoadFlow
    return
  }

  if {$curMode eq "task"} {
    ::wb::cfg::panelLoadTask add
    ::wb::cfg::uiUpdateItemButtons
    ::wb::cfg::validateTask
    return
  }

  if {$curMode eq "options"} {
    ::wb::cfg::openOptEditor
    return
  }

  if {$curMode eq "parms"} {
    ::wb::cfg::openAddParmWin
    return
  }

  if {$curMode eq "runprop"} {
    ::wb::cfg::openAddRunpropWin
    return
  }

  tk_messageBox -icon info -title "Not implemented" -message "Add for this mode is not implemented yet."
}


# -------------------------
# Add Parm (stage 1)
# -------------------------

# Center a toplevel window on the screen.
proc ::wb::cfg::centerWin {w {wDefault 1560} {hDefault 780}} {
  update idletasks
  set sw [winfo screenwidth $w]
  set sh [winfo screenheight $w]

  # Use the requested target size unless the live requested size is even larger.
  set ww $wDefault
  set wh $hDefault

  set reqW [winfo reqwidth $w]
  set reqH [winfo reqheight $w]
  if {$reqW > $ww} { set ww $reqW }
  if {$reqH > $wh} { set wh $reqH }

  # Never size the window bigger than the screen itself -- leaving a
  # margin for the taskbar/title bar. Without this, a dialog whose actual
  # content needs more room than expected (e.g. Windows DPI-scaled fonts
  # rendering taller than assumed) could end up taller than the screen,
  # permanently pushing bottom-packed content like a button bar off
  # screen -- not recoverable by manually dragging the window bigger,
  # since there's no more screen to grow into.
  set margin 60
  if {$ww > $sw - $margin} { set ww [expr {$sw - $margin}] }
  if {$wh > $sh - $margin} { set wh [expr {$sh - $margin}] }

  set x [expr {($sw - $ww) / 2}]
  set y [expr {($sh - $wh) / 2}]
  if {$x < 0} { set x 0 }
  if {$y < 0} { set y 0 }

  wm geometry $w "${ww}x${wh}+${x}+${y}"
}

# ---- tooltip (simple global tooltip window) ------------------
proc ::wb::cfg::tipShow {x y msg} {
  set tw ._wb_tip
  catch {destroy $tw}
  toplevel $tw -bd 1 -relief solid
  wm overrideredirect $tw 1
  label $tw.l -text $msg -justify left -anchor w -padx 6 -pady 4
  pack $tw.l
  wm geometry $tw +[expr {$x + 12}]+[expr {$y + 12}]
  raise $tw
}

proc ::wb::cfg::tipHide {} {
  catch {destroy ._wb_tip}
}

proc ::wb::cfg::tipAttach {w msg} {
  bind $w <Enter> [list ::wb::cfg::tipShow %X %Y $msg]
  bind $w <Leave> [list ::wb::cfg::tipHide]
}

proc ::wb::cfg::parmTipMotion {lb x y} {
  variable curTaskName
  if {$curTaskName eq ""} { ::wb::cfg::tipHide; return }

  # only show tooltip when parms mode is active
  if {![info exists ::wb::cfg::curMode] || $::wb::cfg::curMode ne "parms"} {
    ::wb::cfg::tipHide
    return
  }

  set idx [$lb nearest $y]
  if {$idx < 0} { ::wb::cfg::tipHide; return }

  set task [getTask $curTaskName]
  set raw  [::wb::cfg::getTaskFieldForMode $task "parms"]
  set val  [::wb::cfg::normTaskFieldForMode $raw "parms"]
  if {$idx >= [llength $val]} { ::wb::cfg::tipHide; return }

  set pd [lindex $val $idx]
  set hint ""
  catch { set hint [dict get $pd hint] }
  if {$hint eq ""} { ::wb::cfg::tipHide; return }

  set rx [winfo rootx $lb]
  set ry [winfo rooty $lb]
  ::wb::cfg::tipShow [expr {$rx + $x}] [expr {$ry + $y}] $hint
}

proc ::wb::cfg::enableParmLineTooltips {} {
  variable ui
  if {![info exists ui(itemsList)]} { return }
  set lb $ui(itemsList)
  bind $lb <Motion> [list ::wb::cfg::parmTipMotion %W %x %y]
  bind $lb <Leave>  [list ::wb::cfg::tipHide]
}

# ---------------------------------------------------------------------------
# parmExecPlaceholder  type
# ---------------------------------------------------------------------------
proc ::wb::cfg::parmExecPlaceholder {type} {
  switch -- $type {
    lit  { return "lit:<value>" }
    copy { return "copy:<glob-key>" }
    eval { return {eval:[glob <key>]} }
    tern { return "tern:<opt>?<val-true>:<val-false>" }
    default { return "" }
  }
}

# ---------------------------------------------------------------------------
# _parmTypeExamples  type
# Returns list of {header parmExec comment} triples.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_parmTypeExamples {type} {
  switch -- $type {
    lit {
      return {
        {"" "lit:fetch"                              "operation keyword"}
        {"" "lit:cit"                               "namespace / short constant"}
        {"" "lit:bmo"                               "bank identifier"}
        {"" "lit:excel"                             "mode string"}
        {"" "lit:d:/1/audit-dump"                   "fixed local path"}
        {"" "lit:d:/1/candidates"                   "fixed output folder"}
        {"" "lit:H:/data/cit-agm/besu-1513"         "fixed project folder"}
        {"" "lit:string to be loaded into value"    "arbitrary literal string"}
        {"Multi-value (slash-separated)"
             "lit:054.323.ofx/1054.331.ofx/4608.095.ofx"  "file pattern list"}
        {"" "lit:CND/CND/USD"                       "currency list"}
        {"" "lit:1054-323/1054-331/4608-095"        "account list"}
        {"" "lit:CIT General Account/CIT Book Account/CIT USD Account"  "name list"}
      }
    }
    copy {
      return {
        {"Plain glob"
             "copy:year"                   "current year glob"}
        {"" "copy:month"                   "current month glob"}
        {"" "copy:fin-year"                "financial year glob"}
        {"" "copy:gael-port"               "server port glob"}
        {"Hidden glob (prefix ~)"
             "copy:~prod-tok"              "production token (hidden)"}
        {"" "copy:~devp-tok"               "development token (hidden)"}
        {"" "copy:~credits-file"           "credentials file path (hidden)"}
      }
    }
    eval {
      return {
        {"[glob key] -- simple path"
             "eval:[glob curDir]/don-cache"                         "subdir of current flow dir"}
        {"" "eval:[glob curDir]/besu-wset"                          "named subdir"}
        {"" "eval:[glob ~gael-base]/restart.txt"                    "file under hidden glob path"}
        {"" "eval:[glob ~staticDir]/prod-fetch-aud-kinds.json"      "file under static dir glob"}
        {"[glob key] -- filename with year"
             "eval:[glob curDir]/aud-out/CITAudit[glob year].xlsx"         "year in filename"}
        {"" "eval:[glob curDir]/trans/chqs-[glob year].json"               "year in JSON filename"}
        {"" "eval:[glob curDir]/aud-src/open-bal-[glob year].xlsx"         "year in balance file"}
        {"" "eval:[glob curDir]/don-cache/gmail-fixes-[glob year].json"    "year in fixes file"}
        {"URL from glob"
             "eval:http://localhost:[glob gael-port]"               "local server URL"}
        {"" "eval:https://[glob ~gael-proj].appspot.com"            "production server URL"}
        {"[env-vbl VAR] -- environment variable"
             "eval:[env-vbl CIT_FIN_HOME]"                          "bare env var as path"}
        {"" "eval:[env-vbl CIT_FIN_HOME]/donor-hist/legacy-raw"     "subpath under env var"}
        {"" "eval:[env-vbl CIT_FIN_BESU]//besu/agm-prod-people"    "env var with subpath"}
        {"" "eval:[env-vbl GAEL_CORE]/inputs/skel"                  "env var subpath"}
        {"" "eval:[env-vbl CIT_FIN_BESU_V3]"                        "bare env var"}
        {"[opt-map] -- option-driven mapping"
             "eval:[opt-map what ~pod-spec-]"                       "glob-prefix map by option"}
        {"" "eval:[opt-map what ~wire-spec-]"                       "glob-prefix map by option"}
        {"" "eval:[opt-map server tern:prod?-prod-url:-devp-url]"   "ternary URL via opt-map"}
        {"" "eval:[opt-map server tern:prod?-prod-tok:-devp-tok]"   "ternary token via opt-map"}
      }
    }
    tern {
      return {
        {"Plain glob values"
             "tern:server?prod-server:devp-server"     "option selects between two glob keys"}
        {"Hidden glob values (prefix ~)"
             "tern:server?~prod-tok:~devp-tok"         "option selects production/dev token"}
        {"" "tern:server?~prod-url:~devp-url"          "URL switch on server option"}
      }
    }
    default { return {} }
  }
}

# ---------------------------------------------------------------------------
# openAddParmWin  ?editIndex?
# Dialog with type selector, fields, and scrollable examples panel.
# editIndex ""      -> Add (blank form)
# editIndex integer -> Edit (preload that parm; parm name locked, same
#                      convention as the Option editor's Label-locked-in-
#                      Edit behaviour)
# ---------------------------------------------------------------------------
proc ::wb::cfg::openAddParmWin {{editIndex ""}} {
  variable curTaskName

  if {$curTaskName eq ""} {
    tk_messageBox -icon warning -title "Add Parm" -message "No task selected."
    return
  }

  set isEdit 0
  set od {}
  if {$editIndex ne ""} {
    set task [getTask $curTaskName]
    if {[dict exists $task parms]} {
      set lst [dict get $task parms]
      if {$editIndex >= 0 && $editIndex < [llength $lst]} {
        set od [lindex $lst $editIndex]
        set isEdit 1
      }
    }
    if {!$isEdit} {
      tk_messageBox -icon info -title "Edit Parm" -message "Edit: no parm selected."
      return
    }
  }

  set w .cfgAddParm
  catch { destroy $w }
  toplevel $w
  wm protocol $w WM_DELETE_WINDOW [list destroy $w]
  wm resizable $w 1 1

  set ::wb::cfg::addParmDlg(isEdit)    $isEdit
  set ::wb::cfg::addParmDlg(editIndex) [expr {$isEdit ? $editIndex : -1}]
  set ::wb::cfg::addParmDlg(errMsg)    ""

  if {$isEdit} {
    wm title $w "Edit Parm -- $curTaskName"
    set ::wb::cfg::addParmDlg(parm)     [dict get $od parm]
    set ::wb::cfg::addParmDlg(parmExec) [dict get $od parmExec]
    set ::wb::cfg::addParmDlg(type)     [::wb::cfg::_parmTypeFromExec [dict get $od parmExec]]
    set ::wb::cfg::addParmDlg(hint)     [expr {[dict exists $od hint] ? [dict get $od hint] : ""}]
  } else {
    wm title $w "Add Parm -- $curTaskName"
    set ::wb::cfg::addParmDlg(type)     "lit"
    set ::wb::cfg::addParmDlg(parm)     ""
    set ::wb::cfg::addParmDlg(parmExec) [::wb::cfg::parmExecPlaceholder "lit"]
    set ::wb::cfg::addParmDlg(hint)     ""
  }

  # ---- Input fields ----
  frame $w.top -padx 14 -pady 10
  pack  $w.top -side top -fill x

  label $w.top.typeL -text "Type:" -anchor e
  ttk::combobox $w.top.typeC \
    -textvariable ::wb::cfg::addParmDlg(type) \
    -values {lit copy eval tern} \
    -state readonly -width 10
  grid $w.top.typeL -row 0 -column 0 -sticky e  -padx {0 8} -pady 5
  grid $w.top.typeC -row 0 -column 1 -sticky w  -pady 5

  label $w.top.typeDesc \
    -text [::wb::cfg::_parmTypeDesc $::wb::cfg::addParmDlg(type)] \
    -anchor w -foreground "#555555" -justify left -wraplength 540
  grid $w.top.typeDesc -row 1 -column 0 -columnspan 2 -sticky w -padx {0 8} -pady {0 5}

  label $w.top.parmL -text "parm:" -anchor e
  entry $w.top.parmE -textvariable ::wb::cfg::addParmDlg(parm) -width 48
  grid $w.top.parmL -row 2 -column 0 -sticky e  -padx {0 8} -pady 4
  grid $w.top.parmE -row 2 -column 1 -sticky we -pady 4
  if {$isEdit} {
    $w.top.parmE configure -state disabled
    ::wb::cfg::tipAttach $w.top.parmE "Name is locked once a parm exists -- remove and re-add to rename"
  } else {
    ::wb::cfg::tipAttach $w.top.parmE "Argument name -- becomes --<parm> on the command line"
  }

  label $w.top.execL -text "parmExec:" -anchor e
  entry $w.top.execE -textvariable ::wb::cfg::addParmDlg(parmExec) -width 64
  grid $w.top.execL -row 3 -column 0 -sticky e  -padx {0 8} -pady 4
  grid $w.top.execE -row 3 -column 1 -sticky we -pady 4
  ::wb::cfg::tipAttach $w.top.execE "Expression producing the parm value -- click an example below to paste"

  label $w.top.hintL -text "hint:" -anchor e
  entry $w.top.hintE -textvariable ::wb::cfg::addParmDlg(hint) -width 64
  grid $w.top.hintL -row 4 -column 0 -sticky e  -padx {0 8} -pady 4
  grid $w.top.hintE -row 4 -column 1 -sticky we -pady 4
  ::wb::cfg::tipAttach $w.top.hintE "Optional -- shown as tooltip in the parms list"

  label $w.top.err \
    -textvariable ::wb::cfg::addParmDlg(errMsg) \
    -foreground red -anchor w -justify left -wraplength 560
  grid $w.top.err -row 5 -column 0 -columnspan 2 -sticky w -pady {2 0}
  grid columnconfigure $w.top 1 -weight 1

  # ---- Separator + examples panel ----
  ttk::separator $w.sep -orient horizontal
  pack $w.sep -side top -fill x -padx 10 -pady {4 0}

  frame $w.exf -padx 10 -pady 4
  pack  $w.exf -side top -fill both -expand 1

  label $w.exf.hdr \
    -text "Examples -- click to paste into parmExec:" \
    -anchor w -font {TkDefaultFont 9 bold}
  pack $w.exf.hdr -anchor w -pady {0 2}

  canvas $w.exf.c -highlightthickness 0 -bd 0 -height 180
  ttk::scrollbar $w.exf.sy -orient vertical -command [list $w.exf.c yview]
  $w.exf.c configure -yscrollcommand [list $w.exf.sy set]
  frame $w.exf.c.f
  $w.exf.c create window 0 0 -anchor nw -window $w.exf.c.f -tags inner

  pack $w.exf.sy -side right -fill y
  pack $w.exf.c  -side left  -fill both -expand 1

  bind $w.exf.c <Configure> {
    %W itemconfigure inner -width [winfo width %W]
    %W configure -scrollregion [list 0 0 [winfo reqwidth %W.f] [winfo reqheight %W.f]]
  }
  bind $w.exf.c.f <Configure> {
    set _c [winfo parent %W]
    $_c configure -scrollregion [list 0 0 [winfo reqwidth %W] [winfo reqheight %W]]
  }

  ::wb::cfg::_addParmBuildExamples $w $::wb::cfg::addParmDlg(type)

  # ---- Buttons ----
  ttk::separator $w.sep2 -orient horizontal
  pack $w.sep2 -side bottom -fill x -padx 10 -pady {0 4}
  frame $w.btns -padx 14 -pady 8
  pack  $w.btns -side bottom -fill x
  ttk::button $w.btns.cancel -style WbRounded.TButton -text "Cancel" \
    -command [list destroy $w]
  ttk::button $w.btns.add -style WbRounded.TButton \
    -text [expr {$isEdit ? "Save Parm" : "Add Parm"}] \
    -command [list ::wb::cfg::parmCommit $w]
  pack $w.btns.cancel -side left  -padx 4
  pack $w.btns.add    -side right -padx 4

  bind $w.top.typeC <<ComboboxSelected>> \
    [list ::wb::cfg::_addParmTypeChanged $w]
  bind $w.top.parmE <KeyRelease> [list ::wb::cfg::validateAddParmForm $w]
  bind $w.top.execE <KeyRelease> [list ::wb::cfg::validateAddParmForm $w]

  ::wb::cfg::validateAddParmForm $w

  update idletasks
  ::wb::cfg::centerWin $w 700 600
  if {$isEdit} {
    focus $w.top.execE
  } else {
    focus $w.top.parmE
  }
}

# ---------------------------------------------------------------------------
# _addParmBuildExamples  dlgWin  type
# Populates the scrollable examples frame for the given type.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_addParmBuildExamples {w type} {
  set f $w.exf.c.f
  foreach child [winfo children $f] { destroy $child }

  set examples [::wb::cfg::_parmTypeExamples $type]
  set row 0

  foreach ex $examples {
    lassign $ex header parmExec comment

    if {$header ne ""} {
      if {$row > 0} {
        frame $f.sp$row -height 4
        grid  $f.sp$row -row $row -column 0 -columnspan 2 -sticky w
        incr row
      }
      label $f.hdr$row \
        -text $header \
        -anchor w -font {TkDefaultFont 8 bold} -foreground "#666666"
      grid $f.hdr$row -row $row -column 0 -columnspan 2 -sticky w \
        -padx {6 0} -pady {4 1}
      incr row
    }

    label $f.ex$row \
      -text $parmExec \
      -anchor w -font {TkFixedFont 9} \
      -foreground "#1a5fb4" -cursor hand2 \
      -padx 6 -pady 2
    label $f.cm$row \
      -text "-- $comment" \
      -anchor w -font {TkDefaultFont 9} \
      -foreground "#444444"

    bind $f.ex$row <Enter>    [list $f.ex$row configure -background "#e8f0fe"]
    bind $f.ex$row <Leave>    [list $f.ex$row configure -background [. cget -background]]
    bind $f.ex$row <Button-1> [list ::wb::cfg::_addParmPasteExample $w $parmExec $comment]

    grid $f.ex$row -row $row -column 0 -sticky w -padx {12 4}
    grid $f.cm$row -row $row -column 1 -sticky w -padx {0 8}
    incr row
  }

  grid columnconfigure $f 0 -weight 0
  grid columnconfigure $f 1 -weight 1

  update idletasks
  set c $w.exf.c
  if {[winfo exists $c]} {
    $c configure -scrollregion \
      [list 0 0 [winfo reqwidth $f] [winfo reqheight $f]]
  }
}

# ---------------------------------------------------------------------------
# _addParmPasteExample  dlgWin  parmExec  ?comment?
#
# comment is the example's short description (e.g. "current year glob") --
# it doubles as the hint text, since the examples table has never carried
# a separate hint field. Both parmExec and hint are always set (or
# cleared, if comment is blank) so a later example click doesn't leave an
# earlier click's hint sitting stale in the field.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_addParmPasteExample {w parmExec {comment ""}} {
  set ::wb::cfg::addParmDlg(parmExec) $parmExec
  set ::wb::cfg::addParmDlg(hint)     $comment
  if {[winfo exists $w.top.execE]} {
    focus $w.top.execE
    $w.top.execE icursor end
  }
  ::wb::cfg::validateAddParmForm $w
}

# ---------------------------------------------------------------------------
# _parmTypeDesc  type
# ---------------------------------------------------------------------------
proc ::wb::cfg::_parmTypeDesc {type} {
  switch -- $type {
    lit  { return "lit -- passes a fixed literal string verbatim (no glob resolution)" }
    copy { return "copy -- copies a named glob value; prefix key with ~ for hidden globs" }
    eval { return "eval -- evaluates a string with \[glob key\] and \[env-vbl VAR\] interpolation" }
    tern { return "tern -- conditional: passes one of two glob values based on an option checkbox" }
    default { return "" }
  }
}

# ---------------------------------------------------------------------------
# _addParmTypeChanged  dlgWin
# ---------------------------------------------------------------------------
proc ::wb::cfg::_addParmTypeChanged {w} {
  set type $::wb::cfg::addParmDlg(type)
  set ::wb::cfg::addParmDlg(parmExec) [::wb::cfg::parmExecPlaceholder $type]
  if {[winfo exists $w.top.typeDesc]} {
    $w.top.typeDesc configure -text [::wb::cfg::_parmTypeDesc $type]
  }
  ::wb::cfg::_addParmBuildExamples $w $type
  if {[winfo exists $w.top.execE]} {
    focus $w.top.execE
    $w.top.execE selection range 0 end
  }
  ::wb::cfg::validateAddParmForm $w
}

# ---------------------------------------------------------------------------
# _parmTypeFromExec  parmExec
#
# parms have no separate stored "type" field -- the type is just the
# prefix on parmExec (lit:/copy:/eval:/tern:). Used to preselect the Type
# combobox and the right example set when editing an existing parm.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_parmTypeFromExec {parmExec} {
  set idx [string first ":" $parmExec]
  if {$idx < 0} { return "lit" }
  set prefix [string range $parmExec 0 [expr {$idx - 1}]]
  if {$prefix in {lit copy eval tern}} { return $prefix }
  return "lit"
}

# ---------------------------------------------------------------------------
# _taskParmNameExists  taskName  parm  ?excludeIndex?
# excludeIndex skips that position in the parms list -- used in Edit mode
# so a parm doesn't collide with itself.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_taskParmNameExists {taskName parm {excludeIndex -1}} {
  set task [::wb::cfg::getTask $taskName]
  if {$task eq ""} { return 0 }
  if {![dict exists $task parms]} { return 0 }
  set idx 0
  foreach p [dict get $task parms] {
    if {$idx != $excludeIndex && [dict exists $p parm] && [dict get $p parm] eq $parm} {
      return 1
    }
    incr idx
  }
  return 0
}

# ---------------------------------------------------------------------------
# validateAddParmForm  dlgWin
#
# Live validation, run on every keystroke in parm/parmExec plus whenever
# type changes or an example is pasted: empty name, an invalid character
# in the name, duplicate name (against this task's existing parms, self
# excluded in Edit mode since the name field is locked there), and an
# unfilled parmExec (still showing the type's placeholder) all set an
# inline error and disable the Add/Save Parm button, the same way a
# missing/duplicate task name already gates Save elsewhere in the app.
# ---------------------------------------------------------------------------
proc ::wb::cfg::validateAddParmForm {w} {
  variable curTaskName

  set parm     [string trim $::wb::cfg::addParmDlg(parm)]
  set parmExec [string trim $::wb::cfg::addParmDlg(parmExec)]
  set type     $::wb::cfg::addParmDlg(type)
  set editIdx  -1
  if {[info exists ::wb::cfg::addParmDlg(editIndex)]} {
    set editIdx $::wb::cfg::addParmDlg(editIndex)
  }

  set err ""
  if {$parm eq ""} {
    set err "parm name is required."
  } elseif {![regexp {^[A-Za-z0-9_-]+$} $parm]} {
    set err "parm name may only contain letters, digits, underscore, and hyphen -- no spaces or other characters."
  } elseif {[::wb::cfg::_taskParmNameExists $curTaskName $parm $editIdx]} {
    set err "A parm named '$parm' already exists on this task."
  } elseif {$parmExec eq "" || $parmExec eq [::wb::cfg::parmExecPlaceholder $type]} {
    set err "parmExec must be filled in (replace the placeholder)."
  }

  set ::wb::cfg::addParmDlg(errMsg) $err

  if {[winfo exists $w.btns.add]} {
    $w.btns.add configure -state [expr {$err eq "" ? "normal" : "disabled"}]
  }
  return [expr {$err eq ""}]
}

# ---------------------------------------------------------------------------
# parmCommit  dlgWin
# Dispatcher bound to the dialog's Add/Save button -- routes to the Add or
# Edit committer based on addParmDlg(isEdit), same pattern commitOptSave
# uses for the Option editor.
# ---------------------------------------------------------------------------
proc ::wb::cfg::parmCommit {w} {
  if {[info exists ::wb::cfg::addParmDlg(isEdit)] && $::wb::cfg::addParmDlg(isEdit)} {
    ::wb::cfg::editParmCommit $w $::wb::cfg::addParmDlg(editIndex)
  } else {
    ::wb::cfg::addParmCommit $w
  }
}

# ---------------------------------------------------------------------------
# addParmCommit  dlgWin
# ---------------------------------------------------------------------------
proc ::wb::cfg::addParmCommit {w} {
  variable curTaskName

  if {![::wb::cfg::validateAddParmForm $w]} { bell; return }

  set parm     [string trim $::wb::cfg::addParmDlg(parm)]
  set parmExec [string trim $::wb::cfg::addParmDlg(parmExec)]
  set hint     [string trim $::wb::cfg::addParmDlg(hint)]

  set newParm [dict create parm $parm parmExec $parmExec]
  if {$hint ne ""} { dict set newParm hint $hint }

  set task [::wb::cfg::getTask $curTaskName]
  if {$task eq ""} {
    set ::wb::cfg::addParmDlg(errMsg) "Current task not found."
    return
  }
  set parms [expr {[dict exists $task parms] ? [dict get $task parms] : {}}]
  lappend parms $newParm
  dict set task parms $parms
  ::wb::cfg::setTask $curTaskName $task

  ::wb::cfg::uiLoadItems
  ::wb::cfg::uiUpdateItemButtons
  ::wb::cfg::itemPanelSetDirty
  ::wb::cfg::validateParms

  log "addParmCommit: added parm='$parm' parmExec='$parmExec' to task '$curTaskName'"
  destroy $w
}

# ---------------------------------------------------------------------------
# editParmCommit  dlgWin  editIndex
# ---------------------------------------------------------------------------
proc ::wb::cfg::editParmCommit {w editIndex} {
  variable curTaskName

  if {![::wb::cfg::validateAddParmForm $w]} { bell; return }

  set parm     [string trim $::wb::cfg::addParmDlg(parm)]
  set parmExec [string trim $::wb::cfg::addParmDlg(parmExec)]
  set hint     [string trim $::wb::cfg::addParmDlg(hint)]

  set newParm [dict create parm $parm parmExec $parmExec]
  if {$hint ne ""} { dict set newParm hint $hint }

  set task [::wb::cfg::getTask $curTaskName]
  if {$task eq ""} {
    set ::wb::cfg::addParmDlg(errMsg) "Current task not found."
    return
  }
  set parms [expr {[dict exists $task parms] ? [dict get $task parms] : {}}]
  if {$editIndex < 0 || $editIndex >= [llength $parms]} {
    set ::wb::cfg::addParmDlg(errMsg) "Parm no longer exists at that position."
    return
  }
  set parms [lreplace $parms $editIndex $editIndex $newParm]
  dict set task parms $parms
  ::wb::cfg::setTask $curTaskName $task

  ::wb::cfg::uiLoadItems
  ::wb::cfg::uiUpdateItemButtons
  ::wb::cfg::itemPanelSetDirty
  ::wb::cfg::validateParms

  log "editParmCommit: updated parm='$parm' (index $editIndex) on task '$curTaskName'"
  destroy $w
}

# ---------------------------------------------------------------------------
# _runpropExamples
#
# Real key/value patterns mined from the sample flows (cit-agm, cit-aud,
# cit-fin, cit-web, run-gael, wb-devp), grouped by key and reduced to the
# unique patterns actually in use -- not every occurrence (e.g. dozens of
# distinct javaMain class names collapse to a few representative
# namespace examples, since the class name itself is task-specific and
# not something to enumerate exhaustively).
#   javaMain  -- fully-qualified Java class to invoke (every java-type
#                task needs this)
#   cpTag     -- classpath tag selecting which jar set to use
#   procExit  -- post-process hook trigger
#   manageApp -- companion Tcl script launched after this task
# Returns a list of {header fieldsDict comment} tuples, same shape as
# _parmTypeExamples/_optTypeExamples so _addRunpropBuildExamples can reuse
# that same rendering pattern.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_runpropExamples {} {
  return {
    {"javaMain -- fully-qualified class to invoke"
         {key javaMain value org.gaelic.becu.GaelBecuClient}
         "gaelic namespace example"}
    {"" {key javaMain value org.citc.batch.fin.CitcFetchPeople}
         "citc namespace example"}
    {"" {key javaMain value org.srp.psec.TestArgsPsec}
         "srp namespace example"}
    {"cpTag -- classpath tag selecting which jar set to use"
         {key cpTag value basic}
         "standard classpath -- most tasks use this"}
    {"" {key cpTag value gael-util}
         "gaelic utility classpath"}
    {"" {key cpTag value srp-util}
         "srp utility classpath"}
    {"procExit -- post-process hook trigger"
         {key procExit value post}
         "run the hook after the process exits"}
    {"manageApp -- companion Tcl script launched after this task"
         {key manageApp value manage-audit-excel.tcl}
         "opens a generated Excel workbook"}
    {"" {key manageApp value start-excel.tcl}
         "launches Excel directly"}
  }
}

# ---------------------------------------------------------------------------
# _addRunpropBuildExamples  dlgWin
# Populates the scrollable examples frame. No type dimension here (unlike
# opts/parms) -- runprops examples are one flat list grouped by key.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_addRunpropBuildExamples {w {filterKey ""}} {
  set f $w.exf.c.f
  foreach child [winfo children $f] { destroy $child }

  set examples [::wb::cfg::_runpropExamples]
  set row 0

  foreach ex $examples {
    lassign $ex header fields comment

    if {$filterKey ne "" && [dict get $fields key] ne $filterKey} { continue }

    if {$header ne ""} {
      if {$row > 0} {
        frame $f.sp$row -height 4
        grid  $f.sp$row -row $row -column 0 -columnspan 2 -sticky w
        incr row
      }
      label $f.hdr$row \
        -text $header \
        -anchor w -font {TkDefaultFont 8 bold} -foreground "#666666"
      grid $f.hdr$row -row $row -column 0 -columnspan 2 -sticky w \
        -padx {6 0} -pady {4 1}
      incr row
    }

    set disp "[dict get $fields key] = [dict get $fields value]"

    label $f.ex$row \
      -text $disp \
      -anchor w -font {TkFixedFont 9} \
      -foreground "#1a5fb4" -cursor hand2 \
      -padx 6 -pady 2
    label $f.cm$row \
      -text "-- $comment" \
      -anchor w -font {TkDefaultFont 9} \
      -foreground "#444444"

    bind $f.ex$row <Enter>    [list $f.ex$row configure -background "#e8f0fe"]
    bind $f.ex$row <Leave>    [list $f.ex$row configure -background [. cget -background]]
    bind $f.ex$row <Button-1> [list ::wb::cfg::_addRunpropPasteExample $w $fields]

    grid $f.ex$row -row $row -column 0 -sticky w -padx {12 4}
    grid $f.cm$row -row $row -column 1 -sticky w -padx {0 8}
    incr row
  }

  if {$row == 0} {
    label $f.none -anchor w -foreground "#888888" -font {TkDefaultFont 9 italic} \
      -text "(no examples for key '$filterKey')"
    grid  $f.none -row 0 -column 0 -columnspan 2 -sticky w -padx {6 4} -pady 4
  }

  grid columnconfigure $f 0 -weight 0
  grid columnconfigure $f 1 -weight 1

  update idletasks
  set c $w.exf.c
  if {[winfo exists $c]} {
    $c configure -scrollregion \
      [list 0 0 [winfo reqwidth $f] [winfo reqheight $f]]
  }
}

# ---------------------------------------------------------------------------
# _addRunpropPasteExample  dlgWin  fields
# fields is {key ... value ...}. In Edit mode the key field is locked, so
# only value gets pasted there (same rule as parm name / option label).
# ---------------------------------------------------------------------------
proc ::wb::cfg::_addRunpropPasteExample {w fields} {
  variable runpropDlg

  if {![info exists runpropDlg(isEdit)] || !$runpropDlg(isEdit)} {
    set ::wb::cfg::runpropDlg(key) [dict get $fields key]
  }
  set ::wb::cfg::runpropDlg(value) [dict get $fields value]

  if {[winfo exists $w.top.valueE]} {
    focus $w.top.valueE
    $w.top.valueE icursor end
  }
  ::wb::cfg::validateRunpropForm $w
}

# ---------------------------------------------------------------------------
# _taskRunpropKeyExists  taskName  key  ?excludeIndex?
# ---------------------------------------------------------------------------
proc ::wb::cfg::_taskRunpropKeyExists {taskName key {excludeIndex -1}} {
  set task [::wb::cfg::getTask $taskName]
  if {$task eq ""} { return 0 }
  if {![dict exists $task runprops]} { return 0 }
  set idx 0
  foreach k [dict keys [dict get $task runprops]] {
    if {$idx != $excludeIndex && $k eq $key} { return 1 }
    incr idx
  }
  return 0
}

# ---------------------------------------------------------------------------
# validateRunpropForm  dlgWin
# Same validation shape as validateAddParmForm: empty key, invalid
# characters in key, duplicate key (self excluded in Edit mode), empty
# value -- any of these disables the Add/Save button with an inline
# message.
# ---------------------------------------------------------------------------
proc ::wb::cfg::validateRunpropForm {w} {
  variable curTaskName

  set key   [string trim $::wb::cfg::runpropDlg(key)]
  set value [string trim $::wb::cfg::runpropDlg(value)]
  set editIdx -1
  if {[info exists ::wb::cfg::runpropDlg(editIndex)]} {
    set editIdx $::wb::cfg::runpropDlg(editIndex)
  }

  set err ""
  if {$key eq ""} {
    set err "key is required."
  } elseif {![regexp {^[A-Za-z0-9_-]+$} $key]} {
    set err "key may only contain letters, digits, underscore, and hyphen -- no spaces or other characters."
  } elseif {[::wb::cfg::_taskRunpropKeyExists $curTaskName $key $editIdx]} {
    set err "A runprop key named '$key' already exists on this task."
  } elseif {$value eq ""} {
    set err "value is required."
  }

  set ::wb::cfg::runpropDlg(errMsg) $err

  if {[winfo exists $w.btns.add]} {
    $w.btns.add configure -state [expr {$err eq "" ? "normal" : "disabled"}]
  }
  return [expr {$err eq ""}]
}

# ---------------------------------------------------------------------------
# runpropCommit  dlgWin
# Dispatcher, mirrors parmCommit/commitOptSave.
# ---------------------------------------------------------------------------
proc ::wb::cfg::runpropCommit {w} {
  if {[info exists ::wb::cfg::runpropDlg(isEdit)] && $::wb::cfg::runpropDlg(isEdit)} {
    ::wb::cfg::editRunpropCommit $w $::wb::cfg::runpropDlg(editIndex)
  } else {
    ::wb::cfg::addRunpropCommit $w
  }
}

# ---------------------------------------------------------------------------
# addRunpropCommit  dlgWin
# ---------------------------------------------------------------------------
proc ::wb::cfg::addRunpropCommit {w} {
  variable curTaskName

  if {![::wb::cfg::validateRunpropForm $w]} { bell; return }

  set key   [string trim $::wb::cfg::runpropDlg(key)]
  set value [string trim $::wb::cfg::runpropDlg(value)]

  set task [::wb::cfg::getTask $curTaskName]
  if {$task eq ""} {
    set ::wb::cfg::runpropDlg(errMsg) "Current task not found."
    return
  }
  set runprops [expr {[dict exists $task runprops] ? [dict get $task runprops] : [dict create]}]
  dict set runprops $key $value
  dict set task runprops $runprops
  ::wb::cfg::setTask $curTaskName $task

  ::wb::cfg::uiLoadItems
  ::wb::cfg::uiUpdateItemButtons
  ::wb::cfg::itemPanelSetDirty
  ::wb::cfg::validateRunprops

  log "addRunpropCommit: added runprop '$key'='$value' to task '$curTaskName'"
  destroy $w
}

# ---------------------------------------------------------------------------
# editRunpropCommit  dlgWin  editIndex
# ---------------------------------------------------------------------------
proc ::wb::cfg::editRunpropCommit {w editIndex} {
  variable curTaskName

  if {![::wb::cfg::validateRunpropForm $w]} { bell; return }

  set key   [string trim $::wb::cfg::runpropDlg(key)]
  set value [string trim $::wb::cfg::runpropDlg(value)]

  set task [::wb::cfg::getTask $curTaskName]
  if {$task eq ""} {
    set ::wb::cfg::runpropDlg(errMsg) "Current task not found."
    return
  }
  set runprops [expr {[dict exists $task runprops] ? [dict get $task runprops] : [dict create]}]
  set keys [dict keys $runprops]
  if {$editIndex < 0 || $editIndex >= [llength $keys]} {
    set ::wb::cfg::runpropDlg(errMsg) "Runprop no longer exists at that position."
    return
  }
  # Rebuild in place so the key's position doesn't move even though the
  # key itself is locked (value-only edit) -- dict set on an existing key
  # already preserves order, this just makes that explicit.
  dict set runprops $key $value
  dict set task runprops $runprops
  ::wb::cfg::setTask $curTaskName $task

  ::wb::cfg::uiLoadItems
  ::wb::cfg::uiUpdateItemButtons
  ::wb::cfg::itemPanelSetDirty
  ::wb::cfg::validateRunprops

  log "editRunpropCommit: updated runprop '$key'='$value' (index $editIndex) on task '$curTaskName'"
  destroy $w
}

# ---------------------------------------------------------------------------
# openAddRunpropWin  ?editIndex?
# Dialog with key/value fields and a scrollable examples panel -- same
# shape as openAddParmWin. editIndex ""      -> Add (blank form)
#                           editIndex integer -> Edit (preload that
#                           runprop; key locked, same convention as parm
#                           name / option label in Edit mode)
# ---------------------------------------------------------------------------
proc ::wb::cfg::openAddRunpropWin {{editIndex ""}} {
  variable curTaskName

  if {$curTaskName eq ""} {
    tk_messageBox -icon warning -title "Add Runprop" -message "No task selected."
    return
  }

  set isEdit 0
  set curKey ""
  set curVal ""
  if {$editIndex ne ""} {
    set task [getTask $curTaskName]
    if {[dict exists $task runprops]} {
      set keys [dict keys [dict get $task runprops]]
      if {$editIndex >= 0 && $editIndex < [llength $keys]} {
        set curKey [lindex $keys $editIndex]
        set curVal [dict get [dict get $task runprops] $curKey]
        set isEdit 1
      }
    }
    if {!$isEdit} {
      tk_messageBox -icon info -title "Edit Runprop" -message "Edit: no runprop selected."
      return
    }
  }

  set w .cfgAddRunprop
  catch { destroy $w }
  toplevel $w
  wm protocol $w WM_DELETE_WINDOW [list destroy $w]
  wm resizable $w 1 1

  set ::wb::cfg::runpropDlg(isEdit)    $isEdit
  set ::wb::cfg::runpropDlg(editIndex) [expr {$isEdit ? $editIndex : -1}]
  set ::wb::cfg::runpropDlg(errMsg)    ""

  if {$isEdit} {
    wm title $w "Edit Runprop -- $curTaskName"
    set ::wb::cfg::runpropDlg(key)   $curKey
    set ::wb::cfg::runpropDlg(value) $curVal
  } else {
    wm title $w "Add Runprop -- $curTaskName"
    set ::wb::cfg::runpropDlg(key)   ""
    set ::wb::cfg::runpropDlg(value) ""
  }

  # ---- Input fields ----
  frame $w.top -padx 14 -pady 10
  pack  $w.top -side top -fill x

  label $w.top.keyL -text "key:" -anchor e
  entry $w.top.keyE -textvariable ::wb::cfg::runpropDlg(key) -width 48
  grid $w.top.keyL -row 0 -column 0 -sticky e  -padx {0 8} -pady 4
  grid $w.top.keyE -row 0 -column 1 -sticky we -pady 4
  if {$isEdit} {
    $w.top.keyE configure -state disabled
    ::wb::cfg::tipAttach $w.top.keyE "Key is locked once a runprop exists -- remove and re-add to rename"
  } else {
    ::wb::cfg::tipAttach $w.top.keyE "Runtime property name, e.g. javaMain, cpTag"
  }

  label $w.top.valueL -text "value:" -anchor e
  entry $w.top.valueE -textvariable ::wb::cfg::runpropDlg(value) -width 64
  grid $w.top.valueL -row 1 -column 0 -sticky e  -padx {0 8} -pady 4
  grid $w.top.valueE -row 1 -column 1 -sticky we -pady 4
  ::wb::cfg::tipAttach $w.top.valueE "Value for this runprop entry -- click an example below to paste"

  label $w.top.err \
    -textvariable ::wb::cfg::runpropDlg(errMsg) \
    -foreground red -anchor w -justify left -wraplength 560
  grid $w.top.err -row 2 -column 0 -columnspan 2 -sticky w -pady {2 0}
  grid columnconfigure $w.top 1 -weight 1

  # ---- Separator + examples panel ----
  ttk::separator $w.sep -orient horizontal
  pack $w.sep -side top -fill x -padx 10 -pady {4 0}

  frame $w.exf -padx 10 -pady 4
  pack  $w.exf -side top -fill both -expand 1

  label $w.exf.hdr \
    -text [expr {$isEdit \
      ? "Examples for '$curKey' -- click to paste a value:" \
      : "Examples -- click to paste into key/value:"}] \
    -anchor w -font {TkDefaultFont 9 bold}
  pack $w.exf.hdr -anchor w -pady {0 2}

  canvas $w.exf.c -highlightthickness 0 -bd 0 -height 180
  ttk::scrollbar $w.exf.sy -orient vertical -command [list $w.exf.c yview]
  $w.exf.c configure -yscrollcommand [list $w.exf.sy set]
  frame $w.exf.c.f
  $w.exf.c create window 0 0 -anchor nw -window $w.exf.c.f -tags inner

  pack $w.exf.sy -side right -fill y
  pack $w.exf.c  -side left  -fill both -expand 1

  bind $w.exf.c <Configure> {
    %W itemconfigure inner -width [winfo width %W]
    %W configure -scrollregion [list 0 0 [winfo reqwidth %W.f] [winfo reqheight %W.f]]
  }
  bind $w.exf.c.f <Configure> {
    set _c [winfo parent %W]
    $_c configure -scrollregion [list 0 0 [winfo reqwidth %W] [winfo reqheight %W]]
  }

  if {$isEdit} {
    ::wb::cfg::_addRunpropBuildExamples $w $curKey
  } else {
    ::wb::cfg::_addRunpropBuildExamples $w
  }

  # ---- Buttons ----
  ttk::separator $w.sep2 -orient horizontal
  pack $w.sep2 -side bottom -fill x -padx 10 -pady {0 4}
  frame $w.btns -padx 14 -pady 8
  pack  $w.btns -side bottom -fill x
  ttk::button $w.btns.cancel -style WbRounded.TButton -text "Cancel" \
    -command [list destroy $w]
  ttk::button $w.btns.add -style WbRounded.TButton \
    -text [expr {$isEdit ? "Save Runprop" : "Add Runprop"}] \
    -command [list ::wb::cfg::runpropCommit $w]
  pack $w.btns.cancel -side left  -padx 4
  pack $w.btns.add    -side right -padx 4

  bind $w.top.keyE   <KeyRelease> [list ::wb::cfg::validateRunpropForm $w]
  bind $w.top.valueE <KeyRelease> [list ::wb::cfg::validateRunpropForm $w]

  ::wb::cfg::validateRunpropForm $w

  update idletasks
  ::wb::cfg::centerWin $w 700 600
  if {$isEdit} {
    focus $w.top.valueE
  } else {
    focus $w.top.keyE
  }
}

proc ::wb::cfg::uiCloneItem {} {
  variable curMode
  variable curItemIndex
  variable curTaskName

  if {$curMode eq "task"} {
    ::wb::clone::openCloneTaskWindow
    return
  }

  set cap [::wb::cfg::modeTitle $curMode]
  log "Clone $cap not yet implemented for mode=$curMode"
}

# ---------------------------------------------------------------------------
# cloneListFlows  ?excludeFlow?
#
# Returns sorted list of flow names under flows.dir that have a cfg.json,
# excluding excludeFlow.
# ---------------------------------------------------------------------------
proc ::wb::cfg::cloneListFlows {{excludeFlow ""}} {
  if {[catch {::wb::lib::requireTclFlows} flowsDir]} { return {} }
  set flows {}
  foreach d [glob -nocomplain -directory $flowsDir -type d *] {
    set name [file tail $d]
    if {$name eq $excludeFlow} { continue }
    if {[file exists [file join $d "${name}-cfg.json"]]} {
      lappend flows $name
    }
  }
  return [lsort $flows]
}

# ---------------------------------------------------------------------------
# cloneTaskNamesFromFlow  flowName
#
# Loads the cfg.json for flowName and returns its list of task names.
# Returns {} on any error.
# ---------------------------------------------------------------------------
proc ::wb::cfg::cloneTaskNamesFromFlow {flowName} {
  if {[catch {::wb::lib::requireTclFlows} flowsDir]} { return {} }
  set cfgPath [file join $flowsDir $flowName "${flowName}-cfg.json"]
  if {![file exists $cfgPath]} { return {} }
  if {[catch {jsonFileAsDict $cfgPath} d]} { return {} }
  set names {}
  if {[dict exists $d tasks]} {
    foreach t [dict get $d tasks] {
      if {[dict exists $t name]} { lappend names [dict get $t name] }
    }
  }
  return $names
}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# cloneTaskFromSameFlow / cloneTaskFromOtherFlow -- REMOVED at v171.
# Both were dead code: left in place at v153 as "candidates for the
# fs-clone real clone-execution plumbing," but the actual implementation
# (::wb::clone::onCloneButtonClick in fs-clone.tcl) reimplements the
# insert/copy/rename logic inline instead of calling either one. Neither
# had any remaining caller. See v171 changelog entry above for details.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# cloneRenameTaskFile  tail  srcTask  newTask
#
# Returns the dest filename for a file being copied into a new task folder.
# Renames:
#   <srcTask>-help.md    -> <newTask>-help.md
#   <srcTask>-*.tcl      -> <newTask>-*.tcl  (preserves suffix)
# All other files copied verbatim.
# ---------------------------------------------------------------------------
proc ::wb::cfg::cloneRenameTaskFile {tail srcTask newTask} {
  if {$tail eq "${srcTask}-help.md"} {
    return "${newTask}-help.md"
  }
  if {[string match "${srcTask}-*.tcl" $tail]} {
    set suffix [string range $tail [string length "${srcTask}-"] end]
    return "${newTask}-${suffix}"
  }
  return $tail
}

# ---------------------------------------------------------------------------
# taskFolderConsistencyCheck
#
# Compares cfgDict's task list against the flow's tasks/ folder on disk.
# Returns dict: missing {task names with no folder}, orphaned {folder
# names on disk with no matching task}.
#
# A task that's the *target* of a pending rename (see pendingRenames) is
# checked under its current on-disk name, not its new in-memory name --
# otherwise every rename would show as "missing" the instant it's
# confirmed, even though that's expected until the next final Save
# actually moves the folder. Symmetrically, that current-name folder is
# treated as accounted-for rather than orphaned.
# ---------------------------------------------------------------------------
proc ::wb::cfg::taskFolderConsistencyCheck {} {
  variable pendingRenames

  set flow     [::wb::cfg::cfgBaseName]
  set flowsDir [::wb::lib::requireTclFlows]
  set tasksDir [file join $flowsDir $flow tasks]

  set names [::wb::cfg::taskNames]

  set diskNameFor [dict create]
  foreach pr $pendingRenames {
    lassign $pr o n
    dict set diskNameFor $n $o
  }

  set missing {}
  set accountedFor {}
  foreach n $names {
    set diskName $n
    if {[dict exists $diskNameFor $n]} { set diskName [dict get $diskNameFor $n] }
    lappend accountedFor $diskName
    if {![file isdirectory [file join $tasksDir $diskName]]} {
      lappend missing $n
    }
  }

  set orphaned {}
  if {[file isdirectory $tasksDir]} {
    foreach d [glob -nocomplain -directory $tasksDir -type d *] {
      set tail [file tail $d]
      if {[lsearch -exact $accountedFor $tail] < 0} { lappend orphaned $tail }
    }
  }

  return [dict create missing $missing orphaned $orphaned]
}

# ---------------------------------------------------------------------------
# applyPendingRenames
#
# Applies every queued {oldName newName} folder rename to disk: renames
# the task folder itself (single file rename -- atomic, unlike the
# copy-then-delete pattern used for cloning), then renames any
# <oldName>-help.md / <oldName>-*.tcl files inside it via
# cloneRenameTaskFile.
#
# Idempotent against a previously-partial attempt: if oldName's folder is
# already gone and newName's folder already exists, that entry is treated
# as already done rather than an error.
#
# Returns a list of error strings (empty = full success). On full
# success, pendingRenames is cleared; on partial failure, only the
# entries that succeeded are removed -- the rest stay queued for retry.
# Called only from saveCfg's final-save path, and only after the caller
# has already confirmed via taskFolderConsistencyCheck that nothing is
# missing (so this should normally just succeed).
# ---------------------------------------------------------------------------
proc ::wb::cfg::applyPendingRenames {} {
  variable pendingRenames
  if {[llength $pendingRenames] == 0} { return {} }

  set flow     [::wb::cfg::cfgBaseName]
  set flowsDir [::wb::lib::requireTclFlows]
  set tasksDir [file join $flowsDir $flow tasks]

  set errs {}
  set applied {}

  foreach pr $pendingRenames {
    lassign $pr oldName newName
    set srcDir  [file join $tasksDir $oldName]
    set destDir [file join $tasksDir $newName]

    if {![file isdirectory $srcDir]} {
      if {[file isdirectory $destDir]} {
        lappend applied $pr
        continue
      }
      lappend errs "$oldName -> $newName: source folder not found ($srcDir)"
      continue
    }
    if {[file exists $destDir]} {
      lappend errs "$oldName -> $newName: destination already exists ($destDir)"
      continue
    }
    if {[catch {file rename $srcDir $destDir} err]} {
      lappend errs "$oldName -> $newName: $err"
      continue
    }

    foreach f [glob -nocomplain -directory $destDir -type f *] {
      set tail     [file tail $f]
      set destTail [::wb::cfg::cloneRenameTaskFile $tail $oldName $newName]
      if {$destTail ne $tail} {
        if {[catch {file rename -force $f [file join $destDir $destTail]} err2]} {
          lappend errs "$oldName -> $newName: could not rename file $tail: $err2"
        }
      }
    }
    lappend applied $pr
  }

  if {[llength $errs] == 0} {
    set pendingRenames {}
  } else {
    set remaining {}
    foreach pr $pendingRenames {
      if {[lsearch -exact $applied $pr] < 0} { lappend remaining $pr }
    }
    set pendingRenames $remaining
  }
  return $errs
}

proc ::wb::cfg::uiEditItem {} {
  variable curMode
  variable curItemIndex
  variable ui

  log "uiEditItem: mode=$curMode curItemIndex=$curItemIndex"

  if {$curMode eq "flow"} {
    if {! [::wb::cfg::panelConfirmDiscard]} { return }
    ::wb::cfg::panelLoadFlow
    return
  }

  if {$curMode eq "task"} {
    # No Edit Task button in task mode: selecting a task in the list
    # already opens the edit form (panelLoadTask), so a separate Edit
    # button here would just re-enter the same panel. See
    # uiUpdateItemButtons, which hides the button for this mode.
    return
  }

  if {! [::wb::cfg::panelConfirmDiscard]} { return }

  if {$curMode eq "options"} {
    # v79: selection tracked via treeview in curItemIndex
    if {$curItemIndex < 0} {
      tk_messageBox -icon info -title "Edit Option" -message "Edit: no option selected."
      return
    }
    ::wb::cfg::openOptEditor $curItemIndex
    return
  }

  if {$curMode eq "parms"} {
    if {$curItemIndex < 0} {
      tk_messageBox -icon info -title "Edit Parm" -message "Edit: no parm selected."
      return
    }
    ::wb::cfg::openAddParmWin $curItemIndex
    return
  }

  if {$curMode eq "runprop"} {
    if {$curItemIndex < 0} {
      tk_messageBox -icon info -title "Edit Runprop" -message "Edit: no runprop selected."
      return
    }
    ::wb::cfg::openAddRunpropWin $curItemIndex
    return
  }

  tk_messageBox -icon info -title "Not implemented" -message "Edit for this mode is not implemented yet."
}

proc ::wb::cfg::uiRemoveItem {} {
  variable curTaskName
  variable curMode
  variable curItemIndex
  variable curItemKey

  if {$curMode eq "task"} { return }
  if {$curTaskName eq ""} { return }
  if {$curItemIndex < 0} { return }

  set task [getTask $curTaskName]
  set f   [::wb::cfg::fieldForMode $curMode]
  set raw [::wb::cfg::getTaskFieldForMode $task $curMode]
  set val [::wb::cfg::normTaskFieldForMode $raw $curMode]

  if {$curMode eq "options" || $curMode eq "parms"} {
    set new {}
    for {set i 0} {$i < [llength $val]} {incr i} {
      if {$i == $curItemIndex} { continue }
      lappend new [lindex $val $i]
    }
    if {[llength $new] == 0} {
      dict set task $f ""
    } else {
      dict set task $f $new
    }
  } else {
    if {$curItemKey ne "" && [dict exists $val $curItemKey]} {
      dict unset val $curItemKey
    }
    if {[dict size $val] == 0} {
      dict set task $f ""
    } else {
      dict set task $f $val
    }
  }

  setTask $curTaskName $task
  set curItemIndex -1
  set curItemKey ""
  ::wb::cfg::uiLoadItems
  ::wb::cfg::uiUpdateItemButtons
  ::wb::cfg::validateTask
}

# Move Up: swap selected item with previous row and refresh list.
# Handles options (opts) and parms modes; others ignored for now.
proc ::wb::cfg::uiMoveUpItem {} {
  variable curTaskName
  variable curMode
  variable curItemIndex

  if {$curMode eq "task"} { return }
  if {$curMode ne "parms" && $curMode ne "options"} { return }
  if {$curTaskName eq ""} { return }
  if {$curItemIndex <= 0} { return }

  set task [getTask $curTaskName]
  set raw  [::wb::cfg::getTaskFieldForMode $task $curMode]
  set val  [::wb::cfg::normTaskFieldForMode $raw $curMode]

  set i $curItemIndex
  set a [lindex $val [expr {$i-1}]]
  set b [lindex $val $i]
  set val [lreplace $val [expr {$i-1}] $i $b $a]

  set field [::wb::cfg::fieldForMode $curMode]
  dict set task $field $val
  setTask $curTaskName $task

  ::wb::cfg::uiLoadItems

  set ni [expr {$i-1}]

  if {$curMode eq "options"} {
    ::wb::cfg::optsGridSelectIndex $ni
  } else {
    if {[info exists ::wb::cfg::ui(itemsList)]} {
      set lb $::wb::cfg::ui(itemsList)
      $lb selection clear 0 end
      $lb selection set $ni
      $lb activate $ni
      $lb see $ni
    }
    set curItemIndex $ni
    ::wb::cfg::uiUpdateItemButtons
  }
  ::wb::cfg::validateTask
}

# -------------------------
# Task-level move and remove (v96)
# -------------------------

proc ::wb::cfg::uiRemoveTask {} {
  variable curTaskName
  variable cfgDict

  if {$curTaskName eq ""} { return }
  set idx [::wb::cfg::taskIndexByName $curTaskName]
  if {$idx < 0} { return }

  set ans [tk_messageBox -icon warning -type yesno -default no \
    -title "Remove Task" \
    -message "Remove task '$curTaskName'? This cannot be undone."]
  if {$ans ne "yes"} { return }

  set tasks [taskList]
  set tasks [lreplace $tasks $idx $idx]
  dict set cfgDict tasks $tasks
  ::wb::cfg::cfgMarkDirty
  set curTaskName ""
  ::wb::cfg::uiLoadTasks

  set sz [::wb::cfg::taskTvSize]
  if {$sz > 0} {
    ::wb::cfg::taskTvSelect [expr {min($idx, $sz-1)}]
    ::wb::cfg::uiSelectTask
  }
  ::wb::cfg::uiUpdateItemButtons
  ::wb::cfg::validateTask
}

proc ::wb::cfg::uiMoveUpTask {} {
  variable curTaskName
  variable cfgDict

  if {$curTaskName eq ""} { return }
  set idx [::wb::cfg::taskIndexByName $curTaskName]
  if {$idx <= 0} { return }

  set tasks [taskList]
  set a [lindex $tasks [expr {$idx-1}]]
  set b [lindex $tasks $idx]
  set tasks [lreplace $tasks [expr {$idx-1}] $idx $b $a]
  dict set cfgDict tasks $tasks
  ::wb::cfg::cfgMarkDirty
  ::wb::cfg::uiLoadTasks
  ::wb::cfg::taskTvSelect [expr {$idx-1}]
  ::wb::cfg::uiSelectTask
  ::wb::cfg::validateTask
}

# Dispatchers -- wired to toolbar buttons
proc ::wb::cfg::onRemove {} {
  if {$::wb::cfg::curMode eq "task"} {
    ::wb::cfg::uiRemoveTask
  } else {
    ::wb::cfg::uiRemoveItem
  }
}

proc ::wb::cfg::onMoveUp {} {
  if {$::wb::cfg::curMode eq "task"} {
    ::wb::cfg::uiMoveUpTask
  } else {
    ::wb::cfg::uiMoveUpItem
  }
}


proc ::wb::cfg::saveCfg {} {
  variable cfgPath
  variable cfgDict
  variable cfgIsDirty
  variable ui
  variable opts

  set dir  [file dirname $cfgPath]
  set base [file rootname [file tail $cfgPath]]

  # devp.enabled=false : always save to -cfg file (production mode)
  # devp.enabled=true  : save to -tmp unless Save Final checkbox is checked
  set isFinal [expr {![fsCfgGetBool devp.enabled] || $::wb::cfg::ui(saveFinal)}]

  if {$isFinal} {
    set savePath $cfgPath
  } else {
    set savePath [file join $dir "${base}-tmp.json"]
  }

  # Folder rename/orphan handling only applies to a real (final) save --
  # a scratch/tmp save during dev-mode iteration doesn't touch disk beyond
  # its own -tmp.json, same as always. (Missing-folder cases are already
  # covered: cfgSaveGate keeps the Save button disabled whenever any task
  # has no folder on disk, so we don't need to re-check that here too --
  # one place for that check, per cfgSaveGate.)
  if {$isFinal} {
    set fc [::wb::cfg::taskFolderConsistencyCheck]
    if {[llength [dict get $fc orphaned]] > 0} {
      set ans [tk_messageBox -icon warning -type yesno -default yes \
        -title "Save" \
        -message "These folders under tasks/ aren't referenced by any task in this flow:\n\n[join [dict get $fc orphaned] \n]\n\n(The runner ignores these the same way.) Save anyway?"]
      if {$ans ne "yes"} { return }
    }

    set renameErrs [::wb::cfg::applyPendingRenames]
    if {[llength $renameErrs] > 0} {
      tk_messageBox -icon error -title "Save" \
        -message "Cfg was NOT saved -- some pending task renames could not be applied on disk:\n\n[join $renameErrs \n]\n\nFix the issue and Save again; the rename(s) will retry."
      return
    }
  }

  log "Saving cfg to $savePath"
  dictAsJsonFile $savePath $cfgDict wb-cfg

  set cfgIsDirty 0
  if {[info exists ui(btnSave)] && [winfo exists $ui(btnSave)]} {
    $ui(btnSave) configure -state disabled
  }
}


proc ::wb::cfg::onClose {} {
  log "Exiting wb-cfg $::wb::cfg::VERSION"
  destroy .
  exit 0
}

# -------------------------
# Main window
# -------------------------
proc ::wb::cfg::openCfg {path} {
  variable cfgPath
  variable cfgDict
  variable ui

  wm withdraw .
  set cfgPath [file normalize $path]
  set cfgDict [jsonFileAsDict $cfgPath]

  set w .
  wm deiconify $w
  wm title $w "WB Configurator $::wb::cfg::VERSION - [file tail $cfgPath]"
  # Set window icon from [fsCfgGet home.dir]/icons/fs-icon-C.ico
  set iconPath [file join [fsCfgGet home.dir] "icons" "fs-icon-C.ico"]
  log "Setting icon $iconPath"
  if {[file exists $iconPath]} {
    if {[catch {
      wm iconbitmap $w $iconPath
    } err]} {
      log "set_icon failed: [lindex [split $err \n] 0]"
    }
  }
  wm geometry $w 1260x780 ;#ignored - see later
  wm protocol $w WM_DELETE_WINDOW ::wb::cfg::onClose
  update idletasks
  ::wb::cfg::centerWin $w 1560 780

  foreach c [winfo children $w] { destroy $c }

  ::wb::cfg::initButtonStyle

# ---- Global bar -- packed into top-level window first, spans full width ----
frame ${w}g
label ${w}g.l       -text "Global:"
ttk::button ${w}g.save -style WbRounded.TButton -text "Save" \
  -state disabled \
  -command {::wb::cfg::saveCfg}
checkbutton ${w}g.final -text "Save Final" \
  -variable ::wb::cfg::ui(saveFinal)
# Clone -- label tracks Cfg Mode, hidden in flow mode
ttk::button ${w}g.clone  -style WbRounded.TButton \
  -text "Clone Task..."  -command {::wb::cfg::uiCloneItem}
# Restart controls on the right
checkbutton ${w}g.restartOn -text "Enable Restart" \
  -variable ::wb::cfg::enableRestart \
  -command {::wb::cfg::updateRestartBtn}
ttk::button ${w}g.restartBtn -style WbRounded.TButton \
  -text "Restart" -state disabled -command {::wb::cfg::doRestart77}
# Help link to the right of Restart
ttk::label ${w}g.helpLnk -text "Help" -style Wb.Link.TLabel -cursor hand2
bind ${w}g.helpLnk <Button-1> {::wb::cfg::onHelpHelp}
bind ${w}g.helpLnk <Enter>   {.g.helpLnk configure -style Wb.LinkHover.TLabel}
bind ${w}g.helpLnk <Leave>   {.g.helpLnk configure -style Wb.Link.TLabel}

pack ${w}g.l          -side left  -padx 4
pack ${w}g.save       -side left  -padx 4
# Save Final checkbox only shown in devp mode
if {[fsCfgGetBool devp.enabled]} {
  pack ${w}g.final    -side left  -padx 10
}
pack ${w}g.clone      -side left  -padx 4
pack ${w}g.helpLnk    -side right -padx 6
pack ${w}g.restartBtn -side right -padx 4
pack ${w}g.restartOn  -side right -padx 4
pack ${w}g -fill x -padx 8 -pady {2 4}

# ---- dashed separator below global bar ------------------------------------
canvas ${w}gsep -height 2 -highlightthickness 0 -bd 0
${w}gsep create line 0 1 2000 1 -fill gray50
pack ${w}gsep -fill x -padx 8 -pady {0 4}

# ---- Main content: Tasks list (left) + right panel ------------------------
frame ${w}main
pack ${w}main -fill both -expand 1

  frame ${w}main.left
  label ${w}main.left.h -text "Tasks"
  listbox ${w}main.left.lb -height 22 -width 40 -exportselection 0 -activestyle none
  label ${w}main.left.saveErr \
    -textvariable ::wb::cfg::cfgSaveErrMsg \
    -foreground red -anchor w -justify left \
    -wraplength 280 -relief flat
  pack ${w}main.left    -side left -fill y -padx 6 -pady 6
  pack ${w}main.left.h  -anchor w
  pack ${w}main.left.lb -fill y
  pack ${w}main.left.saveErr -fill x -anchor w -pady {4 0}

  frame ${w}main.right
  pack ${w}main.right -side right -fill both -expand 1

# ---- Current task line ----------------------------------------------------
frame ${w}main.right.t
label ${w}main.right.t.l -text "Task:"
label ${w}main.right.t.v -text "" -font TkBoldFont
pack ${w}main.right.t.l -side left -padx {0 4}
pack ${w}main.right.t.v -side left
pack ${w}main.right.t -anchor w -padx 8 -pady {0 6}

# ---- Mode + item actions toolbar ------------------------------------------
frame ${w}main.right.h
label ${w}main.right.h.ml -text "Cfg Mode:"
ttk::combobox ${w}main.right.h.mode -state readonly -width 10 \
  -values {flow task options parms runprop} -textvariable ::wb::cfg::curMode
ttk::button ${w}main.right.h.add    -style WbRounded.TButton -text "Add"     -command {::wb::cfg::uiAddItem}
ttk::button ${w}main.right.h.edit   -style WbRounded.TButton -text "Edit"    -command {::wb::cfg::uiEditItem}   -state disabled
ttk::button ${w}main.right.h.remove -style WbRounded.TButton -text "Remove"  -command {::wb::cfg::onRemove} -state disabled
ttk::button ${w}main.right.h.up     -style WbRounded.TButton -text "Move Up" -command {::wb::cfg::onMoveUp} -state disabled

pack ${w}main.right.h.ml     -side left -padx 4
pack ${w}main.right.h.mode   -side left -padx 4
pack ${w}main.right.h.remove -side right -padx 4
pack ${w}main.right.h.up     -side right -padx 4
pack ${w}main.right.h.edit   -side right -padx 4
pack ${w}main.right.h.add    -side right -padx 4
pack ${w}main.right.h -fill x -padx 8 -pady {0 6}

bind ${w}main.right.h.mode <<ComboboxSelected>> {::wb::cfg::uiSetMode $::wb::cfg::curMode}


  # --- Items area: listbox for parms/runprop/hooks; treeview grid for options mode ---
  listbox ${w}main.right.opts -height 14 -width 150 -exportselection 0

  # Options grid (treeview) - shown only in options mode
  frame ${w}main.right.optsGrid
  ttk::treeview ${w}main.right.optsGrid.tv \
    -columns {label type parm place} \
    -show headings \
    -selectmode browse \
    -style WbOptsGrid.Treeview \
    -height 14
  ${w}main.right.optsGrid.tv heading label -text "Label"  -anchor w
  ${w}main.right.optsGrid.tv heading type  -text "Type"   -anchor w
  ${w}main.right.optsGrid.tv heading parm  -text "Parm"   -anchor w
  ${w}main.right.optsGrid.tv heading place -text "Place"  -anchor w
  ${w}main.right.optsGrid.tv column  label -width 120 -stretch 0
  ${w}main.right.optsGrid.tv column  type  -width 100 -stretch 0
  ${w}main.right.optsGrid.tv column  parm  -width 110 -stretch 0
  ${w}main.right.optsGrid.tv column  place -width 200 -stretch 1
  ttk::scrollbar ${w}main.right.optsGrid.sy -orient vertical \
    -command [list ${w}main.right.optsGrid.tv yview]
  ${w}main.right.optsGrid.tv configure \
    -yscrollcommand [list ${w}main.right.optsGrid.sy set]
  pack ${w}main.right.optsGrid.sy -side right -fill y
  pack ${w}main.right.optsGrid.tv -side left -fill both -expand 1

  # ---- Parms grid --------------------------------------------------------
  frame ${w}main.right.parmsGrid
  ttk::treeview ${w}main.right.parmsGrid.tv \
    -columns {parm type} \
    -show headings \
    -selectmode browse \
    -style WbParmsGrid.Treeview \
    -height 14
  ${w}main.right.parmsGrid.tv heading parm -text "Parm" -anchor w
  ${w}main.right.parmsGrid.tv heading type -text "Type" -anchor w
  ${w}main.right.parmsGrid.tv column  parm -width 180 -stretch 0
  ${w}main.right.parmsGrid.tv column  type -width  80 -stretch 1
  ttk::scrollbar ${w}main.right.parmsGrid.sy -orient vertical \
    -command [list ${w}main.right.parmsGrid.tv yview]
  ${w}main.right.parmsGrid.tv configure \
    -yscrollcommand [list ${w}main.right.parmsGrid.sy set]
  pack ${w}main.right.parmsGrid.sy -side right -fill y
  pack ${w}main.right.parmsGrid.tv -side left -fill both -expand 1

  # ---- Runprops grid -----------------------------------------------------
  frame ${w}main.right.runpropsGrid
  ttk::treeview ${w}main.right.runpropsGrid.tv \
    -columns {runprop text} \
    -show headings \
    -selectmode browse \
    -style WbRunGrid.Treeview \
    -height 14
  ${w}main.right.runpropsGrid.tv heading runprop -text "Runprop" -anchor w
  ${w}main.right.runpropsGrid.tv heading text    -text "Text"    -anchor w
  ${w}main.right.runpropsGrid.tv column  runprop -width 200 -stretch 0
  ${w}main.right.runpropsGrid.tv column  text    -width 400 -stretch 1
  ttk::scrollbar ${w}main.right.runpropsGrid.sy -orient vertical \
    -command [list ${w}main.right.runpropsGrid.tv yview]
  ${w}main.right.runpropsGrid.tv configure \
    -yscrollcommand [list ${w}main.right.runpropsGrid.sy set]
  pack ${w}main.right.runpropsGrid.sy -side right -fill y
  pack ${w}main.right.runpropsGrid.tv -side left -fill both -expand 1

  # ---- Item-level panel (options / parms / runprops) ----------------------
  # Constrained height -- sits below the grid/list, never expands to fill.
  frame ${w}main.right.itemPanel -bd 1 -relief groove -padx 4 -pady 4
  label ${w}main.right.itemPanel.err \
    -textvariable ::wb::cfg::itemErrMsg \
    -foreground red -anchor w -justify left \
    -wraplength 800 -height 2 -relief flat
  ttk::button ${w}main.right.itemPanel.apply \
    -style WbRounded.TButton \
    -text "Apply Option(s) Change" \
    -state disabled \
    -command {::wb::cfg::itemPanelApply}
  pack ${w}main.right.itemPanel.err   -fill x -anchor w
  pack ${w}main.right.itemPanel.apply -anchor e -pady {4 0}

  frame ${w}main.right.panel
  frame ${w}main.right.panel.body

  frame ${w}main.right.panel.flow
  label ${w}main.right.panel.flow.nameL  -text "Name:"
  entry ${w}main.right.panel.flow.nameE  -textvariable ::wb::cfg::panel(flowName) -state readonly -width 50
  label ${w}main.right.panel.flow.titleL -text "Title:"
  entry ${w}main.right.panel.flow.titleE -textvariable ::wb::cfg::panel(flowTitle) -width 70
  grid ${w}main.right.panel.flow.nameL  -row 0 -column 0 -sticky e  -padx {0 8} -pady 4
  grid ${w}main.right.panel.flow.nameE  -row 0 -column 1 -sticky we -pady 4
  grid ${w}main.right.panel.flow.titleL -row 1 -column 0 -sticky e  -padx {0 8} -pady 4
  grid ${w}main.right.panel.flow.titleE -row 1 -column 1 -sticky we -pady 4
  grid columnconfigure ${w}main.right.panel.flow 1 -weight 1

  frame ${w}main.right.panel.task
  label ${w}main.right.panel.task.nameL  -text "Name:"
  entry ${w}main.right.panel.task.nameE  -textvariable ::wb::cfg::panel(taskName) -width 50
  ttk::button ${w}main.right.panel.task.renameBtn -style WbRounded.TButton \
    -text "Rename..." -state disabled -command {::wb::cfg::uiRenameTask}
  label ${w}main.right.panel.task.titleL -text "Title:"
  entry ${w}main.right.panel.task.titleE -textvariable ::wb::cfg::panel(taskTitle) -width 70
  label ${w}main.right.panel.task.descL  -text "Desc:"
  entry ${w}main.right.panel.task.descE  -textvariable ::wb::cfg::panel(taskDesc) -width 70
  label ${w}main.right.panel.task.typeL  -text "Type:"
  ttk::combobox ${w}main.right.panel.task.typeC -state readonly -width 18     -values {tcl-int tcl-ext java manual} -textvariable ::wb::cfg::panel(taskType)
  label ${w}main.right.panel.task.depL   -text "DependsOn:"
  frame ${w}main.right.panel.task.depF -bd 1 -relief sunken
  canvas ${w}main.right.panel.task.depF.c -height 140 -highlightthickness 0 -bd 0
  ttk::scrollbar ${w}main.right.panel.task.depF.sy -orient vertical -command [list ${w}main.right.panel.task.depF.c yview]
  frame ${w}main.right.panel.task.depF.c.f
  ${w}main.right.panel.task.depF.c configure -yscrollcommand [list ${w}main.right.panel.task.depF.sy set]
  ${w}main.right.panel.task.depF.c create window 0 0 -anchor nw -window ${w}main.right.panel.task.depF.c.f -tags inner
  pack ${w}main.right.panel.task.depF.sy -side right -fill y
  pack ${w}main.right.panel.task.depF.c -side left -fill both -expand 1
  bind ${w}main.right.panel.task.depF.c <Configure> [list ::wb::cfg::panelChecklistOnConfigure ${w}main.right.panel.task.depF.c ${w}main.right.panel.task.depF.c.f]

  label ${w}main.right.panel.task.failL  -text "WhenFail:"
  frame ${w}main.right.panel.task.failF -bd 1 -relief sunken
  canvas ${w}main.right.panel.task.failF.c -height 140 -highlightthickness 0 -bd 0
  ttk::scrollbar ${w}main.right.panel.task.failF.sy -orient vertical -command [list ${w}main.right.panel.task.failF.c yview]
  frame ${w}main.right.panel.task.failF.c.f
  ${w}main.right.panel.task.failF.c configure -yscrollcommand [list ${w}main.right.panel.task.failF.sy set]
  ${w}main.right.panel.task.failF.c create window 0 0 -anchor nw -window ${w}main.right.panel.task.failF.c.f -tags inner
  pack ${w}main.right.panel.task.failF.sy -side right -fill y
  pack ${w}main.right.panel.task.failF.c -side left -fill both -expand 1
  bind ${w}main.right.panel.task.failF.c <Configure> [list ::wb::cfg::panelChecklistOnConfigure ${w}main.right.panel.task.failF.c ${w}main.right.panel.task.failF.c.f]

  # staleAfter -- only meaningful/shown on the first task in a flow (no
  # prior tasks to depend on / be depended on by), so it occupies the
  # same grid row DependsOn/WhenFail would otherwise use -- see
  # panelToggleStaleAfter, which shows this exactly when those are
  # hidden. Two fields per Steve's spec: a plain integer (0 = "not set,
  # don't save"), and a unit chosen from a fixed radio set that must
  # match what fs-run.tcl's _parseStaleAfterSeconds actually accepts.
  label ${w}main.right.panel.task.staleAfterL -text "Stale After:"
  frame ${w}main.right.panel.task.staleAfterF
  entry ${w}main.right.panel.task.staleAfterF.val -textvariable ::wb::cfg::panel(staleAfterVal) -width 8
  label ${w}main.right.panel.task.staleAfterF.hint -text "(0 = off)" -foreground #777777
  foreach {u ulabel} {secs Secs mins Mins hours Hours days Days weeks Weeks months Months years Years} {
    ttk::radiobutton ${w}main.right.panel.task.staleAfterF.u_$u -text $ulabel \
      -variable ::wb::cfg::panel(staleAfterUnit) -value $u
  }
  pack ${w}main.right.panel.task.staleAfterF.val -side left -padx {0 6}
  pack ${w}main.right.panel.task.staleAfterF.hint -side left -padx {0 14}
  foreach u {secs mins hours days weeks months years} {
    pack ${w}main.right.panel.task.staleAfterF.u_$u -side left -padx {0 8}
  }

  grid ${w}main.right.panel.task.nameL   -row 0 -column 0 -sticky ne -padx {0 8} -pady 4
  grid ${w}main.right.panel.task.nameE   -row 0 -column 1 -sticky we -pady 4
  grid ${w}main.right.panel.task.renameBtn -row 0 -column 2 -sticky w -padx {8 0} -pady 4
  grid ${w}main.right.panel.task.titleL  -row 1 -column 0 -sticky ne -padx {0 8} -pady 4
  grid ${w}main.right.panel.task.titleE  -row 1 -column 1 -sticky we -pady 4
  grid ${w}main.right.panel.task.descL   -row 2 -column 0 -sticky ne -padx {0 8} -pady 4
  grid ${w}main.right.panel.task.descE   -row 2 -column 1 -sticky we -pady 4
  grid ${w}main.right.panel.task.typeL   -row 3 -column 0 -sticky ne -padx {0 8} -pady 4
  grid ${w}main.right.panel.task.typeC   -row 3 -column 1 -sticky w  -pady 4
  grid ${w}main.right.panel.task.depL    -row 4 -column 0 -sticky ne -padx {0 8} -pady 4
  grid ${w}main.right.panel.task.depF    -row 4 -column 1 -sticky nsew -pady 4
  grid ${w}main.right.panel.task.staleAfterL -row 4 -column 0 -sticky ne -padx {0 8} -pady 4
  grid ${w}main.right.panel.task.staleAfterF -row 4 -column 1 -sticky nw -pady 4
  grid ${w}main.right.panel.task.failL   -row 5 -column 0 -sticky ne -padx {0 8} -pady 4
  grid ${w}main.right.panel.task.failF   -row 5 -column 1 -sticky nsew -pady 4
  grid columnconfigure ${w}main.right.panel.task 1 -weight 1
  grid rowconfigure ${w}main.right.panel.task 4 -weight 1
  grid rowconfigure ${w}main.right.panel.task 5 -weight 1

  ttk::button ${w}main.right.panel.apply -style WbRounded.TButton -text "Apply" -state disabled -command {::wb::cfg::panelApply}
  label ${w}main.right.panel.err -textvariable ::wb::cfg::panelErrMsg -foreground red -anchor w -justify left -height 2 -wraplength 900 -relief flat

  # opts listbox visibility managed by panelShowMode based on current mode

  frame ${w}log
  text ${w}log.t -height 7
  pack ${w}log.t -fill x

  set ui(saveFinal) 0

  set ui(taskList) ${w}main.left.lb
  set ui(taskTitle) ${w}main.right.t
  set ui(taskName) ${w}main.right.t.v
  set ui(panelHost) ${w}main.right.panel
  set ui(panelBody) ${w}main.right.panel.body
  set ui(panelFlow) ${w}main.right.panel.flow
  set ui(panelTask) ${w}main.right.panel.task
  set ui(panelApply) ${w}main.right.panel.apply
  set ui(panelErr) ${w}main.right.panel.err
  set ui(taskNameEntry) ${w}main.right.panel.task.nameE
  set ui(taskRenameBtn) ${w}main.right.panel.task.renameBtn
  set ui(taskDepLabel) ${w}main.right.panel.task.depL
  set ui(taskFailLabel) ${w}main.right.panel.task.failL
  set ui(taskDepends) ${w}main.right.panel.task.depF
  set ui(taskWhenFail) ${w}main.right.panel.task.failF
  set ui(staleAfterLabel) ${w}main.right.panel.task.staleAfterL
  set ui(staleAfterFrame) ${w}main.right.panel.task.staleAfterF
  set ui(itemsList) ${w}main.right.opts
  # Compatibility for fs-opts.tcl (expects ui(optsList))
  set ui(optsList) ${w}main.right.opts
  # Options-mode treeview grid
  set ui(optsGrid)      ${w}main.right.optsGrid
  set ui(optsTv)        ${w}main.right.optsGrid.tv
  set ui(parmsGrid)     ${w}main.right.parmsGrid
  set ui(parmsTv)       ${w}main.right.parmsGrid.tv
  set ui(runpropsGrid)  ${w}main.right.runpropsGrid
  set ui(runpropsTv)    ${w}main.right.runpropsGrid.tv
  # Item-level panel (options/parms/runprops)
  set ui(itemPanel)  ${w}main.right.itemPanel
  set ui(itemApply)  ${w}main.right.itemPanel.apply
  set ui(itemErr)    ${w}main.right.itemPanel.err
  set ui(btnRemove) ${w}main.right.h.remove
  set ui(btnMoveUp) ${w}main.right.h.up
  set ui(btnEdit)   ${w}main.right.h.edit
  set ui(btnGClone) ${w}g.clone
  set ui(gFinalCb)  ${w}g.final
  set ui(modeCombo) ${w}main.right.h.mode
  set ui(btnAdd)    ${w}main.right.h.add
  set ui(btnSave)    ${w}g.save
  set ui(btnRestart) ${w}g.restartBtn
  set ui(log) ${w}log.t

  set ::wb::cfg::enableRestart 0
  ::wb::cfg::updateRestartBtn

  set ::wb::cfg::panel(flowName)  ""
  set ::wb::cfg::panel(flowTitle) ""
  set ::wb::cfg::panel(taskName)  ""
  set ::wb::cfg::panel(taskTitle) ""
  set ::wb::cfg::panel(taskDesc)  ""
  set ::wb::cfg::panel(taskType)  "tcl-int"
  set ::wb::cfg::panel(staleAfterVal)  ""
  set ::wb::cfg::panel(staleAfterUnit) "secs"

foreach vName {
  ::wb::cfg::panel(flowName)
  ::wb::cfg::panel(flowTitle)
  ::wb::cfg::panel(taskName)
  ::wb::cfg::panel(taskTitle)
  ::wb::cfg::panel(taskDesc)
  ::wb::cfg::panel(taskType)
  ::wb::cfg::panel(staleAfterVal)
  ::wb::cfg::panel(staleAfterUnit)
} {
  catch {trace remove variable $vName write ::wb::cfg::panelTrackVar}
  trace add variable $vName write ::wb::cfg::panelTrackVar
}

set ::wb::cfg::panelErrMsg ""

  bind $ui(taskList) <<ListboxSelect>> ::wb::cfg::uiSelectTask
  bind $ui(itemsList) <<ListboxSelect>> ::wb::cfg::uiSelectItem
  bind $ui(optsTv)      <<TreeviewSelect>> ::wb::cfg::uiOptsGridSelect
  bind $ui(parmsTv)     <<TreeviewSelect>> ::wb::cfg::parmsGridSelect
  bind $ui(runpropsTv)  <<TreeviewSelect>> ::wb::cfg::runpropsGridSelect

  uiLoadTasks

  # Startup: select first task and CALL handler directly (no reliance on virtual event ordering)
  if {[::wb::cfg::taskTvSize] > 0} {
    ::wb::cfg::taskTvSelect 0
    update idletasks
    ::wb::cfg::uiSelectTask
  }

  # Run initial validation so save gate and task indicators are correct from the start
  ::wb::cfg::cfgSaveGate

  ::wb::cfg::uiSetMode $::wb::cfg::curMode

  update idletasks
  wm geometry $w 1560x780
  ::wb::cfg::centerWin $w 1460 780
  ::wb::cfg::panelErrRefresh

  # Raise this window to the front on startup (Option 2 cooperative raise).
  # Called after the window is fully built so Windows sees an active Tk window.
  wm deiconify $w
  catch {wm attributes $w -topmost 1}
  raise $w
  focus -force $w
  after 500 [list catch [list wm attributes $w -topmost 0]]

  log "==> wb-cfg $::wb::cfg::VERSION loaded"

}

# --- main ------------------------------------------------------
# ---------------------------------------------------------------------------

proc ::wb::cfg::bootConfigurator {cfgPath} {
  variable opts
  hilite -green "booting configurator $cfgPath devp=[fsCfgGetBool devp.enabled]"

  ::wb::cfg::openCfg $cfgPath
  vwait forever
}


if {[info exists argv0] && [file tail $argv0] eq [file tail [info script]]} {
  puts stderr "==> Loading fs-cfg.tcl (::wb::cfg $::wb::cfg::VERSION)"

  if {[llength $argv] < 1} {
    puts stderr "Usage: tclsh [file tail [info script]] <flow-cfg.json>"
    exit 2
  }
  variable ::wb::cfg::opts

  #  m or .       flag      argname  description
  set parmsDef {
  }

  array set ::wb::cfg::opts [parseParms $parmsDef 1 $argv]

  ::wb::cfg::bootConfigurator $::wb::cfg::opts(POS0)
}
