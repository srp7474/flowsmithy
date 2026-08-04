# Generated 2026-jul-28 courtesy of Claude (claude.ai)
# fs-clone.tcl - v12
# Changelog (skinny; full detail in CHANGELOG.md):
#   v12 (2026-jul-28): changelog moved to CHANGELOG.md; this header now a skinny per-version log
#   v11: fixed blank "Cloning into flow:" label on window open (destFlow assigned too late)
#   v10: REVERT of v09 -- runprops is a plain dict on disk, not a list of {key,value} objects
#   v08: flow name field is now a case-insensitive regex match against folder names
#   v07: new "Flow names" field in Search Criteria, restricts scan to matching flows
#   v06: options rows show control type in parens; new Clone This Task button
#   v05: new reusable Task Detail window (.wbCloneDetail) -- Options/Parms/Runprops
#   v04: real fix for checkbox spacing (label sized to column 0 without columnspan)
#   v03: uniform padding on Type checkboxes; search regex made case-insensitive
#   v02: fixed "bad screen distance '0 12'" crash on open
#   v01: initial version
#
# ::wb::clone -- Clone Task search/select window.
#
# Replaces the old single-flow-dropdown Clone Task dialog
# (::wb::cfg::cloneTaskDialog et al -- since removed from fs-cfg.tcl)
# with a scan-and-filter workflow:
#
#   1. openCloneTaskWindow scans every flow under flows.dir and reads
#      each <flow>/<flow>-cfg.json's tasks[] list.
#   2. Search Criteria panel: a single regex (matches Title OR Desc),
#      a Type filter (checkboxes; none checked = Any), and a
#      "Recipes only" checkbox (task has a non-empty recipe field).
#      Search is re-runnable any time criteria change.
#   3. Results are de-duplicated when desc+type are identical --
#      first occurrence wins (flows in alpha order, tasks in cfg.json
#      order), duplicates dropped silently (no count shown).
#   4. Each result is shown as a card: Src Flow, Src Task, Title,
#      Desc, Type, Recipe (if present), runprops.javaMain (if present).
#   5. Clicking a card opens/updates a reusable Task Detail window showing
#      Options (actual saved values), Parms, and Runprops (definitions),
#      in that order. Real clone execution (prompt for new name, copy task
#      dict + files) is separate follow-up work; see
#      ::wb::cfg::cloneTaskFromSameFlow / cloneTaskFromOtherFlow /
#      cloneRenameTaskFile in fs-cfg.tcl, which remain in place and are
#      likely candidates for that plumbing.
#   6. Search window has an explicit Close button plus the window-manager
#      close box. Neither it nor the Task Detail window is modal (a
#      strict OS-level Tk grab on one toplevel blocks all sibling
#      toplevels in the same app, which would break the reusable-window
#      behaviour -- see CHANGELOG.md v05 for the full reasoning).
# ---------------------------------------------------------------------------

namespace eval ::wb::clone {
  variable VERSION 12

  # Search criteria state (persists only while the process is running;
  # reset to defaults each time the window is opened)
  variable crit
  array set crit {
    text        ""
    flows       ""
    tJava       0
    tTclInt     0
    tTclExt     0
    tManual     0
    recipeOnly  0
  }
  #   flow task title desc type recipe javaMain
  variable results {}

  # Status line text ("N task(s) found.")
  variable statusText ""

  # Destination flow name, captured when the window is opened
  variable destFlow ""

  # The result record currently shown in the Task Detail window
  # (set by _populateDetailWindow; read by onCloneButtonClick)
  variable curDetailRec {}

  puts stderr "==> Loading fs-clone.tcl (v$VERSION)"
}

