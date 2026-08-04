# Generated 2026-jul-30 courtesy of Claude (claude.ai)
# fs-opts.tcl - v19
# Changelog (skinny; full detail in CHANGELOG.md):
#   v19 (2026-jul-30): fixed OK/Cancel buttons getting clipped off the bottom of the Add/Edit Option dialog -- button bar now packed -side bottom first, guaranteed visible regardless of body height; window also taller (720) and resizable
#   v18 (2026-jul-29): added real widgets for custVal (text+file+directory) and readonly (text only, matching actual runtime scope) -- same silent-drop-on-save gap as regexPat/regexMsg, fixed the same way
#   v17 (2026-jul-29): renamed bindVal -> custVal (one example-string mention) -- see CHANGELOG.md for why
#   v16 (2026-jul-29): fixed regexPat/regexMsg silently dropping on save -- added real widgets for text opts, round-trip on Edit, blank-field removal, and regexMsg is discarded without a regexPat
#   v15 (2026-jul-28): changelog moved to CHANGELOG.md; this header now a skinny per-version log
#   v14 (2026-jul-16): _addOptPasteExample no longer touches opt(label) in Edit mode
#   v13: removed Clone Option entirely; fixed radio/select examples never populating Values/Places
#   v12: openOptEditor enlarged (760x660) with scrollable examples panel from production cfg files
#   v11: commitOptAdd/commitOptEdit call itemPanelSetDirty before validateOptions
#   v10: uiLoadOpts delegates to uiLoadOptsGrid (treeview) when present
#   v9: dialog title/height cleanup; file/directory type added; Required checkbox hidden for check/radio/select
#
# FlowSmithy Options module (hived off from wb-cfg)
#
# This file is sourced by fs-cfg.tcl (main configurator).
# It contains the option editor window + option list UI plumbing.

set ::FS_OPTS_VERSION 19
puts stderr "==> Loading fs-opts.tcl (v$::FS_OPTS_VERSION)"

namespace eval ::wb::cfg {
  variable OPTS_VERSION 12
  # Option editor state (owned by wb-opts)
  variable optWin ""
  variable curOptIndex -1
  variable optUI
  array set optUI {}
  variable optErr ""
}

# openOptEditor
#   editIndex: ""      = Add  (blank form)
#              integer = Edit (load existing opt at that index; label locked)
#
# Callers:
#   uiAddItem  -> openOptEditor       (no args  -> Add)
#   uiEditItem -> openOptEditor $idx  (integer  -> Edit)

