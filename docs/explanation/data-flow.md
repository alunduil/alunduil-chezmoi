# Data flow

Where data moves on a chezmoi-managed workstation, what transforms it, and which trust boundaries it crosses. The audience is someone threat-modelling this host or auditing a credential: the diagrams below are the input a per-element STRIDE pass walks over, and the secrets table answers "what reaches what" for any one token.

Scope is the workstation-bounded slice of alunduil's personal systems—the surface chezmoi manages, plus the Model Context Protocol (MCP) fleet a Claude Code session talks to. The cloud and home-network slice has its own diagram in `alunduil-infrastructure`, which owns the decomposition of GitHub, Cloudflare, and the home network; here they stay external entities. Controls and mitigations belong to the threat model, not here—a data flow diagram carries boundaries, not defences.

These are *physical* diagrams: elements name the software, hosts, and files doing the work rather than abstract activities. Processes are rounded, data stores are cylinders, external entities are rectangles, and each trust boundary is a `subgraph` named for whoever controls that side. The `dfd` skill under `dot_claude/skills/dfd/` carries the notation and the correctness rules the diagrams are checked against, and the repo's `CLAUDE.md` carries the rule that keeps this document current.

## Context

The workstation as a single process, surrounded by everything it exchanges data with. The user is the trust root and sits outside every boundary; every other entity belongs to someone else.

```mermaid
flowchart LR
  user[User]
  github[GitHub]
  anthropic[Anthropic]
  cloudflare[Cloudflare]
  context7[Context7]
  uptimerobot[Uptime Robot]
  codecov[Codecov]
  truenas[TrueNAS appliance]
  grafana[Grafana Cloud]
  upstream[Debian archives and release hosts]

  p0(0 Operate the chezmoi-managed workstation)

  user -->|prompt| p0
  user -->|shell command| p0
  user -->|age identity| p0
  user -->|GPG passphrase| p0
  p0 -->|session output| user
  p0 -->|status line| user
  p0 -->|command output| user

  github -->|chezmoi source| p0
  github -->|repository data| p0
  p0 -->|signed commit and pull request| github
  p0 -->|authenticated repository query| github

  anthropic -->|completion and tool call| p0
  anthropic -->|connector document| p0
  p0 -->|prompt, file content, and tool result| anthropic
  p0 -->|connector query| anthropic

  cloudflare -->|zone, DNS analytics, and documentation| p0
  p0 -->|zone and documentation query| cloudflare

  context7 -->|library documentation| p0
  p0 -->|library documentation query| context7

  uptimerobot -->|monitor and incident data| p0
  p0 -->|authenticated monitor query| uptimerobot

  codecov -->|coverage and test result data| p0
  p0 -->|authenticated coverage query| codecov

  truenas -->|pool, app, and alert data| p0
  p0 -->|authenticated storage query| truenas

  p0 -->|authenticated host metrics and logs| grafana

  upstream -->|package and release binary| p0
  p0 -->|package and release request| upstream
```

The age identity is the only inbound secret with no network path: a password manager holds it and the user restores it by hand on a fresh host. Everything else the host needs unlocks from that one value.

## The workstation and its stores

The boundary that carries the most weight is the workstation edge, because there is no privilege separation inside it: a bootstrap pass and a model-driven session run as the same user, over the same stores.

