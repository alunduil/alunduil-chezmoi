# Contributing

This is personal configuration, not a project looking for contributors. The README means what it says: no roadmap, no support, no promise that a change lands. Fork it under [0BSD](LICENSE) and take what's useful.

Pull requests arrive anyway, and they get read. This page covers the repo mechanics a reviewer would otherwise have to explain to you mid-review.

## Your description becomes the commit message

The repo squash-merges with `squash_merge_commit_message: PR_BODY`, so GitHub copies your title and description verbatim into `git log` and discards the commits on your branch along with any trailers they carry. Write the description as a commit message, following the [seven rules of a great commit message](https://cbea.ms/git-commit/):

- The title is the subject line: imperative mood, 50 characters or fewer, no trailing period.
- Wrap the body at 72 columns and spend it on why the change matters and anything surprising about how it works.
- Write the body as prose, not as a structured document. An H1 repeating the title, `##` section headings, checkbox lists, and a trailing disclosure block all land in `git log` as scaffolding around the content you meant to write.
- `Signed-off-by`, `Assisted-by`, and every other trailer on a branch commit disappears in the squash. Anything that has to persist belongs in the description.

When the branch already carries a good commit message, that message is usually the right description.

## Open as a draft

Open every pull request as a draft and mark it ready when you want eyes on it. Review starts at ready, so a draft leaves room for the checks to run and for you to push fixes without pulling anyone in mid-change.

## Show how you know it works

Every check runs on your pull request: pre-commit hooks, the shell tests, chezmoi source validation, Zellij and telemetry config validation, prose linting, and systemd unit validation. Those green checks are the evidence, and citing them beats a transcript of commands you ran on your own machine that nobody else can reproduce. It also settles the linters you couldn't install locally: CI already ran them, so there's nothing to hedge about.

`just check` runs the same sensors locally when you have the host tooling installed. CI is authoritative either way.

## Machine-assisted contributions

Pull requests written with an AI assistant or agent are welcome, on the same terms as anything else. The diff has to stand on its own, and you're accountable for it. Name the tool in the description, where one line does. That's the only place the disclosure survives, since the description is what becomes the commit message.

## Review

One maintainer, reviewing when time allows. A pull request that goes quiet for 30 days picks up a `stale` label and closes 14 days later. A comment or a push resets the clock, and asking on a closed one gets it reopened.
