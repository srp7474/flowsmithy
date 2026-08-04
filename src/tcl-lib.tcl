# Generated 2026-aug-03 courtesy of Claude (claude.ai)
# tcl-lib.tcl (v53)
# Changelog (skinny; full detail in CHANGELOG.md):
#   v53 (2026-aug-03): new fsCfgSetPersist proc -- writes a single scalar
#     cfg key back to flowsmithy.cfg on disk (in place, preserving
#     comments/other lines) plus in-memory ::wb::lib::fscfg, using the
#     already-known ::wb::lib::fscfgPath. Added to support fs-shell.tcl's
#     new "Do not display this window on FS Startup" welcome-screen
#     button (writes show.welcome = 0).
#   v52 (2026-aug-03): fsCfgLoad now clears ::wb::lib::fscfg before repopulating -- makes repeated calls in the same process idempotent instead of silently accumulating scalar keys (home.dir included) into 2-element lists; this was actively happening (fs-new.tcl's own unconditional fsCfgLoad call + fs-shell.tcl v14's added call), root cause of Steve's "run"/"cfg" "script not found: h:/tcl h:/tcl/src/fs-run.tcl" -- see fs-shell.tcl v18
#   v51 (2026-aug-03): fsCfgLoad now exposes the resolved flowsmithy.cfg path via ::wb::lib::fscfgPath -- lets callers (fs-shell's startup banner) report which cfg file is actually in use without recomputing the same path formula themselves
#   v50 (2026-jul-29): requireTclFlows now reads flows.dir from flowsmithy.cfg exclusively (removed the env(TCL_FLOWS) fallback -- one source of truth)
#   v49 (2026-jul-28): changelog moved to CHANGELOG.md; this header now a skinny per-version log
#   v48 (2026-jul-18): fsCfgLoad resolves home dir via $env(HOME)/$env(USERPROFILE) directly (Tcl 9 removed "~" expansion)
#   v47: fixed jsonFileAsDict missing -encoding utf-8 on read (was the real cause of em-dash corruption)
#   v46: {tasks[].runprops} is "obj" not "arr" -- v43-45 were chasing a non-conforming sample

set ::WB_TCL_LIB_VERSION 50
puts "==> Loading tcl-lib.tcl (v$::WB_TCL_LIB_VERSION)"


namespace eval ::wb::lib {
  variable VER 12
}


# tcllib packages
package require json
package require json::write


set ::WB_JSON_EMIT_TRACE 0   ;# 0 = off, 1 = on

# runprops is a plain JSON object ({"javaMain":"...","cpTag":"..."}),
# matching fs-run.tcl and the majority of existing cfg files (e.g.
# cit-aud) -- not an array. No {tasks[].runprops[]} entry needed since
# it isn't an array; its individual string fields fall through to the
# default "str" type inference (_defaultTypeForKeyS), same as any other
# unlisted object field.
set ::WB_JSON_SCHEMAS(wb-cfg) [dict create \
  tasks                    arr \
  {tasks[]}                obj \
  {tasks[].opts}           arr \
  {tasks[].opts[]}         obj \
  {tasks[].opts[].reqd}    bool \
  {tasks[].opts[].places}  arr \
  {tasks[].opts[].places[]} str \
  {tasks[].parms}           arr \
  {tasks[].parms[]}         obj \
  {tasks[].hooks}           arr \
  {tasks[].hooks[]}         obj \
  {tasks[].runprops}        obj \
  def                       arr \
  {def[]}                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               obj \
]

set ::WB_JSON_SCHEMAS(wb-registry) [dict create \
  parms      arr \
  {parms[]}  obj \
]

set ::WB_JSON_SCHEMAS(wb-dyn) [dict create \
  winsize    obj \
  globs      obj \
  uiHistory  arr \
  uiHistory[]  obj \
]

set ::WB_JSON_SCHEMAS(wb-task) [dict create \
  args      arr \
  {args[]}  obj \
]

## --- low level global procs

proc log {msg} {
  puts $msg
}

proc isTrue {bool} {
  return [string is true -strict $bool]
}

proc env-vbl {ev} {
    if {[info exists ::env($ev)]} {
        set val $::env($ev)
        regsub -all {\\} $val {/} val
        return $val
    } else {
        return "?${ev}?"
    }
}


#if {[info exists ::WB_JSON_SCHEMAS(wb-demo)]} {
#    log "schema RAW = <$::WB_JSON_SCHEMAS(wb-demo)>"
#}

# ---------------------------------------------------------------------------
# getDateStamp
# Returns current local time as:  yyyy-mmm-dd:HH:MM
# e.g. 2026-apr-02:11:49
# ---------------------------------------------------------------------------
# Generated 2026-apr-02 courtesy of Claude (claude.ai)
proc getDateStamp {} {
    set now [clock seconds]
    set yyyy [clock format $now -format "%Y"]
    set mmm  [string tolower [clock format $now -format "%b"]]
    set dd   [clock format $now -format "%d"]
    set HHMM [clock format $now -format "%H:%M"]
    return "${yyyy}-${mmm}-${dd}:${HHMM}"
}

