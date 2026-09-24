# podman

Personal notes and experiments for learning [Podman](https://podman.io/) and containers, plus
some PowerShell helper functions for everyday Podman use on Windows.

## Requirements

- [Podman](https://podman.io/docs/installation) with a Podman machine (`podman machine init`)
- [lolcatjs](https://www.npmjs.com/package/lolcatjs) for the rainbow output: `npm install -g lolcatjs`

## PowerShell helpers

[`PodmanHelpers.ps1`](PodmanHelpers.ps1) defines these functions:

| Function | What it does |
|---|---|
| `pod_start` | Start the Podman machine |
| `pod_end` | Stop the Podman machine |
| `pod_run <image>` | Run an image once and remove the container afterwards (`podman run --rm`) |
| `pod_test` | Check Podman works by running `quay.io/podman/hello` |
| `pod_ls` | List all containers (running and stopped), images and volumes in a box |

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
pod_start
pod_test
pod_ls
pod_end
```

## Licence

[MIT](LICENSE)