# ---------------------------------------------------------------------------
# openCloneTaskWindow
#
# Entry point. Called from ::wb::cfg::uiCloneItem when curMode eq "task".
# Builds the search-criteria + scrollable-results window and runs an
# initial (unfiltered) scan.
# ---------------------------------------------------------------------------
proc ::wb::clone::openCloneTaskWindow {} {
  variable crit
  variable destFlow

  # Reset criteria to defaults on every open
  array set crit {
    text        ""
    flows       ""
    tJava       0
    tTclInt     0
    tTclExt     0
    tManual     0
    recipeOnly  0
  }

  # v11: resolve destFlow up front so the "Cloning into flow:" label below
  # is correct on open, instead of showing blank until (too late) it's set
  # inside onCloneButtonClick.
  set destFlow [::wb::cfg::cfgBaseName]

  set w .wbCloneScan
  catch { destroy $w }
  toplevel $w
  wm title $w "Clone Task -- Search Existing Flows"
  wm protocol $w WM_DELETE_WINDOW ::wb::clone::closeWindow

  # ---- Destination info ----------------------------------------------
  frame $w.top -padx 14 -pady 10
  pack  $w.top -side top -fill x

  label $w.top.destL -text "Cloning into flow:" -anchor e
  label $w.top.destV -text $destFlow -font TkBoldFont -anchor w \
    -foreground "#1a5fb4"
  grid  $w.top.destL -row 0 -column 0 -sticky e -padx {0 8}
  grid  $w.top.destV -row 0 -column 1 -sticky w
  grid columnconfigure $w.top 1 -weight 1

  # ---- Search Criteria panel ------------------------------------------
  labelframe $w.crit -text "Search Criteria" -padx 10 -pady 8
  pack $w.crit -side top -fill x -padx 14 -pady {0 8}

  label $w.crit.txtL \
    -text "Search text (regex, case-insensitive, matches Title or Desc -- blank = any):" \
    -anchor w
  entry $w.crit.txtE -textvariable ::wb::clone::crit(text) -width 70
  grid  $w.crit.txtL -row 0 -column 0 -columnspan 5 -sticky w -pady {0 2}
  grid  $w.crit.txtE -row 1 -column 0 -columnspan 5 -sticky we -pady {0 8}

  label $w.crit.flowsL \
    -text "Flow name (regex, case-insensitive, blank = all flows):" \
    -anchor w
  entry $w.crit.flowsE -textvariable ::wb::clone::crit(flows) -width 70
  grid  $w.crit.flowsL -row 2 -column 0 -columnspan 5 -sticky w -pady {0 2}
  grid  $w.crit.flowsE -row 3 -column 0 -columnspan 5 -sticky we -pady {0 8}

  label $w.crit.typeL -text "Type (none checked = Any):" -anchor w
  checkbutton $w.crit.tJava   -text "java"    -variable ::wb::clone::crit(tJava)
  checkbutton $w.crit.tTclInt -text "tcl-int" -variable ::wb::clone::crit(tTclInt)
  checkbutton $w.crit.tTclExt -text "tcl-ext" -variable ::wb::clone::crit(tTclExt)
  checkbutton $w.crit.tManual -text "manual"  -variable ::wb::clone::crit(tManual)
  grid $w.crit.typeL   -row 4 -column 0 -columnspan 5 -sticky w -pady {0 4}
  grid $w.crit.tJava   -row 5 -column 0 -sticky w -padx {0 18}
  grid $w.crit.tTclInt -row 5 -column 1 -sticky w -padx {0 18}
  grid $w.crit.tTclExt -row 5 -column 2 -sticky w -padx {0 18}
  grid $w.crit.tManual -row 5 -column 3 -sticky w -padx {0 18}

  checkbutton $w.crit.recipeOnly -text "Recipes only" \
    -variable ::wb::clone::crit(recipeOnly)
  grid $w.crit.recipeOnly -row 6 -column 0 -columnspan 2 -sticky w -pady {8 0}

  frame $w.crit.btns
  grid  $w.crit.btns -row 6 -column 2 -columnspan 3 -sticky e -pady {8 0}
  ttk::button $w.crit.btns.search -style WbRounded.TButton -text "Search" \
    -command ::wb::clone::doScan
  ttk::button $w.crit.btns.close  -style WbRounded.TButton -text "Close" \
    -command ::wb::clone::closeWindow
  pack $w.crit.btns.search -side left -padx 4
  pack $w.crit.btns.close  -side left -padx 4

  grid columnconfigure $w.crit 4 -weight 1

  # ---- Status line ------------------------------------------------------
  label $w.status -textvariable ::wb::clone::statusText -anchor w -padx 14
  pack  $w.status -side top -fill x

  # ---- Scrollable results panel -----------------------------------------
  frame $w.res -padx 14 -pady 12
  pack  $w.res -side top -fill both -expand 1

  canvas $w.res.c -highlightthickness 0 -bd 0
  ttk::scrollbar $w.res.sy -orient vertical -command [list $w.res.c yview]
  $w.res.c configure -yscrollcommand [list $w.res.sy set]
  frame $w.res.c.f
  $w.res.c create window 0 0 -anchor nw -window $w.res.c.f -tags inner

  pack $w.res.sy -side right -fill y
  pack $w.res.c  -side left  -fill both -expand 1

  bind $w.res.c <Configure> {
    %W itemconfigure inner -width [winfo width %W]
    %W configure -scrollregion [list 0 0 [winfo reqwidth %W.f] [winfo reqheight %W.f]]
  }
  bind $w.res.c.f <Configure> {
    set _c [winfo parent %W]
    $_c configure -scrollregion [list 0 0 [winfo reqwidth %W] [winfo reqheight %W]]
  }
  bind $w.res.c <MouseWheel> [list ::wb::clone::_resultsMouseWheel $w.res.c %D]

  # ---- Transient, on top of the configurator (not modal -- the detail
  # window opened from a result click needs to stay usable alongside
  # this window; see onResultClick / showTaskDetail) -----------------
  wm transient $w .
  update idletasks
  ::wb::cfg::centerWin $w 900 700
  focus $w.crit.txtE

  # Initial (unfiltered) scan
  ::wb::clone::doScan
}

