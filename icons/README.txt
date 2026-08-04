FlowSmithy step icons, 48x48 PNG, transparent background.

Fresh/result states:
- state_good_fresh.png
- state_fail_fresh.png
- state_trap_fresh.png
- state_running.png
- state_halted.png

Stale readiness-only bases:
- state_ready_stale.png
- state_blocked_stale.png

Stale readiness + previous result overlays:
- state_ready_stale_prev_good.png
- state_ready_stale_prev_fail.png
- state_ready_stale_prev_trap.png
- state_blocked_stale_prev_good.png
- state_blocked_stale_prev_fail.png
- state_blocked_stale_prev_trap.png

Suggested mapping:
- FRESH + GOOD    -> state_good_fresh
- FRESH + FAIL    -> state_fail_fresh
- FRESH + TRAP    -> state_trap_fresh
- RUNNING         -> state_running
- HALTED          -> state_halted
- STALE + READY   -> state_ready_stale_prev_*
- STALE + BLOCKED -> state_blocked_stale_prev_*

Note:
You said Step n text should be dimmed for stale state, not the icon or task title.
That should be handled in Tcl UI styling, not in these PNGs.
