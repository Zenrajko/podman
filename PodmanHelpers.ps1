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
function pod_start { (podman machine start 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs }
function pod_end   { (podman machine stop 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs }

# Run an image once and remove its container afterwards, in rainbow, e.g. pod_run quay.io/podman/hello
function pod_run {
    param([Parameter(Mandatory)][string]$Image)
    (podman run --rm $Image 2>&1 | ForEach-Object { "$_" }) -join "`n" | lolcatjs
}

# Quick check that Podman works
function pod_test { pod_run quay.io/podman/hello }

# List all containers (running and stopped), images and volumes, in rainbow
function pod_ls {
    $out = & {
        "--- CONTAINERS ---"
        podman ps -a
        ""
        "--- IMAGES ---"
        podman images
        ""
        "--- VOLUMES ---"
        podman volume ls
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