# ---------------------------------------------------------------------------
# ::wb::lib::applyDictToTemplate  dict str
#
# Mustache-like token substitution over a string.
#
# Token syntax:
#   {{tok}}   - required token: replaced with dict value for tok;
#               if tok not in dict, replaced with literal ?tok?
#   {{tok?}}  - optional token: replaced with dict value for tok;
#               if tok not in dict, replaced with "" (empty string)
#
# Returns the updated string.
# ---------------------------------------------------------------------------
# Generated 2026-apr-02 courtesy of Claude (claude.ai)
proc ::wb::lib::applyDictToTemplate {dct str} {
    # Build pattern via hex escapes - keeps ALL literal braces out of
    # this proc body so Tcl brace-counting cannot mis-parse the proc.
    set ob  \x7b
    set cb  \x7d
    set pat "${ob}${ob}(\[^${ob}${cb}\]+)${cb}${cb}"

    set result ""
    set rest $str

    while {[regexp -indices -- $pat $rest fullIdx tokIdx]} {
        set preEnd [expr {[lindex $fullIdx 0] - 1}]
        if {$preEnd >= 0} {
            append result [string range $rest 0 $preEnd]
        }

        set tok [string range $rest [lindex $tokIdx 0] [lindex $tokIdx 1]]

        if {[string index $tok end] eq "?"} {
            set key      [string range $tok 0 end-1]
            set optional 1
        } else {
            set key      $tok
            set optional 0
        }

        if {[dict exists $dct $key]} {
            append result [dict get $dct $key]
        } elseif {!$optional} {
            append result "?${key}?"
        }

        set rest [string range $rest [expr {[lindex $fullIdx 1] + 1}] end]
    }

    append result $rest
    return $result
}
# ---- Root/path helpers (flows.dir, from flowsmithy.cfg, is mandatory) ----
#
# This used to read $env(TCL_FLOWS) directly, and a SEPARATE, later
# definition of this same proc in fs-cfg.tcl (defined after fs-cfg.tcl
# sources this file, so it silently won via Tcl's last-definition-wins)
# read flows.dir from flowsmithy.cfg instead -- two competing sources of
# truth for the same setting, order-dependent rather than structurally
# guaranteed to agree. fs-clone.tcl and fs-new.tcl call this proc too and
# had no override of their own, so they were silently at the mercy of
# whichever definition happened to be loaded last. Consolidated here as
# the one, canonical, flowsmithy.cfg-based definition; the duplicate in
# fs-cfg.tcl is removed (see that file's changelog).
proc ::wb::lib::requireTclFlows {} {
  set dirs [fsCfgGetList flows.dir]
  if {[llength $dirs] == 0} {
    error "flows.dir is not defined in flowsmithy.cfg"
  }
  foreach dir $dirs {
    if {[file isdirectory $dir]} { return $dir }
  }
  error "flows.dir: none of the configured directories exist:\n  [join $dirs \n\ \ ]"
}

proc ::wb::lib::pathGlobal {leaf} {
  set root [::wb::lib::requireTclFlows]
  return [file join $root $leaf]
}

proc ::wb::lib::pathFlow {flow leaf} {
  set root [::wb::lib::requireTclFlows]
  return [file join $root flows $flow $leaf]
}

proc ::wb::lib::pathTask {flow task leaf} {
  set root [::wb::lib::requireTclFlows]
  return [file join $root $flow tasks $task $leaf]
}

# ---------------------------------------------------------------------------
# fsOpenInEditor  filePath
# Resolves editor.command from cfg, substitutes {{file}}, and launches
# on Windows via "start /b" (non-blocking, no console window).
# Blows up clearly if editor.command is not configured or {{file}} missing.
# ---------------------------------------------------------------------------
proc fsOpenInEditor {filePath} {
  set cmd [fsCfgGet editor.command]
  if {$cmd eq ""} {
    error "fsOpenInEditor: editor.command is not defined in flowsmithy.cfg"
  }
  if {[string first "{{file}}" $cmd] < 0} {
    error "fsOpenInEditor: editor.command has no {{file}} placeholder: $cmd"
  }

  # Normalise path separators for Windows
  set filePath [file normalize $filePath]

  set resolved [string map [list "{{file}}" $filePath] $cmd]

  #hilite -red "EDITOR:$resolved"

  # Convert command string to argv list.
  # Do NOT use split here; lrange honors quoted args in $cmd.
  set rc [catch {
    set argv [lrange $resolved 0 end]
  } err]

  if {$rc} {
    error "fsOpenInEditor: editor command is not a valid Tcl list: $err\nCommand was: $resolved"
  }

  if {0} {
    hilite -red "EDITOR argv:"
    foreach arg $argv {
      hilite -red "  <$arg>"
    }
  }

  if {$::tcl_platform(platform) eq "windows"} {
    # Launch Sublime directly. Do not use cmd /c start.
    set rc [catch {
      exec {*}$argv &
    } err]

    if {$rc} {
      error "fsOpenInEditor: failed to launch editor: $err\nArgs were: $argv"
    }
  } else {
    error "fsOpenInEditor: platform '$::tcl_platform(platform)' is not yet implemented"
  }
}