proc ::wb::cfg::openOptEditor {{editIndex ""}} {
  variable optWin
  variable curTaskName
  variable optUI
  array unset optUI
  array set optUI {}

  if {$curTaskName eq ""} { bell; return }

  if {[winfo exists $optWin]} {
    raise $optWin
    focus $optWin
    return
  }

  set optWin .optEditor
  toplevel $optWin
  wm transient $optWin .
  wm protocol $optWin WM_DELETE_WINDOW ::wb::cfg::closeOptEditor

  # ---- Determine mode and set title ----------------------------------------
  # openMode ""      + editIndex ""  -> Add
  # openMode ""      + editIndex int -> Edit
  set isAdd   0
  set isEdit  0
  if {$editIndex eq ""} {
    set isAdd 1
    wm title $optWin "Add Option - $curTaskName"
  } else {
    set isEdit 1
    wm title $optWin "Edit Option - $curTaskName"
  }

  set optUI(isEdit)    $isEdit
  set optUI(editIndex) [expr {$isEdit ? $editIndex : -1}]
  set optUI(origLabel) ""

  # ---- Load source opt dict (edit) -------------------------------------------
  set od {}
  if {!$isAdd} {
    set task [getTask $curTaskName]
    if {[dict exists $task opts]} {
      set lst [dict get $task opts]
      if {$editIndex >= 0 && $editIndex < [llength $lst]} {
        set od [lindex $lst $editIndex]
        if {[dict exists $od label]} {
          set optUI(origLabel) [dict get $od label]
        }
      }
    }
  }

  # ---- Initialise field variables -------------------------------------------
  if {$isAdd} {
    set ::wb::cfg::opt(type)     "check"
    set ::wb::cfg::opt(label)    ""
    set ::wb::cfg::opt(reqd)     0
    set ::wb::cfg::opt(parm)     ""
    set ::wb::cfg::opt(place)    ""
    set ::wb::cfg::opt(hint)     ""
    set ::wb::cfg::opt(fileType) ""
    set ::wb::cfg::opt(histTag)  ""
    set ::wb::cfg::opt(regexPat) ""
    set ::wb::cfg::opt(regexMsg) ""
    set ::wb::cfg::opt(custVal)  ""
    set ::wb::cfg::opt(readonly) 0
  } else {
    # Edit: preload from od
    set ::wb::cfg::opt(type)     [expr {[dict exists $od type]     ? [dict get $od type]     : "check"}]
    set ::wb::cfg::opt(reqd)     [expr {[dict exists $od reqd]     ? 1 : 0}]
    set ::wb::cfg::opt(parm)     [expr {[dict exists $od parm]     ? [dict get $od parm]     : ""}]
    set ::wb::cfg::opt(place)    [expr {[dict exists $od place]    ? [dict get $od place]    : ""}]
    set ::wb::cfg::opt(hint)     [expr {[dict exists $od hint]     ? [dict get $od hint]     : ""}]
    set ::wb::cfg::opt(fileType) [expr {[dict exists $od fileType] ? [dict get $od fileType] : ""}]
    set ::wb::cfg::opt(histTag)  [expr {[dict exists $od histTag]  ? [dict get $od histTag]  : ""}]
    set ::wb::cfg::opt(label)    [expr {[dict exists $od label] ? [dict get $od label] : ""}]
    # regexPat/regexMsg previously had no widget at all, so editing and
    # saving an option that already had them (e.g. hand-authored in the
    # JSON) would silently drop both on the next Save -- buildOptDict
    # never read them because nothing ever set ::wb::cfg::opt(regexPat/
    # regexMsg) in the first place. Preloading them here is what makes
    # the round trip actually work now that the widgets exist below.
    set ::wb::cfg::opt(regexPat) [expr {[dict exists $od regexPat] ? [dict get $od regexPat] : ""}]
    set ::wb::cfg::opt(regexMsg) [expr {[dict exists $od regexMsg] ? [dict get $od regexMsg] : ""}]
    # custVal/readonly: same previously-missing round trip as
    # regexPat/regexMsg -- e.g. demo-options' CustValDemo field would
    # have had its custVal silently stripped on the next Save without this.
    set ::wb::cfg::opt(custVal)  [expr {[dict exists $od custVal]  ? [dict get $od custVal]  : ""}]
    set ::wb::cfg::opt(readonly) [expr {[dict exists $od readonly] ? 1 : 0}]
  }

  # ---- Position editor centered over parent ---------------------------------
  update idletasks
  set px [winfo rootx .]
  set py [winfo rooty .]
  set pw [winfo width .]
  set ph [winfo height .]
  set ew 760
  set eh 720
  set ex [expr {$px + ($pw - $ew) / 2}]
  set ey [expr {$py + ($ph - $eh) / 2}]
  wm geometry $optWin ${ew}x${eh}+${ex}+${ey}
  wm minsize $optWin 700 500
  wm resizable $optWin 1 1

  # ---- Bottom bar (error label + OK/Cancel) ---------------------------------
  # Packed FIRST, with -side bottom, so Tk reserves its height before
  # anything else claims space. Previously this was created and packed
  # LAST, after $optWin.body and the examples panel -- both of which
  # request "-fill both -expand 1" -- so once the body grew past a
  # certain height (adding regexPat/regexMsg/custVal/readonly pushed it
  # over that point), there was no room left for the button bar at all
  # and it was silently clipped off the bottom of the fixed-size window.
  # Packing it -side bottom first guarantees it's always visible no
  # matter how tall the middle content ends up being.
  frame $optWin.bot
  pack $optWin.bot -side bottom -fill x -padx 10 -pady 6

  label $optWin.bot.err -text "" -anchor w -foreground red
  pack $optWin.bot.err -side left -fill x -expand 1

  # (7) Rounded buttons matching main window style
  ttk::button $optWin.bot.ok -style WbRounded.TButton -text "OK"     -command ::wb::cfg::commitOptSave
  ttk::button $optWin.bot.ca -style WbRounded.TButton -text "Cancel" -command ::wb::cfg::closeOptEditor
  pack $optWin.bot.ca -side right -padx 6
  pack $optWin.bot.ok -side right -padx 6

  # ---- Top grid (Type / Label / Required / Parm / Hint) --------------------
  frame $optWin.top
  pack $optWin.top -fill x -padx 10 -pady 6

  label $optWin.top.tl -text "Type:"
  ttk::combobox $optWin.top.type \
    -values {check text radio select file directory} \
    -textvariable ::wb::cfg::opt(type) -state readonly -width 12
  label $optWin.top.ll -text "Label:"
  entry $optWin.top.le -textvariable ::wb::cfg::opt(label) -width 30
  # Edit mode: label is locked (Add leaves it editable)
  if {$isEdit} {
    $optWin.top.le configure -state disabled
  }
  # Required: only meaningful for text / file / directory
  checkbutton $optWin.top.req -text "Required" -variable ::wb::cfg::opt(reqd)
  label $optWin.top.pl -text "Parm:"
  entry $optWin.top.pe -textvariable ::wb::cfg::opt(parm) -width 30
  label $optWin.top.hl -text "Hint:"
  entry $optWin.top.he -textvariable ::wb::cfg::opt(hint) -width 60

  grid $optWin.top.tl  $optWin.top.type -sticky w -padx 4 -pady 2
  grid $optWin.top.ll  $optWin.top.le   -sticky w -padx 4 -pady 2
  grid $optWin.top.req x                -sticky w -padx 4 -pady 2
  grid $optWin.top.pl  $optWin.top.pe   -sticky w -padx 4 -pady 2
  grid $optWin.top.hl  $optWin.top.he   -sticky w -padx 4 -pady 2

  # Store ref so rebuildOptBody can show/hide the Required row
  set optUI(reqWidget) $optWin.top.req

  # ---- Body frame (rebuilt on type change) ----------------------------------
  frame $optWin.body
  pack $optWin.body -fill both -expand 1 -padx 10 -pady 6

  bind $optWin.top.type <<ComboboxSelected>> ::wb::cfg::rebuildOptBody
  bind $optWin.top.le   <KeyRelease>         ::wb::cfg::validateOptEditor

  rebuildOptBody

  # ---- Populate body text widgets for edit/clone ----------------------------
  if {!$isAdd} {
    set t $::wb::cfg::opt(type)
    if {$t in {"radio" "select"}} {
      if {[dict exists $od values] && [winfo exists $optWin.body.vt]} {
        $optWin.body.vt delete 1.0 end
        foreach v [dict get $od values] { $optWin.body.vt insert end "$v\n" }
      }
      if {[dict exists $od places] && [winfo exists $optWin.body.pt]} {
        $optWin.body.pt delete 1.0 end
        foreach p [dict get $od places] { $optWin.body.pt insert end "$p\n" }
      }
    }
    # place field for check/text/file/directory is textvariable-bound; already set above
  }

  # ---- Examples panel (mirrors Add Parm examples) ---------------------------
  ttk::separator $optWin.exsep -orient horizontal
  pack $optWin.exsep -fill x -padx 10 -pady {6 0}

  frame $optWin.exf -padx 10 -pady 4
  pack  $optWin.exf -fill both -expand 1

  label $optWin.exf.hdr \
    -text "Examples -- click to paste into fields:" \
    -anchor w -font {TkDefaultFont 9 bold}
  pack $optWin.exf.hdr -anchor w -pady {0 2}

  canvas $optWin.exf.c -highlightthickness 0 -bd 0 -height 160
  ttk::scrollbar $optWin.exf.sy -orient vertical -command [list $optWin.exf.c yview]
  $optWin.exf.c configure -yscrollcommand [list $optWin.exf.sy set]
  frame $optWin.exf.c.f
  $optWin.exf.c create window 0 0 -anchor nw -window $optWin.exf.c.f -tags inner

  pack $optWin.exf.sy -side right -fill y
  pack $optWin.exf.c  -side left  -fill both -expand 1

  bind $optWin.exf.c <Configure> {
    %W itemconfigure inner -width [winfo width %W]
    %W configure -scrollregion [list 0 0 [winfo reqwidth %W.f] [winfo reqheight %W.f]]
  }
  bind $optWin.exf.c.f <Configure> {
    set _c [winfo parent %W]
    $_c configure -scrollregion [list 0 0 [winfo reqwidth %W] [winfo reqheight %W]]
  }

  # Store dialog window path so rebuildOptBody can reach the examples panel
  set optUI(optWin) $optWin

  ::wb::cfg::_addOptBuildExamples $optWin $::wb::cfg::opt(type)

  set optUI(okBtn)  $optWin.bot.ok
  set optUI(errLbl) $optWin.bot.err

  validateOptEditor
}



