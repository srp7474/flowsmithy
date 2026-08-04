# Code generated on 2026-Feb-19 11:31  courtesy of chatGPT
# fs-core.tcl (v05)
# Changelog (skinny; full detail in CHANGELOG.md):
#   v05 (2026-jul-28): changelog moved to CHANGELOG.md; this header now a skinny per-version log
#   v04 (2026-jul-21): removed the whole dead registry-file apparatus (FS_REG_JSON/FS_REG_TCL, both path helpers)
#
# ============================================================
# fs-core.tcl
# Shared core constants + path helpers (no UI, no side effects)
# ============================================================

set ::FS_CORE_VERSION 05

puts stderr "==> Loading fs-core.tcl (v$::FS_CORE_VERSION)"

# ------------------------------------------------------------
# Core namespace
# ------------------------------------------------------------

namespace eval ::wb::core {
  variable baseDir ""
}

# ------------------------------------------------------------
# Base directory helper
# Returns directory containing the caller script
# ------------------------------------------------------------

proc ::wb::core::baseDir {} {
  variable baseDir
  if {$baseDir eq ""} {
    set baseDir [file dirname [info script]]
  }
  return $baseDir
}

# ------------------------------------------------------------
# gen directory helper
# Returns h:/tcl/gen when called from h:/tcl/src/*
# ------------------------------------------------------------

proc ::wb::core::genDir {} {
  set dir [file dirname [info script]]
  return [file join [file dirname $dir] gen]
}
