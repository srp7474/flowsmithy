## FS Workflow Demonstration and Examples ## 


### Purpose: ###
This set of tasks is used to demonstrate the capabilities of the FlowSmithy Workflow subsystem.

It contains contrived examples of the various capabilities of the system.

The source code provided with each can also be used to build other flow scripts as they contain many examples of
the code needed to orchestrate the various programs. The configurator is able to find and search for these
examples.



### Included Examples ###
                                                         
1. **Showcase Contexter** Used to pass global values to subsequent stops. The
values selected show up in the **Show Options** description.

2. **Showcase Options** Used to illustrate the various options that can be used. They are passed to the Java
program that reports on their values.

3. **Showcase Depends** Used to illustrate how a step can be made dependent on a previous steps good completion.

4. **Showcase WhenFail** Used to illustrate how to include a remediation step.

5. **Showcase Manual** Used to show how a manual step is coded. Subsequent steps can be made dependent on the manual step being completed.
It relies on the manual step being performed offline and indication made here that the step(s) have been performed.

6. **Showcase Excel Utility** This demonstrates the creation of an Excel file. It uses Java classes included with the demonstration system.