proc ::wb::cfg::closeOptEditor {} {
  variable optWin
  if {[winfo exists $optWin]} {
    destroy $optWin
  }
  set optWin ""
  setOptError ""
}

# -------------------------
# Remove Option
# -------------------------


proc ::wb::cfg::validateOptEditor {} {
  variable opt
  variable optWin

  set lbl [string trim $opt(label)]
  if {$lbl eq ""} {
    setOptError "Label is required."
    return 0
  }

  set existing [existingLabelsForCurrentTask]
  # In edit mode, allow keeping the original label
  if {[info exists ::wb::cfg::optUI(isEdit)] && $::wb::cfg::optUI(isEdit)} {
    if {$lbl eq $::wb::cfg::optUI(origLabel)} {
      set existing [lsearch -all -inline -not -exact $existing $lbl]
    }
  }
  if {[lsearch -exact $existing $lbl] >= 0} {
    setOptError "Duplicate label '$lbl' already exists in this task."
    return 0
  }

  if {$opt(type) in {"radio" "select"}} {
    if {[winfo exists $optWin.body.vt]} {
      set raw [$optWin.body.vt get 1.0 end]
      set vals {}
      foreach line [split $raw "\n"] {
        set v [string trim $line]
        if {$v ne ""} { lappend vals $v }
      }
      if {[llength $vals] == 0} {
        setOptError "At least one value is required."
        return 0
      }
    }
  }

  setOptError ""
  return 1
}

# -------------------------
# Option Editor (ADD)
# -------------------------


proc ::wb::cfg::setOptError {msg} {
  variable optErr
  variable optUI
  set optErr $msg
  if {[info exists optUI(errLbl)] && [winfo exists $optUI(errLbl)]} {
    $optUI(errLbl) configure -text $msg
  }
  if {[info exists optUI(okBtn)] && [winfo exists $optUI(okBtn)]} {
    if {$msg eq ""} {
      $optUI(okBtn) configure -state normal
    } else {
      $optUI(okBtn) configure -state disabled
    }
  }
}