## --- Common helpers
proc getScriptDir {} {
 set scriptDir [file dirname [file normalize [info script]]]
 return $scriptDir;
}


proc getEnvVbl {vbl} {
  if {[info exists ::env($vbl)]} {
    return $::env($vbl)
  }
  return "?${vbl}?"
}

## --- Json lib wrappers - these 4 routines take care of our needs

proc jsonFileAsDict {path} {
  set fh [open $path r]
  fconfigure $fh -encoding utf-8
  set data [read $fh]
  close $fh
  return [::json::json2dict $data]
}

proc jsonStrAsFile {path jsonStr} {
  set f [open $path w]
  fconfigure $f -translation lf -encoding utf-8
  puts -nonewline $f $jsonStr
  close $f
  log "wrote ${path}"
}

proc dictAsJsonFile {path dict schema} {
  set jsonStr [dictToPrettyJsonStr $dict $schema]
  jsonStrAsFile $path $jsonStr
}



# ------------------------------------------------------------
# dictToPrettyJsonStr.tcl
# Round-trip-safe JSON emitter for Tcl dicts produced by ::json::json2dict
#
# Defaults:
#   - Everything is a JSON string unless schema says otherwise.
#   - Arrays/objects are only emitted when schema (or naming rules) say so.
#
# Naming rules (used only when schema does NOT override):
#   - Hungarian typed if 1st char in {a b i f s d o} AND 2nd char is uppercase:
#       a* => array, d*/o* => object, b* => bool, i*/f* => number, s* => string
#   - If NOT Hungarian-typed and key ends with "s" => array
#   - Otherwise => string
#
# Schema:
#   Store schemas in global ::WB_JSON_SCHEMAS(<name>) as a dict mapping path->type.
#   Paths use dot notation and [] for array elements.
#     Example overrides:
#       tasks[]                obj     ;# array items are objects
#       tasks[].opts[]         obj     ;# opts items are objects
#       tasks[].opts[].reqd    bool
#       tasks[].opts[].place   bool
#       tasks[].opts[].places  arr     ;# places is an array
#       tasks[].opts[].places[] str    ;# places elements are strings
#
# Types: str | bool | num | obj | arr
# ------------------------------------------------------------

# Code generated on 2026-Feb-13 20:41 courtesy of chatGPT

# --- public entry ---
proc dictToPrettyJsonStr {d schemaName} {
    if {[catch {dict size $d} err]} {
        error "dictToPrettyJsonStr: not a dict: $err"
    }
    ::json::write indented true
    return [_emitObjS $d $schemaName ""]
}

# ---- schema type lookup (FIXED + TRACE) ----
proc _schemaTypeAtS {schemaName path} {
    if {$schemaName eq ""} { return "" }
    if {![info exists ::WB_JSON_SCHEMAS($schemaName)]} { return "" }

    set sd $::WB_JSON_SCHEMAS($schemaName)

    if {$path ne "" && [dict exists $sd $path]} {
        set t [dict get $sd $path]
        if {[info exists ::WB_JSON_EMIT_TRACE] && $::WB_JSON_EMIT_TRACE} {
            log "schemaType HIT schema=$schemaName path=<$path> => <$t>"
        }
        return $t
    }

    if {[info exists ::WB_JSON_EMIT_TRACE] && $::WB_JSON_EMIT_TRACE} {
        log "schemaType MISS schema=$schemaName path=<$path>"
    }
    return ""
}

proc _isHunKeyS {k} {
    if {[string length $k] < 2} { return 0 }
    set p  [string index $k 0]
    set c2 [string index $k 1]
    expr {($p in {a b i f s d o}) && [string is upper $c2]}
}

proc _defaultTypeForKeyS {k} {
    if {[_isHunKeyS $k]} {
        set p [string index $k 0]
        switch -- $p {
            a { return "arr" }
            d - o { return "obj" }
            b { return "bool" }
            i - f { return "num" }
            default { return "str" }
        }
    }
    if {[string match "*s" $k]} { return "arr" }
    return "str"
}

# ---- TRACE helper ----
proc _traceEmitS {path chosenType src v} {
    if {![info exists ::WB_JSON_EMIT_TRACE] || !$::WB_JSON_EMIT_TRACE} { return }

    set isDict [expr {![catch {dict size $v} _]}]
    set llen 0
    if {![catch {llength $v} _l]} { set llen [llength $v] }

    set preview $v
    if {[string length $preview] > 120} {
        set preview "[string range $preview 0 120]..."
    }
    # log is your proc; if not in scope, change to puts
    log "emit path=$path type=$chosenType src=$src isDict=$isDict llength=$llen preview=<$preview>"
}

