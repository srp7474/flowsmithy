# Code generated on 2026-Feb-12 20:22  courtesy of chatGPT
# tcl-devp.tcl (v17) - DevP test GUI (copy-friendly errors). Run with:
# Changelog (skinny; full detail in CHANGELOG.md):
#   v17 (2026-jul-28): changelog moved to CHANGELOG.md; this header now a skinny per-version log
#   v16 (2026-jul-17): readJsonFile now sets -encoding utf-8 on read, matching tcl-lib.tcl's fix
#   tclsh tcl-devp.tcl <work-dir>
# If Tk isn't available under tclsh, run:
#   wish  tcl-devp.tcl <work-dir>

set ::WB_TCL_DEVP_VERSION "17"
puts "==> Loading tcl-devp.tcl (v$::WB_TCL_DEVP_VERSION)"

# Ensure tcl-lib is loaded (for ::wb::lib::* JSON helpers)
if {![info exists ::WB_TCL_LIB_VERSION]} {
  set _devp_dir [file dirname [file normalize [info script]]]
  set _wb_lib [file join $_devp_dir "tcl-lib.tcl"]
  if {[file exists $_wb_lib]} {
    source $_wb_lib
  } else {
    puts stderr "WARNING: tcl-lib.tcl not found at: $_wb_lib"
  }
}


namespace eval ::wb::devp {}
set ::wb::devp::workDir ""

proc ::wb::devp::_copyTextWidget {wText} {
  if {[winfo exists $wText]} {
    set s [$wText get 1.0 end]
    clipboard clear
    clipboard append $s
  }
}

proc ::wb::devp::_errTextWin {title msg} {
  # Copy-friendly error dialog (text box + Copy button)
  set w .err[clock clicks]
  toplevel $w
  wm title $w $title
  wm geometry $w 900x500

  frame $w.f -padx 10 -pady 10
  pack $w.f -fill both -expand 1

  label $w.f.h -text $title -font "TkDefaultFont 12 bold" -anchor w
  text  $w.f.t -wrap none -height 20
  scrollbar $w.f.sy -orient vertical   -command "$w.f.t yview"
  scrollbar $w.f.sx -orient horizontal -command "$w.f.t xview"
  $w.f.t configure -yscrollcommand "$w.f.sy set" -xscrollcommand "$w.f.sx set"

  frame $w.f.bot
  button $w.f.bot.copy  -text "1) Copy"  -command [list ::wb::devp::_copyTextWidget $w.f.t]
  button $w.f.bot.close -text "2) Close" -command [list destroy $w]

  # grid-only inside $w.f
  grid $w.f.h   -row 0 -column 0 -columnspan 3 -sticky we -pady {0 8}
  grid $w.f.t   -row 1 -column 0 -sticky nsew
  grid $w.f.sy  -row 1 -column 1 -sticky ns
  grid $w.f.sx  -row 2 -column 0 -sticky ew
  grid $w.f.bot -row 3 -column 0 -columnspan 3 -sticky e -pady {10 0}

  pack $w.f.bot.copy  -side right
  pack $w.f.bot.close -side right -padx 8

  grid columnconfigure $w.f 0 -weight 1
  grid rowconfigure    $w.f 1 -weight 1

  $w.f.t insert end $msg
  $w.f.t mark set insert 1.0
  $w.f.t see 1.0
  focus -force $w.f.t
}


proc ::wb::devp::_errWait {title msg} {
  puts stderr $msg
  if {[catch {package require Tk}]} {
    puts stderr "Tk not available; cannot show GUI error dialog."
    return
  }
  ::wb::devp::_errTextWin $title $msg
}

proc ::wb::devp::_showTextWin {title text} {
  set w .show[clock clicks]
  toplevel $w
  wm title $w $title
  wm geometry $w 900x650

  text $w.t -wrap none
  scrollbar $w.sy -orient vertical -command "$w.t yview"
  scrollbar $w.sx -orient horizontal -command "$w.t xview"
  $w.t configure -yscrollcommand "$w.sy set" -xscrollcommand "$w.sx set"

  grid $w.t  -row 0 -column 0 -sticky nsew
  grid $w.sy -row 0 -column 1 -sticky ns
  grid $w.sx -row 1 -column 0 -sticky ew
  grid columnconfigure $w 0 -weight 1
  grid rowconfigure    $w 0 -weight 1

  $w.t insert end $text
  $w.t configure -state disabled
}

