# alunduil-chezmoi

By [@alunduil](https://github.com/alunduil)

[![License: 0BSD](https://img.shields.io/github/license/alunduil/alunduil-chezmoi)](LICENSE)
[![Managed with chezmoi](https://img.shields.io/badge/managed%20with-chezmoi-blue)](https://chezmoi.io)
[![Platform: Debian / Crostini](https://img.shields.io/badge/platform-Debian%20%2F%20Crostini-A81D33?logo=debian&logoColor=white)](https://www.debian.org)
[![Claude skills: shareable](https://img.shields.io/badge/Claude%20skills-shareable-262625?logo=claude&logoColor=D97757)](dot_claude/skills/)

Personal [chezmoi](https://chezmoi.io)-managed dotfiles. Run one command on a fresh Debian/Crostini host to go from bare OS to a fully configured development environment with AI pair programming, terminal multiplexing, and git integration—layouts, keybinds, and guardrails included. Source: <https://github.com/alunduil/alunduil-chezmoi>.

Personal config—no warranty, no support. [0BSD licensed](LICENSE).

## Documentation

Organised by [Diátaxis](https://diataxis.fr):

- Tutorials
  - [Bootstrap](docs/tutorials/bootstrap.md)—zero to working host.
- How-to
  - [Adding an encrypted secret](docs/how-to/encrypted-secret.md)
  - [PGP commit signing](docs/how-to/pgp-signing.md): includes paper-key backup and key rotation.
- Explanation
  - [Architecture](docs/explanation/architecture.md)—source vs. apply clone, bootstrap shape, layered trust, the `gh` shim, the two `CLAUDE.md` files.

## Contributing

Personal configuration—not accepting contributions. Fork under [0BSD](LICENSE).