# ---- recursion guard ----
# Tracks active (type,path) frames so schema mistakes fail fast.
proc _pushFrameS {st path} {
    if {![info exists ::WB_JSON_EMIT_STACK]} { set ::WB_JSON_EMIT_STACK {} }
    set key "${st}@${path}"
    if {[lsearch -exact $::WB_JSON_EMIT_STACK $key] >= 0} {
        error "JSON emit recursion detected at st=$st path=<$path> (check schema: likely arr resolving to arr repeatedly)"
    }
    lappend ::WB_JSON_EMIT_STACK $key
}
proc _popFrameS {st path} {
    set key "${st}@${path}"
    set i [lsearch -exact $::WB_JSON_EMIT_STACK $key]
    if {$i >= 0} {
        set ::WB_JSON_EMIT_STACK [lreplace $::WB_JSON_EMIT_STACK $i $i]
    }
}


proc _emitArrS {lst schemaName path} {
    _pushFrameS arr $path
    try {
        if {[catch {llength $lst}]} {
            return [::json::write string $lst]
        }

        set itemPath "${path}\[\]"
        set itemType [_schemaTypeAtS $schemaName $itemPath]

        if {[info exists ::WB_JSON_EMIT_TRACE] && $::WB_JSON_EMIT_TRACE} {
            log "emitArr path=<$path> itemPath=<$itemPath> itemType=<$itemType> n=[llength $lst]"
        }

        set items {}
        foreach it $lst {
            if {$itemType eq ""} {
                # default array items are scalar
                lappend items [_emitScalarS $it]
            } else {
                lappend items [_emitValS $it $schemaName $itemPath $itemType]
            }
        }
        return [::json::write array {*}$items]
    } finally {
        _popFrameS arr $path
    }
}

proc _emitValS {v schemaName path st} {
    switch -- $st {
        obj  { return [_emitObjS $v $schemaName $path] }
        arr  { return [_emitArrS $v $schemaName $path] }
        str  { return [::json::write string $v] }
        bool { return [_emitBoolS $v] }
        num  { return [_emitNumOrStrS $v] }
        default { return [::json::write string $v] }
    }
}

# ---- enhanced to inspect output value. Schema can prevent.

proc _emitObjS {d schemaName path} {
    _pushFrameS obj $path
    try {
        if {[catch {dict size $d}]} {
            return [::json::write string $d]
        }

        set pairs {}
        dict for {k v} $d {
            set childPath [expr {$path eq "" ? $k : "${path}.${k}"}]

            set st  [_schemaTypeAtS $schemaName $childPath]
            set src "schema"
            if {$st eq ""} {
                set st [_defaultTypeForKeyS $k]
                set src "default"
            }

            _traceEmitS $childPath $st $src $v

            # --- tweak: allow scalar strings to auto-coerce, with "false" dropping the key
            if {$st in {str num bool}} {
                set sv [_emitScalarS $v]
                if {$sv eq "__OMIT__"} {
                    continue
                }
                lappend pairs $k $sv
            } else {
                lappend pairs $k [_emitValS $v $schemaName $childPath $st]
            }
        }
        return [::json::write object {*}$pairs]
    } finally {
        _popFrameS obj $path
    }
}

proc _emitScalarS {v} {
    # tweak rules:
    #   "true"  -> true
    #   "false" -> OMIT key (only meaningful when called from dict emission)
    #   "null"  -> null
    #   json-number-looking -> number literal
    #   else -> JSON string
    set lv [string tolower $v]

    if {$lv eq "true"}  { return "true" }
    if {$lv eq "false"} { return "__OMIT__" }
    if {$lv eq "null"}  { return "null" }

    # JSON-number-ish: -?(0|[1-9]\d*)(\.\d+)?([eE][+-]?\d+)?
    if {[regexp {^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$} $v]} {
        return $v
    }

    return [::json::write string $v]
}

proc _emitBoolS {v} {
    # keep existing behavior when schema forces bool,
    # but accept string forms explicitly
    set lv [string tolower $v]
    if {$lv eq "true"}  { return "true" }
    if {$lv eq "false"} { return "false" }
    return [expr {$v ? "true" : "false"}]
}

proc _emitNumOrStrS {v} {
    # When schema forces num, accept json-number-looking strings as number literal.
    if {[regexp {^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$} $v]} {
        return $v
    }
    return [::json::write string $v]
}


# Code generated on 2026-Feb-15 19:45  courtesy of chatGPT
# hilite -- print highlighted text using ANSI escape codes (VT)
# Usage: hilite ? | hilite ?-color? ?-nonewline? text...

