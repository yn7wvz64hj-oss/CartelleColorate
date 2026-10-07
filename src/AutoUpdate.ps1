param([Parameter(Mandatory=$true)][string]$Request,[switch]$NoRestart)
$ErrorActionPreference='Stop'
if ($NoRestart -and $env:GITHUB_ACTIONS -ne 'true') { throw 'NoRestart is restricted to the isolated CI test.' }
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
. (Join-Path $PSScriptRoot 'Localization.ps1')
$root=Join-Path $env:LOCALAPPDATA 'CartelleColorate'; Initialize-Language $root
. (Join-Path $PSScriptRoot 'Advanced.ps1')
$resume=[IO.File]::ReadAllText($Request) | ConvertFrom-Json
if ($resume.Version -notmatch '^\d+\.\d+\.\d+$' -or $resume.Parent -le 0 -or ![IO.Path]::GetFullPath($resume.State).StartsWith([IO.Path]::GetFullPath($root)+'\updates\',[StringComparison]::OrdinalIgnoreCase)) { throw (T 'updateIntegrity') }
Assert-UpdateDirectory $PSScriptRoot $resume.Version|Out-Null
Write-AdvancedJson $resume.State ([pscustomobject]@{Status='Ready';Version=$resume.Version})
try { $parent=[Diagnostics.Process]::GetProcessById([int]$resume.Parent); if (!$parent.WaitForExit(12000)) { throw (T 'updateError') } } catch [ArgumentException] { }
$window=[Windows.Window]::new(); $window.Title='CartelleColorate'; $window.Width=380; $window.Height=155; $window.ResizeMode='NoResize'; $window.WindowStartupLocation='CenterScreen'; $window.FontFamily='Segoe UI Variable, Segoe UI'; $window.FontSize=13
$window.Background=[Windows.Media.Brushes]::White; $window.Foreground=[Windows.Media.Brushes]::Black; $panel=[Windows.Controls.StackPanel]::new(); $panel.Margin=[Windows.Thickness]::new(22); $label=[Windows.Controls.TextBlock]::new(); $label.Text=T 'updateInstalling'; $label.TextWrapping='Wrap'; $panel.Children.Add($label)|Out-Null
$bar=[Windows.Controls.ProgressBar]::new(); $bar.Height=5; $bar.IsIndeterminate=$true; $bar.Margin=[Windows.Thickness]::new(0,18,0,0); $panel.Children.Add($bar)|Out-Null; $window.Content=$panel
$script:installComplete=$false; $window.Add_Closing({param($sender,$e) if (!$script:installComplete) { $e.Cancel=$true } })
$window.Show(); $window.UpdateLayout()
$runner={ param($package,$installedRoot)
    $ps=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'; $arguments='-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $package 'Setup.ps1')+'"'
    $child=Start-Process -FilePath $ps -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $package 'install.log') -RedirectStandardError (Join-Path $package 'install-error.log')
    while (!$child.HasExited) { [Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Background); Start-Sleep -Milliseconds 80 }; $child.WaitForExit(); return $child.ExitCode
}
try {
    Invoke-AutoInstallCore $PSScriptRoot $root $resume.Version $runner
    Write-AdvancedJson $resume.State ([pscustomobject]@{Status='Complete';Version=$resume.Version})
    $label.Text=T 'updateComplete'; $bar.IsIndeterminate=$false; $bar.Value=100; $window.UpdateLayout()
} catch {
    Write-AdvancedJson $resume.State ([pscustomobject]@{Status='Failed';Version=$resume.Version;Restored=[bool]$_.Exception.Data['Restored']})
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'update-error.log'),($_.ToString()+[Environment]::NewLine+$_.ScriptStackTrace))
    if (!$NoRestart) { [Windows.MessageBox]::Show((T 'updateError'),'CartelleColorate')|Out-Null }
}
try {
    $folder=[string]$resume.Folder; if (![IO.Directory]::Exists($folder)) { $folder=$root }
    if (!$NoRestart) { Start-Process -FilePath (Join-Path $env:SystemRoot 'System32/wscript.exe') -ArgumentList ('//B //Nologo "'+(Join-Path $root 'Avvio.vbs')+'" "'+$folder+'"') -WindowStyle Hidden }
} finally { $script:installComplete=$true; $window.Close() }
