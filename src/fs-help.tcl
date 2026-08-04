#    fs-help.tcl (v39)
# Changelog (skinny; full detail in CHANGELOG.md):
#   v39 (2026-jul-31): found the real cause of the "Trap" mid-paragraph indent loss that v38 couldn't reproduce -- inline `code` spans were inserted with only the "inlinecode" tag, silently dropping the paragraph's "li" tag; also cleaned up a corrupted, duplicate-option backlnk tag configuration found nearby
#   v38 (2026-jul-31): fixed a loose list item's second paragraph (blank line then indented text) losing its "li" tag entirely and rendering flush-left instead of staying part of the bullet
#   v37 (2026-jul-29): fixed self-contradicting "not found" message -- a bare filename that degraded to a local guess (home.dir unavailable) was wrongly shown the "includes a path" text; now states the real reason (home.dir unset / fsCfgGet unavailable)
#   v36 (2026-jul-29): bare-filename help: links now route straight to <home.dir>/help (never the local task folder); "not found" message states exactly which location was tried
#   v35 (2026-jul-28): changelog moved to CHANGELOG.md; this header now a skinny per-version log
#   v34 (2026-jul-27): cross-file help: links fall back to <home.dir>/help when no local match
#   v33 (2026-jul-27): cross-file help:/help-same: links -- new window vs. replace-with-backlink
#   v32 (2026-jul-27): fixed ordered-list numbering resetting on wrapped/blank-separated list items
#   v31: default help window size increased to 1260x840; mdRender gains -width/-height
#   v30: fixed a bogus [image inuse] guard suppressing nearly every icon
#   v29: fixed _slugify regsub -- unescaped hyphen was breaking as a flag
#   v28: fixed table-cell image rendering; anchor/fragment (#slug) link support
#   v27: inline image support (![alt](img:filename.png)); mdRender gains -imagecache
#   v23: mdRender gains optional -backlink {label url}; back-nav chrome
#   v22: table support (GFM pipe tables)
#   v21: horizontal rule support
#   v20: mdRender gains optional -linkhandler argument
#
# Simple help rendering: Markdown (.md) -> Tk text widget tags
# No HTML intermediate, no platform-specific code.

namespace eval ::wb::help {
  variable VERSION 39

  # Default help window dimensions.  Override per-call via -width / -height.
  variable WIN_W 1260
  variable WIN_H  840

  # List bullet character.
  # NOTE: Keep this as an explicit Unicode codepoint to avoid encoding issues
  # (e.g., source files showing "â€¢" when not treated as UTF-8).
  # You can swap this later for an alternate glyph if desired.
  variable BULLET_CHAR "\u2022"   ;# "•"

  # Light gray background for inline `code` and fenced code blocks.
  variable CODE_BG "#f2f2f2"

  # Table colours
  variable TBL_HDR_BG  "#4A7BA7"   ;# header background (matches treeview heading)
  variable TBL_HDR_FG  "white"
  variable TBL_ROW_BG  "white"
  variable TBL_ALT_BG  "#f5f5f5"   ;# alternate row
  variable TBL_BORDER  "#cccccc"

  # --- Aggressive vertical tightening ---

  # Heading padding: {top bottom}
  set ::wb::help::H1_PAD_Y {8 3}
  set ::wb::help::H2_PAD_Y {6 2}
  set ::wb::help::H3_PAD_Y {6 1}
  set ::wb::help::H4_PAD_Y {6 0}

  # Paragraph spacing
  set ::wb::help::PARA_PAD_Y {6 1}

  # Link rendering
  variable LINK_FG "#0000ee"       ;# standard blue
  variable LINK_HOVER_BG "#00ffff" ;# cyan
  variable LINK_SEQ 0
  variable linkMap
  array set linkMap {}
  variable tipWin ""
  variable tipAfter ""

  # Per-window link handler scripts.
  # Key: toplevel window path.  Value: handler script prefix.
  # When a link is clicked, we call: {*}$script $url
  # If no entry exists for the window, renderHelpLink is used as fallback.
  variable linkHandlerMap
  array set linkHandlerMap {}

  # Horizontal rule: unique canvas widget name counter (reset per mdRender call)
  variable HR_SEQ 0

  # Table: unique frame widget name counter (reset per mdRender call)
  variable TABLE_SEQ 0

  # Image cache: maps "filename@50pct" -> subsampled Tk photo image name.
  # Populated lazily on first use; persists for the process lifetime.
  variable imgCache
  array set imgCache {}

  # Per-render image cache dict supplied via -imagecache argument.
  # Maps filename -> original Tk photo image name (from ::wb::run::iconCache).
  variable curImageCache
  set curImageCache {}

  # Per-render heading anchor map: slug -> text widget mark name.
  # Built during rendering; used by fragment (#slug) link clicks.
  variable curAnchorMap
  array set curAnchorMap {}

  # Per-window tracking of what file/title is currently rendered, so a
  # help: / help-same: link click knows what it's relative to, and so
  # help-same:'s auto-backlink knows what to point back at.
  # Key: toplevel window path. Not set for synthesized fallback content
  # (see -mdtext below) -- only real files update these.
  variable curFileMap
  array set curFileMap {}
  variable curTitleMap
  array set curTitleMap {}

  # Counter used to name additional help windows when help: (not
  # help-same:) opens a new one. Starts at 1; .wbHelp itself is never
  # renamed, so this only ever produces .wbHelp2, .wbHelp3, ...
  variable helpWinSeq 1
}

  # Snapshot / debug export
  # Creates: fs-help-snapshot-v$VERSION-<timestamp>.zip containing:
  #   - render.png      (snapshot of the help window)
  #   - input.md        (copy of the source markdown file)
  #   - parse-dump.txt  (block-level parse dump)
  #   - prompt.txt      (contents of the on-window Prompt box)
  #
  # Timestamp format: YYYYMMDD-HHMMSS (no spaces)

puts stderr "==> Loading fs-help.tcl (v$::wb::help::VERSION)"

# ---- public entry -----------------------------------------------------------

