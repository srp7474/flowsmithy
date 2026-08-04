# fs-objs.tcl (v61)
# Changelog (skinny; full detail in CHANGELOG.md):
#   v61 (2026-aug-01): added Task.staleRefTS (schema field + getter) -- the refreshStepStates freshness high-water mark a task's staleness was judged against, for fs-run.tcl's stale-manual-checkbox reset guard; also cleaned up a duplicate/misleading optErrCnt schema declaration found nearby
#   v60 (2026-jul-30): fixed text-opt FocusOut/Return/KP_Enter commit bindings only being attached when the opt had a "place" value -- a placeless text opt (e.g. custVal demo fields) got no commit trigger at all; also fixed a stray "uiRend" corrupting the KP_Enter binding
#   v59 (2026-jul-29): renamed bindVal -> custVal (schema field, getter, constructor read, debug dump) -- see CHANGELOG.md for why
#   v58 (2026-jul-28): file/directory opt controls (Input, Becudir, ...) -- value combobox now expands to fill available width, mode+Browse pushed to the right edge (aligned with other controls), live tooltip added showing the full untruncated value
#   v57 (2026-jul-28): changelog moved to CHANGELOG.md; this header now a skinny per-version log
#   v56 (2026-jul-28): Ctx.getGlob/setGlob (new getGlob; glob kept as alias) route through Form, bypassing Task
#   v55 (2026-jul-27): same variable-aliasing bug as v54, independently, in uiRender -- curValues/curPlaces
#   v54 (2026-jul-27): fixed Arg.parseValues producing literal "$valStr" instead of a real value (brace-quoting bug)
#   v53 (2026-jul-20): added Task.staleAfter -- optional "staleAfter" key, same pattern as dependsOn/whenFail
#   v52 (2026-jul-20): version-number cleanup only, no content change from golden-base src.zip
#   v50 (2026-jul-18): package require Tcl 8.6 -> Tcl 8.6 9, loads under either Tcl 8.6 or 9.x
#   v49 (2026-jul-18): fixed Task.dependsOnNames/whenFailNames always empty (wrong JSON keys since day one)

# Code generated on 2026-Mar-10 12:00  courtesy of chatGPT
#
# Dict-backed "objects" for the Workflow GUI.
# This version aligns with key fields seen in PSEC flow/gui PowerShell classes
# (Task.dependsOn, Task.whenFail, visibility, script type, etc).
#
# ---------------------------------------------------------------------------
# v19 schema enforcement + get/set protocol overhaul
#
# Major change:
#   - All ::wbobj::TclObj subclasses MUST implement method _schema {}.
#   - TclObj initializes declared fields from _schema defaults at construction.
#   - TclObj provides strict get/set:
#       * Unknown field -> hilite -red (once per object per run) then error.
#       * Known field -> get returns current value; set updates value.
#   - Subclasses updated on a best-efforts basis to:
#       * declare _schema
#       * use my set/my get internally (esp. constructors)
#       * route existing convenience methods through get/set
# ---------------------------------------------------------------------------


set ::FS_OBJS_VERSION 61
puts stderr "==> Loading fs-objs.tcl (v$::FS_OBJS_VERSION)"



#------------------ pure OO Objects ---------------------------
# Code generated on 2026-Feb-26 20:05  courtesy of chatGPT
# wb-arg.tcl  (initial Arg object)

package require Tcl 8.6 9
package require Tk

namespace eval ::wbobj {}

# ---- Option panel layout constants (tweakable) ------------------------------
if {![info exists ::wbobj::OPT_LABEL_CH]} { set ::wbobj::OPT_LABEL_CH 9 }   ;# label column (chars)
if {![info exists ::wbobj::OPT_PARM_CH]}  { set ::wbobj::OPT_PARM_CH  7 }   ;# parm column (chars)
if {![info exists ::wbobj::OPT_PARM_PX]}  { set ::wbobj::OPT_PARM_PX  60 }  ;# parm col min width (px)
if {![info exists ::wbobj::OPT_CTRL_PX]}  { set ::wbobj::OPT_CTRL_PX  220 } ;# ctrl col min width (px)
if {![info exists ::wbobj::OPT_ERR_PX]}   { set ::wbobj::OPT_ERR_PX   300 } ;# err  col min width (px)

# Code generated on 2026-Feb-26 20:05  courtesy of chatGPT
# Pure TclOO shell objects: TclObj + Form + Task + Arg
# - Form ctor takes (cfgDict cfgPath) and constructs Task objects immediately
# - No fallbacks: required keys must exist or we error
# - Task currently builds only the *shell* (args empty for now)
# - Task will later build Arg list during construction (next iteration)

namespace eval ::wbobj {}

# ---------------------------------------------------------------------------
# Helpers (strict key enforcement)
# This helps keep hand edited .json files valid so the rest of the engine can rely on good
# files.
# ---------------------------------------------------------------------------
proc ::wbobj::_requireKeys {d keys ctx} {
  foreach k $keys {
    if {![dict exists $d $k]} {
      error "$ctx: missing required key '$k'"
    }
  }
}

proc ::wbobj::_requireList {v ctx} {
  # Ensure v is a valid Tcl list (and return it)
  if {[catch {llength $v}]} { error "$ctx: expected list" }
  return $v
}

