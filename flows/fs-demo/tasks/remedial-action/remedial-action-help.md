[comment]: # (this produces the RTF for the help file)


### Purpose ####

This step is used demonstrate the **whenFail** feature of the PSEC workflow system in which the task
is only visible if one or more of the *whenFail* tasks failed to run. 

### Operation ####

The previous step(s) specified in the config file with the whenFail parameter
must have failed for this task to be visible.

### Usage ####

Its primary usage is for remediation steps (such as getting updated data) that will allow
the failing step to be successfully rerun (hopefully).


