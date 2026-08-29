# Viewing workstation telemetry

`chezmoi apply` enables the collectors, so on a fresh host there's nothing to
start. For metric and path names, see
[../reference/workstation-telemetry-reference.md](../reference/workstation-telemetry-reference.md).

## Capture a live wedge

Run this *before* killing anything. Killing the server destroys the evidence:

```bash
script/diagnose-zellij-freeze
```

It writes a bundle to `/tmp/zellij-freeze-<timestamp>/` and a matching
`.tar.gz`. Alloy ships the `*.txt` files from that directory, so the snapshot
survives a container reset. For fork ancestry during a reproduction, add
`sudo forkstat -e exec,fork`.

## Read the local record

```bash
sar -w                        # task creation rate, today
sar -q                        # run queue and process count
sar -f /var/log/sysstat/sa27  # replay the 27th
```

A gap in sar's output means one of two different things, so check which before
reading anything into it:

```bash
systemctl is-active sysstat-collect.timer
```

## Read the remote record

In Grafana Cloud, the pids pool is the series to watch. A drained pool stops
the machine forking:

```promql
cgroup_pids_current / cgroup_pids_max
```

## Find out what drained the pool

The pool series says a burst happened; these say what it was made of. Rank the
groups over the incident window:

```promql
topk(10, namedprocess_namegroup_num_threads)
```

Then separate a group that grew from one that merely churned. A group climbing
here is holding processes open:

```promql
topk(10, deriv(namedprocess_namegroup_num_procs[5m]))
```

A burst that never shows up in either, but does move `node_forks_total`, was
short-lived enough to live and die between two 30s samples. Reach for
`sudo forkstat -e exec,fork` during a reproduction to see those.

Blocked work concentrates in one state, which separates a fork storm from a
pile-up of processes waiting on something:

```promql
sum by (groupname) (namedprocess_namegroup_states{state="Running"})
```

## Record while logged out

User services stop with your session, so unattended capture needs lingering:

```bash
loginctl enable-linger
```

Lingering doesn't affect `sadc`. It runs as root in `system.slice`.