# ---------------------------------------------------------------------------
# closeWindow -- releases the modal grab and destroys the window.
# ---------------------------------------------------------------------------
proc ::wb::clone::closeWindow {} {
  set w .wbCloneScan
  catch { grab release $w }
  catch { destroy $w }
}

# ---------------------------------------------------------------------------
# _resultsMouseWheel -- standard Tk mousewheel-to-yview scroll helper.
# ---------------------------------------------------------------------------
proc ::wb::clone::_resultsMouseWheel {canvas delta} {
  $canvas yview scroll [expr {-$delta / 120}] units
}

# ---------------------------------------------------------------------------
# doScan
#
# Validates the regex (if any), scans all flows, applies filters, dedups,
# and re-renders the results panel.
# ---------------------------------------------------------------------------
proc ::wb::clone::doScan {} {
  variable crit
  variable results

  set txt [string trim $crit(text)]
  if {$txt ne "" && [catch {regexp -nocase -- $txt ""}]} {
    tk_messageBox -icon error -title "Clone Task Search" \
      -message "Invalid regular expression:\n$txt"
    return
  }

  set flowRe [string trim $crit(flows)]
  if {$flowRe ne "" && [catch {regexp -nocase -- $flowRe ""}]} {
    tk_messageBox -icon error -title "Clone Task Search" \
      -message "Invalid flow name regular expression:\n$flowRe"
    return
  }

  set raw {}
  if {[catch {::wb::clone::scanAllTasks $flowRe} raw]} {
    tk_messageBox -icon error -title "Clone Task Search" \
      -message "Scan failed:\n$raw"
    set raw {}
  }

  set filtered {}
  foreach rec $raw {
    if {[::wb::clone::taskMatches $rec]} { lappend filtered $rec }
  }

  set results [::wb::clone::dedupResults $filtered]
  ::wb::clone::renderResults
}

# ---------------------------------------------------------------------------
# scanAllTasks  ?flowRegex?
#
# Reads every <flow>/<flow>-cfg.json under flows.dir and returns a flat
# list of task record dicts:
#   flow task title desc type recipe javaMain
# flowRegex, if non-empty, is matched case-insensitively against each flow
# folder name (regexp -nocase) -- only matching flows are scanned. Blank/
# omitted flowRegex means "scan all flows".
# Flows/cfg files that fail to parse are skipped (logged), scan continues.
# ---------------------------------------------------------------------------
proc ::wb::clone::scanAllTasks {{flowRegex ""}} {
  set out {}
  set flowsDir [::wb::lib::requireTclFlows]

  foreach d [lsort [glob -nocomplain -directory $flowsDir -type d *]] {
    set flow    [file tail $d]

    if {$flowRegex ne ""} {
      if {[catch {regexp -nocase -- $flowRegex $flow} m] || !$m} { continue }
    }

    set cfgPath [file join $d "${flow}-cfg.json"]
    if {![file exists $cfgPath]} { continue }

    if {[catch {jsonFileAsDict $cfgPath} cfgDict]} {
      log "fs-clone scanAllTasks: failed to parse $cfgPath: $cfgDict"
      continue
    }
    if {![dict exists $cfgDict tasks]} { continue }

    foreach t [dict get $cfgDict tasks] {
      set javaMain ""
      if {[dict exists $t runprops] && [dict exists $t runprops javaMain]} {
        set javaMain [dict get $t runprops javaMain]
      }
      set rec [dict create \
        flow     $flow \
        task     [expr {[dict exists $t name]   ? [dict get $t name]   : ""}] \
        title    [expr {[dict exists $t title]  ? [dict get $t title]  : ""}] \
        desc     [expr {[dict exists $t desc]   ? [dict get $t desc]   : ""}] \
        type     [expr {[dict exists $t type]   ? [dict get $t type]   : ""}] \
        recipe   [expr {[dict exists $t recipe] ? [dict get $t recipe] : ""}] \
        javaMain $javaMain \
        raw      $t \
      ]
      lappend out $rec
    }
  }
  return $out
}

