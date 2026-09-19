# Contributing

This is personal configuration, not a project looking for contributors. No roadmap, no support, no promise that a change lands. Fork it under [0BSD](LICENSE) and take what's useful.

Pull requests arrive anyway, and they get read. This page covers the repo mechanics a reviewer would otherwise have to explain to you mid-review.

## Your description becomes the commit message

The repo squash-merges with `squash_merge_commit_message: PR_BODY`, so GitHub copies your title and description verbatim into `git log` and discards the commits on your branch. The description is the only thing that survives the merge.

Write it as a commit message, following the [seven rules of a great commit message](https://cbea.ms/git-commit/):

- The title is the subject line: imperative mood, 50 characters or fewer, no trailing period.
- Wrap the body at 72 columns and spend it on why the change matters and anything surprising about how it works.
- Write the body as prose, not as a structured document. An H1 repeating the title, `##` section headings, checkbox lists, and a trailing disclosure block all land in `git log` as noise.
- Trailers don't survive. `Signed-off-by`, `Assisted-by`, and the rest sit on the branch commits that the squash throws away.

When the branch already carries a good commit message, that message is usually the right description.

## Open as a draft

Open every pull request as a draft and mark it ready when you want eyes on it. Review starts at ready, so a draft leaves room for the checks to run and for you to push fixes without pulling anyone in mid-change.

## Show how you know it works

The checks on your pull request are the evidence. Cite them rather than a transcript of commands you ran on your own machine, which nobody else can reproduce. Don't hedge about a linter you couldn't install locally, because CI ran it.

`just check` runs the same sensors locally when you have the host tooling installed.

## Machine-assisted contributions

Pull requests written with an AI assistant or agent are welcome, on the same terms as anything else. The diff has to stand on its own, and you're accountable for it. Name the tool in the description, where one line does.

## Review

One maintainer, reviewing when time allows. A pull request that goes quiet for 30 days picks up a `stale` label and closes 14 days later. A comment or a push resets the clock, and asking on a closed one gets it reopened.
