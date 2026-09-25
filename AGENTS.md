# AGENTS.md

This file provides guidance to coding agents (Claude Code, Codex, Copilot and others) when working
with code in this repository.

## What this is

A personal repo for learning Podman on Windows: notes and experiments, plus `PodmanHelpers.ps1`,
a set of PowerShell functions (`pod-sys-start`, `pod-sys-stop`, `pod-run`, `pod-start`,
`pod-open`, `pod-test`, `pod-test-alp`, `pod-ls`) that users dot-source from their `$PROFILE`.
There is no build, test suite or linter.
It may be published, so keep it free of employer names, customer data and PII.

`PLAN.md` is the learning plan: phases of short lessons, each with a **Try** command, and a
progress tracker at the end.

## Your role

This is the owner's learning project, and the README's "How AI is used in this project" section
tells readers what AI did. Stay within it:

- **Do, when asked:** prepare and update the learning plan, give advice and explanations, and
  write or change the PowerShell in `PodmanHelpers.ps1` (with the README table and docs that go
  with it).
- **Leave to the owner:** working through the lessons, deciding what functionality the helpers
  need, and taking screenshots. Don't add helpers or features that weren't asked for; suggest
  them instead. Don't mark lessons or phases done unless the owner says they are.
- You can run podman commands to check an answer or test a change, but tidy up anything you
  create (containers, services you stopped) and say what you ran. Ask before anything
  disruptive, such as stopping the machine.
- Don't commit unless asked. Assume most commits are co-authored by AI: the point of this repo
  is learning, and AI acts as the teacher and assistant. So commit messages have no AI
  attribution lines; the README explains AI's part in the project once, for the whole history.

## Trying changes

Reload the helpers in the current session and run them. Podman needs a running machine, so start
it first:

```powershell
. .\PodmanHelpers.ps1
pod-sys-start
pod-test      # runs quay.io/podman/hello
pod-ls
pod-sys-stop
```

`pod-ls` also works with the machine stopped (it shows only what Windows knows), so test both
states when changing it.

Output is piped through `lolcatjs` (`npm install -g lolcatjs`), which must be on PATH.

If `podman` isn't found in an agent's shell, the shell may have started with a stale PATH.
Podman installs to `C:\Program Files\RedHat\Podman\` and is on the machine PATH.

## Conventions in PodmanHelpers.ps1

- **Names:** helpers are `pod-<name>` with dashes, not underscores, matching usual CLI naming.
- **The rainbow-output pattern:** podman output is captured with `2>&1` (so warnings show too),
  each line is turned into a string with `ForEach-Object { "$_" }`, and the lines are joined with
  `` "`n" `` (LF only) before being piped to `lolcatjs`. CRs make lolcatjs add a blank line after
  every line. New functions that print podman output should follow this pattern. Inside `pod-ls`
  the nested `podlines` helper does the first two steps. Rainbow output is the norm for `pod-*`
  helpers, so requests rarely need to spell it out.
- `pod-run` reads `$args` rather than a `param()` block on purpose, so options meant for the
  container (`-la`, `-i`, `-o`) aren't bound by PowerShell as parameters of `pod-run`. Wrap it
  (like `pod-test`) rather than duplicating `podman run --rm` logic.
- Only `podman --version`, `podman machine list` and `podman system connection list` work without
  a running machine. Everything else asks the server in the machine, so guard it on the machine
  being running (as `pod-ls` does) rather than printing connection errors.
- The file must work in both Windows PowerShell 5.1 and PowerShell 7. In 5.1, a UTF-8 BOM is
  prefixed to text piped to native commands unless the profile sets
  `[Console]::InputEncoding` to UTF-8 without a BOM. That fix belongs in the user's profile
  (documented in the file header and README), not in the helpers. Also in 5.1, `ConvertFrom-Json`
  outputs a JSON array as a single object, so assign it to a variable rather than piping it.
- Don't print the SSH identity path from `podman system connection list` or `podman machine list`:
  it contains the Windows username.
- Each function has a short comment above it explaining *why* where it's not obvious. Match
  that density.

## README

The README's function table and example screenshots (`pod-test.png`, `pod-ls.png`) document
the helpers. When adding, renaming or changing a function, update the table in the same change.
Screenshots must be cropped to the output, with no prompt, username or local paths.

## PLAN.md

When a phase is finished, update the progress tracker row (status, dates, notes) and the
**Status** row at the top. If a lesson's command is built into a helper, add a line to the
lesson saying where the helper shows it.

## .gitignore

Already set up for container work: `.env*` (except `.env.example`), keys, `data/` and
`volumes/` for bind-mounted volume data, and `*.tar` for `podman save` archives. Put
experiment data in those paths rather than committing it.