# ---------------------------------------------------------------------------
# taskMatches  rec
#
# Applies the current ::wb::clone::crit filters to a single task record.
# Returns 1 if it matches, 0 otherwise.
# ---------------------------------------------------------------------------
proc ::wb::clone::taskMatches {rec} {
  variable crit

  set txt [string trim $crit(text)]
  if {$txt ne ""} {
    set matched 0
    if {![catch {regexp -nocase -- $txt [dict get $rec title]} rt] && $rt} { set matched 1 }
    if {!$matched} {
      if {![catch {regexp -nocase -- $txt [dict get $rec desc]} rd] && $rd} { set matched 1 }
    }
    if {!$matched} { return 0 }
  }

  set anyTypeChecked [expr {
    $crit(tJava) || $crit(tTclInt) || $crit(tTclExt) || $crit(tManual)
  }]
  if {$anyTypeChecked} {
    set ok 0
    switch -exact -- [dict get $rec type] {
      java    { if {$crit(tJava)}   { set ok 1 } }
      tcl-int { if {$crit(tTclInt)} { set ok 1 } }
      tcl-ext { if {$crit(tTclExt)} { set ok 1 } }
      manual  { if {$crit(tManual)} { set ok 1 } }
    }
    if {!$ok} { return 0 }
  }

  if {$crit(recipeOnly)} {
    if {[string trim [dict get $rec recipe]] eq ""} { return 0 }
  }

  return 1
}

# ---------------------------------------------------------------------------
# dedupResults  list
#
# Drops later entries whose desc+type match an earlier entry (first
# occurrence in scan order wins). Silent -- no count of drops is shown.
# ---------------------------------------------------------------------------
proc ::wb::clone::dedupResults {list} {
  set seen [dict create]
  set out {}
  foreach rec $list {
    set key "[dict get $rec desc]\u0001[dict get $rec type]"
    if {[dict exists $seen $key]} { continue }
    dict set seen $key 1
    lappend out $rec
  }
  return $out
}

# ---------------------------------------------------------------------------
# renderResults
#
# Rebuilds the scrollable results panel from ::wb::clone::results.
# ---------------------------------------------------------------------------
proc ::wb::clone::renderResults {} {
  variable results
  variable statusText

  set w .wbCloneScan
  if {![winfo exists $w]} { return }
  set f $w.res.c.f
  foreach child [winfo children $f] { destroy $child }

  set statusText "[llength $results] task(s) found."

  if {[llength $results] == 0} {
    label $f.none -text "No matching tasks found." -anchor w -padx 10 -pady 10
    grid  $f.none -row 0 -column 0 -sticky w
  } else {
    set row 0
    foreach rec $results {
      ::wb::clone::_buildResultCard $f $row $rec
      incr row
    }
  }

  grid columnconfigure $f 0 -weight 1

  update idletasks
  set c $w.res.c
  if {[winfo exists $c]} {
    $c configure -scrollregion [list 0 0 [winfo reqwidth $f] [winfo reqheight $f]]
  }
}

# ---------------------------------------------------------------------------
# _buildResultCard  parentFrame  row  rec
#
# Builds one result "card" showing Src Flow, Src Task, Title, Desc, Type,
# Recipe (if present) and runprops.javaMain (if present). The whole card
# is clickable (and hover-highlighted) -- click invokes onResultClick.
# ---------------------------------------------------------------------------
proc ::wb::clone::_buildResultCard {parentFrame row rec} {
  set card ${parentFrame}.card${row}
  frame $card -relief groove -borderwidth 1 -padx 8 -pady 6
  grid  $card -row $row -column 0 -sticky we -padx 4 -pady 3
  grid columnconfigure $card 1 -weight 1

  set r 0
  ::wb::clone::_cardField $card r "Src Flow" [dict get $rec flow]
  ::wb::clone::_cardField $card r "Src Task" [dict get $rec task]
  ::wb::clone::_cardField $card r "Title"    [dict get $rec title]
  ::wb::clone::_cardField $card r "Desc"     [dict get $rec desc]
  ::wb::clone::_cardField $card r "Type"     [dict get $rec type]
  if {[string trim [dict get $rec recipe]] ne ""} {
    ::wb::clone::_cardField $card r "Recipe" [dict get $rec recipe]
  }
  if {[string trim [dict get $rec javaMain]] ne ""} {
    ::wb::clone::_cardField $card r "runprops.javaMain" [dict get $rec javaMain]
  }

  bind $card <Button-1> [list ::wb::clone::onResultClick $rec]
  bind $card <Enter>    [list $card configure -background "#e8f0fe"]
  bind $card <Leave>    [list $card configure -background [. cget -background]]
  foreach ch [winfo children $card] {
    bind $ch <Button-1> [list ::wb::clone::onResultClick $rec]
    bind $ch <Enter>    [list $card configure -background "#e8f0fe"]
    bind $ch <Leave>    [list $card configure -background [. cget -background]]
  }
}

