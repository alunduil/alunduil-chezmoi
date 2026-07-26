# RTK

A `PreToolUse` hook rewrites Bash commands through `rtk`, a filtering
proxy that trims command output. Transparent — write ordinary commands.

`rtk proxy <cmd>` runs one unfiltered, when filtering is itself the
suspect.