proc hilite {args} {
  # Accepted color switches (PowerShell-compatible names)
  set allColors {
    -black -darkblue -darkgreen -darkcyan -darkred -darkmagenta -darkyellow -gray
    -darkgray -blue -green -cyan -red -magenta -yellow -white
    -foreground
  }

  # Help
  if {[llength $args] == 1 && [string equal -nocase [lindex $args 0] "?"]} {
    hilite -cyan "--------- hilite help -----------------"
    hilite -cyan "colors:" -white " $allColors"
    hilite -cyan "switches:" -white " -nonewline"
    return
  }

  # Map lower-case names to ANSI SGR foreground codes.
  # dark* => normal 30-37; bright => 90-97
  array set sgr {
    foreground 0

    black 30
    darkblue 34
    darkgreen 32
    darkcyan 36
    darkred 31
    darkmagenta 35
    darkyellow 33
    gray 37

    darkgray 90
    blue 94
    green 92
    cyan 96
    red 91
    magenta 95
    yellow 93
    white 97
  }

  set esc "\u001b"
  set nonewline 0

  # current color (start reset)
  puts -nonewline "${esc}\[0m"

  foreach arg $args {
    set a [string tolower $arg]

    if {$a eq "-nonewline"} {
      set nonewline 1
      continue
    }

    if {[lsearch -exact $allColors $a] >= 0} {
      set nm [string range $a 1 end]  ;# strip leading '-'
      if {![info exists sgr($nm)]} {
        error "hilite: unsupported color '$arg'"
      }
      set code $sgr($nm)
      puts -nonewline "${esc}\[${code}m"
      continue
    }

    # regular text token (no implicit spaces, like your PS version)
    puts -nonewline $arg
  }

  # reset so later output isn't affected
  puts -nonewline "${esc}\[0m"

  # newline unless -nonewline
  if {!$nonewline} {
    puts ""
  }
}


# ---------------------------------------------------------------------------
# openDebugWin
#   title   - window title
#   wid     - width  (pixels)
#   hgt     - height (pixels)
#   strData - text to display (may contain newlines)
#
# Simple scrollable debug window (centered on screen).
# ---------------------------------------------------------------------------
proc openDebugWin {title wid hgt strData} {

  # Unique toplevel name
  set w .dbg_[clock milliseconds]
  toplevel $w
  wm title $w $title
  wm geometry $w ${wid}x${hgt}

  # ---- Center on screen ----
  update idletasks
  set sw [winfo screenwidth  $w]
  set sh [winfo screenheight $w]
  set x  [expr {($sw - $wid) / 2}]
  set y  [expr {($sh - $hgt) / 2}]
  wm geometry $w ${wid}x${hgt}+${x}+${y}

  # Main frame
  ttk::frame $w.main
  pack $w.main -fill both -expand 1 -padx 8 -pady 8

  # Text + scrollbars
  text $w.main.txt \
      -wrap none \
      -yscrollcommand "$w.main.sy set" \
      -xscrollcommand "$w.main.sx set" \
      -font TkFixedFont

  ttk::scrollbar $w.main.sy -orient vertical   -command "$w.main.txt yview"
  ttk::scrollbar $w.main.sx -orient horizontal -command "$w.main.txt xview"

  grid $w.main.txt -row 0 -column 0 -sticky nsew
  grid $w.main.sy  -row 0 -column 1 -sticky ns
  grid $w.main.sx  -row 1 -column 0 -sticky ew

  grid columnconfigure $w.main 0 -weight 1
  grid rowconfigure    $w.main 0 -weight 1

  # Insert data (preserves newlines)
  $w.main.txt insert end $strData
  $w.main.txt configure -state disabled

  # Close button
  ttk::frame $w.btn
  pack $w.btn -fill x -padx 8 -pady {0 8}

  ttk::button $w.btn.close -text "Close" -command "destroy $w"
  pack $w.btn.close -side right

  return $w
}

#-------------------------------------------------------------------------
# script execution helpers
#
# wbTry "Bind Failed: $bindName" 900 600 $useDebugWin [list $bindName $ctx]
#
# wbTryCall "Bind Failed: $bindName" $useDebugWin $bindName $ctx#
#
#-------------------------------------------------------------------------
proc wbTry {title wid hgt useDebugWin script} {
  # Run in caller scope so variables like $bindName, $ctx resolve naturally
  set rc [catch {uplevel 1 $script} err opts]
  if {$rc} {
    set ei ""
    set ec ""
    catch { set ei [dict get $opts -errorinfo] }
    catch { set ec [dict get $opts -errorcode] }

    hilite -red "FAILED: $title"
    hilite -red "  err: $err"
    if {$ec ne ""} { hilite -yellow "  errorCode: $ec" }
    if {$ei ne ""} { hilite -yellow "  errorInfo:\n$ei" }

    if {$useDebugWin} {
      set msg "FAILED: $title\n\nerr: $err\n"
      if {$ec ne ""} { append msg "\nerrorCode:\n$ec\n" }
      if {$ei ne ""} { append msg "\nerrorInfo:\n$ei\n" }
      openDebugWin $title $wid $hgt $msg
    }
  }
  return $rc
}

proc wbTryCall {title useDebugWin cmdPrefix args} {
  return [wbTry $title 900 600 $useDebugWin [list {*}$cmdPrefix {*}$args]]
}



# ------------------------------------------------------------------------------
# mainCatch
# Wrap your top-level entry point with this.
# If an error occurs:
#   - Prints file:line of call site (if available)
#   - Prints full Tcl stack trace
#   - Exits (CLI mode)
# Later: you can detect UI mode and open debug window instead.
# ------------------------------------------------------------------------------
proc mainCatch {script} {

  if {[catch {uplevel 1 $script} err opts]} {

    hilite -red "FATAL ERROR: $err"

    if {[dict exists $opts -errorinfo]} {
      puts stderr [dict get $opts -errorinfo]
    } else {
      puts stderr $::errorInfo
    }

    exit 1
  }
}

