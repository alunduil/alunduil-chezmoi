# Paths

The order of three paths across the [data flow](data-flow.md#level-0),
and what a failure does at each step. In the sequence diagrams, an `alt`
box runs exactly one of its bracketed branches, and an `opt` box runs
only when its condition holds.

## Read a secret at apply

Process `1.0`, through `2.0`, for every item in
`.chezmoidata/onepassword.yaml`.

```mermaid
sequenceDiagram
  participant Apply as chezmoi apply
  participant Op as op
  participant App as 1Password app
  participant User
  participant Tokens as D3 Service tokens
  participant Register as register script
  participant Registry as D5 MCP registry

  alt CHEZMOI_NO_1PASSWORD set
    Note over Apply: renders the secret empty, so no file is written
  else
    Apply->>Op: item ID
    Op->>App: secret request
    opt process not yet approved
      App->>User: approval prompt
      User-->>App: approval
    end
    alt app locked or request denied
      App-->>Op: refusal
      Op-->>Apply: error
      Note over Apply: apply fails
    else
      App-->>Op: secret value
      Op-->>Apply: secret value
      Apply->>Tokens: service token, mode 600
      opt the secret's hash changed
        Apply->>Register: run the registration script
        Register->>Tokens: read token
        Register->>Registry: remove the server, then add it with the token
      end
    end
  end
```

A changed Grafana Cloud token restarts `alloy.service` in place of a
registration.

## Call a tool

Process `3.0`, for every tool call the model proposes.

```mermaid
sequenceDiagram
  participant Model as Claude API
  participant Session as Claude Code
  participant Pre as PreToolUse hooks
  participant Tool as MCP server, shell, or file edit
  participant Post as PostToolUse hooks

  Model-->>Session: tool call
  Session->>Pre: proposed tool call
  alt create_pull_request without draft: true
    Pre-->>Session: rejection
    Session->>Model: rejection as the tool result
  else
    Session->>Tool: approved tool call
    Tool-->>Session: tool result
    Session->>Post: tool result
    opt an edited file in a repository with pre-commit
      Post->>Post: run pre-commit on the file
      Post-->>Session: lint findings
    end
    Session->>Model: tool result and lint findings
  end
```

Both hook phases also send session events to the Zellij pane title,
asynchronously.

## Sign a commit or authenticate a connection

Process `4.0`, through `2.0`. `git` signs through `op-ssh-sign`. `ssh`
authenticates through the agent socket.

```mermaid
sequenceDiagram
  participant Git as git or ssh
  participant App as 1Password app
  participant User
  participant GitHub as GitHub or Home Assistant

  Git->>App: signing request
  opt process not yet approved
    App->>User: approval prompt
    User-->>App: approval
  end
  alt app locked or request denied
    App-->>Git: refusal
    Note over Git: the commit or the connection fails
  else
    App-->>Git: SSH signature
    Git->>GitHub: signed commit, or authenticated session
  end
```

The SSH key never leaves D4. Only the signature crosses to `4.0`.