# ---------------------------------------------------------------------------
# Base class: TclObj
# - dumpDict/dumpStr: introspect all instance vars (debug)
# - toDict/applyDict: persist only whitelist (subclass overrides persistFields)
# ---------------------------------------------------------------------------
\
oo::class create ::wbobj::TclObj {
  # Base class for all Workbench objects.
  #
  # Schema-based field protocol (v24):
  #   - Subclasses MUST implement: method _schema {} -> dict of field->default
  #   - Base constructor initializes an internal dict of field values from schema defaults
  #   - get/set are schema-aware:
  #       * unknown field: hilite -red once per object per run, then continue
  #       * get unknown: returns ""
  #       * set unknown: still sets the field (so later get will return the value)
  #   - The "warn once" tracking is per-instance in _warned (dict: "op|field" -> 1)
  #
  # NOTE: This class intentionally stores all schema fields in an internal dict
  # (not Tcl variables named after each field). This avoids collisions with any
  # TclOO "variable fieldName" declarations in subclasses.

  variable _warned   ;# dict of "op|field" -> 1
  variable dyn       ;# free-form runtime dict for callers (not schema-enforced)
  variable vals      ;# dict of schema field values (and any unknown fields that were set)

  constructor {} {
    set dyn [dict create]
    set _warned [dict create]

    # Enforce schema contract and initialize declared fields to defaults.
    set schema [my _schema]
    set vals [dict create]
    foreach {k def} $schema {
      dict set vals $k $def
    }
  }

  # -------------------------------------------------------------------------
  # KISS field access: all domain fields are TclOO instance variables.
  # get/set validate the field name against the declared schema (instance vars).
  # Unknown field => hilite -red and error immediately (catch typos early).
  # -------------------------------------------------------------------------
  method schemaFields {} {
    # Default schema = all declared instance variables on this object.
    # Subclasses may override to further restrict allowed fields.
    return [info object vars [self]]
  }

  method getXX {field} {
    if {[lsearch -exact [my schemaFields] $field] < 0} {
      hilite -red "[my kind].get: unknown field '$field'"
      error "[my kind].get: unknown field '$field'"
    }
    my variable $field
    if {![info exists $field]} {
      hilite -red "[my kind].get: field '$field' is unset"
      error "[my kind].get: field '$field' is unset"
    }
    return [set $field]
  }

  method setXX {field value} {
    if {[lsearch -exact [my schemaFields] $field] < 0} {
      hilite -red "[my kind].set: unknown field '$field'"
      error "[my kind].set: unknown field '$field'"
    }
    my variable $field
    set $field $value
    return
  }


  # Subclasses MUST override.
  method _schema {} {
    error "[namespace tail [self class]]: missing required method _schema"
  }

  method _condGet {def fld} {
    return  [expr {[dict exists $def $fld] ? [dict get $def $fld] : ""}]
  }
  method kind {} { return [namespace tail [self class]] }
  method hash {} { return [namespace tail [self]] }

  method is {} { return [my get is] }

  method hashStr {} {
    return "[my is].[my hash]"
  }

  # Schema-aware getter.
  # Unknown field => hilite -red once + return "".
  method get {field {default __WB_NO_DEFAULT__}} {
    my variable vals
    set schema [my _schema]

    if {![dict exists $schema $field] && ![dict exists $vals $field]} {
      my _badField get $field
      if {$default ne "__WB_NO_DEFAULT__"} { return $default }
      return ""
    }

    if {[dict exists $vals $field]} {
      return [dict get $vals $field]
    }

    # Declared in schema but not present in vals (should not happen), fall back.
    if {$default ne "__WB_NO_DEFAULT__"} { return $default }
    return [dict get $schema $field]
  }

  # Schema-aware setter.
  # Unknown field => hilite -red once + still set + continue.
  method set {field value} {
    my variable vals
    set schema [my _schema]

    if {![dict exists $schema $field]} {
      my _badField set $field
      # still set (unknown field becomes part of vals for this run)
      dict set vals $field $value
      return $value
    }

    dict set vals $field $value
    return $value
  }

  method _badField {op field} {
    my variable _warned
    set key "${op}|${field}"
    if {![dict exists $_warned $key]} {
      dict set _warned $key 1
      hilite -red "[my kind].${op}: unknown field '${field}' on [my hashStr]"
      error "catch the bad code ${field}"
    }
    return
  }

  # Debug dump only declared schema fields (plus class/kind).
  # Introspect "First Class" fields from TclOO instance variables (no maintained list).
  # We treat schema-declared fields (from _schema) as "Work Fields".
  method _firstClassVars {} {
    set vars [info object vars [self]]

    # Internal bookkeeping vars in TclObj
    set internal { _warned dyn vals }

    # Remove internal + private-ish vars (leading underscore)
    set out {}
    foreach v $vars {
      if {[lsearch -exact $internal $v] >= 0} { continue }
      if {[string match "_*" $v]} { continue }
      lappend out $v
    }
    return $out
  }

  # Debug dump: Provide two dicts for dumping
  method dumpDictFC {} {
    set out [dict create kind [my kind] class [self class]]

    # First Class
    foreach k [lsort -dictionary [my _firstClassVars]] {
      my variable $k
      if {[array exists $k]} {
        dict set out $k [array get $k]
      } else {
        if {[info exists $k]} {
          dict set out $k [set $k]
        }
      }
    }
    return $out
  }

  method dumpDictWork {} {
    set out [dict create kind [my kind] class [self class]]

    # Work Fields (_schema)
    set schema [my _schema]
    foreach k [lsort -dictionary [dict keys $schema]] {
      if {![dict exists $out $k]} {
        dict set out $k [my get $k]
      }
    }
    return $out
  }

  method dumpStr {{spec ""} {indent 0}} {
    if {$spec eq ""} { set spec {} }
    if {[catch {llength $spec}]} {
      error "[my kind].dumpStr: spec must be a list of field names"
    }
    set pad [string repeat "  " $indent]
    set out ""
    append out "${pad}[my kind].[my is].[my hash]\n"

    append out "${pad}  --- First Class values ---\n"
    set d [my dumpDictFC]
    append out [my dumpGivenDict $spec $d $pad $indent]
    append out "${pad}  --- Work values ---\n"
    set d [my dumpDictWork]
    append out [my dumpGivenDict $spec $d $pad $indent]
    return $out
  }

  method dumpGivenDict {spec d pad indent} {
    set out ""
    foreach k [lsort -dictionary [dict keys $d]] {
      if {$k in {kind class}} continue
      set v [dict get $d $k]
      set inSpec [expr {[lsearch -exact $spec $k] >= 0}]
      set inObj  [expr {[lsearch -exact $spec "<$k>"] >= 0}]

      # object?
      if {[info object isa object $v]} {
        if {$inSpec} {
          append out "${pad}  $k:\n"
          append out [$v dumpStr $spec [expr {$indent + 2}]]
        } else {
          append out "${pad}  $k: ->[$v hashStr]\n"
        }
        continue
      }

      # list? (heuristic: field names ending in 's')
      set isList [my _looksPlural $k]
      if {$isList} {
        if {$inSpec} {
          append out "${pad}  $k:\n"
          foreach el $v {
            if {[info object isa object $el]} {
              append out [$el dumpStr $spec [expr {$indent + 2}]]
            } else {
              set pad2 [string repeat "  " [expr {$indent + 2}]]
              append out "${pad2}$el\n"
            }
          }
        } else {
          append out "${pad}  $k: [llength $v]\n"
        }
        continue
      }

      # scalar | marked dict
      if {$inSpec} { continue }
      if {$inObj} {
        if {[info object isa object $v]} {
          append out [$v dumpStr $spec [expr {$indent + 2}]]
          } else {
          append out "${pad} XXX $k: $v\n"
        }
      } else {
        append out "${pad}  $k: $v\n"
      }
    }
    return $out
  }



  method _looksPlural {k} {
    expr {[string match "*s" $k] && $k ni {is class}}
  }

  # Subclasses may override this if they have persistence requirements.
  method persistFields {} { return {} }

  method toDict {} {
    set out [dict create kind [my kind]]
    foreach f [my persistFields] {
      dict set out $f [my get $f]
    }
    return $out
  }

  method applyDict {d} {
    foreach f [my persistFields] {
      if {[dict exists $d $f]} {
        my set $f [dict get $d $f]
      }
    }
    return
  }
}