# Generated 2026-apr-01 courtesy of Claude (claude.ai)
# ---------------------------------------------------------------
# FSCFG - FlowSmithy configuration file loader and accessors
#
# Loads ~/flowsmithy/flowsmithy.cfg into global array FSCFG.
#
# Accessors (never touch FSCFG directly - always use these):
#   fsCfgLoad               - find, parse and populate FSCFG; call once at startup
#   fsCfgGet      key       - string value, default ""
#   fsCfgGetBool  key       - boolean value, default false
#   fsCfgGetList  key       - list value, default {}
#   fsCfgRequire  key       - string value, error if missing or empty
#
# cfg file format:
#   # comment lines and blank lines are skipped
#   key = value
#   key = value              ;# duplicate keys accumulate as a TCL list
# ---------------------------------------------------------------

# Private config data - access only via public procs below
namespace eval ::wb::lib {
    variable fscfg
    array set fscfg {}
}

# ---------------------------------------------------------------------------
# ::wb::lib::userHomeDir
#
# Resolves the current user's home directory. Deliberately does NOT rely
# on Tcl's own tilde handling in either direction:
#   - Tcl 8.6 auto-expands a bare "~" in file join/normalize/etc.
#   - Tcl 9 removed that (TIP 602) and added explicit `file home` /
#     `file tildeexpand` commands instead -- but those don't exist under
#     8.6, so calling them directly would break the 8.6 side.
# Since FlowSmithy needs to run under both, this goes straight to the
# environment variables both versions (and both OSes) already expose,
# with `file home` only as a last-resort fallback if somehow neither is
# set. This is what fsCfgLoad uses to find flowsmithy.cfg -- see that
# proc below for the bug this was fixing (Tcl 9 was leaving a literal
# "~" in the path, producing "...bin/~/flowsmithy/flowsmithy.cfg" and a
# "configuration file not found" error).
# ---------------------------------------------------------------------------
proc ::wb::lib::userHomeDir {} {
    if {[info exists ::env(HOME)] && $::env(HOME) ne ""} {
        return $::env(HOME)
    }
    if {[info exists ::env(USERPROFILE)] && $::env(USERPROFILE) ne ""} {
        return $::env(USERPROFILE)
    }
    if {![catch {file home} h] && $h ne ""} {
        return $h
    }
    error "Cannot determine user home directory -- no HOME or USERPROFILE environment variable is set, and 'file home' is unavailable."
}

proc fsCfgLoad {} {
    set cfgPath [file normalize [file join [::wb::lib::userHomeDir] flowsmithy flowsmithy.cfg]]
    set ::wb::lib::fscfgPath $cfgPath

    # Idempotent: fsCfgLoad can legitimately be called more than once in the
    # same process (fs-new.tcl calls it unconditionally at source time; a
    # caller further up the chain may call it again). Without this reset,
    # a second call would find every key already populated and lappend
    # onto it (the intra-file duplicate-key-as-list mechanism, intended for
    # genuinely list-valued keys like flows.dir), silently turning every
    # scalar key -- home.dir included -- into a 2-element list. Clearing
    # here makes every call a clean, independent, correct load.
    array unset ::wb::lib::fscfg

    if {![file exists $cfgPath]} {
        error "FlowSmithy configuration file not found: $cfgPath\nPlease create this file before running FlowSmithy."
    }
    if {![file readable $cfgPath]} {
        error "FlowSmithy configuration file exists but cannot be read: $cfgPath"
    }

    set fh [open $cfgPath r]
    set lineNum 0

    while {[gets $fh line] >= 0} {
        incr lineNum
        set line [string trim $line]

        # Skip blank lines and comments
        if {$line eq "" || [string index $line 0] eq "#"} { continue }

        # Expect: key = value
        if {![regexp {^([A-Za-z0-9._-]+)\s*=\s*(.*)$} $line -> key value]} {
            puts stderr "WARNING fsCfgLoad: malformed line $lineNum in $cfgPath: $line"
            continue
        }

        set key   [string trim $key]
        set value [string trim $value]

        # Duplicate keys accumulate as a list
        if {[info exists ::wb::lib::fscfg($key)]} {
            lappend ::wb::lib::fscfg($key) $value
        } else {
            set ::wb::lib::fscfg($key) $value
        }
    }

    close $fh
    hilite -green "==> fsCfgLoad: loaded $cfgPath"
}