proc ::wb::devp::_pathTestJson {} {
  return [file join $::wb::devp::workDir "test-json.json"]
}

# (6) Read file test-json.json into a JSON object (raw JSON string)
proc ::wb::devp::readJsonFile {} {
  set path [::wb::devp::_pathTestJson]
  if {![file exists $path]} {
    error "readJsonFile: file not found: $path"
  }
  set fh [open $path r]
  fconfigure $fh -encoding utf-8
  set s [read $fh]
  close $fh
  if {[string trim $s] eq ""} {
    error "readJsonFile: empty JSON file: $path"
  }
  return $s
}

# (7) Read JSON file, pretty-print, show in window
proc ::wb::devp::showJsonObjStringified {} {
  if {[catch {
    set obj [::wb::devp::readJsonFile]
    set pretty [::wb::lib::jsonObjAsPrettyStr $obj 1]
    ::wb::devp::_showTextWin "JSON object Stringified" $pretty
  } err]} {
    ::wb::devp::_errWait "JSON Test Failed" $err
  }
}

# (8) Read JSON file into dict entry using tcl-lib jsonFileAsDict
proc ::wb::devp::readJsonFileAsDict {} {
  if {[catch {
    set d [::wb::lib::jsonFileAsDict [::wb::devp::_pathTestJson]]
    # Show keys *and* values (one per line) to make dict content visible.
    set out ""
    foreach k [dict keys $d] {
      # Use list to preserve spaces/control chars in the rendered string.
      set v [dict get $d $k]
      append out "$k => $v\n"
    }
    ::wb::devp::_showTextWin "Dict Entry" $out
  } err]} {
    ::wb::devp::_errWait "Dict Test Failed" $err
  }
}

# (9) Dict -> JSON obj -> pretty -> show
proc ::wb::devp::showDictObjStringified {} {
  if {[catch {
    set d [::wb::lib::jsonFileAsDict [::wb::devp::_pathTestJson]]
    set obj [::wb::lib::dictAsJsonObj $d]
    set pretty [::wb::lib::jsonObjAsPrettyStr $obj 1]
    ::wb::devp::_showTextWin "Dict entry object Stringified" $pretty
  } err]} {
    ::wb::devp::_errWait "Dict->JSON Test Failed" $err
  }
}