# ---------------------------------------------------------------------------
# _cardField  card  rowVarName  label  value
#
# Grids one Label:Value row into $card at row [set $rowVarName], then
# increments that row counter (passed by name via upvar).
# ---------------------------------------------------------------------------
proc ::wb::clone::_cardField {card rowVarName label value} {
  upvar 1 $rowVarName row
  label $card.l$row -text "${label}:" -anchor ne \
    -font {TkDefaultFont 9 bold} -width 18
  label $card.v$row -text $value -anchor w -justify left -wraplength 640
  grid  $card.l$row -row $row -column 0 -sticky ne -padx {0 8} -pady 1
  grid  $card.v$row -row $row -column 1 -sticky w  -pady 1
  incr row
}

# ---------------------------------------------------------------------------
# onResultClick  rec
#
# Opens (or repopulates, if already open) the reusable Task Detail window
# for the clicked result. Real clone execution (prompt for new name, clash
# check, copy task dict + folder) is separate follow-up work -- see
# ::wb::cfg::cloneTaskFromSameFlow / cloneTaskFromOtherFlow /
# cloneRenameTaskFile in fs-cfg.tcl.
# ---------------------------------------------------------------------------
proc ::wb::clone::onResultClick {rec} {
  variable destFlow
  log "Clone Task: viewing detail for srcFlow='[dict get $rec flow]' srcTask='[dict get $rec task]' (target flow='$destFlow')"
  ::wb::clone::showTaskDetail $rec
}

# ---------------------------------------------------------------------------
# showTaskDetail  rec
#
# Entry point for the reusable Task Detail window. Creates the window on
# first use; on subsequent calls (a second/third result clicked) it just
# repopulates the existing window rather than rebuilding it.
# ---------------------------------------------------------------------------
proc ::wb::clone::showTaskDetail {rec} {
  set w [::wb::clone::_ensureDetailWindow]
  ::wb::clone::_populateDetailWindow $w $rec
  wm deiconify $w
  raise $w
}

# ---------------------------------------------------------------------------
# _ensureDetailWindow
#
# Builds the Task Detail window's static structure (header frame, scrollable
# body, Close button) exactly once. Returns the existing window path on
# every subsequent call without rebuilding anything -- this is what makes
# the window "reusable" across multiple result clicks.
# ---------------------------------------------------------------------------
proc ::wb::clone::_ensureDetailWindow {} {
  set w .wbCloneDetail
  if {[winfo exists $w]} { return $w }

  toplevel $w
  wm title $w "Task Detail"
  wm protocol $w WM_DELETE_WINDOW ::wb::clone::_closeDetailWindow
  wm transient $w .

  # ---- Header: Src Flow / Src Task / Title / Type / Desc (fixed, not
  # part of the scrolling body) -----------------------------------------
  frame $w.hdr -padx 14 -pady 10
  pack  $w.hdr -side top -fill x

  ttk::separator $w.hsep -orient horizontal
  pack  $w.hsep -side top -fill x -padx 14

  # ---- Buttons (fixed, bottom) ------------------------------------------
  frame $w.btns -padx 14 -pady 10
  pack  $w.btns -side bottom -fill x
  ttk::button $w.btns.close -style WbRounded.TButton -text "Close" \
    -command ::wb::clone::_closeDetailWindow
  pack $w.btns.close -side right
  ttk::button $w.btns.clone -style WbRounded.TButton -text "Clone This Task" \
    -command ::wb::clone::onCloneButtonClick
  pack $w.btns.clone -side right -padx 6

  # ---- Scrollable body: Options / Parms / Runprops sections -------------
  frame $w.body -padx 14 -pady 10
  pack  $w.body -side top -fill both -expand 1

  canvas $w.body.c -highlightthickness 0 -bd 0
  ttk::scrollbar $w.body.sy -orient vertical -command [list $w.body.c yview]
  $w.body.c configure -yscrollcommand [list $w.body.sy set]
  frame $w.body.c.f
  $w.body.c create window 0 0 -anchor nw -window $w.body.c.f -tags inner

  pack $w.body.sy -side right -fill y
  pack $w.body.c  -side left  -fill both -expand 1

  bind $w.body.c <Configure> {
    %W itemconfigure inner -width [winfo width %W]
    %W configure -scrollregion [list 0 0 [winfo reqwidth %W.f] [winfo reqheight %W.f]]
  }
  bind $w.body.c.f <Configure> {
    set _c [winfo parent %W]
    $_c configure -scrollregion [list 0 0 [winfo reqwidth %W] [winfo reqheight %W]]
  }
  bind $w.body.c <MouseWheel> [list ::wb::clone::_resultsMouseWheel $w.body.c %D]

  # Dock to the right side of the screen so it can sit alongside the
  # search window rather than fully overlapping it. Only done once, at
  # creation -- if the user drags it later we leave it where they put it.
  update idletasks
  set ww 820
  set wh 700
  set sw [winfo screenwidth $w]
  set sh [winfo screenheight $w]
  set x  [expr {$sw - $ww - 30}]
  if {$x < 0} { set x 0 }
  set y  [expr {($sh - $wh) / 2}]
  if {$y < 0} { set y 0 }
  wm geometry $w "${ww}x${wh}+${x}+${y}"

  return $w
}