oo::class create ::wbobj::Arg {
  superclass ::wbobj::TclObj

  # first class fields
  variable argType     ;# Arg type. one of opt|parm|hook|runprop
  variable label       ;# label (unique)
  variable bindName    ;# name of code bound to argument | ""
  variable bReqd       ;# if required
  variable parm        ;# parm str sent to pgm or ""
  variable uiType      ;# UI control to implement data collection. For opt. input|radio|check|select
  variable desc        ;# description
  variable values      ;# multiple values for combo, radio
  variable places      ;# multiple places for combo, radio
  variable place       ;# place for input, checkbox
  variable hint        ;# hint for all
  variable propStr     ;# extra properties / descriptive string
  variable histTag     ;# shared history tag
  variable histDepth   ;# max shared history depth
  variable comboWidth  ;# combo width for file/directory/select
  variable fileType    ;# semicolon separated file patterns
  variable regexPat    ;# text regex validator
  variable regexMsg    ;# text regex fail msg
  variable custVal     ;# custom validator hook -- renamed from bindVal (2026-jul-29):
                        ;# the old name collided with a completely different,
                        ;# documented-but-different feature description (see
                        ;# CHANGELOG.md fs-objs.tcl v59)
  variable readonly    ;# make control readonly. Note ofteb readonly options can be replaced by parm definition
  variable initVal     ;# Initial value - useful for readonly text. Globable string. eg [glob _prod-tok]
  variable parmExec    ;# How to format parm value

  variable def         ;# definition dict from cfg
  variable dyn         ;# dynamic value dict

  method _schema {} {
    set s [dict create]
    dict set s is        "Arg"         ;# type tag
    dict set s optIdx    -1            ;# opt index (opts only)
    dict set s task      ""            ;# owning Task object
    dict set s value     ""            ;# current value
    dict set s optErr    ""            ;# option or parm has error (like validation)
    dict set s hooksProc ""            ;# actual validation proc implementation ptr
    dict set s isReadOnly false        ;# is control text readonly
    dict set s modeVal   ""            ;# persisted value for file, directory type
    dict set s parmVerb  ""            ;# how to populate parm. from parmExec
    dict set s parmDict  ""            ;# values for parm verb processing
    return $s
  }

  # first class getters
  method argType  {}     { my variable argType  ; return $argType  }
  method label    {}     { my variable label    ; return $label    }
  method bindName {}     { my variable bindName ; return $bindName }
  method bReqd    {}     { my variable bReqd    ; return $bReqd    }
  method parm     {}     { my variable parm     ; return $parm     }
  method uiType   {}     { my variable uiType   ; return $uiType   }
  method desc     {}     { my variable desc     ; return $desc     }
  method values   {}     { my variable values   ; return $values   }
  method places   {}     { my variable places   ; return $places   }
  method place    {}     { my variable place    ; return $place    }
  method hint     {}     { my variable hint     ; return $hint     }
  method propStr  {}     { my variable propStr  ; return $propStr  }
  method histTag  {}     { my variable histTag  ; return $histTag  }
  method histDepth {}    { my variable histDepth ; return $histDepth }
  method comboWidth {}   { my variable comboWidth ; return $comboWidth }
  method fileType {}     { my variable fileType ; return $fileType }
  method regexPat {}     { my variable regexPat ; return $regexPat }
  method regexMsg {}     { my variable regexMsg ; return $regexMsg }
  method custVal  {}     { my variable custVal  ; return $custVal  }
  method readonly {}     { my variable readonly ; return $readonly }
  method initVal  {}     { my variable initVal  ; return $initVal  }
  method parmExec {}     { my variable parmExec ; return $parmExec }

  # _schema getters
  method is         {} { return [my get is         ] }
  method optIdx     {} { return [my get optIdx     ] }
  method task       {} { return [my get task       ] }
  method value      {} { return [my get value      ] }
  method optErr     {} { return [my get optErr     ] }
  method hooksProc  {} { return [my get hooksProc  ] }
  method isReadOnly {} { return [my get isReadOnly ] }
  method modeVal    {} { return [my get modeVal    ] }
  method parmDict   {} { return [my get parmDict   ] }

  constructor {kindIn argDef taskObj {inIdx -1}} {
    next
    my set is       "Arg"
    my set task     $taskObj

    my variable argType  ; set argType  $kindIn
    my variable label    ; set label    [my _condGet $argDef label   ]
    my variable bindName ; set bindName [my _condGet $argDef bindName]
    my variable uiType   ; set uiType   [my _condGet $argDef uiType  ]

    my variable bReqd    ; set bReqd    [expr {[dict exists $argDef reqd] ? true : false}]
    my variable parm     ; set parm     [my _condGet $argDef parm    ]
    my variable desc     ; set desc     [my _condGet $argDef desc    ]
    my variable values   ; set values   [my _condGet $argDef values  ]
    my variable places   ; set places   [my _condGet $argDef places  ]
    my variable place    ; set place    [my _condGet $argDef place   ]
    my variable hint     ; set hint     [my _condGet $argDef hint    ]
    my variable propStr  ; set propStr  [my _condGet $argDef propStr ]
    my variable histTag  ; set histTag  [my _condGet $argDef histTag ]
    my variable histDepth ; set histDepth [my _condGet $argDef histDepth]
    if {$histDepth eq ""} { set histDepth 20 }
    my variable comboWidth ; set comboWidth [my _condGet $argDef comboWidth]
    my variable fileType ; set fileType [my _condGet $argDef fileType ]
    if {$fileType eq ""} { set fileType "*" }
    my variable regexPat ; set regexPat [my _condGet $argDef regexPat]
    my variable regexMsg ; set regexMsg [my _condGet $argDef regexMsg]
    my variable custVal  ; set custVal  [my _condGet $argDef custVal ]
    my variable readonly ; set readonly [expr {[dict exists $argDef readonly] ? true : false}]
    my variable initVal  ; set initVal  [my _condGet $argDef initVal ]
    my variable parmExec ; set parmExec [my _condGet $argDef parmExec]

    my variable dyn      ; set dyn [dict create]
    my variable def      ; set def [dict create {*}$argDef]

    # ----- specific fld adjustments
    my set optIdx -1
    if {[my argType] eq "opt"} {
      my set optIdx $inIdx
      if {[my bReqd] && $parm eq ""} {
        set parm $label ;#zap FC fld
      }
      if {[dict exists $def type]} {
        set ctlType [dict get $def type]
        my variable uiType; set uiType $ctlType
      }
      my set isReadOnly $readonly
    }
    if {[my argType] eq "parm"} {
      my set value "value tbd [my parm] [my _condGet $argDef parm    ]"
      my set optErr "have an error"

      set parmExec [my parmExec]
      my parseParmExec $parmExec

    }

  }

  # parses parmExec. Implemented formats
  #
  # copy:<glob-name>
  # term:<opt-label>?<glob-name>:<glob-name>
  # lit:<literal string>
  # eval:<evaluate string>
  # bind:tcl proc. implement later
  #

  method parseParmExec {parmExec} {

    set task [my task]
    #hilite -cyan "parse [$task name] $parmExec"

    set parmSpec ""

    if {[regexp {^([a-z]+):(.*)$} $parmExec -> verb rest]} {
        switch -- $verb {
            copy {
                if {[regexp {^([^:]+)$} $rest -> globName]} {
                    set parmSpec [dict create globName $globName]
                }
            }

            tern {
                if {[regexp {^([^?]+)\?([^:]+):(.+)$} $rest -> optLab globTrue globFalse]} {
                    set parmSpec [dict create \
                        optLab $optLab \
                        globTrue $globTrue \
                        globFalse $globFalse]
                }
            }

            eval { set parmSpec [dict create evalStr $rest] }

            lit {  set parmSpec [dict create litStr $rest]  }

        }
    }

    if {$verb eq ""} {
        error "Invalid parmExec verb '$parmExec' in task [$task name]"
    }

    if {$parmSpec eq ""} {
        error "Invalid parmExec $verb parms '$parmExec' in task [$task name]"
    }
    # store both if you want
    my set parmVerb $verb
    my set parmDict $parmSpec

  }


  #--- helpers
  method setValue {v} { my set value $v; return } ;# meaninless for opt type Args
  method setModeVal {v} { my set modeVal $v; return } ;# for file, directory

  method str {} {
    return "[my hashStr]<$label,$argType>"
  }

  method notVal {fld} {
    if {[my $fld] eq ""} {return true}
    return false
  }

  method hasVal {fld} {
    if {[my $fld] ne ""} {return true}
    return false
  }

  method _sortedDict {d pref} {
    set maxLen 30
    set lines {}

    # Guard: if not a valid dict, don't crash (and show what it was)
    if {[catch {dict size $d} err]} {
      lappend lines "$pref   <NOT A DICT> $err"
      lappend lines "$pref   raw=<$d>"
      return $lines
    }

    foreach k [lsort -dictionary [dict keys $d]] {
      set vStr [format "%s" [dict get $d $k]]
      if {[set vLen [string length $vStr]] > $maxLen} {
        set suffix "...<$vLen>"
        set keepLen [expr {$maxLen - [string length $suffix]}]
        set vStr "[string range $vStr 0 [expr {$keepLen - 1}]]$suffix"
      }
      lappend lines "$pref   [format %-10s $k] $vStr"
    }
    return $lines
  }


  method viewStr {} { # For debug window view args
    my variable def
    my variable dynData
    set lines {}
    lappend lines "---------- [my hashStr].[my label].[my argType] -----------"
    lappend lines "fld   optIdx     [my optIdx]"
    lappend lines "fld   task       [my task]"
    lappend lines "fld   label      [my label]"
    lappend lines "fld   uiType     [my uiType]"

    if {"" ne [my value   ]} {lappend lines "fld   value      [my value   ]"}
    if {"" ne [my bReqd   ]} {lappend lines "fld   bReqd      [my bReqd   ]"}
    if {"" ne [my parm    ]} {lappend lines "fld   parm       [my parm    ]"}
    #if {"" ne [my desc    ]} {lappend lines "fld   desc       [my desc    ]"}
    if {"" ne [my values  ]} {lappend lines "fld   values     [my values  ]"}
    if {"" ne [my places  ]} {lappend lines "fld   places     [my places  ]"}
    if {"" ne [my place   ]} {lappend lines "fld   place      [my place   ]"}
    #if {"" ne [my hint    ]} {lappend lines "fld   hint       [my hint    ]"}
    if {"" ne [my propStr ]} {lappend lines "fld   propStr    [my propStr ]"}
    if {"" ne [my histTag ]} {lappend lines "fld   histTag    [my histTag ]"}
    if {"" ne [my histDepth ]} {lappend lines "fld   histDepth  [my histDepth ]"}
    if {"" ne [my comboWidth ]} {lappend lines "fld   comboWidth [my comboWidth ]"}
    if {"" ne [my fileType ]} {lappend lines "fld   fileType   [my fileType ]"}
    if {"" ne [my regexPat]} {lappend lines "fld   regexPat   [my regexPat]"}
    if {"" ne [my regexMsg]} {lappend lines "fld   regexMsg   [my regexMsg]"}
    if {"" ne [my custVal ]} {lappend lines "fld   custVal    [my custVal ]"}
    if {"" ne [my isReadOnly ]} {lappend lines "fld   isReadOnly [my isReadOnly ]"}
    if {"" ne [my modeVal   ]} {lappend lines "fld   modeVal    [my modeVal   ]"}
    if {"" ne [my initVal ]} {lappend lines "fld   initVal    [my initVal ]"}
    #lappend lines ""

    lappend lines {*}[my _sortedDict $def def]
    #lappend lines ""
    lappend lines {*}[my _sortedDict $dyn dyn]

    return $lines;
  }

  # Control value backing store lives in ::wb::argVal(arrayIndex).
  # This avoids per-widget locals and makes retrieval easy later.
  method _uiVarName {} {
    # Use hash as stable per-object key
    return "::wb::argVal([my hash])"
  }

  method _prettyLabel {} {
    my variable label uiType
    set s $label
    if {$s eq ""} { set s $uiType }

    # prettify: underscores/hyphens -> spaces, trim, Title Case
    set s [string trim [string map {_ " " - " "} $s]]
    set s [string totitle $s]

    return "${s}:"
  }

  # Return the current UI value for this Arg (from its rendered control).
  # - For text w/placeholder: returns "" if placeholder is still showing.
  # - For check: returns 0/1.
  # - For radio/select: returns the backing value (not display text).
  method uiValue {} {
    my variable uiType place

    set vname [my _uiVarName]
    if {![info exists $vname]} { return "" }
    set v [set $vname]

    # Placeholder handling for text entries
    if {$uiType eq "text" && $place ne ""} {
      set phFlag "::wb::argPH([my hash])"
      if {[info exists $phFlag] && [set $phFlag]} {
        return ""
      }
      # extra safety: if it still equals place, treat as empty
      if {$v eq $place} { return "" }
    }

    # Normalize checkbox to 0/1
    if {$uiType eq "check"} {
      if {$v eq ""} { return 0 }
      if {[string is boolean -strict $v]} { return [expr {$v ? 1 : 0}] }
      return [expr {$v ne "0"}]
    }

    return $v
  }

  # allows values to be extracted from the globs table
  # format dyn:XXXX where XXXX is a globs list of values typically set up at run setup
  #
  # IMPORTANT: this method's result variable is deliberately named outVals,
  # NOT values (or places). "values" and "places" are declared with the
  # class-level `variable` command (see near the top of this class), which
  # in TclOO means EVERY method -- not just ones that say `my variable
  # values` -- automatically resolves a bare `values` to the OBJECT's own
  # instance variable. A previous version of this method used `set values
  # ...` for its local result, which silently overwrote the Arg's real
  # values/places fields as a side effect of every call. For a plain
  # literal list that's a harmless no-op (same list written back), but for
  # "dyn:xxx" it permanently replaced the dynamic marker with a one-time
  # resolved snapshot -- so after the first render, a "dyn:" values list
  # would stop tracking the live globs table and just show stale data on
  # every subsequent re-render. Using outVals avoids the aliasing entirely.
  method parseValues {valStr} {
    #hilite -cyan "parseValues $valStr"
    if {[catch {llength $valStr}]} {
      error "parseValues: '[my argType]' opt missing bad values: [my toString]"
    } elseif {[llength $valStr] > 1} {
      set outVals $valStr
    } else {
      if {[string match "dyn:*" $valStr]} {
        set globName [string range $valStr 4 end]
        #hilite -cyan "access $valStr $globName"
        set t [my task]
        set outVals [$t glob $globName]
        hilite -cyan "access.3 $valStr $globName $outVals"
      } else {
        # NOT {$valStr} -- that's Tcl brace-quoting, which suppresses
        # substitution and produces the literal 8-character string
        # "$valStr" every time (a real bug that shipped: it showed up as
        # a select control's default entry literally reading "$valStr").
        # Plain $valStr correctly passes through whatever the caller
        # gave us -- "" (no values/places specified) becomes an empty
        # list, same as before this branch runs "* January" et al, and a
        # single bare-word value becomes a proper 1-element list.
        set outVals $valStr
      }
    }
    return $outVals
  }

  # UI renderer (real widgets now).
  # Renders into $parent starting at $row and RETURNS the next row index.
  # One "slice" == one grid row for now.
  method uiRender {parent row} {
    my variable uiType bReqd def 

    set place  [my place]
    # NOTE: deliberately named curValues/curPlaces, NOT values/places.
    # "values" and "places" are declared with the class-level `variable`
    # command near the top of this class, which in TclOO means every
    # method automatically resolves a bare `values`/`places` to the
    # OBJECT's own instance variable -- even without `my variable values`
    # in this method. A previous version of this method used `values`/
    # `places` as its working copies and reassigned them after resolving
    # "dyn:xxx" glob references (see parseValues), which silently
    # overwrote the Arg's real fields as a side effect of rendering: after
    # the first render, "dyn:xxx" was permanently replaced by a one-time
    # resolved snapshot, so a dynamic values list would stop tracking the
    # live globs table on every subsequent re-render. curValues/curPlaces
    # avoid the aliasing entirely -- see the matching fix in parseValues.
    set curValues [my values]
    set curPlaces [my places]
    set hint   [my hint]
    set isReadOnly [my isReadOnly]
    set initVal [my initVal]

    set key [my hash]
    set labTxt [my _prettyLabel]
    set tipTxt $hint

    if {$uiType in {"select"}} {
      set dynVals [my parseValues $curValues]
      set dynPlaces [my parseValues $curPlaces]
      #hilite -cyan "select.access [llength $dynPlaces] $dynPlaces"
      set curValues $dynVals
      set curPlaces $dynPlaces
    }

    # If no hint and uiType=text and place is set, use place as tooltip
    if {$tipTxt eq "" && $uiType in {"text" "file" "directory"} && $place ne ""} {
      set tipTxt $place
    }

    # Ensure backing var exists and is initialized from Arg.value (suppress trace during UI build)
    set vname [my _uiVarName]
    if {![info exists $vname]} { set $vname "" }
    if {[info exists ::wb::run::UI_BUILDING]} { set ::wb::run::UI_BUILDING 1 }
    catch { set $vname [my value] }
    if {[info exists ::wb::run::UI_BUILDING]} { set ::wb::run::UI_BUILDING 0 }

    # Sync UI var -> Arg.value and trigger persistence (run-mode).
    if {[info commands ::wb::run::updateArgUiVal] ne ""} {
      # Remove any prior updateArgUiVal traces (avoid duplicates on rerender)
      foreach ti [trace info variable $vname] {
        if {[lindex $ti 0] eq "write"} {
          set cmd [lindex $ti 1]
          if {[string match "::wb::run::updateArgUiVal*" $cmd]} {
            catch { trace remove variable $vname write $cmd }
          }
        }
      }
      trace add variable $vname write [list ::wb::run::updateArgUiVal [self]]
    }


    # --- left label (always) ---
    ttk::label $parent.l_${key}_$row -text $labTxt -style WbOptTitle.TLabel -width $::wbobj::OPT_LABEL_CH -anchor e
    grid $parent.l_${key}_$row -row $row -column 0 -sticky ne -padx {0 10}

    # --- right cell container (the "slice") ---
    ttk::frame $parent.r_${key}_$row -style WbOpts.TFrame
    grid $parent.r_${key}_$row -row $row -column 1 -sticky ew
    grid columnconfigure $parent.r_${key}_$row 0 -weight 1

    set slice $parent.r_${key}_$row

    # slice columns: parm | ctrl | err
    set parmTxt [my parm]
    set errTxt  [my optErr]

    ttk::label $slice.parm -text $parmTxt -style WbOpts.TLabel -width $::wbobj::OPT_PARM_CH -anchor w
    ttk::frame $slice.ctrl -style WbOpts.TFrame
    ttk::label $slice.err  -text $errTxt  -style WbOpts.TLabel -foreground red -anchor e -justify right

    grid $slice.parm -row 0 -column 0 -sticky w  -padx {0 10}
    grid $slice.ctrl -row 0 -column 1 -sticky ew
    grid $slice.err  -row 0 -column 2 -sticky e  -padx {10 0}

    # fixed/weighted sizing (pixel minsize for err)
    grid columnconfigure $slice 0 -minsize $::wbobj::OPT_PARM_PX -weight 0
    grid columnconfigure $slice 1 -minsize $::wbobj::OPT_CTRL_PX -weight 1
    grid columnconfigure $slice 2 -minsize $::wbobj::OPT_ERR_PX -weight 0

    set ctrl $slice.ctrl

    # control area: entry fills; select sits on right
    grid columnconfigure $ctrl 0 -weight 1
    grid columnconfigure $ctrl 1 -weight 0
    # Tooltip over the entire row (label + parm + ctrl + err)
    if {$tipTxt ne "" && [info commands ::wb::run::tipAttach] ne ""} {
      ::wb::run::tipAttach $slice $tipTxt
      ::wb::run::tipAttach $parent.l_${key}_$row $tipTxt
      ::wb::run::tipAttach $slice.parm $tipTxt
      ::wb::run::tipAttach $slice.ctrl $tipTxt
      ::wb::run::tipAttach $slice.err  $tipTxt
    }

    # --- uiType dispatch ---
    switch -exact -- $uiType {

      check {
        # checkbox: place text to the right; clicking text toggles checkbox
        grid columnconfigure $ctrl 0 -weight 0
        grid columnconfigure $ctrl 1 -weight 1
        ttk::checkbutton $ctrl.cb -variable $vname
        ttk::label $ctrl.txt -text $place -style WbOpts.TLabel
        grid $ctrl.cb  -row 0 -column 0 -sticky w
        grid $ctrl.txt -row 0 -column 1 -sticky w -padx {6 0}

        bind $ctrl.txt <Button-1> [list ::wb::run::argToggleBool $vname]
        bind $ctrl.cb  <Button-1> [format {::wb::run::argToggleBool {%s}; break} $vname]

      }

      text {
        # entry with placeholder-like behavior using bindings
        ttk::entry $ctrl.ent -textvariable $vname

        # readonly: disable + light-gray fieldbackground
        if {$isReadOnly} {
          if {![info exists ::wbobj::STYLE_INIT(ReadonlyEntry)]} {
            ttk::style configure WbReadonly.TEntry
            ttk::style map WbReadonly.TEntry -fieldbackground {disabled #e8e8e8} -foreground {disabled #000000}
            set ::wbobj::STYLE_INIT(ReadonlyEntry) 1
          }
          $ctrl.ent configure -style WbReadonly.TEntry
          $ctrl.ent state disabled
        }
        grid $ctrl.ent -row 0 -column 0 -columnspan 2 -sticky ew
        grid columnconfigure $ctrl 0 -weight 1

        # phFlag needs to exist regardless of whether this opt has a
        # "place" value -- FocusOut/Return/KP_Enter below are no longer
        # conditional on place, so they need somewhere valid to pass.
        # argEntryFocusOut/onTextFocusOut only ever dereference phFlag's
        # value when place != "", so a placeholder-less opt never
        # actually reads it -- this is just making sure the variable
        # name is always valid to bind against.
        set phFlag "::wb::argPH([my hash])"

        if {$place ne ""} {
          # placeholder: show place when empty, but mark it so we can clear on focus-in
          if {![info exists $phFlag]} { set $phFlag 1 }
          if {[set $vname] eq ""} {
            # Set placeholder without firing traces
            if {[info exists ::wb::run::UI_BUILDING]} { set ::wb::run::UI_BUILDING 1 }
            set $vname $place
            if {[info exists ::wb::run::UI_BUILDING]} { set ::wb::run::UI_BUILDING 0 }
            set $phFlag 1
          }

          bind $ctrl.ent <FocusIn> [list ::wb::run::argEntryFocusIn $vname $phFlag $place]
        } else {
          if {![info exists $phFlag]} { set $phFlag 0 }
        }

        # FocusOut / Return / KP_Enter (commit-on-blur) previously lived
        # INSIDE the "if {$place ne ""}" block above, which meant a text
        # opt with no "place" value (e.g. demo-options' CustValDemo) got
        # NO commit trigger at all -- not just no Enter-as-blur, no
        # FocusOut either. The only reason it ever appeared to update was
        # as an incidental side effect of some OTHER control on the same
        # task (a combobox, say) triggering its own full-panel re-render.
        # Hoisted out here so every text opt gets this regardless of
        # whether it also happens to have a placeholder.
        #
        # Also fixed a real, separate bug on the KP_Enter line: a stray
        # "uiRend" was concatenated directly onto the end of the bound
        # script with no whitespace, turning "break" into the invalid
        # command "breakuiRend" -- this would have thrown a Tcl error on
        # Numpad Enter for any field that DID have a placeholder (the
        # only ones that previously got this binding at all).
        bind $ctrl.ent <FocusOut> [list ::wb::run::onTextFocusOut [my task] $vname $phFlag $place]
        bind $ctrl.ent <Return>   [format {::wb::run::persistOptsNow {%s}; focus .; break} [my task]]
        bind $ctrl.ent <KP_Enter> [format {::wb::run::persistOptsNow {%s}; focus .; break} [my task]]
      }

      file -
      directory {
        set cbWidth [my comboWidth]
        if {![string is integer -strict $cbWidth] || $cbWidth < 8} { set cbWidth 32 }

        set histVals {}
        if {[info commands ::wb::run::argHistoryValues] ne ""} {
          set histVals [::wb::run::argHistoryValues [self]]
        }

        set comboVals {}
        if {[set $vname] ne ""} { lappend comboVals [set $vname] }
        foreach item $histVals {
          if {$item eq ""} { continue }
          if {[lsearch -exact $comboVals $item] < 0} { lappend comboVals $item }
        }

        set modeVar [::wb::run::argPathModeVar [self]]
        set modeInit [string trim [my modeVal]]
        if {$modeInit eq ""} { set modeInit old }
        if {[lsearch -exact {old new any} $modeInit] < 0} { set modeInit old }
        set $modeVar $modeInit

        # Column 0 (the value combobox) gets the expanding weight so it
        # fills whatever width isn't needed by the fixed-size mode
        # dropdown / Browse button / trailing place label -- which pushes
        # those three to the right edge of the control area, lining up
        # with the right edge of other opt types (e.g. a "text" entry's
        # sticky ew across its full columnspan). Previously all four
        # columns had weight 0, so the whole cluster hugged the left with
        # a large unclaimed gap on the right, and the value combobox's
        # fixed character -width was the only thing determining how much
        # of a long path was visible before truncating.
        grid columnconfigure $ctrl 0 -weight 1
        grid columnconfigure $ctrl 1 -weight 0
        grid columnconfigure $ctrl 2 -weight 0
        grid columnconfigure $ctrl 3 -weight 0

        log "arg [my label] cbWidth $cbWidth"

        ttk::combobox $ctrl.cb -state normal -textvariable $vname -values $comboVals -width $cbWidth
        ttk::combobox $ctrl.mode -state readonly -textvariable $modeVar -values {old new any} -width 4
        ttk::button $ctrl.browse -text "Browse" -style WbBrowse.TButton             -command [list ::wb::run::argBrowsePath [self] $vname $modeVar]

        grid $ctrl.cb     -row 0 -column 0 -sticky ew
        grid $ctrl.mode   -row 0 -column 1 -sticky w -padx {8 6}

        # Trailing padx after Browse is breathing room before the place
        # label -- only needed when that label is actually shown (see
        # below). Without it, Browse should sit flush against the true
        # right edge of the control area, lining up with other controls.
        if {$place ne ""} {
          grid $ctrl.browse -row 0 -column 2 -sticky w -padx {0 8}
        } else {
          grid $ctrl.browse -row 0 -column 2 -sticky w
        }

        # Only grid the trailing place-text label when there's actually
        # text to show it -- an empty ttk::label still reserves a sliver
        # of column-3 width even with nothing visible in it, which was
        # leaving Browse's right edge a few pixels short of lining up
        # with other controls' right edge (e.g. a "text" opt's entry).
        # Most file/directory opts (Input, Becudir, ...) don't set
        # "place" at all, so this is the common case.
        if {$place ne ""} {
          ttk::label $ctrl.txt -text $place -style WbOpts.TLabel -anchor w
          grid $ctrl.txt -row 0 -column 3 -sticky w
        }

        set modeTip "old - file must exist\nnew - file must not exist\nany - existence not checked"

        if {[info commands ::wb::run::tipAttach] ne ""} {
          ::wb::run::tipAttach $ctrl.mode $modeTip
        }

        # Live tooltip on the value field itself: shows the full path even
        # when the combobox is too narrow to display all of it. Uses the
        # dynamic variant (re-reads $vname fresh on every hover) rather
        # than a plain static tipAttach, so it stays correct as the user
        # types/browses to a new value instead of showing a stale snapshot
        # from render time.
        if {[info commands ::wb::run::tipAttachDynamic] ne ""} {
          ::wb::run::tipAttachDynamic $ctrl.cb $vname
        }

        bind $ctrl.cb <FocusOut> [list ::wb::run::argPathFocusOut [self] $vname $modeVar]
        bind $ctrl.cb <Return>   [format {::wb::run::argPathAccept {%s} {%s} {%s}; focus .; break} [self] $vname $modeVar]
        bind $ctrl.cb <KP_Enter> [format {::wb::run::argPathAccept {%s} {%s} {%s}; focus .; break} [self] $vname $modeVar]
        bind $ctrl.cb <<ComboboxSelected>> [list ::wb::run::argPathAccept [self] $vname $modeVar]
        bind $ctrl.mode <<ComboboxSelected>> [list ::wb::run::argPathAccept [self] $vname $modeVar]
      }

      radio {
        # radio group horizontal; values are control values; places are display text
        # default indicated by leading "*"
        set vals {}
        set defVal ""

        foreach v $curValues {
          set s $v
          if {[string length $s] && [string index $s 0] eq "*"} {
            set s [string range $s 1 end]
            if {$defVal eq ""} { set defVal $s }
          }
          lappend vals $s
        }

        # Apply default only when unset (so user can change it later)
        if {[set $vname] eq ""} {
          if {$defVal ne ""} {
            set $vname $defVal
            my set value $defVal
          } else {
            set $vname ""
          }
        }

        set n [llength $vals]
        for {set i 0} {$i < $n} {incr i} {
          set vv [lindex $vals $i]
          set pp [expr {$i < [llength $curPlaces] ? [lindex $curPlaces $i] : $vv}]

          ttk::radiobutton $ctrl.rb$i -variable $vname -value $vv
          ttk::label       $ctrl.lb$i -text $pp -style WbOpts.TLabel

          grid $ctrl.rb$i -row 0 -column [expr {$i*2}]   -sticky w
          grid $ctrl.lb$i -row 0 -column [expr {$i*2+1}] -sticky w -padx {4 12}

          bind $ctrl.lb$i <Button-1> [list set $vname $vv]
          bind $ctrl.rb$i <Button-1> [format {set {%s} {%s}; break} $vname $vv]
        }

        # keep group left-justified: add stretch column at end
        set endCol [expr {$n*2}]
        for {set c 0} {$c < $endCol} {incr c} {
          grid columnconfigure $ctrl $c -weight 0
        }
        grid columnconfigure $ctrl $endCol -weight 1
        ttk::label $ctrl.fill -text "" -style WbOpts.TLabel
        grid $ctrl.fill -row 0 -column $endCol -sticky ew

      }

      select {
        # combobox: shows places; sets control var to corresponding values
        # default indicated by leading "*"
        set vals {}
        set disp {}

        set defIndex -1
        set i 0
        foreach v $curValues {
          set s $v
          set isDef 0
          if {[string length $s] && [string index $s 0] eq "*"} {
            set s [string range $s 1 end]
            set isDef 1
          }
          lappend vals $s
          set pp [expr {$i < [llength $curPlaces] ? [lindex $curPlaces $i] : $s}]
          lappend disp $pp
          if {$isDef && $defIndex < 0} { set defIndex $i }
          incr i
        }

        # optional none row
        if {!$bReqd} {
          set vals [linsert $vals 0 ""]
          set disp [linsert $disp 0 "---- none ---"]
          if {$defIndex >= 0} { incr defIndex } ;# shift by 1
        }

        set dvar "::wb::argDisp([my hash])"
        if {![info exists $dvar]} { set $dvar "" }

        ttk::combobox $ctrl.cb -state readonly -values $disp -textvariable $dvar -width 26
        ttk::frame $ctrl.sp -style WbOpts.TFrame
        grid $ctrl.cb -row 0 -column 0 -sticky w
        grid $ctrl.sp -row 0 -column 1 -sticky ew
        grid columnconfigure $ctrl 1 -weight 1

        # init selection
        # prefer existing arg value; else use default (marked with "*"); else (if optional) select "none"
        set cur [my value]

        # if no explicit value yet, apply default (if any)
        if {$cur eq "" && $defIndex >= 0} {
          set cur [lindex $vals $defIndex]
          # also seed the Arg value so downstream sees the default
          my set value $cur
        }

        # pick display index based on cur
        set selIndex -1
        if {$cur ne ""} {
          set selIndex [lsearch -exact $vals $cur]
        } elseif {!$bReqd} {
          set selIndex 0  ;# implied none row
        }

        if {$selIndex >= 0} {
          set $dvar [lindex $disp $selIndex]
          set $vname [lindex $vals $selIndex]
        } else {
          # required + no match + no default: show blank with empty value
          set $dvar ""
          set $vname $cur
        }

        bind $ctrl.cb <<ComboboxSelected>> [list ::wb::run::argComboSelected $dvar $vname $disp $vals]
      }

      default {
        error "uiType [my uiType] specified as type in .cfg file not implemented"
      }
    }

    return [expr {$row + 1}]
  }


  # persistence later (task options.json):
  # method persist {} { ... }
}

# ---------------------------------------------------------------------------
# Task (shell)
# - Built from cfg node dict + seq + derived paths from cfgPath
# - Args list is empty for now (next iteration Task builds Args)
# ---------------------------------------------------------------------------
oo::class create ::wbobj::Task {
  superclass ::wbobj::TclObj

  # first class fields (from json def)
  variable name                   ;# step name
  variable title                  ;# title
  variable type                   ;# tcl-int | java | ...
  variable desc                   ;# description
  variable dependsOnNames         ;# depends on tasks names
  variable whenFailNames          ;# only show when one in task list fails
  variable staleAfter             ;# raw "nnn[unit]" string; only enforced on the FIRST task (fs-run.tcl), read as-is here
  variable runprops               ;# dictionary of properties such as javaMain

  method _schema {} {
    set s [dict create]
    dict set s is "Task"          ;# type tag
    dict set s seq 0              ;# sequence number in form
    dict set s taskDir ""         ;# directory for task assets
    dict set s helpPath ""        ;# resolved help path (optional)
    dict set s briefPath ""       ;# resolved brief.json path (runtime)
    dict set s briefTS 0          ;# brief.json timestamp or 0 does not exist
    dict set s briefDict ""       ;# brief.json parsed contents
    dict set s logPath ""         ;# resolved runlog.txt path (runtime)
    dict set s execPath ""        ;# resolved exec script path (runtime)
    dict set s execHand ""        ;# handler proc name (routing)
    dict set s execMode ""        ;# sync|async
    dict set s args {}            ;# list of Arg objects
    dict set s form ""            ;# owning Form
    dict set s setupErr ""        ;# setup error text
    dict set s optErrCnt 0        ;# number errors in Opt block
    dict set s hooksTS 0          ;# timestamp of <taskname>-hooks.tcl file or 0 (first time) or -1 (not needed)
    dict set s bHooksOK 0         ;# bHooksOK : 1 - hooks valid. 0 - hooks not valid but reported
    dict set s stepState ""       ;# STALE (new prio steps) or FRESH (not STALE)
    dict set s staleRefTS 0       ;# refreshStepStates' lastFreshTS at the moment this task's
                                   ;# staleness was judged -- the timestamp of whichever earlier
                                   ;# task set the freshness high-water mark this one is being
                                   ;# compared against (not necessarily the immediately preceding
                                   ;# task -- flows can skip steps). Used to tell "user already
                                   ;# started redoing a stale manual task's checkboxes since it
                                   ;# went stale" apart from "still showing leftover checkmarks
                                   ;# from before" (see _resetStaleManualCheckboxes in fs-run.tcl).
    dict set s compState ""       ;# Completion status. GOOD, FAIL or TRAP from Brief sCondCode. TRAP no brief of no sCondCode
    dict set s stepIcon ""        ;# Computed icon name
    return $s
  }

  # first class getters
  method name           {}     { my variable name           ; return $name            }
  method title          {}     { my variable title          ; return $title           }
  method type           {}     { my variable type           ; return $type            }
  method desc           {}     { my variable desc           ; return $desc            }
  method dependsOnNames {}     { my variable dependsOnNames ; return $dependsOnNames  }
  method whenFailNames  {}     { my variable whenFailNames  ; return $whenFailNames   }
  method staleAfter     {}     { my variable staleAfter     ; return $staleAfter      }
  method runprops       {}     { my variable runprops       ; return $runprops        }

  # _schema getters
  method is        {} { return [my get is        ] }
  method seq       {} { return [my get seq       ] }
  method taskDir   {} { return [my get taskDir   ] }
  method helpPath  {} { return [my get helpPath  ] }
  method briefPath {} { return [my get briefPath ] }
  method logPath   {} { return [my get logPath   ] }
  method execPath  {} { return [my get execPath  ] }
  method execHand  {} { return [my get execHand  ] }
  method execMode  {} { return [my get execMode  ] }
  method args      {} { return [my get args      ] }
  method form      {} { return [my get form      ] }
  method setupErr  {} { return [my get setupErr  ] }
  method optErrCnt {} { return [my get optErrCnt ] }
  method hooksTS   {} { return [my get hooksTS   ] }
  method bHooksOK  {} { return [my get bHooksOK  ] }
  method briefTS   {} { return [my get briefTS   ] }
  method briefDict {} { return [my get briefDict ] }
  method stepState {} { return [my get stepState ] }
  method staleRefTS {} { return [my get staleRefTS ] }
  method compState {} { return [my get compState ] }
  method stepIcon  {} { return [my get stepIcon  ] }


  constructor {node seqIn cfgPath formObj} {

    # Strict required fields for Task shell
    ::wbobj::_requireKeys $node {name title type desc} "Task"

    next
    my variable name           ; set name            [my _condGet $node name           ]
    my variable title          ; set title           [my _condGet $node title          ]
    my variable type           ; set type            [my _condGet $node type           ]
    my variable desc           ; set desc            [my _condGet $node desc           ]
    my variable dependsOnNames ; set dependsOnNames  [my _condGet $node dependsOn ]
    my variable whenFailNames  ; set whenFailNames   [my _condGet $node whenFail  ]
    my variable staleAfter     ; set staleAfter      [my _condGet $node staleAfter]
    my variable runprops       ; set runprops        [my _condGet $node runprops       ]

    my set is    "Task"
    my set seq   $seqIn
    set flowRoot [file dirname [file normalize $cfgPath]]
    set tDir [file join $flowRoot tasks $name]
    my set taskDir   $tDir
    my set helpPath  [file join $tDir "$name-help.md"]
    my set briefPath  [file join $tDir "brief.json"]
    my set logPath   [file join $tDir "runlog.txt"]
    my set execPath  ""
    my set execHand  ""
    my set execMode  ""
    my set form  $formObj
    my set args  {}
    my set setupErr ""


    # Shell only for now
    # ---- transfer runprops ----------------------------------
    if {[dict exists $node runprops]} {
    }
    # ---- build Arg objects from opts ----------------------------------
    set seenLabels [dict create]
    set argLst {}
    if {[dict exists $node opts]} {
      set optList [dict get $node opts]

      set optIdx -1
      foreach optDef $optList {
        # basic validation
        if {![dict exists $optDef label]} {
          error "Task '$name': opt missing 'label'"
        }
        set label [dict get $optDef label]
        set label [string tolower $label]
        if {[dict exists $seenLabels $label]} {
          error "Label $label is not unique in task $name"
        }
        dict set seenLabels $label 1

        if {![dict exists $optDef type]} {
          error "Task '$name': opt missing 'type'"
        }

        # kind is always "opt" for now
        set kind "opt"

        # create Arg object (pass this Task as parent)
        incr optIdx
        set a [::wbobj::Arg new $kind $optDef [self] $optIdx]

        lappend argLst $a
      }
    }

    # Build parm args (parms[] -> Arg objects, argType=parm)
    if {[dict exists $node parms]} {
      set parmList [dict get $node parms]

      set parmIdx -1
      foreach parmDef $parmList {

        if {![dict exists $parmDef parm]} {
          error "Task '$name': parm missing 'parm'"
        }
        incr parmIdx
        #set label $parmIdx
        dict set parmDef label [format "%02d:" $parmIdx] 
        set kind "parm"
        set a [::wbobj::Arg new $kind $parmDef [self] $parmIdx]
        lappend argLst $a
      }
    }
    my set args $argLst
  }

  method getTypedArgs {kind} {
    set args [my get args]
    set out {}
    foreach a $args {
      if {[$a argType] eq $kind} { lappend out $a }
    }
    return $out
  }

  method findArg {lab} {
    set args [my get args]
    foreach a $args {
      if {[$a label] eq $lab} { return $a }
    }
    return ""
  }

  method toString {} {
    return "Task<seq=$seq name=$name type=$type args=[llength $args]>"
  }

  method setSetupErr {err} { ;# only
    if {$err eq ""} {
      my set setupErr ""
      return
    }
    if {[my setupErr] eq ""} {my set setupErr $err }
  }

  method globs {} {
    set form [my form]
    return [$form globs]
  }

  method glob {key {defValue "??"}} {
    set form [my form]
    if {$defValue eq "??"} {set defValue "?${key}?"}
    return [$form glob $key $defValue]
  }


  # used to replace the dictionary with a new one.
  method repBriefDict(dict ts) {
    my set briefDict $dict;
    my set briefTS ts;
  }

  # special logic for manual tasks
  method canTaskRun {} {
    set icon [my stepIcon]
    set args [my getTypedArgs opt];

    if {[llength $args] == 0} { return 0; }
    foreach arg $args {
      if {[$arg uiType] eq "check" && ![isTrue [$arg value]]} {return 0;}
    }
    return 1;
  }

}

# ---------------------------------------------------------------------------
# Form (shell)
# - ctor takes (cfgDict cfgPath) and constructs Task objects immediately
# - No fallbacks: requires cfgDict keys: title, tasks
# ---------------------------------------------------------------------------
oo::class create ::wbobj::Form {
  superclass ::wbobj::TclObj
  variable cfgPath title tasks
  variable selSeq globs   ;# runtime fields (globs is a ::wbobj::Globs object)
  variable ui

  method _schema {} {
    set s [dict create]
    dict set s is "Form"                ;# type tag
    dict set s cfgPath ""               ;# cfg path used to load
    dict set s title ""                 ;# form title
    dict set s tasks {}                 ;# list of Task objects
    dict set s selSeq 0                 ;# selected task seq
    dict set s globs ""                 ;# ::wbobj::Globs object handle (shared runtime globs)
    dict set s paths dict create]       ;# dictionary of named paths used for -CP construction and other equivalents
    dict set s ui [dict create]         ;# UI runtime dict
    return $s
  }

  constructor {cfgDict cfgPathIn} {
    #log "form const: $cfgDict $cfgPathIn"
    ::wbobj::_requireKeys $cfgDict {title tasks} "Form"

    next
    my set ui [dict create formObj [self]]
    my set is "Form"
    my set cfgPath $cfgPathIn
    my set title   [dict get $cfgDict title]

    my set selSeq 0
    my set globs  [::wbobj::Globs new]
    my set paths  [dict create]

    # tasks list from cfg (strict list)
    set taskNodes [::wbobj::_requireList [dict get $cfgDict tasks] "Form.tasks"]
    #log "form const: $taskNodes"
    set tskLst {}

    set i 0
    foreach node $taskNodes {
      incr i
      # Each node must be a dict with required keys checked in Task constructor
      lappend tskLst [::wbobj::Task new $node $i $cfgPathIn [self]]
    }
    my set tasks $tskLst
  }

  method uiDict {}  { return [my get ui] }
  method cfgPath {} { return [my get cfgPath] }
  method title {}   { return [my get title] }
  method tasks {}   { return [my get tasks] }

  method selSeq {}  { return [my get selSeq] }
  method globs {}   { return [my get globs] }   ;# returns ::wbobj::Globs handle
  method paths {}   { return [my get paths] }   ;# returns clone of dict. OK as s/b readonly

  method taskBySeq {n} {
    foreach t [my get tasks] {
      if {[$t seq] == $n} { return $t }
    }
    return ""
  }

  method toString {} {
    return "Form<title=[my title] tasks=[llength [my tasks]] cfgPath=[my cfgPath]>"
  }

  # These methods ensure that only one copy of the globs table exists.
  # globs is a ::wbobj::Globs object (shared by reference).
  method glob {key {defValue ""}} {
    set g [my globs]
    return [$g dget $key $defValue]
  }

  method setGlob {key value} {
    set g [my globs]
    $g dset $key $value
    return
  }
}