# Replacement: prettier, flatter, left-justified buttons (ttk)
proc ::wb::devp::main {workDirArg} {
  if {[catch {package require Tk} tkErr]} {
    puts stderr "ERROR: Tk not available. Try running with wish.exe instead of tclsh.exe"
    puts stderr "Tk error: $tkErr"
    return
  }

  # Make ttk explicit
  catch {package require Ttk}

  set ::wb::devp::workDir [file normalize $workDirArg]
  log "Devp work-dir: $::wb::devp::workDir"
  log "Devp test-json : [::wb::devp::_pathTestJson]"

  wm title . "WB Devp (v$::WB_TCL_DEVP_VERSION)"
  wm geometry . 520x560

  # Close main window cleanly (stop vwait)
  wm protocol . WM_DELETE_WINDOW {
    set ::wb::devp::done 1
    destroy .
  }

  # ---- ttk style for "flat-ish" left-justified buttons ----
  # Notes:
  # - ttk doesn't truly do rounded corners in classic Tk; this is "flatter/2D" + better padding.
  # - Relief is controlled by style; we keep it flat.
  set s Devp.TButton
  ttk::style configure $s \
    -padding {10 7} \
    -anchor w
  ttk::style map $s \
    -relief {pressed flat active flat !active flat}

  # Layout
  frame .p -padx 12 -pady 12
  pack .p -fill both -expand 1

  label .p.h  -text "Devp Test Panel" -font "TkDefaultFont 12 bold"
  label .p.wd -text "work-dir: $::wb::devp::workDir" -anchor w

  # ---- JSON file select (all *.json in workDir) ----
  # Stores selection in ::wb::devp::selJson (full path)
  set ::wb::devp::jsonFiles [lsort -dictionary [glob -nocomplain -directory $::wb::devp::workDir *.json]]
  if {[llength $::wb::devp::jsonFiles] > 0} {
    set ::wb::devp::selJson [lindex $::wb::devp::jsonFiles 0]
  } else {
    set ::wb::devp::selJson ""
  }

  frame .p.js
  label .p.js.l -text "json:" -anchor w
  ttk::combobox .p.js.cb -state readonly -textvariable ::wb::devp::selJson \
    -values $::wb::devp::jsonFiles -width 52

  grid .p.js.l  -row 0 -column 0 -sticky w
  grid .p.js.cb -row 0 -column 1 -sticky we -padx 6
  grid columnconfigure .p.js 1 -weight 1
  # -----------------------------------------------

  # Updated buttons (ttk + left-justified)
  ttk::button .p.b6  -text "1. jsonFile --> Dict View"              -style $s -command ::wb::devp::jsonFileToDictView
  ttk::button .p.b7  -text "2. jsonFile --> dict --> prettyJson"    -style $s -command ::wb::devp::showDictAsPrettyJsonStr
  ttk::button .p.b8  -text "3) jsonFileAsDict (dict entry)"         -style $s -command ::wb::devp::readJsonFileAsDict
  ttk::button .p.b9  -text "4) Dict entry object Stringified"       -style $s -command ::wb::devp::showDictObjStringified

  label .p.h2 -text "============ cosmos tests ==========" -font "TkDefaultFont 10"

  ttk::button .p.b10 -text "5) Show Cosmos Dict (pretty JSON)"      -style $s -command ::wb::devp::showCosmosDict
  ttk::button .p.b11 -text "6) Save Cosmos Dict"                    -style $s -command ::wb::devp::saveCosmosDict
  ttk::button .p.b12 -text "7) Save Cosmos List (5 entries)"        -style $s -command ::wb::devp::saveCosmosList
  ttk::button .p.b13 -text "8) Show Cosmos List (pretty JSON)"      -style $s -command ::wb::devp::showCosmosList

  grid .p.h  -row 0 -column 0 -sticky w
  grid .p.wd -row 1 -column 0 -sticky we -pady 8
  grid .p.js -row 2 -column 0 -sticky we -pady 4

  # Make buttons stretch to fill width, keep text left
  grid .p.b6  -row 3  -column 0 -sticky we -pady 4
  grid .p.b7  -row 4  -column 0 -sticky we -pady 4
  grid .p.b8  -row 5  -column 0 -sticky we -pady 4
  grid .p.b9  -row 6  -column 0 -sticky we -pady 4
  grid .p.h2  -row 7  -column 0 -sticky w  -pady 4

  grid .p.b10 -row 8  -column 0 -sticky we -pady 4
  grid .p.b11 -row 9  -column 0 -sticky we -pady 4
  grid .p.b12 -row 10 -column 0 -sticky we -pady 4
  grid .p.b13 -row 11 -column 0 -sticky we -pady 4

  grid columnconfigure .p 0 -weight 1

  raise .
  focus -force .
}

# Button 1) entrypoint: read selected JSON -> dict -> nested view text window
proc ::wb::devp::jsonFileToDictView {} {
  set d [::wb::devp::selectedJsonFileToDict]
  if {$d eq ""} { return } ;# helper already showed UI error

  
  set s ""
  append s "File: [file tail $::wb::devp::selJson]\n"
  append s "Path: $::wb::devp::selJson\n"
  append s "------------------------------------------------------------\n"
  append s [::wb::devp::_dictToTreeStr $d 0]
  append s "\n"

  ::wb::devp::_showTextWin [file tail $::wb::devp::selJson] $s
}


# Button 2) entrypoint: read selected JSON -> dict -> nested view text window
proc ::wb::devp::showDictAsPrettyJsonStr {} {
  set d [::wb::devp::selectedJsonFileToDict]
  set jsonStr [dictToPrettyJsonStr $d "wb-cfg"]

  set s ""
  append s "File: [file tail $::wb::devp::selJson]\n"
  append s "Path: $::wb::devp::selJson\n"
  append s "------------------------------------------------------------\n"
  append s $jsonStr
  append s "\n"

  ::wb::devp::_showTextWin [file tail $::wb::devp::selJson] $s
}



# --- Devp helpers for: 1) jsonFile --> Dict View -----------------------------

proc ::wb::devp::selectedJsonFileToDict {} {
  set path [::wb::devp::getSelectedFilePath]
  if {$path eq ""} { return } ;# helper already showed UI error
  set d [jsonFileAsDict $path]
  if {$d eq ""} { return } ;# helper already showed UI error
  return $d
}

