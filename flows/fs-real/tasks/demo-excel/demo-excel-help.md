
### Purpose ###
To demonstrate the capabilities of the built-in support for reading and writing Excel files.

It also serves to demonstrate the abilities of FS to start and stop partner programs, in this case the Excel program.

Note that this task has no dependencies and therefore may be run no matter what the status of the previous tasks.

### Description ###
For the most part, this task runs the DemoExcel program in one of 6 modes.  The 6th mode runs the standalone program HelloExcel. The modes are
shown in the next section.




### Demonstrations ###
The following demonstrations can be performed. Each demonstration is detailed in subsequent sections

1. **run basic** - show the foundational capabilities of the WriteExcel. 

1. **run reader** - show how to use the Reader routines as a template reader. Excel will not be started.

1. **run cloner** - show how to use to clone existing sheets.

1. **run chart** - show how to write with a chart with WriteExcel.

1. **run regress** - Run the Regression test used to verify the proper functioning of the WriteExcel methods.

1. **run hello** - The Standalone program (shown in the Javadocs for WriteExcel.java)

### run basic ###

This option causes DemoExcel to run the most basic routines to demonstrate various capabilities.

The *negfmt* option is used to modify how the output routines represent negative numbers

### run reader ###
This option causes DemoExcel to exercise the ReadExcelFile routines and create an output using the input as a template with calculated values.

### run cloner ###
This option causes DemoExcel to exercise the sheet clone methods ow WriteExcel.

Note that any charts within the sheets will not be cloned and may cause unpredictable results.

### run chart ###
Charts are complicated beasts and best left to Excel itself to create them.  Furthermore, how they are stored in a Workbook is also complicated.

Therefore, to avoid implementing this complicated logic, WriteExcel allows an existing workbook to be loaded and written out as a different filename.
The existing Workbook can contain one or more charts.

Inbetween loading the input file and writing the output file, sheets can be added, deleted or modified (including the data columns
referenced by the charts). Thus a chart can formatted with sample data and updated to reflect current data.

The *negfmt* option is used to modify how the output routines represent negative numbers

### run regress ###
This option causes DemoExcel to run in regression mode where all options (except Charts) are exercised and then the ReadExcelFile class is used to read back
the resulting output file and written in a specific serialized format to a log file. This log file can be compared to the gold copy of the log file that
contains the expected results.

The *negfmt* option is used to modify how the output routines represent negative numbers

### run hello ###
This runs the basic HelloExcel program used as the Javadoc sample.