# ---------------------------------------------------------------------------
# _closeDetailWindow
# ---------------------------------------------------------------------------
proc ::wb::clone::_closeDetailWindow {} {
  catch { destroy .wbCloneDetail }
}

# ---------------------------------------------------------------------------
# _populateDetailWindow  w  rec
#
# Rebuilds the header and the Options / Parms / Runprops sections from rec.
# Called every time a result is clicked, whether the window was just
# created or already open from a previous selection.
# ---------------------------------------------------------------------------
proc ::wb::clone::_populateDetailWindow {w rec} {
  variable curDetailRec
  set curDetailRec $rec

  set flow  [dict get $rec flow]
  set task  [dict get $rec task]
  set title [dict get $rec title]
  set type  [dict get $rec type]
  set desc  [dict get $rec desc]
  set raw   [dict get $rec raw]

  wm title $w "Task Detail: $flow / $task"

  # ---- Header -------------------------------------------------------
  set hdr $w.hdr
  foreach c [winfo children $hdr] { destroy $c }

  set hr 0
  foreach {lbl val wrap} [list \
      "Src Flow:" $flow  0 \
      "Src Task:" $task  0 \
      "Title:"    $title 0 \
      "Type:"     $type  0 \
      "Desc:"     $desc  1 \
    ] {
    label $hdr.l$hr -text $lbl -anchor e -font {TkDefaultFont 9 bold} -width 12
    if {$wrap} {
      label $hdr.v$hr -text $val -anchor w -justify left -wraplength 640
    } else {
      label $hdr.v$hr -text $val -anchor w
    }
    grid  $hdr.l$hr -row $hr -column 0 -sticky ne -padx {0 8} -pady 1
    grid  $hdr.v$hr -row $hr -column 1 -sticky w  -pady 1
    incr hr
  }
  grid columnconfigure $hdr 1 -weight 1

  # ---- Body: Options / Parms / Runprops, in that order ---------------
  set f $w.body.c.f
  foreach c [winfo children $f] { destroy $c }

  set row 0

  # -- Options (from <flow>/tasks/<task>/options.json -- actual saved
  #    values, unlike Parms/Runprops which are just config definitions) --
  ::wb::clone::_detailSectionHeader $f row "Options"
  set optDict [::wb::clone::_loadTaskOptions $flow $task]
  if {[dict size $optDict] == 0} {
    ::wb::clone::_detailEmptyRow $f row "(no options.json found for this task)"
  } else {
    # opts[] in cfg.json defines each option's control type, keyed by
    # its "label" -- that's the same string used as the options.json key.
    set optTypes [dict create]
    if {[dict exists $raw opts]} {
      foreach o [dict get $raw opts] {
        if {[dict exists $o label]} {
          set oty ""
          if {[dict exists $o type]} { set oty [dict get $o type] }
          dict set optTypes [dict get $o label] $oty
        }
      }
    }
    dict for {k v} $optDict {
      set lbl $k
      if {[dict exists $optTypes $k] && [dict get $optTypes $k] ne ""} {
        set lbl "$k ([dict get $optTypes $k])"
      }
      ::wb::clone::_detailKVRow $f row $lbl $v
    }
  }

  # -- Parms (definitions from cfg.json: parm / parmExec / hint) --------
  ::wb::clone::_detailSectionHeader $f row "Parms"
  set parms {}
  if {[dict exists $raw parms]} { set parms [dict get $raw parms] }
  if {[llength $parms] == 0} {
    ::wb::clone::_detailEmptyRow $f row "(no parms defined)"
  } else {
    foreach p $parms {
      set pname ""
      set pexec ""
      set phint ""
      if {[dict exists $p parm]}     { set pname [dict get $p parm] }
      if {[dict exists $p parmExec]} { set pexec [dict get $p parmExec] }
      if {[dict exists $p hint]}     { set phint [dict get $p hint] }
      set sub ""
      if {$phint ne ""} { set sub "hint: $phint" }
      ::wb::clone::_detailKVRow $f row $pname $pexec $sub
    }
  }

  # -- Runprops (definitions from cfg.json, e.g. javaMain / cpTag) ------
  ::wb::clone::_detailSectionHeader $f row "Runprops"
  set runprops [dict create]
  if {[dict exists $raw runprops]} { set runprops [dict get $raw runprops] }
  if {[dict size $runprops] == 0} {
    ::wb::clone::_detailEmptyRow $f row "(no runprops defined)"
  } else {
    dict for {k v} $runprops {
      ::wb::clone::_detailKVRow $f row $k $v
    }
  }

  grid columnconfigure $f 1 -weight 1

  update idletasks
  set c $w.body.c
  if {[winfo exists $c]} {
    $c configure -scrollregion [list 0 0 [winfo reqwidth $f] [winfo reqheight $f]]
    $c yview moveto 0
  }
}

