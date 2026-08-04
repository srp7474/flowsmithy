### Purpose ####

This step is used demonstrate the **whenFail** feature of the FS workflow system in which the task
is only visible if one or more of the *whenFail* tasks failed to run. 

### Operation ####

The previous step(s) specified in the config file with the whenFail parameter
must have failed for this task to be visible.

### Usage ####

Its primary usage is for remediation steps (such as getting updated data) that will allow
the failing step to be successfully rerun (hopefully). This one does nothing.  The flow **fs-demo**
step `remedial-action` actually has code that updates status fields illustrating one way of remediating.

Remediation can also be something completely offline that when performed the whenFail target step
is rerun and this stap automatically disappears.



