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
repo's choice; a process joins the first matcher it matches:

| Group | Matches |
| ----- | ------- |
| `zellij-pipe` | `zellij pipe`, one per Claude tool call |
| `zellaude-hook` | the hook script that blocks on the pipe above |
| `zjstatus-command` | the `zellij-*-status` scripts zjstatus runs on a timer |
| `zellij-server` | the server itself |
| `claude` | Claude Code |
| *executable basename* | everything else, one group per binary |

The catch-all matches every remaining process, so nothing is left for
`track_children` to attribute upward: a group counts processes running that
binary, not the work that spawned them. A matcher with no `comm`, `exe`, or
`cmdline` rule is rejected rather than treated as always-match, which is why
the catch-all carries `cmdline = [".+"]`.

## Scrape intervals

| Scrape | Interval | Why |
| ------ | -------- | --- |
| `host` (node_exporter) | 15s | A pool can drain between two 60s samples. |
| `processes` | 30s | Walks `/proc` per process, so it costs most under load. |

Both are sampled populations. A process that lives and dies inside one
interval is counted by `node_forks_total` and named by nothing.

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
