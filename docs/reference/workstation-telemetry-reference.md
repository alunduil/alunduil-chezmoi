# Workstation telemetry reference

Destinations, paths, and the metric names worth querying. To operate it, see
[../how-to/viewing-workstation-telemetry.md](../how-to/viewing-workstation-telemetry.md);
for the rationale, see
[../explanation/workstation-telemetry.md](../explanation/workstation-telemetry.md).

## Services

| Service | Runs as | Writes to |
| ------- | ------- | --------- |
| `sadc` (`sysstat-collect.timer`) | root, `system.slice` | `/var/log/sysstat` |
| `alloy.service` | user | Grafana Cloud; WAL under `~/.local/state/alloy` |
| `cgroup-pids-textfile.timer` | user | `~/.local/state/node-textfile` |

Alloy's own HTTP interface listens on `127.0.0.1:12345`. Nothing else binds a
port; the local stores are gone.

## Destinations

| Signal | Endpoint | User |
| ------ | -------- | ---- |
| Metrics | `https://prometheus-prod-55-prod-gb-south-1.grafana.net/api/prom/push` | `2471599` |
| Logs | `https://logs-prod-035.grafana.net/loki/api/v1/push` | `1231476` |

## Collection intervals

| What | Interval | Retention |
| ---- | -------- | --------- |
| `sadc` | 1 minute | 28 days (`HISTORY` in `/etc/sysstat/sysstat`) |
| Alloy scrape | 1 minute | Grafana Cloud plan retention |
| cgroup pids textfile | 1 minute | overwritten each run |

## Metrics

From node_exporter's `processes` collector, which is off by default upstream:

| Metric | Type | Description |
| ------ | ---- | ----------- |
| `node_forks_total` | counter | Forks since boot; the fork-storm signal. |
| `node_procs_running` | gauge | Processes in runnable state. |
| `node_procs_blocked` | gauge | Processes blocked on I/O. |
| `node_processes_state` | gauge | Processes by state; `state="Z"` catches zombies. |
| `node_processes_threads` | gauge | Threads across all processes. |
| `node_filefd_allocated` | gauge | Allocated file descriptors. |
| `node_filefd_maximum` | gauge | File descriptor ceiling. |

From the textfile source, carrying a `slice` label:

| Metric | Type | Description |
| ------ | ---- | ----------- |
| `cgroup_pids_current` | gauge | Processes and threads in the slice. |
| `cgroup_pids_max` | gauge | Ceiling above which forks fail with `EAGAIN`. |

## Logs

| Job | Source |
| --- | ------ |
| `systemd-journal` | the user journal |
| `zellij` | the Zellij server log under `/tmp/zellij-<uid>/zellij-log/` |
| `zellij-diag` | `*.txt` from the diagnose bundle directory |

## sar equivalents

`sar` reads today's file by default; `sar -f /var/log/sysstat/saDD` replays a
given day.

| Command | Shows |
| ------- | ----- |
| `sar -w` | Task creation rate, the local view of `node_forks_total`. |
| `sar -q` | Run queue, load, and `plist-sz`, the total process count. |
| `sar -r` | Memory use. |
| `sar -u` | CPU use. |