```mermaid
flowchart TB
  user[User]

  subgraph ws["Workstation: Crostini VM"]
    p1(1.0 Apply the chezmoi source)
    p2(2.0 Register MCP servers)
    p3(3.0 Run a Claude Code session)
    p4(4.0 Run developer tooling)
    p5(5.0 Ship host telemetry)

    s1[(Apply clone)]
    s2[(age identity)]
    s3[(Service tokens)]
    s8[(Signing and transport identities)]
    s4[(MCP registry)]
    s5[(Claude configuration)]
    s6[(Session record)]
    s7[(Host telemetry)]
  end

  subgraph gh[GitHub]
    github[GitHub API and git remote]
  end

  subgraph anth[Anthropic]
    anthropic[Claude API and claude.ai connectors]
  end

  subgraph cf[Cloudflare]
    cloudflare[Cloudflare MCP endpoints]
  end

  subgraph tp[Third-party SaaS]
    context7[Context7]
    uptimerobot[Uptime Robot]
    codecov[Codecov]
    grafana[Grafana Cloud]
  end

  subgraph home[Home network]
    truenas[TrueNAS appliance]
  end

  subgraph dist[Distribution and release hosts]
    upstream[Debian archives and release hosts]
  end

  user -->|age identity| p1
  user -->|prompt| p3
  user -->|shell command| p4
  user -->|GPG passphrase| p4
  p3 -->|session output| user
  p3 -->|status line| user
  p4 -->|command output| user

  github -->|chezmoi source| p1
  p1 -->|chezmoi source| s1
  s1 -->|source template and encrypted blob| p1
  p1 -->|age identity| s2
  s2 -->|age identity| p1
  p1 -->|deployed file and service token| s3
  p1 -->|SSH key and encrypted GPG key| s8
  p1 -->|Claude configuration| s5
  s8 -->|passphrase-protected GPG key| p1
  p1 -->|imported GPG key| s8
  p1 -->|rendered registration script| p2
  p1 -->|package and release request| upstream
  upstream -->|package and release binary| p1

  s3 -->|plaintext token| p2
  p2 -->|MCP endpoint and credential| s4

  s4 -->|MCP endpoint and credential| p3
  s5 -->|Claude configuration| p3
  s6 -->|transcript and memory| p3
  p3 -->|transcript and memory| s6
  p3 -->|shell command| p4
  p4 -->|command output| p3
  p3 -->|zellij log and process metric| s7

  anthropic -->|completion and tool call| p3
  anthropic -->|connector document| p3
  p3 -->|prompt, file content, and tool result| anthropic
  p3 -->|connector query| anthropic
  cloudflare -->|zone, DNS analytics, and documentation| p3
  p3 -->|zone and documentation query| cloudflare
  context7 -->|library documentation| p3
  p3 -->|library documentation query| context7
  uptimerobot -->|monitor and incident data| p3
  p3 -->|authenticated monitor query| uptimerobot
  truenas -->|pool, app, and alert data| p3
  p3 -->|authenticated storage query| truenas
  github -->|repository data| p3
  p3 -->|authenticated repository query| github

  s3 -->|Codecov API token| p4
  s3 -->|Cloudflare API token| p4
  s8 -->|SSH key and GPG key| p4
  github -->|repository data| p4
  p4 -->|authenticated repository query| github
  p4 -->|signed commit and pull request| github
  codecov -->|coverage and test result data| p4
  p4 -->|authenticated coverage query| codecov

  s3 -->|Grafana Cloud token| p5
  s7 -->|journal entry, zellij log, and process metric| p5
  p5 -->|authenticated host metrics and logs| grafana
```

Three stores hold credentials in the clear; the source tree holds none of them, carrying only the age-encrypted blob. *Service tokens* and *Signing and transport identities* are chezmoi targets, written on apply with the encryption stripped off. Their reach differs sharply: the tokens fan out to three processes and, through the registry, into a file that holds them in plaintext, while a single process reads the identities.

*MCP registry* is `~/.claude.json`, which Claude Code owns and rewrites, so chezmoi can't manage it and registration runs from a bootstrap pass instead. Bearer tokens and stdio environment variables land there in plaintext, and a rotated token has to re-register rather than merely re-deploy.

*Session record* covers transcripts and the per-project auto memory under `~/.claude/projects/`. It's machine-local with no cross-machine path in either direction, so it never crosses a boundary except as prompt content the model already sees.

The lean host role narrows this picture. `.chezmoiignore` drops the whole *Signing and transport identities* store for that role, so a network-exposed host next to home automation carries only the narrowly scoped tokens it needs.

## Applying the source

Process `1.0` is where the single out-of-band secret turns into every other one.

```mermaid
flowchart LR
  user[User]
  github[GitHub]
  upstream[Debian archives and release hosts]

  subgraph ws[Workstation]
    p11(1.1 Initialise the host)
    p12(1.2 Render templates and decrypt secrets)
    p13(1.3 Run bootstrap passes)
    p2(2.0 Register MCP servers)

    s1[(Apply clone)]
    s2[(age identity)]
    s3[(Service tokens)]
    s8[(Signing and transport identities)]
    s4[(MCP registry)]
    s5[(Claude configuration)]
  end

  user -->|age identity| p11
  github -->|chezmoi source| p11
  p11 -->|age identity| s2
  p11 -->|chezmoi source| s1

  s1 -->|source template and encrypted blob| p12
  s2 -->|age identity| p12
  p12 -->|deployed file and service token| s3
  p12 -->|SSH key and encrypted GPG key| s8
  p12 -->|Claude configuration| s5
  p12 -->|rendered registration script| p2
  p12 -->|rendered bootstrap script| p13
  s3 -->|plaintext token| p2
  p2 -->|MCP endpoint and credential| s4

  s8 -->|passphrase-protected GPG key| p13
  p13 -->|imported GPG key| s8
  p13 -->|package and release request| upstream
  upstream -->|package and release binary| p13
```

