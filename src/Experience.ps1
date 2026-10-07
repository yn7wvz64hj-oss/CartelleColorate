function Get-BackgroundValue($Entry,[string]$Name,$Default) {
    if ($Entry -and $null -ne $Entry.$Name) { return $Entry.$Name }; return $Default
}
function Assert-BackgroundLayout($Position,$Zoom,$Veil) {
    if ($Position -isnot [int] -and $Position -isnot [long]) { throw (T 'backgroundError') }
    if ($Position -lt 0 -or $Position -gt 4 -or $Zoom -isnot [ValueType] -or [double]::IsNaN([double]$Zoom) -or [double]$Zoom -lt 1 -or [double]$Zoom -gt 3 -or $Veil -isnot [ValueType] -or [double]$Veil -lt 0 -or [double]$Veil -gt 100) { throw (T 'backgroundError') }
}
function New-BackgroundBrush($Entry) {
    $file=Get-Item -LiteralPath $Entry.Image -ErrorAction Stop; $key=$file.FullName+'|'+$file.LastWriteTimeUtc.Ticks
    if (!$script:backgroundImageCache) { $script:backgroundImageCache=@{} }
    if (!$script:backgroundImageCache.ContainsKey($key)) {
        $source=[Drawing.Image]::FromFile($file.FullName); try { if ([long]$source.Width*$source.Height -gt 67108864) { throw (T 'backgroundError') }; $decodeWidth=[Math]::Min(1920,$source.Width) } finally { $source.Dispose() }
        $image=[Windows.Media.Imaging.BitmapImage]::new(); $image.BeginInit(); $image.CacheOption='OnLoad'; $image.DecodePixelWidth=$decodeWidth; $image.UriSource=[Uri]::new($file.FullName); $image.EndInit(); $image.Freeze()
        if ($script:backgroundImageCache.Count -ge 4) { $script:backgroundImageCache.Clear() }; $script:backgroundImageCache[$key]=$image
    }
    $position=[int](Get-BackgroundValue $Entry Position 0); $zoom=[double](Get-BackgroundValue $Entry Zoom 1); $x=0.5; $y=0.5
    switch ($position) { 1 { $y=0 } 2 { $y=1 } 3 { $x=0 } 4 { $x=1 } }
    $brush=[Windows.Media.ImageBrush]::new($script:backgroundImageCache[$key]); $brush.Stretch='UniformToFill'; $brush.AlignmentX=@('Left','Center','Right')[[int]($x*2)]; $brush.AlignmentY=@('Top','Center','Bottom')[[int]($y*2)]
    $size=1/$zoom; $brush.Viewbox=[Windows.Rect]::new((1-$size)*$x,(1-$size)*$y,$size,$size); $brush.ViewboxUnits='RelativeToBoundingBox'; $brush.Freeze(); return $brush
}
function Initialize-BackgroundPreview($Context) {
    $Context.Timer=[Windows.Threading.DispatcherTimer]::new(); $Context.Timer.Interval=[TimeSpan]::FromMilliseconds(40)
    $Context.Timer.Add_Tick({ $ctx=$script:backgroundDialog; if (!$ctx) { return }; $ctx.Timer.Stop(); Apply-BackgroundDraft })
}
function Request-BackgroundPreview {
    $ctx=$script:backgroundDialog; if (!$ctx -or $ctx.Syncing -or $ctx.Mode.SelectedIndex -lt 0) { return }; $ctx.Timer.Stop(); $ctx.Timer.Start()
}
function Apply-BackgroundDraft {
    $ctx=$script:backgroundDialog; if (!$ctx -or $ctx.Hex.Text -notmatch '^#[0-9A-Fa-f]{6}$') { return }
    $mode=@('Default','Color','Image')[$ctx.Mode.SelectedIndex]; if ($mode -eq 'Image' -and !$ctx.Path) { return }
    $script:backgroundDraft=[pscustomobject]@{Style=$ctx.Style;Mode=$mode;Hex=$ctx.Hex.Text;Image=$ctx.Path;Position=[int]$ctx.Position.SelectedIndex;Zoom=[double]$ctx.Zoom.Value;Veil=[int]$ctx.Veil.Value}
    Apply-Appearance $ctx.Style
    if ($mode -eq 'Image') { try { $ctx.Preview.Background=New-BackgroundBrush $script:backgroundDraft } catch {} }
}
function Place-PreviewWindow($Dialog) {
    if ($Preview -or $UITest) { return }; $area=[Windows.SystemParameters]::WorkArea; $Dialog.WindowStartupLocation='Manual'
    $right=$window.Left+$window.ActualWidth+12; $left=$window.Left-$Dialog.Width-12
    $Dialog.Left=if ($right+$Dialog.Width -le $area.Right) { $right } elseif ($left -ge $area.Left) { $left } else { [Math]::Max($area.Left,[Math]::Min($area.Right-$Dialog.Width,$window.Left+70)) }
    $Dialog.Top=[Math]::Max($area.Top,[Math]::Min($area.Bottom-$Dialog.Height,$window.Top))
}
function Add-GroupedActions($Parent,[string]$Group) {
    $actions=switch ($Group) { 'folderTools' { @('batch','singleFolder','managed','history','redo') } 'iconTools' { @('folderPreview','editPng','badge','iconSizes') } 'libraryTools' { @('collections','importColors','exportColors','exportBackup','importBackup') } }
    foreach ($action in $actions) {
        $item=[Windows.Controls.MenuItem]::new(); $item.Header=T $action; $item.Tag=$action; $item.Style=$window.FindResource('FluentMenuItem')
        if ($action -eq 'editPng') { $item.IsEnabled=[bool]$script:pngSelection }; if ($action -eq 'singleFolder') { $item.IsEnabled=$script:batchTargets.Count -gt 1 }
        $item.Add_Click({ param($sender,$e) try {
            $action=[string]$sender.Tag
            if ($action -in @('importColors','exportColors','importBackup','exportBackup')) {
                $import=$action -in @('importColors','importBackup'); $dialog=if ($import) { [Microsoft.Win32.OpenFileDialog]::new() } else { [Microsoft.Win32.SaveFileDialog]::new() }
                $backup=$action -in @('importBackup','exportBackup'); $dialog.Filter=if ($backup) { 'CartelleColorate (*.ccbackup)|*.ccbackup' } else { 'JSON (*.json)|*.json' }; $dialog.DefaultExt=if ($backup) { '.ccbackup' } else { '.json' }
                if ($dialog.ShowDialog($window)) { switch ($action) { 'importColors' { Import-Colors $dialog.FileName } 'exportColors' { Export-Colors $dialog.FileName } 'exportBackup' { Export-LibraryBackup $dialog.FileName; Show-Toast (T 'backupSaved') } 'importBackup' { Import-LibraryBackup $dialog.FileName; Reload-LibraryInterface; Show-Toast (T 'backupLoaded') } } }; return
            }; if ($action -eq 'folderPreview') { Show-FolderPreview; return }; Invoke-AdvancedAction $action
        } catch { Show-Status $_.Exception.Message } }); $Parent.Items.Add($item)|Out-Null
    }
}
function Set-AdaptiveWindow($Dialog,$Area=$null) {
    if (!$Area) { $Area=[Windows.SystemParameters]::WorkArea }; $width=[Math]::Max(240,$Area.Width-24); $height=[Math]::Max(220,$Area.Height-24)
    $Dialog.MinWidth=[Math]::Min($Dialog.MinWidth,$width); $Dialog.MinHeight=[Math]::Min($Dialog.MinHeight,$height); $Dialog.MaxWidth=$width; $Dialog.MaxHeight=$height
    $Dialog.Width=[Math]::Min($Dialog.Width,$width); $Dialog.Height=[Math]::Min($Dialog.Height,$height)

}
function Initialize-AdaptiveLayout {
    Set-AdaptiveWindow $window
    $window.Add_SourceInitialized({ Set-AdaptiveWindow $window })
}
function Get-ReleaseOffer($Release,[string]$Version) {
    if ($Version -notmatch '^\d+\.\d+\.\d+$' -or $Release.tag_name -cne ('v'+$Version) -or $Release.draft -or $Release.prerelease) { throw (T 'updateError') }
    $name='CartelleColorate-'+$Version+'-windows.zip'; $assets=@($Release.assets | Where-Object { $_.name -ceq $name }); if ($assets.Count -ne 1) { throw (T 'updateError') }
    $asset=$assets[0]; $url='https://github.com/yn7wvz64hj-oss/CartelleColorate/releases/download/v'+$Version+'/'+$name
    if ($asset.browser_download_url -cne $url -or $asset.digest -notmatch '^sha256:[a-f0-9]{64}$' -or $asset.size -lt 1 -or $asset.size -gt 33554432) { throw (T 'updateError') }
    $body=[string]$Release.body; $section=if ($script:activeLanguage.code -eq 'it') { 'Italiano' } else { 'English' }
    $match=[regex]::Match($body,'(?ms)^## '+$section+'\s*\r?\n(.*?)(?=^## |\z)'); if ($match.Success) { $body=$match.Groups[1].Value }
    $body=$body -replace '(?m)^#+\s*','' -replace '\*\*','' -replace '`',''; $body=[regex]::Replace($body,'\[([^\]]+)\]\([^\)]+\)','$1'); if ($body.Length -gt 16000) { $body=$body.Substring(0,16000) }
    return [pscustomobject]@{Version=$Version;Url=$url;Hash=$asset.digest.Substring(7);Size=[long]$asset.size;Notes=$body.Trim()}
}
function Expand-VerifiedUpdate([byte[]]$Bytes,$Offer,[string]$Destination) {
    if ($Bytes.Length -ne $Offer.Size -or (Get-DataHash $Bytes) -cne $Offer.Hash) { throw (T 'updateIntegrity') }
    Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
    $memory=[IO.MemoryStream]::new($Bytes,$false); $zip=[IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Read); $files=@{}; $total=0L
    try {
        foreach ($entry in $zip.Entries) {
            $name=$entry.FullName.Replace('\','/'); if ($name -eq 'CartelleColorate/') { continue }
            if ($name -notmatch '^CartelleColorate/([A-Za-z0-9._-]+)$') { throw (T 'updateIntegrity') }; $leaf=$Matches[1]
            if ($files.ContainsKey($leaf) -or $entry.Length -gt 33554432) { throw (T 'updateIntegrity') }; $total+=$entry.Length; if ($total -gt 67108864) { throw (T 'updateIntegrity') }
            $stream=$entry.Open(); $buffer=[IO.MemoryStream]::new(); try { $stream.CopyTo($buffer); $files[$leaf]=$buffer.ToArray() } finally { $stream.Dispose(); $buffer.Dispose() }
        }
        foreach ($required in @('VERSION','MANIFEST-SHA256.txt','Installa.cmd','Setup.ps1','CartelleColorate.ps1','Avvio.vbs')) { if (!$files.ContainsKey($required)) { throw (T 'updateIntegrity') } }
        if ([Text.Encoding]::UTF8.GetString($files['VERSION']).Trim() -cne $Offer.Version) { throw (T 'updateIntegrity') }
        $seen=@{}; foreach ($line in ([Text.Encoding]::ASCII.GetString($files['MANIFEST-SHA256.txt']) -split '\r?\n')) { if (!$line) { continue }; if ($line -notmatch '^([a-f0-9]{64})  ([A-Za-z0-9._-]+)$') { throw (T 'updateIntegrity') }; $hash=$Matches[1]; $file=$Matches[2]; if ($seen.ContainsKey($file) -or !$files.ContainsKey($file) -or (Get-DataHash $files[$file]) -cne $hash) { throw (T 'updateIntegrity') }; $seen[$file]=$true }
        if ($seen.Count -ne $files.Count-1 -or $seen.ContainsKey('MANIFEST-SHA256.txt')) { throw (T 'updateIntegrity') }
    } finally { $zip.Dispose(); $memory.Dispose() }
    if ([IO.Directory]::Exists($Destination)) { throw (T 'updateIntegrity') }; [IO.Directory]::CreateDirectory($Destination)|Out-Null
    foreach ($name in $files.Keys) { [IO.File]::WriteAllBytes((Join-Path $Destination $name),$files[$name]) }; return (Join-Path $Destination 'Installa.cmd')
}
function Initialize-GuidedUpdate($Dialog,$Panel) {
    $Dialog.Content=$null
    $notes=[Windows.Controls.TextBlock]::new(); $notes.TextWrapping='Wrap'; $notes.Text=T 'releaseLoading'; $notes.Margin=[Windows.Thickness]::new(0,12,0,12)
    $scroll=[Windows.Controls.ScrollViewer]::new(); $scroll.VerticalScrollBarVisibility='Auto'; $scroll.Content=$notes; $scroll.MaxHeight=220; $Panel.Children.Insert(1,$scroll)
    $help=[Windows.Controls.TextBlock]::new(); $help.Text=T 'updateSteps'; $help.TextWrapping='Wrap'; $help.Margin=[Windows.Thickness]::new(0,12,0,0); $Panel.Children.Add($help)|Out-Null
    # The download button remains reachable when the display has little vertical space.
    $layout=[Windows.Controls.DockPanel]::new(); $footer=[Windows.Controls.StackPanel]::new(); $footer.Margin=[Windows.Thickness]::new(20,4,20,16); $Panel.Children.Remove($script:updateDownload); $footer.Children.Add($script:updateDownload)|Out-Null; $Panel.Children.Remove($help); $footer.Children.Add($help)|Out-Null
    $progress=[Windows.Controls.ProgressBar]::new(); $progress.Minimum=0; $progress.Maximum=100; $progress.Height=6; $progress.Visibility='Collapsed'; $progress.Margin=[Windows.Thickness]::new(0,8,0,6); $footer.Children.Insert(0,$progress)
    $progressText=[Windows.Controls.TextBlock]::new(); $progressText.Foreground=$window.Resources['Text']; $progressText.Visibility='Collapsed'; $progressText.Margin=[Windows.Thickness]::new(0,0,0,4); $footer.Children.Insert(1,$progressText)
    [Windows.Controls.DockPanel]::SetDock($footer,'Bottom'); $layout.Children.Add($footer)|Out-Null; $outer=[Windows.Controls.ScrollViewer]::new(); $outer.VerticalScrollBarVisibility='Auto'; $outer.Content=$Panel; $layout.Children.Add($outer)|Out-Null; $Dialog.Content=$layout
    Add-Type -AssemblyName System.Net.Http; $client=[Net.Http.HttpClient]::new(); $client.Timeout=[TimeSpan]::FromSeconds(30); $client.DefaultRequestHeaders.UserAgent.ParseAdd('CartelleColorate/'+$script:productVersion)
    $script:guidedUpdate=@{Window=$Dialog;Notes=$notes;Help=$help;Client=$client;Task=$null;Phase='';Offer=$null;Requested='';Installer='';Progress=$progress;ProgressText=$progressText;Transfer=$null}
    $timer=[Windows.Threading.DispatcherTimer]::new(); $timer.Interval=[TimeSpan]::FromMilliseconds(120); $script:guidedUpdate.Timer=$timer; $timer.Add_Tick({ Invoke-GuidedUpdateTick })
    Refresh-GuidedRelease
}
function Refresh-GuidedRelease {
    $ctx=$script:guidedUpdate; if (!$UITest -and !$Preview -and $ctx -and !$ctx.Offer -and $ctx.Phase -ne 'Release') { $ctx.Requested=''; Refresh-GuidedRelease; return }; if (!$ctx -or $UITest -or $Preview -or !$script:availableVersion -or ($ctx.Requested -eq $script:availableVersion -and ($ctx.Offer -or $ctx.Phase)) -or $ctx.Phase -eq 'Download') { return }
    $ctx.Requested=$script:availableVersion; $ctx.Offer=$null; $ctx.Installer=''; $ctx.Phase='Release'; $script:updateDownload.IsEnabled=$false; $ctx.Notes.Text=T 'releaseLoading'
    $ctx.Task=$ctx.Client.GetStringAsync('https://api.github.com/repos/yn7wvz64hj-oss/CartelleColorate/releases/tags/v'+$ctx.Requested); $ctx.Timer.Start()
}
function Invoke-GuidedDownload {
    $ctx=$script:guidedUpdate; if (!$ctx -or $UITest -or $Preview -or !$ctx.Offer -or $ctx.Phase -eq 'Download') { return }
    try { Initialize-Transfer; if ($ctx.Transfer) { $ctx.Transfer.Dispose() }; $ctx.Transfer=[CartelleColorate.Transfer]::new($script:productVersion); $ctx.Started=[DateTime]::UtcNow; $ctx.Phase='Download'; $ctx.Progress.Visibility='Visible'; $ctx.ProgressText.Visibility='Visible'; $ctx.Progress.IsIndeterminate=$false; $ctx.Progress.Value=0; $script:updateDownload.IsEnabled=$false; $script:updateDownload.Content=T 'updateDownloading'; $ctx.Task=$ctx.Transfer.DownloadAsync($ctx.Offer.Url,$ctx.Offer.Size); $ctx.Timer.Start() } catch { $ctx.Help.Text=T 'updateError'; $script:updateDownload.IsEnabled=$true }
}
function Invoke-GuidedUpdateTick {
    $ctx=$script:guidedUpdate; if (!$ctx -or !$ctx.Task) { return }; if ($ctx.Phase -eq 'Download') { Set-DownloadProgress $ctx }; if (!$ctx.Task.IsCompleted) { return }; $ctx.Timer.Stop()
    try {
        $result=$ctx.Task.GetAwaiter().GetResult()
        if ($ctx.Phase -eq 'Release') { $ctx.Offer=Get-ReleaseOffer ($result | ConvertFrom-Json) $ctx.Requested; $ctx.Notes.Text=$ctx.Offer.Notes; $script:updateDownload.Content=T 'autoUpdate'; $script:updateDownload.IsEnabled=$true }
        elseif ($ctx.Phase -eq 'Download') { $destination=Join-Path $root ('updates/package-'+[Guid]::NewGuid().ToString('N')); $ctx.Progress.Value=100; $ctx.Help.Text=T 'updateInstalling'; $ctx.Progress.IsIndeterminate=$true; $ctx.Window.UpdateLayout(); $ctx.Installer=Expand-VerifiedUpdate $result $ctx.Offer $destination; Start-AutoInstallation $ctx }
    } catch { $ctx.Progress.IsIndeterminate=$false; $ctx.Help.Text=T 'updateError'; $ctx.Notes.Text=if ($ctx.Offer) { $ctx.Offer.Notes } else { T 'releaseUnavailable' }; $script:updateDownload.Content=T 'retryUpdate'; $script:updateDownload.IsEnabled=$true }
    finally { $ctx.Phase='' }
}
function Stop-GuidedUpdate {
    $ctx=$script:guidedUpdate; if (!$ctx) { return }; $ctx.Timer.Stop(); if ($ctx.Transfer) { $ctx.Transfer.Dispose() }; $ctx.Client.CancelPendingRequests(); $ctx.Client.Dispose(); $script:guidedUpdate=$null
}
function Test-ExperienceBackend {
    $case=Join-Path $root ('update-check-'+[Guid]::NewGuid().ToString('N')); [IO.Directory]::CreateDirectory($case)|Out-Null
    $files=@{}; foreach ($name in @('VERSION','Installa.cmd','Setup.ps1','CartelleColorate.ps1','Avvio.vbs')) { $files[$name]=[Text.Encoding]::UTF8.GetBytes($(if ($name -eq 'VERSION') { '99.0.0' } else { 'fixture only' })) }
    $manifest=@(); foreach ($name in $files.Keys) { $manifest+=((Get-DataHash $files[$name])+'  '+$name) }; $files['MANIFEST-SHA256.txt']=[Text.Encoding]::ASCII.GetBytes(($manifest -join "`n"))
    Add-Type -AssemblyName System.IO.Compression; $memory=[IO.MemoryStream]::new(); $zip=[IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Create,$true)
    foreach ($name in $files.Keys) { $stream=$zip.CreateEntry('CartelleColorate/'+$name).Open(); try { $stream.Write($files[$name],0,$files[$name].Length) } finally { $stream.Dispose() } }; $zip.Dispose(); $bytes=$memory.ToArray(); $memory.Dispose()
    $offer=[pscustomobject]@{Size=$bytes.Length;Hash=(Get-DataHash $bytes);Version='99.0.0'}; $installer=Expand-VerifiedUpdate $bytes $offer (Join-Path $case 'good'); if (![IO.File]::Exists($installer)) { throw 'Verified update not extracted' }
    $bad=$bytes.Clone(); $bad[0]=$bad[0] -bxor 1; $rejected=$false; try { Expand-VerifiedUpdate $bad $offer (Join-Path $case 'bad') } catch { $rejected=$true }; if (!$rejected -or [IO.Directory]::Exists((Join-Path $case 'bad'))) { throw 'Corrupt update accepted' }
    $offer.Version='99.0.1'; $rejected=$false; try { Expand-VerifiedUpdate $bytes $offer (Join-Path $case 'wrong') } catch { $rejected=$true }; if (!$rejected) { throw 'Wrong update version accepted' }
    $offer.Version='99.0.0'; $memory=[IO.MemoryStream]::new(); $zip=[IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Create,$true); $stream=$zip.CreateEntry('CartelleColorate/../outside.txt').Open(); $stream.Dispose(); $zip.Dispose(); $unsafe=$memory.ToArray(); $memory.Dispose(); $offer.Hash=Get-DataHash $unsafe; $offer.Size=$unsafe.Length; $rejected=$false; try { Expand-VerifiedUpdate $unsafe $offer (Join-Path $case 'unsafe') } catch { $rejected=$true }; if (!$rejected -or [IO.Directory]::Exists((Join-Path $case 'unsafe'))) { throw 'Archive path traversal accepted' }
    $rejected=$false; try { Assert-BackgroundLayout 8 1 70 } catch { $rejected=$true }; if (!$rejected) { throw 'Bad background position accepted' }
    Write-Output 'OK: pacchetto aggiornamento verificato prima di estrarre; checksum e versione errati respinti.'
}
function Test-ExperienceInterface([string]$Png) {
    $menu=$ui.PaletteTools.ContextMenu; $folders=@($menu.Items | Where-Object { $_.Tag -eq 'folderTools' }); $library=@($menu.Items | Where-Object { $_.Tag -eq 'libraryTools' }); if ($menu.Items.Count -ne 7 -or $folders.Count -ne 1 -or $library[0].Items.Count -ne 5) { throw 'Grouped menu lost actions' }
    $script:visualCancelTest=$true; $before=Get-DataHash ([IO.File]::ReadAllBytes((Join-Path $root 'sfondi.json'))); $beforeColor=$ui.PersonalBackground.Background.Color.ToString(); Show-BackgroundDialog; $script:visualCancelTest=$false
    if ((Get-DataHash ([IO.File]::ReadAllBytes((Join-Path $root 'sfondi.json')))) -ne $before -or $script:backgroundDraft -or $ui.PersonalBackground.Background.Color.ToString() -ne $beforeColor) { throw 'Cancelled background wrote preferences or did not restore preview' }
    Save-BackgroundChoice 'MacOS' 'Image' '#123456' $Png 4 2 35; Apply-Appearance 'MacOS'; $brush=$ui.PersonalBackground.Background
    if ($brush.AlignmentX -ne 'Right' -or $brush.Viewbox.Width -ne 0.5 -or $ui.BackgroundShade.Background.Color.A -ne $(if ($script:dark) { 204 } else { 230 })) { throw 'Background image layout failed' }; $same=New-BackgroundBrush ((Read-BackgroundChoices)['MacOS']); if (![object]::ReferenceEquals($brush.ImageSource,$same.ImageSource)) { throw 'Background reloads during preview' }
    Test-ProCheckoutInterface
    Test-ProPreviewInterface
    Test-ProToolsInterface
    Test-ProProgressInterface
    Test-ComfortInterface
    $height=$window.Height; $width=$window.Width; $minHeight=$window.MinHeight; $minWidth=$window.MinWidth; $maxHeight=$window.MaxHeight; $maxWidth=$window.MaxWidth
    try { Set-AdaptiveWindow $window ([Windows.Rect]::new(0,0,480,470)); $window.UpdateLayout(); $point=$ui.Apply.TransformToAncestor($ui.Root).Transform([Windows.Point]::new(0,$ui.Apply.ActualHeight)); if ($point.Y -gt $ui.Root.ActualHeight+1) { throw 'Apply button outside compact window' }
        foreach ($scale in @(1.25,1.5,2.0)) { $visual=[Windows.Media.DrawingVisual]::new(); $dc=$visual.RenderOpen(); try { $dc.PushTransform([Windows.Media.ScaleTransform]::new($scale,$scale)); $dc.DrawRectangle([Windows.Media.VisualBrush]::new($ui.Root),$null,[Windows.Rect]::new(0,0,$ui.Root.ActualWidth,$ui.Root.ActualHeight)); $dc.Pop() } finally { $dc.Close() }; $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]($ui.Root.ActualWidth*$scale),[int]($ui.Root.ActualHeight*$scale),96,96,[Windows.Media.PixelFormats]::Pbgra32); $bitmap.Render($visual); if ($bitmap.PixelWidth -lt 400) { throw 'Scaled rendering failed' } }
    } finally { $window.MaxHeight=$maxHeight; $window.MaxWidth=$maxWidth; $window.MinHeight=$minHeight; $window.MinWidth=$minWidth; $window.Height=$height; $window.Width=$width; $window.UpdateLayout() }
}