# ---------------------------------------------------------------------------
# _detailSectionHeader  parent  rowVarName  titleText
#
# Grids a bold section heading + separator at row [set $rowVarName],
# advancing the row counter (passed by name via upvar).
# ---------------------------------------------------------------------------
proc ::wb::clone::_detailSectionHeader {parent rowVarName titleText} {
  upvar 1 $rowVarName row
  if {$row > 0} {
    frame $parent.sp$row -height 10
    grid  $parent.sp$row -row $row -column 0 -columnspan 2 -sticky w
    incr row
  }
  label $parent.sh$row -text $titleText -anchor w \
    -font {TkDefaultFont 11 bold} -foreground "#1a5fb4"
  grid  $parent.sh$row -row $row -column 0 -columnspan 2 -sticky w -padx {4 0} -pady {2 4}
  incr row
  ttk::separator $parent.ssep$row -orient horizontal
  grid  $parent.ssep$row -row $row -column 0 -columnspan 2 -sticky we -pady {0 6}
  incr row
}

# ---------------------------------------------------------------------------
# _detailKVRow  parent  rowVarName  label  value  ?sub?
#
# Grids one Label:Value row, with an optional smaller/greyed sub-line
# underneath (used for a parm's hint text).
# ---------------------------------------------------------------------------
proc ::wb::clone::_detailKVRow {parent rowVarName label value {sub ""}} {
  upvar 1 $rowVarName row
  label $parent.l$row -text "${label}:" -anchor ne \
    -font {TkDefaultFont 9 bold} -width 18
  label $parent.v$row -text $value -anchor w -justify left -wraplength 560
  grid  $parent.l$row -row $row -column 0 -sticky ne -padx {12 8} -pady 1
  grid  $parent.v$row -row $row -column 1 -sticky w  -pady 1
  incr row
  if {$sub ne ""} {
    label $parent.s$row -text $sub -anchor w -justify left -wraplength 560 \
      -font {TkDefaultFont 8} -foreground "#666666"
    grid  $parent.s$row -row $row -column 1 -sticky w -pady {0 4}
    incr row
  }
}

# ---------------------------------------------------------------------------
# _detailEmptyRow  parent  rowVarName  text
# ---------------------------------------------------------------------------
proc ::wb::clone::_detailEmptyRow {parent rowVarName text} {
  upvar 1 $rowVarName row
  label $parent.e$row -text $text -anchor w -foreground "#888888" \
    -font {TkDefaultFont 9 italic}
  grid  $parent.e$row -row $row -column 0 -columnspan 2 -sticky w -padx {12 0} -pady {0 4}
  incr row
}

# ---------------------------------------------------------------------------
# _loadTaskOptions  flow  task
#
# Reads <flowsDir>/<flow>/tasks/<task>/options.json (the task's saved
# option values -- separate from the parms/runprops definitions that live
# in the flow's cfg.json). Returns an empty dict if the file is missing
# or fails to parse (logged, not fatal).
# ---------------------------------------------------------------------------
proc ::wb::clone::_loadTaskOptions {flow task} {
  if {[catch {::wb::lib::requireTclFlows} flowsDir]} { return [dict create] }
  set optPath [file join $flowsDir $flow tasks $task options.json]
  if {![file exists $optPath]} { return [dict create] }
  if {[catch {jsonFileAsDict $optPath} d]} {
    log "fs-clone _loadTaskOptions: failed to parse $optPath: $d"
    return [dict create]
  }
  return $d
}

