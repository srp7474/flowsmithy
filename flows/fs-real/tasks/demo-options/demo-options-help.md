### Purpose ####

This step is used demonstrate the *options* capabilities of the FS workflow system.

### Operation ####
The *options* are passed to a partner Java program (`TestArgsFS`) that lists the options passed in
and modifies its behavior based on the parameters passed in.

The *options* can cause the Java program to process in a certain way such as *Failure* 
or *Exception* (*TRAP*) so that these execution paths can be verified.

See [options fields](help:fs-cfg-task-options-help.md#option-fields) for descriptions of the various fields used to construct each entry.

The *option* values are persisted from one run to another, even with intermediate WorkFlow restarts.

### Option Fields ####

Each control below is listed in the same order it appears on the Showcase Options screen. As
you go through them, check the **Hint** shown next to each control in the running app -- it's
a short reminder of exactly what that control is illustrating, matching the description here.

- **Gen** An *input* field that must be numeric, enforced by a `regexPat` validation rule.
  A non-numeric value shows a "Not Integer" error under the field and disables `Run Task`
  until it's fixed.

  The value is used by `TestArgsFS` to control the number of log lines generated, so the
  scrolling mechanism of the `Show Log` action can be verified.

- **GenStr** An optional *input* string field passed to `TestArgsFS`. If provided, it becomes
  the text used for the generated log lines.

- **Bool1** A basic *checkbox* control. `TestArgsFS` prints its value on the run log.

- **Trap** A *select* control. The list passed in is parsed into value/label pairs; a value
  that starts with `*` is the initial default. Whatever is chosen is persisted between runs
  and passed to `TestArgsFS`, which uses it to control how it operates -- including
  deliberately triggering a *Failure* or *Exception* (*TRAP*) so those execution paths can be
  verified.

- **boolFail** Used to trigger unknown parm as it passes *-boolFail* which is not known to `TestArgsFS`.

- **Combo** A second *select* control, working the same way as **Trap** but optional rather
  than required, and demonstrating a plain value list with no `*`-marked default -- notice
  that when you first open this task, **Combo** starts blank rather than pre-selected.

- **Input** A *file input* control. The chosen path is printed on the run log -- it isn't
  read or validated further, this is purely showing the file-picker control itself.

- **BecuDir** A *directory input* control, working the same way as **Input** but for
  choosing a folder rather than a file. The chosen path is printed on the run log.

- **runtime** A **read-only** field (`readonly: true`) whose value is computed entirely by a
  `custVal` hook (`set-run-time`) rather than typed by the user -- illustrating a field meant
  purely for the task to report something back to you, not to collect input.

- **head** Another **read-only** field driven by its own `custVal` hook (`build-head`),
  demonstrating a more involved computed value than **runtime** -- same mechanism, showing
  it isn't limited to something as simple as a timestamp.

- **custval** A plain, *editable* text field -- unlike **runtime**/**head**, this one is
  meant to be typed into. Its `custVal` hook (`str2-custval`) runs custom validation on
  whatever you enter instead of a built-in `regexPat` rule: try typing something that
  doesn't start with `A` or `a` and watch `Run Task` disable with a custom error message,
  the same way **Gen**'s regex validation does but driven entirely by hand-written hook code.
