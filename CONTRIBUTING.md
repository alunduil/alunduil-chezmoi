# Contributing

This is personal configuration, not a project looking for contributors. No roadmap, no support, no promise that a change lands. Fork it under [0BSD](LICENSE) and take what's useful.

## What happens to your pull request

One maintainer, reviewing when time allows, on a repo that isn't looking for changes. Most pull requests here won't merge, and that isn't a judgement on the work. Decide whether it's worth your time before you spend it.

A pull request that goes quiet for 30 days picks up a `stale` label and closes 14 days later. A comment or a push resets the clock, and asking on a closed one gets it reopened.

## Your description becomes the commit message

The repo squash-merges with `squash_merge_commit_message: PR_BODY`, so GitHub copies your title and description verbatim into `git log` and discards the commits on your branch. The description is the only thing that survives the merge.

Write it as a commit message, following the [seven rules of a great commit message](https://cbea.ms/git-commit/).

- Write the body as prose, not as a structured document. An H1 repeating the title, `##` section headings, checkbox lists, and a trailing disclosure block all land in `git log` as noise.
- Trailers don't survive. `Signed-off-by`, `Assisted-by`, and the rest sit on the branch commits that the squash throws away.

For evidence that the change works, cite the checks on your pull request rather than a transcript of commands you ran on your own machine, which nobody else can reproduce. Don't hedge about a linter you couldn't install locally, because CI ran it.

When the branch already carries a good commit message, that message is usually the right description.

## Machine-assisted contributions

Pull requests written with an AI assistant or agent are welcome, on the same terms as anything else. The diff has to stand on its own, and you're accountable for it. Name the tool in the description, where one line does.