# --------------------------------------------------------------------------
# Ctx
# - Context object passed to registry hooks and tcl-int procs.
# - Pointers to Arg/Task/Form and other runtime state.
# ---------------------------------------------------------------------------
oo::class create ::wbobj::Ctx {
  superclass ::wbobj::TclObj
  method _schema {} {
    set s [dict create]
    dict set s is "Ctx"                ;# type tag
    dict set s arg ""                  ;# current Arg object
    dict set s task ""                 ;# current Task object
    dict set s form ""                 ;# current Form object
    dict set s execArg ""              ;# execution argument object/string
    dict set s src ""                  ;# caller/source tag
    dict set s scriptDir ""            ;# caller/source tag
    # tcl-int additions
    dict set s briefDict [dict create] ;# Brief dictionary
    dict set s logLines {}             ;# log lines
    return $s
  }



  constructor {} {
    next
    my set is "Ctx"
    my set arg ""
    my set task ""
    my set form ""
    my set execArg ""
    my set src ""
    my set briefDict [dict create]
    my set logLines  {}
    my set scriptDir [::wb::run::fetchScriptDir]
  }

  method persistFields {} { return {is arg task form execArg src} }
  method arg {}                { return [my get arg] }
  method task {}               { return [my get task] }
  method form {}               { return [my get form] }
  method globs {}              { set form [my form]; return [$form globs] }
  method execArg {}            { return [my get execArg] }
  method src {}                { return [my get src] }
  method briefDict {}          { return [my get briefDict] }
  method logLines {}           { return [my get logLines] }
  method scriptDir {}          { return [my get scriptDir] }




  method setArg {v} { my set arg $v; return }
  method setTask {v} { my set task $v; return }
  method setForm {v} { my set form $v; return }
  method setExecArg {v} { my set execArg $v; return }
  method setSrc {v} { my set src $v; return }


  # ------------------------------------------------------------------
  # Globs access -- getGlob / setGlob / glob (legacy name)
  #
  # Ctx is the core object passed to setup scripts, exit functions, and
  # other registry hooks -- and reading/updating the Globs table is one
  # of the main things that code does. Those hooks are NOT guaranteed to
  # have a task attached: a flow-boot setup script's Ctx is built from
  # the Form alone (see ::wbobj::buildCtx / ::wb::run::bootRuntime), so
  # its task field is "". A previous version of these methods routed
  # through [my task] -> $task globs, which crashed with "invalid
  # command name """ whenever they were called from exactly that kind of
  # hook (real incident: a *-setup.tcl script calling $ctx setGlob).
  #
  # Fixed to go through [my globs] (-> [$form globs]) instead, for two
  # reasons, not just to dodge the crash:
  #   1. It works everywhere a Ctx exists, task-attached or not.
  #   2. It's not even a loss of precision: Task's OWN glob/globs methods
  #      (see ::wbobj::Task) just forward to [my form] themselves --
  #      there is no separate task-level Globs store to begin with, only
  #      the one shared Globs object living on Form. Going through Task
  #      was always an unnecessary extra hop to the exact same object.
  # This mirrors Form's own glob/setGlob methods exactly (same dget/dset
  # pattern) -- Ctx, Task, and Form should all read as "the same globs
  # table, accessed from wherever you happen to be standing."
  #
  # getGlob is the preferred name going forward. glob is kept as an
  # alias (delegating to getGlob) since it predates this fix and nothing
  # about its signature needs to change -- just what it routes through.
  # ------------------------------------------------------------------
  method getGlob {key {defValue ""}} {
    set g [my globs]
    return [$g dget $key $defValue]
  }

  method glob {key {defValue "??"}} {
    if {$defValue eq "??"} { set defValue "?${key}?" }
    return [my getGlob $key $defValue]
  }

  method setGlob {key value} {
    set g [my globs]
    $g dset $key $value
    return
  }

  method brief {key value} {
    set d [my get briefDict]
    dict set d $key $value
    my set briefDict $d
  }

  method log {line} {
    set lines [my get logLines]
    lappend lines $line
    my set logLines $lines
  }

  # ---------------------- helpers ----------------------
  method opt {optName} { ;# return value of named opt. logs if not found
    set t [my task]
    log "opt for $optName $t"
    set optArgs [$t getTypedArgs opt]
    foreach a $optArgs {
      if {[$a label] eq $optName} {
        return "[$a value]"
      }
    }
    hilite -red "opt value lookup failed to find $optName"
  }

}