`1.2` reads the apply clone at `~/.local/share/chezmoi`, never a developer's working tree, which is why `chezmoi source` always originates at GitHub. [Architecture](architecture.md) covers why the two clones are separate.

The GPG key crosses `1.3` still encrypted, because the armored blob is passphrase-protected by GPG independently of age. Signing therefore needs age identity *and* GPG passphrase, while SSH needs only the age identity—the asymmetry that lets `chezmoi init --apply` reach GitHub unattended on a fresh host.

## The session and the MCP fleet

This is the level where the fleet's trust boundaries separate.

```mermaid
flowchart TB
  user[User]

  subgraph ws[Workstation]
    p31(3.1 Exchange turns with the model)
    p32(3.2 Gate the tool call)
    p33(3.3 Annotate the tool result)
    p34(3.4 Call an MCP server)
    p35(3.5 Render the status line)
    p4(4.0 Run developer tooling)

    s4[(MCP registry)]
    s5[(Claude configuration)]
    s6[(Session record)]
    s7[(Host telemetry)]
  end

  subgraph anth[Anthropic]
    api[Claude API]
    connectors["claude.ai connectors: Notion, Readwise"]
  end

  subgraph gh[GitHub]
    github[GitHub Copilot MCP]
  end

  subgraph cf[Cloudflare]
    cloudflare["graphql, docs, dns-analytics"]
  end

  subgraph tp[Third-party remote]
    context7[Context7]
    uptimerobot[Uptime Robot]
  end

  subgraph home[Home network]
    truenas[TrueNAS appliance]
  end

  user -->|prompt| p31
  s5 -->|Claude configuration| p31
  s6 -->|transcript and memory| p31
  p31 -->|transcript and memory| s6
  p31 -->|session output| user
  p31 -->|zellij log and process metric| s7
  p31 -->|session usage| p35
  p35 -->|status line| user

  api -->|completion and tool call| p31
  p31 -->|prompt, file content, and tool result| api

  p31 -->|proposed tool call| p32
  p32 -->|shell command| p4
  p32 -->|approved tool call| p34
  p34 -->|tool result| p33

  p4 -->|command output| p33
  p33 -->|annotated tool result| p31

  s4 -->|MCP endpoint and credential| p34
  p34 -->|connector query| connectors
  connectors -->|connector document| p34
  p34 -->|authenticated repository query| github
  github -->|repository data| p34
  p34 -->|zone and documentation query| cloudflare
  cloudflare -->|zone, DNS analytics, and documentation| p34
  p34 -->|library documentation query| context7
  context7 -->|library documentation| p34
  p34 -->|authenticated monitor query| uptimerobot
  uptimerobot -->|monitor and incident data| p34
  p34 -->|authenticated storage query| truenas
  truenas -->|pool, app, and alert data| p34
```

Processes `3.2` and `3.3` are this repo's own guardrails between a model-proposed action and the host, layered over Claude Code's permission prompts rather than replacing them. They're two processes because they hold different powers at different moments. `3.2` is the `PreToolUse` phase and is the only one that can stop anything: the pull-request guard rejects a `create_pull_request` call missing `draft: true`, and the `rtk` hook rewrites a Bash command to run through a filtering proxy. `3.3` is the `PostToolUse` phase and can only add: lint on a just-written file, and the session events the Zellij pane title reads.

The rewrite in `3.2` is why the `command output` arriving at `3.3` is already trimmed—`4.0` ran the proxy, not the bare command. What `3.1` finally reads is a summary of what the host said, not the host's own answer.

Four kinds of credential relationship show up across the fleet:

- **No local credential.** The claude.ai connectors authenticate by an OAuth grant held on the Anthropic account. Nothing for Notion or Readwise is deployed to this host, so a compromised workstation reaches them only for as long as it can drive a session.
- **OAuth held by Claude Code.** The Cloudflare endpoints are Cloudflare-hosted and obtain their grant through a browser on first use. The grant lives outside the chezmoi source, so rotating it isn't an apply-time operation.
- **Bearer token in the registry.** GitHub and Uptime Robot pass a token via `--header`, which Claude Code writes into `~/.claude.json` in plaintext. GitHub takes this route because its OAuth endpoint wants a pre-registered client that Claude Code's dynamic registration doesn't satisfy.
- **Environment variable to a local process.** TrueNAS runs as a stdio binary on this host with its URL and API key passed as `-e` variables, also persisted into `~/.claude.json`. It's the only flow that terminates inside the home network, and it runs with certificate verification disabled because the appliance's certificate carries no IP subject alternative name.

Context7 sits outside all four, running keyless. Anonymous use is rate-limited and a key would raise the ceiling, but no limit pressure has appeared.

## Running developer tooling

Process `4.0` is the catch-all both the user and the session shell into, and the one place a credential lives in an environment variable rather than a file.

```mermaid
flowchart LR
  user[User]

  subgraph ws[Workstation]
    p41(4.1 Run the interactive shell)
    p42(4.2 Run git and gh)
    p43(4.3 Query Codecov)
    p3(3.0 Run a Claude Code session)

    s3[(Service tokens)]
    s8[(Signing and transport identities)]
  end

  subgraph gh[GitHub]
    github[GitHub API and git remote]
  end

  subgraph tp[Third-party SaaS]
    codecov[Codecov]
  end

  user -->|shell command| p41
  p3 -->|shell command| p41
  s3 -->|Codecov API token| p41
  s3 -->|Cloudflare API token| p41
  p41 -->|command output| user
  p41 -->|command output| p3
  p41 -->|dispatched command| p42
  p41 -->|dispatched command| p43
  p41 -->|Codecov API token| p43
  p42 -->|command output| p41
  p43 -->|command output| p41

  user -->|GPG passphrase| p42
  s8 -->|SSH key and GPG key| p42
  github -->|repository data| p42
  p42 -->|authenticated repository query| github
  p42 -->|signed commit and pull request| github

  codecov -->|coverage and test result data| p43
  p43 -->|authenticated coverage query| codecov
```

`4.1` is `dot_bashrc` exporting the decrypted tokens, which every child shell then inherits whether or not it needs them. Only `4.2` reads the signing and transport identities, and no path leads from the MCP registry to the GPG key, so a token compromise never produces a signed commit.

The Cloudflare API token enters `4.1` and leaves through no drawn flow: a grey hole, an input the outputs can't account for. Either a flow is missing because someone reaches Cloudflare interactively, or the credential is dead and its blob carries risk for nothing. Ad-hoc shell use leaves no trace in the source tree, so the diagram settles only the narrower claim—nothing this repo manages consumes the token.

## Deployed secrets

Every credential the source tree carries, and what reaches what once it's decrypted.

| Secret | Deployed to | Read by | Boundary it crosses |
| --- | --- | --- | --- |
| age identity | `~/.config/chezmoi/key.txt` | chezmoi apply | none—never leaves the host |
| GPG secret key | `~/.gnupg/secret-keys.asc` | PGP import pass, commit signing | none directly; signatures reach GitHub |
| SSH key and config | `~/.ssh/` | git over SSH | GitHub |
| GitHub token | `~/.config/github/token` | `github` MCP registration, then `~/.claude.json` | GitHub |
| TrueNAS API key | `~/.config/truenas/api_key` | `truenas` MCP registration, then `~/.claude.json` | home network |
| Uptime Robot token | `~/.config/uptimerobot/token` | `uptimerobot` MCP registration; `UPTIMEROBOT_API_TOKEN` in the shell | Uptime Robot |
| Codecov token | `~/.config/codecov/token` | `CODECOV_API_TOKEN`, consumed by `codecov-api` | Codecov |
| Grafana Cloud token | `~/.config/grafana-cloud/token` | `alloy.service` via `LoadCredential` | Grafana Cloud |
| Cloudflare token | `~/.config/cloudflare/token` | `CLOUDFLARE_API_TOKEN` in the shell | none drawn |

Cloudflare crosses no boundary because its three MCP servers authenticate by OAuth rather than by this token—the grey hole in `4.0`.

The GitHub token and the SSH key both reach GitHub, through different processes with different blast radii. The SSH key authenticates git transport and is scoped by its own registration; the token authenticates the MCP server and carries whatever fine-grained permissions were granted at issue time. A compromise of `~/.claude.json` reaches the token and not the key.
