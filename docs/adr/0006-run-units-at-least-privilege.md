# 6. Run units at the lowest privilege the job needs

## Status

Accepted

## Context

This repo ships units to two systemd managers: user units under
`dot_config/systemd/user/`, and system units under `etc/systemd/system/` that a
bootstrap pass installs with `sudo`. Nothing stated which manager a new unit
belongs in, or what it should run as. The nearest thing to a rule was a comment
in the docker-prune pass (#312).

An earlier plan (#348) sketched a privilege split for an observability stack.
It never landed, and #404 removed most of what did, so the rule has to fit the
units left standing.

Four facts shape it, each checked on `penguin` at systemd 252.

- `DynamicUser=yes` doesn't work in the user manager. A unit that sets it dies
  with status 217, because that manager runs unprivileged and can't allocate a
  uid. The setting only ever applies to system units.
- `LoadCredential=` does work in the user manager. Either manager can use it to
  hand a unit one secret.
- Access doesn't settle every case. The Docker socket is owned by `root:docker`
  and the login user is in the `docker` group, so a user unit could run the
  prune. Root isn't forced.
- Privilege sometimes buys survival rather than access. `sysstat-collect.service`
  runs as root in `system.slice`, so `sadc` keeps sampling when the user slice
  runs out of pids. That's the failure #404 exists to record, and a user unit
  goes dark at exactly that moment.

The last two split one question into two: which manager owns the job, and what
it runs as inside that manager.

## Decision

Place a unit in the manager that matches whose state it touches. Host-wide
state, or work that must outlive a login session, goes in a system unit. The
user's own files, caches, and credentials go in a user unit.

Then run it as the least privileged identity that reaches the resource. A
system unit needing nothing root-owned takes `DynamicUser=yes` with
`StateDirectory=`. Root is for a job that needs a root-owned resource, or that
has to keep running when the user slice fails. User units run as the login
user, and there is no lower option there.

Pass secrets with `LoadCredential=`, so the unit names the secret it needs.

A unit that departs from this says why in a comment beside the setting.

## Consequences

- The Docker prune stays a root system unit, even though the `docker` group
  would also reach the socket. Docker keeps host-wide state, and tying host
  maintenance to one login identity buys nothing.
- The Alloy shipper takes its Grafana Cloud token through `LoadCredential=`,
  and `config.alloy` reads `$CREDENTIALS_DIRECTORY`. Running Alloy outside
  systemd means setting that variable, or it looks in the wrong place.
- `DynamicUser=yes` has no user yet, because the system units here need root.
  The clause is written down so the next system daemon doesn't re-derive it.
- The shipper stays in the user slice, so it still goes dark during a pids
  exhaustion. That's accepted rather than overlooked: sar owns the local
  record (#404).
- The per-user timers keep running as the login user, which is what gives them
  the user's `gh` auth and clone layout.