proc fsCfgGet {key {_resolving {}}} {
    # Circular reference guard
    if {[lsearch -exact $_resolving $key] >= 0} {
        error "fsCfgGet: circular reference detected resolving key '$key' via: [join $_resolving { -> }] -> $key"
    }

    if {![info exists ::wb::lib::fscfg($key)]} { return "" }

    set value $::wb::lib::fscfg($key)

    # [use otherkey] - one level of wholesale indirection, resolved first.
    # The entire value is replaced by the raw value of the referenced key,
    # then the result is re-parsed for [cfg ...] references.
    # No recursion - [use] inside a [use] target is not processed.
    if {[regexp {\[use ([A-Za-z0-9._-]+)\]} $value match ref]} {
        if {![info exists ::wb::lib::fscfg($ref)]} {
            error "fsCfgGet: [use $ref] in key '$key' refers to undefined key '$ref'"
        }
        set value $::wb::lib::fscfg($ref)
    }

    # $result is set AFTER [use] substitution so [cfg] replacements
    # are applied to the correct base string
    set result $value

    # Resolve any [cfg otherkey] references
    foreach {match ref} [regexp -all -inline {\[cfg ([A-Za-z0-9._-]+)\]} $value] {
        set resolved [fsCfgGet $ref [lappend _resolving $key]]
        set result [string map [list $match $resolved] $result]
    }
    return $result
}

proc fsCfgGetBool {key} {
    if {![info exists ::wb::lib::fscfg($key)]} { return false }
    switch -- [string tolower [string trim $::wb::lib::fscfg($key)]] {
        "true"  - "yes" - "1" { return true  }
        "false" - "no"  - "0" { return false }
        default {
            puts stderr "WARNING fsCfgGetBool: unexpected boolean value '$::wb::lib::fscfg($key)' for key '$key' - defaulting to false"
            return false
        }
    }
}

proc fsCfgGetList {key} {
    if {![info exists ::wb::lib::fscfg($key)]} { return {} }
    return $::wb::lib::fscfg($key)
}

proc fsCfgRequire {key} {
    if {![info exists ::wb::lib::fscfg($key)] || [string trim $::wb::lib::fscfg($key)] eq ""} {
        error "FlowSmithy configuration error: required key '$key' is not defined in flowsmithy.cfg"
    }
    return $::wb::lib::fscfg($key)
}