proc ::wbobj::buildCtx {from {arg ""}} {
  set ctx [::wbobj::Ctx new]
  if {[$from is] eq "Form"} {
    $ctx setForm $from
  } else {
    $ctx setTask $from
    set form [$from form]
    $ctx setForm $form
  }
  if {$arg ne ""} { $ctx set arg $arg }
  return $ctx
}


# ---------------------------------------------------------------------------
# ExecResp
#   Execution engine response object. This reports execution STATUS (engine-level),
#   not task semantics.
# ---------------------------------------------------------------------------
oo::class create ::wbobj::ExecResp {
  superclass ::wbobj::TclObj

  method _schema {} {
    set s [dict create]
    dict set s is "ExecResp"      ;# type tag
    dict set s status ""          ;# NOT_STARTED|START_FAILED|RUNNING|DONE
    dict set s task ""            ;# connected task
    dict set s mode ""            ;# sync|async
    dict set s engine ""          ;# tcl-int|tcl-ext|java|...
    dict set s exitCode ""        ;# integer or ""
    dict set s errMsg ""          ;# start/runtime error
    dict set s runDir ""          ;# directory for runlog/brief
    dict set s pid ""             ;# process id (async)
    dict set s startedAt 0        ;# epoch ms (TS number)
    dict set s endedAt 0          ;# epoch ms (TS number)
    return $s
  }

  constructor {} {
    next
    my set is "ExecResp"
  }

  # Convenience accessors (route through get/set)
  method status {}    { return [my get status] }
  method mode {}      { return [my get mode] }
  method task {}      { return [my get task] }
  method engine {}    { return [my get engine] }
  method exitCode {}  { return [my get exitCode] }
  method errMsg {}    { return [my get errMsg] }
  method runDir {}    { return [my get runDir] }
  method pid {}       { return [my get pid] }
  method startedAt {} { return [my get startedAt] }
  method endedAt {}   { return [my get endedAt] }

  method markStarted {} {
    #hilite -cyan "mark started"
    set ts [clock milliseconds]
    my set startedAt $ts
  }

  method markEnded { cc {msg "no=msg"}} {
    #hilite -cyan "mark started $cc $msg"
    set ts [clock milliseconds]
    my set endedAt $ts
  }

  method duration {} {
    set startTS [my startedAt]
    set endTS   [my endedAt]
    if {$startTS <= 0 || $endTS <= 0} { return "0.0? secs" }

    set durSecs [expr {($endTS - $startTS) / 1000.0}]
    if {$durSecs <= 0} { set durSecs 0.01 }

    if {$durSecs < 60} {
        return [format "%.2f secs" $durSecs]
    }

    if {$durSecs < 3600} {
        set mins [expr {$durSecs / 60.0}]
        return [format "%.1f mins" $mins]
    }

    set hrs [expr {$durSecs / 3600.0}]
    return [format "%.1f hrs" $hrs]
  }

  method startedAtStr {} {
    set ts [my startedAt]3
    if {$ts <= 0} { return "?startedAt?" }

    set secs [expr {$ts / 1000}]
    return [clock format $secs -format "%Y-%m-%d %H:%M:%S"]
  }
}