# Read the currently selected JSON file and return a dict entry.
# All error handling is inside here.
proc ::wb::devp::getSelectedFilePath {} {
  if {![info exists ::wb::devp::selJson] || $::wb::devp::selJson eq ""} {
    ::wb::devp::_errWait "No JSON Selected" "No .json file is selected.\n\nSelect a file from the dropdown first."
    return ""
  }
  if {![file exists $::wb::devp::selJson]} {
    ::wb::devp::_errWait "JSON Not Found" "Selected JSON file does not exist:\n\n$::wb::devp::selJson"
    return ""
  }

  return $::wb::devp::selJson
}




# Read the currently selected JSON file and return a dict entry.
# All error handling is inside here.
proc ::wb::devp::_readJsonSelectedAsDict {} {
  if {![info exists ::wb::devp::selJson] || $::wb::devp::selJson eq ""} {
    ::wb::devp::_errWait "No JSON Selected" "No .json file is selected.\n\nSelect a file from the dropdown first."
    return ""
  }
  if {![file exists $::wb::devp::selJson]} {
    ::wb::devp::_errWait "JSON Not Found" "Selected JSON file does not exist:\n\n$::wb::devp::selJson"
    return ""
  }

  if {[catch {
    # Uses tcl-lib.tcl
    set d [::wb::lib::jsonFileAsDict $::wb::devp::selJson]
  } err]} {
    ::wb::devp::_errWait "JSON -> Dict Failed" $err
    return ""
  }
  log "read $::wb::devp::selJson entries [dict size $d]"

  return $d
}


proc ::wb::devp::_isDictLike {x} {
  if {[catch {llength $x}]} { return 0 }
  if {([llength $x] % 2) != 0} { return 0 }
  return [expr {![catch {dict size $x}]}]
}

proc ::wb::devp::_isListLike {x} {
  if {[catch {llength $x}]} { return 0 }
  # Avoid treating simple scalars as list
  return [expr {[llength $x] > 1}]
}


# Pretty "tree" rendering for nested Tcl values (dicts, lists, scalars).
# Returns a string.
proc ::wb::devp::_dictToTreeStr {value {indent 0}} {
  set pad [string repeat "  " $indent]

  # dict?
  if {[::wb::devp::_isDictLike $value]} {
    set out ""
    foreach {k v} $value {
      if {![catch {dict size $v} _]} {
        append out "${pad}${k}:\n"
        append out [::wb::devp::_dictToTreeStr $v [expr {$indent + 1}]]
      } else {
        # list?
        if {[::wb::devp::_isListLike $v]} {
          append out "${pad}${k}:\n"
          append out [::wb::devp::_listToTreeStr $v [expr {$indent + 1}]]
        } else {
          append out "${pad}${k}: [::wb::devp::_scalarStr $v]\n"
        }
      }
    }
    return $out
  }

  # list?
  if {[::wb::devp::_isListLike $value]} {
    return [::wb::devp::_listToTreeStr $value $indent]
  }

  # scalar
  return "${pad}[::wb::devp::_scalarStr $value]\n"
}

proc ::wb::devp::_listToTreeStr {lst indent} {
  set pad [string repeat "  " $indent]
  set out ""
  set n [llength $lst]
  for {set i 0} {$i < $n} {incr i} {
    set v [lindex $lst $i]
    if {[::wb::devp::_isDictLike $v]} {
      append out "${pad}\[$i\]:\n"
      append out [::wb::devp::_dictToTreeStr $v [expr {$indent + 1}]]
    } elseif {[::wb::devp::_isListLike $v]} {
      append out "${pad}\[$i\]:\n"
      append out [::wb::devp::_listToTreeStr $v [expr {$indent + 1}]]
    } else {
      append out "${pad}\[$i\]: [::wb::devp::_scalarStr $v]\n"
    }
  }
  return $out
}


proc ::wb::devp::_scalarStr {v} {
  # keep strings readable; show newlines/tabs
  set s $v
  regsub -all {\r} $s {\\r} s
  regsub -all {\n} $s {\\n} s
  regsub -all {\t} $s {\\t} s
  return $s
}

# Simple scrollable text window for displaying large strings
proc ::wb::devp::_showTextWin {title text} {
  set w .devp_view_[clock milliseconds]
  toplevel $w
  wm title $w $title
  wm geometry $w 800x600

  frame $w.top -padx 8 -pady 8
  pack $w.top -fill both -expand 1

  scrollbar $w.top.sb -orient vertical
  text $w.top.t -yscrollcommand [list $w.top.sb set] -wrap none -font "TkFixedFont"
  $w.top.sb configure -command [list $w.top.t yview]

  grid $w.top.t  -row 0 -column 0 -sticky nsew
  grid $w.top.sb -row 0 -column 1 -sticky ns
  grid columnconfigure $w.top 0 -weight 1
  grid rowconfigure    $w.top 0 -weight 1

  $w.top.t insert end $text
  $w.top.t configure -state disabled

  raise $w
  focus -force $w
}

