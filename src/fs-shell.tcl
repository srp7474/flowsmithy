# Generated 2026-aug-03 courtesy of Claude (claude.ai)
# Code generated on 2026-Mar-26 07:19  courtesy of chatGPT
# fs-shell.tcl - v20
# Changelog (skinny; full detail in CHANGELOG.md):
#   v20 (2026-aug-03): fix "invalid command name ::wb::help::mdRender" on
#     startup -- v19's fsWelcomeShow called mdRender, but fs-shell.tcl
#     never sourced fs-help.tcl (only fs-cfg.tcl/fs-run.tcl did, and
#     those run as separate tclsh processes via tclrun, not in this
#     process). Added source of fs-help.tcl at bootstrap alongside
#     tcl-lib.tcl/fs-new.tcl.
#   v19 (2026-aug-03): new welcome screen -- when flowsmithy.cfg has
#     show.welcome=1 (installer writes this on first install only),
#     startup now opens help/user-welcome.md via mdRender in its own
#     .wbWelcome window, with a "Do not display this window on FS
#     Startup" button that persists show.welcome=0 via tcl-lib.tcl v53's
#     new fsCfgSetPersist. Installer-driven feature, see installer OKF
#     thread.
#   v18 (2026-aug-03): "Still no joy" -- traced precisely and reproduced byte-for-byte: fs-new.tcl (sourced at bootstrap) already calls fsCfgLoad unconditionally at its own top level; v14 added a SECOND fsCfgLoad call right after, same process, and fsCfgLoad never cleared its array between calls -- every scalar cfg key (home.dir included) silently became a 2-element list ("h:/tcl h:/tcl"), which file join then treated as one directory component containing a space, exactly reproducing "script not found: h:/tcl h:/tcl/src/fs-run.tcl". flows.dir has the same 2-element corruption but stayed silently masked, since requireTclFlows/fsCfgGetList are list-aware and both (identical) elements point at a real directory. Fixed at the source of the duplication: removed this file's own redundant fsCfgLoad call (fs-new.tcl's is sufficient) -- paired with tcl-lib.tcl v52 making fsCfgLoad itself idempotent as defense in depth, not a substitute for having only one call.
#   v17 (2026-aug-03): startup banner now reports the resolved flowsmithy.cfg full path (via tcl-lib.tcl v51's new ::wb::lib::fscfgPath) -- Steve hit a "run" failure (script not found: h:/tcl h:/tcl/src/fs-run.tcl) most likely caused by a duplicate home.dir line in his cfg making fsCfgGet return a 2-element list instead of a scalar path; seeing the exact cfg file in use is the first step to spotting that. Also added "info patchlevel" to help's example Tcl commands list.
#   v16 (2026-aug-03): removed the auto_execok tclsh PATH fallback from v15's tclsh.exe lookup -- fast-fail instead, per Steve's explicit "I hate fallbacks, we end up with multiple run modes to support" -- one mode: sibling tclsh.exe next to the running wish.exe, or a clear error naming the expected path
#   v15 (2026-aug-03): tclrun's tclsh.exe lookup no longer uses tcl.dir from flowsmithy.cfg (added in v14) -- derives it from [info nameofexecutable] (the running wish.exe) instead, since Steve pointed out the shortcut already fixes which runtime everything uses, so a separate config value can only drift out of sync with it; tcl.dir is gone, not just unused
#   v14 (2026-aug-03): removed all remaining env(TCL_FLOWS)/env(TCL_HOME)/env(TCL_INSTALL) reads -- runHelp/flows/tclrun now go through fsCfgLoad (added at bootstrap, mandatory/hard-fail) + requireTclFlows/fsCfgGet home.dir/fsCfgGet tcl.dir (new key), matching the one-source-of-truth convention already established elsewhere; tcl.dir tried before auto_execok since a bundled runtime is the whole point
#   v13 (2026-aug-01): flowsExpand no longer aborts the whole "flows" listing when one flow's *-cfg.json fails to parse -- catches jsonFileAsDict per-flow, reports the error in red and continues to the next flow
#   v12 (2026-jul-28): changelog moved to CHANGELOG.md; this header now a skinny per-version log
#   v11 (2026-jul-17): both window icon lookups switched from $::env(TCL_HOME) to self-located $fsHomeDir
#   v10 (2026-may-26): "new" command uses the clone-only path; default src is flow-template
#   v09 (2026-may-20): "new" command takes an optional second arg for clone mode
#   v08 (2026-may-20): new command -- scaffold and open a new flow
#   v07 (2026-03-31): env/ls/dir glob matching made case-insensitive

