param([switch]$Remove,[switch]$ValidateOnly)
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:LOCALAPPDATA 'CartelleColorate'
. (Join-Path $PSScriptRoot 'Localization.ps1')
Initialize-Language $root
try {
    if (!$Remove) {
        foreach ($file in @('CartelleColorate.ps1','Advanced.ps1','Productivity.ps1','Enhancements.ps1','Visuals.ps1','Experience.ps1','AutoUpdates.ps1','AutoUpdate.ps1','Transfer.cs','VERSION','Interfaccia.ps1','Avvio.vbs','Rapido.vbs','FolderShell.dll','DesktopPicker.dll','Verifica.vbs','Avvio.ps1','NativeLibraries.ps1','FolderShell.cs','DesktopPicker.cs','Localization.ps1','Languages.json','LauncherMessages.txt')) {
            if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $file))) { throw (T 'missingFiles' @($file)) }
        }
        $checkHost=Join-Path $env:SystemRoot 'System32\cscript.exe'
        & $checkHost '//B' '//Nologo' (Join-Path $PSScriptRoot 'Verifica.vbs')
        if ($LASTEXITCODE -ne 0) { throw (T 'hostMissing') }
        if ($ValidateOnly) { Write-Host (T 'packageOK'); exit }
    }
    $root = Join-Path $env:LOCALAPPDATA 'CartelleColorate'
    $key = 'HKCU:\Software\Classes\Directory\shell\CartelleColorate'
    $stop=Join-Path $root 'worker.stop'; $heartbeat=Join-Path $root 'worker.attivo'
    if (Test-Path -LiteralPath $root) {
        if ((Test-Path -LiteralPath $heartbeat) -and ([DateTime]::Now-(Get-Item -LiteralPath $heartbeat).LastWriteTime).TotalSeconds -gt 8) { [IO.File]::Delete($heartbeat) }
        [IO.File]::WriteAllText($stop,'stop')
        $deadline=[DateTime]::UtcNow.AddSeconds(5)
        while ((Test-Path -LiteralPath $heartbeat) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
        if (Test-Path -LiteralPath $heartbeat) { throw (T 'workerBusy') }
        if (Test-Path -LiteralPath $stop) { [IO.File]::Delete($stop) }
    }
    if ($Remove) {
        if (Test-Path $key) { Remove-Item -LiteralPath $key -Recurse }
        $store='HKCU:\Software\Classes\CartelleColorate.Menu'
        if (Test-Path $store) { Remove-Item -LiteralPath $store -Recurse }
        $presetStore='HKCU:\Software\Classes\CartelleColorate.Presets'; if (Test-Path -LiteralPath $presetStore) { Remove-Item -LiteralPath $presetStore -Recurse }
        Write-Host (T 'removed')
    } else {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'CartelleColorate.ps1') -Destination $root -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Advanced.ps1') -Destination $root -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Productivity.ps1') -Destination $root -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Enhancements.ps1') -Destination $root -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Visuals.ps1') -Destination $root -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Experience.ps1') -Destination $root -Force
        foreach ($file in @('AutoUpdates.ps1','AutoUpdate.ps1','Transfer.cs')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $root -Force }
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'VERSION') -Destination $root -Force
          Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Interfaccia.ps1') -Destination $root -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Avvio.vbs') -Destination $root -Force
        . (Join-Path $PSScriptRoot 'NativeLibraries.ps1')
        Install-NativeLibraries $PSScriptRoot $root
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Avvio.ps1') -Destination $root -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rapido.vbs') -Destination $root -Force
        foreach ($file in @('Localization.ps1','Languages.json','LauncherMessages.txt')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $root -Force }
        & (Join-Path $root 'CartelleColorate.ps1') -RefreshMenu
        $ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        Start-Process -FilePath $ps -ArgumentList ('-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Worker' -f (Join-Path $root 'CartelleColorate.ps1')) -WindowStyle Hidden
        Write-Host (T 'installed')
    }
} catch { Write-Host $_.Exception.Message; exit 1 }
