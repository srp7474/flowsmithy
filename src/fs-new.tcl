# Generated 2026-jul-28 courtesy of Claude (claude.ai)
# fs-new.tcl - v07
# Changelog (skinny; full detail in CHANGELOG.md):
#   v07 (2026-jul-28): changelog moved to CHANGELOG.md; this header now a skinny per-version log
#   v06 (2026-jul-18): package require Tk 8.6 -> Tk 8.6 9, loads under either Tcl/Tk 8.6 or 9.x
#   v05: templateDir now uses fsCfgGet home.dir instead of TCL_HOME env var
#   v04: simplified -- creation IS cloning; single code path (cloneFlow srcDir destName)
#   v03: cloneFlow overhaul -- per-file rename + fixupFlowRefs helper
#   v02: optional second argument enables clone-from-source mode
#   v01: initial version -- scaffold a new flow from template and open in configurator
#
# FlowSmithy - New Flow Creator
#
# Namespace: ::wb::new

package require Tk 8.6 9
package require json

namespace eval ::wb::new {
  variable VERSION "v07"
  puts stderr "==> Loading fs-new.tcl ($::wb::new::VERSION)"
}

source [file join [file dirname [info script]] fs-core.tcl]

set _wb_new_dir [file dirname [info script]]
set _wb_lib     [file join $_wb_new_dir tcl-lib.tcl]
if {![file exists $_wb_lib]} { error "Missing required file: $_wb_lib" }
source $_wb_lib
unset _wb_new_dir _wb_lib

# Load flowsmithy.cfg - mandatory
fsCfgLoad

# ---------------------------------------------------------------------------
# ::wb::new::log  msg
# ---------------------------------------------------------------------------
proc ::wb::new::log {msg} {
  catch { puts stderr $msg }
}

# ---------------------------------------------------------------------------
# ::wb::new::validateFlowName  name
#
# Returns "" if acceptable, or an error message string.
# Rules: 2-40 chars, lowercase letters/digits/hyphens, start with letter,
#        must not end with a hyphen.
# ---------------------------------------------------------------------------
proc ::wb::new::validateFlowName {name} {
  if {[string length $name] < 2 || [string length $name] > 40} {
    return "Flow name must be 2-40 characters."
  }
  if {![regexp {^[a-z][a-z0-9-]*[a-z0-9]$} $name]} {
    return "Flow name must be lowercase letters, digits, and hyphens only;\nmust start with a letter and not end with a hyphen."
  }
  return ""
}

# ---------------------------------------------------------------------------
# ::wb::new::templateDir
#
# Resolves the built-in flow-template directory from <home.dir>/templates.
# Uses fsCfgGet home.dir (from flowsmithy.cfg). Errors clearly if not found.
# ---------------------------------------------------------------------------
proc ::wb::new::templateDir {} {
  set homeDir [fsCfgGet home.dir]
  if {$homeDir eq ""} {
    error "home.dir is not set in flowsmithy.cfg"
  }
  set tplDir [file join $homeDir templates flow-template]
  if {![file isdirectory $tplDir]} {
    error "Built-in template not found: $tplDir\nPlease ensure <home.dir>/templates/flow-template exists."
  }
  return $tplDir
}

# ---------------------------------------------------------------------------
# ::wb::new::writeFile  path  content
# ---------------------------------------------------------------------------
proc ::wb::new::writeFile {path content} {
  set fh [open $path w]
  fconfigure $fh -encoding utf-8 -translation lf
  puts -nonewline $fh $content
  close $fh
  ::wb::new::log "  wrote: $path"
}

# ---------------------------------------------------------------------------
# ::wb::new::readFile  path
# ---------------------------------------------------------------------------
proc ::wb::new::readFile {path} {
  set fh [open $path r]
  fconfigure $fh -encoding utf-8
  set str [read $fh]
  close $fh
  return $str
}

