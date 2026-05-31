# Running the observability stack

The Zellij-freeze observability stack comes up on `chezmoi apply`: the
binaries install, the units deploy, and `zellij-observability.target` is
enabled and started. On a fresh host there's nothing to do but look. For what
the stack is and why it's shaped this way, see
[../explanation/zellij-observability.md](../explanation/zellij-observability.md);
for ports, storage paths, and the metrics it exposes, see
[../reference/zellij-observability.md](../reference/zellij-observability.md).

## View the dashboards

Grafana runs as part of the stack, so open <http://127.0.0.1:3000> (default
login `admin`/`admin`) and select the **Zellij freeze** dashboard. The Session
variable filters to one or more sessions.

## Keep capturing while logged out

The user services stop when your session ends. To capture an unattended wedge,
enable lingering so they keep running:

```bash
loginctl enable-linger
```

## Check what's being captured

Straight from the sampler, no stack required:

```bash
curl -s 127.0.0.1:9095/metrics
```

Follow a service's log, or check its state:

```bash
journalctl --user -u zellijstat.service -f
systemctl --user status alloy.service
```

## Stop or restart

```bash
systemctl --user stop zellij-observability.target
systemctl --user restart zellij-observability.target
```

## Bring it up by hand

The enable step that `chezmoi apply` runs, if you ever need it directly:

```bash
systemctl --user daemon-reload
systemctl --user enable --now zellij-observability.target
```
