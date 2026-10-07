function Initialize-Transfer {
    if ('CartelleColorate.Transfer' -as [type]) { return }; Add-Type -AssemblyName System.Net.Http
    Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Transfer.cs'))) -ReferencedAssemblies @('System.dll','System.Core.dll','System.Net.Http.dll')
}
function Assert-UpdateDirectory([string]$Directory,[string]$Version) {
    $files=@{}; $manifest=Join-Path $Directory 'MANIFEST-SHA256.txt'
    foreach ($line in [IO.File]::ReadAllLines($manifest)) {
        if (!$line) { continue }; if ($line -notmatch '^([a-f0-9]{64})  ([A-Za-z0-9._-]+)$') { throw (T 'updateIntegrity') }; $hash=$Matches[1]; $name=$Matches[2]
        if ($files.ContainsKey($name) -or $name -in @('colori.json','impostazioni.json','sfondi.json','preset.json','recenti.json','raccolte.json')) { throw (T 'updateIntegrity') }
        $path=Join-Path $Directory $name; if ((Get-DataHash ([IO.File]::ReadAllBytes($path))) -cne $hash) { throw (T 'updateIntegrity') }; $files[$name]=$true
    }
    foreach ($required in @('VERSION','Setup.ps1','AutoUpdate.ps1','Avvio.vbs','CartelleColorate.ps1')) { if (!$files.ContainsKey($required)) { throw (T 'updateIntegrity') } }
    if ([IO.File]::ReadAllText((Join-Path $Directory 'VERSION')).Trim() -cne $Version) { throw (T 'updateIntegrity') }; return $files
}
function Invoke-AutoInstallCore([string]$Package,[string]$InstalledRoot,[string]$Version,[scriptblock]$Runner) {
    $files=Assert-UpdateDirectory $Package $Version; $previous=@{}; $backup=Join-Path $InstalledRoot ('updates/rollback-'+[Guid]::NewGuid().ToString('N')); [IO.Directory]::CreateDirectory($backup)|Out-Null
    foreach ($name in $files.Keys) { if ($name -eq 'VERSION' -or $name -in @('Languages.json','LauncherMessages.txt') -or [IO.Path]::GetExtension($name) -in @('.ps1','.cs','.dll','.vbs')) { $path=Join-Path $InstalledRoot $name; $previous[$name]=[IO.File]::Exists($path); if ($previous[$name]) { [IO.File]::Copy($path,(Join-Path $backup $name)) } } }
    try { $exit=& $Runner $Package $InstalledRoot; if ($exit -ne 0 -or [IO.File]::ReadAllText((Join-Path $InstalledRoot 'VERSION')).Trim() -cne $Version) { throw (T 'updateError') } }
    catch {
        $failure=$_; $restored=$false
        try { foreach ($name in $previous.Keys) { $path=Join-Path $InstalledRoot $name; if ($previous[$name]) { [IO.File]::Copy((Join-Path $backup $name),$path,$true) } elseif ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }; $restored=$true } catch { }
        $failure.Exception.Data['Restored']=$restored; throw $failure
    }
}
function Start-AutoInstallation($Context) {
    $directory=[IO.Path]::GetDirectoryName($Context.Installer); Assert-UpdateDirectory $directory $Context.Offer.Version|Out-Null
    $state=Join-Path $root ('updates/status-'+[Guid]::NewGuid().ToString('N')+'.json'); $request=Join-Path $directory 'resume.json'
    $folder=$script:currentFolder; if (![IO.Directory]::Exists($folder)) { $folder=$root }
    Write-AdvancedJson $request ([pscustomobject]@{Parent=$PID;Folder=$folder;Version=$Context.Offer.Version;State=$state})
    $ps=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $arguments='-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $directory 'AutoUpdate.ps1')+'" -Request "'+$request+'"'
    $process=Start-Process -FilePath $ps -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $deadline=[DateTime]::UtcNow.AddSeconds(8)
    while (![IO.File]::Exists($state) -and !$process.HasExited -and [DateTime]::UtcNow -lt $deadline) { [Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Background); Start-Sleep -Milliseconds 40 }
    if (![IO.File]::Exists($state) -or $process.HasExited) { throw (T 'updateError') }
    $Context.Window.Close(); $window.Close()
}
function Set-DownloadProgress($Context) {
    if (!$Context.Transfer) { return }; $received=$Context.Transfer.Received; $total=$Context.Offer.Size; $percent=[Math]::Min(100,[Math]::Floor($received*100.0/$total)); $Context.Progress.Value=$percent
    $Context.ProgressText.Text=T 'downloadProgress' @($percent,[Math]::Round($received/1024.0,1),[Math]::Round($total/1024.0,1))
}
function Test-AutoUpdateBackend {
    Initialize-Transfer
    $case=Join-Path $root ('auto-update-'+[Guid]::NewGuid().ToString('N')); $package=Join-Path $case 'package'; $installed=Join-Path $case 'installed'; [IO.Directory]::CreateDirectory($package)|Out-Null; [IO.Directory]::CreateDirectory($installed)|Out-Null
    $files=@('VERSION','Setup.ps1','AutoUpdate.ps1','Avvio.vbs','CartelleColorate.ps1'); $manifest=@()
    foreach ($name in $files) { $content=if ($name -eq 'VERSION') { '99.0.0' } else { 'fixture' }; $path=Join-Path $package $name; [IO.File]::WriteAllText($path,$content); $manifest+=((Get-DataHash ([IO.File]::ReadAllBytes($path)))+'  '+$name) }; [IO.File]::WriteAllLines((Join-Path $package 'MANIFEST-SHA256.txt'),$manifest)
    [IO.File]::WriteAllText((Join-Path $installed 'VERSION'),'98.0.0'); [IO.File]::WriteAllText((Join-Path $installed 'CartelleColorate.ps1'),'old'); [IO.File]::WriteAllText((Join-Path $installed 'colori.json'),'personal palette')
    $failed=$false; try { Invoke-AutoInstallCore $package $installed '99.0.0' {param($p,$r) [IO.File]::WriteAllText((Join-Path $r 'CartelleColorate.ps1'),'partial'); 1} } catch { $failed=$true; if (!$_.Exception.Data['Restored']) { throw 'Rollback failed' } }
    if (!$failed -or [IO.File]::ReadAllText((Join-Path $installed 'CartelleColorate.ps1')) -ne 'old') { throw 'Failed update replaced previous version' }
    Invoke-AutoInstallCore $package $installed '99.0.0' {param($p,$r) foreach ($name in @('VERSION','CartelleColorate.ps1')) { [IO.File]::Copy((Join-Path $p $name),(Join-Path $r $name),$true) }; 0}
    if ([IO.File]::ReadAllText((Join-Path $installed 'colori.json')) -ne 'personal palette') { throw 'Update changed user data' }
    [IO.File]::AppendAllText((Join-Path $package 'Setup.ps1'),'tampered'); $failed=$false; try { Assert-UpdateDirectory $package '99.0.0'|Out-Null } catch { $failed=$true }; if (!$failed) { throw 'Changed extracted package accepted' }
    Write-Output 'OK: aggiornamento automatico con rollback, dati personali conservati e nuova verifica prima di installare.'
}
