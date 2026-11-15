# Windows PowerShell entry point for examples/run.sh.
#
# On many Windows machines `bash` resolves to C:\Windows\System32\bash.exe
# (the WSL launcher), which fails with "WSL has no installed distributions".
# This thin wrapper locates a real Git Bash and forwards every argument.
#
#   powershell -ExecutionPolicy Bypass -File examples/run.ps1 -Fetch "https://example.com/a"
#   powershell -ExecutionPolicy Bypass -File examples/run.ps1
#   powershell -ExecutionPolicy Bypass -File examples/run.ps1 -Html my.html
#   powershell -ExecutionPolicy Bypass -File examples/run.ps1 --fetch "https://example.com/a"
#
# All work is still done by run.sh; this script only fixes the bash lookup.

[CmdletBinding()]
param(
    [string] $Fetch,
    [string] $Html,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Forward
)

$ErrorActionPreference = 'Stop'

$candidates = @()
if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles 'Git\bin\bash.exe') }
$pf86 = ${env:ProgramFiles(x86)}
if ($pf86) { $candidates += (Join-Path $pf86 'Git\bin\bash.exe') }
if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe') }

$bash = $null
foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { $bash = $c; break }
}
if (-not $bash) {
    $cmd = Get-Command bash.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and $cmd.Source -notmatch '\\(System32|WindowsApps)\\bash\.exe$') {
        $bash = $cmd.Source
    }
}
if (-not $bash) {
    Write-Host 'ERROR: no usable Bash found.' -ForegroundColor Red
    Write-Host 'Install Git for Windows (https://git-scm.com/download/win), or call Git Bash directly:'
    Write-Host '  & "C:\Program Files\Git\bin\bash.exe" examples/run.sh --fetch "URL"'
    exit 1
}

$argList = @('examples/run.sh')
if ($Fetch) { $argList += @('--fetch', $Fetch) }
if ($Html) { $argList += $Html }
if ($Forward) { $argList += $Forward }

Write-Host "Using Bash: $bash"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    & $bash $argList
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($null -ne $code -and $code -ne 0) { exit $code }
