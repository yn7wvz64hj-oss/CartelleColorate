param([switch]$Remove,[switch]$ValidateOnly)
$ErrorActionPreference = 'Stop'
try {
    if (!$Remove) {
        foreach ($file in @('CartelleColorate.ps1','Interfaccia.ps1','Avvio.vbs','Rapido.vbs','FolderShell.dll','DesktopPicker.dll','Verifica.vbs')) {
            if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $file))) { throw ('File mancante: '+$file+'. Estrai tutto lo ZIP prima di installare.') }
        }
        $checkHost=Join-Path $env:SystemRoot 'System32\cscript.exe'
        & $checkHost '//B' '//Nologo' (Join-Path $PSScriptRoot 'Verifica.vbs')
        if ($LASTEXITCODE -ne 0) { throw 'Windows Script Host o VBScript non sono disponibili. Questo pacchetto richiede entrambi.' }
        if ($ValidateOnly) { Write-Host 'OK: pacchetto completo e VBScript disponibile.'; exit }
    }
    $root = Join-Path $env:LOCALAPPDATA 'CartelleColorate'
    $key = 'HKCU:\Software\Classes\Directory\shell\CartelleColorate'
    $stop=Join-Path $root 'worker.stop'; $heartbeat=Join-Path $root 'worker.attivo'
    if (Test-Path -LiteralPath $root) {
        if ((Test-Path -LiteralPath $heartbeat) -and ([DateTime]::Now-(Get-Item -LiteralPath $heartbeat).LastWriteTime).TotalSeconds -gt 8) { [IO.File]::Delete($heartbeat) }
        [IO.File]::WriteAllText($stop,'stop')
        $deadline=[DateTime]::UtcNow.AddSeconds(5)
        while ((Test-Path -LiteralPath $heartbeat) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
        if (Test-Path -LiteralPath $heartbeat) { throw 'Chiudi CartelleColorate e riprova: il processo precedente e ancora attivo.' }
        if (Test-Path -LiteralPath $stop) { [IO.File]::Delete($stop) }
    }
    if ($Remove) {
        if (Test-Path $key) { Remove-Item -LiteralPath $key -Recurse }
        $store='HKCU:\Software\Classes\CartelleColorate.Menu'
        if (Test-Path $store) { Remove-Item -LiteralPath $store -Recurse }
        Write-Host 'Menu rimosso. Colori, icone e backup conservati per consentire il ripristino.'
    } else {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'CartelleColorate.ps1') -Destination $root -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Interfaccia.ps1') -Destination $root -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Avvio.vbs') -Destination $root -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'FolderShell.dll') -Destination $root -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'DesktopPicker.dll') -Destination $root -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rapido.vbs') -Destination $root -Force
        & (Join-Path $root 'CartelleColorate.ps1') -RefreshMenu
        $ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        Start-Process -FilePath $ps -ArgumentList ('-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Worker' -f (Join-Path $root 'CartelleColorate.ps1')) -WindowStyle Hidden
        Write-Host 'Installato. Tasto destro su una cartella > Mostra altre opzioni > Cambia colore.'
    }
} catch { Write-Host $_.Exception.Message; exit 1 }