# ---------------------------------------------------------------------------
# _chooseUniqueTaskName  baseName
#
# Returns baseName unchanged if it doesn't already exist as a task in the
# currently open (destination) flow. Otherwise appends -copy1, -copy2, ...
# until a free name is found.
# ---------------------------------------------------------------------------
proc ::wb::clone::_chooseUniqueTaskName {baseName} {
  set existing [::wb::cfg::taskNames]
  if {[lsearch -exact $existing $baseName] < 0} { return $baseName }
  set n 1
  while {1} {
    set candidate "${baseName}-copy${n}"
    if {[lsearch -exact $existing $candidate] < 0} { return $candidate }
    incr n
  }
}

# ---------------------------------------------------------------------------
# onCloneButtonClick
#
# The real Clone action, run against whatever task the Task Detail window
# is currently showing (::wb::clone::curDetailRec):
#   1. Insert the cloned task dict into the destination flow's cfgDict
#      (in memory -- same "dirty until Save" convention as every other
#      edit in the configurator) right after the currently selected task.
#   2. Name: keep the source task's name if free in the destination flow,
#      otherwise uniquify with -copyN.
#   3/4. Create <destFlow>/tasks/<chosenName>/ and copy the source task
#      folder's files into it.
#   5. Files are renamed via the existing cloneRenameTaskFile (handles
#      <src>-help.md and <src>-*.tcl -> <chosenName>-... renaming).
#   6. Refresh the configurator's task list/selection, then close both
#      the Task Detail and Clone Task Search windows.
# ---------------------------------------------------------------------------
proc ::wb::clone::onCloneButtonClick {} {
  variable curDetailRec

  if {$curDetailRec eq ""} {
    tk_messageBox -icon error -title "Clone Task" -message "No task selected."
    return
  }

  set srcFlow [dict get $curDetailRec flow]
  set srcTask [dict get $curDetailRec task]
  set raw     [dict get $curDetailRec raw]

  if {[catch {::wb::lib::requireTclFlows} flowsDir]} {
    tk_messageBox -icon error -title "Clone Task" \
      -message "Cannot resolve flows dir:\n$flowsDir"
    return
  }

  set destFlow [::wb::cfg::cfgBaseName]

  # -- (2) Name algorithm ------------------------------------------------
  set chosenName [::wb::clone::_chooseUniqueTaskName $srcTask]

  # -- (1) Insert cloned task dict after the currently selected task -----
  set clonedTask $raw
  dict set clonedTask name $chosenName
  set afterName $::wb::cfg::curTaskName
  ::wb::cfg::insertTaskAfter $afterName $clonedTask

  # -- (3)/(4)/(5) Create folder, copy + rename files ---------------------
  set srcTaskDir  [file join $flowsDir $srcFlow  tasks $srcTask]
  set destTaskDir [file join $flowsDir $destFlow tasks $chosenName]
  set fileErrs {}
  if {[file isdirectory $srcTaskDir]} {
    if {[catch {file mkdir $destTaskDir} err]} {
      lappend fileErrs "Could not create folder $destTaskDir: $err"
    } else {
      foreach srcFile [glob -nocomplain -directory $srcTaskDir -type f *] {
        set tail     [file tail $srcFile]
        set destTail [::wb::cfg::cloneRenameTaskFile $tail $srcTask $chosenName]
        if {[catch {file copy -force $srcFile [file join $destTaskDir $destTail]} err]} {
          lappend fileErrs "  $tail -> $destTail: $err"
        }
      }
    }
  }

  # -- (6) Refresh the configurator's task list and select the new task --
  ::wb::cfg::uiLoadTasks
  set idx [::wb::cfg::taskIndexByName $chosenName]
  if {$idx >= 0} { ::wb::cfg::taskTvSelect $idx }
  ::wb::cfg::uiSelectTask

  if {[llength $fileErrs] > 0} {
    tk_messageBox -icon warning -title "Clone Task" \
      -message "Task '$chosenName' added to '$destFlow', but some files failed to copy:\n[join $fileErrs \n]"
  } else {
    log "Clone Task: '$srcTask' from '$srcFlow' cloned as '$chosenName' into '$destFlow' (after '$afterName')."
  }

  # -- (6) Close both fs-clone windows ------------------------------------
  ::wb::clone::_closeDetailWindow
  ::wb::clone::closeWindow
}