# mdRender title mdPath ?-linkhandler script?
#
# Opens a centered help window and renders a small Markdown subset.
# Optional -linkhandler: a script prefix invoked as {*}$script $url
# when any link in the rendered document is clicked.  When omitted,
# the built-in renderHelpLink stub is used.
#
# Supported markdown:
#   - Headings: #, ##, ###, ####, #####, ######
#   - Unordered lists: -, *, +
#   - Ordered lists: 1. 2. etc
#   - Fenced code blocks: ``` (language ignored)
#   - Inline code: `code`
#   - Bold: **text**
#   - Italic: *text*
#   - Links: [label](url "optional tooltip")
#   - Horizontal rules: --- *** ___ (3 or more, line alone)
proc ::wb::help::mdRender {title mdPath args} {
  variable linkHandlerMap

  # Reset HR and table counters for this document
  set ::wb::help::HR_SEQ    0
  set ::wb::help::TABLE_SEQ 0
  catch { unset ::wb::help::curAnchorMap }
  array set ::wb::help::curAnchorMap {}

  if {$title eq ""} { set title "Help" }

  # Parse optional arguments: -linkhandler, -backlink, -backtop, -imagecache,
  # -winname, -mdtext
  set linkHandler ""
  set backLabel   ""
  set backUrl     ""
  set topLabel    ""
  set topUrl      ""
  set ::wb::help::curImageCache {}
  set winW $::wb::help::WIN_W
  set winH $::wb::help::WIN_H
  set winName ".wbHelp"
  set mdTextOverride ""
  set i 0
  while {$i < [llength $args]} {
    set opt [lindex $args $i]
    if {$opt eq "-linkhandler"} {
      incr i
      set linkHandler [lindex $args $i]
    } elseif {$opt eq "-backlink"} {
      incr i
      set pair [lindex $args $i]
      set backLabel [lindex $pair 0]
      set backUrl   [lindex $pair 1]
    } elseif {$opt eq "-backtop"} {
      incr i
      set pair [lindex $args $i]
      set topLabel [lindex $pair 0]
      set topUrl   [lindex $pair 1]
    } elseif {$opt eq "-imagecache"} {
      incr i
      set ::wb::help::curImageCache [lindex $args $i]
    } elseif {$opt eq "-width"} {
      incr i
      set winW [lindex $args $i]
    } elseif {$opt eq "-height"} {
      incr i
      set winH [lindex $args $i]
    } elseif {$opt eq "-winname"} {
      incr i
      set winName [lindex $args $i]
    } elseif {$opt eq "-mdtext"} {
      incr i
      set mdTextOverride [lindex $args $i]
    }
    incr i
  }

  # Extras (Save button + Prompt box) are enabled only when:
  #   - there is NO current task (standalone usage), OR
  #   - current task globs contains the enable flag "+wb-gen-help/1"
  #
  # Used to coordinate with chatGPT to resolve .md parse issues
  #
  # Current task is obtained from ::wb::run::curTaskObj.
  set wantExtras 0
  set task ""
  if {[info commands ::wb::run::curTaskObj] ne ""} {
    set task [::wb::run::curTaskObj]
  }
  if {$task ne ""} {
    set g ""
    if {![catch { set g [$task globs] }]} {
      if {[$g exists "+wb-gen-help"] && [$g dget "+wb-gen-help"] == 1} { set wantExtras 1 }
    }
  }

  # Read markdown as UTF-8 to avoid mojibake (e.g., â€¢) -- unless the
  # caller supplied the text directly via -mdtext (used for synthesized
  # fallback pages that have no backing file).
  set md ""
  if {$mdTextOverride ne ""} {
    set md $mdTextOverride
  } else {
    if {![file exists $mdPath]} {
      ::wb::help::_errWin "Help not found" "Missing help file:
$mdPath"
      return
    }
    if {[catch {
      set fh [open $mdPath r]
      fconfigure $fh -encoding utf-8 -translation lf
      set md [read $fh]
      close $fh
    } err]} {
      catch {close $fh}
      ::wb::help::_errWin "Help read failed" "Could not read:
$mdPath

$err"
      return
    }
  }

  # Window
  set w $winName
  catch {destroy $w}

  # Clean up any stale handler registration for this window path
  catch { unset linkHandlerMap($w) }

  toplevel $w
  wm title $w $title
  wm geometry $w ${winW}x${winH}
  ::wb::help::_centerWindow $w $winW $winH

  # Register the handler for this window instance (before any links are rendered)
  if {$linkHandler ne ""} {
    set linkHandlerMap($w) $linkHandler
  }

  # Clean up handler registration when window is destroyed
  bind $w <Destroy> [list ::wb::help::_cleanupWindow $w]

  # UI: tiny toolbar + scrollable text
  ttk::frame $w.top
  pack $w.top -side top -fill x -padx 10 -pady {10 6}

  ttk::label $w.top.path -text $mdPath
  pack $w.top.path -side left -fill x -expand 1

  ttk::label $w.top.status -text ""
  pack $w.top.status -side left -padx {10 0}

  if {$wantExtras} {
    ttk::button $w.top.save -text "Save" -command [list ::wb::help::saveSnapshot $w $mdPath]
    pack $w.top.save -side right -padx {6 0}
  }

  ttk::frame $w.body
  pack $w.body -side top -fill both -expand 1 -padx 10 -pady {0 10}

  text $w.body.t -wrap word -undo 0 -takefocus 1
  ttk::scrollbar $w.body.sy -orient vertical -command [list $w.body.t yview]
  $w.body.t configure -yscrollcommand [list $w.body.sy set]

  grid $w.body.t  -row 0 -column 0 -sticky nsew
  grid $w.body.sy -row 0 -column 1 -sticky ns
  grid rowconfigure    $w.body 0 -weight 1
  grid columnconfigure $w.body 0 -weight 1

  ::wb::help::_configureTags $w.body.t

  # Render
  $w.body.t configure -state normal
  if {$backLabel ne "" && $backUrl ne ""} {
    ::wb::help::_insertBackLink $w.body.t $backLabel $backUrl $topLabel $topUrl
  }
  ::wb::help::_mdIntoText $w.body.t $md
  $w.body.t configure -state disabled

  # Record what's now showing in this window, for help:/help-same: link
  # resolution and backlinks -- but only for real files, not synthesized
  # fallback content (-mdtext), which has no meaningful path to link from.
  if {$mdTextOverride eq ""} {
    set ::wb::help::curFileMap($w)  [file normalize $mdPath]
    set ::wb::help::curTitleMap($w) $title
  }


  if {$wantExtras} {
  # Prompt box (saved into snapshot zip). Used to paste "next prompt" notes.
    ttk::frame $w.prompt
    pack $w.prompt -side bottom -fill both -padx 10 -pady {0 10}
  
    ttk::label $w.prompt.l -text "Prompt:"
    pack $w.prompt.l -side top -anchor w
  
    text $w.prompt.t -height 6 -wrap word -undo 0 -takefocus 1
    ttk::scrollbar $w.prompt.sy -orient vertical -command [list $w.prompt.t yview]
    $w.prompt.t configure -yscrollcommand [list $w.prompt.sy set]
  
    pack $w.prompt.sy -side right -fill y
    pack $w.prompt.t  -side left -fill both -expand 1
  }


  # Helpful bindings
  bind $w <Escape> [list destroy $w]
  focus $w.body.t
}

# ---- window cleanup ---------------------------------------------------------

proc ::wb::help::_cleanupWindow {w} {
  variable linkHandlerMap
  variable curFileMap
  variable curTitleMap
  # Note: the bind that invokes this always passes the toplevel's own
  # window path (baked in via [list ... $w] at bind time), so this fires
  # correctly per-window even though child-widget Destroy events also
  # bubble through the toplevel's bindtag. No longer restricted to
  # ".wbHelp" -- cross-file help: links can open .wbHelp2, .wbHelp3, ...
  # and each needs its own cleanup.
  catch { unset linkHandlerMap($w) }
  catch { unset curFileMap($w) }
  catch { unset curTitleMap($w) }
}

# ---- rendering --------------------------------------------------------------