# ---------------------------------------------------------------------------
# ::wb::new::isTextFile  path
#
# Returns 1 if the file appears to be text (by extension), 0 if binary.
# Text extensions are those we might usefully rename content in.
# ---------------------------------------------------------------------------
proc ::wb::new::isTextFile {path} {
  set ext [string tolower [file extension $path]]
  return [expr {$ext in {.tcl .json .md .txt .cfg .ini .yaml .yml .html .xml ""}}]
}

# ---------------------------------------------------------------------------
# ::wb::new::cloneDir  srcDir  destDir  srcName  destName
#
# Recursively clones srcDir into destDir.
# For every file:
#   - destination filename: srcName replaced with destName
#   - text files: content also has srcName replaced with destName
#   - binary files: copied verbatim
# destDir must not already exist (caller checks).
# ---------------------------------------------------------------------------
proc ::wb::new::cloneDir {srcDir destDir srcName destName} {
  file mkdir $destDir
  ::wb::new::log "  mkdir: $destDir"

  foreach srcPath [glob -nocomplain -directory $srcDir *] {
    set tail     [file tail $srcPath]
    set destTail [string map [list $srcName $destName] $tail]
    set destPath [file join $destDir $destTail]

    if {[file isdirectory $srcPath]} {
      # Recurse into subdirectory
      ::wb::new::cloneDir $srcPath $destPath $srcName $destName
    } else {
      if {[::wb::new::isTextFile $srcPath]} {
        # Read, substitute, write
        if {[catch {::wb::new::readFile $srcPath} content]} {
          ::wb::new::log "  WARNING: could not read $tail: $content"
          catch {file copy -force $srcPath $destPath}
          continue
        }
        set fixed [string map [list $srcName $destName] $content]
        if {[catch {::wb::new::writeFile $destPath $fixed} err]} {
          ::wb::new::log "  WARNING: could not write $destTail: $err"
        }
      } else {
        # Binary: copy verbatim
        if {[catch {file copy -force $srcPath $destPath} err]} {
          ::wb::new::log "  WARNING: could not copy $tail: $err"
        } else {
          ::wb::new::log "  copied (binary): $destTail"
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# ::wb::new::cloneFlow  destName  srcDir  srcName
#
# Core clone operation. Pure data — no UI.
#
# Arguments:
#   destName  new flow name (validated)
#   srcDir    full path to source flow directory
#   srcName   flow name token used in the source files (= [file tail $srcDir]
#             for a flow, or "flow-template" for the template)
#
# Steps:
#   1. Validate destName
#   2. Resolve flows root; confirm dest folder does not exist
#   3. Clone srcDir -> destDir with full rename of srcName -> destName
#      in both filenames and text file contents
#
# Returns dict: ok, msg, cfgPath
# ---------------------------------------------------------------------------
proc ::wb::new::cloneFlow {destName srcDir srcName} {
  # Validate destination name
  set nameErr [::wb::new::validateFlowName $destName]
  if {$nameErr ne ""} {
    return [dict create ok 0 msg $nameErr cfgPath ""]
  }

  # Resolve flows root
  if {[catch {::wb::lib::requireTclFlows} flowsDir]} {
    return [dict create ok 0 \
      msg "Cannot resolve flows directory:\n$flowsDir" cfgPath ""]
  }

  # Confirm dest folder does not exist
  set destDir [file join $flowsDir $destName]
  if {[file exists $destDir]} {
    return [dict create ok 0 \
      msg "Flow '$destName' already exists:\n$destDir\nAborting." cfgPath ""]
  }

  # Confirm source exists
  if {![file isdirectory $srcDir]} {
    return [dict create ok 0 \
      msg "Source directory not found:\n$srcDir" cfgPath ""]
  }

  ::wb::new::log "Cloning '$srcName' -> '$destName'"
  ::wb::new::log "  src:  $srcDir"
  ::wb::new::log "  dest: $destDir"

  # Clone recursively with rename
  if {[catch {::wb::new::cloneDir $srcDir $destDir $srcName $destName} err]} {
    # Attempt cleanup of partial dest
    catch {file delete -force $destDir}
    return [dict create ok 0 \
      msg "Clone failed:\n$err\n(partial dest removed)" cfgPath ""]
  }

  set cfgPath [file join $destDir "${destName}-cfg.json"]
  set msg "Flow '$destName' created from '$srcName'.\n$cfgPath"
  ::wb::new::log $msg
  return [dict create ok 1 msg $msg cfgPath $cfgPath]
}

# ---------------------------------------------------------------------------
# ::wb::new::run  destName  ?sourceFlow?  ?launchCfg?
#
# Public entry point called from fs-shell.tcl.
#
#   destName    the new flow name
#   sourceFlow  if non-empty, clone this existing flow (looked up in flows.dir);
#               if empty, clone the built-in flow-template from TCL_HOME/templates
#   launchCfg   1 (default) to open fs-cfg.tcl on success
#
# Returns a human-readable result string (for the shell to display).
# ---------------------------------------------------------------------------
proc ::wb::new::run {destName {sourceFlow ""} {launchCfg 1}} {

  if {$sourceFlow ne ""} {
    # Clone an existing named flow
    if {[catch {::wb::lib::requireTclFlows} flowsDir]} {
      return "ERROR: Cannot resolve flows directory:\n$flowsDir"
    }
    set srcDir  [file join $flowsDir $sourceFlow]
    set srcName $sourceFlow
  } else {
    # Clone the built-in template
    if {[catch {::wb::new::templateDir} srcDir]} {
      return "ERROR: $srcDir"
    }
    set srcName "flow-template"
  }

  set result [::wb::new::cloneFlow $destName $srcDir $srcName]

  if {![dict get $result ok]} {
    return "ERROR: [dict get $result msg]"
  }

  set cfgPath [dict get $result cfgPath]
  set msg     [dict get $result msg]

  if {$launchCfg} {
    if {[info commands tclrun] ne ""} {
      tclrun cfg $destName
    } else {
      ::wb::new::launchCfgStandalone $cfgPath
    }
  }

  return $msg
}

# ---------------------------------------------------------------------------
# ::wb::new::launchCfgStandalone  cfgPath
#
# Fallback: exec fs-cfg.tcl directly when not running inside fs-shell.
# ---------------------------------------------------------------------------
proc ::wb::new::launchCfgStandalone {cfgPath} {
  set script [file join [file dirname [info script]] fs-cfg.tcl]
  if {![file exists $script]} {
    ::wb::new::log "WARNING: fs-cfg.tcl not found at $script - cannot launch configurator"
    return
  }
  set tclsh [auto_execok tclsh]
  if {$tclsh eq ""} {
    ::wb::new::log "WARNING: cannot find tclsh - cannot launch configurator"
    return
  }
  ::wb::new::log "launching configurator: $script $cfgPath"
  set chan [open [list | $tclsh $script $cfgPath 2>@1] r]
  fconfigure $chan -blocking 0 -buffering line -encoding utf-8
  fileevent $chan readable [list ::wb::new::standaloneReadable $chan]
}

proc ::wb::new::standaloneReadable {chan} {
  if {[eof $chan]} {
    fileevent $chan readable {}
    catch {fconfigure $chan -blocking 1}
    catch {close $chan}
    return
  }
  while {[gets $chan line] >= 0} {
    puts $line
  }
}

# ---------------------------------------------------------------------------
# Standalone entry point
# Usage:
#   tclsh fs-new.tcl <flow-name>
#   tclsh fs-new.tcl <flow-name> <source-flow>
# ---------------------------------------------------------------------------
if {[info exists argv0] && [file tail $argv0] eq [file tail [info script]]} {
  puts stderr "==> fs-new.tcl standalone ($::wb::new::VERSION)"

  if {[llength $argv] < 1} {
    puts stderr "Usage: tclsh [file tail [info script]] <flow-name> ?source-flow?"
    exit 2
  }

  set _destName   [lindex $argv 0]
  set _sourceFlow [expr {[llength $argv] >= 2 ? [lindex $argv 1] : ""}]
  set _result     [::wb::new::run $_destName $_sourceFlow 1]
  puts $_result

  vwait forever
}
