# remedial-action-sync.tcl
#
# This script runs whenever the Task Run is clicked.
#
#  Updated 2026-jul-18 courtesy of Claude (claude.ai)
#    v1 -> v2:
#      (1) Gets the watched task's object -> $watched (from this task's
#          own whenFailNames, first entry).
#      (2) Replaces $watched's brief.json entirely with exactly two
#          keys: sCondCode -> GOOD, action -> a message naming the
#          cycle/event that triggered this (via $globs dget).
#      (3) Updates THIS task's own brief (sCondCode/action) to record
#          which watched task it hit.
#      (4) ::wb::run::refreshBriefStatusForTask $watched 1 -- syncs
#          $watched's in-memory status to match what was just written.
#          Not explicitly re-requested this round, kept anyway: without
#          it, step (2)'s file write wouldn't be visible in memory yet
#          when step (5) switches the view to it -- this was the whole
#          point of the strategy discussion this session.
#      (5) after idle [list ::wb::run::selectStep $idx] -- deferred, not
#          a direct call, so it isn't immediately overwritten by this
#          task's own automatic post-run render (signalTaskEnd fires
#          right after this proc returns and repaints the shared detail
#          panel with THIS task's status regardless of curIndex).
#
#    Two typos corrected from the instructions as given (flagged in
#    chat, not silently changed): "$glob dget event" -> "$globs dget
#    event" (matches the correctly-spelled $globs used just before it),
#    and the own-brief action message used $watched (the task OBJECT)
#    directly, which would print an internal Tcl handle, not a name --
#    used [$watched name] instead.
#
#    "cycle"/"event" globs: not confirmed to exist yet. If unset, dget
#    with no default returns the literal "?cycle?"/"?event?" rather than
#    erroring -- that literal text appearing means those globs still
#    need setting up somewhere, not that this code is broken.

puts stderr "==> Loading remedial-action-sync.tcl (v2)"
namespace eval ::wb::exec::sync {}


proc ::wb::exec::sync::execSyncTask {ctx} {
  set task [$ctx task]

  hilite -magenta "execSyncTask called for [$task name]"

  # --- (1) get the task object for the watched name -> $watched -------

  set watchedNames [$task whenFailNames]
  if {[llength $watchedNames] == 0} {
    hilite -red "remedial-action: no whenFailNames on this task -- nothing to reset"
    return
  }
  set watchedName [lindex $watchedNames 0]

  set idx [::wb::run::findTaskIndexByName $watchedName]
  if {$idx < 0} {
    hilite -red "remedial-action: watched task '$watchedName' not found -- nothing to reset"
    return
  }
  set watched [lindex [::wb::run::_tasks] $idx]

  set form  [$ctx form]
  set globs [$form globs]

  # --- (2) replace $watched's brief.json with exactly two keys --------

  set watchedAction "remedial action taken by cycle [$globs dget cycle] event [$globs dget event]"
  set watchedDict [dict create sCondCode "GOOD" action $watchedAction]

  if {[catch {
    dictAsJsonFile [$watched briefPath] $watchedDict ""
  } err]} {
    hilite -red "remedial-action: failed to write $watchedName's brief.json: $err"
    return
  }

  # --- update this task's own brief, recording what it hit ------------

  $ctx brief sCondCode "GOOD"
  $ctx brief "action" "remediated watched task [$watched name]"
  $ctx log "remediated watched task [$watched name]: $watchedAction"

  # --- (4) sync $watched's in-memory status to match the file ---------

  ::wb::run::refreshBriefStatusForTask $watched 1

  # --- (5) reset the current task, deferred ----------------------------

  after 0 [list ::wb::run::selectStep $idx]
}
