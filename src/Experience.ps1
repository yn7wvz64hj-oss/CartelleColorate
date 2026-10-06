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
    $actions=switch ($Group) { 'folderTools' { @('batch','singleFolder','managed','history','redo') } 'iconTools' { @('editPng','badge','iconSizes') } 'libraryTools' { @('collections','importColors','exportColors','exportBackup','importBackup') } }
    foreach ($action in $actions) {
        $item=[Windows.Controls.MenuItem]::new(); $item.Header=T $action; $item.Tag=$action; $item.Style=$window.FindResource('FluentMenuItem')
        if ($action -eq 'editPng') { $item.IsEnabled=[bool]$script:pngSelection }; if ($action -eq 'singleFolder') { $item.IsEnabled=$script:batchTargets.Count -gt 1 }
        $item.Add_Click({ param($sender,$e) try {
            $action=[string]$sender.Tag
            if ($action -in @('importColors','exportColors','importBackup','exportBackup')) {
                $import=$action -in @('importColors','importBackup'); $dialog=if ($import) { [Microsoft.Win32.OpenFileDialog]::new() } else { [Microsoft.Win32.SaveFileDialog]::new() }
                $backup=$action -in @('importBackup','exportBackup'); $dialog.Filter=if ($backup) { 'CartelleColorate (*.ccbackup)|*.ccbackup' } else { 'JSON (*.json)|*.json' }; $dialog.DefaultExt=if ($backup) { '.ccbackup' } else { '.json' }
                if ($dialog.ShowDialog($window)) { switch ($action) { 'importColors' { Import-Colors $dialog.FileName } 'exportColors' { Export-Colors $dialog.FileName } 'exportBackup' { Export-LibraryBackup $dialog.FileName; Show-Toast (T 'backupSaved') } 'importBackup' { Import-LibraryBackup $dialog.FileName; Reload-LibraryInterface; Show-Toast (T 'backupLoaded') } } }; return
            }; Invoke-AdvancedAction $action
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
    [Windows.Controls.DockPanel]::SetDock($footer,'Bottom'); $layout.Children.Add($footer)|Out-Null; $outer=[Windows.Controls.ScrollViewer]::new(); $outer.VerticalScrollBarVisibility='Auto'; $outer.Content=$Panel; $layout.Children.Add($outer)|Out-Null; $Dialog.Content=$layout
    Add-Type -AssemblyName System.Net.Http; $client=[Net.Http.HttpClient]::new(); $client.Timeout=[TimeSpan]::FromSeconds(30); $client.DefaultRequestHeaders.UserAgent.ParseAdd('CartelleColorate/'+$script:productVersion)
    $script:guidedUpdate=@{Window=$Dialog;Notes=$notes;Help=$help;Client=$client;Task=$null;Phase='';Offer=$null;Requested='';Installer=''}
    $timer=[Windows.Threading.DispatcherTimer]::new(); $timer.Interval=[TimeSpan]::FromMilliseconds(120); $script:guidedUpdate.Timer=$timer; $timer.Add_Tick({ Invoke-GuidedUpdateTick })
    Refresh-GuidedRelease
}
function Refresh-GuidedRelease {
    $ctx=$script:guidedUpdate; if (!$ctx -or $UITest -or $Preview -or !$script:availableVersion -or ($ctx.Requested -eq $script:availableVersion -and ($ctx.Offer -or $ctx.Phase)) -or $ctx.Phase -eq 'Download') { return }
    $ctx.Requested=$script:availableVersion; $ctx.Offer=$null; $ctx.Installer=''; $ctx.Phase='Release'; $script:updateDownload.IsEnabled=$false; $ctx.Notes.Text=T 'releaseLoading'
    $ctx.Task=$ctx.Client.GetStringAsync('https://api.github.com/repos/yn7wvz64hj-oss/CartelleColorate/releases/tags/v'+$ctx.Requested); $ctx.Timer.Start()
}
function Invoke-GuidedDownload {
    $ctx=$script:guidedUpdate; if (!$ctx -or $UITest -or $Preview) { return }
    if ($ctx.Installer) { try { Start-Process -FilePath $ctx.Installer -WorkingDirectory ([IO.Path]::GetDirectoryName($ctx.Installer)); $ctx.Window.Close(); $window.Close() } catch { $ctx.Help.Text=T 'updateError' }; return }
    if (!$ctx.Offer -or $ctx.Phase -eq 'Download') { return }; $ctx.Phase='Download'; $script:updateDownload.IsEnabled=$false; $script:updateDownload.Content=T 'updateDownloading'; $ctx.Task=$ctx.Client.GetByteArrayAsync($ctx.Offer.Url); $ctx.Timer.Start()
}
function Invoke-GuidedUpdateTick {
    $ctx=$script:guidedUpdate; if (!$ctx -or !$ctx.Task -or !$ctx.Task.IsCompleted) { return }; $ctx.Timer.Stop()
    try {
        $result=$ctx.Task.GetAwaiter().GetResult()
        if ($ctx.Phase -eq 'Release') { $ctx.Offer=Get-ReleaseOffer ($result | ConvertFrom-Json) $ctx.Requested; $ctx.Notes.Text=$ctx.Offer.Notes; $script:updateDownload.Content=T 'downloadUpdate'; $script:updateDownload.IsEnabled=$true }
        elseif ($ctx.Phase -eq 'Download') { $destination=Join-Path $root ('updates/package-'+[Guid]::NewGuid().ToString('N')); $ctx.Installer=Expand-VerifiedUpdate $result $ctx.Offer $destination; $ctx.Help.Text=T 'updateReady'; $script:updateDownload.Content=T 'installUpdate'; $script:updateDownload.IsEnabled=$true }
    } catch { $ctx.Help.Text=T 'updateError'; $ctx.Notes.Text=if ($ctx.Offer) { $ctx.Offer.Notes } else { T 'releaseUnavailable' }; $script:updateDownload.Content=T 'downloadUpdate'; $script:updateDownload.IsEnabled=[bool]$ctx.Offer }
    finally { $ctx.Phase='' }
}
function Stop-GuidedUpdate {
    $ctx=$script:guidedUpdate; if (!$ctx) { return }; $ctx.Timer.Stop(); $ctx.Client.CancelPendingRequests(); $ctx.Client.Dispose(); $script:guidedUpdate=$null
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
    $menu=$ui.PaletteTools.ContextMenu; $folders=@($menu.Items | Where-Object { $_.Tag -eq 'folderTools' }); $library=@($menu.Items | Where-Object { $_.Tag -eq 'libraryTools' }); if ($menu.Items.Count -ne 6 -or $folders.Count -ne 1 -or $library[0].Items.Count -ne 5) { throw 'Grouped menu lost actions' }
    $script:visualCancelTest=$true; $before=Get-DataHash ([IO.File]::ReadAllBytes((Join-Path $root 'sfondi.json'))); $beforeColor=$ui.PersonalBackground.Background.Color.ToString(); Show-BackgroundDialog; $script:visualCancelTest=$false
    if ((Get-DataHash ([IO.File]::ReadAllBytes((Join-Path $root 'sfondi.json')))) -ne $before -or $script:backgroundDraft -or $ui.PersonalBackground.Background.Color.ToString() -ne $beforeColor) { throw 'Cancelled background wrote preferences or did not restore preview' }
    Save-BackgroundChoice 'MacOS' 'Image' '#123456' $Png 4 2 35; Apply-Appearance 'MacOS'; $brush=$ui.PersonalBackground.Background
    if ($brush.AlignmentX -ne 'Right' -or $brush.Viewbox.Width -ne 0.5 -or $ui.BackgroundShade.Background.Color.A -ne 89) { throw 'Background image layout failed' }; $same=New-BackgroundBrush ((Read-BackgroundChoices)['MacOS']); if (![object]::ReferenceEquals($brush.ImageSource,$same.ImageSource)) { throw 'Background reloads during preview' }
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
