# Zellij-freeze observability reference

Ports, storage locations, and the metrics `zellijstat` exposes. To operate the
stack see
[../how-to/viewing-zellij-freeze-data.md](../how-to/viewing-zellij-freeze-data.md);
for the rationale see
[../explanation/zellij-freeze-observability.md](../explanation/zellij-freeze-observability.md).

## Services

| Service    | Listens on        | Data under `~/.local/state/`       |
|------------|-------------------|------------------------------------|
| zellijstat | `127.0.0.1:9095`  | —                                  |
| Prometheus | `127.0.0.1:9090`  | `zellij-observability/prometheus`  |
| Loki       | `127.0.0.1:3100`  | `zellij-observability/loki`        |
| Tempo      | `127.0.0.1:3200`  | `zellij-observability/tempo`       |
| Alloy      | `127.0.0.1:12345` | `zellij-observability/alloy` (WAL) |
| Grafana    | `127.0.0.1:3000`  | `zellij-observability/grafana`     |

Alloy's OTLP receiver listens on `127.0.0.1:4317` (gRPC) and `4318` (HTTP), and
tails `~/.local/state/zellij-diag/*.log` into Loki.

## Metrics

`zellijstat` exposes these on `127.0.0.1:9095/metrics`. Every per-server series
carries `session` and `pid` labels.

| Metric | Type | Description |
| ------ | ---- | ----------- |
| `zellijstat_servers` | gauge | Number of Zellij servers sampled. |
| `zellijstat_server_threads` | gauge | Threads in the server process. |
| `zellijstat_server_threads_by_comm` | gauge | Threads grouped by thread name (`comm` label). |
| `zellijstat_server_threads_by_wchan` | gauge | Threads grouped by kernel wait-channel (`wchan` label); the futex pile-up. |
| `zellijstat_server_unix_connections` | gauge | Unix-domain sockets held by the server. |
| `zellijstat_server_unix_recvq_bytes` | gauge | Summed Recv-Q across those sockets. |
| `zellijstat_server_unix_sendq_bytes` | gauge | Summed Send-Q across those sockets. |
| `zellijstat_server_open_fds` | gauge | Open file descriptors. |
| `zellijstat_server_cpu_seconds_total` | counter | Server CPU time (`utime` + `stime`), seconds. |
| `zellijstat_server_memory_rss_bytes` | gauge | Resident set size, bytes. |