# ---- shared helper: build opt dict from current form fields ----------------
proc ::wb::cfg::buildOptDict {} {
  variable opt
  variable optWin

  set t $opt(type)
  set od [dict create type $t label [string trim $opt(label)]]

  # Required: only stored for text / file / directory
  if {$t in {"text" "file" "directory"} && $opt(reqd)} {
    dict set od reqd true
  }

  if {[string trim $opt(parm)] ne ""} { dict set od parm [string trim $opt(parm)] }
  if {[string trim $opt(hint)] ne ""} { dict set od hint [string trim $opt(hint)] }

  if {$t eq "check"} {
    if {[string trim $opt(place)] ne ""} {
      dict set od place [string trim $opt(place)]
    }

  } elseif {$t eq "text"} {
    if {[string trim $opt(place)] ne ""} {
      dict set od place [string trim $opt(place)]
    }

    # Blank Regex Pattern removes both keys entirely (rather than saving
    # an empty string) -- this is the actual fix for the silent-drop bug:
    # previously neither key was ever written at all, regardless of
    # whether the option already had them; now a genuinely blank field
    # means "remove this", not "value happens to be empty". A Regex
    # Message with no Regex Pattern is meaningless on its own, so it's
    # only saved when a pattern is also present.
    set rp [string trim $opt(regexPat)]
    if {$rp ne ""} {
      dict set od regexPat $rp
      set rm [string trim $opt(regexMsg)]
      if {$rm ne ""} {
        dict set od regexMsg $rm
      }
    }

    # custVal: blank removes the key, same convention as regexPat above.
    set cv [string trim $opt(custVal)]
    if {$cv ne ""} {
      dict set od custVal $cv
    }

    # readonly: boolean flag, only written when true (omit the key
    # entirely when false -- same convention "reqd" already uses, not a
    # literal "false" value sitting in the JSON).
    if {$opt(readonly)} {
      dict set od readonly true
    }

  } elseif {$t in {"file" "directory"}} {
    if {[string trim $opt(place)]    ne ""} { dict set od place    [string trim $opt(place)]    }
    if {[string trim $opt(fileType)] ne ""} { dict set od fileType [string trim $opt(fileType)] }
    if {[string trim $opt(histTag)]  ne ""} { dict set od histTag  [string trim $opt(histTag)]  }

    # custVal applies to file/directory too (fs-run.tcl validates it in
    # the same shared switch case as text) -- readonly does not (runtime
    # only checks it for text), so it's intentionally not saved here.
    set cv [string trim $opt(custVal)]
    if {$cv ne ""} {
      dict set od custVal $cv
    }

  } else {
    # radio / select
    set raw [$optWin.body.vt get 1.0 end]
    set vals {}
    foreach line [split $raw "\n"] {
      set v [string trim $line]
      if {$v ne ""} { lappend vals $v }
    }
    dict set od values $vals

    set rawp [$optWin.body.pt get 1.0 end]
    set pls {}
    foreach line [split $rawp "\n"] {
      set p [string trim $line]
      if {$p ne ""} { lappend pls $p }
    }
    if {[llength $pls] > 0} { dict set od places $pls }
  }

  return $od
}

proc ::wb::cfg::commitOptAdd {} {
  variable curTaskName
  variable optWin

  if {![validateOptEditor]} { bell; return }

  set od [::wb::cfg::buildOptDict]

  set task [getTask $curTaskName]
  if {[dict exists $task opts]} {
    dict set task opts [concat [dict get $task opts] [list $od]]
  } else {
    dict set task opts [list $od]
  }
  setTask $curTaskName $task

  log "Added option '[dict get $od label]' to task '$curTaskName'"
  closeOptEditor
  uiLoadOpts
  ::wb::cfg::itemPanelSetDirty
  ::wb::cfg::validateOptions
}



proc ::wb::cfg::commitOptSave {} {
  variable optUI
  if {[info exists optUI(isEdit)] && $optUI(isEdit)} {
    ::wb::cfg::commitOptEdit
  } else {
    ::wb::cfg::commitOptAdd
  }
}

proc ::wb::cfg::commitOptEdit {} {
  variable curTaskName
  variable optWin
  variable optUI

  if {![validateOptEditor]} { bell; return }
  if {![info exists optUI(editIndex)] || $optUI(editIndex) < 0} {
    setOptError "Edit: no option selected."
    bell
    return
  }

  set od [::wb::cfg::buildOptDict]

  set task [getTask $curTaskName]
  if {![dict exists $task opts]} {
    setOptError "Edit: task has no opts."
    bell
    return
  }
  set lst [dict get $task opts]
  if {$optUI(editIndex) >= [llength $lst]} {
    setOptError "Edit: option index out of range."
    bell
    return
  }
  set lst [lreplace $lst $optUI(editIndex) $optUI(editIndex) $od]
  dict set task opts $lst
  setTask $curTaskName $task

  log "Edited option '[dict get $od label]' in task '$curTaskName'"
  closeOptEditor
  uiLoadOpts
  ::wb::cfg::itemPanelSetDirty
  ::wb::cfg::validateOptions
}

proc ::wb::cfg::formatOptLine {od} {
  set t [dict get $od type]
  set l [dict get $od label]
  set parts [list "$t:$l"]

  if {[dict exists $od reqd] && [string tolower [dict get $od reqd]] in {"true" "1" "yes"}} {
    lappend parts "REQD"
  }
  if {[dict exists $od parm] && [string trim [dict get $od parm]] ne ""} {
    lappend parts "parm=[dict get $od parm]"
  }

  if {$t in {"check" "text"}} {
    if {[dict exists $od place] && [string trim [dict get $od place]] ne ""} {
      lappend parts "place=[dict get $od place]"
    }
  } elseif {$t in {"file" "directory"}} {
    if {[dict exists $od place]    && [string trim [dict get $od place]]    ne ""} { lappend parts "place=[dict get $od place]"    }
    if {[dict exists $od fileType] && [string trim [dict get $od fileType]] ne ""} { lappend parts "fileType=[dict get $od fileType]" }
    if {[dict exists $od histTag]  && [string trim [dict get $od histTag]]  ne ""} { lappend parts "histTag=[dict get $od histTag]"  }
  } elseif {$t in {"radio" "select"}} {
    if {[dict exists $od values]} {
      set raw [dict get $od values]
      set vals {}
      foreach v $raw { lappend vals [stripStar $v] }
      set def [findDefaultValue $raw]
      lappend parts "vals=[trimJoin $vals 70]"
      if {$def ne ""} { lappend parts "def=$def" }
    }
    if {[dict exists $od places]} {
      set pls [dict get $od places]
      lappend parts "places=[llength $pls]"
    }
  }
  return [join $parts "  "]
}

