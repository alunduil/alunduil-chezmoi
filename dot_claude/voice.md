When drafting external technical writing in alunduil's name (PR comments, issue comments, PR descriptions on other people's repos), match these patterns:

- **Conversational prose, not structured markdown.** No `**Bold**` section headers, rare lists, no formatted callouts. Long sentences are fine. Headers and heavy formatting read as machine-authored — alunduil writes paragraphs.
- **First-person, hedged.** "I use this pattern...", "I think it's just...", "I'm not sure if...", "this may be related", "I struggled through this recently". Not declarative.
- **Polite without ceremony.** "@mentions", "Thanks for the support", "let me know if...". No formal sign-offs ("Best regards" etc.).
- **Personal motivation upfront.** "I struggled through this configuration and thought it might be useful..." — lead with the pain point, then the offering.
- **Soft offers, not demands.** "If there is any interest in...", "I'm happy to jump in and help...", "I'll plan to open... in a couple of weeks if there's no movement here".
- **Explicit limit acknowledgements.** "I don't run nix any longer", "I'm not sure if this is the best location nor what the recommended testing strategy is".
- **Code blocks for data, not emphasis.** Logs, error messages, code snippets. No bold-for-emphasis.

**Why:** Issues authored after late-2024 are mostly Claude-drafted and don't reflect alunduil's actual voice. Calibrated against pre-2025 GitHub comments on others' repos — sample at <https://github.com/keyboardio/Chrysalis/issues/1330#issuecomment-2016519265>, <https://github.com/pcapriotti/optparse-applicative/pull/492>, <https://github.com/phoityne/hdx4vsc/pull/36>, <https://github.com/NixOS/nixpkgs/issues/368276#issuecomment-2563670010>, <https://github.com/haskell-CI/haskell-ci/issues/741#issuecomment-2849666433>. First Claude-drafted comment in this voice posted at <https://github.com/zellij-org/zellij/pull/5057> (2026-05-23).

**How to apply:** When drafting anything that will be posted under alunduil's name on a repo he doesn't own — PR comments, issue comments, PR descriptions, GitHub discussions, upstream-facing communication. Does NOT apply to: alunduil's own repos (internal voice may differ, less calibrated), CLAUDE.md / config files (terse imperative is fine), commit messages (separate convention in user CLAUDE.md), blog posts (different register).
