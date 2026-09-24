# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal repo for learning Podman on Windows: notes and experiments, plus `PodmanHelpers.ps1`,
a set of PowerShell functions (`pod_start`, `pod_end`, `pod_run`, `pod_test`, `pod_test_2`,
`pod_ls`) that users dot-source from their `$PROFILE`. There is no build, test suite or linter.
It may be published, so keep it free of employer names, customer data and PII.

## Trying changes

Reload the helpers in the current session and run them. Podman needs a running machine, so start
it first:

```powershell
. .\PodmanHelpers.ps1
pod_start
pod_test      # runs quay.io/podman/hello
pod_ls
pod_end
```

Output is piped through `lolcatjs` (`npm install -g lolcatjs`), which must be on PATH.

## Conventions in PodmanHelpers.ps1

- **The rainbow-output pattern:** podman output is captured with `2>&1` (so warnings show too),
  each line is turned into a string with `ForEach-Object { "$_" }`, and the lines are joined with
  `` "`n" `` (LF only) before being piped to `lolcatjs`. CRs make lolcatjs add a blank line after
  every line. New functions that print podman output should follow this pattern.
- `pod_run` reads `$args` rather than a `param()` block on purpose, so options meant for the
  container (`-la`, `-i`, `-o`) aren't bound by PowerShell as parameters of `pod_run`. Wrap it
  (like `pod_test`) rather than duplicating `podman run --rm` logic.
- The file must work in both Windows PowerShell 5.1 and PowerShell 7. In 5.1, a UTF-8 BOM is
  prefixed to text piped to native commands unless the profile sets
  `[Console]::InputEncoding` to UTF-8 without a BOM. That fix belongs in the user's profile
  (documented in the file header and README), not in the helpers.
- Each function has a short comment above it explaining *why* where it's not obvious. Match
  that density.

## README

The README's function table and example screenshots (`pod_test.png`, `pod_ls.png`) document
the helpers. When adding, renaming or changing a function, update the table in the same change.

## .gitignore

Already set up for container work: `.env*` (except `.env.example`), keys, `data/` and
`volumes/` for bind-mounted volume data, and `*.tar` for `podman save` archives. Put
experiment data in those paths rather than committing it.
