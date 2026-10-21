$ErrorActionPreference = 'Stop'
$indexes = @(Get-ChildItem "$env:TEMP/cygwin-packages" -Recurse -Filter setup.ini | Where-Object { $_.Directory.Name -eq 'x86_64' })
if ($indexes.Count -ne 1) { throw 'Expected one verified Cygwin package index' }
$index = Get-Content $indexes[0].FullName -Raw
$packages = @{}
foreach ($match in [regex]::Matches($index, '(?m)^@ ([^\r\n]+)')) {
    $packages[$match.Groups[1].Value] = $true
}
$versions = @([regex]::Matches($index, '(?m)^@ python([0-9]+)-mako\r?$') | ForEach-Object { $_.Groups[1].Value } | Sort-Object { [int]$_ } -Descending)
$selected = $null
foreach ($version in $versions) {
    $required = @("python$version", "python$version-mako", "python$version-packaging", "python$version-ply", "python$version-pefile")
    if (@($required | Where-Object { -not $packages.ContainsKey($_) }).Count -eq 0) {
        $selected = $version
        break
    }
}
if (-not $selected) { throw "No Cygwin Python version provides all Mesa modules; Mako versions: $versions" }
Write-Host "Selected official Cygwin Python packages: $($required -join ',')"
& "$PSScriptRoot/install-cygwin.ps1" -Root C:\cygwin-build -AdditionalPackages ($required -join ',')
$minor = $selected.Substring(1)
& C:\cygwin-build\bin\bash.exe --login -c "set -eu; mkdir -p /opt/mesa-python/bin; ln -sfn /usr/bin/python3.$minor.exe /opt/mesa-python/bin/python3; /opt/mesa-python/bin/python3 -c 'import sys, mako, packaging, ply, pefile; print(sys.version)'"
if ($LASTEXITCODE -ne 0) { throw 'Missing Mesa Python dependencies' }