# -------------------------
# UI helpers (main)
# -------------------------


proc ::wb::cfg::rebuildOptBody {} {
  variable optWin
  variable opt
  variable optUI

  foreach c [winfo children $optWin.body] { destroy $c }

  set t $opt(type)

  # (4) Required checkbox: only relevant for text / file / directory.
  # For check it is always on; for radio/select the default field implies it.
  if {[info exists optUI(reqWidget)] && [winfo exists $optUI(reqWidget)]} {
    if {$t in {"text" "file" "directory"}} {
      grid $optUI(reqWidget)
    } else {
      grid remove $optUI(reqWidget)
    }
  }

  if {$t eq "check"} {
    label $optWin.body.l -text "Place:"
    entry $optWin.body.e -textvariable ::wb::cfg::opt(place) -width 58
    pack $optWin.body.l -anchor w
    pack $optWin.body.e -fill x

  } elseif {$t eq "text"} {
    label $optWin.body.l -text "Place:"
    entry $optWin.body.e -textvariable ::wb::cfg::opt(place) -width 58
    pack $optWin.body.l -anchor w
    pack $optWin.body.e -fill x

    # Regex Pattern / Regex Message: previously documented (see
    # fs-cfg-task-options-help.md) but never had actual widgets here --
    # an option authored by hand with these keys would have them
    # silently stripped on the next Save, since nothing read them into
    # ::wb::cfg::opt(...) and buildOptDict had nothing to save. Blank
    # either field to remove that key entirely (see buildOptDict);
    # leaving Regex Message blank with a Regex Pattern set is fine --
    # the engine falls back to a generic "regex failed" message.
    label $optWin.body.rpl -text "Regex Pattern (optional, validates this field before the task can run):"
    entry $optWin.body.rpe -textvariable ::wb::cfg::opt(regexPat) -width 58
    label $optWin.body.rml -text "Regex Message (optional, shown on failure -- blank = generic \"regex failed\"):"
    entry $optWin.body.rme -textvariable ::wb::cfg::opt(regexMsg) -width 58
    pack $optWin.body.rpl -anchor w -pady {8 0}
    pack $optWin.body.rpe -fill x
    pack $optWin.body.rml -anchor w -pady {8 0}
    pack $optWin.body.rme -fill x

    # custVal: names a custom validation hook proc in ::wb::opt::hook::,
    # invoked at validation time (see fs-cfg-task-options-help.md's
    # "custVal" section, and demo-options' CustValDemo field for a real
    # example). Same silent-drop-on-Save gap as regexPat/regexMsg had --
    # fixed the same way: blank to remove.
    label $optWin.body.cvl -text "Custom Validation Hook (optional, proc name in ::wb::opt::hook::):"
    entry $optWin.body.cve -textvariable ::wb::cfg::opt(custVal) -width 58
    pack $optWin.body.cvl -anchor w -pady {8 0}
    pack $optWin.body.cve -fill x

    # readonly: makes the field non-editable at runtime (real behavior,
    # not cosmetic -- see fs-objs.tcl's uiRender, which disables the
    # entry widget and grays its background when this is set). Runtime
    # support currently exists for "text" only -- file/directory never
    # check this flag -- so the checkbox is scoped to match, rather than
    # offering a control that would silently do nothing for those types.
    checkbutton $optWin.body.ro -text "Read-only (value set entirely by a hook or bindVal-style computation, not typed by the user)" \
        -variable ::wb::cfg::opt(readonly)
    pack $optWin.body.ro -anchor w -pady {8 0}

  } elseif {$t in {"file" "directory"}} {
    # (5) file / directory: Place + optional fileType + optional histTag
    label $optWin.body.pl  -text "Place:"
    entry $optWin.body.pe  -textvariable ::wb::cfg::opt(place)    -width 58
    label $optWin.body.ftl -text "File Type (optional, e.g. {{JSON files} {.json}} {All files} *):"
    entry $optWin.body.fte -textvariable ::wb::cfg::opt(fileType) -width 58
    label $optWin.body.htl -text "Hist Tag (optional, history key for file browser):"
    entry $optWin.body.hte -textvariable ::wb::cfg::opt(histTag)  -width 58
    pack $optWin.body.pl  -anchor w -pady {4 0}
    pack $optWin.body.pe  -fill x
    pack $optWin.body.ftl -anchor w -pady {8 0}
    pack $optWin.body.fte -fill x
    pack $optWin.body.htl -anchor w -pady {8 0}
    pack $optWin.body.hte -fill x

    # custVal validates for file/directory too (fs-run.tcl's
    # validateOptions shares one switch case across text/file/directory),
    # so it belongs here as well, not just on the text body above.
    label $optWin.body.cvl -text "Custom Validation Hook (optional, proc name in ::wb::opt::hook::):"
    entry $optWin.body.cve -textvariable ::wb::cfg::opt(custVal) -width 58
    pack $optWin.body.cvl -anchor w -pady {8 0}
    pack $optWin.body.cve -fill x

  } else {
    # radio / select: values list + places list
    label $optWin.body.vl -text "Values (one per line, * = default):"
    text  $optWin.body.vt -height 6 -width 58
    label $optWin.body.pl -text "Places (optional, one per line):"
    text  $optWin.body.pt -height 6 -width 58
    pack $optWin.body.vl -anchor w
    pack $optWin.body.vt -fill both -expand 1
    pack $optWin.body.pl -anchor w -pady 4
    pack $optWin.body.pt -fill both -expand 1

    bind $optWin.body.vt <KeyRelease> ::wb::cfg::validateOptEditor
  }

  validateOptEditor

  # Rebuild examples panel for the new type (optUI(optWin) set by openOptEditor)
  if {[info exists optUI(optWin)] && [winfo exists $optUI(optWin)]} {
    ::wb::cfg::_addOptBuildExamples $optUI(optWin) $t
  }
}