# Code generated on 2026-Mar-04 15:30  courtesy of chatGPT
# ---------------------------------------------------------------------------
# Globs
#   Shared mutable “globs” container (by reference). Holds a dict internally.
#   Designed to be passed around (Ctx/Form/etc.) as an object handle so updates
#   are seen everywhere.
#
#  Keys
#   keys are snake-case strings.
#
#   those starting with an ~ are not seen and not persisted
#
#   those starting with an + are not seen but are persisted
#
# ---------------------------------------------------------------------------
oo::class create ::wbobj::Globs {
  superclass ::wbobj::TclObj

  method _schema {} {
    set s [dict create]
    dict set s is   "Globs"        ;# type tag
    dict set s dict [dict create]  ;# internal globs dict
    dict set s needsPersist false  ;# There are updates taht needs persisting
    return $s
  }

  constructor {} {
    next
    my set is "Globs"
    my set dict [dict create]
  }

  # Optional: persist if you ever serialize Globs objects
  method persistFields {} { return {is dict} }

  # Convenience accessors
  method dict {} { return [my get dict] }   ;# returns a VALUE copy (ok for debug/serialize)
  method needsPersist {} { return [my get needsPersist] }

  method exists {key} {
    set d [my get dict]
    return [dict exists $d $key]
  }

  method dget {key {defValue ""}} {
    set d [my get dict]
    if {$defValue eq ""} { set defValue "?$key?" }
    if {[dict exists $d $key]} { return [dict get $d $key] }
    return $defValue
  }

  method dset {key value} {
    set d [my get dict]
    dict set d $key $value
    my set dict $d
    if {[string index $key 0] ne "~"} {
      my setDirty
    }
    return
  }

  method unset {key} {
    set d [my get dict]
    if {[dict exists $d $key]} {
      dict unset d $key
      my set dict $d
      if {[string index $key 0] ne "~"} {
        my setDirty
      }
    }
    return
  }

  method keys {} {
    set d [my get dict]
    return [dict keys $d]
  }

  method setDirty {} {
    my set needsPersist true
  }

}
