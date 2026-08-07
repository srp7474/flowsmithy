# FlowSmithy

**[flowsmithy.com](https://flowsmithy.com)** · [Demo video](https://youtu.be/FjhwmO6vAro)

Lightweight, cross-platform task orchestration, written in pure Tcl/Tk.
No installation beyond the Tcl/Tk runtime. Runs wherever Tcl/Tk runs —
developed and tested on Windows so far, with Linux and Mac expected to
work. Public domain.

## Why

Most real-world orchestration needs don't require Airflow, Prefect, or
anything else built for a cluster. They need a small, auditable,
human-in-the-loop way to run a multi-step process reliably — a build,
a deployment, a monthly maintenance job, a data migration — without
depending on whoever happens to remember the steps this time.

FlowSmithy is built around one idea: **memory in the process.** Every
task carries its own instructions. The runner walks you through each
step. Nothing about running a flow correctly depends on the operator's
memory.

It also works well as a structured execution harness for AI agents —
inspectable, restartable, auditable steps rather than an opaque script.

## What's in it

- **Configurator** — a Tk UI for authoring flow configuration files
- **Runner** — executes a defined flow, task by task, with built-in help
- **Shell** — a small interactive front end for running/configuring flows
- JSON-driven flow configuration, no proprietary format
- A registry of reusable tasks shared across flows

## Cross-platform

FlowSmithy is pure Tcl/Tk — it runs anywhere Tcl/Tk runs. Developed and
tested primarily on Windows so far; Linux and Mac are expected to work
(`apt install tcl tk` / `brew install tcl-tk`) but haven't had the same
depth of testing yet. Issues and reports from either platform are
genuinely useful.

## Install

**Windows:** grab the latest installer from the
[Releases](../../releases/latest) page and run it. It bundles its own private
Tcl/Tk runtime — nothing else needs to be installed first.

**From source (any platform):** install Tcl/Tk for your platform, then
run `src/fs-shell.tcl` with `wish`.

## Quick start

Once FlowSmithy is running, at the shell prompt:

```
run fs-demo
```
A short guided flow — the fastest way to see how a run actually
behaves.

```
run fs-real
```
A more complete, realistic example, including a Java integration step
(requires a Java runtime on your machine for that part).

```
cfg fs-real
```
Opens the configurator against the same flow, so you can see how a
flow's steps and options are put together.

Type `help` at any time for the full list of shell commands.

## Repo layout

```
src/     -- the Tcl/Tk engine (configurator, runner, shell)
help/    -- markdown help content used by the built-in help system
icons/   -- application icons
flows/   -- example flows (fs-demo, fs-real)
```

## Status

Early release. Feedback, issues, and pull requests are welcome —
especially anything found on Mac or Linux.

## License

Public domain — see [LICENSE](LICENSE).