proc ::wb::cfg::uiLoadOpts {} {
  variable ui
  variable curTaskName
  variable curOptIndex

  # Prefer the treeview grid (v79+); fall back to legacy listbox
  if {[info commands ::wb::cfg::uiLoadOptsGrid] ne ""} {
    ::wb::cfg::uiLoadOptsGrid
    return
  }

  $ui(optsList) delete 0 end
  set curOptIndex -1

  if {$curTaskName eq ""} {
    $ui(optsList) insert end "(no task selected)"
    return
  }

  set task [getTask $curTaskName]
  if {![dict exists $task opts]} {
    $ui(optsList) insert end "(no opts)"
    return
  }

  foreach od [dict get $task opts] {
    $ui(optsList) insert end [formatOptLine $od]
  }
}



proc ::wb::cfg::uiSelectOpt {} {
  variable ui
  variable curOptIndex
  set sel [$ui(optsList) curselection]
  if {$sel eq ""} {
    set curOptIndex -1
  } else {
    set curOptIndex [lindex $sel 0]
  }
  uiUpdateOptButtons
}



proc ::wb::cfg::uiUpdateOptButtons {} {
  variable ui
  variable curOptIndex
  if {$curOptIndex < 0} {
    $ui(btnRemove) configure -state disabled
  } else {
    $ui(btnRemove) configure -state normal
  }
}

# -------------------------
# Add Option editor: validation helpers
# -------------------------


proc ::wb::cfg::uiRemoveOption {} {
  variable curTaskName
  variable curOptIndex

  if {$curOptIndex < 0} { bell; return }

  set task [getTask $curTaskName]
  set opts [dict get $task opts]
  set od [lindex $opts $curOptIndex]
  set label [dict get $od label]

  set rc [tk_messageBox -type yesno -icon question \
    -message "Remove option '$label' from task '$curTaskName'?"]
  if {$rc ne "yes"} { return }

  set opts [lreplace $opts $curOptIndex $curOptIndex]
  if {[llength $opts] == 0} {
    dict unset task opts
  } else {
    dict set task opts $opts
  }
  setTask $curTaskName $task
  log "Removed option '$label'"
  uiLoadOpts
  uiUpdateOptButtons
}

# -------------------------
# Save / Close
# -------------------------


# -------------------------
# Examples panel procs (v12)
# Mirrors the Add Parm examples approach in fs-cfg.tcl.
# -------------------------

# ---------------------------------------------------------------------------
# _optTypeDesc  type
# One-line description shown as a hint in the type-change tooltip area.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_optTypeDesc {type} {
  switch -- $type {
    check     { return "check -- checkbox; optional parm passed as boolean flag when checked" }
    text      { return "text -- free-text entry; validate with regexPat, require with reqd" }
    radio     { return "radio -- mutually exclusive buttons; prefix value with * for default" }
    select    { return "select -- combobox choice; prefix value with * for default; dyn: for runtime lists" }
    file      { return "file -- file-picker; add fileType for filter, histTag for history" }
    directory { return "directory -- folder-picker; add histTag for history" }
    default   { return "" }
  }
}

