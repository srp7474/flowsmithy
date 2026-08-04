### Purpose ####

This step is used demonstrate the use of a manual step in the FS workflow system.

### Description ####

Manual steps serve to be landmarks in a work flow where manual steps (such as downloading
a file or getting a signature) can be indicated. Apart from checking that the step(s) has been taken
and creating documentation for the step no other action is possible.

### Operation ####

The checkboxes are used to describe manual steps that need to be taken. All must be check for the`getManualSteps([Task]$task)` function is used to return an array of strings that
task to become *Runnable*

Running the task simply marks it as completed with notations made in the log and brief files.

### Note ###
This example does not use a `DependsOn demo-depends` and so even if `demo-depends` runs and FAILs this
manual step can still be updated.  To prevent this the `DependsOn demo-depends` setting should be used.


