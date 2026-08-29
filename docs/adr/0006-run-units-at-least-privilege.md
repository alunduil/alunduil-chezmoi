# 6. Run units at the lowest privilege the job needs

## Status

Accepted

## Context

This repo defines units in two systemd managers. `dot_config/systemd/user/`
holds the user ones. `etc/systemd/system/` holds the system ones, which a
bootstrap pass copies in with `sudo`. Nothing stated which manager a new unit
belongs in, or what it should run as. The nearest thing to a rule was a comment
in the docker-prune pass (#312).

An earlier plan, #348, sketched a split for an observability stack: root for
the host-wide readers, `DynamicUser=yes` for the plain daemons,
`LoadCredential=` for the cloud token. That stack never landed. #404 tore out
what did, leaving one shipper, one sampler, and the maintenance timers. So the
rule has to fit the units that exist, not the ones that were planned.

Four facts shape it. Each was checked on `penguin`, which runs systemd 252.

`DynamicUser=yes` doesn't work in the user manager. A unit that sets it dies
with status 217. The user manager runs unprivileged and can't allocate a uid,
so the setting only ever applies to system units.

`LoadCredential=` does work in the user manager. The secret lands under
`/run/user/<uid>/credentials/<unit>/`, mode 0400, owned by the user. Both
managers can use it.

Access doesn't settle every case. The Docker socket is owned by `root:docker`,
and the login user is in the `docker` group, so a user unit could run the
prune. Root isn't forced here.

Privilege sometimes buys survival rather than access. `sysstat-collect.service`
runs as root in `system.slice`. That's why `sadc` keeps sampling when the user
slice runs out of pids, which is the failure #404 exists to record. A user unit
goes dark at that moment.

The last two facts split one question into two. Ask which manager owns the job.
Then ask what it runs as inside that manager.

## Decision

Place a unit in the manager that matches whose state it touches. Host-wide
state, or work that must outlive a login session, goes in a system unit. The
user's own files, caches, and credentials go in a user unit.

Then run it as the least privileged identity that reaches the resource. A
system unit that needs nothing root-owned takes `DynamicUser=yes` with
`StateDirectory=`. Root is for a job that needs a root-owned resource, or that
has to keep running when the user slice fails. User units run as the login
user, and there is no lower option there.

Pass secrets with `LoadCredential=`. The unit then names the one secret it
needs, and systemd hands it over on tmpfs at 0400.

A unit that departs from this says why in a comment beside the setting. The
rule covers the common case, so only the exceptions need prose.

## Consequences

- The Docker prune stays a root system unit, even though the `docker` group
  would also reach the socket. Docker keeps host-wide state, and tying host
  maintenance to one login identity buys nothing. Its comment already says so.
- The Alloy shipper takes its Grafana Cloud token through `LoadCredential=`
  rather than reading `$HOME`. The unit declares the secret, and `config.alloy`
  reads `$CREDENTIALS_DIRECTORY`. Running Alloy by hand now needs that variable
  set, which `script/checks/telemetry-config` does so the config still
  validates.
- `DynamicUser=yes` has no user today. The one system unit this repo owns needs
  root. The clause is here so the next system daemon doesn't re-derive it.
- The shipper stays in the user slice, so it still goes dark during a pids
  exhaustion. That's accepted rather than overlooked: sar owns the local
  record (#404).
- The per-user timers keep running as the login user, which is what gives them
  the user's `gh` auth and clone layout.
- New units get placed without a fresh argument each time. The cost is that a
  genuine exception now has to be argued in a comment.
