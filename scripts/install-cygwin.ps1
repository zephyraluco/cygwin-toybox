[CmdletBinding()]
param(
    [string]$Root = 'C:\cygwin',
    [string]$Mirror = 'https://mirrors.kernel.org/sourceware/cygwin/',
    [string]$Cache = (Join-Path $env:TEMP 'cygwin-packages')
)

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) {
    throw 'Run this script with PowerShell 7 on Windows.'
}

$installer = Join-Path $Cache 'setup-x86_64.exe'
New-Item -ItemType Directory -Path $Cache -Force | Out-Null
Invoke-WebRequest -Uri 'https://cygwin.com/setup-x86_64.exe' -OutFile $installer

$pkgs = 'bash,cygwin,ncurses,terminfo,base-files,tzdata,zsh,libssl3'
# -B avoids elevation; the installation belongs to the current user.
$setupArguments = @('-q', '-B', '-n', '-R', ('"{0}"' -f $Root), '-s', ('"{0}"' -f $Mirror), '-P', $pkgs, '-l', ('"{0}"' -f $Cache))
$setup = Start-Process -FilePath $installer -ArgumentList $setupArguments -Wait -PassThru
if ($setup.ExitCode -ne 0) {
    throw "Cygwin setup failed with exit code $($setup.ExitCode)"
}

# Exercise the installed runtime and requested shells before packaging.
& (Join-Path $Root 'bin\bash.exe') --login -c 'set -eu; report=$(cygcheck -c bash cygwin ncurses terminfo base-files tzdata zsh libssl3); printf "%s\n" "$report"; for pkg in bash cygwin ncurses terminfo base-files tzdata zsh libssl3; do printf "%s\n" "$report" | grep -Eq "^$pkg[[:space:]]+[^[:space:]]+[[:space:]]+OK$"; done; zsh -fc ''print -r -- cygwin-zsh-ok''; test -f /usr/bin/cygssl-3.dll; test -f /usr/share/zoneinfo/UTC'
if ($LASTEXITCODE -ne 0) {
    throw "Cygwin runtime validation failed with exit code $LASTEXITCODE"
}