function Get-DialogContent($Dialog) { $content=$Dialog.Content; if ($content -is [Windows.Controls.ScrollViewer]) { return $content.Content }; return $content }

function Show-AdaptiveDialog($Dialog) {
    if ($Dialog -is [Windows.Window]) { Set-AdaptiveWindow $Dialog; if ($Dialog.Content -is [Windows.Controls.StackPanel] -or $Dialog.Content -is [Windows.Controls.WrapPanel]) { $content=$Dialog.Content; $Dialog.Content=$null; $scroll=[Windows.Controls.ScrollViewer]::new(); $scroll.VerticalScrollBarVisibility='Auto'; $scroll.HorizontalScrollBarVisibility='Disabled'; $scroll.Content=$content; $Dialog.Content=$scroll } }
    return $Dialog.ShowDialog()
}

. (Join-Path $PSScriptRoot 'AutoUpdates.ps1')

function Show-FolderPreview {
    $dialog=New-ProductWindow (T 'folderPreview') 440 290; $panel=[Windows.Controls.StackPanel]::new(); $panel.Margin=[Windows.Thickness]::new(20)
    $tiles=[Windows.Controls.Grid]::new(); $tiles.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new()); $tiles.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new()); $panel.Children.Add($tiles)|Out-Null
    $memory=[IO.MemoryStream]::new([FolderShell]::ReadFolderPreview($script:currentFolder)); $current=[Windows.Media.Imaging.BitmapImage]::new(); try { $current.BeginInit(); $current.CacheOption='OnLoad'; $current.StreamSource=$memory; $current.EndInit(); $current.Freeze() } finally { $memory.Dispose() }
    $path=Join-Path $root ('compare-'+[Guid]::NewGuid().ToString('N')+'.ico'); $prepared=$null
    try {
        $prepared=Get-PreparedIcon $script:badge; if ($prepared) { New-PngIcon $prepared $path } else { New-ColorIcon (Valid-Hex) $path }; $proposed=Read-IconFrame $path 96
        for ($i=0;$i -lt 2;$i++) { $tile=[Windows.Controls.StackPanel]::new(); $tile.Margin=[Windows.Thickness]::new(10); [Windows.Controls.Grid]::SetColumn($tile,$i); $tiles.Children.Add($tile)|Out-Null
            $label=[Windows.Controls.TextBlock]::new(); $label.Text=T $(if ($i) { 'proposedIcon' } else { 'currentIcon' }); $label.HorizontalAlignment='Center'; $label.TextWrapping='Wrap'; $tile.Children.Add($label)|Out-Null
            $image=[Windows.Controls.Image]::new(); $image.Source=if ($i) { $proposed } else { $current }; $image.Width=72; $image.Height=72; $image.Margin=[Windows.Thickness]::new(0,14,0,10); $tile.Children.Add($image)|Out-Null
            $name=[Windows.Controls.TextBlock]::new(); $name.Text=if ($i -and $script:batchTargets.Count -eq 1) { $ui.FolderName.Text } else { [IO.Path]::GetFileName($script:currentFolder) }; $name.TextWrapping='Wrap'; $name.TextAlignment='Center'; $tile.Children.Add($name)|Out-Null
        }; $dialog.Content=$panel; $script:compareDialog=$dialog
        if ($UITest) { $dialog.Add_ContentRendered({ $script:compareDialog.Close() }) }; [void](Show-AdaptiveDialog $dialog)
    } finally { if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }; if ($prepared -and $prepared -ne $script:pngSelection -and [IO.File]::Exists($prepared)) { [IO.File]::Delete($prepared) }; $script:compareDialog=$null }
}
function Reset-VisualAppearance {
    Save-AppearancePreference 'Windows'; Save-AppSetting 'theme' 'System'; Save-AppSetting 'glassOpacity' '55'; Save-AppSetting 'glassDepth' '50'
    $choices=Read-BackgroundChoices; foreach ($style in @('Windows','MacOS')) { $choices[$style]=[pscustomobject]@{Style=$style;Mode='Default';Hex='#4A90E2';Image='';Position=0;Zoom=1;Veil=70} }; Write-AdvancedJson (Join-Path $root 'sfondi.json') @($choices.Values)
    $script:backgroundDraft=$null; $script:appearance='Windows'; $script:themeMode='System'; $script:glassOpacity=55; $script:glassDepth=50; Update-ProductTheme
}
function Apply-AccessibleAppearance {
    if (![Windows.SystemParameters]::HighContrast) { return }
    foreach ($key in @('Page','Card','Input','MenuSurface','Hover')) { $window.Resources[$key]=[Windows.SystemColors]::WindowBrush }
    foreach ($key in @('Text','Secondary','BackdropText','MenuText','Line','MenuLine')) { $window.Resources[$key]=[Windows.SystemColors]::WindowTextBrush }
    foreach ($key in @('Accent','PrimaryFill','AccentHover','Selected','MenuHover')) { $window.Resources[$key]=[Windows.SystemColors]::HighlightBrush }; $window.Resources['OnAccent']=[Windows.SystemColors]::HighlightTextBrush
}
function Invoke-ComfortShortcut([string]$Key,[bool]$Shift) {
    switch ($Key) {
        'Enter' { $ui.Apply.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)); return $true }
        'S' { if ($ui.Save.IsEnabled) { $ui.Save.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }; return $true }
        'F' { if ($ui.SearchRow.Visibility -ne 'Visible') { $ui.SearchToggle.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }; $ui.SearchText.Focus()|Out-Null; return $true }
        'Z' { if ([Windows.Input.Keyboard]::FocusedElement -is [Windows.Controls.TextBox]) { return $false }; if ($Shift) { Invoke-AdvancedAction 'redo' } elseif ($ui.Undo.Visibility -eq 'Visible') { $ui.Undo.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }; return $true }
        'P' { Show-FolderPreview; return $true }
    }; return $false
}
function Initialize-ComfortInterface {
    $window.Add_PreviewKeyDown({ param($sender,$e) if ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) { try { if (Invoke-ComfortShortcut $e.Key.ToString() ([bool]([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Shift))) { $e.Handled=$true } } catch { Show-Status $_.Exception.Message } } })
    $focus=[Windows.Markup.XamlReader]::Parse('<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Control"><Setter Property="Template"><Setter.Value><ControlTemplate><Rectangle Stroke="{DynamicResource Accent}" StrokeThickness="2" StrokeDashArray="2 2" Margin="2" RadiusX="4" RadiusY="4"/></ControlTemplate></Setter.Value></Setter></Style>')
    foreach ($control in $ui.Values) { if ($control -is [Windows.Controls.Control]) { $control.FocusVisualStyle=$focus } }
    foreach ($pair in @(@('Apply','Ctrl+Enter'),@('Save','Ctrl+S'),@('Undo','Ctrl+Z'),@('SearchToggle','Ctrl+F'))) { $ui[$pair[0]].ToolTip=([string]$ui[$pair[0]].ToolTip+' · '+$pair[1]).Trim([char[]]" ·") }
}

