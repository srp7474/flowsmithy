# fs-demo-setup.tcl
#
# This script runs whenever the fs-run.tcl boots using the fs-demo-cfg.json file
#
#  Created by fs-cfg.tcl on 2026-may-20:16:45
#  Updated 2026-jul-18 courtesy of Claude (claude.ai)
#    v1 -> v2:
#      (1) formatGlobs wired into main() -- was defined but never called.
#      (2) Dropped the "date-stamp" sample glob (would visibly date the
#          demo video every time it's re-run/re-recorded).
#      (3) Added "computer-name" -- [info hostname], proves the flow is
#          actually running on a specific real machine, not a server.
#      (4) Added "run-count" -- persisted glob, incremented on every boot.
#          Demonstrates state genuinely persisting across runs (same
#          dyn.json mechanism already used for fin-year/month/proj in
#          wb-demo), not just within a single run.
#      (5) Added "~tcl-version" as a HIDDEN glob ([info patchlevel]).
#          Hidden (~-prefixed) globs are intentionally excluded from
#          persistence (see ::wbobj::Globs::dset -- dset only calls
#          setDirty, which triggers the dyn.json write, for non-~ keys),
#          so this is recomputed fresh every boot rather than saved --
#          which is fine, since it's cheap to compute and shouldn't be
#          stale anyway.
#      java path setup (formatJavaPaths) left commented out/dormant,
#      as-is -- picking that back up later.
#
# ---------------------------------------------------------------------------
puts stderr "==> Loading fs-demo-setup.tcl (v2)"
namespace eval ::wb::setup {}
proc ::wb::setup::main {ctx} {
  global env
  hilite -magenta "::wb::setup::main called $ctx for fs-demo"
  set form [$ctx form]
  #::wb::setup::formatJavaPaths ctx
  ::wb::setup::formatGlobs $ctx
}
# format java paths example
proc ::wb::setup::formatJavaPaths { ctx } {
  global env
  set form [$ctx form]
  if {[info exists env(PSEC_V4_UTILS)]} {
      set utils $env(PSEC_V4_UTILS)
      set path1 [file join $utils gael-core out-lib]
      set path2 [file join $utils gael-core lib]
      set path3 [file join $utils gael-core libaux]
      set paths [$form paths]
      dict set paths gael-util [list $path1 $path2 $path3]
      $form set paths $paths
      hilite -magenta "::wb::setup::formatJavaPaths $paths"
  } else {
    error "lost env vbl PSEC_V4_UTILS"
  }
}
# fs-demo globs: computer-name, run-count (persisted), ~tcl-version (hidden)
proc ::wb::setup::formatGlobs { ctx } {
  set form  [$ctx form]
  set globs [$form globs]

  # (1) Computer name -- real, machine-specific, proves this is running
  # locally rather than against some server.
  $globs dset "computer-name" [info hostname]

  # (2) cycle -- read current value (0 if never set), increment,
  # write back. Because "cycle" doesn't start with ~, dset marks the
  # globs object dirty and it gets written to fs-demo-dyn.json on persist,
  # same as fin-year/month/proj already do in wb-demo.
  set cycle [$globs dget "cycle" 0]
  incr cycle
  $globs dset "cycle" $cycle
  set event [$globs dget "event" 0]
  $globs dset "event" $event

  # (3) TCL/Tk version -- hidden (~) glob: available for [glob ~tcl-version]
  # interpolation in any desc/parm, but never written to disk.
  $globs dset "~tcl-version" [info patchlevel]

  hilite -magenta "::wb::setup::formatGlobs computer-name=[$globs dget computer-name] run-count=[$globs dget run-count] ~tcl-version=[$globs dget ~tcl-version]"
}
