# fs-real-setup.tcl
#
# Generated 2026-jul-28 courtesy of Claude (claude.ai), modeled directly
# on cit-fin-setup.tcl's paths/cpTag mechanism.
#
#
# ---------------------------------------------------------------------------

puts stderr "==> Loading fs-real-setup.tcl (v4)"
namespace eval ::wb::setup {}

proc ::wb::setup::main {ctx} {
  hilite -magenta "::wb::setup::main called $ctx"
  set form [$ctx form]

  # srp-util-fs.jar plus its dependency jars/zips all live flat in
  # ship\lib -- same folder the build script (build-srp-util-fs-v06.ps1)
  # writes srp-util-fs.jar into. Every archive in there becomes part of
  # the "srp-util-fs" classpath tag referenced by demo-excel and the
  # other Java tasks in fs-real-cfg.json.
  #
  # paths dict entries are DIRECTORIES, not individual files --
  # ::wb::exec::expandJavaPath scans each directory for *.jar/*.zip
  # itself (mtime-sorted) at build/launch time. See v4 changelog above.

  set cfgPath [$form cfgPath]
  set flowDir [file dirname $cfgPath]
  set libDir [file join $flowDir "java-lib"]

  if {![file isdirectory $libDir]} {
    error "fs-real-setup: lib folder not found at $libDir"
  }

  # Validation only (fail fast with a clear message) -- not what actually
  # gets stored in paths; expandJavaPath does its own scan of $libDir.
  set jarList [glob -nocomplain -directory $libDir -types f *.jar]
  set zipList [glob -nocomplain -directory $libDir -types f *.zip]
  set archiveCount [llength [concat $jarList $zipList]]

  if {$archiveCount == 0} {
    error "fs-real-setup: no jars/zips found in $libDir"
  }

  set paths [$form paths]
  dict set paths srp-util-fs [list $libDir]
  $form set paths $paths


  # cycleNo/month live in the globs table, so they persist across runs of
  # the flow. $ctx getGlob's default argument already means "existing
  # value if set, otherwise this default" -- see the v3 changelog above --
  # so no explicit exists-check or first-run branching is needed here.
  #
  # $ctx getGlob/setGlob work here even though no task is attached yet
  # (this runs at flow-boot time, before any task executes) -- they go
  # through Form's shared Globs table directly. See fs-objs.tcl v56.
  set cycleNo [$ctx getGlob cycleNo 1]
  $ctx setGlob cycleNo $cycleNo

  set month [$ctx getGlob month "January"]
  $ctx setGlob month $month

  # Sets the run-date glob to today's date, formatted yyyy-mmm-dd (lowercase),
  # every time this runs -- not persisted/defaulted like month/cycleNo, since
  # a run date should always reflect the current run, not a stored default.
  set runDate [string tolower [clock format [clock seconds] -format "%Y-%b-%d"]]
  $ctx setGlob run-date $runDate


  hilite -magenta "srp-util-fs setup at $libDir ($archiveCount jars/zips found)"
}
