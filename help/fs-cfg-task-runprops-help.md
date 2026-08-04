# Runprops Configuration

**Cfg Mode: runprop**

Runprops (runtime properties) are required for any task of type `java`. They
tell the Runner which Java class to invoke and how to set up the classpath.
An optional `manageApp` property handles starting and stopping an external
application (such as Excel) around the task execution.

Non-Java tasks (`tcl-int`, `tcl-ext`, `manual`) only use the manageApp property.

---

## Runprops Fields

### javaMain *(required for java tasks)*

The fully qualified Java class name containing the `main` method to invoke.

**Examples:**
```
org.gaelic.psec.RecycleServer
org.citc.batch.fin.CitcFetchPeople
org.citc.batch.fin.CitcHandleEtrans2025
org.citc.batch.fin.CitcFormatTransBMO
org.citc.batch.fin.CitcDonReconciler2025
org.srp.psec.TestArgsPsec
```

### cpTag *(required for java tasks)*

A short identifier that selects the classpath configuration to use when
launching the JVM. The mapping from tag to actual classpath entries is
defined outside the cfg file (in the flow setup or environment).

**Examples:** `basic`, `gael-util`, `srp-util`

All the `cit-fin` production tasks use `cpTag: "basic"`. The server recycle
task uses `cpTag: "gael-util"` because it belongs to a different library set.

### manageApp

Path to a TCL script that starts an external application before the task
runs and stops it afterward. The path is relative to the task folder.

Used when the Java program needs a desktop application to be running — for
example, Excel must be open before a report-generation task writes to it, and
closed (or restarted) after.

**Example** — from `cit-fin` — `gen-don-anal-dec2021`:
```json
"runprops": {
    "javaMain" : "org.citc.batch.fin.CitcFinGen2022",
    "cpTag"    : "basic",
    "manageApp": "start-excel.tcl"
}
```

The `start-excel.tcl` script lives in the task folder, under whichever
`flows.dir` entry is currently active:
```
<flows.dir>/cit-fin/tasks/gen-don-anal-dec2021/start-excel.tcl
```

---

## Complete Examples

**Minimal Java invocation** — `recycle-server` in `cit-fin`:
```json
"runprops": {
    "javaMain": "org.gaelic.psec.RecycleServer",
    "cpTag"   : "gael-util"
}
```

**Standard batch Java task** — all the `cit-fin` processing tasks follow
this pattern:
```json
"runprops": {
    "javaMain": "org.citc.batch.fin.CitcFormatTransBMO",
    "cpTag"   : "basic"
}
```

**Java task with managed external app** — `gen-don-anal-dec2021`:
```json
"runprops": {
    "javaMain" : "org.citc.batch.fin.CitcFinGen2022",
    "cpTag"    : "basic",
    "manageApp": "start-excel.tcl"
}
```

**Test task** — `test-java-exec` in `wb-devp`:
```json
"runprops": {
    "javaMain": "org.srp.psec.TestArgsPsec",
    "cpTag"   : "srp-util"
}
```

---

## Adding Runprops in the Configurator

1. Select the task.
2. Set Cfg Mode to **runprop**.
3. Click **Add Runprop...** and supply `javaMain` and `cpTag` at minimum if it is a Java type task.
4. Add `manageApp` if the task needs to drive an external application.
5. Click **Apply**, then **Save**.

Edit Runprop reuses the same dialog: the key is locked once set (it acts as
the "type" of the entry), and the examples panel is filtered to only that
key's own patterns.

---
