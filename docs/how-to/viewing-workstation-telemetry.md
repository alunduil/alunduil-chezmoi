# Viewing workstation telemetry

`chezmoi apply` enables the collectors and keeps them running, so on a fresh
host there's nothing to start. For what the layers are and why there are two,
see
[../explanation/workstation-telemetry.md](../explanation/workstation-telemetry.md);
for endpoints, paths, and metric names, see
[../reference/workstation-telemetry-reference.md](../reference/workstation-telemetry-reference.md).

## Read the local record

`sar` answers most questions without leaving the box, and it's the only source
that keeps sampling through a pids exhaustion.

```bash
sar -w                        # task creation rate, today
sar -q                        # run queue and total process count
sar -f /var/log/sysstat/sa27  # replay the 27th
```

Check collection is actually on before trusting a gap:

```bash
systemctl is-active sysstat-collect.timer
ls -l /var/log/sysstat/
```

## Read the remote record

Log in to Grafana Cloud and query the metrics in the reference. The fork-storm
shape is a rising `node_forks_total` rate against a climbing
`cgroup_pids_current`:

```promql
rate(node_forks_total[5m])
cgroup_pids_current / cgroup_pids_max
```

Logs land under the `systemd-journal`, `zellij`, and `zellij-diag` jobs.

## Capture a live wedge

Run the diagnostic *before* killing anything, since killing the server destroys
the evidence:

```bash
script/diagnose-zellij-freeze
```

It writes a self-contained bundle to `/tmp/zellij-freeze-<timestamp>/` and a
matching `.tar.gz`. Alloy ships the `*.txt` files from the bundle directory, so
the snapshot survives a container reset.

For fork ancestry during a reproduction:

```bash
sudo forkstat -e exec,fork
```

## Record while logged out

User services stop with your session, so unattended capture needs lingering:

```bash
loginctl enable-linger
```

`sadc` is unaffected either way; it runs as root in `system.slice`.
