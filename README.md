# podman

Personal notes and experiments for learning [Podman](https://podman.io/) and containers, plus
some PowerShell helper functions for everyday Podman use on Windows.

[`PLAN.md`](PLAN.md) is the step-by-step plan for learning Podman, with labs and a progress tracker.
It was prepared with AI; see [How AI is used in this project](#how-ai-is-used-in-this-project).

## Requirements

- [Podman](https://podman.io/docs/installation) with a Podman machine (`podman machine init`)
- [lolcatjs](https://www.npmjs.com/package/lolcatjs) for the rainbow output: `npm install -g lolcatjs`

## PowerShell helpers

[`PodmanHelpers.ps1`](PodmanHelpers.ps1) defines these functions:

| Function | What it does |
|---|---|
| `pod-start` | Start the Podman machine |
| `pod-end` | Stop the Podman machine |
| `pod-run <image> [command...]` | Run an image once, optionally with a command, and remove the container afterwards (`podman run --rm`) |
| `pod-test` | Check Podman works by running `quay.io/podman/hello` |
| `pod-test-2` | Show the Alpine image's release with `cat /etc/os-release` |
| `pod-ls` | Show the Podman client/server versions, the machine's kernel and OCI runtime, and connections (rootless or rootful, and which is the default), and list Podman machines, all containers (running and stopped), images and volumes in a box |

### Setup

Dot-source the file from your PowerShell profile (`notepad $PROFILE`):

```powershell
. <path-to-this-repo>\PodmanHelpers.ps1
```

In Windows PowerShell 5.1, also add this line to your profile, or a UTF-8 BOM is prefixed to
text piped into lolcatjs:

```powershell
if ([Console]::InputEncoding.GetPreamble().Length) { [Console]::InputEncoding = [Text.UTF8Encoding]::new($false) }
```

Open a new PowerShell window, then try it:

```powershell
pod-start
pod-test
pod-ls
pod-end
```

### Example output

`pod-test`:

![pod-test output: the Podman hello image's ASCII-art seals and project links in rainbow colours](pod-test.png)

`pod-ls`:

![pod-ls output: client, server, kernel and runtime versions, then connections, machines, containers, images and volumes, in a rainbow box](pod-ls.png)

## How AI is used in this project

This is a learning project, so the learning is done by me. An AI coding assistant
([Claude Code](https://claude.com/claude-code)) helps in three ways.

The AI:

- Prepared the learning plan in [`PLAN.md`](PLAN.md), and updates it when I ask.
- Gives advice and explanations when I ask, such as what a lesson is showing or which naming
  convention is usual.
- Writes and changes the PowerShell in [`PodmanHelpers.ps1`](PodmanHelpers.ps1) when I ask, such
  as a new function I think is necessary.

I:

- Follow the lessons and run the **Try** commands.
- Decide what functionality the helpers need.
- Run the functions, check the results and take the screenshots.

Because the AI acts as my teacher and assistant throughout, most commits are made with its help.
They aren't marked individually; this section covers the whole history. The instructions the
AI follows in this repo are in [`AGENTS.md`](AGENTS.md).

## Licence

[MIT](LICENSE)
