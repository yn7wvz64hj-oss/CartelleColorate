param([Parameter(Mandatory=$true)][string]$Package)
$ErrorActionPreference='Stop'
$Package=(Resolve-Path -LiteralPath $Package).Path
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'This installation test requires the isolated GitHub runner.' }
$previousLocal=$env:LOCALAPPDATA; $case=Join-Path $Package ('test-data/auto-install-'+[Guid]::NewGuid().ToString('N')); $environment=Join-Path $case 'local'; $installed=Join-Path $environment 'CartelleColorate'; [IO.Directory]::CreateDirectory($installed)|Out-Null
$env:LOCALAPPDATA=$environment; $ps=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
try {
    & $ps -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File (Join-Path $Package 'Setup.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Initial isolated installation failed.' }
    [IO.File]::WriteAllText((Join-Path $installed 'VERSION'),'1.2.0')
    $palette='[{"Name":"Personal 日本語","Hex":"#123456","Favorite":false,"Group":""}]'; $settings='{"language":"it","appearance":"MacOS","theme":"Light","custom":"keep"}'
    [IO.File]::WriteAllText((Join-Path $installed 'colori.json'),$palette,[Text.UTF8Encoding]::new($true)); [IO.File]::WriteAllText((Join-Path $installed 'impostazioni.json'),$settings,[Text.UTF8Encoding]::new($true))
    $beforePalette=[IO.File]::ReadAllBytes((Join-Path $installed 'colori.json')); $beforeSettings=[IO.File]::ReadAllBytes((Join-Path $installed 'impostazioni.json'))
    $parent=Start-Process -FilePath $ps -ArgumentList '-NoProfile -NonInteractive -WindowStyle Hidden -Command "Start-Sleep -Seconds 2"' -WindowStyle Hidden -PassThru
    $state=Join-Path $installed 'updates/ci-status.json'; [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($state))|Out-Null
    $request=Join-Path $case 'request.json'; $version=[IO.File]::ReadAllText((Join-Path $Package 'VERSION')).Trim(); [IO.File]::WriteAllText($request,([pscustomobject]@{Parent=$parent.Id;Folder=$case;Version=$version;State=$state} | ConvertTo-Json),[Text.UTF8Encoding]::new($true))
    $process=Start-Process -FilePath $ps -ArgumentList ('-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $Package 'AutoUpdate.ps1')+'" -Request "'+$request+'" -NoRestart') -WindowStyle Hidden -PassThru
    if (!$process.WaitForExit(90000)) { throw 'Automatic updater did not complete.' }
    if ($process.ExitCode -ne 0 -or ![IO.File]::Exists($state) -or (([IO.File]::ReadAllText($state) | ConvertFrom-Json).Status) -ne 'Complete') { foreach ($log in @('update-error.log','install-error.log','install.log')) { $path=Join-Path $Package $log; if ([IO.File]::Exists($path)) { Write-Output ([IO.File]::ReadAllText($path)) } }; throw 'Automatic update failed.' }
    if ([IO.File]::ReadAllText((Join-Path $installed 'VERSION')).Trim() -cne $version -or [Convert]::ToBase64String($beforePalette) -cne [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $installed 'colori.json'))) -or [Convert]::ToBase64String($beforeSettings) -cne [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $installed 'impostazioni.json')))) { throw 'Update lost preferences or palette.' }
    Write-Output 'OK: aggiornamento reale silenzioso tramite app, attesa della chiusura, installer automatico e dati personali conservati.'
} finally {
    try { & $ps -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File (Join-Path $Package 'Setup.ps1') -Remove } finally { $env:LOCALAPPDATA=$previousLocal }
}
