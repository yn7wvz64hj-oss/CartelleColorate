function Read-ProductSetting([string]$Key,$Default) {
    try { $settings=Get-Content -LiteralPath $script:languageSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json; if ($null -ne $settings.$Key) { return $settings.$Key } } catch {}
    return $Default
}
function Read-ProductList([string]$Name) {
    $path=Join-Path $root $Name
    if ([IO.File]::Exists($path)) { $loaded=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json; foreach ($item in $loaded) { if ($item) { $item } } }
}
function Save-CompletePreset([string]$Name,[string]$Hex,[string]$Png,[string]$Badge,[string]$BadgeHex) {
    if (!$Name.Trim() -or $Hex -notmatch '^#[0-9A-Fa-f]{6}$' -or $BadgeHex -notmatch '^#[0-9A-Fa-f]{6}$') { throw (T 'colorInvalid') }
    $items=@(Read-ProductList 'preset.json'); $existing=@($items | Where-Object { $_.Name -eq $Name.Trim() }); $id=if ($existing.Count) { $existing[0].Id } else { [Guid]::NewGuid().ToString('N') }
    $asset=''; if ($Png) { $image=[Drawing.Image]::FromFile($Png); try { $asset=Join-Path $root ('preset-'+[Guid]::NewGuid().ToString('N')+'.png'); $image.Save($asset,[Drawing.Imaging.ImageFormat]::Png) } finally { $image.Dispose() } }
    $preset=[pscustomobject]@{Id=$id;Name=$Name.Trim();Hex=$Hex.ToUpperInvariant();Png=$asset;OriginName=$(if ($existing.Count) { [string]$existing[0].OriginName } else { '' });Badge=$Badge;BadgeHex=$BadgeHex.ToUpperInvariant();Favorite=$(if ($existing.Count) { [bool]$existing[0].Favorite } else { $false })}
    Write-AdvancedJson (Join-Path $root 'preset.json') (@($items | Where-Object { $_.Id -ne $id })+@($preset)); Sync-PresetMenu; return $preset
}
function Get-SnapshotSignature($Snapshot) {
    $sha=[Security.Cryptography.SHA256]::Create(); try { return [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($Snapshot | ConvertTo-Json -Compress -Depth 12)))) } finally { $sha.Dispose() }
}
function Save-FolderActivity($Record,[string]$Kind) {
    $records=if ($Record.Batch) { @($Record.Batch) } else { @($Record) }
    $after=@(); foreach ($entry in $records) { $after+=Get-SnapshotSignature (New-FolderUndo $entry.Current) }
    $directory=Join-Path $root 'cronologia'; [IO.Directory]::CreateDirectory($directory)|Out-Null
    $id=[Guid]::NewGuid().ToString('N'); Write-AdvancedJson (Join-Path $directory ($id+'.json')) ([pscustomobject]@{Id=$id;Date=[DateTime]::UtcNow.ToString('o');Kind=$Kind;Records=@($records);After=@($after)})
}
function Read-FolderActivities {
    $directory=Join-Path $root 'cronologia'; if (![IO.Directory]::Exists($directory)) { return }
    foreach ($file in (Get-ChildItem -LiteralPath $directory -Filter '*.json' -File | Sort-Object LastWriteTimeUtc -Descending)) { try { $entry=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json; if ($entry.Id -match '^[a-f0-9]{32}$' -and @($entry.Records).Count) { $entry } } catch {} }
}
function Remove-ActivityForRecord($Record) {
    $records=if ($Record.Batch) { @($Record.Batch) } else { @($Record) }; $signature=Get-SnapshotSignature $records
    foreach ($entry in @(Read-FolderActivities)) { if ((Get-SnapshotSignature @($entry.Records)) -eq $signature) { [IO.File]::Delete((Join-Path $root ('cronologia/'+$entry.Id+'.json'))); break } }
}
function Restore-FolderActivity($Activity,[bool]$Repeat=$false) {
    if ($Activity.Id -notmatch '^[a-f0-9]{32}$' -or @($Activity.Records).Count -ne @($Activity.After).Count) { throw (T 'backupError') }
    $i=0; foreach ($record in $Activity.Records) {
        if (![IO.Directory]::Exists($record.Current) -or (Get-SnapshotSignature (New-FolderUndo $record.Current)) -ne $Activity.After[$i]) { throw (T 'historyConflict') }
        $null=Get-RenameDestination $record.Current ([IO.Path]::GetFileName($record.Original)); $i++
    }
    $rollback=@($Activity.Records | ForEach-Object { New-FolderUndo $_.Current }); $done=@()
    try { foreach ($record in $Activity.Records) { $done+=Restore-UndoRecord $record } }
    catch { for ($j=0;$j -lt $done.Count;$j++) { $rollback[$j].Current=$done[$j]; try { $null=Restore-UndoRecord $rollback[$j] } catch {} }; throw }
    for ($j=0;$j -lt $rollback.Count;$j++) { $rollback[$j].Current=$done[$j] }; Save-ReversibleActivity $Activity $rollback $Repeat
    [IO.File]::Delete((Join-Path $root ($(if ($Repeat) { 'ripeti/' } else { 'cronologia/' })+$Activity.Id+'.json')))
    $last=Join-Path $root 'ultima-modifica.json'; if ([IO.File]::Exists($last)) { try { $saved=Get-Content -LiteralPath $last -Raw -Encoding UTF8 | ConvertFrom-Json; $records=if ($saved.Batch) { @($saved.Batch) } else { @($saved) }; if ((Get-SnapshotSignature $records) -eq (Get-SnapshotSignature @($Activity.Records))) { [IO.File]::Delete($last) } } catch {} }
    if ($Repeat) { Save-FolderUndo ([pscustomobject]@{Batch=$rollback}) }; return $done
}
function Read-PersonalizedFolders {
    foreach ($file in (Get-ChildItem -LiteralPath $root -Filter '*.json' -File)) {
        if ($file.Name -notmatch '^[a-f0-9]{64}\.json$') { continue }
        try { $entry=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json; if ([IO.Directory]::Exists($entry.Folder)) { $icon=Get-FolderIconPath $entry.Folder; if ($icon) { [pscustomobject]@{Name=[IO.Path]::GetFileName($entry.Folder);Path=$entry.Folder;Icon=$icon} } } } catch {}
    }
}
function Get-FolderIconPath([string]$Path) {
    $ini=Join-Path $Path 'desktop.ini'; if (![IO.File]::Exists($ini)) { return '' }
    $match=[regex]::Match([IO.File]::ReadAllText($ini),'(?im)^IconResource\s*=\s*(.+),\s*0\s*$')
    if ($match.Success) { $icon=$match.Groups[1].Value.Trim().Trim('"'); if ($icon.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -and [IO.File]::Exists($icon)) { return $icon } }; return ''
}
function Convert-ProductBitmap([Drawing.Bitmap]$Bitmap) {
    $stream=[IO.MemoryStream]::new(); try { $Bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png); $stream.Position=0; $image=[Windows.Media.Imaging.BitmapImage]::new(); $image.BeginInit(); $image.CacheOption='OnLoad'; $image.StreamSource=$stream; $image.EndInit(); $image.Freeze(); return $image } finally { $stream.Dispose() }
}
function Read-IconFrame([string]$Path,[int]$Size) {
    $bytes=[IO.File]::ReadAllBytes($Path); if ($bytes.Length -lt 22 -or [BitConverter]::ToUInt16($bytes,2) -ne 1) { throw (T 'pngError') }; $count=[BitConverter]::ToUInt16($bytes,4); $chosen=$null; $distance=[int]::MaxValue
    for ($i=0;$i -lt $count;$i++) { $position=6+$i*16; if ($position+16 -gt $bytes.Length) { throw (T 'pngError') }; $width=if ($bytes[$position]) { [int]$bytes[$position] } else { 256 }; $delta=[Math]::Abs($width-$Size); if ($delta -lt $distance) { $chosen=@([BitConverter]::ToUInt32($bytes,$position+8),[BitConverter]::ToUInt32($bytes,$position+12)); $distance=$delta } }
    if (!$chosen -or $chosen[1]+$chosen[0] -gt $bytes.Length) { throw (T 'pngError') }
    $stream=[IO.MemoryStream]::new($bytes,[int]$chosen[1],[int]$chosen[0],$false); try { $image=[Windows.Media.Imaging.BitmapImage]::new(); $image.BeginInit(); $image.CacheOption='OnLoad'; $image.StreamSource=$stream; $image.EndInit(); $image.Freeze(); return $image } finally { $stream.Dispose() }
}
function New-ProductWindow([string]$Title,[int]$Width=450,[int]$Height=440) {
    $dialog=[Windows.Window]::new(); $dialog.Title=$Title; $dialog.Width=$Width; $dialog.Height=$Height; $dialog.MinWidth=350; $dialog.MinHeight=280; $dialog.Owner=$window; $dialog.WindowStartupLocation='CenterOwner'; $dialog.Resources.MergedDictionaries.Add($window.Resources); $dialog.FontFamily=$window.FontFamily; $dialog.FontSize=13; $dialog.Background=$window.Resources['Page']; $dialog.Foreground=$window.Resources['Text']; $dialog.FlowDirection=$window.FlowDirection; return $dialog
}
function Select-ProductFolders([string[]]$Targets) {
    $valid=@(); foreach ($target in $Targets) { $item=Get-Item -LiteralPath $target -Force -ErrorAction Stop; if (!$item.PSIsContainer) { throw (T 'folderInvalid') }; $valid+=$item.FullName }; $valid=@($valid | Select-Object -Unique)
    if (!$valid.Count) { throw (T 'folderInvalid') }
    $script:batchTargets=$valid; $script:currentFolder=$valid[0]; $script:singleFolder=$valid[0]; $ui.FolderName.IsEnabled=$valid.Count -eq 1; $ui.RenameFolder.IsEnabled=$valid.Count -eq 1; $ui.FolderName.Text=if ($valid.Count -gt 1) { T 'folderCount' @($valid.Count) } else { [IO.Path]::GetFileName($valid[0]) }; $ui.FolderName.ToolTip=$valid -join [Environment]::NewLine; Update-UndoButton
}
function Apply-CompletePreset($Preset) {
    if ($Preset.Hex -notmatch '^#[0-9A-Fa-f]{6}$' -or $Preset.BadgeHex -notmatch '^#[0-9A-Fa-f]{6}$' -or $Preset.Badge -notin @('none','star','check','lock','heart','document','music','photo')) { throw (T 'colorInvalid') }
    if ($Preset.Png -and ![IO.File]::Exists($Preset.Png)) { throw (T 'pngError') }
    $ui.UseColor.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)); $ui.Hex.Text=$Preset.Hex; if ($Preset.Png) { Set-PngPreview $Preset.Png }; $script:badge=$Preset.Badge; $script:badgeHex=$Preset.BadgeHex; Update-BadgePreview
}
function Show-ProductList([string]$Mode) {
    $dialog=New-ProductWindow (T $Mode) 550 480
    $grid=[Windows.Controls.Grid]::new(); $grid.Margin=[Windows.Thickness]::new(16); foreach ($height in @('*','Auto')) { $row=[Windows.Controls.RowDefinition]::new(); $row.Height=[Windows.GridLengthConverter]::new().ConvertFromString($height); $grid.RowDefinitions.Add($row) }
    $list=[Windows.Controls.ListBox]::new(); $list.HorizontalContentAlignment='Stretch'; $list.Background=[Windows.Media.Brushes]::Transparent; $list.Foreground=$window.Resources['Text']; $list.BorderThickness=[Windows.Thickness]::new(0)
    $template='<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><Grid Margin="4,6"><Grid.ColumnDefinitions><ColumnDefinition Width="42"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Image Source="{Binding Image}" Width="32" Height="32"/><StackPanel Grid.Column="1"><TextBlock Text="{Binding Title}" FontWeight="SemiBold"/><TextBlock Text="{Binding Detail}" FontSize="11" Foreground="{DynamicResource Secondary}" TextWrapping="Wrap"/></StackPanel></Grid></DataTemplate>'
    $list.ItemTemplate=[Windows.Markup.XamlReader]::Parse($template); $surface=[Windows.Controls.Border]::new(); $surface.Background=$window.Resources['Card']; $surface.BorderBrush=$window.Resources['Line']; $surface.BorderThickness=[Windows.Thickness]::new(1); $surface.CornerRadius=[Windows.CornerRadius]::new(12); $surface.Padding=[Windows.Thickness]::new(6); $surface.Child=$list; $grid.Children.Add($surface)|Out-Null
    $buttons=[Windows.Controls.WrapPanel]::new(); $buttons.Margin=[Windows.Thickness]::new(0,12,0,0); [Windows.Controls.Grid]::SetRow($buttons,1); $grid.Children.Add($buttons)|Out-Null
    $empty=[Windows.Controls.TextBlock]::new(); $empty.Text=T 'emptyList'; $empty.HorizontalAlignment='Center'; $empty.VerticalAlignment='Center'; $empty.Foreground=$window.Resources['Secondary']; $empty.IsHitTestVisible=$false; $grid.Children.Add($empty)|Out-Null
    $script:productList=@{Window=$dialog;List=$list;Mode=$Mode;Empty=$empty}; Refresh-ProductList
    $actions=switch($Mode) { 'presets' { @('loadPreset','savePreset','pinPreset','renamePreset','deletePreset') } 'history' { @('undoSelected') } 'redo' { @('redoSelected') } 'managed' { @('openFolder','restoreOriginal') } }
    foreach ($action in $actions) { $button=[Windows.Controls.Button]::new(); $button.Content=T $action; $button.Tag=$action; $button.Margin=[Windows.Thickness]::new(0,0,6,6); $button.Padding=[Windows.Thickness]::new(10,7,10,7); $buttons.Children.Add($button)|Out-Null
        $button.Add_Click({ param($sender,$e) try {
            $selected=$script:productList.List.SelectedItem; if (!$selected -and $sender.Tag -ne 'savePreset') { return }
            switch ([string]$sender.Tag) {
                'loadPreset' { Apply-CompletePreset $selected.Value; $script:productList.Window.Close(); Show-Toast (T 'loadPreset') }
                'savePreset' { $name=Show-AdvancedText (T 'presetName'); if ($name) { $null=Save-CompletePreset $name (Valid-Hex) $script:pngSelection $script:badge $script:badgeHex; Refresh-ProductList } }
                'pinPreset' { Set-PresetFavorite $selected.Value.Id; Refresh-ProductList }
                'redoSelected' { $paths=@(Restore-FolderActivity $selected.Value $true); if ($paths.Count) { Select-ProductFolders $paths }; Refresh-ProductList; Show-Toast (T 'redo') }
                'renamePreset' { $name=Show-AdvancedText (T 'presetName') $selected.Value.Name; if ($name) { $items=@(Read-ProductList 'preset.json'); if (@($items | Where-Object { $_.Id -ne $selected.Value.Id -and $_.Name -eq $name }).Count) { throw (T 'nameExists') }; foreach ($p in $items) { if ($p.Id -eq $selected.Value.Id) { $p.Name=$name } }; Write-AdvancedJson (Join-Path $root 'preset.json') $items; Sync-PresetMenu; Refresh-ProductList } }
                'deletePreset' { Write-AdvancedJson (Join-Path $root 'preset.json') @(Read-ProductList 'preset.json' | Where-Object { $_.Id -ne $selected.Value.Id }); Sync-PresetMenu; Refresh-ProductList }
                'undoSelected' { $paths=@(Restore-FolderActivity $selected.Value); if ($paths.Count) { Select-ProductFolders $paths }; Refresh-ProductList; Show-Toast (T 'restored') }
                'openFolder' { Start-Process -FilePath explorer.exe -ArgumentList ('"'+$selected.Value.Path+'"') }
                'restoreOriginal' { $path=$selected.Value.Path; $before=New-FolderUndo $path; Restore-Folder $path; Save-FolderUndo $before; Save-FolderActivity $before 'restoreOriginal'; Refresh-ProductList; Update-UndoButton; Show-Toast (T 'restored') }
            }
        } catch { [Windows.MessageBox]::Show($_.Exception.Message,$script:productList.Window.Title)|Out-Null } })
    }
    $dialog.Content=$grid
    if ($UITest -and $script:productDialogTest) { $dialog.Add_ContentRendered({ if ($script:productDialogAction -and $script:productList.Mode -eq 'presets') { $script:productList.List.SelectedIndex=0; foreach ($button in $script:productList.Window.Content.Children[1].Children) { if ($button.Tag -eq $script:productDialogAction) { $button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)); break } } }; $script:productDialogCount=$script:productList.List.Items.Count; $script:productList.Window.Close() }) }
    try { [void]$dialog.ShowDialog() } finally { $script:productList=$null }
}
function Refresh-ProductList {
    $items=@(); switch ($script:productList.Mode) {
        'presets' { foreach ($p in @(Read-ProductList 'preset.json')) { $image=$null; $icon=$null; $source=$null; $bitmap=$null; try { if ($p.Png) { $source=[Drawing.Image]::FromFile($p.Png) } else { $path=Join-Path $root ('preset-preview-'+$p.Hex.TrimStart('#')+'.ico'); if (![IO.File]::Exists($path)) { New-ColorIcon $p.Hex $path }; $icon=[Drawing.Icon]::new($path,256,256); $source=$icon.ToBitmap() }; $bitmap=Render-PreparedImage $source 1 0 0 $false $p.Badge $p.BadgeHex; $image=Convert-ProductBitmap $bitmap } catch {} finally { if ($bitmap) { $bitmap.Dispose() }; if ($source) { $source.Dispose() }; if ($icon) { $icon.Dispose() } }; $items+=[pscustomobject]@{Title=$(if ($p.Favorite) { '★ '+$p.Name } else { $p.Name });Detail=$p.Hex+' · '+(T $p.Badge);Image=$image;Value=$p} } }
        { $_ -in @('history','redo') } { $history=if ($script:productList.Mode -eq 'redo') { @(Read-RepeatActivities) } else { @(Read-FolderActivities) }; foreach ($h in $history) { $title=if ($h.Records.Count -gt 1) { T 'folderCount' @($h.Records.Count) } else { [IO.Path]::GetFileName($h.Records[0].Current) }; $items+=[pscustomobject]@{Title=$title+' · '+(T $h.Kind);Detail=([DateTime]::Parse($h.Date).ToLocalTime().ToString('g'))+' · '+$h.Records[0].Current;Image=$null;Value=$h} } }
        'managed' { foreach ($f in @(Read-PersonalizedFolders | Sort-Object Name)) { $image=$null; try { $image=Read-IconFrame $f.Icon 32 } catch {}; $items+=[pscustomobject]@{Title=$f.Name;Detail=$f.Path;Image=$image;Value=$f} } }
    }; $script:productList.List.ItemsSource=[object[]]$items
    $script:productList.Empty.Visibility=if ($items.Count) { 'Collapsed' } else { 'Visible' }
}
function Update-BadgePreview {
    $ui.BadgePreview.Visibility=if ($script:badge -eq 'none') { 'Collapsed' } else { 'Visible' }; $ui.BadgeGlyph.FontFamily='Segoe UI Symbol'; $ui.BadgeGlyph.Text=Get-BadgeGlyph $script:badge; $ui.BadgeGlyph.Foreground=Brush $script:badgeHex
}
function Get-BadgeGlyph([string]$Name) { switch($Name) { 'star' {'★'} 'check' {'✔'} 'lock' {'⚿'} 'heart' {'♥'} 'document' {'▤'} 'music' {'♫'} 'photo' {'▧'} default {''} } }
function Show-BadgePicker {
    $dialog=New-ProductWindow (T 'badge') 380 320; $panel=[Windows.Controls.StackPanel]::new(); $panel.Margin=[Windows.Thickness]::new(18); $tiles=[Windows.Controls.WrapPanel]::new(); $panel.Children.Add($tiles)|Out-Null
    foreach ($name in @('none','star','check','lock','heart','document','music','photo')) { $button=[Windows.Controls.Button]::new(); $button.Tag=$name; $button.ToolTip=T $name; $button.Content=if ($name -eq 'none') { '×' } else { Get-BadgeGlyph $name }; $button.FontFamily='Segoe UI Symbol'; $button.FontSize=24; $button.Width=70; $button.Height=54; $button.Margin=[Windows.Thickness]::new(0,0,6,6); if ($name -eq $script:badge) { $button.BorderBrush=$window.Resources['Accent']; $button.BorderThickness=[Windows.Thickness]::new(2) }; $tiles.Children.Add($button)|Out-Null; $button.Add_Click({param($sender,$e) $script:badge=[string]$sender.Tag; Update-BadgePreview; $script:badgeDialog.Close() }) }
    $label=[Windows.Controls.TextBlock]::new(); $label.Text=T 'badgeColor'; $label.Margin=[Windows.Thickness]::new(0,12,0,5); $panel.Children.Add($label)|Out-Null; $hex=[Windows.Controls.TextBox]::new(); $hex.Text=$script:badgeHex; $hex.FlowDirection='LeftToRight'; $panel.Children.Add($hex)|Out-Null
    $hex.Add_TextChanged({ param($sender,$e) if ($sender.Text -match '^#[0-9A-Fa-f]{6}$') { $script:badgeHex=$sender.Text.ToUpperInvariant(); Update-BadgePreview } }); $dialog.Content=$panel; $script:badgeDialog=$dialog
    if ($UITest -and $script:productDialogTest) { $dialog.Add_ContentRendered({ $script:badgeDialog.Content.Children[2].Text='#CC2255'; $script:badgeDialog.Content.Children[0].Children[4].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }) }
    try { [void]$dialog.ShowDialog() } finally { $script:badgeDialog=$null }
}
function Show-IconSizes {
    $dialog=New-ProductWindow (T 'iconSizes') 430 290; $panel=[Windows.Controls.WrapPanel]::new(); $panel.HorizontalAlignment='Center'; $panel.VerticalAlignment='Center'; $panel.FlowDirection='LeftToRight'
    $prepared=Get-PreparedIcon $script:badge; $path=Join-Path $root ('size-preview-'+[Guid]::NewGuid().ToString('N')+'.ico')
    try { if ($prepared) { New-PngIcon $prepared $path } else { New-ColorIcon (Valid-Hex) $path }
        foreach ($size in @(16,32,48,96)) { $stack=[Windows.Controls.StackPanel]::new(); $stack.Margin=[Windows.Thickness]::new(12); $image=[Windows.Controls.Image]::new(); $image.Source=Read-IconFrame $path $size; $image.Width=$size; $image.Height=$size; $image.VerticalAlignment='Bottom'; $label=[Windows.Controls.TextBlock]::new(); $label.Text=[string]$size+' px'; $label.HorizontalAlignment='Center'; $label.Margin=[Windows.Thickness]::new(0,10,0,0); $stack.Children.Add($image)|Out-Null; $stack.Children.Add($label)|Out-Null; $panel.Children.Add($stack)|Out-Null }
        $dialog.Content=$panel; $script:sizeDialog=$dialog; if ($UITest -and $script:productDialogTest) { $dialog.Add_ContentRendered({ $script:productSizeCount=$script:sizeDialog.Content.Children.Count; $script:sizeDialog.Close() }) }; [void]$dialog.ShowDialog()
    } finally { $script:sizeDialog=$null; if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
}
function Show-VisualSettings {
    $dialog=New-ProductWindow (T 'visualSettings') 380 380; $panel=[Windows.Controls.StackPanel]::new(); $panel.Margin=[Windows.Thickness]::new(20)
    $combo=[Windows.Controls.ComboBox]::new(); foreach ($mode in @('System','Light','Dark')) { $null=$combo.Items.Add((T ('theme'+$mode))) }; $combo.SelectedIndex=@('System','Light','Dark').IndexOf($script:themeMode); $panel.Children.Add($combo)|Out-Null
    foreach ($key in @('glassOpacity','glassDepth')) { $label=[Windows.Controls.TextBlock]::new(); $label.Text=T $key; $label.Margin=[Windows.Thickness]::new(0,16,0,6); $panel.Children.Add($label)|Out-Null; $slider=[Windows.Controls.Slider]::new(); $slider.Minimum=0; $slider.Maximum=100; $slider.Value=if ($key -eq 'glassOpacity') { $script:glassOpacity } else { $script:glassDepth }; $slider.Tag=$key; $panel.Children.Add($slider)|Out-Null; $slider.Add_ValueChanged({ param($sender,$e) if ($sender.Tag -eq 'glassOpacity') { $script:glassOpacity=$sender.Value } else { $script:glassDepth=$sender.Value }; Apply-Appearance $script:appearance }) }
    $combo.Add_SelectionChanged({ param($sender,$e) $script:themeMode=@('System','Light','Dark')[$sender.SelectedIndex]; Update-ProductTheme })
    $button=[Windows.Controls.Button]::new(); $button.Content=T 'save'; $button.Margin=[Windows.Thickness]::new(0,20,0,0); $panel.Children.Add($button)|Out-Null; $button.Add_Click({ try { Save-AppSetting 'theme' $script:themeMode; Save-AppSetting 'glassOpacity' ([string][int]$script:glassOpacity); Save-AppSetting 'glassDepth' ([string][int]$script:glassDepth); $script:visualDialog.DialogResult=$true } catch { Show-Status $_.Exception.Message } }); $dialog.Content=$panel; $script:visualDialog=$dialog
    $previous=@($script:themeMode,$script:glassOpacity,$script:glassDepth)
    if ($UITest -and $script:productDialogTest) { $dialog.Add_ContentRendered({ $script:visualDialog.Content.Children[2].Value=45; $script:visualDialog.Content.Children[4].Value=75; $script:visualDialog.Content.Children[5].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }) }
    try { if (!$dialog.ShowDialog()) { $script:themeMode=$previous[0]; $script:glassOpacity=$previous[1]; $script:glassDepth=$previous[2]; Update-ProductTheme } } finally { $script:visualDialog=$null }
}
function Update-ProductTheme {
    $value=$script:themeMode -eq 'Dark'; if ($script:themeMode -eq 'System') { try { $value=(Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme) -eq 0 } catch {} }
    $script:dark=$value; Apply-Appearance $script:appearance; $hwnd=[Windows.Interop.WindowInteropHelper]::new($window).Handle; if ($hwnd -ne [IntPtr]::Zero) { $mode=[int]$value; [void][FluentWindow]::DwmSetWindowAttribute($hwnd,20,[ref]$mode,4) }
}
function Test-NewProductVersion([string]$Remote,[string]$Local) {
    if ($Remote -notmatch '^\d+\.\d+\.\d+(?:-beta\.\d+)?$' -or $Local -notmatch '^\d+\.\d+\.\d+(?:-beta\.\d+)?$') { throw (T 'updateError') }
    $r=$Remote -split '-beta\.'; $l=$Local -split '-beta\.'; if ([version]$r[0] -ne [version]$l[0]) { return [version]$r[0] -gt [version]$l[0] }; if ($r.Count -eq 1) { return $l.Count -gt 1 }; if ($l.Count -eq 1) { return $false }; return [int]$r[1] -gt [int]$l[1]
}
function Start-ProductUpdateCheck([bool]$Quiet=$false) {
    if ($script:updateTask -and !$script:updateTask.IsCompleted) { return }
    Add-Type -AssemblyName System.Net.Http; if ($script:updateClient) { $script:updateClient.Dispose() }; $script:updateClient=[Net.Http.HttpClient]::new(); $script:updateClient.Timeout=[TimeSpan]::FromSeconds(8); $script:updateQuiet=$Quiet
    $script:updateTask=$script:updateClient.GetStringAsync('https://raw.githubusercontent.com/yn7wvz64hj-oss/CartelleColorate/main/VERSION?check='+[DateTime]::UtcNow.Ticks); if ($script:updateLabel) { $script:updateLabel.Text=T 'checking' }; $script:updateTimer.Start()
}
function Show-UpdateDialog {
    $dialog=New-ProductWindow (T 'updates') 390 300; $panel=[Windows.Controls.StackPanel]::new(); $panel.Margin=[Windows.Thickness]::new(20); $label=[Windows.Controls.TextBlock]::new(); $label.Text='CartelleColorate '+$script:productVersion; $label.TextWrapping='Wrap'; $panel.Children.Add($label)|Out-Null
    $check=[Windows.Controls.CheckBox]::new(); $check.Content=T 'autoUpdates'; $check.IsChecked=(Read-ProductSetting 'checkUpdates' 'false') -eq 'true'; $check.Margin=[Windows.Thickness]::new(0,18,0,18); $panel.Children.Add($check)|Out-Null; $check.Add_Click({param($sender,$e) try { Save-AppSetting 'checkUpdates' ([string]([bool]$sender.IsChecked)).ToLowerInvariant() } catch { Show-Status $_.Exception.Message } })
    $button=[Windows.Controls.Button]::new(); $button.Content=T 'checkNow'; $button.Add_Click({ Start-ProductUpdateCheck $false }); $panel.Children.Add($button)|Out-Null
    $download=[Windows.Controls.Button]::new(); $download.Content=T 'downloadUpdate'; $download.IsEnabled=[bool]$script:availableVersion; $download.Margin=[Windows.Thickness]::new(0,10,0,0); $panel.Children.Add($download)|Out-Null; $download.Add_Click({ if ($script:availableVersion -match '^\d+\.\d+\.\d+(?:-beta\.\d+)?$') { Start-Process ('https://github.com/yn7wvz64hj-oss/CartelleColorate/raw/refs/heads/main/downloads/CartelleColorate-'+$script:availableVersion+'-windows.zip') } })
    $script:updateLabel=$label; $script:updateDownload=$download; $dialog.Content=$panel; $script:updateDialog=$dialog; if ($script:availableVersion) { $label.Text=(T 'updateAvailable')+' '+$script:availableVersion }
    if ($UITest -and $script:productDialogTest) { $dialog.Add_ContentRendered({
        Add-Type -AssemblyName System.Net.Http
        $completion=[Threading.Tasks.TaskCompletionSource[string]]::new(); if ($script:productUpdateFailure) { $completion.SetException([Exception]::new('Offline test')) } else { $completion.SetResult('99.0.0-beta.1') }
        $script:updateTask=$completion.Task; $script:updateClient=[Net.Http.HttpClient]::new(); $script:updateQuiet=$true; $script:updateTimer.Start()
        $script:updateTestTimer=[Windows.Threading.DispatcherTimer]::new(); $script:updateTestTimer.Interval=[TimeSpan]::FromMilliseconds(350); $script:updateTestTimer.Add_Tick({ $script:updateTestTimer.Stop(); $script:productUpdateText=$script:updateLabel.Text; $script:productUpdateEnabled=$script:updateDownload.IsEnabled; $script:updateDialog.Close() }); $script:updateTestTimer.Start()
    }) }
    try { [void]$dialog.ShowDialog() } finally { $script:updateLabel=$null; $script:updateDownload=$null; $script:updateDialog=$null }
}
function Invoke-ProductAction([string]$Action) {
    switch ($Action) { 'backup' { Show-LibraryBackup } 'redo' { Show-ProductList 'redo' } 'presets' { Show-ProductList 'presets' } 'history' { Show-ProductList 'history' } 'managed' { Show-ProductList 'managed' } 'iconSizes' { Show-IconSizes } 'visualSettings' { Show-VisualSettings } 'updates' { Show-UpdateDialog } }
}
function Initialize-ProductInterface {
    $script:appearance=Read-AppearancePreference
    $script:badgeHex='#233755'; $script:themeMode=if ($Theme -ne 'System') { $Theme } else { [string](Read-ProductSetting 'theme' 'System') }; if ($script:themeMode -notin @('System','Light','Dark')) { $script:themeMode='System' }; $script:glassOpacity=[Math]::Max(0,[Math]::Min(100,[double](Read-ProductSetting 'glassOpacity' 55))); $script:glassDepth=[Math]::Max(0,[Math]::Min(100,[double](Read-ProductSetting 'glassDepth' 50))); $script:productVersion=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'VERSION')).Trim()
    $window.AllowDrop=$true
    $window.Add_PreviewDragOver({ param($sender,$e) if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) { $e.Effects=[Windows.DragDropEffects]::Copy; $e.Handled=$true } })
    $window.Add_PreviewDrop({ param($sender,$e) if (!$e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) { return }; $e.Handled=$true; try { $paths=[string[]]$e.Data.GetData([Windows.DataFormats]::FileDrop); Select-ProductFolders $paths; Show-Toast (T 'folderCount' @($paths.Count)) } catch { Show-Status $_.Exception.Message } })
    $script:themeTimer=[Windows.Threading.DispatcherTimer]::new(); $script:themeTimer.Interval=[TimeSpan]::FromSeconds(3); $script:themeTimer.Add_Tick({ if ($script:themeMode -eq 'System') { try { $value=(Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme) -eq 0; if ($value -ne $script:dark) { Update-ProductTheme } } catch {} } }); if (!$UITest -and !$Preview) { $script:themeTimer.Start() }
    $script:updateTimer=[Windows.Threading.DispatcherTimer]::new(); $script:updateTimer.Interval=[TimeSpan]::FromMilliseconds(150); $script:updateTimer.Add_Tick({ if (!$script:updateTask.IsCompleted) { return }; $script:updateTimer.Stop(); try { $remote=$script:updateTask.GetAwaiter().GetResult().Trim(); $new=Test-NewProductVersion $remote $script:productVersion; $text=if ($new) { (T 'updateAvailable')+' '+$remote } else { T 'upToDate' }; if ($new) { $script:availableVersion=$remote }; if ($script:updateLabel) { $script:updateLabel.Text=$text; $script:updateDownload.IsEnabled=$new }; if (!$script:updateQuiet -or $new) { Show-Toast $text } } catch { if ($script:updateLabel) { $script:updateLabel.Text=T 'updateError' }; if (!$script:updateQuiet) { Show-Status (T 'updateError') } } finally { $script:updateClient.Dispose(); $script:updateClient=$null } })
    $window.Add_Closed({ $script:themeTimer.Stop(); $script:updateTimer.Stop(); if ($script:updateClient) { $script:updateClient.CancelPendingRequests(); $script:updateClient.Dispose() } })
    if (!$UITest -and !$Preview -and (Read-ProductSetting 'checkUpdates' 'false') -eq 'true') { Start-ProductUpdateCheck $true }; Update-ProductTheme
}
function Test-ProductBackend {
    if (!(Test-NewProductVersion '0.8.0-beta.1' '0.7.0-beta.1') -or (Test-NewProductVersion '0.8.0-beta.1' '0.8.0') -or !(Test-NewProductVersion '0.8.0' '0.8.0-beta.2') -or (Test-NewProductVersion '0.8.0-beta.2' '0.8.0-beta.3')) { throw 'Version comparison failed' }
    $target=Join-Path $root 'History test'; [IO.Directory]::CreateDirectory($target)|Out-Null
    $before=New-FolderUndo $target; Set-FolderColor $target '#1267AA'; Save-FolderActivity $before 'apply'; $first=@(Read-FolderActivities)[0]
    if (!@((Read-PersonalizedFolders) | Where-Object { $_.Path -eq $target }).Count) { throw 'Managed folder missing' }
    $second=New-FolderUndo $target; Set-FolderColor $target '#AA6712'; Save-FolderActivity $second 'apply'; $recent=@(Read-FolderActivities)[0]
    $conflict=$false; try { $null=Restore-FolderActivity $first } catch { $conflict=$true }; if (!$conflict) { throw 'Old history overwrites newer changes' }
    $null=Restore-FolderActivity $recent; $null=Restore-FolderActivity $first
    if ([IO.File]::Exists((Join-Path $target 'desktop.ini')) -or @((Read-PersonalizedFolders) | Where-Object { $_.Path -eq $target }).Count) { throw 'History restoration incomplete' }
    $bitmap=[Drawing.Bitmap]::new(64,64); $graphics=[Drawing.Graphics]::FromImage($bitmap); try { $graphics.Clear([Drawing.Color]::Blue); $png=Join-Path $root 'preset-source.png'; $bitmap.Save($png,[Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
    $preset=Save-CompletePreset '日本語 Test' '#123456' $png 'heart' '#CC2255'; $moved=$png+'.moved'; if ([IO.File]::Exists($moved)) { [IO.File]::Delete($moved) }; [IO.File]::Move($png,$moved)
    $loaded=@(Read-ProductList 'preset.json' | Where-Object { $_.Id -eq $preset.Id })[0]; if (!$loaded -or ![IO.File]::Exists($loaded.Png) -or $loaded.Badge -ne 'heart' -or $loaded.BadgeHex -ne '#CC2255') { throw 'PNG preset depends on source' }
    Write-AdvancedJson (Join-Path $root 'empty-products.json') @(); if (@(Read-ProductList 'empty-products.json').Count) { throw 'Empty array roundtrip failed' }
    $source=[Drawing.Image]::FromFile($loaded.Png); try { foreach ($name in @('star','check','lock','heart','document','music','photo')) { $rendered=Render-PreparedImage $source 1 0 0 $false $name '#FF0000'; try { $colored=0; for ($y=178;$y -lt 240;$y+=2) { for ($x=178;$x -lt 240;$x+=2) { $pixel=$rendered.GetPixel($x,$y); if ($pixel.R -gt 180 -and $pixel.G -lt 100 -and $pixel.B -lt 100) { $colored++ } } }; if ($colored -lt 3) { throw ('Badge missing: '+$name) } } finally { $rendered.Dispose() } } } finally { $source.Dispose() }
    Write-Output 'OK: cronologia protetta, ripristino, inventario, preset PNG indipendente, sette simboli colorati e confronto aggiornamenti.'
}
function Test-ProductInterface([string]$Png) {
    $script:productDialogTest=$true; $originalHex=$ui.Hex.Text; $originalBadge=$script:badge; $originalBadgeHex=$script:badgeHex; $originalTheme=$script:themeMode; $originalOpacity=$script:glassOpacity; $originalDepth=$script:glassDepth
    try {
        $preset=Save-CompletePreset 'UI preset' '#AC1234' $Png 'music' '#11CC33'; Apply-CompletePreset $preset
        if ($script:pngSelection -ne $preset.Png -or $script:badge -ne 'music' -or $ui.BadgeGlyph.Text -ne '♫') { throw 'Preset application failed' }
        Show-ProductList 'presets'; if ($script:productDialogCount -lt 1) { throw 'Preset dialog empty' }
        Show-BadgePicker; if ($script:badge -ne 'heart' -or $script:badgeHex -ne '#CC2255') { throw 'Badge picker failed' }
        Show-IconSizes; if ($script:productSizeCount -ne 4) { throw 'Size preview missing' }
        Show-VisualSettings; if ($script:glassOpacity -ne 45 -or $script:glassDepth -ne 75 -or (Read-ProductSetting 'glassOpacity' 0) -ne '45') { throw 'Glass preference failed' }
        Show-UpdateDialog; if (!$script:productUpdateText.Contains('99.0.0-beta.1') -or !$script:productUpdateEnabled) { throw 'Async update check failed' }
        $script:availableVersion=$null; $script:productUpdateFailure=$true; Show-UpdateDialog; if ($script:productUpdateText -ne (T 'updateError') -or $script:productUpdateEnabled) { throw 'Offline update handling failed' }; $script:productUpdateFailure=$false
        $targets=@((Join-Path $root 'Drop A'),(Join-Path $root 'Drop B')); foreach ($path in $targets) { [IO.Directory]::CreateDirectory($path)|Out-Null }; $old=$script:currentFolder
        Select-ProductFolders $targets; if ($script:batchTargets.Count -ne 2 -or $ui.RenameFolder.IsEnabled -or !$window.AllowDrop) { throw 'Dropped folders selection failed' }
        $rejected=$false; try { Select-ProductFolders @($targets[0],$Png) } catch { $rejected=$true }; if (!$rejected -or $script:batchTargets.Count -ne 2) { throw 'Mixed drop changes target' }
        Select-ProductFolders @($old); Show-ProductList 'history'; Show-ProductList 'managed'
    } finally { $script:productDialogTest=$false; $script:badge=$originalBadge; $script:badgeHex=$originalBadgeHex; Update-BadgePreview; $ui.UseColor.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)); $ui.Hex.Text=$originalHex; $script:themeMode=$originalTheme; $script:glassOpacity=$originalOpacity; $script:glassDepth=$originalDepth; Save-AppSetting 'theme' $originalTheme; Save-AppSetting 'glassOpacity' ([string][int]$originalOpacity); Save-AppSetting 'glassDepth' ([string][int]$originalDepth); Update-ProductTheme }
}

. (Join-Path $PSScriptRoot 'Enhancements.ps1')
