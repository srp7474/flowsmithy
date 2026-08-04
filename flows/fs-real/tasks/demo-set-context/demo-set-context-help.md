### Purpose ####

This step is used to demonstrate how to set global context for all tasks in the flow.


### Description ####
This is used to set the global context values stored in FS [globs table](help:fs-run-help.md#globs). The values set are
readable by subsequent tasks.

In practice in makes most sense to have it at the beginning of the flow's task set.

### Operation ###

The (globs table)[help:fs-run-help.md#Globs]) is persisted for each flow between FS runs.
Options are persisted by the FS procedures whenever a Run Task is initiated.

The **month** option is inserted into the [globs table](help:fs-run-help.md#globs)

The **CycleNo** is incremented in the [globs table](help:fs-run-help.md#globs) or set to 1
if it does not exist.