# ---------------------------------------------------------------------------
# fsCfgSetPersist key value
#
# Updates a single scalar key both in memory (::wb::lib::fscfg) and on
# disk in flowsmithy.cfg -- rewrites that key's line in place, preserving
# every other line (comments, blank lines, other keys) untouched.
# Appends a new line if the key isn't already present.
#
# Uses ::wb::lib::fscfgPath (set by fsCfgLoad) as the target file -- does
# not recompute the cfg path itself, so it can never point at a different
# file than the one actually loaded this session (same reasoning as
# fscfgPath's original purpose in v51).
#
# Intended for simple scalar UI-writable options (e.g. show.welcome).
# NOT list-aware: if a key legitimately appears on more than one line
# (the multi-value convention used by e.g. flows.dir), only the FIRST
# occurrence is rewritten and any others are left as-is -- this proc is
# not meant for list-valued keys.
# ---------------------------------------------------------------------------
proc fsCfgSetPersist {key value} {
    if {![info exists ::wb::lib::fscfgPath] || $::wb::lib::fscfgPath eq ""} {
        error "fsCfgSetPersist: no flowsmithy.cfg path known -- fsCfgLoad must run first"
    }
    set cfgPath $::wb::lib::fscfgPath

    if {![file exists $cfgPath]} {
        error "fsCfgSetPersist: $cfgPath does not exist"
    }

    set fh [open $cfgPath r]
    fconfigure $fh -encoding utf-8
    set lines [split [read $fh] "\n"]
    close $fh

    set found 0
    set newLines {}
    foreach line $lines {
        set trimmed [string trim $line]
        if {!$found && $trimmed ne "" && [string index $trimmed 0] ne "#" \
                && [regexp {^([A-Za-z0-9._-]+)\s*=} $trimmed -> lineKey] \
                && [string trim $lineKey] eq $key} {
            lappend newLines "$key = $value"
            set found 1
        } else {
            lappend newLines $line
        }
    }
    if {!$found} {
        lappend newLines "$key = $value"
    }

    set fh [open $cfgPath w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh [join $newLines "\n"]
    close $fh

    set ::wb::lib::fscfg($key) $value
    hilite -green "==> fsCfgSetPersist: wrote $key = $value to $cfgPath"
}

# ---------------------------------------------------------------
# parseParms-v8.tcl
# Drop-in proc for tcl-lib
#
# Usage:
#   # m or .  flag    argname  description
#   set parmsDef {
#       { .  -devp  ""       "development mode" }
#       { m  -out   outfile  "Target file"      }
#   }
#   array set ::wb::cfg::opts [parseParms $parmsDef 1 $argv]
#
# parmsDef format - list of 4-element rows:
#   { mandatory  flag      argname   description  }
#   { m          -out      outfile  "Target file" }  ;# value parm
#   { .          -refresh  ""       "Refresh"     }  ;# boolean flag
#
#   mandatory : MUST be "m" (mandatory) or "." (optional) - error if not
#   flag      : command-line flag including leading dash
#   argname   : "" = boolean switch; non-empty = expects a following value
#   description: help text
#
#   Every row MUST have exactly 4 tokens - error if not.
#   Comments belong outside the parmsDef braces, not inside.
#
#   NOTE: -h is handled automatically. Do not include in parmsDef.
#         It will always appear at the bottom of the help table.
#
#   NOTE: -- in argv is silently consumed. Useful when the calling
#         shell uses -- to separate its own flags from script flags.
#
# firstArg:
#   0-based index into argv where flag parsing begins.
#   Args before firstArg are stored as POS0, POS1, ...
#   At least firstArg positional args must be present or an error is raised.
#
# Output keys in opts array:
#   - Flag keys  : flag with leading dash stripped  (e.g. opts(out), opts(refresh))
#   - Positional : POS0, POS1, ...
#   - Boolean    : 0 by default, 1 when flag present
#   - Value parm : "" by default, value when flag present
#   All defined parms are always present in output array.
# ---------------------------------------------------------------

proc parseParms {parmsDef firstArg parmArgs} {

    # --- Validate and build lookup map, initialize all defaults ---
    array set flagMap {}
    array set result {}
    set rowNum 0

    foreach row $parmsDef {
        incr rowNum

        # Every row must have exactly 4 tokens
        if {[llength $row] != 4} {
            puts stderr "ERROR: parmsDef row $rowNum must have exactly 4 tokens, got [llength $row]: {$row}"
            exit 1
        }

        lassign $row mandatory flag argname desc

        # First token must be m or .
        if {$mandatory ne "m" && $mandatory ne "."} {
            puts stderr "ERROR: parmsDef row $rowNum token 1 must be 'm' or '.', got '$mandatory': {$row}"
            exit 1
        }

        set flagMap($flag) [list $mandatory $argname $desc]
        set key [string trimleft $flag -]
        if {$argname eq ""} {
            set result($key) 0    ;# boolean default
        } else {
            set result($key) ""   ;# value default
        }
    }

    # --- Check minimum positional args ---
    if {$firstArg > 0 && [llength $parmArgs] < $firstArg} {
        set got [llength $parmArgs]
        puts stderr "ERROR: Expected at least $firstArg positional argument(s) before flags, got $got"
        parseParms_help $parmsDef
        exit 1
    }

    # --- Positional args (before firstArg) ---
    for {set i 0} {$i < $firstArg} {incr i} {
        set result(POS$i) [lindex $parmArgs $i]
    }

    # --- Parse flags starting at firstArg ---
    set i $firstArg
    set nArgs [llength $parmArgs]

    while {$i < $nArgs} {
        set token [lindex $parmArgs $i]

        # Silently consume -- separator
        if {$token eq "--"} {
            incr i
            continue
        }

        # Must start with dash
        if {![string match "-*" $token]} {
            puts stderr "ERROR: Unexpected argument '$token' (expected a flag)"
            parseParms_help $parmsDef
            exit 1
        }

        # -h is always handled internally
        if {$token eq "-h"} {
            parseParms_help $parmsDef
            exit 0
        }

        # Known flag?
        if {![info exists flagMap($token)]} {
            puts stderr "ERROR: Unknown flag '$token'"
            parseParms_help $parmsDef
            exit 1
        }

        lassign $flagMap($token) mandatory argname desc
        set key [string trimleft $token -]

        if {$argname eq ""} {
            # Boolean flag
            set result($key) 1
        } else {
            # Expects a value
            incr i
            if {$i >= $nArgs} {
                puts stderr "ERROR: Flag '$token' requires a value <$argname>"
                parseParms_help $parmsDef
                exit 1
            }
            set result($key) [lindex $parmArgs $i]
        }

        incr i
    }

    # --- Check mandatory parms ---
    set missing {}
    foreach row $parmsDef {
        lassign $row mandatory flag argname desc
        if {$mandatory eq "m"} {
            set key [string trimleft $flag -]
            if {$result($key) eq ""} {
                lappend missing $flag
            }
        }
    }
    if {[llength $missing] > 0} {
        puts stderr "ERROR: Missing mandatory flag(s): [join $missing {, }]"
        parseParms_help $parmsDef
        exit 1
    }

    return [array get result]
}

# ---------------------------------------------------------------
# parseParms_help - prints formatted help table
# -h always appended at bottom.
# ---------------------------------------------------------------
proc parseParms_help {parmsDef} {
    puts ""
    puts "Usage: $::argv0 \[options\]"
    puts ""
    puts [format "  %-14s %-2s %-12s %s" "Flag" "  " "Arg" "Description"]
    puts "  [string repeat - 14]  [string repeat - 12]  [string repeat - 36]"
    foreach row $parmsDef {
        lassign $row mandatory flag argname desc
        set mmark [expr {$mandatory eq "m" ? "*" : " "}]
        set argcol [expr {$argname eq "" ? "-" : "<$argname>"}]
        puts [format "  %-14s %s  %-12s %s" $flag $mmark $argcol $desc]
    }
    puts [format "  %-14s %s  %-12s %s" "-h" " " "-" "Show this help"]
    puts ""
    puts "  * = mandatory"
    puts ""
}
