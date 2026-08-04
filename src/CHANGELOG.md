# FlowSmithy Source Changelog

Full detail, alphabetical by file, newest to oldest within each file. This
is the complete blow-by-blow history that used to accumulate at the top of
each `.tcl` file. Each source file now keeps its own compact, skinny
one-liner per version (accumulating, newest-to-oldest) in its own header
for quick in-file reference -- this file is where the full story behind
any of those one-liners lives.

Scope: this covers only the core `src/*.tcl` engine files. Flow-level
exit/setup scripts (e.g. `fs-real-setup.tcl`) keep their own inline
changelog as-is and are not part of this convention.

Date is omitted where the original entry never recorded one (mostly
entries from before this dated-changelog convention started).

---

## fs-cfg.tcl

### v179 (2026-jul-29)
Removed the duplicate `::wb::lib::requireTclFlows` definition -- see tcl-lib.tcl v50 for the full story. This file had its own copy (reading `flows.dir` from `flowsmithy.cfg`) that happened to override an older, separate `env(TCL_FLOWS)`-based definition in `tcl-lib.tcl` purely by load order (this file sources `tcl-lib.tcl`, then redefines the proc afterward). `fs-clone.tcl` and `fs-new.tcl` call the same proc with no override of their own, so they were silently at the mercy of whichever definition happened to be loaded last -- an order-dependent, not structurally-guaranteed, single source of truth. Steve's directive: `flowsmithy.cfg` is the one source of truth, full stop, no environment-variable fallback anywhere except `fs-shell.tcl`'s own bootstrap (which genuinely can't avoid it -- it has to locate the FlowSmithy installation before it can even find `flowsmithy.cfg` to read). The canonical, flowsmithy.cfg-based definition now lives in `tcl-lib.tcl` alone; this file's copy is gone.

### v177 (2026-jul-27)
openContextHelpWin's "window already exists" branch previously just raised the window unconditionally, ignoring whether the helpPath argument had actually changed. Since Task Help and Flow Help both use a single fixed window path (.wbTaskHelp / .wbFlowHelp) reused across different tasks/flows, this meant: open Task Help for task A, close nothing, select task B, click "View Task Help" again -> the window just raised, still showing task A's content under a title now claiming to be task B's help. Fixed: the existing- window branch now compares the requested helpPath against what's already tracked for that window (contextHelpPath, normalized) and, if different, updates the title/path label/tracking and re-renders before raising -- same-file re-opens still just raise, cheaply, as before.

### v176 (2026-jul-27)
close a gap in fs-help.tcl v33's cross-file help:/help-same: link tracking. Flow Help (.wbFlowHelp) and Task Help (.wbTaskHelp) windows are built by openContextHelpWin/_contextHelpRender, which render via ::wb::help::_mdIntoText directly and never go through ::wb::help::mdRender -- so mdRender's curFileMap/curTitleMap tracking never ran for them. A help:/help-same: link clicked inside one of these windows would resolve relative to the process's cwd instead of the actual help file's folder. Fixed:

(1) _contextHelpRender now records curFileMap/curTitleMap for its window after every (re-)render, same as mdRender does.

(2) openContextHelpWin now binds <Destroy> to a new _contextHelpCleanup proc, which clears both fs-cfg.tcl's own per-window tracking (contextHelpMtime/Path/Title/AfterID -- this already had no cleanup at all, a pre-existing minor leak) and, via ::wb::help::_cleanupWindow, fs-help.tcl's tracking too.

### v175 (2026-jul-21)
fixed Apply never enabling after editing staleAfter -- Steve caught this immediately on testing v174. Two separate bugs, both mine, both from the same root cause (v174 added the widgets and the commit logic, but missed wiring them into the existing dirty-detection machinery):

(1) panelCurrentState (the dict compared against a snapshot to compute panelIsDirty) never included staleAfterVal/ staleAfterUnit -- so even if a change WAS noticed, it could never register as "different from the snapshot".

(2) panelTrackVar's write-trace is only attached to a hardcoded list of panel(*) variables (flowName/flowTitle/taskName/ taskTitle/taskDesc/taskType) -- staleAfterVal/staleAfterUnit weren't in that list, so editing them fired no trace at all, meaning panelUpdateDirty never even got called to begin with. Both fixed: staleAfterVal/staleAfterUnit added to panelCurrentState's returned dict, and added (with matching initialization) to the traced- variable list. Radiobutton -variable writes go through the same plain Tcl variable-write mechanism as an entry's -textvariable, so no separate handling was needed for the unit radio buttons vs. the integer entry.

### v174 (2026-jul-21)
added Configurator UI for staleAfter (ISSUE-14), task mode only, and only visible on the first task in a flow -- shares the DependsOn/WhenFail checklists' grid row, toggled to show exactly when those are hidden (per Steve: "we have space because dependsOn/ whenFail are not visible" there). Two fields, per spec: a plain integer entry (blank/0 = off, not saved at all) and a fixed radio set for the unit (secs/mins/hours/days/weeks/months/years -- must match fs-run.tcl's _parseStaleAfterSeconds exactly, since these two files are separate processes and this one can't call that parser directly). New: panelToggleStaleAfter (mirrors panelToggleTaskChecklists). Changed: task-panel widget creation/grid (new staleAfterL/staleAfterF widgets), panelSetupTask's add-mode init and edit-mode populate (parses an existing "nnn[unit]" string back into the two fields), and panelApplyTask (validates the integer, builds the string, commits with the same conditional set/unset idiom already used for dependsOn/ whenFail). A genuinely bad value (non-numeric/negative) surfaces via panelErrMsg rather than being silently treated as off. Known, accepted edge case: a task forced to show its DependsOn/WhenFail checklists for orphan-display reasons even while having no CURRENT prior tasks could theoretically want the same grid space as staleAfter at once -- see the comment on panelToggleStaleAfter.

### v173 (2026-jul-21)
removed the dead registry-file load entirely from bootConfigurator -- regJsonPath/regDict (and the "variable regDict {}" namespace declaration further up). Traced first (per Steve's suspicion it might be obsolete): ::wb::core::regJsonPath was genuinely called at boot, but the data it loaded was used for exactly one diagnostic log line and nothing else anywhere in this file -- a leftover of the pre-v144 registry/hookName-based parm builder system, already replaced by the current Type-combo Add Parm dialog. Steve's call: "blow it away entirely, it belongs to a track we never took." Matching removal on the fs-core.tcl side (FS_REG_JSON/FS_REG_TCL constants and both path- helper procs) -- see that file's own changelog. Bonus: this also fully resolves the earlier wb-reg-sys.* stale-filename concern (ISSUE-01) -- there's no longer any filename to be stale about.

### v172 (2026-jul-17)
package require Tk 8.6 -> Tk 8.6 9, so this loads under either Tcl/Tk 8.6 or 9.x (single-version pin was refusing to start at all against a 9.x install -- confirmed "version conflict" error tested directly). Applied against the golden-base src.zip supplied 2026-jul-18 -- no other changes made to this file.

### v171
(1) Removed cloneTaskFromSameFlow and cloneTaskFromOtherFlow -- confirmed dead code. Both were left in place at v153 as "candidates for the fs-clone real clone-execution plumbing" (see that changelog entry below), but the actual implementation (::wb::clone::onCloneButtonClick in fs-clone.tcl, v06+) reimplements the insert/copy/rename logic inline instead of calling either one. Neither proc had any remaining caller anywhere in the source. cloneListFlows, cloneTaskNamesFromFlow, and cloneRenameTaskFile are untouched -- cloneRenameTaskFile is still live, called directly from fs-clone.tcl's onCloneButtonClick.

### v170
(1) Main window icon lookup (openCfg) switched from $::env(TCL_HOME) to [fsCfgGet home.dir], matching every other path resolution in this file. This was the last direct env(TCL_HOME) reference left in fs-cfg.tcl -- everything else moved to home.dir/flows.dir back at v120. No functional change if TCL_HOME and home.dir happen to be the same directory on this machine; matters once someone runs FlowSmithy without TCL_HOME set (e.g. from a packaged install).

### v169
(1) Labeling consistency: the mode identifier "runtime" renamed to "runprop" everywhere it's live code (the Cfg Mode select box's -values list, every curMode/mode eq comparison, getTaskFieldForMode/normTaskFieldForMode's literal mode arg, the switch case labels in itemPanelApply/validateTask/fieldForMode/ modeTitle). modeTitle now returns "Runprop" instead of "Runtime" for button captions (Edit/Remove/Apply etc.), matching the existing singular-caption convention already used for "Option"/ "Parm". The select box itself now shows "runprop" instead of "runtime", consistent with the other all-lowercase mode values (flow/task/options/parms). The runprops dialog/grid code (openAddRunpropWin, uiLoadRunpropsGrid, runpropDlg, etc.) already used correct "Runprop" naming throughout and needed no changes -- only the mode identifier itself was inconsistent. Historical changelog entries mentioning "runtime" left as-is (accurate record of what those versions actually did).

### v168
(1) REVERT of v167. v167 changed runprops from a plain dict to a list of {key,value} objects based on one non-conforming sample (wb-demo's demo-set-context task, which uses a flat array and apparently was never actually run through fs-run.tcl). That was wrong -- the real, working format (matching fs-run.tcl and most existing cfg files, e.g. cit-aud) is a plain JSON object: "runprops": {"javaMain": "...", "cpTag": "..."} which is exactly what this file already did before v167. Every v167 change reverted: normTaskFieldForMode (runtime back to dict-mode), uiLoadRunpropsGrid, uiRemoveItem, uiSelectItem, _taskRunpropKeyExists, addRunpropCommit, editRunpropCommit, openAddRunpropWin's edit preload -- all back to dict get/set/ keys/for, as they were at v166. The actual bug was purely in tcl-lib.tcl's write-side schema (see that file's v46 changelog); nothing here needed to change at all.

### v166
(1) Edit Runprop examples now filtered to the locked key's own group only -- the key is effectively a "type" once it's fixed (can't be changed in Edit mode), so showing every key's examples there made little sense. _addRunpropBuildExamples takes an optional filterKey; openAddRunpropWin passes the current key in Edit mode, omits it (shows everything) in Add mode. Falls back to a plain "(no examples for key '...')" message for a key with no curated examples (e.g. a custom key). Examples header text also updated in Edit mode to say "click to paste a value" since key can't be touched there anyway.

### v165
(1) Dropped the recipe examples from _runpropExamples -- recipes are a task-level concept only, not a useful runprops pattern. Key list is now javaMain/cpTag/procExit/manageApp.

### v164
(1) Removed Clone from runtime mode too (added to the same hide-list as flow/options/parms in uiUpdateGlobalButtons). Nothing else to remove -- uiCloneItem never had a runtime-specific branch, it was already just falling through to the generic "not yet implemented" log line, as noted.

(2) /

(3) Implemented Add and Edit Runprop, sharing one dialog (openAddRunpropWin) the same way Parms does: editIndex "" -> Add, integer -> Edit (key field locked, same convention as parm name / option label in Edit mode). Runprops have no "type" field of their own (unlike opts/parms) -- they're a flat key/value dict, so the dialog is just Key + Value with no type selector. Examples panel (_runpropExamples) uses only real key/value patterns mined from the sample flows (cit-agm, cit-aud, cit-fin, cit-web, run-gael, wb-devp), grouped by key and reduced to unique patterns: javaMain, cpTag, procExit, manageApp, recipe. Dozens of distinct javaMain class names collapsed to 3 representative namespace examples rather than being enumerated, since the class name is task-specific and not itself a reusable pattern. Validation mirrors Parms exactly: live, on every keystroke -- empty key, invalid characters in key (letters/digits/underscore/ hyphen only, same rule as parm names), duplicate key (self excluded in Edit mode via _taskRunpropKeyExists), and empty value all disable the Add/Save button with an inline message. Commit path mirrors Parms too: addRunpropCommit/editRunpropCommit both call itemPanelSetDirty (so the "Apply Runprop(s) Change" button enables correctly, matching the fix already made for Parms) and validateRunprops (already existed, just wasn't wired to anything before). New procs: _runpropExamples, _addRunpropBuildExamples, _addRunpropPasteExample, _taskRunpropKeyExists, validateRunpropForm, runpropCommit, addRunpropCommit, editRunpropCommit, openAddRunpropWin. uiAddItem/uiEditItem's runtime branches (previously "not implemented") now call it.

### v163
(1) Edit Parm implemented by reusing the Add Parm dialog: openAddParmWin now takes an optional editIndex. Add mode is unchanged; Edit mode preloads type/parm/parmExec/hint from the existing parm (type is inferred from the parmExec prefix via new _parmTypeFromExec, since parms have no separate stored type field), locks the parm-name entry (same convention as the Option editor locking Label in Edit mode -- rename isn't supported here, remove+re-add instead), and relabels the commit button "Save Parm". New parmCommit dispatcher (mirrors commitOptSave) routes to addParmCommit or the new editParmCommit based on addParmDlg(isEdit). uiEditItem's parms branch, previously just "not implemented", now calls openAddParmWin $curItemIndex.

(2) validateAddParmForm's duplicate-name check is now edit-aware: _taskParmNameExists takes an excludeIndex so editing a parm doesn't collide with itself.

(3) parm names are now restricted to letters/digits/underscore/hyphen -- no spaces, no other punctuation. Same live validation, disables Add/Save Parm with an inline message.

(4) Fixed "Apply Parm(s) Change" (the item-panel button at the bottom of the parms/options grid -- separate from the top Save button) never enabling after adding or editing a parm: addParmCommit and editParmCommit were both missing the ::wb::cfg::itemPanelSetDirty call that fs-opts.tcl's commitOptAdd/commitOptEdit already make for options -- parms just never had the equivalent call. Both now match the options commit path exactly.

### v162
(1) Removed Clone Parm: uiUpdateGlobalButtons now hides the global Clone button for parms mode too (same as flow/options). No dedicated Clone Parm code existed beyond the generic "not yet implemented" fallback in uiCloneItem, so hiding the button was the whole fix here.

(2) /

(3) Add Parm examples: the example's comment (e.g. "current year glob") now also becomes the hint text -- the examples table never had a real hint field, only this comment string used for display, so hint was never populated at all before. _addParmPasteExample now sets both parmExec and hint together and clears them when the clicked example doesn't specify them (previously it only ever set parmExec and left everything else however a prior click had left it).

(4) Add Parm dialog buttons getting clipped off the bottom, even after manually resizing: centerWin never clamped its window size to the actual screen size, so a dialog whose real content needed more room than expected (Windows DPI-scaled font metrics, etc.) could end up taller than the screen itself -- not recoverable by dragging the window bigger, since there's no more screen to grow into. centerWin now clamps to screen size minus a margin; this is a shared helper so it also protects every other dialog built on it (Rename Task, opt editor, etc.), not just this one. Also removed the same -height 2 label-clipping bug as the Rename Task dialog had, on this dialog's own error label.

(5) Add Parm form now validates live (every keystroke in parm/ parmExec, plus on type change and example paste): empty name, duplicate name against this task's existing parms (_taskParmNameExists), and an unreplaced parmExec placeholder all set an inline error and disable the Add Parm button -- previously none of this was live, only checked once when Add was actually clicked, and there was no duplicate-name check at all.

### v161
(1) Removed Clone Option entirely: uiCloneItem's "options" branch (which called ::wb::cfg::openOptEditor $curItemIndex clone) is gone, and uiUpdateGlobalButtons now hides the global Clone button for options mode the same way it already does for flow mode -- so there's no Clone button showing at all in options mode. The corresponding openOptEditor "clone" mode code was removed from fs-opts.tcl (now v13); see that file's changelog for the rest.

### v160
(1) Rename Task dialog: buttons were getting clipped off the bottom whenever a validation error appeared. Root cause: centerWin sets an explicit wm geometry string, which disables Tk's automatic content-based resizing for that window from then on -- so the dialog sized correctly once, for the empty-error state at creation, and never grew again when the (2-line) error text showed up later. New _resizeRenameDlgToFit clears the explicit geometry (wm geometry $w "") and re-runs centerWin every time the error message changes, so the window re-fits its content instead of staying pinned to its original size.

### v159
(1) Rename Task dialog: the error-message label had a hardcoded -height 2 (text lines), but the actual validation message needs 3 -- it was getting clipped/overlapping the note text above it instead of the window growing to fit. Removed the height cap and widened the dialog (480x260) so it fits naturally. Also dropped the forced mid-sentence newlines in both the note and the validateTaskName error text -- they read awkwardly once wrapped; wraplength now handles line breaks on its own, same as everywhere else in the app.

### v158
(1) Fixed "invalid command name ::wb::new::validateFlowName" on Rename: fs-cfg.tcl doesn't source fs-new.tcl, so that proc was never actually loaded in this process (a latent bug carried over from the old, now-removed cloneTaskDialog, which used the same call and apparently never got exercised either). Added a local ::wb::cfg::validateTaskName with the identical rule instead of reaching across to an unloaded module.

### v157
(1) Task mode no longer has an Edit Task button -- selecting a task already opens the edit form, so it was always just re-entering the same panel. uiUpdateItemButtons now hides btnEdit for task mode; the dead branch in uiEditItem is removed.

(2) New Rename button next to the Name field in the task panel (the field itself stays read-only in edit mode -- this dialog is now the only path to a rename). Design, in one place per task: - Rename dialog (uiRenameTask/uiRenameTaskCommit) validates the new name with the same rule as flow names and checks it's not already a task in this flow. - commitTaskRename updates cfgDict immediately (name field, curTaskName, panelOrigTaskName) and rewrites every other task's dependsOn/whenFail so a rename never produces an orphaned dependency -- this happens the moment you confirm the dialog, no Save needed. - The actual on-disk folder/file rename is deferred: queued in pendingRenames (queuePendingRename, which collapses chained renames of the same task to a single disk move and drops net-no-op renames), and only applied by applyPendingRenames during a *final* Save (saveCfg) -- never on a dev-mode scratch/tmp save, so an in-progress dev session never has its folders shuffled out from under it. All-or-nothing: if any queued rename fails to apply, the whole save aborts (cfg.json is not written) rather than saving a json that references a name whose folder never moved -- the entries that already succeeded on disk are still pruned from the queue so a retry doesn't redo them.

(3) New taskFolderConsistencyCheck, run from two places (single source of truth for both): - cfgSaveGate (the existing continuous Save-button gate) now also disables Save whenever a task has no folder on disk -- folded into the same errDict/red-highlight mechanism that already flags empty title/desc etc, rather than a second parallel check. Correctly accounts for tasks with a pending rename (checks under their still-current on-disk name, not the new in-memory name, so confirming a rename doesn't immediately show as "missing"). - saveCfg (final-save path only) confirms with the user before proceeding if any folders under tasks/ are orphaned (present on disk, no matching task) -- non-fatal, matches the runner's own "ignore orphaned folders" behaviour; default is Proceed. Missing folders are NOT re-checked here since the Save button being clickable already implies cfgSaveGate found none.

### v156
(1) New proc insertTaskAfter (alongside appendTask): inserts a task dict into cfgDict's task list right after a named task, falling back to append-at-end if that name isn't found. Needed by fs-clone.tcl's new real Clone action, which inserts the cloned task after whatever's currently selected in the configurator rather than always at the bottom.

### v155
(1) openCfg still had a leftover "pack ${w}g.recipe" from the original global-bar build (separate from uiUpdateGlobalButtons, which was already fixed in v152) -- caused "bad window path name .g.recipe" on boot since the button widget itself was deleted in v152 but this initial pack call was missed. Removed.

### v154
(1) Fixed source line: deployed files are version-stripped (fs-clone.tcl, not fs-clone-v01.tcl), same convention as every other fs-*.tcl module. Was referencing fs-clone-v01.tcl, causing "Missing required file" at boot on the deployed tree.

### v153
(1) Removed cloneTaskDialog, cloneOnFlowSelect, cloneOnTaskSelect, and cloneTaskCommit entirely -- dead code left over from v152's switch to ::wb::clone::openCloneTaskWindow, now deleted outright. cloneListFlows / cloneTaskNamesFromFlow / cloneTaskFromSameFlow / cloneTaskFromOtherFlow / cloneRenameTaskFile are untouched and remain available for the fs-clone real clone-execution plumbing.

### v152
(1) Recipe Task browser removed entirely: the global "Recipe Task..." button, its packing logic in uiUpdateGlobalButtons, the recipe:// branch of helpLinkHandler, and procs openRecipeBrowser / cloneFromRecipe / uiRecipeMdFile (plus the recipeMdDir state var) are all deleted -- dead code, unreferenced anywhere else.

(2) uiCloneItem (task mode): now calls ::wb::clone::openCloneTaskWindow (new fs-clone.tcl module) instead of ::wb::cfg::cloneTaskDialog. (The old dialog and its helpers were removed outright in v153 -- see below.)

(3) New source line for fs-clone.tcl alongside fs-opts.tcl/fs-help.tcl.

### v151
(1) Recipe button hidden for all non-task modes (options/parms/runtime). uiUpdateGlobalButtons: flow hides both Recipe+Clone (unchanged); non-task/non-flow modes now hide Recipe and show Clone only.

(2) uiRecipeMdFile: options/parms/runtime now return "" -- recipe browser disabled for those modes (examples panels in fs-opts.tcl and the Add Parm dialog replace the recipe workflow).

### v150
(1) Global em-dash sweep: all 39 occurrences of the UTF-8 em-dash character (U+2014) replaced with -- throughout the file (comments, labels, tooltips, log messages, wm titles, example headings).

### v149
(1) Em-dash replaced with -- in examples panel header label and in the per-example comment separator (both were rendering as garbage on some Tk builds). v147 corrected the same way retroactively.

### v148
(1) parmExecPlaceholder eval case: use braces {eval:[glob <key>]} instead of double-quoted string so Tcl does not execute [glob <key>] as a command when the placeholder is assigned.

### v147
(1) _addParmBuildExamples: Leave binding now uses [. cget -background] instead of "" to clear hover highlight (empty string is not a valid Tk color name).

(2) Examples canvas given explicit -height 180 so the panel is smaller and the Add Parm / Cancel buttons are always visible without resizing.

(3) Comment separator changed from Unicode em-dash to two plain spaces to avoid garbage character rendering on some Tk builds.

### v146
(1) Add Parm dialog enlarged (680x520) with a scrollable examples panel below the input fields showing real patterns for the selected type. Examples are mined from production cfg files; eval shows sub-groups (glob-path, env-vbl, compound, opt-map). Clicking an example copies its parmExec string into the parmExec entry.

(2) New procs: _parmTypeExamples, _addParmBuildExamples.

### v145
(1) Add Parm dialog restored as a proper parm builder. - Type selector combobox: lit / copy / eval / tern - parmExec entry pre-populated with a labelled placeholder when type is selected: lit:<value>, copy:<glob-key>, eval:[glob <key>], tern:<opt>?<val-true>:<val-false> - parm name entry and optional hint entry - Appends new parm dict {parm, parmExec, hint} to current task - validateParms called on commit

(2) uiAddItem parms branch: calls new openAddParmWin (not recipe browser)

### v144
(1) uiAddItem parms branch: replaced dead openAddParmWin call with openRecipeBrowser -- parms are now added via recipes, consistent with the Recipe Parm... button.

(2) Removed dead procs: openAddParmWin, addParmSelect, addParmTipMotion, mkParmEntryFromReg, appendParmToCurrentTask, addParmCommit. All relied on registry hookName field that no longer exists and predated the recipe system.

### v143
(1) Context help windows: FocusIn reload now uses a 300ms debounced after-callback to avoid mtime race with editor autosave. _contextHelpScheduleReload cancels any pending callback before scheduling a new one, so rapid child-widget focus flaps only trigger a single reload check. New array: contextHelpAfterID tracks pending after IDs per window.

### v142
(1) Flow mode: Edit Help button added next to Edit Setup when <flowName>-help.md exists in the flow directory. View Help button opens a dedicated .wbFlowHelp toplevel rendered via ::wb::help::mdRender. On FocusIn the window checks file mtime and re-renders only if the file has changed since last load.

(2) Task mode: Edit Help and View Help buttons added beside Edit Script when <taskName>-help.md exists in the task folder. Same hot-reload-on-focus behaviour (.wbTaskHelp toplevel).

(3) New procs: flowHelpPath, flowRefreshHelpButtons, onEditFlowHelp, onViewFlowHelp, taskHelpPath, taskRefreshHelpButtons, onEditTaskHelp, onViewTaskHelp, openContextHelpWin.

### v141
(1) uiEditItem: fixed Edit Task button silence -- moved panelConfirmDiscard AFTER the task-mode branch so it is never called for task mode. Previously the discard dialog appeared behind the main window when panelIsDirty was true, causing apparent "radio silence" on Edit Task. Flow mode still prompts on discard; options/parms/runtime unchanged.

(2) uiEditItem: added log line so button activity is always visible.

(3) helpTitleFromFile: fixed syntax error in dict literal (missing quote on "Runprops Configuration" entry -- stray wb-cfg-help token removed).

### v140
(1) Clone Task dialog reworked: direction corrected - Source flow combobox: OTHER flows to pull from (blank = same flow) - Source task combobox: tasks in selected source flow (or current flow tasks) - New task name entry: defaults to source task name on selection - Destination is ALWAYS the current flow - Cross-flow: copies task dict + folder from source flow into current flow - Same-flow: copies task dict + folder within current flow - File renaming applied in both cases (dest name may differ from src)

### v139
(1) Parms grid: Type column width fixed (narrow, left of Parm)

(2) Parms grid tooltip: parmExec + hint (if present) on next line

### v137
(1) uiLoadParmsGrid: fixed field names to match actual JSON structure parm field (not parmId), type from parmExec prefix before colon

### v136
(1) uiLoadParmsGrid: fixed field reading (parmId/propStr/parmStr), added debug logging, fixed column widths

### v135
(1) Parms grid: treeview with Parm/Type columns; hint as tooltip Type derived from first token before : in parmId

(2) Runprops grid: treeview with Runprop/Text columns; no tooltip

(3) validateParms/validateRunprops called on mode switch and task select following same pattern as validateOptions

### v134
(1) fs-opts.tcl: commitOptAdd/commitOptEdit call itemPanelSetDirty (was itemPanelMarkDirty - wrong name) so Apply button now enables

(2) taskListData rowH updated to 26 to match WbOptsGrid.Treeview rowheight

### v133
(1) WbOptsGrid.Treeview rowheight set to 26 (~30% taller)

(2) commitOptAdd/commitOptEdit call itemPanelMarkDirty so Apply Options(s) Change button enables after editing an option (fs-opts.tcl)

### v130
(1) iconPath variable name matches user code; no tmp var cleanup needed.

### v129
(1) Window icon: fs-icon-S.ico set via wm iconbitmap in openCfg. Resolved from $TCL_HOME/icons/. Silently skipped if not found.

### v128
(1) panelApplyTask add mode: calls taskProvisionFiles to create task directory and copy/customise template files

(2) taskProvisionFiles: creates dir, copies brief.json + runlog.txt always, sync/async script for tcl-int/tcl-ext, prompts skip/overwrite if exists

(1) Task panel: Create/Edit Script button added for tcl-int and tcl-ext tasks - tcl-int: <task-name>-sync.tcl, template task-sync.tcl - tcl-ext: <task-name>-async.tcl, template task-async.tcl - No button shown for other task types - Full script path shown as tooltip - taskRefreshScriptButton called from panelShowMode task branch

### v121
(1) Flow mode panel: Edit Setup / Create Setup button added - Resolves <flows.dir>/<flow-name>/<flow-name>-setup.tcl - Edit Setup shown if file exists (stub logs resolved editor command) - Create Setup shown if file does not exist (stub logs intent) - Full path shown as tooltip on both buttons - panelShowMode flow branch calls flowRefreshSetupButton directly so button is always current when flow panel is displayed

### v120
(1) fsCfgLoad called at startup - loads ~/flowsmithy/flowsmithy.cfg

(2) devp flag: replaced -devp command line arg with devp.enabled from cfg file

(3) TCL_FLOWS env vbl replaced by flows.dir list in cfg - first match wins

(4) TCL_HOME env vbl replaced by home.dir in cfg file WB Configurator (CFG authoring only) FIXES from v14: 1) Startup selection: ensure curTaskName is actually set (no startup beep on Add Option). We now call uiSelectTask directly after selecting index 0, rather than relying on event generate. 2) Option editor error line is now RED (foreground). Still LOCKED to wb-demo-cfg.json format.

### v119
(1) Fix: uiUpdateGlobalButtons crashed when devp=OFF because Recipe button was positioned -after gFinalCb which is not packed in production mode. Now positions after btnSave when devp=OFF, after gFinalCb when devp=ON.

### v118
(1) devp mode controls Save Final behaviour: devp=ON : "Save Final" checkbox shown; save goes to -tmp.json unless checked devp=OFF : "Save Final" checkbox hidden; save always goes to -cfg.json

### v92
(1) Help back-navigation: openHelpPage now tracks a one-deep back stack (helpBackStack variable). When navigating to a sub-page, the previous page title+file is passed to mdRender as -backlink so the renderer injects the back link automatically. MD source files are clean.

(2) Requires fs-help.tcl for -backlink support. Launch: tclsh fs-cfg.tcl <flow-cfg.json>

### v91
(1) fs-help.tcl load moved to correct position (Steve's tweak preserved). Requires fs-help.tcl for table rendering support.

### v90
(1) Help button wired: opens [fsCfgGet home.dir]/help/wb-cfg-help.md via wb-help mdRender with -linkhandler ::wb::cfg::helpLinkHandler.

(2) helpLinkHandler: handles help:// URIs (navigate same window) and recipe:// URIs (delegates to cloneFromRecipe). Ignores others.

(3) onHelpHelp: now calls openHelpPage rather than just logging.

### v88
(1) Welcome link removed -- Help link only.

(2) Global bar now truly spans the full window: packed into the top-level window (.) BEFORE the main frame, so Tasks list and right panel sit below it, not beside it.

### v87
(1) Global bar now spans the full window width (packed directly under .main, not under .main.right). Left panel sits below it.

(2) Recipe X and Clone X buttons moved from the Cfg Mode toolbar to the Global bar, placed after the "Save Final" checkbox. - Labels still track Cfg Mode via uiUpdateGlobalButtons. - Still hidden in flow mode.

(3) Cfg Mode toolbar (h bar) retains only: Cfg Mode combo, Add, Edit, Remove, Move Up.

(4) Help links "Welcome" and "Help" added to the right of the Restart button on the Global bar, using Wb.Link.TLabel style (blue, hand cursor) matching fs-run.tcl pattern.

(5) ::wb::cfg::onHelpWelcome / ::wb::cfg::onHelpHelp -- stub handlers that log the click for now.

(6) initButtonStyle: adds Wb.Link.TLabel, Wb.LinkHover.TLabel styles.

(7) uiUpdateGlobalButtons: new proc -- updates Recipe/Clone label text and visibility on the global bar, called from uiUpdateItemButtons.

### v86
(1) Recipe button added to global bar. - Label tracks Cfg Mode: "Recipe Task...", "Recipe Option...", etc. - Hidden in flow mode (same hide pattern as other buttons). - Opens the appropriate recipes-<mode>.md from [fsCfgGet home.dir]/help via fs-help.tcl mdRender with an injected -linkhandler.

(2) openRecipeBrowser: resolves md file path from mode, calls mdRender.

(3) cloneFromRecipe: stub dispatcher -- logs the recipe:// url and the current mode/task; real clone logic to follow in v87+.

(4) uiUpdateItemButtons: hides Recipe button in flow mode.

(5) uiRecipeMdFile: maps mode -> recipes-*.md filename.

### v85
(1) uiLoadOptsGrid: reads scalar "place" for check/text/file/directory, list "places" for radio/select (grid Place column was always blank for non-radio/select types)

(2) Grid refresh after Add/Edit/Clone: fixed in fs-opts.tcl v10 (uiLoadOpts now delegates to uiLoadOptsGrid)

### v84
(1) uiCloneItem: wired for options mode -> openOptEditor $idx clone (all other Edit Option window changes are in fs-opts.tcl v9)

### v80
(1) Move Up button now also enables in options mode when row > 0

(2) Label and Parm columns reduced to ~1/3 prior width

(3) Fixed missing "variable curItemIndex" in uiEditItem (caused crash on Edit Option) Options mode: replaced crude listbox with a treeview grid. Columns: Label / Type / Parm / Place Extra fields (hint, reqd, dflt, vals) shown as row tooltips. Selecting a grid row activates Edit/Remove buttons above.

### v79
(no description recorded)

## fs-clone.tcl

### v11
(1) Fixed blank "Cloning into flow:" label on window open. destFlow was declared but never actually assigned until deep inside onCloneButtonClick (i.e. after a clone had already happened), so the label built in openCloneTaskWindow always read the empty default. openCloneTaskWindow now sets destFlow to [::wb::cfg::cfgBaseName] (the currently open flow) right before building the header label -- same source onCloneButtonClick already trusted for the real destination, just also assigned up front for display. Display-only fix; clone execution itself was never affected since it never depended on this early value.

### v10
(1) REVERT of v09. runprops is a plain dict on disk (matching fs-run.tcl and most existing cfg files), not a list of {key,value} objects -- v09 was chasing a non-conforming sample. scanAllTasks's javaMain lookup and the Task Detail window's Runprops section both reverted to dict get/for, as they were at v08. See fs-cfg.tcl v168 / tcl-lib.tcl v46 changelogs.

### v08
(1) Flow name field is now a case-insensitive regex matched against each flow folder name (regexp -nocase), not an exact-name list. Replaced _parseFlowFilter with inline regex validation in doScan (same pattern as the main search text) and changed scanAllTasks' flowFilter arg to flowRegex, matched with regexp instead of lsearch -exact. Blank still means "scan all flows".

### v07
(1) New "Flow names" field in Search Criteria: comma/space separated list of flow names to restrict the scan to (case-insensitive match on folder name); blank = search all flows, unchanged from before. New crit(flows), _parseFlowFilter, and scanAllTasks now takes an optional flowFilter arg and skips non-matching flow dirs before even trying to read their cfg.json (cheaper than filtering results after the fact).

### v06
(1) Options rows now show each option's control type in parens next to its key, e.g. "noparm (check):", "txtfld (text):" -- looked up from raw's opts[] list by matching label (opts[].label is the same string used as the options.json key).

(2) New Clone This Task button on the Task Detail window, next to Close. Runs the real clone action: - name: keeps the source task's name if free in the destination flow, otherwise uniquifies with -copyN (_chooseUniqueTaskName) - inserts the cloned task dict into the destination flow's cfgDict (in memory, same dirty-until-Save convention as every other configurator edit) immediately after the currently selected task, via the new ::wb::cfg::insertTaskAfter (fs-cfg v156) - creates <destFlow>/tasks/<chosenName>/ and copies the source task folder's files into it, renaming via the existing ::wb::cfg::cloneRenameTaskFile (handles -help.md/-*.tcl) - refreshes the configurator's task list/selection - closes both the Task Detail and Clone Task Search windows New procs: onCloneButtonClick, _chooseUniqueTaskName. New state: curDetailRec (tracks which result the detail window is currently showing, so the Clone button knows what to act on).

### v05
(1) New reusable Task Detail window (.wbCloneDetail): clicking a result card now opens/updates a window showing Options (from <flow>/tasks/<task>/options.json -- actual saved values), Parms, and Runprops (both definitions from cfg.json), in that order, in a scrollable body -- style loosely follows fs-run.tcl's label:value grid conventions (renderGlobsPanel / onViewRunProps). New procs: showTaskDetail, _ensureDetailWindow, _closeDetailWindow, _populateDetailWindow, _detailSectionHeader, _detailKVRow, _detailEmptyRow, _loadTaskOptions. The window is built once and reused -- clicking a different result repopulates it in place rather than opening a new window.

(2) scanAllTasks: each result record now carries the full source task dict under key "raw" so the detail window can read parms/runprops without re-reading the flow's cfg.json.

(3) Search window (.wbCloneScan) is no longer modal (grab set removed). A strict OS-level Tk grab on one toplevel blocks all sibling toplevels in the same app, which would have made it impossible to click a second search result while the detail window was open -- the "reusable window" behaviour just requested needs both windows interactive at once. Both stay on top of the configurator via wm transient; the search window just no longer excludes clicks to the main configurator behind it while open.

### v04
(1) Real fix for checkbox spacing: the "Type (none checked = Any):" label was gridded into column 0 only (no columnspan), so grid sized column 0 to fit that whole label text rather than the "java" checkbox -- that's what was producing the large gap before tcl-int while tcl-int/tcl-ext/manual (whose columns were already sized to their own short content) looked evenly spaced. v03's uniform -padx {0 18} was correct but couldn't fix this on its own since it was added on top of an oversized column 0. Label now spans -columnspan 5 so column 0 sizes to the checkbox itself; the four columns are now evenly spaced.

### v03
(1) Type checkboxes (java/tcl-int/tcl-ext/manual): added uniform -padx {0 18} on each grid cell so spacing between them no longer varies with label text width.

(2) Search regex is now case-insensitive (regexp -nocase) for both the validation check and the Title/Desc match test.

### v02
(1) Fixed "bad screen distance '0 12'" crash on open: the results panel's outer frame used a widget-creation -pady of {0 12}, which is only valid for pack/grid geometry-manager padding, not for a widget's own -padx/-pady config option (that takes a single screen distance). Changed to -pady 12. Replaces the old single-flow-dropdown Clone Task dialog (::wb::cfg::cloneTaskDialog et al -- since removed from fs-cfg.tcl) with a scan-and-filter workflow: 1. openCloneTaskWindow scans every flow under flows.dir and reads each <flow>/<flow>-cfg.json's tasks[] list. 2. Search Criteria panel: a single regex (matches Title OR Desc), a Type filter (checkboxes; none checked = Any), and a "Recipes only" checkbox (task has a non-empty recipe field). Search is re-runnable any time criteria change. 3. Results are de-duplicated when desc+type are identical -- first occurrence wins (flows in alpha order, tasks in cfg.json order), duplicates dropped silently (no count shown). 4. Each result is shown as a card: Src Flow, Src Task, Title, Desc, Type, Recipe (if present), runprops.javaMain (if present). 5. Clicking a card opens/updates a reusable Task Detail window showing Options (actual saved values), Parms, and Runprops (definitions), in that order. Real clone execution (prompt for new name, copy task dict + files) is separate follow-up work; see ::wb::cfg::cloneTaskFromSameFlow / cloneTaskFromOtherFlow / cloneRenameTaskFile in fs-cfg.tcl, which remain in place and are likely candidates for that plumbing. 6. Search window has an explicit Close button plus the window-manager close box. Neither it nor the Task Detail window is modal (see v05 changelog below for why).

### v01
(1) Initial version. ---------------------------------------------------------------------------

## fs-core.tcl

### v04 (2026-jul-21)
removed the whole registry-file apparatus (FS_REG_JSON, FS_REG_TCL, ::wb::core::regJsonPath, ::wb::core::regTclPath) rather than just fixing its stale wb- filenames (v03). Traced its only caller (fs-cfg.tcl's bootConfigurator) and found the loaded data (regDict) was used for exactly one diagnostic log line and nothing else -- a leftover of the pre-v144 registry/hookName-based parm builder system, already confirmed dead and replaced by the current Type-combo Add Parm dialog. Steve's call: "blow it away entirely, it belongs to a track we never took." See fs-cfg.tcl's own changelog for the matching removal on the caller side.

## fs-exec.tcl

### v6 (2026-aug-03)
Steve's request: when a task's engine is `java` and no Java runtime is available, treat it as a setup error ("Java runtime not found") rather than letting it fail some other way -- and design the check to extend cleanly to future engine types (python, c#, node.js).

Design settled across a short discussion before implementing (Steve explicitly asked for "the most standard way... consistent with our existing codebase"): checked two options -- `$env(JAVA_HOME)/bin/java(.exe)` existence vs. PATH-based lookup (`auto_execok java`) -- and went with `JAVA_HOME`, for three reasons: (1) it's what `::wb::exec::handleJavaASync` already uses to actually launch Java (fs-exec.tcl line ~547) -- a PATH-based check could pass while the real launch still fails; (2) every other setup check in this codebase (hooks-file-missing, the tclsh.exe sibling check in fs-shell.tcl) is a plain `file exists`, not a PATH scan; (3) checking both `JAVA_HOME` and a PATH fallback is exactly the "multiple run modes" pattern Steve rejected for tclsh earlier this session -- one source of truth, one failure mode.

New `::wb::run::checkTaskRuntime` (fs-run.tcl v117) holds the actual check, structured as an `$ttype` routing table matching this file's own `prepTaskExec` routing table style, so adding python/csharp/node later is a mechanical addition to both tables, not a new pattern. `prepTaskExec` now calls it as a safety net right after determining `$ttype`: previously, `$env(JAVA_HOME)` was used completely unchecked at actual launch time (a raw Tcl error -- "can't read env(JAVA_HOME)" -- if unset, not a clean failure). On a runtime-check failure, mirrors the existing "type not implemented" error-reporting shape exactly: `setupErr` set, a proper FAIL `brief.json` written via `writeBrief` (so Status/Brief panels show a real failure record, not just a console error), `hilite -red`, and the message returned.

The primary, Steve-requested behavior -- setup error shown *at task selection*, before Play is ever clicked -- is implemented in fs-run.tcl v117's `renderTask` (see that entry); this file's change is the Play-time safety net, reusing the identical check rather than duplicating the logic.

### v5 (2026-jul-28)
REVERT of v4. v4's diagnosis was wrong: it assumed `fs-real-setup.tcl` pre-resolving individual jar/zip file paths was a legitimate second convention that `expandJavaPath` needed to accommodate, and changed `expandJavaPath` to accept both directories and individual files. A known-working setup script (using `gael-util`/`basic` cpTags, populated entirely from directory paths built via `[file join ...]`, never pre-resolved files) proved `expandJavaPath`'s original directory-only contract was correct all along -- the actual bug was on the other side, in `fs-real-setup.tcl` itself, globbing files it should have left for `expandJavaPath` to glob. Reverted `expandJavaPath` back to its original directory-only behavior; the real fix is in `fs-real-setup.tcl` v4 (see that entry).

### v4 (2026-jul-28) -- SUPERSEDED, see v5 above
Based on a misdiagnosis: changed `expandJavaPath` to also accept pre-resolved individual jar/zip file paths (in addition to directories), believing that was a legitimate convention needing support. It wasn't -- see v5.

Prior to v4, this file had no dated changelog history -- its header was purely architecture/design documentation (execution engine flow: task validation, prepTaskExec/fireTaskExec, sync vs async handling), which stays in the file itself.

## fs-help.tcl

### v39 (2026-jul-31)
Found the actual cause of the `Trap` mid-paragraph indent loss that v38 explicitly flagged as unreproduced. Steve's screenshot after installing v38 showed `Gen`'s multi-paragraph bug genuinely fixed, but `Trap` still breaking -- and breaking at the exact same word both times: `` `TestArgsFS` ``, an inline `code`-formatted span. That pattern (not a coincidence across two separate reports) was the actual lead: `_insertInline`'s code-span branch did `$t insert end $seg inlinecode` -- only the `inlinecode` tag, silently dropping `$baseTag` entirely. Every *other* inline-formatting branch (bold: `[list $baseTag b]`, italic: `[list $baseTag i]`, links: `[list $baseTag $tag]`) correctly combines the two; the code-span branch was the one exception. So any code span inside a list item lost its `li` tag -- including the `lmargin1`/`lmargin2` hanging-indent properties -- for those specific characters, and whenever Tk's word-wrap happened to break a display line starting at or after one of those tag-less characters, that line rendered flush-left instead of indented. v38's isolated synthetic test used a **bold** span, not a `code` span, which is exactly why it didn't catch this -- bold/italic were never broken, only code spans were.

Fixed the one-line omission: `$t insert end $seg [list $baseTag inlinecode]`. Also found and cleaned up, in the same block of tag configuration, a corrupted `backlnk` tag definition with duplicate `-font`/`-spacing1`/`-spacing3` options (looked like two separate configurations had gotten merged together at some point) -- Tcl's last-value-wins semantics meant the first occurrence of each was already dead code, so deduplicating it changes nothing about current runtime behavior, just removes confusing dead text. Unrelated to the indent bug itself, just found nearby.

Verified precisely: confirmed a code span now carries both `li` and `inlinecode` tags together (previously only `inlinecode`), then re-rendered the *exact* real `Trap` paragraph and checked `dlineinfo`'s pixel x-offset on every one of its wrapped display lines -- all five now report the correct offset, including the one immediately following `TestArgsFS` that broke twice before. Re-rendered the full updated `demo-options-help.md` (which now also has a new `boolFail` bullet) and confirmed every list item, without exception, gets the `li` tag. Full existing `fs-help.tcl` regression suite -- the v38 multi-paragraph fix, the original v32 loose-list-numbering fix, cross-file link tests, context-help tests -- re-run clean alongside it.

### v38 (2026-jul-31)
Reported via screenshot: `demo-options-help.md`'s "Option Fields" list, specifically the **Gen** bullet, which has a second paragraph (blank line, then more indented text) that rendered flush-left instead of staying part of the bullet's hanging indent. Confirmed with certainty by rendering the actual uploaded file through the real `_mdIntoText`/`_flushLi` code and dumping the tag on every logical line: `Gen`'s first paragraph correctly got the `li` tag, but the second paragraph -- separated from the first by a blank line -- got the plain `p` tag instead, with none of `li`'s `lmargin1`/`lmargin2` hanging-indent properties.

Root cause: the blank-line handler in `_mdIntoText` always flushed the pending list item immediately, with no way to tell "this blank line is followed by more content that's still part of the same list item" (a CommonMark "loose list item" with multiple paragraphs) from "the list has actually ended." Fixed by deferring that flush: a blank line no longer flushes a pending list item if a list is still open, and the following line is checked for whether it's genuinely leaving the list (flush-left, ends it) or still indented (continues the same item, appended into the same buffered block) -- matching CommonMark's actual rule that indentation, not just presence of a blank line, determines whether content after a blank line stays inside a list item.

Also investigated, but could not reproduce: a second symptom in the same screenshot, where a *single* wrapped line in the middle of the **Trap** bullet (no blank line involved at all) appeared to lose its indent while the lines immediately before and after it, in the same bullet, stayed correctly indented. Tried rendering the actual uploaded content at multiple widths, dumping `dlineinfo`/tags for every wrapped display line, and an isolated synthetic case specifically testing whether an inline bold/italic span interferes with `lmargin2` continuation -- all came back correctly indented in this sandbox (Tcl 8.6 / Linux). Flagging as possibly a Windows/Tcl-9-specific Tk rendering difference that couldn't be verified remotely, worth re-checking after this fix ships in case it was somehow connected to the same code path.

Verified the actual fix directly: `Gen`'s two paragraphs now merge into one `li`-tagged block with the full combined text, confirmed every wrapped display line of that (now longer) block reports the correct `lmargin1`/`lmargin2` pixel offset via `dlineinfo`. Also re-verified the original v32 loose-ordered-list fix (blank lines between numbered items) still numbers correctly -- this touches the same `afterBlank` code path -- and confirmed a genuinely non-indented paragraph following a blank line after a list still correctly ends the list and gets the plain `p` tag, not `li`. 5 checks on the original repro, 5 more on the targeted regression pass, all green; full existing `fs-help.tcl` test suite re-run clean alongside it.

### v37 (2026-jul-29)
The reporter caught a self-contradicting error message from v36: clicking `help:fs-run-help.md#globs` (a plainly bare filename, no `/` or `\`) produced "File not found... -- \"fs-run-help.md\" *includes a path*, so it was resolved locally" -- visibly false, since the filename shown right there has no path in it. Root cause: `_resolveHelpLink`'s bare-name branch has a safety net for when `<home.dir>/help` genuinely can't be computed (`fsCfgGet` not loaded, or `home.dir` not set in `flowsmithy.cfg`) -- it degrades to a local guess rather than returning an unusable empty path. That degradation was silently setting `route` to the same plain `"local"` value used for genuinely path-qualified references, so `_openHelpLink`'s message picked the wrong (and, for a bare name, false) explanation.

Fixed by giving that degradation its own distinct route value, `"homehelp-unavailable:<reason>"`, carrying the *specific* reason (`fsCfgGet` unavailable vs. `home.dir` unset) captured at the moment it happens. The not-found message now has three accurate branches instead of two: found nowhere in the shared help folder (bare name, home.dir working fine); found nowhere locally (genuinely path-qualified reference); and this new case -- a bare name that should have gone to the shared folder but couldn't, stating plainly why, e.g. *"...should have been looked up in FlowSmithy's shared help folder (\<home.dir\>/help), but that wasn't possible: home.dir is not set in flowsmithy.cfg. Fell back to a local guess as a last resort, which also wasn't found."* This is now directly actionable rather than misleading, and should settle definitively whether the reporter's live app can actually see `home.dir` at the moment a help link is clicked -- something confirmed working in isolated testing against their real `flowsmithy.cfg`, but evidently not proven yet for the live running process.

### v36 (2026-jul-29)
Traced a real-world report: `help:fs-run-help.md#globs` (a bare filename, no `/` or `\`) inside a task help file was resolving against the task's own local folder (`.../tasks/demo-set-context/fs-run-help.md`) and reporting that as "not found" -- even though the file genuinely existed at `<home.dir>/help/fs-run-help.md`, confirmed via a real `dir` listing on the reporter's machine. The v34 fallback mechanism (try local, then try `<home.dir>/help` if local misses) was still present and correctly wired -- verified via a from-scratch Tcl 9.0.1 build tested against the reporter's actual `flowsmithy.cfg` and exact markdown content, ruling out file corruption, CRLF handling, and a Tcl-8.6-vs-9 discrepancy one by one. The real problem was upstream of the mechanism itself: `_openHelpFallback`'s "not found" message only ever displayed the **local** path it had tried, by design, regardless of whether the `<home.dir>/help` fallback also ran and also missed -- making it genuinely impossible to tell, from the error alone, whether the fallback had been attempted at all. That ambiguity is what actually cost the most time here.

Redesigned the routing to be exclusive rather than layered, per the reporter's own stated intent: a **bare filename** (no `/` or `\` anywhere in it) now routes straight to `<home.dir>/help` -- it never touches local resolution at all. A **path-qualified** reference (`sub/other.md`, `../other.md`) or an already-absolute path resolves **locally**, relative to the file that referenced it, as before. There's no secondary fallback between the two rules; if a bare name isn't in the shared help folder, that's reported plainly, instead of silently also guessing at a local interpretation. `_resolveHelpLink` now returns which route it used (`"homehelp"` or `"local"`), so the not-found message can state exactly what was tried: e.g. *"File not found in FlowSmithy's shared help folder (\<home.dir\>/help) -- "fs-run-help.md" is a bare filename, so that's the only location tried."* -- naming the actual folder searched, not the task folder that was never even attempted.

Verified with the reporter's exact markdown content, exact `flowsmithy.cfg`, and exact directory layout: bare-filename links now correctly resolve to `<home.dir>/help` and never the task folder; path-qualified sibling references still resolve locally exactly as before; when `home.dir` isn't configured at all, a bare name gracefully degrades to local rather than producing an unusable path. Full existing regression suite (cross-file link new-window/same-window behavior, backlinks, missing-file and bad-anchor fallbacks, context-help window tracking) re-run clean against this change.

### v34
(1) Cross-file help: links now fall back to <home.dir>/help -- FlowSmithy's shared help folder, per flowsmithy.cfg -- when the target doesn't exist relative to the file that referenced it. This is what makes the primary use case work: a task/flow help file can write help:fs-run-help.md#globs-table to reach FS's main help content, without needing a relative ../../.. chain back to the shared folder (and without knowing how deep its own file happens to be nested). Sibling-file links within a task/flow's own help folder still resolve there first, as before; the fallback only kicks in when that lookup misses. Implemented via a soft dependency on fsCfgGet (tcl-lib.tcl) -- if it's not loaded or home.dir isn't set, the fallback is simply skipped, same as today. New proc: _defaultHelpDirPath.

### v33
(1) Cross-file help links: help:<path>[#anchor] opens the target file in a new help window; help-same:<path>[#anchor] replaces the current window's content with an automatic "Back to <title>" link. Anchors resolve against the target file's headings exactly like existing same-document #slug links.

(2) mdRender gains optional -winname (render into a window other than .wbHelp) and -mdtext (render supplied text instead of reading a file, used for the "not found" fallback page) arguments. Both are purely additive -- no existing call site's behaviour changes.

(3) New per-window curFileMap/curTitleMap track which real file/title is currently showing in a given help window, so a help:/help-same: click knows what it's relative to and help-same:'s backlink knows what to point back at. _cleanupWindow now also clears these (and is no longer hardcoded to only fire for .wbHelp, since cross-file links can now open .wbHelp2, .wbHelp3, ...).

(4) Fix vs. sketch: a missing anchor on an already-successfully-loaded target page now shows the "not found" message inside that same target window instead of abandoning it and opening yet another new window (which the original sketch would have done for help: links specifically -- see _openHelpFallback's winOverride).

(5) The pre-existing help:// (double-slash) scheme used by fs-cfg.tcl's own -linkhandler routing is left untouched: the new help:/ help-same: interception explicitly excludes help://.

### v32
(1) Fix: ordered-list numbering no longer resets to 1 when a list item's text wraps onto a following source line without its own "N." marker. Wrapped/continuation lines are now buffered and joined onto the current list item (GitHub-style lazy continuation), matching the existing paragraph-wrap behaviour, instead of being treated as "leaving the list". Code generated on 2026-Mar-01 19:33 courtesy of chatGPT Simple help rendering: Markdown (.md) -> Tk text widget tags No HTML intermediate, no platform-specific code.

### v31
(1) Default help window size increased to 1260x840 (was 900x700).

(2) mdRender gains optional -width and -height arguments so callers can specify a custom window size without editing this file. Code generated on 2026-Mar-01 19:33 courtesy of chatGPT Simple help rendering: Markdown (.md) -> Tk text widget tags No HTML intermediate, no platform-specific code.

### v30
(1) Fix: remove bogus [image inuse] guard — was suppressing all icons not yet attached to a widget (i.e. nearly all of them).

### v29
(1) Fix _slugify regsub: escape hyphen to avoid flag parsing error.

### v28
(1) Fix table cell image rendering (was leaving "!alt" literal text).

(2) Anchor/fragment link support for road-map navigation (#slug).

### v28
(1) Fix: table cell stripping regex now correctly removes ![alt](img:...) syntax (was leaving "!alt" literal text in icon column). Icon cells use a Tk label with -image instead of -text so images render inside the table grid exactly like regular cells.

(2) Fix: anchor/fragment link support for road-map navigation. Headings now register a named mark in the text widget using a slugified form of their text (lowercase, spaces->hyphens, punct stripped). _linkClick detects "#fragment" URLs and yview-scrolls to the mark. _mdIntoText passes the text widget path into heading rendering via the new _insertHeading helper which sets the mark before inserting.

### v27
(1) Inline image support: ![alt](img:filename.png)

(2) mdRender gains -imagecache argument (dict: filename -> photo image).

(3) Images displayed at 50% via Tk photo -subsample; cached in imgCache.

(4) _insertLinks routes img: URLs to _insertImageWidget.

### v27
(1) Inline image support: ![alt](img:filename.png)

(2) mdRender gains -imagecache argument (dict: filename -> photo image).

(3) Images displayed at 50% via Tk photo -subsample; cached in imgCache.

(4) _insertLinks routes img: URLs to _insertImageWidget.

### v23
(1) mdRender gains optional -backlink {label url} argument.

(2) _insertBackLink renders back-nav chrome above document content.

### v23
(1) mdRender gains optional -backlink {label url} argument.

(2) _insertBackLink renders back-nav chrome above document content.

### v22
(1) Table support (GFM pipe tables).

### v22
(1) Table support (GFM pipe tables).

### v21
(1) Horizontal rule support.

### v21
(1) Horizontal rule support.

### v20
(1) mdRender gains optional -linkhandler argument.

### v20
(1) mdRender gains optional -linkhandler argument.

## fs-new.tcl

### v05
templateDir now uses fsCfgGet home.dir instead of TCL_HOME env var for consistency with the rest of the tool chain. Namespace: ::wb::new

### v04
simplified — creation IS cloning. new <flow-name> clones flow-template (from TCL_HOME/templates) new <flow-name> <source> clones named source flow Single code path: ::wb::new::cloneFlow srcDir destName All files (text): string-replace srcName->destName in filename and content. Binary files: copied verbatim. Existence check: error if dest folder already exists.

### v03
cloneFlow overhaul — per-file rename + fixupFlowRefs helper

### v02
optional second argument enables clone mode

### v01
scaffold a new flow from template and open in configurator

## fs-objs.tcl

### v61 (2026-aug-01)
Adds `Task.staleRefTS` -- schema field plus a getter matching the existing `stepState` pattern -- needed by `fs-run.tcl` v114's guard on the stale-manual-checkbox reset (v113): the timestamp `refreshStepStates` was actually comparing this task's own `briefTS` against when it decided `STALE`, captured at the exact moment of that comparison (before the loop's `lastFreshTS` can advance further for a later task). This is the real freshness high-water mark, not "whichever task happens to sit immediately before this one" -- Steve's call, since flows can skip steps and the immediately-preceding task isn't reliably the one that actually matters.

Also cleaned up something found directly adjacent while adding this: the schema had `optErrCnt` declared twice back to back, with the *second* copy's comment reading "bHooksOK : 1 - hooks valid..." -- describing a completely different field, not itself. Harmless (re-declaring the same key with the same default value changes nothing), but confusing to read, and `bHooksOK` is correctly declared separately two lines later regardless. Removed the stray duplicate.

### v60 (2026-jul-30)
Traced a real UX bug Steve hit while testing the `custVal` demo: after his hook cleared `optErr`, the error stayed visible on screen unless he edited some *other* field first. Root cause turned out to be upstream of the hook or the redisplay call entirely -- `uiRender`'s `text` case had `FocusIn`/`FocusOut`/`Return`/`KP_Enter` all nested inside `if {$place ne ""}`, so a text opt with no `place` value (like `CustValDemo`) got **no commit-trigger bindings at all**. What looked like "editing another field forces a refresh" was actually that other field's own commit path triggering a full-panel `renderTask "all"` re-render, sweeping the untriggered field along as a side effect -- not anything `CustValDemo` itself was doing.

Fixed by hoisting `FocusOut`/`Return`/`KP_Enter` out of the placeholder guard so every text opt gets commit-on-blur/Enter regardless of whether it also has a `place` value; `FocusIn` stays inside the guard since placeholder-restore genuinely only applies when there's a placeholder. Confirmed safe to hoist by reading `argEntryFocusOut`/`onTextFocusOut` directly first -- both already internally no-op when `place eq ""`, so nothing needed to change in those procs, only where the bindings get attached.

Also fixed, found while in the same few lines: the `<KP_Enter>` binding had a stray `uiRend` concatenated directly onto the end of the bound script with no whitespace (`]]uiRend`), turning `break` into the invalid command `breakuiRend`. This would have thrown a Tcl error on Numpad Enter for any text field that *did* have a placeholder -- the only ones that previously got this binding at all, so it had presumably gone unnoticed simply because nobody had hit Numpad Enter in one of those fields yet.

Verified directly against real rendered widgets, not just code review: a placeless text opt now has `FocusOut`/`Return`/`KP_Enter` bindings that were completely absent before, confirmed the bound `KP_Enter` script is now valid Tcl (no `uiRend`, ends cleanly in `break`), fired a real `<FocusOut>` event and confirmed the commit path actually runs, and confirmed a `place`-bearing text opt's placeholder behavior (`FocusIn` present, everything else unchanged) is unaffected by the restructuring. 11/11 checks pass, full existing regression suite clean alongside it.

### v59 (2026-jul-29)
Renamed `bindVal` -> `custVal` throughout (schema declaration, getter method, constructor's JSON read, and the Arg Values debug-dump line). This is the schema half of a three-file rename (see `fs-run.tcl` v112 and `fs-opts.tcl` v17 for the other two); the reasoning lives in `fs-run.tcl`'s entry below. Confirmed zero remaining `bindVal` references anywhere in the golden source afterward, aside from one explanatory comment noting the old name for anyone who greps old configs or old conversation history.

### v58 (2026-jul-28)
UI cleanup for the file/directory opt controls (Input, Becudir, and any other `type: file`/`type: directory` option), reported via screenshot: the value combobox was a fixed character width, truncating long paths, with a large unclaimed empty gap to its right where the mode dropdown ("old"/"new"/"any") and Browse button sat hugging the left edge instead of using that space.

Root cause: all four grid columns in the control area (value combobox, mode dropdown, Browse button, trailing place-text label) had `-weight 0`, so nothing expanded to claim the row's available width -- the whole cluster just sat at its natural minimum size on the left. Fixed: column 0 (the value combobox) now has `-weight 1` and `-sticky ew`, so it expands to fill whatever width isn't needed by the other three (now genuinely fixed-width) columns, which pushes the mode dropdown and Browse button to the right edge of the control area -- lining up with the right edge of other opt types like a `text` entry (verified by direct pixel measurement: 0px difference between a "text" opt's entry and a "file" opt's Browse button, rendered side by side).

Two follow-on fixes were needed to get that alignment pixel-perfect rather than off by ~8-10px: the trailing place-text label (`$ctrl.txt`) was always being gridded into column 3 even when its text was empty (the common case for Input/Becudir, which don't set a "place" hint) -- an empty `ttk::label` still reserves a small sliver of width, which was leaving Browse short of the true right edge. Fixed to only grid that label when `place` is actually non-empty. Similarly, Browse's own `-padx {0 8}` (breathing room before the label) is now only applied when the label is being shown; without a label following it, Browse sits flush against the true right edge. Verified the label still renders correctly for opts that do set a "place" value (e.g. a hypothetical directory opt with `"place": "Base becu folder"`).

Also added: a live tooltip on the value combobox itself, showing the full untruncated value on hover -- for cases where even the now-wider combobox still isn't wide enough for a very long path. Uses the new `::wb::run::tipAttachDynamic` (fs-run.tcl v109) rather than the existing static `tipAttach`, since the combobox's text changes as the user types or browses to a new path and a snapshot taken once at render time would go stale. Verified directly: attached the tooltip, confirmed it shows the full path on hover, then changed the underlying value and confirmed a second hover shows the *new* value rather than the original.

### v56 (2026-jul-28)
Ctx.getGlob/setGlob/ glob now route through [my globs] (-> Form's shared Globs table) instead of through the current task. This is the proper fix for the "invalid command name """ crash from a *-setup.tcl script calling $ctx setGlob (worked around in that specific script in fs-real-setup.tcl v2 by calling $globs dset directly; this makes the underlying Ctx method itself correct, so any caller -- existing or future, setup script or exit function or anything else holding a Ctx -- gets the fix, not just that one script). Added getGlob as the new preferred name (dget-style: key + optional default); glob is kept as an alias for it. Task's own glob/globs methods were already just forwarding to Form -- there was never a separate task-level Globs store -- so this loses no functionality, it just removes an unnecessary (and, as it turned out, unsafe) hop through the task. See the inline comment on Ctx.getGlob for the full explanation.

### v55 (2026-jul-27)
follow-up to v54. The same variable-aliasing problem fixed in parseValues (v54) also existed in uiRender itself, independently: it used bare `values`/`places` as its own working copies, and its `set values $dynVals` / `set places $dynPlaces` (after resolving "dyn:xxx" via parseValues) still silently overwrote the Arg's real values/places instance fields on every render -- v54 alone didn't fully close this, since the corruption was happening at this second call site too, not just inside parseValues. Fixed: renamed uiRender's working copies to curValues/curPlaces throughout (the initial fetch, the select-branch dyn: resolution, and every subsequent read in both the radio and select uiType branches), so no code path in this method can alias the instance variables anymore. Verified live: a "dyn:xxx" select now genuinely re-queries the globs table on every render (confirmed fresh data on a 2nd render, where before it silently kept showing 1st-render data forever), while plain literal values/places lists and the radio uiType (which reads these same fields) render exactly as before.

### v54 (2026-jul-27)
fixed Arg.parseValues, which was producing the literal 8-character string "$valStr" as a bogus single-element list instead of returning an empty/pass-through list. Root cause of a real bug: uiRender calls parseValues on BOTH an opt's "values" and "places" for uiType=select, unconditionally -- so an opt with "values" but no "places" key (places is meant to be optional, falling back to using the values themselves as display text) fed "" into parseValues, which returned {$valStr} (one element, the literal text) instead of {} (empty, zero elements). Downstream, the select-rendering code treats "places shorter than values" as "use the value itself as display text past the end of places" -- but with places wrongly length 1, index 0 (usually the "*"-marked default entry) got overridden with the display text "$valStr" instead of the real value. This is what was showing up in the Runner UI as a control's value literally reading "$valStr". The bug was `set values {$valStr}` -- Tcl curly braces suppress substitution, so this was never actually substituting $valStr's *value*, just producing the 8-char literal string "$valStr" every time this branch ran (i.e. every time an optional values/places field was omitted or was a single non-list, non-"dyn:" string). Fixed to `set values $valStr` -- for "" this correctly yields an empty list (0 elements), and for a genuine single bare-word value it still yields a proper 1-element list, exactly as intended. Also fixed the adjacent dead error-reporting branch (catch on a malformed values/places string): it was wrapped in an extra, equally-erroneous pair of braces, so instead of raising a clear message it would fail with a confusing "invalid command name" error; also referenced an undefined variable ($type) that isn't in scope on the Arg class (Task has "type"; Arg's own field is "argType"). Fixed to actually call [error ...] with [my argType].

### v53 (2026-jul-20)
added Task.staleAfter -- reads an optional "staleAfter" key from cfg.json, same pattern as dependsOn/whenFail (raw string, no parsing/validation here). Format ("nnn[unit]", unit one of secs/mins/hours/days/weeks/ months/years, defaults to secs) is parsed and enforced entirely in fs-run.tcl (refreshStepStates), and ONLY for the first task in a flow -- this file just stores/returns whatever string is there, same as any other optional field. See fs-run.tcl's own changelog for the enforcement logic and reasoning.

### v52 (2026-jul-20)
version-number cleanup only, no content change from this file as supplied in the golden-base src.zip. Context: earlier this session I built a v50 that bundled two unrelated things together -- a Ctx.log streaming experiment Steve didn't want, AND this file's "package require Tcl 8.6 9" fix. When asked to revert the streaming change, I reverted the WHOLE FILE back to v49 instead of undoing just that one method, which silently threw away the package-require fix too -- and called the result "v51". That v51 is what actually got deployed and is what just failed ("version conflict for package Tcl: have 9.0.4, need 8.6") when Check Status was run under Tcl 9. This golden-base file already has both pieces correct (reverted Ctx.log, package-require fix intact) -- confirmed by reading it directly, not assumed. Only bumping the version number here, from 50 to 52, so it doesn't collide with the earlier (bad) "v50" and so the deployed file reads as newer than the broken v51 it's replacing.

### v50 (2026-jul-18)
package require Tcl 8.6 -> Tcl 8.6 9, so this loads under either Tcl 8.6 or 9.x (single-version pin was refusing to start at all against a 9.x install). Applied against the golden-base src.zip supplied 2026-jul-18 -- no other changes made to this file; the v49 fix above is untouched.

### v49 (2026-jul-18)
fixed a real bug that meant Task.dependsOnNames and Task.whenFailNames were ALWAYS empty, on every task, since the day this constructor was written. The constructor read [my _condGet $node dependsOnNames] and [my _condGet $node whenFailNames] -- but the actual JSON keys written by fs-cfg.tcl (and documented right here in this file's own v2 changelog note) are "dependsOn" and "whenFail", not "dependsOnNames"/"whenFailNames". _condGet silently returns "" for a missing key, so both fields were unconditionally blank at runtime regardless of what a task's cfg.json actually contained. This is why the DependsOn/WhenFail tooltip in fs-run.tcl always showed nothing, and why the newly-added whenFail visibility gating (fs-run.tcl v96-v98) never worked at all -- it was reading a field that could never be populated. Fixed by reading the correct source keys; no schema or JSON format change needed, the cfg files were always correct. puts stderr "==> Loading fs-objs.tcl (v$::FS_OBJS_VERSION)"

## fs-opts.tcl

### v19 (2026-jul-30)
Fixed the OK/Cancel buttons getting clipped off the bottom of the Add/Edit Option dialog -- reported via screenshot on a `directory`-type option (the type with the most fields, so the first to actually overflow). Root cause: the button bar (`$optWin.bot`) was created and packed *last* in the dialog, after both `$optWin.body` and the examples panel, both of which request `-fill both -expand 1`. In a fixed-size 760x660 window, once the two v16-v18 rounds of new fields (`regexPat`/`regexMsg`, `custVal`, `readonly`) pushed the body's content past a certain height, there was nothing left for the button bar to claim -- it was silently squeezed out of the visible window entirely, not resized or scrolled, just gone.

Fixed the standard Tk way: the button bar is now created and packed **first**, with `-side bottom`, so Tk reserves its space before anything else gets laid out -- guaranteed visible no matter how tall the middle content grows. Everything else (top grid, body, examples panel) is unchanged in its own packing, it just now fills whatever's left above the reserved button strip rather than potentially pushing the buttons out of the window. Also bumped the default window height (660 -> 720) and made the dialog resizable, since the content genuinely has grown across the last few rounds of fixes and a bit more breathing room helps regardless of the layout-order fix.

Verified with real pixel measurements against a live rendered window, not just re-reading the pack calls: for both `directory` (the reported case) and `text` (also grew across the same rounds of fixes) option types, confirmed the OK/Cancel buttons' bottom edge sits within the window's actual bottom edge and that they have real, non-zero height -- not just present in the widget tree but genuinely visible on screen. 8/8 checks pass, full existing regression suite clean alongside it.

### v18 (2026-jul-29)
Steve asked directly whether `readonly` (documented alongside `custVal` in the corrected `fs-cfg-task-options-help.md`) was actually implemented in the Configurator's editing UI, the same way `custVal` wasn't before it was pointed out. Checked, confirmed the same gap existed for both, and added real widgets for each -- correctly scoped to where they actually do something at runtime, not just wherever it seemed convenient to put them:

- **`custVal`**: added to both the `text` body *and* the `file`/`directory` body. Confirmed by re-reading `fs-run.tcl`'s `validateOptions` closely: it shares one `switch` case across `text`/`file`/`directory`, and the `custVal` hook-invocation logic sits inside that shared case -- so `custVal` genuinely validates for all three types, not just `text`, and the dialog now matches.
- **`readonly`**: added to the `text` body only. Unlike `custVal`, `readonly`'s actual disabling behavior (`fs-objs.tcl`'s `uiRender`, which grays out and disables the entry widget) only exists inside the `text` case -- `file`/`directory` never check `isReadOnly` at all. Offering the checkbox there would have been a control that silently did nothing, which is exactly the class of bug this whole thread has been about closing, not reintroducing in a new spot.

Both follow the same round-trip fix as `regexPat`/`regexMsg`: `openOptEditor` now preloads both from the existing opt dict on Edit, and `buildOptDict` saves them with blank/unchecked genuinely removing the key (`readonly` uses the same omit-when-false convention already established for `reqd`, not a literal `"false"` in the JSON).

Verified directly: widgets exist exactly where expected and nowhere else (present for `text`+`file`/`directory` on `custVal`, `text`-only on `readonly`, absent entirely for `check`/`radio`/`select`); save-on-Add, preload-on-Edit, and clear-removes-both all confirmed for a `text` opt; `custVal` alone confirmed saving correctly for a `file`-type opt. 12/12 checks pass. Full existing regression suite re-run clean alongside this.

### v17 (2026-jul-29)
Renamed `bindVal` -> `custVal` in the one example-string mention in the Add Option dialog's examples panel ("set readonly and custVal in JSON manually after Add"). Part of the same three-file rename as `fs-objs.tcl` v59 and `fs-run.tcl` v112.

### v16 (2026-jul-29)
Found while inventorying `tcl-flows`/`tcl-help` keyword coverage against the golden source: `regexPat`/`regexMsg` are fully implemented and documented (`fs-objs.tcl` schema, `fs-run.tcl` runtime validation, `fs-cfg-task-options-help.md`), but the Configurator's Add/Edit Option dialog had no input widgets for either -- only mentions in help text and example strings. Worse, `buildOptDict` (which assembles an opt's JSON on Save) never referenced either key, so opening an option that already had them (hand-authored in the JSON, e.g. `fs-real`'s `demo-options` "Gen" field) and clicking Save would silently strip both, destroying working validation with no warning.

Fixed properly, not just a widget: added `Regex Pattern` / `Regex Message` entry fields to the `text` opt type's dialog body (not `check`, which was never documented to support them); `openOptEditor` now preloads both from the existing opt dict on Edit (the actual missing half of the round trip -- adding only the widgets without this would still show blank fields for an option that already had values, and Save would have overwritten them with emptiness); `buildOptDict` now saves both, but omits either key entirely when its field is blank rather than saving an empty string, so clearing a field genuinely removes that key. Per Steve's explicit spec: a `regexMsg` with no `regexPat` is meaningless on its own (the message has nothing to attach to) and is discarded rather than saved as an orphan; confirmed directly against `fs-run.tcl` that a present `regexPat` with a blank `regexMsg` is fine as documented -- the engine falls back to a generic "regex failed" message, so leaving the message blank is a legitimate, supported choice, not a defect.

Verified all six cases directly through the real dialog procs: save-on-Add, preload-on-Edit (the actual bug), clear-both-removes-both, pattern-alone saves cleanly with message correctly absent, message-alone-with-no-pattern discards both, and `check`-type opts get no regex widgets at all. 12/12 checks pass.

### v14 (2026-jul-16)
(1) _addOptPasteExample no longer touches opt(label) in Edit mode -- the Label entry is locked there (existing options can't be renamed this way), so clicking an example shouldn't silently change the underlying value either, even though the widget itself already didn't show it. Add mode is unaffected -- label still gets set/cleared from examples same as before.

### v13
(1) Removed Clone Option entirely: openOptEditor no longer has a "clone" openMode (isClone var/optUI(isClone), the "Clone Option -" title case, the blank-label-on-clone logic, and the openMode parameter itself, since it's now always ""). commitOptSave's isClone branch removed -- it just called commitOptAdd anyway, same as the else fallback. The actual button and its uiCloneItem/openOptEditor call live in fs-cfg.tcl (see that file's changelog).

(2) Fixed _addOptPasteExample: radio/select examples' Values/Places were never actually populated on click -- the code had a comment claiming they'd be "inserted... after the type variable is updated" but nothing did that insertion, and the examples table only ever carried "values: [...] places: [...]" as prose in the comment string, never as real dict fields. Radio and select examples now carry real values/places lists; _addOptPasteExample clears then repopulates the Values/Places text widgets from them. The compact example-row display (_addOptBuildExamples) excludes values/places from its one-line summary -- the comment already gives a short human version, and the real lists can be long now that they're structured data instead of prose.

(3) Fixed _addOptPasteExample to clear every field it manages (label/parm/hint/place/histTag/fileType/reqd, plus Values/Places) when the clicked example doesn't specify it, instead of only ever setting fields and never clearing -- previously, clicking example A (which sets parm/place) then example B (which doesn't mention them) left A's stale values sitting in B's fields. FlowSmithy Options module (hived off from wb-cfg) This file is sourced by fs-cfg.tcl (main configurator). It contains the option editor window + option list UI plumbing.

### v12
(1) openOptEditor enlarged (760x660) with scrollable examples panel below the body frame, mirroring the Add Parm examples approach. Examples are mined from production cfg files and sectioned by opt type. Clicking an example row pre-fills the relevant form fields.

(2) New procs: _optTypeExamples, _optTypeDesc, _addOptBuildExamples, _addOptPasteExample.

(3) rebuildOptBody now also rebuilds the examples panel on type change.

(4) Recipe field removed from all opt types -- recipe column removed from options editor (recipe is Tasks-only from v151 of fs-cfg.tcl).

### v11
(1) commitOptAdd/commitOptEdit call itemPanelSetDirty before validateOptions so Apply Options(s) Change button enables after editing an option

### v10
(1) uiLoadOpts now delegates to uiLoadOptsGrid (treeview) when present, so Add/Edit/Clone commits immediately refresh the visible grid

(2) [see fs-cfg for place vs places grid fix]

### v9
(1) Title: plain " - " separator, driven by openMode (no garbage char)

(2) Dialog height increased 480 -> 600 for more room

(3) Type combobox: added "file" and "directory"

(4) Required checkbox hidden for check/radio/select; shown for text/file/directory only

(5) file/directory body: Place + optional fileType + histTag text entries

(6) Clone mode: preloads all fields from source opt except Label (left blank)

(7) OK/Cancel buttons: ttk::button with WbRounded.TButton style (-) buildOptDict helper extracted (single dict-assembly path for Add/Edit/Clone) (-) formatOptLine extended for file/directory fields (-) uiCloneItem in fs-cfg.tcl wired to openOptEditor $idx clone

## fs-run.tcl

### v117 (2026-aug-03)
Companion to fs-exec.tcl v6 (see that entry for the full design discussion). New `::wb::run::checkTaskRuntime` holds the actual engine-runtime-availability check, structured as an `$ttype` routing table (`java` today, `elseif` branches ready for python/csharp/node) mirroring `::wb::exec::prepTaskExec`'s own routing table in fs-exec.tcl.

Wired into `renderTask` -- called before `loadTaskHooks`, not folded into it. `loadTaskHooks` resets `setupErr` unconditionally at its top *except* on its cached fast-path (`hooksTS == -1`, the common steady state after the first render), where it returns immediately without touching `setupErr` at all -- a check placed inside that proc would only actually run on a task's very first render and go stale/silent afterward. Kept as a separate proc/call instead: `checkTaskRuntime` runs on every `renderTask` (i.e. every task selection, matching Steve's ask that this show up "when the task is selected"), and `loadTaskHooks` is only invoked if the runtime check passed -- avoids the two checks fighting over the single `setupErr` field, and correctly treats a missing runtime as the more fundamental blocker (no point evaluating hook wiring if the interpreter/JVM isn't there).

`java` branch: `$env(JAVA_HOME)/bin/java(.exe)` existence, deliberately matching how `::wb::exec::handleJavaASync` already launches Java (fs-exec.tcl) rather than a PATH-based check -- see fs-exec.tcl v6's entry for the reasoning Steve confirmed before implementing.

### v116 (2026-aug-01)
Added a task-folder reference reachable from `parmExec eval:` strings, per Steve's request ("is there a way to reference the current flow task folder from a parm").

Traced the full `eval:` path first: `parseParmExec`/`populateParmValue` (fs-objs.tcl) hand `eval:` strings to `::wb::run::evalCfgStr`, which `subst`s the string with exactly two commands aliased in -- `[glob <key>]` (reads `$templateTask globs dget key`, i.e. the `::wbobj::Globs` object on `Form`) and `[opt-map ...]`. No task-folder access existed in that vocabulary at all.

Found, while tracing it, that the existing `~flowPath` (`dynEnsureGlobs`) was silently dead for this purpose: it writes into `dynData(globs)`, a plain dict that only feeds `expandGlobs`'s `${key}` template substitution in task descriptions -- a completely different store from the `Globs` object `eval:[glob ...]` actually reads. The two are synced exactly once, at flow load (`$globs set dict [dict get $dynData globs]`, then `dynData globs` is unset) -- anything `dynEnsureGlobs` writes afterward never reaches the `Globs` object. Steve confirmed no flow JSON currently references `eval:[glob ~flowPath]`, so this was inert rather than actively broken.

Fixed by seeding both keys directly into the `Globs` object (not `dynData`), at the two points each is stable:
- `~flowPath`: once, right after the flow-load sync (`buildRunUI` area), from `[file dirname $cfgPath]` -- doesn't change during a run.
- `~taskPath`: on every `selectStep`, from `[$t taskDir]` -- per-task, must be reseeded on switch.

Both use `$globs dset`, so both get the existing "~"-prefix treatment for free: `Globs::dset`/`unset` skip `setDirty` for "~"-prefixed keys (never persisted to `brief.json`), and the globs-table UI (`renderTaskSecGlobs`, `saveDynNow`) already skips "~"/"+"-prefixed keys in both display and persistence. No changes needed to `evalCfgStr`, `dset`, or the UI -- `eval:[glob ~flowPath]/...` and `eval:[glob ~taskPath]/...` now just work, using the same vocabulary as any user-defined glob (e.g. the existing `curDir` parmExec examples).

`dynEnsureGlobs`'s `dynData`-based `~flowPath` seeding was left untouched -- it's a distinct, still-legitimate mechanism for `${flowPath}`-style tokens in task descriptions (via `expandGlobs`), even though no current usage of that specific token was found either.

### v115 (2026-aug-01)
"NO JOY" on v114 -- Steve's exact reproduction (start on the manual step, check a box, visit a different step, come back) still cleared the checkbox. Traced it precisely against the boot log rather than re-guessing: v113/v114's new `staleRefTS`-guarded reset had correctly declined to fire (`skip stale-manual reset for demo-manual -- options.json (...) newer than staleRefTS (...), user already redoing it` -- exactly right). The actual culprit, sitting one line above in the same log and completely unrelated to anything built this week, was `applyOptsDictToTask`'s own pre-existing `forceOff` mechanism (`f=1` in its debug output): "for manual task we ignore persisted options while datestamp on options.json is > than brief.json (Options changed, task not run)". That comparison doesn't actually detect what its comment claims -- it fires on *any* checkbox click through the running UI too, since `persistOptsNow` (the normal, expected path for saving a click) also touches `options.json`'s mtime, and `brief.json` only updates on an actual task completion. So after a manual task's very first completion, `options.json` becomes newer than `brief.json` the moment you click anything, and stays that way until the next real run -- meaning this fired on completely ordinary use, discarding the click on the very next reload.

Reproduced directly before touching anything: built the exact scenario (`brief.json` at an old timestamp simulating a completed task, `options.json` written *after* it with a checked box, simulating an ordinary click with no re-run) and confirmed the current code's `forceOff` really does zero it. Disabled the mechanism -- matching the codebase's own existing convention for keeping disabled code visible with an explanation (`&& 0 ;# t/off ...`) rather than deleting it -- since the case it was actually trying to protect (a stale manual task's checkmarks no longer being trustworthy) is now handled properly and more precisely by `_resetStaleManualCheckboxes` (v113/v114), which is keyed off whether a *later task in the sequence* ran since this one completed, not this task's own file mtimes, and correctly leaves in-progress re-checking alone rather than wiping it on every single visit.

Verified against the real, extracted `applyOptsDictToTask` (not reimplemented) with the exact reported scenario: a manual task's checked box, clicked once and not yet re-run, now correctly survives a reload -- `f=0` throughout, value stays `1`. Full existing regression suite (the v113/v114 stale-manual-reset tests, the skip-scenario `staleRefTS` test) re-run clean alongside it.

### v114 (2026-aug-01)
Steve's follow-up on v113: as originally written, the stale-manual-checkbox reset would fire on *every* `selectStep` visit as long as `stepState` stayed `STALE` -- which it does until the manual task is actually re-run, not just re-confirmed. So a user who navigates back to a stale manual step, starts re-checking its boxes, then clicks away and back (or the panel re-renders for any other reason) would find their in-progress work silently wiped every single time. Fixed with a guard: if `options.json`'s mtime is newer than `staleRefTS` (fs-objs.tcl v61 -- the actual point this task's staleness was judged against), the user has already touched this task's options since it went stale, meaning they're mid-way through redoing the confirmation themselves -- skip the reset.

Steve's specific call on what "the point staleness was judged against" should mean: not "the immediately preceding task in the list" (my first suggestion), but `refreshStepStates`' real `lastFreshTS` high-water mark, since flows can skip steps -- the task directly before a given one in the visible sequence isn't reliably the one whose completion actually set the freshness bar it's being compared to.

Verified two ways. First, with real `Task`/`Arg` objects and hand-set `staleRefTS`/`options.json` mtimes: confirmed the reset is correctly skipped when `options.json` is newer than `staleRefTS` (in-progress work preserved, exactly the bug this closes), and correctly still proceeds when `options.json` is genuinely older (no regression on the case v113 was built for). Second, and more importantly, against the real, unmodified `refreshStepStates` itself (extracted verbatim, not reimplemented) with a 4-task skip scenario -- task 1 fresh, task 2 deliberately stale/lower timestamp (simulating a skipped step), task 3 fresh again with a later timestamp, task 4 (manual) with no `briefTS` of its own -- confirmed task 4's `staleRefTS` correctly reflects task 3's timestamp, the genuine high-water mark, correctly skipping over task 2's lower value rather than naively picking up whatever sits immediately before it. 17 checks across both test passes, all green; full existing regression suite clean alongside it.

### v113 (2026-aug-01)
Completes a feature that was already half-built and sitting disabled in the code: `refreshStepStates` had a stub, guarded by `&& 0` ("t/off manual done indicators"), that inspected a stale manual task's checkbox opts but never actually reset them (`$arg setValue 0` was commented out, and there was no persist call at all). Steve's screenshot showed the actual scenario this was aimed at: a manual task (`demo-manual`) completes with its "did you do this?" checkboxes checked, then a *later* task in the sequence (`demo-depends`) gets re-run afterward -- making the manual task `STALE` per `refreshStepStates`' cross-task timestamp comparison -- and navigating back to it showed the halted icon correctly, but the checkboxes were still showing checked from the no-longer-trusted prior run.

Rather than complete the existing stub in place, implemented this in `selectStep` instead, per Steve's explicit choice between the two: `refreshStepStates` runs on *every* render of *any* task (it's called at the end of `renderTask`), so wiring the reset there would zero out a stale manual task's checkboxes the moment it goes stale, even while looking at a completely different step. `selectStep` only fires when a task actually becomes the one being navigated to, matching "when the step is made current" literally. New proc `::wb::run::_resetStaleManualCheckboxes` (called right after `applyOptsDictToTask` loads the persisted, possibly-stale dict, before `renderTask` displays it): for a `manual`-type task whose `stepState` is `STALE`, any currently-`true` `check`-type opt gets reset both live (`setValue 0`, plus the checkbutton's separate `-variable`-bound UI variable, which is not the same thing) and persisted (`persistOptsNow`, which writes `options.json` and re-renders). `selectStep`'s own subsequent `renderTask` call is skipped when a reset already triggered one via `persistOptsNow`, avoiding a redundant double-render on the (rare) path where this fires.

One real bug surfaced and fixed along the way, unrelated to the feature itself: the live-UI-variable update was first written calling `[$a _uiVarName]` -- which doesn't work from outside the `Arg` class. Confirmed with an isolated two-line TclOO test that this is standard, correct Tcl behavior, not a codebase bug: methods with a leading underscore are unexported by default, callable via `my` from inside the class, never as `$obj methodname` from outside. Fixed by building the same variable name directly from the public `hash` method instead (`"::wb::argVal([$a hash])"`, exactly what `_uiVarName` does internally).

Verified against real `Task`/`Arg`/`Form` objects, not a synthetic dict: a manual task with 3 checkboxes (2 checked) confirmed untouched while `FRESH`; confirmed both checked boxes reset to 0 (internal value, actually-rendered live UI variable, and `options.json` on disk) the moment `stepState` flips to `STALE`; confirmed a checkbox that was already unchecked stays that way with no error; and confirmed a `STALE` task that *isn't* type `manual` is completely unaffected, staying checked -- this is deliberately scoped to manual tasks only. 13 checks, all green. Full existing regression suite re-run clean alongside it.

### v112 (2026-jul-29)
Renamed `bindVal` -> `custVal` (the `needHooks` pre-scan, the hook-invocation block that builds `::wb::opt::hook::<name>` and calls it, and the corresponding error messages). This is the same key discovered a few turns earlier to have a documentation/implementation mismatch: `fs-cfg-task-options-help.md` described `bindVal` as "names a glob key whose value is automatically written into the field at run time," but the actual code does something else entirely -- it names a **custom validation hook proc** to invoke, with no glob-copying involved anywhere. Rather than just fix the doc, Steve chose to rename the key to `custVal` to stop the old name (which read very naturally as "bind this field's value to something") from continuing to invite that same wrong assumption in future readers. Companion changes: `fs-objs.tcl` v59 (schema), `fs-opts.tcl` v17 (one example-string mention), and `fs-cfg-task-options-help.md` (full corrected documentation, describing the actual hook-invocation mechanism -- see that file's own notes for detail, it isn't part of this src.zip's changelog).

Also built out as a real, working example rather than a described-but-untested feature: extracted the one proc with a currently-correct signature (`val-custreq {ctx}`) from an early PSEC-era draft (`test-opt-ctls-hooks.tcl`) into a new stub, `demo-options-hooks.tcl` v01, wired to two new opts added to `fs-real-cfg.json`'s `demo-options` task (`noparm`, a companion checkbox, and `CustValDemo`, a text field whose value the hook sets based on `noparm`'s state). The other two procs in that original draft (`identity`, `globsLookup`) used an older two-argument signature and called into `::wb::parmhook::`, a namespace that was never implemented anywhere in the golden source -- an abandoned earlier design, not carried forward.

Verified end-to-end against the real, unmodified `fs-run.tcl` code (extracted `loadTaskHooks`/`validateOptions` verbatim into an isolated test harness, not reimplemented) and real `fs-objs.tcl` objects: hook loads and registers correctly; fires correctly and sets the expected value in both the "companion checked" and "companion unchecked" cases; correctly reports a clear error when the companion opt is missing entirely; and separately verified against the actual shipped `fs-real-cfg.json` + `demo-options-hooks.tcl` pairing, not just a synthetic fixture. 14 checks total across both test passes, all green.

### v111 (2026-jul-29)
Correction to v110. Steve was explicit: `fs-run.tcl` and `fs-cfg.tcl` should both fast-fail if `flowsmithy.cfg` can't be located -- one source of truth, no graceful degradation. v110's `fsCfgLoad` call was wrapped in `catch` with just a `WARNING:` on failure, on the theory that this file already tolerates a missing `tcl-lib.tcl` gracefully (it's sourced inside an `if {[file exists ...]}` guard) so a missing config should degrade the same way. That reasoning was wrong -- silent degradation is exactly the multiple-sources-of-truth problem this whole thread has been about. Removed the `catch`: `fsCfgLoad` is now called directly, matching `fs-cfg.tcl` and `fs-new.tcl` exactly, and blows up immediately with a clear message if `flowsmithy.cfg` is missing or unreadable. Verified directly: with the config file temporarily removed, the Runner now fails at boot with `FlowSmithy configuration file not found: ...`, the same message `fs-cfg.tcl` has always given.

### v110 (2026-jul-29)
Root cause of the entire "help: bare-filename fallback isn't working" saga (see fs-help.tcl v34-v37): the Runner never calls `fsCfgLoad` anywhere in its own boot sequence. `fs-cfg.tcl` (the Configurator) and `fs-new.tcl` (New Flow) both call it immediately after sourcing `tcl-lib.tcl`; `fs-run.tcl` sources `tcl-lib.tcl` too but never follows up with the load call. This means `::wb::lib::fscfg` has always been an empty array for the entire lifetime of every Runner process, and every `fsCfgGet` call anywhere in the Runner -- `home.dir` included -- has always silently returned `""`. Confirmed directly by the reporter's own boot log: comparing against Configurator boot logs elsewhere in this project, the `==> fsCfgLoad: loaded ...` line that always appears there is simply absent from every Runner boot log ever pasted in this project's history. Not a regression introduced this session -- there's no `fsCfgLoad` call to have removed; it was never there.

Fixed by calling `fsCfgLoad` right after `tcl-lib.tcl` is sourced, matching the same pattern already used by the other two entry points. Made it soft/best-effort (`catch`, with a `WARNING:` on failure) rather than mandatory like `fs-cfg.tcl`'s hard call: this file already treats `tcl-lib.tcl` itself as optional (wrapped in `if {[file exists ...]}`), so a missing or unreadable `flowsmithy.cfg` should degrade functionality (cross-file `help:` links losing their `<home.dir>/help` fallback, for instance) rather than prevent the Runner from launching at all. Verified: the `==> fsCfgLoad: loaded ...` line now appears in the Runner's own boot sequence, in the correct position, before any UI or task rendering begins.

### v109 (2026-jul-28)
Added `tipAttachDynamic` and `tipOnEnterDynamic`, a variant of the existing `tipAttach`/`tipOnEnter` tooltip helper for widgets whose displayed text can change after the tooltip is attached (e.g. an editable combobox bound via `-textvariable`, such as fs-objs.tcl's file/directory value field). The existing `tipAttach` bakes in a static text string at attach time via `bind ... [list ... $text ...]`, which would go stale the moment the user typed something new or clicked Browse to pick a different path. `tipAttachDynamic` instead binds a wrapper that re-reads the bound variable fresh on every `<Enter>` event (`varName` must be a fully-qualified variable name, same convention as `-textvariable`), then delegates to the existing `tipOnEnter`/`tipOnLeave`/`tipOnMotion`/`tipShow`/`tipHide` machinery unchanged. First consumer: fs-objs.tcl v58's file/directory control, showing the full untruncated path on hover. Verified the tooltip correctly reflects a changed value on a second hover, not the value captured when it was first attached.

### v108 (2026-jul-28)
`onViewArgValues` (the "Arg Values" entry on the 3-bar menu) was joining its per-line output with `join $lines " "` -- a single space -- instead of a newline, so every field of every arg ran together onto one unbroken line. The two sibling diagnostic viewers in this same file, `onViewJavaProps` and a third one, both correctly use `join $lines "\n"`; `onViewArgValues` was the only one of the three using a space, which reads like a plain copy-paste slip rather than anything deliberate. Fixed to match the established, correct pattern already used twice elsewhere in this file. Verified directly: reproduced the exact crammed-single-line symptom from the reported screenshot using the old space-join against a real `Arg.viewStr` output, then confirmed the newline-join produces properly separated, readable lines (14 lines from a single test option).

### v106 (2026-jul-21)
removed a dead duplicate ::wb::run::onRunTaskClick -- a bare, older definition with none of the v99+ dependsOn-aware disabled-reason messaging or the SR&ED _powLogAppend hook, silently overridden at load time by the real, maintained definition further down (Tcl's last-definition-wins rule). Zero runtime behavior change -- purely a source-cleanliness fix ahead of public release, per Steve's "no critical flaws that look like a sloppy job" pass.

### v105 (2026-jul-20)
fixed staleAfter (v104) not propagating -- task 1 correctly flipped STALE, but task 2 onward kept coming out fresh anyway. Root cause: the staleAfter override happened AFTER the relative freshness compare had already run, and only the FRESH branch ever advances lastFreshTS (the high-water mark later tasks compare against) -- so the override never touched what subsequent tasks were actually being compared to. New forceStaleFromHereOn flag: set only when staleAfter fires on task 1, checked at the top of every later iteration, ahead of the normal relative compare. Deliberately narrow -- this does NOT make every "naturally" stale task (one whose own briefTS just happens to be older, nothing to do with staleAfter) cascade forward too; that's a bigger behavioral change to freshness semantics for every flow, not just the staleAfter case, and wasn't asked for. Only a staleAfter-forced override on task 1 propagates.

### v104 (2026-jul-20)
added staleAfter -- an optional per-task cfg.json field, "nnn[unit]" (unit one of secs/mins/hours/days/weeks/months/years, default secs), enforced ONLY on the first task in a flow (Steve's design: a stale earlier result implies everyone downstream is suspect too, so checking every task individually is redundant). If set and the first task's briefTS is older than staleAfter seconds, forces STALE regardless of what the existing relative freshness comparison decided -- which, by construction, always calls task 1 fresh on its own, since there's nothing earlier for it to be relatively stale against. Checked after normal fresh/stale determination but before the v99 dependsOn-blocked override, so blocked still wins if both apply. New: _parseStaleAfterSeconds (this file), Task.staleAfter (fs-objs.tcl v53, mirrors how dependsOn/whenFail are stored -- raw string in, no parsing there, all parsing and enforcement live here). Malformed specs log a warning and are treated as unset, never error the whole status refresh. fs-cfg.tcl (Configurator UI to actually set this without hand- editing JSON) is a separate, not-yet-done follow-up -- noted in the tracker, not part of this change.

### v103 (2026-jul-20)
logs window pixel size on resize (debounced, size-change-only, not on pure moves) into the same console panel "Switched to Step..." already uses -- Steve wants to nail down a clean recording resolution for the intro video before the real session. Also logs how far off 16:9 the current size is, since that's specifically what he's tuning for. New: scheduleLogWindowSize/logWindowSizeNow, mirroring scheduleSaveDyn's existing debounce pattern on its own separate timer. Changed: dynBindAutoSave's <Configure> binding now also calls the new scheduler. (No v102 changelog entry exists in this header -- FS_RUN_VERSION was already at 102 in the golden base Steve provided; left as-is rather than fabricated.)

### v102 (2026-jul-18)
package require Tk 8.6 -> Tk 8.6 9, so this loads under either Tcl/Tk 8.6 or 9.x (single-version pin was refusing to start at all against a 9.x install). Applied against the golden-base src.zip supplied 2026-jul-18 -- no other changes made to this file; everything through v101 is untouched.

### v101 (2026-jul-18)
"blocked" formalized as its own named state: a task cannot be run because a task it names in dependsOn is not currently GOOD -- applies uniformly regardless of whether the blocked task itself has ever run before (Steve's definition: no separate case for never-run vs blocked- with-history -- _taskDependsSatisfied already treated these the same, so no logic change here, just naming/icon). Icon renamed from the v100 placeholder state_blocked.png to blocked_dependson_blocked.png per Steve's naming. Color chosen as muted amber/slate rather than red, despite the stop-sign shape being Steve's suggestion and kept -- red is already FAIL/TRAP's color (#b00020 text elsewhere in this file), and a red blocked icon would read as "something's wrong" when blocked is really just "waiting, not broken".

### v100 (2026-jul-18)
added a dedicated "state_blocked.png" icon for a dependsOn-gated task whose dependency isn't satisfied -- overrides whatever icon its own compState/stepState would otherwise select (refreshStepStates). Deliberately a new icon rather than reusing state_halted.png -- that one means something specific already (manual task interrupted mid-flow) and reusing it for "blocked before ever starting" would make both states harder to read correctly. Actual PNG asset needs to be added to the icons/ folder alongside the existing state_*.png files -- loadIconFolder auto-registers anything with a .png extension there, no code-side manifest to update. A placeholder was generated separately for testing; swap in real art whenever convenient, same filename.

### v99 (2026-jul-18)
added dependsOn runnability gating -- mirror image of v96/v97's whenFail visibility gating, using the same watcher/watched relationship (dependsOn names an earlier "watched" task; the task that OWNS the dependsOn field is the one gated). Difference from whenFail: a dependsOn-gated task stays VISIBLE regardless -- it's blocked from RUNNING, not hidden. New: _taskDependsSatisfied (mirrors _taskIsVisible). Changed: canRunCurrent (now also checks dependency satisfaction), onRunTaskClick (disabled-click log message now distinguishes "unmet dependency" from generic busy). A named dependency counts as unmet unless its compState is exactly GOOD -- FAIL, TRAP, AND never-having-run-yet (blank) all block the dependent task equally. This relies on fs-objs.tcl v49 for dependsOnNames to actually be populated at all.

### v98 (2026-jul-18)
fixed a real bug Steve hit testing v97's whenFail gating -- remedial-action stayed visible after check-status recovered to GOOD. Root cause wasn't the gating logic itself: refreshBriefStatusForTask only reloads brief.json when file mtime has changed since last read, and [file mtime] is typically only second-resolution. Two runs of the same task completing within the same second (easy to do manually -- re-running check-status right after a FAIL to confirm recovery) left compState stuck on the FIRST run's result even though the file on disk had actually changed, which _taskIsVisible (added at v96/v97) then read as stale/wrong. Added a $force parameter to refreshBriefStatusForTask, bypassing the mtime check; the post-run render path (renderTask, secs=post-run) now passes force=1, since it already knows a fresh write just happened for exactly that task. The other caller (full-task-list refresh at GUI build time) keeps the cheap mtime-check default. (v98 turned out not to be THE fix either -- see fs-objs.tcl v49: Task.dependsOnNames/whenFailNames were reading the wrong JSON keys and were unconditionally empty on every task. v98's mtime fix is still correct and worth keeping, just wasn't sufficient alone.)

### v97 (2026-jul-18)
CORRECTED v96 -- had the gating direction backwards. whenFail holds the name of an earlier "watched" task; the task that OWNS the whenFail field is the remedial step and is the one that should be hidden/revealed, not the task it names. v96 gated the wrong side of the relationship entirely (it hid whichever task was named inside someone else's whenFail list, revealing it when the OWNER of that field failed -- exactly inverted). _taskIsVisible rewritten: reads the task's own whenFailNames, looks up each named watched task by name (::wb::run::findTaskIndexByName, already existed), and the task is visible once any of them is FAIL/TRAP. No changes needed to refreshStepList/canRunCurrent -- both just call _taskIsVisible, so the fix was fully contained to that one proc.

### v96 (2026-jul-18)
implemented real whenFail gating -- this was previously just tooltip metadata (see the removed "For now: show ALL steps (including whenFail steps)" note above, which was accurate until now). A task named in some other task's whenFail list is now hidden from the step list -- and therefore not selectable/runnable -- until at least one of the task(s) watching it reports compState FAIL or TRAP. Recovers back to hidden if the watched task returns to GOOD on a later run. New: _taskIsVisible (fs-run.tcl). Changed: refreshStepList (skips building/updating rows for hidden tasks, reselects a visible fallback if the current selection just became hidden), canRunCurrent (defense in depth -- refuses to run a task that isn't currently visible, even if curIndex somehow still points at it). Untouched: _tasks (still returns the full unfiltered list -- every curIndex-based call site elsewhere in this file assumes indices into the FULL list, so filtering happened only at the rendering/run-gating layer instead, to avoid reindexing risk).

### v95 (2026-jul-17)
main window icon lookup switched from $::env(TCL_HOME) to [fsCfgGet home.dir], matching the path-resolution convention used elsewhere. Last direct TCL_HOME reference in this file's icon-setting code.

### v36
replace treeview with grid rows; icon-only coloring; widen icon column; ASCII glyphs (no emoji)s), widen icon column to avoid clipping

### v21
first working config loader + GUI populate + XBM icons embedded correctly as strings Usage: tclsh fs-run.tcl <cfgPath> Example: tclsh fs-run.tcl $::env(TCL_FLOWS)/psec-demo/psec-demo-cfg.json

## fs-shell.tcl

### v20 (2026-aug-03)
Steve hit `invalid command name "::wb::help::mdRender"` on first real-world test of v19's welcome screen, thrown from `fsWelcomeShow` at startup. Root cause: `fs-shell.tcl` sources `tcl-lib.tcl` and `fs-new.tcl` at bootstrap, but has never sourced `fs-help.tcl` -- the file that actually defines `::wb::help::mdRender`. `fs-cfg.tcl` and `fs-run.tcl` both source `fs-help.tcl` themselves, but they run as separate `tclsh` child processes (spawned by `tclrun`), entirely separate Tcl interpreters from the shell's own -- their sourcing it never made the proc available here. v19's `fsWelcomeShow` was the first thing in `fs-shell.tcl` itself to ever call `mdRender` directly, which is why this gap went unnoticed until now.

Fix: added `source [file join $fsScriptDir fs-help.tcl]` to the bootstrap block, alongside the existing `tcl-lib.tcl`/`fs-new.tcl` source lines. Confirmed `fs-help.tcl` has no dependencies beyond `Tk` (already required earlier in this file) and standard Tcl -- safe to source directly with no init-order concerns.

### v19 (2026-aug-03)
New welcome screen, driven by the installer thread's flowsmithy.cfg template: on startup, if `show.welcome = 1` is set in flowsmithy.cfg, `fsWelcomeShow` renders `help/user-welcome.md` in its own window (`.wbWelcome`) via the existing `::wb::help::mdRender` path -- same renderer task/flow help already uses, no new markdown engine.

Added one piece of chrome mdRender doesn't provide itself: a "Do not display this window on FS Startup" button that calls `fsWelcomeDismiss`, which persists `show.welcome = 0` back to `flowsmithy.cfg` via tcl-lib.tcl v53's new `fsCfgSetPersist`, then closes the window.

Packing note worth remembering: the dismiss button bar is packed with `-side bottom -before $w.body`. mdRender already packs `$w.body` as `-side top -fill both -expand 1`; Tk's packer allocates cavity space strictly in packing-list order, so a bottom-side widget added *after* an already-packed expand widget gets squeezed to nothing -- `-before` inserts it earlier in the packing list retroactively, which is the correct fix, not a workaround.

Only fires when `show.welcome` is explicitly `1` -- existing installs whose flowsmithy.cfg predates this key simply don't have it, `fsCfgGetBool` defaults to false when a key is absent, so nothing changes for them unless they (or a future installer run) add the key.

Installer (separate thread) writes `show.welcome = 1` into flowsmithy.cfg on first install only -- never overwrites an existing cfg, so this is genuinely first-run-only behavior for fresh installs, not something existing users see appear unexpectedly.

### v18 (2026-aug-03)
"Still no joy" -- Steve's uploaded `flowsmithy.cfg` ruled out the duplicate-line theory from v17 immediately (`home.dir` genuinely appears once). Re-diagnosed from scratch and reproduced the exact reported string byte-for-byte (`script = {h:/tcl h:/tcl/src/fs-run.tcl}`) with a standalone repro before touching any code.

Root cause: `fs-new.tcl` (v07 line 33) calls `fsCfgLoad` unconditionally at its own top level, every time it's sourced -- and `fs-shell.tcl` sources `fs-new.tcl` at bootstrap (line 34), then v14 added its *own* explicit `fsCfgLoad` call right after (line ~40). Two calls, same process, same never-cleared `::wb::lib::fscfg` array. `fsCfgLoad`'s duplicate-key handling (`if exists -> lappend`, by design, for genuinely list-valued keys like `flows.dir`) doesn't distinguish "this key appeared twice in one file" from "this whole load ran twice" -- so the second call lappended every key onto itself, turning every scalar key, `home.dir` included, into a 2-element list of identical values. `file join` on that list-as-string then produced exactly `h:/tcl h:/tcl/src/fs-run.tcl`.

Confirms the earlier "why does `flows` work but not `run`" puzzle too: `flows.dir` suffered the exact same corruption, but `requireTclFlows`/`fsCfgGetList` are list-aware and both (identical) elements resolve to the same real directory, so it silently worked anyway -- `home.dir`, read as a plain scalar and fed straight into `file join`, had no such protection.

Fixed at the actual source of the duplication, not just its symptom: removed this file's own redundant `fsCfgLoad` call -- `fs-new.tcl`'s call is sufficient and was always there. Paired with `tcl-lib.tcl` v52 making `fsCfgLoad` itself idempotent (clears its array before repopulating) as defense in depth against any *future* accidental second call anywhere in the codebase -- but that's insurance, not a substitute for the actual fix of having only one call in the first place.

Verified against the real uploaded cfg file: single call now resolves `home.dir` to a clean scalar and `script` to `h:/tcl/src/fs-run.tcl`; re-ran the same check calling `fsCfgLoad` three times in a row (deliberately exceeding what the fixed code even does) to confirm the array-clear genuinely makes repeated calls safe, not just the corrected single-call path.

### v17 (2026-aug-03)
Steve hit a real "No joy" running `run fs-real`: `script not found: h:/tcl h:/tcl/src/fs-run.tcl` -- note the doubled `h:/tcl`. Diagnosis: `tclrun`'s `set homeDir [fsCfgGet home.dir]` almost certainly returned a 2-element Tcl list (`"h:/tcl h:/tcl"`) instead of a single scalar path, which `[file join $homeDir src fs-run.tcl]` then treated as one directory component containing a literal space -- exactly reproducing the reported error. `fsCfgLoad` accumulates duplicate keys into a list unconditionally (by design, for genuinely list-valued keys like `flows.dir`, read via `fsCfgGetList`), but nothing distinguishes that from an accidentally-duplicated *scalar* key like `home.dir` -- if it appears twice in `flowsmithy.cfg`, `fsCfgGet` silently hands back the same corrupted 2-element string, and the resulting path error gives no hint that the cause is upstream in the cfg file itself.

Requested fix, step one: report the actual `flowsmithy.cfg` path being used, so Steve can go inspect it directly. Startup banner now prints `cfgPath:` (sourced from tcl-lib.tcl v51's new `::wb::lib::fscfgPath`, set by `fsCfgLoad` -- avoids recomputing the same path formula a second time in this file). Also added `info patchlevel` to `help`'s example Tcl commands list, per Steve's request, so the running Tcl/Tk version is a one-liner away without leaving the shell.

Not yet done: no validation added to catch a duplicate scalar key at load time and fail clearly instead of silently producing a mangled multi-word string -- flagged, not implemented, pending Steve confirming this is in fact what's in his cfg file.

### v16 (2026-aug-03)
Follow-up to v15's fallback, at Steve's explicit request: "I hate fallbacks because we end up with multiple run modes to support. prefer fast-fail, fix the failure, keep things simple." Removed the `auto_execok tclsh` PATH fallback from `tclrun`'s tclsh lookup entirely -- it was kept in v15 only as a last resort for the case where no sibling `tclsh.exe` sits next to the running `wish.exe`, but that's exactly the "silently reach for a possibly-mismatched PATH tclsh" behavior the whole v14/v15 sequence was trying to get away from as a *primary* mechanism, and keeping it as a secondary path means two different code paths to reason about and test instead of one.

Now there's exactly one path: sibling `tclsh.exe` next to `[info nameofexecutable]`, or a hard error naming the exact path that was expected but not found. No silent degradation, no second run mode.

### v15 (2026-aug-03)
Immediate follow-up to v14, before it even shipped further: Steve noticed his current `TCL_INSTALL` env var (still set, though no longer read by this file) points at the older Tcl install he originally started with, not the new v9 runtime he's actually running -- purely by accident of the desktop shortcut having always launched `wish.exe` directly, bypassing `TCL_INSTALL` entirely. His observation: since the shortcut is what fixes which runtime everything downstream uses, `tcl.dir` (v14's new cfg key, the config-based replacement for `TCL_INSTALL`) doesn't actually add anything -- it's a second place recording a fact the running process already knows about itself, and the two can drift apart exactly the way `TCL_INSTALL` just had.

Fixed by deriving `tclsh.exe`'s path from `[info nameofexecutable]` instead -- since `fs-shell.tcl` requires Tk and is therefore always running under `wish.exe`, `[info nameofexecutable]` *is* the exact `wish.exe` the shortcut launched, and its sibling `tclsh.exe` in the same `bin\` folder is structurally guaranteed to be the same install/version. No config value involved, nothing that can be stale, nothing for the installer or Steve to keep in sync. `tcl.dir` is removed entirely (not just left unused) -- `fsCfgGet tcl.dir` no longer appears anywhere in this file. `auto_execok tclsh` remains as the last-resort fallback for the case where no sibling `tclsh.exe` exists alongside the running executable.

Net effect versus v14: one fewer thing Steve needs to add to `flowsmithy.cfg`, and one fewer thing the eventual installer needs to write -- `home.dir` and `flows.dir` are the only FS-specific config keys `fs-shell.tcl` now depends on.

### v14 (2026-aug-03)
Steve, thinking ahead to the installer (which will bundle its own private `tclsh.exe`/`wish.exe` rather than depend on whatever's on `PATH`, to avoid runtime-compatibility issues, and which needs to know the install location anyway to build a desktop shortcut), questioned why `fs-shell.tcl` was still reading `TCL_FLOWS`/`TCL_HOME`/`TCL_INSTALL` from the environment when the rest of the codebase had already consolidated on `flowsmithy.cfg` as the one source of truth (`::wb::lib::requireTclFlows`, `tcl-lib.tcl` v50; `fsCfgGet home.dir`, `fs-cfg.tcl` v170).

Traced it: there was no real bootstrap chicken-and-egg forcing the env-var reads. `flowsmithy.cfg` itself is located via `::wb::lib::userHomeDir` (the OS user-home dir), not `TCL_HOME` -- so reading config never depended on the env vars it was sitting alongside. `fs-shell.tcl` already `source`s `tcl-lib.tcl` and so already had `fsCfgGet`/`requireTclFlows` available; it just never called `fsCfgLoad`, the same gap fs-run.tcl had before its v110/v111 fix.

Fixed:
- Added a mandatory, hard-fail `fsCfgLoad` call to `fs-shell.tcl`'s own bootstrap (same convention as fs-run.tcl v110/111 and fs-cfg.tcl v120).
- `runHelp`, `flows`, and `tclrun`'s `cfgPath` now resolve the flows root via `::wb::lib::requireTclFlows` instead of `$::env(TCL_FLOWS)`.
- `tclrun`'s `run`/`cfg` script paths now resolve via `[fsCfgGet home.dir]` instead of `$::env(TCL_HOME)`.
- `tclrun`'s `tclsh.exe` lookup now checks a new `tcl.dir` cfg key (`<tcl.dir>/bin/tclsh.exe`) *before* falling back to `auto_execok tclsh` -- deliberately inverted from the old PATH-first/env-var-fallback order, since the entire point of bundling a private runtime is to stop depending on whatever happens to be on PATH. `auto_execok` is kept as a fallback for dev machines where `tcl.dir` isn't set yet.

No change to `TCL_INSTALL` was kept anywhere -- it's fully replaced by `tcl.dir`, matching the `home.dir`/`flows.dir` naming convention. Steve is adding `tcl.dir` to his own `flowsmithy.cfg` (pointing at his current ActiveTcl install for now, until the installer sets it for real). The installer itself doesn't need to read `tcl.dir` back -- it's the one choosing/writing that path -- but everything downstream that re-locates the runtime after install (this file included) now goes through config instead of guessing.

### v13 (2026-aug-01)
Steve hit a real crash: `flows` (fs-shell's flow-listing command) died outright with a `json2dict` syntax error from inside one flow's `*-cfg.json`, taking down the entire listing instead of just that one flow. Traced to `flowsExpand`: the `jsonFileAsDict $cfgPath` call for each flow's cfg (used only to pull its `title` for display) had no `catch` around it, so a single malformed JSON file anywhere under `$::env(TCL_FLOWS)` aborted the whole command before any flow past it in the loop could be listed.

Fixed by scoping a `catch` to just that one call, per Steve's explicit ask ("catch this, report the error and continue"): on failure, the flow's line in the listing now shows `[cfg error -- see above]` and the actual Tcl error is printed above it via `tklite -red`, then the loop continues to the next flow. Deliberately scoped to this one call site, not a change to `jsonFileAsDict` itself -- that wrapper is used elsewhere (e.g. actually loading a flow to run it) where a malformed cfg genuinely should hard-fail rather than be silently skipped; this fix is specific to the browse/list use case where one broken flow shouldn't hide every other flow from view.

### v11 (2026-jul-17)
both window icon lookups (fsBanner diagnostic, main window) switched from $::env(TCL_HOME) to the already-computed $fsHomeDir (self-located from [info script] at startup, line ~21). Deliberately NOT changed to fsCfgGet home.dir: this file is the bootstrap entry point and fsHomeDir is resolved before/without needing flowsmithy.cfg to be read at all, which is more robust for an icon lookup this early. The env(TCL_HOME) checks used to locate and launch fs-run.tcl/fs-cfg.tcl (the "run"/"cfg" shell commands, ~line 326) are unchanged -- out of scope for this fix, and arguably by design since that's the documented launch contract (TCL_INSTALL/TCL_HOME env vars).

### v10 (2026-may-26)
new command uses clone-only path; default src is TCL_HOME/templates/flow-template

### v09 (2026-may-20)
new command: optional second arg for clone mode

### v08 (2026-may-20)
new command: scaffold and open a new flow

### v07 (2026-03-31)
env/ls/dir: case-insensitive glob fix

## tcl-devp.tcl

### v16 (2026-jul-17)
readJsonFile now sets -encoding utf-8 on read, matching the same fix in tcl-lib.tcl's jsonFileAsDict (was silently mangling non-ASCII characters like em-dashes on read).

## tcl-lib.tcl

### v53 (2026-aug-03)
New `fsCfgSetPersist key value` -- writes a single scalar cfg key back to `flowsmithy.cfg` on disk, in place, preserving every other line (comments, section headers, blank lines, other keys) untouched; appends a new line if the key isn't already present. Also updates the in-memory `::wb::lib::fscfg` array so the running process sees the new value immediately without a full `fsCfgLoad` reload.

Uses `::wb::lib::fscfgPath` (set by `fsCfgLoad`, v51) as the write target rather than recomputing the cfg path itself -- same reasoning as fscfgPath's original purpose: a caller that needs the path should read the one already resolved this session, not maintain a second formula that could drift out of sync with it.

Deliberately not list-aware: if a key legitimately appears on more than one line (the multi-value convention `flows.dir` uses), only the first occurrence is rewritten and any others are left alone. This proc is for simple scalar UI-writable options -- `show.welcome` (fs-shell.tcl v19's welcome-screen dismiss button) is the first caller -- not a general list-editing mechanism.

Verified: round-tripped against a real multi-section flowsmithy.cfg (Editor/Locations/Options, matching the installer-generated template) -- confirmed the target line is rewritten, every other line including comments is byte-identical to the original, the in-memory value updates immediately, and a fresh `fsCfgLoad` afterward reads back the same value from disk independently.

### v52 (2026-aug-03)
Root-cause fix paired with fs-shell.tcl v18 (see that entry for the full trace): `fsCfgLoad` now does `array unset ::wb::lib::fscfg` before repopulating, making repeated calls in the same process idempotent instead of silently accumulating every scalar key into a 2-element list on the second call. This was the actual mechanism behind Steve's "run"/"cfg" failure (`script not found: h:/tcl h:/tcl/src/fs-run.tcl`) -- `fs-new.tcl` and `fs-shell.tcl` were both calling `fsCfgLoad` in the same bootstrap. The real fix is fs-shell.tcl v18 removing its own redundant call; this change is defense in depth so the same class of bug can't resurface silently if something else in the source tree ever adds another stray `fsCfgLoad` call to a shared process.

### v51 (2026-aug-03)
Small addition alongside fs-shell.tcl v17: `fsCfgLoad` now stashes the resolved `flowsmithy.cfg` path in `::wb::lib::fscfgPath` after computing it, so callers that need to report which config file is actually in use (fs-shell's startup banner, in response to Steve's "please log what flowsmithy.cfg we are using") can read it directly instead of recomputing `[file join [::wb::lib::userHomeDir] flowsmithy flowsmithy.cfg]` a second time elsewhere.

### v50 (2026-jul-29)
Consolidated a real duplicate-definition bug, found while confirming Steve's "one source of truth" directive for `flowsmithy.cfg`: `::wb::lib::requireTclFlows` was defined twice -- here, reading `$env(TCL_FLOWS)` directly and erroring if unset; and separately in `fs-cfg.tcl`, reading `flows.dir` from `flowsmithy.cfg`. Both files source this one first, so `fs-cfg.tcl`'s later redefinition always won there (last-definition-wins) -- but `fs-clone.tcl` and `fs-new.tcl` call the same proc with no redefinition of their own, so they'd silently fall back to whichever copy happened to be loaded, order-dependent rather than structurally single-sourced.

Full sweep of every other `.tcl` file for remaining `TCL_*`/other env-var usage that might compete with a `flowsmithy.cfg` value: `JAVA_HOME` (fs-exec.tcl, locating the JVM -- a standard Java-ecosystem variable, unrelated to FlowSmithy's own settings), the `runlog`/`COMPUTERNAME` diagnostic hook (fs-run.tcl, an opt-in audit-log feature, also unrelated), `env-vbl` (a general-purpose feature letting *task authors* reference arbitrary env vars in their own parm values -- intentional, user-facing, not a FlowSmithy-settings mechanism), and `userHomeDir`'s use of `HOME`/`USERPROFILE` (the bootstrap mechanism *for locating flowsmithy.cfg itself* -- foundational, same category of unavoidable exception as `fs-shell.tcl`'s own bootstrap). None of these compete with `flowsmithy.cfg` for a setting it also provides; `requireTclFlows` was the only real duplicate.

This proc is now the one canonical definition, reading `flows.dir` from `flowsmithy.cfg` exclusively -- `fs-cfg.tcl`'s copy is removed (see that file's changelog). Verified with a decoy `env(TCL_FLOWS)` value deliberately set to a different, wrong directory: `requireTclFlows` still correctly resolves from `flowsmithy.cfg` and ignores the environment variable entirely; and with `flows.dir` absent from the config, it fails even though `env(TCL_FLOWS)` is still set, proving no fallback path remains at all.

### v48 (2026-jul-18)
fsCfgLoad was building flowsmithy.cfg's path via [file join ~ flowsmithy flowsmithy.cfg], relying on Tcl's automatic "~" -> home-directory expansion. Tcl 9 removed that (TIP 602) with no automatic fallback, so under a 9.x install the literal characters "~/flowsmithy/flowsmithy.cfg" were being tacked onto the script's own directory, producing "FlowSmithy configuration file not found: D:/.../bin/~/flowsmithy/flowsmithy.cfg" -- confirmed from a real screenshot of the error. New ::wb::lib::userHomeDir resolves the home directory directly via $::env(HOME) / $::env(USERPROFILE) instead, with `file home` (Tcl 9's own replacement command, which doesn't exist under 8.6) only as a last-resort fallback -- so this works identically under both 8.6 and 9.x without depending on which one is running. Verified against simulated HOME and USERPROFILE cases, and the no-env-var error path. This was the only place in the entire codebase relying on filesystem tilde expansion -- swept the rest of the source and found nothing else affected.

### v47
fix jsonFileAsDict missing -encoding utf-8 on read (write side, jsonStrAsFile, already had it -- this asymmetry was the actual cause of em-dashes and other non-ASCII characters in task desc/hint fields rendering as garbage after a save/reload round trip. Confirmed by reproducing it with a real em-dash and inspecting the raw bytes on disk, not just inferred. Same gap also existed in tcl-devp.tcl's own readJsonFile and is fixed there too.

### v46
actual fix: {tasks[].runprops} is "obj" (a plain JSON object, matching fs-run.tcl and existing cfg files like cit-aud), not "arr". v43/44/45 were chasing a non-conforming sample and are fully superseded -- the {tasks[].runprops[]} entry is removed entirely since there's no array. This was always a one-line fix.


---

## Note: why this file exists

Prior to 2026-jul-28, each `.tcl` file accumulated its full dated changelog
as a comment block at the top of the file -- some (`fs-cfg.tcl`) had grown
past 600 lines of history before a single line of code. Steve asked
whether the Tcl engine's need to brace-match through comment text (real,
and worth knowing: an unbalanced brace *inside* a `{...}`-delimited block
like a proc body genuinely breaks parsing -- confirmed directly) meant this
was a performance concern. It isn't: comment scanning is a one-time
parse-time cost with no per-call overhead once a proc is byte-compiled,
and measured directly, fs-objs.tcl's entire ~10KB changelog block added on
the order of 0.3-0.5ms to that one-time file load. The real reason to
move the *full detail* out here is readability: scrolling past hundreds of
lines of prose to reach the first line of code doesn't help anyone, human
or engine.

Each `.tcl` file's own header keeps a skinny one-liner per version --
newest to oldest, right there for a quick "what changed and when" glance
-- with the full reasoning, root-cause analysis, and what-was-tried-and-
reverted detail living here instead.
