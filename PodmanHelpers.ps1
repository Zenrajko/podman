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
function pod-sys-start { (podman machine start 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs }
function pod-sys-stop  { (podman machine stop 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs }

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

# Start a container in the background, then show the container list so the user sees
# it start, in rainbow. With no image, the name is an existing (stopped) container to start
function pod-start {
    param ([Parameter(Mandatory)][string]$Name, [string]$Image)

    if ($Image) {
        (podman run -d --name $Name $Image 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
    } else {
        # podman container exists prints nothing, so test its exit code rather than output
        podman container exists $Name 2>$null
        if ($LASTEXITCODE -eq 0) {
            (podman start $Name 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
        } else {
            Write-Error "No container named '$Name' and no image given. Usage: pod-start <name> <image>, or pod-start <name> to start an existing container"
        }
    }
    (podman ps -a 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
}

# Stop a container, then list containers, so the user sees it stopped
function pod-stop {
    param ([Parameter(Mandatory)][string]$Name)
    (podman stop $Name 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
    (podman ps -a 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
}

# Remove a container, but not if it's running, then show the container list so the user
# sees it removed
function pod-rm-con {
    param ([Parameter(Mandatory)][string]$Name)
    (podman rm $Name 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
    (podman ps -a 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
}

# Remove an image, but not if it's being used, then show the image list so the user sees
# it removed
function pod-rm-img {
    param ([Parameter(Mandatory)][string]$Name)
    (podman rmi $Name 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
    (podman images 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
}

# Show a container's processes (top output)
function pod-proc {
    param ([Parameter(Mandatory)][string]$Name)
    (podman top $Name 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
}

# Show a container's full details
function pod-show {
    param ([Parameter(Mandatory)][string]$Name)
    (podman inspect $Name 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
}

# Follow a container's logs
function pod-log {
    param ([Parameter(Mandatory)][string]$Name)
    (podman logs -f $Name 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
}

# List images with their digests, in rainbow
function pod-digest { (podman images --digests 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs }

# Show an image's history of layers, in rainbow
function pod-hist { (podman history $args 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs }

# Open an interactive shell in a container, running and removing it afterwards. Runs unbuffered
# (not via lolcatjs), as piping an interactive session through the rainbow would break it
function pod-open {
    param ([Parameter(Mandatory)][string]$Image, [string]$Shell = "sh")
    "Running image '$Image' with shell '$Shell'. Type 'exit' to quit." | lolcatjs
    podman run -it --rm "$Image" "$Shell"
}

# Run a command in a running container's terminal. Interactive, so unbuffered like pod-open
function pod-exec {
    if ($args.Count -lt 2) { Write-Error "Usage: pod-exec <name> <command> [args...]"; return }
    $name = $args[0]
    $command = @($args | Select-Object -Skip 1)
    podman exec -it $name @command
}

# Open a shell in a running container
function pod-edit {
    param ([Parameter(Mandatory)][string]$Name)
    pod-exec $Name sh
}

# Open the Alpine image's sh shell
function pod-alp { pod-open docker.io/library/alpine sh }

# Start an nginx Alpine container in the background
function pod-start-nginx {
    param ([Parameter(Mandatory)][string]$Name)
    pod-start $Name docker.io/library/nginx:alpine
}

# Start an Alpine container in the background, kept alive with sleep infinity, then show
# the container list. Plain alpine has no process to run, so it would exit immediately otherwise
function pod-start-alp {
    param ([Parameter(Mandatory)][string]$Name)
    (podman run -d --name $Name docker.io/library/alpine sleep infinity 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
    (podman ps -a 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
}

# Open the nginx Alpine image's sh shell
function pod-nginx { pod-open docker.io/library/nginx:alpine sh }

# Quick check that Podman works
function pod-test { pod-run quay.io/podman/hello }

# Show which Linux release the Alpine image is
function pod-test-alp { pod-run docker.io/library/alpine cat /etc/os-release }

# Show which Linux release the nginx Alpine image is
function pod-test-nginx { pod-run docker.io/library/nginx:alpine cat /etc/os-release }

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
            "--- STATS ---"
            podlines stats --no-stream
            ""
            "--- IMAGES ---"
            podlines images
            ""
            "--- VOLUMES ---"
            podlines volume ls
            ""
            "--- DISK USAGE ---"
            podlines system df
        } else {
            "Machine not running - run pod-sys-start to see containers, images and volumes"
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

# Return list of podman aliases, optionally filtered
function pod-alias {
    param ([string]$Filter)

    $list = podman machine ssh cat /etc/containers/registries.conf.d/000-shortnames.conf

    if ($null -eq $Filter) {
        return $list
    } else {
        return $list.Where({ $_ -like "*$Filter*" })
    }
}

# List every pod-* helper with a one-line description, grouped by what it does, in a rainbow
# box. Written out rather than gathered from Get-Command, so it shows exactly what the file
# defines. The descriptions are what this file does, so it stays in sync with the README table
function pod-help {
    $help = [ordered]@{
        "MACHINE" = [ordered]@{
            "pod-sys-start" = "Start the Podman machine"
            "pod-sys-stop"  = "Stop the Podman machine"
        }
        "RUN" = [ordered]@{
            "pod-run <image> [cmd...]"  = "Run an image once, then remove the container"
            "pod-start <name> [image]" = "Start a container, or an existing one by name only"
            "pod-start-nginx <name>" = "Start an nginx Alpine container in the background"
            "pod-start-alp <name>"  = "Start an Alpine container, kept running with sleep infinity"
            "pod-stop <name>"       = "Stop a container keeping it, then list containers"
            "pod-rm-con <name>"     = "Remove a container, then list containers"
            "pod-rm-img <name>"     = "Remove an image, then list images"
            "pod-proc <name>"       = "Show a container's processes"
            "pod-show <name>"       = "Inspect a container's full details"
            "pod-log <name>"        = "Follow a container's logs"
            "pod-open <image> [shell]" = "Open an interactive shell, default 'sh'"
            "pod-exec <name> <cmd>"   = "Run a command in a running container"
            "pod-edit <name>"       = "Open a shell in a running container"
            "pod-alp"                  = "Open the Alpine image's sh shell"
            "pod-nginx"                = "Open the nginx Alpine image's sh shell"
            "pod-test"                 = "Check Podman works (quay.io/podman/hello)"
            "pod-test-alp"             = "Show the Alpine image's release"
            "pod-test-nginx"           = "Show the nginx Alpine image's release"
        }
        "IMAGES" = [ordered]@{
            "pod-digest"      = "List images with their digests"
            "pod-hist <image>" = "Show an image's layer history"
        }
        "INFO" = [ordered]@{
            "pod-ls"             = "Dashboard: versions, connections, machines, containers, images and volumes"
            "pod-alias [filter]" = "List short-name aliases, optionally filtered"
            "pod-help"           = "Show this list of helpers"
        }
    }

    # Align names across all sections into one column, then draw a +---+ border around the list
    $nameWidth = 0
    foreach ($names in $help.Values) {
        $nameWidth = [Math]::Max($nameWidth, ($names.Keys | Measure-Object -Property Length -Maximum).Maximum)
    }
    $lines = & {
        foreach ($section in $help.Keys) {
            "--- $section ---"
            foreach ($name in $help[$section].Keys) {
                "{0}  {1}" -f $name.PadRight($nameWidth), $help[$section][$name]
            }
            ""
        }
    }
    $width = ($lines | Measure-Object -Property Length -Maximum).Maximum
    $edge  = "+" + ("-" * ($width + 2)) + "+"
    $boxed = @($edge) + ($lines | ForEach-Object { "| " + $_.PadRight($width) + " |" }) + @($edge)
    # Join with LF only, as CRs make lolcatjs add a blank line after each line
    $boxed -join "`n" | lolcatjs
}