package require Tk

#----------------------------------------------------------
# fs-shell.tcl
#
# Starter FlowSmithy shell.
# Launch with:
#   %TCL_INSTALL%\bin\wish.exe %TCL_HOME%\src\fs-shell.tcl
#----------------------------------------------------------

set fsVersion   "v20"
set fsScriptDir [file dirname [file normalize [info script]]]
set fsHomeDir   [file dirname $fsScriptDir]
set fsHist      {}
set fsHistIx    0

source [file join $fsScriptDir tcl-lib.tcl]
source [file join $fsScriptDir fs-new.tcl]
source [file join $fsScriptDir fs-help.tcl]

# flowsmithy.cfg is the one source of truth for FS/flows locations
# (home.dir, flows.dir) -- mandatory/hard-fail, same convention as
# fs-run.tcl v110/111 and fs-cfg.tcl v120. Located via userHomeDir, not
# TCL_HOME, so this has no dependency on the env vars it's replacing below.
# NOTE: fs-new.tcl (sourced immediately above) already calls fsCfgLoad
# itself, unconditionally, at its own top level -- that's what actually
# loads it for this file too. Not calling it a second time here on
# purpose: two calls to the same "load config" step in one bootstrap is
# exactly the kind of duplication that caused v14-v17's bug (see
# tcl-lib.tcl v52) -- one call, one place, is the fix, not just making
# a second call safe.

#----------------------------------------------------------
# shell output
#----------------------------------------------------------
proc fsWrite {msg {tag ""}} {
    if {![winfo exists .out]} {
        puts $msg
        return
    }

    .out configure -state normal

    if {$tag ne ""} {
        .out insert end "$msg\n" $tag
    } else {
        fsWriteAnsiLine $msg
        .out insert end "\n"
    }

    .out configure -state disabled
    .out see end
    update idletasks
}

proc fsAnsiTag {code} {
    set code [string trim $code]
    if {[scan $code %d n] != 1} {
        return ""
    }

    switch -- $n {
        0  {return ""}

        30 {return black}
        31 {return darkred}
        32 {return darkgreen}
        33 {return darkyellow}
        34 {return darkblue}
        35 {return darkmagenta}
        36 {return darkcyan}
        37 {return gray}

        90 {return darkgray}
        91 {return red}
        92 {return green}
        93 {return yellow}
        94 {return blue}
        95 {return magenta}
        96 {return cyan}
        97 {return white}

        default {
            return ""
        }
    }
}