function Get-ContrastRatio([Windows.Media.Color]$A,[Windows.Media.Color]$B) {
    $lumas=@(); foreach ($color in @($A,$B)) { $sum=0; $channels=@($color.R,$color.G,$color.B); $weights=@(0.2126,0.7152,0.0722); for ($i=0;$i -lt 3;$i++) { $v=$channels[$i]/255.0; $sum+=$weights[$i]*$(if ($v -le 0.04045) { $v/12.92 } else { [Math]::Pow(($v+0.055)/1.055,2.4) }) }; $lumas+=$sum }; return ([Math]::Max($lumas[0],$lumas[1])+0.05)/([Math]::Min($lumas[0],$lumas[1])+0.05)
}
function Test-ComfortInterface {
    $palettePath=Join-Path $root 'colori.json'; $settingsPath=Join-Path $root 'impostazioni.json'; $backgroundPath=Join-Path $root 'sfondi.json'; $before=@{}
    foreach ($path in @($palettePath,$settingsPath,$backgroundPath)) { $before[$path]=if ([IO.File]::Exists($path)) { [IO.File]::ReadAllBytes($path) } else { $null } }
    $oldAppearance=$script:appearance; $oldTheme=$script:themeMode; $oldDark=$script:dark; $oldOpacity=$script:glassOpacity; $oldDepth=$script:glassDepth
    try {
        $ini=Join-Path $script:currentFolder 'desktop.ini'; $hadIni=[IO.File]::Exists($ini); $iniBefore=if ($hadIni) { Get-DataHash ([IO.File]::ReadAllBytes($ini)) } else { '' }
        Show-FolderPreview
        if ([IO.File]::Exists($ini) -ne $hadIni -or ($hadIni -and (Get-DataHash ([IO.File]::ReadAllBytes($ini))) -ne $iniBefore)) { throw 'Preview changed the selected folder' }
        foreach ($darkMode in @($false,$true)) { $script:dark=$darkMode; Apply-Appearance 'MacOS'; $fill=$window.Resources['PrimaryFill']; foreach ($stop in $fill.GradientStops) { if ((Get-ContrastRatio $stop.Color $window.Resources['OnAccent'].Color) -lt 4.5) { throw 'Primary button contrast below 4.5' } }
            $shade=$ui.BackgroundShade.Background.Color; $channel=if ($darkMode) { 255-$shade.A } else { $shade.A }; $worst=[Windows.Media.Color]::FromRgb($channel,$channel,$channel); if ((Get-ContrastRatio $worst $window.Resources['Secondary'].Color) -lt 4.5) { throw 'Image contrast below 4.5' }
        }
        $null=Invoke-ComfortShortcut 'F' $false; if ($ui.SearchRow.Visibility -ne 'Visible' -or !$ui.SearchText.IsKeyboardFocused) { throw 'Keyboard search unavailable' }; $ui.SearchToggle.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        Reset-VisualAppearance; if ($script:appearance -ne 'Windows' -or $script:themeMode -ne 'System' -or @((Read-BackgroundChoices).Values | Where-Object Mode -ne 'Default').Count) { throw 'Appearance reset incomplete' }
        if ($before[$palettePath] -and (Get-DataHash ([IO.File]::ReadAllBytes($palettePath))) -ne (Get-DataHash $before[$palettePath])) { throw 'Appearance reset changed palette' }
        if ($before[$settingsPath]) { $previous=[Text.Encoding]::UTF8.GetString($before[$settingsPath]).TrimStart([char]0xFEFF) | ConvertFrom-Json; $current=Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json; if ($previous.language -ne $current.language) { throw 'Appearance reset changed language' } }
    } finally {
        foreach ($path in $before.Keys) { if ($null -ne $before[$path]) { [IO.File]::WriteAllBytes($path,$before[$path]) } elseif ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
        $script:appearance=$oldAppearance; $script:themeMode=$oldTheme; $script:dark=$oldDark; $script:glassOpacity=$oldOpacity; $script:glassDepth=$oldDepth; Apply-Appearance $oldAppearance
    }
    Write-Output 'OK: confronto senza cambiare la cartella, contrasto dei pulsanti e su immagini chiare/scure, ricerca da tastiera e ripristino aspetto senza perdere dati.'
}