# ---------------------------------------------------------------------------


# ---- Cosmos JSON tests (strings preserved) ----
proc ::wb::devp::makeCosmosDict {} {
  set d [dict create]
  dict set d sEmpty ""
  dict set d sWord "word"
  # NOTE: keep as a *string* (including double spaces)
  dict set d sSpaces "string  with  spaces"
  # control chars inside a single JSON string
  dict set d sCtrl "Line1\nLine2\rTab\tEnd"
  dict set d iNum 42
  dict set d fDbl 3.14159
  dict set d bTrue true
  dict set d bFalse false
  # mixed array payload
  dict set d aMixed [list word 42 3.14159 true]
  return $d
}

proc ::wb::devp::cosmosAsPrettyJson {} {
  # Workaround for tcllib json auto-list behavior:
  # build JSON object field-by-field, forcing some values as strings.
  set d [::wb::devp::makeCosmosDict]

  set parts {}
  lappend parts "\"sEmpty\" : [::json::write string [dict get $d sEmpty]]"
  lappend parts "\"sWord\" : [::json::write string [dict get $d sWord]]"
  lappend parts "\"sSpaces\" : [::json::write string [dict get $d sSpaces]]"
  lappend parts "\"sCtrl\" : [::json::write string [dict get $d sCtrl]]"
  lappend parts "\"iNum\" : [dict get $d iNum]"
  lappend parts "\"fDbl\" : [dict get $d fDbl]"
  lappend parts "\"bTrue\" : true"
  lappend parts "\"bFalse\" : false"
  # aMixed is intended as an array (not a dict)
  set arr [dict get $d aMixed]
  set arrJson [::json::write array {*}[lmap v $arr {
    if {$v eq "true" || $v eq "false"} {
      set v
    } elseif {[string is double -strict $v] || [string is integer -strict $v]} {
      set v
    } else {
      ::json::write string $v
    }
  }]]
  lappend parts "\"aMixed\" : $arrJson"

  set body [join $parts ",\n    "]
  return "{\n    $body\n}\n"
}

proc ::wb::devp::showCosmosDict {} {
  ::wb::devp::_showText "Cosmos Dict (pretty JSON)" [::wb::devp::cosmosAsPrettyJson]
}

proc ::wb::devp::saveCosmosDict {} {
  set path [file join $::wb::devp::workDir dict-entry-cosmos.json]
  set fh [open $path w]
  puts $fh [::wb::devp::cosmosAsPrettyJson]
  close $fh
  tk_messageBox -icon info -title "Saved" -message "Saved:\n$path"
}

proc ::wb::devp::saveCosmosList {} {
  set path [file join $::wb::devp::workDir list-dict-entry-cosmos.json]
  set one [::wb::devp::cosmosAsPrettyJson]
  set fh [open $path w]
  puts $fh "[string trim $one]"
  for {set i 1} {$i < 5} {incr i} {
    puts $fh ","
    puts $fh "[string trim $one]"
  }
  close $fh
  tk_messageBox -icon info -title "Saved" -message "Saved:\n$path"
}

proc ::wb::devp::showCosmosList {} {
  set path [file join $::wb::devp::workDir list-dict-entry-cosmos.json]
  if {![file exists $path]} {
    tk_messageBox -icon warning -title "Missing" -message "File not found:\n$path"
    return
  }
  ::wb::devp::_showText "Cosmos List (pretty JSON)" [::wb::lib::jsonFileAsPrettyStr $path]
}

# ---- run directly ----
puts "argv0: $::argv0"
puts "argv : $argv"

if {![info exists argv] || [llength $argv] < 1} {
  puts stderr "Usage: tclsh tcl-devp.tcl <work-dir>"
  exit 2
}
set arg0 [lindex $argv 0]
if {![file isdirectory $arg0]} {
  puts stderr "ERROR: work-dir is not a directory: $arg0"
  exit 2
}

set ::wb::devp::done 0
::wb::devp::main $arg0
vwait ::wb::devp::done