# ---------------------------------------------------------------------------
# _optTypeExamples  type
# Returns list of {header fields comment} triples.
# fields is a flat dict (key value ...) of form fields to pre-fill on click.
# Sections are introduced by a non-empty header string.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_optTypeExamples {type} {
  switch -- $type {

    check {
      return {
        {"No parm -- UI-only (drives parms processor via tern/eval)"
             {label noparm  place "configure runtime"}
             "result used in parm tern/eval; not passed directly to program"}
        {"" {label server  place "Check for prod server, else development"}
             "server-mode switch consumed by tern: parms"}
        {"" {label prod  hint "Check to read from production server"  place "Check to use production server"}
             "production flag (no parm)"}
        {"Passed as boolean parm to program"
             {label trial  parm trial  hint "When checked, simulates run"  place "Check to simulate run"}
             "simulation guard"}
        {"" {label emit  parm emit  hint "When checked, Excel output files are created"  place "Check to emit Excel files"}
             "emit gate"}
        {"" {label apply  parm apply  hint "When activated, will write transactions to server"  place "Apply to server"}
             "write gate"}
        {"" {label refresh  parm refresh  hint "When activated, connects and downloads records"  place "Refresh cache"}
             "cache refresh trigger"}
        {"" {label show  parm show  place "Show transactions in log"}
             "diagnostic show flag"}
        {"" {label save  parm save  hint "Creates a backup copy of the local_db.bin"  place "Backup local_db.bin"}
             "backup flag"}
        {"" {label stop  parm stop  hint "Stops the server, no restart cycle"  place "Stop server"}
             "server stop flag"}
        {"" {label cold  parm cold  hint "Make server do cold start (new deploy)"  place "Cold start server"}
             "cold-start flag"}
        {"Manual step acknowledgement (no parm)"
             {label step-1  hint "Click when completed then press Run Task"  place "Download bank transactions"}
             "manual step completion gate"}
        {"" {label step-2  place "Confirm local GAEL Web Server running"}
             "second manual step gate"}
      }
    }

    text {
      return {
        {"Optional free-text parm"
             {label genstr  parm genstr  hint "Content of generated lines"  place "string to generate"}
             "optional, blank OK"}
        {"Required text parm"
             {label datestr  parm datestr  hint "Mandatory string test"  place "must have value"}
             "Apply blocked until filled"}
        {"Required integer (regex validated)"
             {label gen  parm gen  hint "number of lines to generate"  place "number lines"}
             "integer-only; set regexPat to ^[0-9]*$"}
        {"Optional integer with custom error message"
             {label loops  parm loops  hint "The number of script loops"  place "script loops"}
             "blank OK; set regexPat ^[0-9]*$ and regexMsg 'Not integer'"}
        {"" {label delay  parm delay  hint "The delay in seconds"  place "delay seconds"}
             "optional integer delay"}
        {"Namespace / short identifier"
             {label SourceNS  parm srcns  hint "Namespace to fetch from"  place "fetch namespace"}
             "short string passed as parm"}
        {"" {label TargetNS  parm targns  hint "Namespace to write into becuDir with"  place "write namespace"}
             "target namespace"}
        {"Comma-separated ID list"
             {label watch  parm watch  hint "Trans IDs to watch (, separated list)"  place "Tranids to watch"}
             "comma-list of IDs"}
        {"Readonly bound field (computed by other controls)"
             {label custfld  parm custfld  hint "Value set programmatically from other controls"  place "supply validated value depends on other controls"}
             "set readonly and custVal in JSON manually after Add"}
      }
    }

    radio {
      return {
        {"Two choices, first is default (prefix *)"
             {label action  parm action  hint "Set the operation"
              values {*start recycle stop}  places {{Start server} {Recycle Server} {Stop Server}}}
             "values: [*start recycle stop]  places: [Start server Recycle Server Stop Server]"}
        {"" {label action  parm action  hint "Controls how the script behaves"
              values {*GOOD FAIL TRAP}  places {{normal completion} {failed completion} Traps}}
             "values: [*GOOD FAIL TRAP]  places: [normal completion failed completion Traps]"}
        {"" {label what  hint "Select what to generate"
              values {*citc gael-core}  places {{CIT code} {Gael-core code}}}
             "values: [*citc gael-core]  places: [CIT code Gael-core code]"}
        {"" {label action  parm action  hint "Controls replace/add/remove"
              values {*rep add-rep del}  places {replace {add or replace} remove}}
             "values: [*rep add-rep del]  places: [replace {add or replace} remove]"}
        {"Three choices, no default (user must choose)"
             {label trap  parm trap  hint "Controls how the program behaves"
              values {{no trap} fail trap}  places {normal {gen FAIL} {gen TRAP}}}
             "values: [{no trap} fail trap]  places: [normal {gen FAIL} {gen TRAP}]"}
        {"Numeric values with default"
             {label radio1  parm radio1  hint "Mutually exclusive numeric choice"
              values {*100 200 300}  places {{value 100 (default)} {value 200} {value 300}}}
             "values: [*100 200 300]  places: [{value 100 (default)} {value 200} {value 300}]"}
        {"Numeric values, no default"
             {label radio2  parm radio2
              values {500 600 700}  places {{nd 500} {nd 600} {nd 700}}}
             "values: [500 600 700]  places: [{nd 500} {nd 600} {nd 700}]"}
      }
    }

    select {
      return {
        {"Year selector with default (prefix *)"
             {label year  hint "Set the processing year"
              values {2025 *2026 2027 2028}}
             "values: [2025 *2026 2027 2028]  (no places needed for bare values)"}
        {"Month selector with display names"
             {label month  hint "Select the processing month"
              values {1 2 3 4 5 6 7 8 9 10 11 12}
              places {January February March April May June July August September October November December}}
             "values: [1 2 3 ... 12]  places: [January February ... December]"}
        {"Simple string values passed to program"
             {label combo  parm combo  hint "Select output mode"
              values {green red blue}  places {green {show red} {show blue}}}
             "values: [green red blue]  places: [green {show red} {show blue}]"}
        {"Required with default (first pre-selected)"
             {label select1  hint "Choose format variant"
              values {*v1 v2 v3}  places {{value v1} {value v2} {value v3}}}
             "values: [*v1 v2 v3]  places: [{value v1} {value v2} {value v3}]"}
        {"Optional, no default"
             {label select2  parm select2  hint "Optional variant selector"
              values {z1 z2 z3}  places {{value z1} {value z2} {value z3}}}
             "values: [z1 z2 z3]  places: [{value z1} {value z2} {value z3}]"}
        {"Dynamic list from glob (dyn:) -- values and places left blank"
             {label server  hint "Set the server"}
             "values: dyn:~servers  places: dyn:~serv-names  (edit JSON manually for dyn: syntax)"}
      }
    }

    file {
      return {
        {"Basic file picker (no filter, no history)"
             {label file1  hint "Shows a file control"  place "Basic file control, no history"}
             "plain file picker"}
        {"With file type filter"
             {label file2  hint "Shows a file control with file types"  place "Basic file with types, no history"}
             "set fileType to *.exe  (edit field below)"}
        {"With filter and history (recommended)"
             {label file3  hint "File control with types and history"  place "File control with types and history"}
             "set fileType to wb*.tcl;*.png  histTag to demo-tag"}
        {"JSON spec file with history"
             {label JsonExec  parm jsonexec  hint "Fetch specification"  place "Fetch specification"}
             "set histTag to becu-exec"}
      }
    }

    directory {
      return {
        {"Basic directory picker (no history)"
             {label dir1  hint "Shows a directory control"  place "Basic directory control, no history"}
             "plain directory picker"}
        {"With history tag (recommended)"
             {label dir2  hint "Directory control with history"  place "Directory control with history"}
             "set histTag to demo-tag"}
        {"Read/Write location with parm and history"
             {label becudir  parm becudir  hint "Read/Write location"  place "Read/Write location"}
             "set histTag to becu-folder"}
      }
    }

    default { return {} }
  }
}

