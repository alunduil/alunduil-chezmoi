# Viewing the Zellij-freeze data

`chezmoi apply` brings the observability stack up and keeps it running, so on a
fresh host there's nothing to start. Open Grafana at <http://127.0.0.1:3000>
(default login `admin`/`admin`) and select the **Zellij freeze** dashboard; the
Session variable filters to one or more sessions.

For unattended capture (recording a wedge while you're logged out), enable
lingering, since user services otherwise stop with your session:

```bash
loginctl enable-linger
```

For what the stack is and why, see
[../explanation/zellij-freeze-observability.md](../explanation/zellij-freeze-observability.md);
for ports, storage paths, and the metrics it exposes, see
[../reference/zellij-freeze-observability-reference.md](../reference/zellij-freeze-observability-reference.md).