proc fsWriteAnsiLine {msg} {
    set esc [format %c 27]
    set rest $msg
    set curTag ""

    while {1} {
        set ix [string first $esc $rest]
        if {$ix < 0} {
            if {$rest ne ""} {
                if {$curTag eq ""} {
                    .out insert end $rest
                } else {
                    .out insert end $rest $curTag
                }
            }
            break
        }

        set before [string range $rest 0 [expr {$ix - 1}]]
        if {$before ne ""} {
            if {$curTag eq ""} {
                .out insert end $before
            } else {
                .out insert end $before $curTag
            }
        }

        set chunk [string range $rest $ix end]

        if {![regexp [format {^%s\[([0-9;]+)m(.*)$} $esc] $chunk -> codes tail]} {
            .out insert end $chunk
            break
        }

        foreach code [split $codes ";"] {
            set code [string trim $code]
            if {$code eq ""} {
                continue
            }

            if {[scan $code %d n] != 1} {
                continue
            }

            if {$n == 0} {
                set curTag ""
                continue
            }

            set newTag [fsAnsiTag $n]
            if {$newTag ne ""} {
                set curTag $newTag
            }
        }

        set rest $tail
    }
}
proc fsPrompt {} {
    return "[pwd] >"
}

proc fsRefreshPrompt {} {
    if {[winfo exists .prompt]} {
        .prompt configure -text [fsPrompt]
    }
}

proc fsBanner {} {
    global fsVersion fsScriptDir fsHomeDir
    #global tcl_platform

    #if {$::tcl_platform(platform) eq "windows"} {
       set iconDir [file join $fsHomeDir "icons" "fs-icon-S.ico"]
       fsWrite "FlowSmithy icon at $iconDir" cyan
    #  ##catch { wm iconbitmap . $iconDir }
    #}


    fsWrite "FlowSmithy Shell $fsVersion" cyan
    fsWrite "scriptDir: $fsScriptDir"
    fsWrite "homeDir:   $fsHomeDir"
    fsWrite "pwd:       [pwd]"
    fsWrite "cfgPath:   $::wb::lib::fscfgPath"
    fsWrite "Type 'help' for starter commands." yellow
    fsWrite ""
    fsRefreshPrompt
}

# ---------------------------------------------------------------------------
# fsWelcomeShow / fsWelcomeDismiss
#
# First-run(ish) welcome screen: renders help/user-welcome.md via the
# normal ::wb::help::mdRender path (own window, .wbWelcome, so it can
# never collide with a task/flow help window) when show.welcome is set
# in flowsmithy.cfg. Adds one extra piece of chrome mdRender doesn't
# provide on its own: a dismiss button that persists show.welcome=0 back
# to flowsmithy.cfg via tcl-lib.tcl's fsCfgSetPersist, so the screen
# doesn't come back on future launches.
#
# The dismiss button bar is packed with -before $w.body -- mdRender
# already packed $w.body as -side top -fill both -expand 1, and Tk's
# packer allocates cavity strictly in packing-list order, so a
# side-bottom widget added AFTER an expand widget gets squeezed out
# entirely unless explicitly inserted ahead of it in the list.
# ---------------------------------------------------------------------------
proc fsWelcomeShow {} {
    global fsHomeDir

    if {![fsCfgGetBool show.welcome]} { return }

    set mdPath [file join $fsHomeDir help user-welcome.md]
    ::wb::help::mdRender "Welcome to FlowSmithy" $mdPath -winname .wbWelcome

    if {[winfo exists .wbWelcome.body]} {
        ttk::frame .wbWelcome.dismiss
        pack .wbWelcome.dismiss -side bottom -fill x -padx 10 -pady {0 10} -before .wbWelcome.body

        ttk::button .wbWelcome.dismiss.btn \
            -text "Do not display this window on FS Startup" \
            -command fsWelcomeDismiss
        pack .wbWelcome.dismiss.btn -side right
    }
}

proc fsWelcomeDismiss {} {
    catch { fsCfgSetPersist show.welcome 0 }
    catch { destroy .wbWelcome }
}

#----------------------------------------------------------
# user commands
#----------------------------------------------------------
proc help {} {
    return [join {
        "FlowSmithy Shell starter commands:"
        "  help               show this help"
        "  cls                clear output window"
        "  ls ?dir?           list files"
        "  dir ?dir?          same as ls"
        "  env ?pattern?      list environment variables"
        "  runHelp | run      show wb/cfg format and available flows"
        "  run <flow>         tclrun TCL_HOME/src/fs-run.tcl with flow cfg"
        "  cfg <flow>         tclrun TCL_HOME/src/fs-cfg.tcl with flow cfg"
        "  new <flow>         create new flow from built-in template (TCL_HOME/templates/flow-template)"
        "  new <flow> <src>   create new flow by cloning existing flow <src>"
        "  flows              list configured flows"
        ""
        "Normal Tcl commands are available directly, for example:"
        "  pwd"
        "  cd h:/tcl"
        "  glob *"
        "  set x 123"
        "  expr {$x + 1}"
        "  info patchlevel   show the exact Tcl/Tk runtime version"
        "  exit"
        ""
        "Special note:"
        "  hilite output from child scripts is shown in this shell."
    } "\n"]
}

proc runHelp {} {
    set flowsDir [::wb::lib::requireTclFlows]

    set out {}
    lappend out "Run shortcuts:"
    lappend out "  run <flow>    - run <flow>"
    lappend out "  cfg <flow>    - configure <flow>"
    lappend out ""
    lappend out "---- Available FS Flows ----"

    foreach cfgPath [lsort -dictionary [glob -nocomplain -directory $flowsDir * *-cfg.json]] {
        set flow [file tail $cfgPath]

        set cfgFile [file join $cfgPath "$flow-cfg.json"]

        if {![file exists $cfgFile]} {
            continue
        }

        set title "<title not found>"

        if {[catch {
            set d [jsonFileAsDict $cfgFile]
            if {[dict exists $d title]} {
                set title [dict get $d title]
            }
        } err]} {
            set title "<json read failed>"
        }

        lappend out [format "%-20s %s" $flow $title]
    }

    return [join $out "\n"]
}

proc cls {} {
    .out configure -state normal
    .out delete 1.0 end
    .out configure -state disabled
    return ""
}

proc flows {} {
   set flowsDir [::wb::lib::requireTclFlows]
   tklite -cyan "flows are at $flowsDir"
   set flowList [flowsExpand $flowsDir]
   foreach flow $flowList {
     tklite -blac $flow
   }
}

proc flowsExpand {dir} {
    set out {}

    foreach path [glob -nocomplain -directory $dir *] {
        if {[file isdirectory $path]} {
            set flow [file tail $path]
            set line [format "%-12s" [string range $flow 0 11]]

            set cfgPath [file join $path "${flow}-cfg.json"]
            if {[file exists $cfgPath]} {
                if {[catch {set cfgDict [jsonFileAsDict $cfgPath]} jerr]} {
                    tklite -red "  [file tail $cfgPath]: $jerr"
                    append line "  \[cfg error -- see above\]"
                } elseif {[dict exists $cfgDict title]} {
                    append line "  " [dict get $cfgDict title]
                }
            }

            lappend out $line
        }
    }

    return $out
}

proc ls {{pat "."}} {
    # pat may be a directory, a glob ("*.tcl"), or bare prefix ("src*").
    # Split into dir + filename pattern so that ls *.tcl and ls src* work
    # even when uplevel has already mangled the glob argument.
    if {[file isdirectory $pat]} {
        set dir  $pat
        set fpat *
    } else {
        set dir  [file dirname $pat]
        set fpat [file tail    $pat]
        if {$dir eq ""} { set dir "." }
    }
    set out {}
    foreach path [lsort -dictionary [glob -nocomplain -directory $dir *]] {
        set tail [file tail $path]
        if {![string match $fpat $tail]} continue
        if {[file isdirectory $path]} {
            lappend out "$tail/"
        } else {
            lappend out $tail
        }
    }
    return [join $out "\n"]
}

proc dir {{pat "."}} {
    return [ls $pat]
}

proc run {flow args} {
    tclrun run $flow {*}$args
}

proc cfg {flow args} {
    tclrun cfg $flow {*}$args
}

proc new {flowName {sourceFlow ""}} {
    return [::wb::new::run $flowName $sourceFlow 1]
}

proc tclrun {{target ""} {flow ""} {args {}} } {
    if {$target eq "" || $flow eq ""} {
      fsWrite [runHelp]
      return
    }

    set homeDir  [fsCfgGet home.dir]
    if {$homeDir eq ""} {
        error "home.dir is not defined in flowsmithy.cfg"
    }
    set flowsDir [::wb::lib::requireTclFlows]

    set target [string tolower $target]

    switch -- $target {
        run {set script [file join $homeDir src fs-run.tcl]}
        cfg {set script [file join $homeDir src fs-cfg.tcl]}
        default {
            error "tclrun target must be run or cfg"
        }
    }

    set cfgPath [file join $flowsDir $flow "${flow}-cfg.json"]

    if {![file exists $script]} {
        error "script not found: $script"
    }
    if {![file exists $cfgPath]} {
        error "cfg not found: $cfgPath"
    }

    # tclsh.exe is derived from the currently-running executable's own
    # folder, not a separately-configured path. fs-shell.tcl is itself
    # launched via wish.exe (by whatever shortcut points at it), so
    # [info nameofexecutable] IS that wish.exe -- its sibling tclsh.exe in
    # the same bin\ folder is guaranteed to be the exact same install/
    # version, with no config value that could drift out of sync with
    # whatever actually launched this shell. No PATH/auto_execok fallback,
    # by design (Steve: "I hate fallbacks -- we end up with multiple run
    # modes to support"). One run mode: sibling tclsh.exe or a clear error.
    set myExe [info nameofexecutable]
    set tclsh [file join [file dirname $myExe] tclsh.exe]
    if {![file exists $tclsh]} {
        error "cannot find tclsh.exe -- expected it alongside the running wish.exe at: $tclsh"
    }

    set cmd [list $tclsh $script $cfgPath]
    if {[llength $args] > 0} {
        set cmd [concat $cmd $args]
    }

    fsWrite "starting: [join $cmd { }]" cyan

    #set chan [open [concat [list |] $cmd [list 2>@1]] r]
    set chan [open [list | {*}$cmd 2>@1] r]
    fconfigure $chan -blocking 0 -buffering line -encoding utf-8

    set ::fsRunCmd($chan)  $cmd
    set ::fsRunFlow($chan) $flow

    fileevent $chan readable [list fsRunReadable $chan]

    return ""
}
proc fsRunReadable {chan} {
    if {[eof $chan]} {
        fileevent $chan readable {}

        # Important: on Windows, close on a nonblocking pipeline channel
        # may not report CHILDSTATUS correctly. Switch back to blocking.
        catch {fconfigure $chan -blocking 1}

        set msg ""
        set rc 0
        set sawCatch 0

        if {[catch {close $chan} msg opts]} {
            set sawCatch 1
            #fsWrite "close catch msg=<$msg>" yellow

            if {[dict exists $opts -errorcode]} {
                set ec [dict get $opts -errorcode]
                #fsWrite "close errorcode=<$ec>" yellow

                if {[llength $ec] >= 3 && [lindex $ec 0] eq "CHILDSTATUS"} {
                    set rc [lindex $ec 2]
                } else {
                    set rc -1
                }
            } else {
                set rc -1
            }
        } else {
            fsWrite "close returned normally" yellow
        }

        set cmd {}
        if {[info exists ::fsRunCmd($chan)]} {
            set cmd $::fsRunCmd($chan)
            catch {unset ::fsRunCmd($chan)}
        }
        catch {unset ::fsRunFlow($chan)}

        #fsWrite "sawCatch=$sawCatch rc=$rc" yellow

        if {$rc == 77} {
            fsWrite "process ended rc=77 - restarting" yellow
            if {[llength $cmd] > 0} {
                after 1 [list fsRunAgain $cmd]
            }
            return
        }

        if {$rc == 0} {
            fsWrite "process ended rc=0" cyan
        } else {
            fsWrite "process ended rc=$rc" red
            if {$msg ne ""} {
                fsWrite $msg yellow
            }
        }
        return
    }

    while {[gets $chan line] >= 0} {
        fsWrite $line
    }
}

proc fsBringToFront {} {
    # Bring this shell window to the top on Windows 11.
    #
    # Strategy (most to least forceful):
    #   1. deiconify  - restore if minimised
    #   2. -topmost 1 - moves window to top of z-order unconditionally
    #   3. raise       - Tk z-order request
    #   4. focus -force - Tk's forceful activate; maps to
    #                     AllowSetForegroundWindow+SetForegroundWindow,
    #                     more likely to be honoured than plain [focus .]
    #   5. after 500ms clear -topmost so window can be moved behind others
    #   6. Taskbar flash - always fires as a guaranteed visible signal
    #                     even if Windows blocks the focus steal entirely

    wm deiconify .
    catch {wm attributes . -topmost 1}
    raise .
    focus -force .
    after 500 {catch {wm attributes . -topmost 0}}

    # Taskbar flash: works regardless of focus-steal prevention.
    # iconify/deiconify round-trip causes Windows to flash the taskbar
    # button amber - guaranteed visible even if focus steal is blocked.
    after 600 {
        catch {
            wm iconify .
            after 200 {wm deiconify .}
        }
    }
}

proc fsRunAgain {cmd} {
    fsWrite "starting: [join $cmd { }]" cyan

    #set chan [open [concat [list |] $cmd [list 2>@1]] r]
    set chan [open [list | {*}$cmd 2>@1] r]
    fconfigure $chan -blocking 0 -buffering line -encoding utf-8

    set ::fsRunCmd($chan) $cmd

    fileevent $chan readable [list fsRunReadable $chan]

    # After restarting the child, surface this shell window so the user
    # can see the "starting:" message and the child's fresh output.
    #fsBringToFront - dropped this V06 as child does it unto self
}

proc env {{pat *}} {
    # Use string match internally rather than passing pat to [array names]
    # so that case-insensitive patterns work:  env t*  env TCL*  env path*
    # (uplevel in fsRunCommand may have mangled or expanded the glob arg)
    set upat [string toupper $pat]
    set out {}
    foreach name [lsort -dictionary [array names ::env]] {
        if {[string match $upat $name]} {
            lappend out [format "%-24s %s" $name $::env($name)]
        }
    }
    return [join $out "\n"]
}

#----------------------------------------------------------
# tklite adapter for wish shell
#
# uses tk tags to colour output
#----------------------------------------------------------

proc tklite {args} {
    if {[llength $args] == 0} {
        return ""
    }

    set tag ""
    set first [lindex $args 0]

    if {[string match "-*" $first]} {
        switch -- $first {
            -black       {set tag black}
            -darkblue    {set tag darkblue}
            -darkgreen   {set tag darkgreen}
            -darkcyan    {set tag darkcyan}
            -darkred     {set tag darkred}
            -darkmagenta {set tag darkmagenta}
            -darkyellow  {set tag darkyellow}
            -gray        {set tag gray}

            -darkgray    {set tag darkgray}
            -blue        {set tag blue}
            -green       {set tag green}
            -cyan        {set tag cyan}
            -red         {set tag red}
            -magenta     {set tag magenta}
            -yellow      {set tag yellow}
            -white       {set tag white}

            default      {set tag ""}
        }
        set msg [join [lrange $args 1 end] " "]
    } else {
        set msg [join $args " "]
    }

    fsWrite $msg $tag
    return ""
}

#----------------------------------------------------------
# command execution
#----------------------------------------------------------
proc fsRunCommand {cmd} {
    global fsHist fsHistIx

    set cmd [string trim $cmd]
    if {$cmd eq ""} {
        return
    }

    lappend fsHist $cmd
    set fsHistIx [llength $fsHist]

    fsWrite "[fsPrompt] $cmd" green

    if {[catch {
        set rc [uplevel #0 $cmd]
    } err opts]} {
        fsWrite $err red
        if {[dict exists $opts -errorinfo]} {
            fsWrite [dict get $opts -errorinfo] magenta
        }
    } else {
        if {$rc ne ""} {
            fsWrite $rc
        }
    }

    fsRefreshPrompt
}

proc fsSubmit {} {
    set cmd [.cmd get]
    .cmd delete 0 end
    fsRunCommand $cmd
}

proc fsHistPrev {} {
    global fsHist fsHistIx

    if {[llength $fsHist] == 0} {
        return
    }

    if {$fsHistIx > 0} {
        incr fsHistIx -1
    }

    .cmd delete 0 end
    .cmd insert 0 [lindex $fsHist $fsHistIx]
}

proc fsHistNext {} {
    global fsHist fsHistIx

    if {[llength $fsHist] == 0} {
        return
    }

    if {$fsHistIx < [llength $fsHist] - 1} {
        incr fsHistIx
        .cmd delete 0 end
        .cmd insert 0 [lindex $fsHist $fsHistIx]
    } else {
        set fsHistIx [llength $fsHist]
        .cmd delete 0 end
    }
}

#----------------------------------------------------------
# UI
#----------------------------------------------------------
wm title . "FlowSmithy(r) $fsVersion Shell"
wm geometry . 1000x700+120+80

if {$::tcl_platform(platform) eq "windows"} {
  set iconPath [file join $fsHomeDir "icons" "fs-icon-S.ico"]
  catch { wm iconbitmap . $iconPath }
  catch { wm iconbitmap . -default $iconPath }
}

grid rowconfigure . 0 -weight 1
grid rowconfigure . 1 -weight 0
grid columnconfigure . 0 -weight 1

text .out \
    -wrap word \
    -state disabled \
    -font {Consolas 11} \
    -yscrollcommand {.sb set}

scrollbar .sb \
    -orient vertical \
    -command {.out yview}

frame .bot
label .prompt -text "" -font {Consolas 10 bold} -anchor w
entry .cmd -font {Consolas 11}

grid .out -row 0 -column 0 -sticky nsew
grid .sb  -row 0 -column 1 -sticky ns
grid .bot -row 1 -column 0 -columnspan 2 -sticky ew

grid columnconfigure .bot 1 -weight 1
grid .prompt -in .bot -row 0 -column 0 -sticky w  -padx 6 -pady 6
grid .cmd    -in .bot -row 0 -column 1 -sticky ew -padx 6 -pady 6


.out tag configure black       -foreground #000000
.out tag configure darkblue    -foreground #00008B
.out tag configure darkgreen   -foreground #006400
.out tag configure darkcyan    -foreground #008B8B
.out tag configure darkred     -foreground #8B0000
.out tag configure darkmagenta -foreground #8B008B
.out tag configure darkyellow  -foreground #B8860B
.out tag configure gray        -foreground #B0B0B0

.out tag configure darkgray    -foreground #606060
.out tag configure blue        -foreground #4DA3FF
.out tag configure green       -foreground #00CC00
.out tag configure cyan        -foreground #00CCCC
.out tag configure red         -foreground #FF4D4D
.out tag configure magenta     -foreground #FF66FF
.out tag configure yellow      -foreground #FFD24D
.out tag configure white       -foreground #FFFFFF

bind .cmd <Return> {fsSubmit}
bind .cmd <Up>     {fsHistPrev; break}
bind .cmd <Down>   {fsHistNext; break}

focus .cmd

fsBanner
fsWelcomeShow