# ---------------------------------------------------------------------------
# _addOptBuildExamples  dlgWin  type
# Populates the scrollable examples frame inside the opt editor.
# Each row is clickable and calls _addOptPasteExample to pre-fill fields.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_addOptBuildExamples {w type} {
  set f $w.exf.c.f
  if {![winfo exists $f]} { return }
  foreach child [winfo children $f] { destroy $child }

  set examples [::wb::cfg::_optTypeExamples $type]
  set row 0

  foreach ex $examples {
    lassign $ex header fields comment

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

    # Build display string from the fields dict (values/places excluded --
    # they can be long lists now that they're real fields, and the
    # comment already gives a compact human summary of them)
    set dispParts {}
    foreach {k v} $fields {
      if {$k in {values places}} { continue }
      lappend dispParts "$k: $v"
    }
    set disp [join $dispParts "  "]

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
    bind $f.ex$row <Button-1> [list ::wb::cfg::_addOptPasteExample $w $fields]

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
# _addOptPasteExample  dlgWin  fields
# fields is a flat Tcl dict (key value ...) from the examples table.
# Fills the corresponding ::wb::cfg::opt() variables and refreshes the body.
#
# Every field this dialog can show is set here, one way or another: fields
# present in the clicked example are pasted in, fields absent from it are
# cleared. Without that, clicking example A (which sets parm/place) and
# then example B (which doesn't mention parm/place) would leave A's values
# sitting in B's fields -- fields handled: label parm hint place histTag
# fileType reqd, plus the values/places text widgets for radio/select.
# ---------------------------------------------------------------------------
proc ::wb::cfg::_addOptPasteExample {w fields} {
  variable optUI

  # Scalar opt() fields -- set if present, cleared if not. Label is
  # excluded in Edit mode: the Label entry is locked there (you can't
  # rename an existing option this way), so an example shouldn't
  # silently change the underlying value even though the widget itself
  # already prevents showing it.
  set scalarFields {label parm hint place histTag fileType}
  if {[info exists optUI(isEdit)] && $optUI(isEdit)} {
    set scalarFields {parm hint place histTag fileType}
  }
  foreach field $scalarFields {
    if {[dict exists $fields $field]} {
      set ::wb::cfg::opt($field) [dict get $fields $field]
    } else {
      set ::wb::cfg::opt($field) ""
    }
  }

  # Required checkbox -- same clear-if-absent treatment.
  if {[dict exists $fields reqd]} {
    set ::wb::cfg::opt(reqd) [dict get $fields reqd]
  } else {
    set ::wb::cfg::opt(reqd) 0
  }

  # Values / Places text widgets (radio / select only) -- always clear
  # first, then paste in this example's lists if it has any. A dyn:-style
  # example that intentionally omits values/places (told to edit JSON
  # manually) correctly leaves both boxes empty.
  if {[winfo exists $w.body.vt]} {
    $w.body.vt delete 1.0 end
    if {[dict exists $fields values]} {
      foreach v [dict get $fields values] { $w.body.vt insert end "$v\n" }
    }
  }
  if {[winfo exists $w.body.pt]} {
    $w.body.pt delete 1.0 end
    if {[dict exists $fields places]} {
      foreach p [dict get $fields places] { $w.body.pt insert end "$p\n" }
    }
  }

  # Focus the label entry if it exists
  if {[winfo exists $w.top.le]} {
    focus $w.top.le
  }

  ::wb::cfg::validateOptEditor
}

# Compatibility alias (older wb-cfg versions may call uiLoadOpts unqualified)

proc uiLoadOpts {} { ::wb::cfg::uiLoadOpts }