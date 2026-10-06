param([Parameter(Mandatory=$true)][string]$Package,[Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$testRoot=Join-Path $OutputDirectory ('dl-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
Get-ChildItem -LiteralPath $Package -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $testRoot }
foreach ($name in @('FolderShell','DesktopPicker')) {
    Set-Content -LiteralPath (Join-Path $testRoot ($name+'.dll')) -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3" -Encoding ASCII
}
$ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$log=Join-Path $testRoot 'before.txt'
& $ps -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $testRoot 'Avvio.ps1') -Folder $testRoot -NoConsoleTest > $log 2>&1
if ($LASTEXITCODE -eq 0 -or !(Test-Path -LiteralPath (Join-Path $testRoot 'avvio-errore.log'))) { throw 'Errore di avvio non rilevato o non registrato.' }
if (!(Get-Content -LiteralPath $log -Raw).Contains('0x80131515')) { throw 'Il test non riproduce il blocco delle DLL scaricate.' }
. (Join-Path $testRoot 'NativeLibraries.ps1')
Install-NativeLibraries $testRoot $testRoot
foreach ($name in @('FolderShell','DesktopPicker')) {
    if (Get-Item -LiteralPath (Join-Path $testRoot ($name+'.dll')) -Stream Zone.Identifier -ErrorAction SilentlyContinue) { throw ('DLL locale ancora marcata come download: '+$name) }
}
$verify=Join-Path $testRoot 'verify-native.ps1'
[IO.File]::WriteAllText($verify,"`$ErrorActionPreference='Stop'`r`nAdd-Type -Path (Join-Path `$PSScriptRoot 'FolderShell.dll')`r`nAdd-Type -Path (Join-Path `$PSScriptRoot 'DesktopPicker.dll')`r`n'OK: DLL locali caricabili'",[Text.Encoding]::UTF8)
& $ps -NoProfile -STA -ExecutionPolicy Bypass -File $verify
if ($LASTEXITCODE -ne 0) { throw 'DLL generate sul PC non caricabili.' }
Write-Output 'OK: riprodotto il blocco 0x80131515, errore di avvio registrato, DLL ricostruite localmente e caricate.'
