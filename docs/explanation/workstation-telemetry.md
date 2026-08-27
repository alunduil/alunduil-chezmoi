# Workstation telemetry

Why the workstation records the same machine twice. To operate it, see
[../how-to/viewing-workstation-telemetry.md](../how-to/viewing-workstation-telemetry.md);
for paths and metric names, see
[../reference/workstation-telemetry-reference.md](../reference/workstation-telemetry-reference.md).

## Why sar exists when everything already ships remotely

Every user process shares one cgroup, `user-1000.slice`, with a fixed pids
ceiling. When that pool drains, every fork in the slice fails with `EAGAIN`,
including the fork a collector needs to record the fact. Any recorder inside
the slice goes blind at the one moment worth recording.

`sadc` runs as root in `system.slice`, so it keeps sampling to local disk
straight through that exhaustion. Alloy, running as the user, doesn't. That's
the whole reason two recorders exist, and it's why dropping sysstat as
redundant would remove the only one that survives the incident.

The split runs the other way too: local files die with the container, and
Crostini can be reset wholesale. Alloy is the copy that leaves the box.

## Why nothing is stored locally

Nothing is stored on the box beyond sar's own files. A local Prometheus, Loki
or Tempo would duplicate what Grafana Cloud already holds, cost real capacity
on a constrained machine, and run in `user-1000.slice`, so it would go down
with the same event as the collectors. Redundancy that shares a failure mode
isn't redundancy.

The rule: drop any measurement system that duplicates another, unless it
captures something lost precisely because the remote copy is unreachable. sar
passes. A local Prometheus doesn't.
