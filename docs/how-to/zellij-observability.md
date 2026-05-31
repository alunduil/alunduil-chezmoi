# Zellij-freeze observability stack

An always-on, out-of-band telemetry stack for the Zellij-freeze
investigation. `zellijstat` samples every Zellij server from `/proc`
(thread count, per-thread wait-channel, Unix-socket connections and queue
depth, file descriptors, CPU, RSS) and exposes Prometheus metrics; Alloy
collects them into a local Prometheus, and Grafana draws the per-session
curves. Because `zellijstat` only reads `/proc`, it keeps recording
straight through a server wedge—the point of an *external* observer.

```
zellijstat ─/metrics─▶ Alloy ─▶ Prometheus ─┐
zellij-diag logs ─────▶ Alloy ─▶ Loki ───────┼─▶ Grafana
fork OTLP ────────────▶ Alloy ─▶ Tempo ──────┘
```

It runs on stock Zellij. Today only the metrics path carries data; the log
(Loki) and trace (Tempo) paths are wired but idle until the Zellij and
zellaude forks emit (issues #223 and #224).

## Bring up the capture stack

`chezmoi apply` installs the binaries and deploys the units; it does **not**
start them. Enable the always-on target once per host:

```bash
systemctl --user daemon-reload
systemctl --user enable --now zellij-observability.target
```

To keep it running while you are logged out (so it captures an unattended
wedge), enable lingering:

```bash
loginctl enable-linger
```

## View the dashboards

Grafana is a separate on-demand viewer—start it only when looking:

```bash
systemctl --user start grafana
```

Open <http://127.0.0.1:3000> (default login `admin`/`admin`) and find the
provisioned **Zellij freeze** dashboard. The Session variable filters to one
or more sessions.

## Ports and storage

| Service    | Address           | Data under `~/.local/state/`        |
|------------|-------------------|-------------------------------------|
| zellijstat | `127.0.0.1:9095`  | —                                   |
| Prometheus | `127.0.0.1:9090`  | `zellij-observability/prometheus`   |
| Loki       | `127.0.0.1:3100`  | `zellij-observability/loki`         |
| Tempo      | `127.0.0.1:3200`  | `zellij-observability/tempo`        |
| Alloy      | `127.0.0.1:12345` | `zellij-observability/alloy` (WAL)  |
| Grafana    | `127.0.0.1:3000`  | `zellij-observability/grafana`      |

The forks write logs to `~/.local/state/zellij-diag/*.log`, which Alloy
tails into Loki, and send OTLP to Alloy on `127.0.0.1:4317`.

## Stop or inspect

```bash
systemctl --user stop zellij-observability.target   # stop the capture stack
systemctl --user status alloy.service               # one service
journalctl --user -u zellijstat.service -f          # follow its log
curl -s 127.0.0.1:9095/metrics                       # raw sample, no stack needed
```