proc ::wb::help::_mdIntoText {t md} {
  set lines [split $md "\n"]
  set inCode  0
  set inOList 0
  set inUList 0
  set oNum    0
  set inTable 0
  set tableRows {}

  # Buffer normal paragraph lines so we don't manufacture extra blank lines.
  set paraLines {}

  # Buffer for the list item currently being built, so that a wrapped
  # continuation line (no marker of its own) joins onto the same item
  # instead of being mistaken for the end of the list. Mirrors paraLines.
  set liMarker ""
  set liBuf    {}

  # True immediately after a blank line while still (tentatively) inside a
  # list. A single blank line between "N. item" lines is a normal "loose"
  # list in Markdown and must NOT end the list or reset the numbering; only
  # genuine non-list content (a plain paragraph line, heading, hr, table, or
  # code fence) ends it. afterBlank distinguishes "blank line then next item"
  # (list continues) from "blank line then ordinary prose" (list has ended).
  set afterBlank 0

  foreach line $lines {
    regsub -all "\r" $line "" line

    # Fenced code blocks
    if {[regexp {^\s*```} $line]} {
      # flush pending paragraph, list item, and any open table first
      ::wb::help::_flushPara t paraLines
      ::wb::help::_flushLi t liMarker liBuf
      set inOList 0
      set inUList 0
      set oNum 0
      set afterBlank 0
      if {$inTable} {
        ::wb::help::_insertTable $t $tableRows
        set inTable 0
        set tableRows {}
      }

      if {$inCode} {
        set inCode 0
        # One trailing newline after the code block; rely on codeblock spacing3 for padding.
        $t insert end "\n" codeblock
      } else {
        set inCode 1
        # Ensure the code block starts on a fresh line
        $t insert end "\n" p
      }
      continue
    }

    if {$inCode} {
      $t insert end "$line\n" codeblock
      continue
    }

    # Blank line => paragraph break / table end / tentative list break.
    # Do NOT reset inOList/inUList/oNum here: a single blank line between
    # list items is a "loose" list and must not restart the numbering.
    # The list is only truly ended if the following non-blank line isn't
    # itself another list item (see afterBlank handling below).
    #
    # Also do NOT flush the pending list item here if we're still
    # tracking a list: a blank line followed by MORE indented content is
    # a second paragraph within the SAME list item (a "loose" list item
    # with multiple paragraphs), not the end of it -- e.g.
    #   - **Gen** first paragraph text...
    #
    #     second paragraph, still part of the Gen bullet
    #
    #   - **GenStr** next bullet
    # Previously this always flushed unconditionally, so that second
    # paragraph lost its "li" tag entirely and rendered as a plain,
    # unindented paragraph -- confirmed directly by rendering real
    # content and inspecting per-line tags. Only flush here when we're
    # NOT in a list at all; the indentation check that decides whether a
    # continuation after a blank line stays in the list lives below, in
    # the plain-line handling.
    if {[string trim $line] eq ""} {
      ::wb::help::_flushPara t paraLines
      if {!$inOList && !$inUList} {
        ::wb::help::_flushLi t liMarker liBuf
      }
      if {$inTable} {
        ::wb::help::_insertTable $t $tableRows
        set inTable 0
        set tableRows {}
      }
      set afterBlank 1
      continue
    }

    # Horizontal rule: ---, ***, ___ (3 or more of same char, nothing else)
    if {[regexp {^\s*([-*_])\1{2,}\s*$} $line]} {
      ::wb::help::_flushPara t paraLines
      ::wb::help::_flushLi t liMarker liBuf
      if {$inTable} {
        ::wb::help::_insertTable $t $tableRows
        set inTable 0
        set tableRows {}
      }
      ::wb::help::_insertHR $t
      set inOList 0
      set inUList 0
      set oNum 0
      set afterBlank 0
      continue
    }

    # Table row: starts and ends with | OR has at least two | separators
    # Separator rows (|---|---| etc) are detected inside _insertTable.
    if {[regexp {^\s*\|} $line] || [regexp {\|\s*$} $line]} {
      ::wb::help::_flushPara t paraLines
      ::wb::help::_flushLi t liMarker liBuf
      set inOList 0
      set inUList 0
      set oNum 0
      set afterBlank 0
      set inTable 1
      lappend tableRows $line
      continue
    }

    # If we were in a table and hit a non-table line, flush it first
    if {$inTable} {
      ::wb::help::_insertTable $t $tableRows
      set inTable 0
      set tableRows {}
    }

    # Headings (#..######) with optional closing hashes (e.g., "## Title ##")
    if {[regexp {^\s*(#{1,6})\s*(.*)$} $line -> hs ht]} {
      ::wb::help::_flushPara t paraLines
      ::wb::help::_flushLi t liMarker liBuf

      set n [string length $hs]

      # Robustly strip optional closing hashes.
      set ht [string trim $ht]
      while {[regexp {^(.*\S)\s+#+\s*$} $ht -> ht2]} {
        set ht $ht2
        set ht [string trim $ht]
      }

      if {$ht eq ""} { set ht " " }
      ::wb::help::_insertHeading $t $ht $n
      set inOList 0
      set inUList 0
      set oNum 0
      set afterBlank 0
      continue
    }

    # Unordered list items: -, *, +
    if {[regexp {^\s*[-*+]\s+(.*)$} $line -> liText]} {
      ::wb::help::_flushPara t paraLines
      # A new item starts: flush whatever item (ordered or unordered) was pending.
      ::wb::help::_flushLi t liMarker liBuf

      set inOList 0
      set oNum 0
      set inUList 1
      set afterBlank 0

      # Render our own bullet glyph to avoid encoding issues from source file
      set liMarker $::wb::help::BULLET_CHAR
      set liBuf [list $liText]
      continue
    }

    # Ordered list items: "1. item" (numbers are ignored; we auto-number)
    if {[regexp {^\s*(\d+)[\.)]\s+(.*)$} $line -> _n liText]} {
      ::wb::help::_flushPara t paraLines
      # A new item starts: flush whatever item (ordered or unordered) was pending.
      ::wb::help::_flushLi t liMarker liBuf

      if {!$inOList} {
        set inOList 1
        set oNum 1
      } else {
        incr oNum
      }
      set inUList 0
      set afterBlank 0
      set liMarker "$oNum."
      set liBuf [list $liText]
      continue
    }

    # A plain line (no list marker) while a list is open.
    #   - If it directly follows a list-item line (no blank line since),
    #     it's a wrapped continuation of that item (GitHub-style lazy
    #     continuation) — join it onto the current item.
    #   - If a blank line intervened, it's STILL a continuation of the
    #     same item -- a second paragraph within a "loose" list item --
    #     as long as this line is indented, matching CommonMark's rule
    #     that indented content after a blank line stays inside the list
    #     item it follows. Only a genuinely flush-left line after a
    #     blank line means the list has actually ended.
    if {$inOList || $inUList} {
      set isIndented [expr {[string length $line] > [string length [string trimleft $line]]}]
      if {!$afterBlank || $isIndented} {
        lappend liBuf [string trim $line]
        set afterBlank 0
        continue
      }
    }

    # Leaving a list (any non-list, non-continuation content ends it).
    # Flush whatever list item was still pending -- no longer guaranteed
    # already-flushed, since a blank line alone no longer flushes it
    # (see above); this is the point where we've now confirmed the list
    # is genuinely over.
    ::wb::help::_flushLi t liMarker liBuf
    set inOList 0
    set inUList 0
    set oNum 0
    set afterBlank 0

    # Buffer normal paragraph line (supports inline `code`)
    lappend paraLines $line
  }

  # final flush
  ::wb::help::_flushPara t paraLines
  ::wb::help::_flushLi t liMarker liBuf
  if {$inTable} {
    ::wb::help::_insertTable $t $tableRows
  }

}

# Convert heading text to a URL-fragment slug matching GitHub Markdown convention:
#   lowercase, spaces -> hyphens, non-alphanumeric (except hyphens) removed.
proc ::wb::help::_slugify {text} {
  set s [string tolower $text]
  regsub -all {[^a-z0-9 \-]} $s "" s
  regsub -all { +} $s "-" s
  regsub -all {\-+} $s "-" s
  set s [string trim $s "-"]
  return $s
}

# Insert a heading at level n (1-6), register a named mark for fragment links,
# then render the heading text with inline markup support.
proc ::wb::help::_insertHeading {t text n} {
  set tag "h$n"
  set slug [::wb::help::_slugify $text]

  # Set a mark at the current insert position so fragment links can scroll here.
  # Use a unique suffix if the same slug appears more than once.
  set markName "anchor.$slug"
  set suffix 0
  while {[lsearch -exact [$t mark names] $markName] >= 0} {
    incr suffix
    set markName "anchor.${slug}.${suffix}"
  }
  $t mark set $markName insert
  $t mark gravity $markName left
  set ::wb::help::curAnchorMap($slug) $markName

  ::wb::help::_insertInline $t $text $tag
  $t insert end "\n" $tag
}

# Inserts text with inline-code handling (`like this`)
proc ::wb::help::_insertInline {t s baseTag} {
  # Split on backticks and render odd segments as inline code.
  # Even segments get simple emphasis parsing (**bold** and *italic*).
  set parts [split $s "`"]
  set n [llength $parts]
  if {$n == 1} {
    ::wb::help::_insertLinks $t $s $baseTag
    return
  }

  for {set i 0} {$i < $n} {incr i} {
    set seg [lindex $parts $i]
    if {$seg eq ""} { continue }

    if {($i % 2) == 1} {
      # Combine baseTag with inlinecode -- every other inline-formatting
      # branch (bold, italic, links) does this via [list $baseTag ...];
      # this one didn't, which meant a code span lost its paragraph-level
      # tag (e.g. "li") entirely. For most tags that's invisible (color/
      # font differences aside), but "li" also carries the hanging-indent
      # lmargin1/lmargin2 -- and when a wrapped display line happened to
      # start exactly at a tag-less code span (e.g. `TestArgsFS` mid-
      # paragraph), Tk had no "li" tag at that position to resolve the
      # margin from, and the line rendered flush-left instead of indented.
      # Confirmed directly: this is the same repro pattern reported twice
      # now, both times breaking exactly at a backtick-code word.
      $t insert end $seg [list $baseTag inlinecode]
    } else {
      ::wb::help::_insertLinks $t $seg $baseTag
    }
  }
}

proc ::wb::help::_insertLinks {t s baseTag} {
  # Parse links of the form:
  #   [label](url "optional tooltip")
  #   ![alt](img:filename.png)   <- inline image via img: scheme
  # Outside links, render minimal emphasis.
  set rest $s
  while {$rest ne ""} {
    # Match both image syntax ![...](...) and link syntax [...](...).
    # We test for the leading '!' to distinguish the two.
    if {![regexp -indices {!?\[[^\]]*\]\([^\)]+\)} $rest m]} {
      ::wb::help::_insertEmphCore $t $rest $baseTag
      break
    }

    lassign $m a b
    if {$a > 0} {
      ::wb::help::_insertEmphCore $t [string range $rest 0 [expr {$a-1}]] $baseTag
    }

    set frag [string range $rest $a $b]

    # Detect image vs link by leading '!'
    if {[string index $frag 0] eq "!"} {
      # Image: ![alt](img:filename "optional title")
      if {[regexp {^!\[([^\]]*)\]\((img:[^\s\)]+)(?:\s+"[^"]*")?\)$} $frag -> alt imgRef]} {
        set fileName [string range $imgRef 4 end]  ;# strip "img:" prefix
        ::wb::help::_insertImageWidget $t $alt $fileName $baseTag
      } else {
        # Doesn't match our img: pattern — render as plain text.
        ::wb::help::_insertEmphCore $t $frag $baseTag
      }
    } else {
      # Regular hyperlink: [label](url "optional title")
      set label ""
      set url ""
      set title ""
      if {[regexp {^\[([^\]]+)\]\(([^\s\)]+)(?:\s+"([^"]*)")?\)$} $frag -> label url title]} {
        ::wb::help::_insertLinkWidget $t $label $url $title $baseTag
      } else {
        ::wb::help::_insertEmphCore $t $frag $baseTag
      }
    }

    set rest [string range $rest [expr {$b+1}] end]
  }
}

proc ::wb::help::_insertLinkWidget {t label url title baseTag} {
  # Insert clickable link text into the Text widget via a unique tag.
  incr ::wb::help::LINK_SEQ
  set tag "link$::wb::help::LINK_SEQ"

  # Store mapping for callbacks
  set ::wb::help::linkMap($tag,url)   $url
  set ::wb::help::linkMap($tag,title) $title

  # Resolve which toplevel window owns this text widget
  set win [winfo toplevel $t]
  set ::wb::help::linkMap($tag,win)   $win

  # Insert with both tags: baseTag controls font/spacing; link tag controls interaction.
  $t insert end $label [list $baseTag $tag]

  $t tag configure $tag -foreground $::wb::help::LINK_FG -underline 0
  $t tag bind $tag <Enter>    [list ::wb::help::_linkEnter $t $tag]
  $t tag bind $tag <Leave>    [list ::wb::help::_linkLeave $t $tag]
  $t tag bind $tag <Button-1> [list ::wb::help::_linkClick $t $tag]
}

# _insertImageWidget --
#   Resolve "img:filename" against curImageCache, create a 50%-subsampled copy
#   (cached in imgCache), and embed it in the text widget at the current insert
#   position.  Falls back to rendering alt-text as plain text if the image
#   cannot be found or loaded.
#
proc ::wb::help::_insertImageWidget {t altText fileName baseTag} {
  variable curImageCache
  variable imgCache

  # Look up the original photo image from the cache supplied by the caller.
  set origImg ""
  if {$curImageCache ne "" && [dict exists $curImageCache $fileName]} {
    set origImg [dict get $curImageCache $fileName]
  }

  if {$origImg eq ""} {
    # Image not in cache — render alt text as plain text instead.
    if {$altText ne ""} {
      $t insert end "\[${altText}\]" $baseTag
    }
    return
  }

  # Create a 50%-subsampled copy if not already cached.
  set cacheKey "${origImg}@50pct"
  if {![info exists imgCache($cacheKey)]} {
    set smallImg [image create photo]
    $smallImg copy $origImg -subsample 2 2
    set imgCache($cacheKey) $smallImg
  }
  set img $imgCache($cacheKey)

  # Embed the image inline.
  $t image create end -image $img -padx 2 -pady 2
}

proc ::wb::help::_linkEnter {t tag} {
  $t tag configure $tag -background $::wb::help::LINK_HOVER_BG

  # Hand cursor while hovering (Tk text tags do not support -cursor on some builds)
  if {![info exists ::wb::help::prevCursor]} {
    catch { set ::wb::help::prevCursor [$t cget -cursor] }
  }
  catch { $t configure -cursor hand2 }

  # Tooltip after 1 second (only if title is present)
  ::wb::help::_cancelTip
  set title ""
  catch { set title $::wb::help::linkMap($tag,title) }
  if {[string trim $title] eq ""} { return }
  set ::wb::help::tipAfter [after 1000 [list ::wb::help::_showTip $t $tag]]
}

proc ::wb::help::_linkLeave {t tag} {
  $t tag configure $tag -background ""
  ::wb::help::_cancelTip
  ::wb::help::_hideTip
}

proc ::wb::help::_linkClick {t tag} {
  variable linkHandlerMap

  set url ""
  catch { set url $::wb::help::linkMap($tag,url) }
  if {$url eq ""} { return }

  # Fragment-only link (#slug) — scroll the text widget to the named anchor mark.
  if {[string index $url 0] eq "#"} {
    set slug [string range $url 1 end]
    if {[info exists ::wb::help::curAnchorMap($slug)]} {
      set markName $::wb::help::curAnchorMap($slug)
      catch { $t see $markName }
    }
    return
  }

  # Resolve the owning window (needed both for cross-file help: links below
  # and for the registered-handler lookup that follows).
  set win ""
  catch { set win $::wb::help::linkMap($tag,win) }

  # Cross-file help:<path>[#anchor] / help-same:<path>[#anchor] links.
  # Deliberately excludes help:// (double-slash) -- that's a pre-existing,
  # unrelated scheme used by fs-cfg.tcl's own -linkhandler routing
  # (::wb::cfg::helpLinkHandler), which must keep working unchanged.
  set resolved [::wb::help::_resolveHelpLink \
      [::wb::help::_currentFileFor $t] $url]
  if {$resolved ne ""} {
    lassign $resolved targetPath anchor sameWindow relPath route
    ::wb::help::_openHelpLink $win $targetPath $anchor $sameWindow $relPath $route
    return
  }

  if {$win ne "" && [info exists linkHandlerMap($win)]} {
    # Injected handler: invoke as {*}$handler $url
    catch { {*}$linkHandlerMap($win) $url }
  } else {
    catch { ::wb::help::renderHelpLink $url }
  }
}

# ---- cross-file help links (help: / help-same:) -----------------------------

# Get the source file backing the window that owns text widget $t, so a
# help:/help-same: link found inside it can be resolved relative to it.
# Returns "" if the window wasn't opened against a real file (e.g. it's
# currently showing synthesized -mdtext fallback content, or is a context
# help window fs-cfg.tcl built directly rather than through mdRender).
proc ::wb::help::_currentFileFor {t} {
  set win [winfo toplevel $t]
  set f ""
  catch { set f $::wb::help::curFileMap($win) }
  return $f
}

# Resolve a help:/help-same: URL found in $sourceFile into an absolute
# target path, an optional anchor slug, whether it should replace the
# current window (1) or open a new one (0), and which routing rule was
# used to compute the target path ("homehelp" or "local") -- needed so
# _openHelpLink/_openHelpFallback can report exactly what was tried
# instead of a message that can't tell the user (or the next person
# debugging this) whether the shared-help fallback even ran.
# Returns "" if $url doesn't match either scheme (including the unrelated
# pre-existing help:// double-slash scheme, which is left untouched).
#
# Routing rule (exclusive, not layered):
#   - A BARE filename (no "/" or "\" anywhere in it, e.g.
#     "fs-run-help.md") always resolves against <home.dir>/help --
#     FlowSmithy's shared help folder. This is the common case for
#     referencing FS's own main help content from any task/flow help
#     file, regardless of how deeply that file is nested.
#   - Anything else -- a path containing "/" or "\" (e.g. "sub/other.md",
#     "../other.md"), or an already-absolute path -- resolves LOCALLY,
#     relative to the file that referenced it, exactly as a same-folder
#     or relative sibling reference would.
# There is deliberately no secondary fallback between the two: a bare
# name that isn't in <home.dir>/help is reported as not found there,
# full stop, rather than silently also trying a local interpretation
# (which previously made "did the fallback even run?" impossible to
# tell from the resulting error message alone).
proc ::wb::help::_resolveHelpLink {sourceFile url} {
  set sameWindow 0
  if {[string match "help-same:*" $url]} {
    set sameWindow 1
    set rest [string range $url 10 end]
  } elseif {[string match "help:*" $url] && ![string match "help://*" $url]} {
    set rest [string range $url 5 end]
  } else {
    return ""
  }

  set anchor ""
  if {[regexp {^([^#]*)#(.*)$} $rest -> filePart anchorPart]} {
    set rest   $filePart
    set anchor $anchorPart
  }

  set isBare [expr {[string first "/" $rest] < 0 && [string first "\\" $rest] < 0}]

  if {$isBare} {
    set route "homehelp"
    set targetPath [::wb::help::_defaultHelpDirPath $rest]
    if {$targetPath eq ""} {
      # This is a bare filename -- it SHOULD go to <home.dir>/help -- but
      # _defaultHelpDirPath couldn't produce a path at all (fsCfgGet not
      # loaded, or home.dir not set in flowsmithy.cfg). Falling back to a
      # local guess is still better than an unusable empty path, but this
      # is NOT the same situation as a genuinely path-qualified reference
      # -- give it its own route value so the resulting message says what
      # actually happened instead of the misleading "includes a path"
      # text (a bare name obviously doesn't).
      set unavailReason "unknown reason"
      if {[info commands fsCfgGet] eq ""} {
        set unavailReason "fsCfgGet is not available (tcl-lib.tcl not loaded in this context)"
      } else {
        set unavailReason "home.dir is not set in flowsmithy.cfg"
      }
      set route "homehelp-unavailable:$unavailReason"
      set targetPath [file normalize [file join [file dirname $sourceFile] $rest]]
    }
  } else {
    set route "local"
    # file join with an absolute $rest just returns $rest -- this covers
    # both author-written-relative paths and already-absolute ones.
    set targetPath [file normalize [file join [file dirname $sourceFile] $rest]]
  }

  return [list $targetPath $anchor $sameWindow $rest $route]
}

# Resolve $relPath (the raw path portion of a help:/help-same: URL, as
# written -- before it was joined against the source file's directory)
# against <home.dir>/help, FlowSmithy's shared help folder per
# flowsmithy.cfg. This is the fallback location tried when a cross-file
# help link doesn't exist relative to the file that referenced it, so a
# task/flow help file can reach FS's own main help content (e.g.
# help:fs-run-help.md#globs-table) without needing a relative ../../..
# chain back to the shared folder.
# Returns "" (meaning: no fallback available/applicable) if:
#   - $relPath is empty or already absolute -- an absolute path has
#     nothing to gain from being reinterpreted under home.dir/help, and
#   - fsCfgGet isn't loaded (fs-help.tcl has no hard dependency on
#     tcl-lib.tcl) or home.dir isn't set in flowsmithy.cfg.
proc ::wb::help::_defaultHelpDirPath {relPath} {
  if {$relPath eq ""} { return "" }
  if {[file pathtype $relPath] ne "relative"} { return "" }
  if {[info commands fsCfgGet] eq ""} { return "" }
  set homeDir ""
  catch { set homeDir [fsCfgGet home.dir] }
  if {$homeDir eq ""} { return "" }
  return [file normalize [file join $homeDir help $relPath]]
}

# Handle a resolved help:/help-same: link click.
#   win        - the toplevel window the click came from (for looking up
#                curFileMap/curTitleMap to build a backlink)
#   targetPath - absolute path from _resolveHelpLink
#   anchor     - anchor slug, or ""
#   sameWindow - 1 for help-same:, 0 for help:
#   relPath    - the raw path portion of the URL as written (used in the
#                not-found message so it's clear what was typed)
#   route      - "homehelp", "local", or "homehelp-unavailable:<reason>"
#                from _resolveHelpLink -- which rule decided targetPath,
#                used to make the not-found message state plainly what
#                was tried and why (the third form covers a bare filename
#                that SHOULD have gone to <home.dir>/help but couldn't,
#                e.g. home.dir isn't set -- see _resolveHelpLink).
proc ::wb::help::_openHelpLink {win targetPath anchor sameWindow {relPath ""} {route "local"}} {
  variable curFileMap
  variable curTitleMap
  variable helpWinSeq

  # Figure out where we're coming FROM, for the backlink (same-window
  # case only) and for constructing a sensible fallback message.
  set sourceFile ""
  set sourceTitle "Help"
  catch { set sourceFile  $curFileMap($win) }
  catch { set sourceTitle $curTitleMap($win) }

  if {![file exists $targetPath]} {
    if {$route eq "homehelp"} {
      set reason "File not found in FlowSmithy's shared help folder (<home.dir>/help) -- \"$relPath\" is a bare filename, so that's the only location tried."
    } elseif {[string match "homehelp-unavailable:*" $route]} {
      set why [string range $route [string length "homehelp-unavailable:"] end]
      set reason "\"$relPath\" is a bare filename and should have been looked up in FlowSmithy's shared help folder (<home.dir>/help), but that wasn't possible: $why. Fell back to a local guess as a last resort, which also wasn't found."
    } else {
      set reason "File not found relative to the file that referenced it -- \"$relPath\" includes a path, so it was resolved locally rather than looked up in the shared help folder."
    }
    ::wb::help::_openHelpFallback $win $sourceFile $sourceTitle \
        $targetPath $anchor $sameWindow $reason
    return
  }

  # Decide the window target.
  if {$sameWindow} {
    set targetWin ".wbHelp"
  } else {
    incr helpWinSeq
    set targetWin ".wbHelp$helpWinSeq"
  }

  # Build the backlink (same-window only) BEFORE rendering, since
  # rendering same-window destroys the window holding sourceFile/title.
  set renderArgs {}
  if {$sameWindow && $sourceFile ne ""} {
    set backUrl "help-same:$sourceFile"
    lappend renderArgs -backlink [list $sourceTitle $backUrl]
  }

  # Render the target normally, into the decided window.
  set targetTitle [file tail $targetPath]
  ::wb::help::mdRender $targetTitle $targetPath -winname $targetWin {*}$renderArgs

  # If an anchor was requested, confirm it actually exists in the
  # freshly-built map for THIS render before trying to scroll to it.
  if {$anchor ne ""} {
    if {[info exists ::wb::help::curAnchorMap($anchor)]} {
      set markName $::wb::help::curAnchorMap($anchor)
      catch { $targetWin.body.t see $markName }
    } else {
      # File loaded fine, but the anchor doesn't exist in it. Reuse the
      # window we just rendered into (targetWin) rather than opening yet
      # another new window on top of it -- that page did load
      # successfully, it just can't scroll to the requested spot.
      ::wb::help::_openHelpFallback $win $sourceFile $sourceTitle \
          $targetPath $anchor $sameWindow \
          "That page exists, but this anchor was not found on it." \
          $targetWin
    }
  }
}

# Render a graceful "not found" message through the normal help
# pipeline (same styling as real content), rather than a modal dialog.
#   winOverride - if supplied, render the fallback into this specific
#                 (already-existing) window rather than picking a fresh
#                 one via the sameWindow rule. Used when the target file
#                 loaded fine but the requested anchor wasn't found on it,
#                 so we correct the page already shown instead of leaking
#                 an extra window alongside it.
proc ::wb::help::_openHelpFallback {win sourceFile sourceTitle targetPath anchor sameWindow reason {winOverride ""}} {
  set msg "# Help Reference Not Found\n\n"
  append msg "$reason\n\n"
  append msg "**File:** \`$targetPath\`\n\n"
  if {$anchor ne ""} {
    append msg "**Anchor:** \`$anchor\`\n\n"
  }
  if {$sourceFile ne ""} {
    append msg "\[Return to $sourceTitle\](help-same:$sourceFile)\n"
  }

  if {$winOverride ne ""} {
    set w $winOverride
  } elseif {$sameWindow} {
    set w ".wbHelp"
  } else {
    incr ::wb::help::helpWinSeq
    set w ".wbHelp$::wb::help::helpWinSeq"
  }
  ::wb::help::mdRender "Help Not Found" "" -winname $w -mdtext $msg
}

proc ::wb::help::_cancelTip {} {
  if {$::wb::help::tipAfter ne ""} {
    catch { after cancel $::wb::help::tipAfter }
    set ::wb::help::tipAfter ""
  }
}

proc ::wb::help::_showTip {t tag} {
  set title ""
  catch { set title $::wb::help::linkMap($tag,title) }
  if {[string trim $title] eq ""} { return }

  ::wb::help::_hideTip

  set w .wbHelpTip
  catch {destroy $w}
  toplevel $w
  wm overrideredirect $w 1

  ttk::label $w.l -text $title
  pack $w.l -padx 6 -pady 3

  # Position near pointer
  set x [expr {[winfo pointerx $t] + 12}]
  set y [expr {[winfo pointery $t] + 18}]
  wm geometry $w "+$x+$y"

  set ::wb::help::tipWin $w
  set ::wb::help::tipAfter ""
}

proc ::wb::help::_hideTip {} {
  if {$::wb::help::tipWin ne ""} {
    catch {destroy $::wb::help::tipWin}
    set ::wb::help::tipWin ""
  }
}

proc ::wb::help::_insertEmphCore {t s baseTag} {
  # Minimal emphasis: **bold** and *italic* (no nesting guarantees).
  set rest $s
  while {$rest ne ""} {
    set pb [string first "**" $rest]
    set pi [string first "*"  $rest]

    # choose earliest marker, preferring bold when tied
    set useBold 0
    if {$pb >= 0 && ($pi < 0 || $pb <= $pi)} {
      set useBold 1
    }

    if {$useBold} {
      set end [string first "**" $rest [expr {$pb + 2}]]
      if {$end < 0} {
        $t insert end $rest $baseTag
        break
      }
      if {$pb > 0} {
        $t insert end [string range $rest 0 [expr {$pb - 1}]] $baseTag
      }
      set inner [string range $rest [expr {$pb + 2}] [expr {$end - 1}]]
      if {$inner ne ""} {
        $t insert end $inner [list $baseTag b]
      }
      set rest [string range $rest [expr {$end + 2}] end]
      continue
    }

    if {$pi >= 0} {
      # ignore if this is actually a bold opener (**)
      if {[string range $rest $pi [expr {$pi+1}]] eq "**"} {
        # bold would have been chosen if earliest; move past and continue
        $t insert end [string range $rest 0 $pi] $baseTag
        set rest [string range $rest [expr {$pi+1}] end]
        continue
      }

      set end [string first "*" $rest [expr {$pi + 1}]]
      if {$end < 0} {
        $t insert end $rest $baseTag
        break
      }
      if {$pi > 0} {
        $t insert end [string range $rest 0 [expr {$pi - 1}]] $baseTag
      }
      set inner [string range $rest [expr {$pi + 1}] [expr {$end - 1}]]
      if {$inner ne ""} {
        $t insert end $inner [list $baseTag i]
      }
      set rest [string range $rest [expr {$end + 1}] end]
      continue
    }

    # no markers
    $t insert end $rest $baseTag
    break
  }
}

# Flush buffered paragraph as a single wrapped line, with tag-based spacing.
# Joins soft-wrapped Markdown lines with spaces (GitHub-style).
proc ::wb::help::_flushPara {tVar paraVar} {
  upvar 1 $tVar t
  upvar 1 $paraVar paraLines
  if {[llength $paraLines] == 0} { return }
  set txt [string trim [join $paraLines " "]]
  if {$txt ne ""} {
    ::wb::help::_insertInline $t "$txt\n" p
  } else {
    $t insert end "\n" p
  }
  set paraLines {}
}

# Flush a buffered list item as a single wrapped line, with its marker
# (bullet glyph or "N.") prefixed. Joins soft-wrapped continuation lines
# with spaces (GitHub-style lazy continuation), matching _flushPara.
proc ::wb::help::_flushLi {tVar markerVar bufVar} {
  upvar 1 $tVar t
  upvar 1 $markerVar liMarker
  upvar 1 $bufVar liBuf
  if {[llength $liBuf] == 0} { return }
  set txt [string trim [join $liBuf " "]]
  ::wb::help::_insertInline $t "$liMarker $txt\n" li
  set liMarker ""
  set liBuf {}
}

# Parse a markdown table pipe row into a list of cell text strings.
# Handles leading/trailing pipes and trims each cell.
proc ::wb::help::_tableParseRow {line} {
  # Strip leading/trailing whitespace and outer pipes
  set line [string trim $line]
  regsub {^\|} $line "" line
  regsub {\|$} $line "" line
  set cells {}
  foreach cell [split $line "|"] {
    lappend cells [string trim $cell]
  }
  return $cells
}

# Returns 1 if the row is a separator (|---|---|) row, 0 otherwise.
proc ::wb::help::_tableIsSep {line} {
  return [regexp {^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$} $line]
}

# Render a list of raw table row strings as an embedded grid widget.
# Row 0 is the header; any separator rows are skipped.
proc ::wb::help::_insertTable {t rawRows} {
  if {[llength $rawRows] == 0} { return }

  incr ::wb::help::TABLE_SEQ
  set fname "${t}.tbl$::wb::help::TABLE_SEQ"

  # Parse all non-separator rows into a list of cell lists
  set parsed {}
  set isHeader 1
  foreach raw $rawRows {
    if {[::wb::help::_tableIsSep $raw]} {
      # separator row marks end of header — skip it
      continue
    }
    lappend parsed [list $isHeader [::wb::help::_tableParseRow $raw]]
    set isHeader 0
  }

  if {[llength $parsed] == 0} { return }

  # Determine number of columns from first row
  set ncols [llength [lindex [lindex $parsed 0] 1]]
  if {$ncols == 0} { return }

  # Build frame
  frame $fname -bd 1 -relief solid -background $::wb::help::TBL_BORDER

  set dataRow 0
  set gridRow 0
  foreach entry $parsed {
    set hdr   [lindex $entry 0]
    set cells [lindex $entry 1]

    if {$hdr} {
      set bg $::wb::help::TBL_HDR_BG
      set fg $::wb::help::TBL_HDR_FG
      set fw bold
    } else {
      set bg [expr {($dataRow % 2 == 0) ? $::wb::help::TBL_ROW_BG : $::wb::help::TBL_ALT_BG}]
      set fg black
      set fw normal
      incr dataRow
    }

    for {set c 0} {$c < $ncols} {incr c} {
      set cell [expr {$c < [llength $cells] ? [lindex $cells $c] : ""}]

      # Check if this cell is purely an inline image: ![alt](img:filename)
      set cellImg ""
      set cellText $cell
      if {[regexp {^!\[([^\]]*)\]\(img:([^\)]+)\)$} [string trim $cell] -> altTxt imgFile]} {
        # Resolve image from cache (subsampled copy)
        set cellText $altTxt
        set origImg ""
        if {$::wb::help::curImageCache ne "" && \
            [dict exists $::wb::help::curImageCache $imgFile]} {
          set origImg [dict get $::wb::help::curImageCache $imgFile]
        }
        if {$origImg ne ""} {
          set cacheKey "${origImg}@50pct"
          if {![info exists ::wb::help::imgCache($cacheKey)]} {
            set smallImg [image create photo]
            $smallImg copy $origImg -subsample 2 2
            set ::wb::help::imgCache($cacheKey) $smallImg
          }
          set cellImg $::wb::help::imgCache($cacheKey)
        }
      } else {
        # Strip inline markup for plain-text label rendering
        regsub -all {!\[([^\]]*)\]\([^\)]+\)} $cellText {\1} cellText  ;# images -> alt
        regsub -all {\*\*([^*]+)\*\*} $cellText {\1} cellText
        regsub -all {\*([^*]+)\*}     $cellText {\1} cellText
        regsub -all {\[([^\]]+)\]\([^\)]+\)} $cellText {\1} cellText
        regsub -all {`([^`]+)`}        $cellText {\1} cellText
      }

      set fnt [expr {$fw eq "bold" ? "TkDefaultFont 9 bold" : "TkDefaultFont 9"}]
      if {$cellImg ne ""} {
        label $fname.r${gridRow}c${c} \
          -image $cellImg \
          -background $bg \
          -anchor center \
          -padx 6 -pady 3
      } else {
        label $fname.r${gridRow}c${c} \
          -text $cellText \
          -background $bg \
          -foreground $fg \
          -font $fnt \
          -anchor w \
          -padx 6 -pady 3
      }
      grid $fname.r${gridRow}c${c} -row $gridRow -column $c -sticky nsew -padx 1 -pady 1
      grid columnconfigure $fname $c -weight 1
    }
    incr gridRow
  }

  # Embed the frame into the text widget
  $t insert end "\n" p
  $t window create end -window $fname -padx 4 -pady 4
  $t insert end "\n" p
}

# Insert a "< Back to label" navigation link at the top of the help window.
# Rendered in a smaller muted style so it reads as chrome, not document content.
# Followed by a thin separator line to visually separate it from the document.
# Insert back navigation line at the top of the help window.
# Always renders "← Back to label".
# If topLabel/topUrl are supplied AND differ from the back target, also renders
# a "↑ Top: label" link separated by a spacer — giving one nav row, not a
# growing stack.
proc ::wb::help::_insertBackLink {t label url {topLabel ""} {topUrl ""}} {
  ::wb::help::_insertLinkWidget $t "\u2190 Back to $label" $url "" backlnk

  # Only show Top link if it's a distinct destination from Back
  if {$topLabel ne "" && $topUrl ne "" && $topUrl ne $url} {
    $t insert end "    " backlnk
    ::wb::help::_insertLinkWidget $t "\u2191 Top: $topLabel" $topUrl "" backlnk
  }

  $t insert end "\n" backlnk
  ::wb::help::_insertHR $t
}

# Insert a horizontal rule as a 1px-high canvas embedded in the text widget.
# The canvas draws a single gray line across its full width, and is configured
# to resize with the text widget via a <Configure> binding.
proc ::wb::help::_insertHR {t} {
  incr ::wb::help::HR_SEQ
  set cname "${t}.hr$::wb::help::HR_SEQ"

  # 1px tall canvas; background matches text widget background
  canvas $cname -height 1 -bd 0 -highlightthickness 0 \
    -background [lindex [$t configure -background] 4]

  # Draw the rule line; we start it short and let the Configure binding stretch it
  $cname create line 0 0 10 0 -fill #b0b0b0 -width 1 -tags ruleline

  # Stretch the line whenever the canvas is resized
  bind $cname <Configure> [list ::wb::help::_hrResize $cname]

  # Embed with spacing tag so there's a little air above and below
  $t insert end "\n" hr
  $t window create end -window $cname -padx 4 -pady 4 -stretch 1
  $t insert end "\n" hr
}

# Resize the rule line to fill the canvas width on <Configure>.
proc ::wb::help::_hrResize {c} {
  set w [winfo width $c]
  if {$w < 2} { return }
  $c coords ruleline 0 0 $w 0
}


proc ::wb::help::_configureTags {t} {
  set fBase "TkDefaultFont"
  set fH1   "TkDefaultFont 16 bold"
  set fH2   "TkDefaultFont 14 bold"
  set fH3   "TkDefaultFont 12 bold"
  set fH4   "TkDefaultFont 11 bold"
  set fCode "TkFixedFont"
  set fBold "TkDefaultFont 10 bold"
  set fItal "TkDefaultFont 10 italic"

  $t tag configure p -font $fBase -spacing1 [lindex $::wb::help::PARA_PAD_Y 0] -spacing3 [lindex $::wb::help::PARA_PAD_Y 1]
  $t tag configure b -font $fBold
  $t tag configure i -font $fItal

  $t tag configure h1 -font $fH1 -spacing1 [lindex $::wb::help::H1_PAD_Y 0] -spacing3 [lindex $::wb::help::H1_PAD_Y 1]
  $t tag configure h2 -font $fH2 -spacing1 [lindex $::wb::help::H2_PAD_Y 0] -spacing3 [lindex $::wb::help::H2_PAD_Y 1]
  $t tag configure h3 -font $fH3 -spacing1 [lindex $::wb::help::H3_PAD_Y 0] -spacing3 [lindex $::wb::help::H3_PAD_Y 1]
  $t tag configure h4 -font $fH4 -spacing1 [lindex $::wb::help::H4_PAD_Y 0] -spacing3 [lindex $::wb::help::H4_PAD_Y 1]

  # Lists: hanging indent
  $t tag configure li -lmargin1 18 -lmargin2 36 -spacing3 2

  # Horizontal rule spacing (the canvas widget sits between two hr-tagged newlines)
  $t tag configure hr -spacing1 4 -spacing3 4

  # Back navigation link (smaller, muted — rendered as chrome above the document)
  # Back navigation link. NOTE: this line previously had duplicate
  # -font/-spacing1/-spacing3 options (looked like two configurations
  # got merged together at some point) -- Tcl's last-value-wins semantics
  # for repeated option flags meant the first occurrence of each was
  # already dead/ignored, so this cleanup doesn't change any current
  # runtime behavior, it just removes the confusing duplicate text.
  # Unrelated to the inline-code/li fix above; found nearby while in
  # this same block of tag configuration.
  $t tag configure backlnk -foreground "#555555" -font $fCode -lmargin1 18 -lmargin2 18 -spacing1 2 -spacing3 6 -background $::wb::help::CODE_BG
  $t tag configure inlinecode -font $fCode -background $::wb::help::CODE_BG
}

# ---- small utilities --------------------------------------------------------

proc ::wb::help::_centerWindow {w wid hgt} {
  # If the main app provides a centering proc, use it.
  # Your ::wb::run::centerWindow takes only (w).
  if {[llength [info commands ::wb::run::centerWindow]]} {
    if {![catch {::wb::run::centerWindow $w}]} {
      return
    }
    # If it exists but failed for any reason, fall through to local centering.
  }

  update idletasks
  set sw [winfo screenwidth  $w]
  set sh [winfo screenheight $w]
  set x [expr {($sw - $wid) / 2}]
  set y [expr {($sh - $hgt) / 2}]
  if {$x < 0} { set x 0 }
  if {$y < 0} { set y 0 }
  wm geometry $w "${wid}x${hgt}+${x}+${y}"
}

proc ::wb::help::_errWin {title msg} {
  set w .wbHelpErr
  catch {destroy $w}
  toplevel $w
  wm title $w $title
  wm geometry $w 640x240
  ::wb::help::_centerWindow $w 640 240

  ttk::frame $w.f
  pack $w.f -fill both -expand 1 -padx 10 -pady 10

  text $w.f.t -wrap word -height 8
  $w.f.t insert end $msg
  $w.f.t configure -state disabled
  pack $w.f.t -side top -fill both -expand 1

  ttk::button $w.f.ok -text "OK" -command [list destroy $w]
  pack $w.f.ok -side bottom -pady {8 0}
}


# ---- snapshot helpers -------------------------------------------------------

proc ::wb::help::_tsNow {} {
  return [clock format [clock seconds] -format "%Y%m%d-%H%M%S"]
}

# Minimal block-level parse dump. (Enough to disambiguate parser vs layout issues.)
proc ::wb::help::makeParseDump {mdText} {
  set out ""
  set inCode 0
  foreach line [split $mdText "\n"] {
    set raw $line
    set line [string trimright $line]

    # fenced code blocks (```); treat as opaque
    if {[regexp {^```} $line]} {
      set inCode [expr {!$inCode}]
      append out "CODE_FENCE\n"
      continue
    }
    if {$inCode} {
      append out "CODE: $raw\n"
      continue
    }

    # heading: leading hashes define level; optional trailing hashes are ignored
    if {[regexp {^(#{1,6})[ \t]*(.*)$} $line -> hashes tail]} {
      set level [string length $hashes]
      set text  [string trim $tail]
      # strip optional closing hashes ONLY if preceded by whitespace
      regsub {([ \t]+)#+[ \t]*$} $text "" text
      set text [string trimright $text]
      if {$text eq ""} { set text "<empty>" }
      append out "HEADING level=$level text=\"$text\"\n"
      continue
    }

    if {[string trim $line] eq ""} {
      append out "BLANK\n"
      continue
    }

    # horizontal rule
    if {[regexp {^\s*([-*_])\1{2,}\s*$} $line]} {
      append out "HR\n"
      continue
    }

    append out "PARA text=\"$line\"\n"
  }
  return $out
}

# Try to snapshot a toplevel into a PNG using a photo image.
# Note: This captures the Tk client area (not OS window decorations).
proc ::wb::help::snapshotWindowToPng {win pngPath} {
  # Cross-platform widget snapshot is not supported reliably in core Tk.
  # On Windows (Steve's environment), use PowerShell + .NET to capture the window's client area.
  update idletasks

  set x [winfo rootx $win]
  set y [winfo rooty $win]
  set w [winfo width  $win]
  set h [winfo height $win]
  if {$w <= 1 || $h <= 1} {
    update
    set w [winfo width  $win]
    set h [winfo height $win]
  }

  set ps [auto_execok powershell]
  if {$ps eq ""} {
    return -code error "snapshot: powershell not found"
  }

  # Ensure output directory exists
  catch { file mkdir [file dirname $pngPath] }

  # PowerShell script: capture rectangle and save PNG
  # Note: we avoid single quotes in paths by using -LiteralPath and double-quoted strings.
  set pngPathN [file nativename $pngPath]

  set cmd [format {
    Add-Type -AssemblyName System.Drawing;
    $bmp = New-Object System.Drawing.Bitmap(%d,%d);
    $g = [System.Drawing.Graphics]::FromImage($bmp);
    $g.CopyFromScreen(%d,%d,0,0,$bmp.Size);
    $bmp.Save("%s",[System.Drawing.Imaging.ImageFormat]::Png);
    $g.Dispose(); $bmp.Dispose();
  } $w $h $x $y [string map {"\"" "\\\""} $pngPathN]]

  # Execute
  exec {*}$ps -NoProfile -ExecutionPolicy Bypass -Command $cmd
}

# Save snapshot zip for a help window instance.
# win: toplevel help window
# mdPath: source markdown file path
proc ::wb::help::saveSnapshot {win mdPath} {
  variable VERSION

  set ts [_tsNow]
  set baseName "fs-help-snapshot-v$VERSION-$ts"

  # Output location (for shipping to ChatGPT): fixed temp dir
  set zipDir "d:/1"
  file mkdir $zipDir

  # Staging directory (deleted after zip is created)
  set workDir [file join $zipDir "${baseName}-work"]
  catch { file delete -force $workDir }
  file mkdir $workDir

  # 1) snapshot PNG
  set pngPath [file join $workDir "render.png"]
  snapshotWindowToPng $win $pngPath

  # 2) parse dump
  set fh [open $mdPath r]
  set mdText [read $fh]
  close $fh
  set dump [makeParseDump $mdText]
  set fh [open [file join $workDir "parse-dump.txt"] w]
  puts -nonewline $fh $dump
  close $fh

  # 3) save input file copy
  file copy -force $mdPath [file join $workDir "input.md"]

  # 4) save prompt textbox
  set promptPath [file join $workDir "prompt.txt"]
  set p ""
  catch {
    set p [$win.prompt.t get 1.0 end-1c]
  }
  set fh [open $promptPath w]
  puts -nonewline $fh $p
  close $fh

  # Zip it up (Windows / PowerShell)
  set zipPath [file join $zipDir "${baseName}.zip"]

  set ps [auto_execok powershell]
  if {$ps eq ""} {
    return -code error "Cannot create zip: powershell not found (needed for Compress-Archive)."
  }

  # Remove any prior zip with same name
  catch { file delete -force $zipPath }

  # Compress-Archive wants a wildcard path
  set globPath [file join $workDir *]
  exec {*}$ps -NoProfile -Command "Compress-Archive -Path '$globPath' -DestinationPath '$zipPath' -Force"

  # Remove staging dir (user requested no work dir)
  catch { file delete -force $workDir }

  # Signal readiness
  ::wb::run::logMsg "zip $zipPath created"

  # Optional: report path in status label if present
  catch { $win.top.status configure -text "Saved: $zipPath" }

  return $zipPath
}



# Public: handle markdown help links.
# FALLBACK STUB — used only when no -linkhandler was registered via mdRender.
# For recipe:// links in the configurator, fs-cfg.tcl injects its own handler.
# Override/extend as desired for other contexts.
proc ::wb::help::renderHelpLink {link} {
  # Stub: override with your routing logic
  hilite -cyan "renderHelpLink $link"
  return
}
