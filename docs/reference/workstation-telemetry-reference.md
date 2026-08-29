# Workstation telemetry reference

What this repo defines, and where to look for it. Endpoints, intervals, and
credentials live in `dot_config/alloy/config.alloy` and the units beside it,
which are the only copies. To operate it, see
[../how-to/viewing-workstation-telemetry.md](../how-to/viewing-workstation-telemetry.md).

## Paths

| Path | Holds |
| ---- | ----- |
| `/var/log/sysstat` | sar's binary day files, written by root |
| `~/.local/state/alloy` | Alloy's write-ahead log |
| `~/.local/state/node-textfile` | the cgroup pids metric, rewritten each minute |
| `~/.local/state/zellij-diag` | diagnose bundles, shipped as logs |

## Metrics this repo emits

node_exporter supplies and documents everything else on the metrics side.
These two don't exist there, because no packaged collector reads cgroup pids
accounting on cgroup v1:

| Metric | Type | Description |
| ------ | ---- | ----------- |
| `cgroup_pids_current` | gauge | Processes and threads in the slice. |
| `cgroup_pids_max` | gauge | The point where forks start failing with `EAGAIN`. |

Both carry a `slice` label.

## Process groups

`prometheus.exporter.process` reports `namedprocess_namegroup_num_procs`,
`_num_threads` and `_states{state=…}` per group. The group names are this
repo's choice. A process joins the first matcher it matches:

| Group | Covers |
| ----- | ------ |
| `zellij-pipe` | `zellij pipe`, one per Claude tool call |
| `zellaude-hook` | the hook script that blocks on that pipe |
| `zjstatus-command` | the `zellij-*-status` scripts zjstatus runs on a timer |
| `zellij-server` | the server process |
| `claude` | Claude Code |
| *executable basename* | everything else, one group per binary |

A group counts processes running that binary, not the work that spawned them.
The catch-all leaves nothing for `track_children` to attribute upward.

## Scrape intervals

The `job` label comes from the exporter, not the scrape, so it's what selects
these series remotely:

| Scrape | `job` | Interval | Why |
| ------ | ----- | -------- | --- |
| `unix` | `integrations/unix` | 15s | A pids pool can drain between two 60s samples. |
| `process` | `integrations/process` | 30s | Walks `/proc` per process, so it costs most under load. |

Both sample a population at an instant. A process that lives and dies inside one
interval moves `node_forks_total` and appears in no group.

## Local equivalents

sar and node_exporter measure the same machine under different names. During an
incident the remote copy may be minutes stale, or missing entirely if the user
slice was out of pids, so the local column is the one that answers:

| Remote metric | Local command |
| ------------- | ------------- |
| `node_forks_total` | `sar -w` |
| `node_procs_running`, `node_procs_blocked` | `sar -q` |
| `node_processes_state` | `sar -q` (`plist-sz`) |
| `cgroup_pids_current` | `cat /sys/fs/cgroup/pids/user.slice/user-$(id -u).slice/pids.current` |

## Log jobs

Alloy labels each source with a `job`, which is how you select them:

| Job | Source |
| --- | ------ |
| `systemd-journal` | the user journal |
| `zellij` | the Zellij server log under `/tmp/zellij-<uid>/zellij-log/` |
| `zellij-diag` | `*.txt` from the diagnose bundle directory |
