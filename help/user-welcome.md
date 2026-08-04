# Welcome to FlowSmithy

FlowSmithy runs multi-step workflows so you don't have to remember how —
each task carries its own instructions, and the runner walks you through
it. Once a flow is set up, running it correctly stops depending on
whoever happens to remember the steps.

## The basics

- Commands are typed at the `>` prompt in this shell window.
- `help` — lists starter commands any time you need a reminder.
- `run <flow>` — executes a flow.
- `cfg <flow>` — opens a flow in the configurator for editing.
- Every task has its own help available from within the runner —
  you're never expected to remember what a step does from memory alone.

## Try it now

**`run fs-demo`**
A short guided flow — the same one shown in the intro video. The
fastest way to see how a run actually behaves.

**`run fs-real`**
A more complete, realistic example, including a Java integration step
(requires a Java runtime on this machine for that part).

**`cfg fs-real`**
Opens the *configurator* against the same flow, so you can see how a
flow's steps and options are put together — useful once you're ready to
build your own.

## Where things live

- Flows shipped with this install: `flows\fs-demo`, `flows\fs-real`
- Your personal settings: `flowsmithy.cfg`, in your user home folder
  (not the install folder — this keeps your settings separate from the
  program files, and safe across reinstalls/upgrades)
- Task/help files for the engine itself: `help\`

## Editing flow files

`flowsmithy.cfg` has an `editor.*` section controlling which editor
opens when you edit a flow's files from within FlowSmithy. It defaults
to Notepad; edit `editor.command` in your `flowsmithy.cfg` if you'd
rather use Sublime Text or another editor of your choice.

## Turning this screen off

Use the button below once you're comfortable getting started — it
updates your `flowsmithy.cfg` so this screen won't show again on
startup. You can always re-enable it later by setting `show.welcome = 1`
back in that file.
