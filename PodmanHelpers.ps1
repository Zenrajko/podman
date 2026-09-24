#---------------------------------------------------------------------------------
# Podman helper functions for PowerShell
#---------------------------------------------------------------------------------
# Dot-source this file from your PowerShell profile:
#   . <path-to-this-repo>\PodmanHelpers.ps1
#
# Output is coloured with lolcatjs (npm install -g lolcatjs).
#
# In Windows PowerShell 5.1, set the console input encoding to UTF-8 without a BOM
# in your profile, or a BOM is prefixed to text piped into lolcatjs:
#   if ([Console]::InputEncoding.GetPreamble().Length) { [Console]::InputEncoding = [Text.UTF8Encoding]::new($false) }
#---------------------------------------------------------------------------------

# Start/stop the Podman machine, in rainbow. 2>&1 includes podman's warnings, and
# lines are joined with LF only, as CRs make lolcatjs add a blank line after each line
function pod-start { (podman machine start 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs }
function pod-end   { (podman machine stop 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs }

# Run an image once and remove its container afterwards, in rainbow. Anything after the
# image is passed to the container as its command, e.g.
#   pod-run quay.io/podman/hello
#   pod-run docker.io/library/alpine ls -la /
# Uses $args rather than a param block, so options meant for the container (-la, -i, -o)
# aren't taken by PowerShell as parameters of pod-run
function pod-run {
    if (-not $args) { Write-Error "Usage: pod-run <image> [command [args...]]"; return }
    $image   = $args[0]
    $command = @($args | Select-Object -Skip 1)
    (podman run --rm $image @command 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
}

# Quick check that Podman works
function pod-test { pod-run quay.io/podman/hello }

# Show which Linux release the Alpine image is
function pod-test-2 { pod-run docker.io/library/alpine cat /etc/os-release }

# List the Podman client/server versions, the machine's kernel and OCI runtime, connections,
# machines, all containers (running and stopped), images and volumes, in rainbow. The client
# (Windows) and server (in the machine) are upgraded separately, so their versions can differ
function pod-ls {
    # Run podman with warnings and errors included as plain lines, so they land inside the box
    function podlines { podman @args 2>&1 | ForEach-Object { "$_" } }

    # Only connections and machines are read from config on Windows; everything else asks the
    # server in the machine, and fails if it isn't running. Not piped, as ConvertFrom-Json in
    # 5.1 outputs a JSON array as a single object
    $machines = podman machine list --format json | ConvertFrom-Json
    $running  = $machines.Running -contains $true

    $out = & {
        # podman --version is local; podman version fails entirely without a server
        $client = "Client " + ((podman --version) -split " ")[-1]
        if ($running) {
            # One podman info call gives the server version, the kernel and the OCI runtime.
            # Containers share the machine's kernel, so this is the kernel they all run on. The
            # runtime (crun or runc) is what actually creates each container for Podman
            "$client | " + ((podlines info --format "Server {{.Version.Version}} {{.Version.OsArch}} | Kernel {{.Host.Kernel}} ({{.Host.Distribution.Distribution}} {{.Host.Distribution.Version}}) | Runtime {{.Host.OCIRuntime.Name}}") -join "`n")
        } else {
            "$client | Server (machine not running)"
        }
        ""
        # Each machine has a rootless and a rootful connection; the default one is the server
        # above. Rootful is when the SSH user in the URI is root. Identity is left out, as it's
        # a long path to the SSH key
        "--- CONNECTIONS ---"
        $conns = podman system connection list --format json | ConvertFrom-Json
        $nameWidth = ($conns.Name + "NAME" | Measure-Object -Property Length -Maximum).Maximum
        "{0}  {1}  {2}  {3}" -f "NAME".PadRight($nameWidth), "MODE    ", "DEFAULT", "URI"
        foreach ($c in $conns) {
            $mode = if (([uri]$c.URI).UserInfo -eq "root") { "rootful " } else { "rootless" }
            $default = if ($c.Default) { "yes    " } else { "       " }
            "{0}  {1}  {2}  {3}" -f $c.Name.PadRight($nameWidth), $mode, $default, $c.URI
        }
        ""
        "--- MACHINES ---"
        podlines machine list
        ""
        if ($running) {
            "--- CONTAINERS ---"
            podlines ps -a
            ""
            "--- IMAGES ---"
            podlines images
            ""
            "--- VOLUMES ---"
            podlines volume ls
        } else {
            "Machine not running - run pod-start to see containers, images and volumes"
        }
    } | Out-String
    # Draw a +---+ border around the output
    $lines = ($out -replace "`r", "").TrimEnd() -split "`n" | ForEach-Object { $_.TrimEnd() }
    $width = ($lines | Measure-Object -Property Length -Maximum).Maximum
    $edge  = "+" + ("-" * ($width + 2)) + "+"
    $boxed = @($edge) + ($lines | ForEach-Object { "| " + $_.PadRight($width) + " |" }) + @($edge)
    ""
    # Join with LF only, as CRs make lolcatjs add a blank line after each line
    $boxed -join "`n" | lolcatjs
}
