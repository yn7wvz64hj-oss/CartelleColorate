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
    $dialog=[Windows.Window]::new(); $dialog.Title=$Title; $dialog.Width=$Width; $dialog.Height=$Height; $dialog.MinWidth=350; $dialog.MinHeight=280; $dialog.Owner=$window; $dialog.WindowStartupLocation='CenterOwner'; $dialog.Resources.MergedDictionaries.Add($window.Resources); $dialog.FontFamily=$window.FontFamily; $dialog.FontSize=13; $dialog.Background=$window.Resources['Page']; $dialog.Foreground=$window.Resources['Text']; $dialog.FlowDirection=$window.FlowDirection; Set-AdaptiveWindow $dialog; $dialog.Add_PreviewKeyDown({ param($sender,$e) if ($e.Key -eq [Windows.Input.Key]::Escape) { $sender.Close(); $e.Handled=$true } }); return $dialog
}
function Select-ProductFolders([string[]]$Targets) {
    $valid=@(); foreach ($target in $Targets) { $item=Get-Item -LiteralPath $target -Force -ErrorAction Stop; if (!$item.PSIsContainer) { throw (T 'folderInvalid') }; $valid+=$item.FullName }; $valid=@($valid | Select-Object -Unique)
    if (!$valid.Count) { throw (T 'folderInvalid') }
    Assert-ProBatch $valid.Count
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
    $rowStyle=[Windows.Style]::new([Windows.Controls.ListBoxItem],$window.Resources[[Windows.Controls.ListBoxItem]]); $rowStyle.Setters.Add([Windows.Setter]::new([Windows.FrameworkElement]::MaxWidthProperty,[double]::PositiveInfinity)); $list.ItemContainerStyle=$rowStyle
    $list.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="ListBox"><ScrollViewer CanContentScroll="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><ItemsPresenter/></ScrollViewer></ControlTemplate>')
    [Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($list,$true); [Windows.Controls.VirtualizingPanel]::SetVirtualizationMode($list,[Windows.Controls.VirtualizationMode]::Recycling)

    $template='<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><Grid Margin="4,6"><Grid.ColumnDefinitions><ColumnDefinition Width="42"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Image Source="{Binding Image}" Width="32" Height="32"/><StackPanel Grid.Column="1"><TextBlock Text="{Binding Title}" FontWeight="SemiBold"/><TextBlock Text="{Binding Detail}" FontSize="11" Foreground="{DynamicResource Secondary}" TextWrapping="Wrap"/></StackPanel></Grid></DataTemplate>'
    $list.ItemTemplate=[Windows.Markup.XamlReader]::Parse($template); $surface=[Windows.Controls.Border]::new(); $surface.Background=$window.Resources['Card']; $surface.BorderBrush=$window.Resources['Line']; $surface.BorderThickness=[Windows.Thickness]::new(1); $surface.CornerRadius=[Windows.CornerRadius]::new(12); $surface.Padding=[Windows.Thickness]::new(6); $surface.Child=$list; $grid.Children.Add($surface)|Out-Null
    $buttons=[Windows.Controls.WrapPanel]::new(); $buttons.Margin=[Windows.Thickness]::new(0,12,0,0); [Windows.Controls.Grid]::SetRow($buttons,1); $grid.Children.Add($buttons)|Out-Null
    $empty=[Windows.Controls.TextBlock]::new(); $empty.Text=T 'emptyList'; $empty.HorizontalAlignment='Center'; $empty.VerticalAlignment='Center'; $empty.Foreground=$window.Resources['Secondary']; $empty.IsHitTestVisible=$false; $grid.Children.Add($empty)|Out-Null
    $search=$null
    if ($Mode -eq 'presets') {
        $header=[Windows.Controls.RowDefinition]::new(); $header.Height=[Windows.GridLength]::Auto; $grid.RowDefinitions.Insert(0,$header)
        [Windows.Controls.Grid]::SetRow($surface,1); [Windows.Controls.Grid]::SetRow($empty,1); [Windows.Controls.Grid]::SetRow($buttons,2)
        $search=[Windows.Controls.TextBox]::new(); $search.ToolTip=T 'searchPresets'; [Windows.Automation.AutomationProperties]::SetName($search,(T 'searchPresets')); $search.Margin=[Windows.Thickness]::new(0); $searchGrid=[Windows.Controls.Grid]::new(); $searchGrid.Margin=[Windows.Thickness]::new(0,0,0,10); $searchGrid.Children.Add($search)|Out-Null; $hint=[Windows.Controls.TextBlock]::new(); $hint.Text=T 'searchPresets'; $hint.Foreground=$window.Resources['Secondary']; $hint.Margin=[Windows.Thickness]::new(12,0,12,0); $hint.VerticalAlignment='Center'; $hint.IsHitTestVisible=$false; $searchGrid.Children.Add($hint)|Out-Null; $grid.Children.Add($searchGrid)|Out-Null
        $search.Add_TextChanged({ param($sender,$e) $sender.Parent.Children[1].Visibility=if ($sender.Text) { 'Collapsed' } else { 'Visible' }; if ($script:productList) { Refresh-ProductList $false } })
    }
    $script:productList=@{Window=$dialog;List=$list;Mode=$Mode;Empty=$empty;Search=$search}; Refresh-ProductList
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
    if ($UITest -and $script:productDialogTest) { $dialog.Add_ContentRendered({ if ($script:productList.Mode -eq 'presets') { Test-RefinementList }; if ($script:productDialogAction -and $script:productList.Mode -eq 'presets') { $script:productList.List.SelectedIndex=0; if ($script:productDialogId) { foreach ($row in $script:productList.List.Items) { if ($row.Value.Id -eq $script:productDialogId) { $script:productList.List.SelectedItem=$row; break } } }; foreach ($button in (Get-DialogContent $script:productList.Window).Children[1].Children) { if ($button.Tag -eq $script:productDialogAction) { $button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)); break } } }; $script:productDialogCount=$script:productList.List.Items.Count; $script:productList.Window.Close() }) }
    try { [void](Show-AdaptiveDialog $dialog) } finally { if ($script:presetPreviewTimer) { $script:presetPreviewTimer.Stop() }; $script:productList=$null }
}
function Refresh-ProductList([bool]$Reload=$true) {
    $items=@(); switch ($script:productList.Mode) {
        'presets' {
            if ($Reload -or $null -eq $script:productList.Presets) { $script:productList.Presets=@(Read-ProductList 'preset.json' | Sort-Object @{Expression={[bool]$_.Favorite};Descending=$true},Name) }; $query=$script:productList.Search.Text.Trim()
            foreach ($p in $script:productList.Presets) {
                if ($query -and $p.Name.IndexOf($query,[StringComparison]::CurrentCultureIgnoreCase) -lt 0 -and $p.Hex.IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
                $items+=[pscustomobject]@{Title=$(if ($p.Favorite) { '★ '+$p.Name } else { $p.Name });Detail=$p.Hex+' · '+(T $p.Badge);Image=$null;Value=$p}
            }
        }
        { $_ -in @('history','redo') } { $history=if ($script:productList.Mode -eq 'redo') { @(Read-RepeatActivities) } else { @(Read-FolderActivities) }; foreach ($h in $history) { $title=if ($h.Records.Count -gt 1) { T 'folderCount' @($h.Records.Count) } else { [IO.Path]::GetFileName($h.Records[0].Current) }; $items+=[pscustomobject]@{Title=$title+' · '+(T $h.Kind);Detail=([DateTime]::Parse($h.Date).ToLocalTime().ToString('g'))+' · '+$h.Records[0].Current;Image=$null;Value=$h} } }
        'managed' { foreach ($f in @(Read-PersonalizedFolders | Sort-Object Name)) { $image=$null; try { $image=Read-IconFrame $f.Icon 32 } catch {}; $items+=[pscustomobject]@{Title=$f.Name;Detail=$f.Path;Image=$image;Value=$f} } }
    }; $rows=[Collections.ObjectModel.ObservableCollection[object]]::new(); foreach ($row in $items) { $rows.Add($row) }; $script:productList.List.ItemsSource=$rows
    $script:productList.Empty.Visibility=if ($items.Count) { 'Collapsed' } else { 'Visible' }
    if ($script:productList.Mode -eq 'presets') { Start-PresetPreviews }

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
    if ($UITest -and $script:productDialogTest) { $dialog.Add_ContentRendered({ (Get-DialogContent $script:badgeDialog).Children[2].Text='#CC2255'; (Get-DialogContent $script:badgeDialog).Children[0].Children[4].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }) }
    try { [void](Show-AdaptiveDialog $dialog) } finally { $script:badgeDialog=$null }
}
function Show-IconSizes {
    $dialog=New-ProductWindow (T 'iconSizes') 430 290; $panel=[Windows.Controls.WrapPanel]::new(); $panel.HorizontalAlignment='Center'; $panel.VerticalAlignment='Center'; $panel.FlowDirection='LeftToRight'
    $prepared=Get-PreparedIcon $script:badge; $path=Join-Path $root ('size-preview-'+[Guid]::NewGuid().ToString('N')+'.ico')
    try { if ($prepared) { New-PngIcon $prepared $path } else { New-ColorIcon (Valid-Hex) $path }
        foreach ($size in @(16,32,48,96)) { $stack=[Windows.Controls.StackPanel]::new(); $stack.Margin=[Windows.Thickness]::new(12); $image=[Windows.Controls.Image]::new(); $image.Source=Read-IconFrame $path $size; $image.Width=$size; $image.Height=$size; $image.VerticalAlignment='Bottom'; $label=[Windows.Controls.TextBlock]::new(); $label.Text=[string]$size+' px'; $label.HorizontalAlignment='Center'; $label.Margin=[Windows.Thickness]::new(0,10,0,0); $stack.Children.Add($image)|Out-Null; $stack.Children.Add($label)|Out-Null; $panel.Children.Add($stack)|Out-Null }
        $dialog.Content=$panel; $script:sizeDialog=$dialog; if ($UITest -and $script:productDialogTest) { $dialog.Add_ContentRendered({ $script:productSizeCount=(Get-DialogContent $script:sizeDialog).Children.Count; $script:sizeDialog.Close() }) }; [void](Show-AdaptiveDialog $dialog)
    } finally { $script:sizeDialog=$null; if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
}
function Show-VisualSettings {
    $dialog=New-ProductWindow (T 'visualSettings') 380 470; $panel=[Windows.Controls.StackPanel]::new(); $panel.Margin=[Windows.Thickness]::new(20)
    $combo=[Windows.Controls.ComboBox]::new(); foreach ($mode in @('System','Light','Dark')) { $null=$combo.Items.Add((T ('theme'+$mode))) }; $combo.SelectedIndex=@('System','Light','Dark').IndexOf($script:themeMode); $panel.Children.Add($combo)|Out-Null
    foreach ($key in @('glassOpacity','glassDepth')) { $label=[Windows.Controls.TextBlock]::new(); $label.Text=T $key; $label.Margin=[Windows.Thickness]::new(0,16,0,6); $panel.Children.Add($label)|Out-Null; $slider=[Windows.Controls.Slider]::new(); $slider.Minimum=0; $slider.Maximum=100; $slider.Value=if ($key -eq 'glassOpacity') { $script:glassOpacity } else { $script:glassDepth }; $slider.Tag=$key; $panel.Children.Add($slider)|Out-Null; $slider.Add_ValueChanged({ param($sender,$e) if ($sender.Tag -eq 'glassOpacity') { $script:glassOpacity=$sender.Value } else { $script:glassDepth=$sender.Value }; Apply-Appearance $script:appearance }) }
    $combo.Add_SelectionChanged({ param($sender,$e) $script:themeMode=@('System','Light','Dark')[$sender.SelectedIndex]; Update-ProductTheme })
    $auto=[Windows.Controls.CheckBox]::new(); $auto.Content=T 'autoUpdates'; $auto.Margin=[Windows.Thickness]::new(0,18,0,0); $auto.IsChecked=(Read-ProductSetting 'checkUpdates' 'true') -eq 'true'; $panel.Children.Add($auto)|Out-Null
    $button=[Windows.Controls.Button]::new(); $button.Content=T 'save'; $button.Margin=[Windows.Thickness]::new(0,20,0,0); $panel.Children.Add($button)|Out-Null; $button.Add_Click({ try { Save-AppSetting 'theme' $script:themeMode; Save-AppSetting 'glassOpacity' ([string][int]$script:glassOpacity); Save-AppSetting 'glassDepth' ([string][int]$script:glassDepth); $enabled=[bool](Get-DialogContent $script:visualDialog).Children[5].IsChecked; Save-AppSetting 'checkUpdates' ([string]$enabled).ToLowerInvariant(); if ($enabled -and !$UITest -and !$Preview) { Start-ProductUpdateCheck $true }; $script:visualDialog.DialogResult=$true } catch { Show-Status $_.Exception.Message } }); $dialog.Content=$panel; $script:visualDialog=$dialog
    $reset=[Windows.Controls.Button]::new(); $reset.Content=T 'resetAppearance'; $reset.Margin=[Windows.Thickness]::new(0,8,0,0); $panel.Children.Add($reset)|Out-Null; $reset.Add_Click({ try { Reset-VisualAppearance; $script:visualDialog.DialogResult=$true } catch { Show-Status $_.Exception.Message } })
    $previous=@($script:themeMode,$script:glassOpacity,$script:glassDepth)
    if ($UITest -and $script:productDialogTest) { $dialog.Add_ContentRendered({ (Get-DialogContent $script:visualDialog).Children[2].Value=45; (Get-DialogContent $script:visualDialog).Children[4].Value=75; (Get-DialogContent $script:visualDialog).Children[6].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }) }
    try { if (!(Show-AdaptiveDialog $dialog)) { $script:themeMode=$previous[0]; $script:glassOpacity=$previous[1]; $script:glassDepth=$previous[2]; Update-ProductTheme } } finally { $script:visualDialog=$null }
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
    $dialog=New-ProductWindow (T 'updates') 440 530; $panel=[Windows.Controls.StackPanel]::new(); $panel.Margin=[Windows.Thickness]::new(20); $label=[Windows.Controls.TextBlock]::new(); $label.Text='CartelleColorate '+$script:productVersion; $label.TextWrapping='Wrap'; $panel.Children.Add($label)|Out-Null
    $check=[Windows.Controls.CheckBox]::new(); $check.Content=T 'autoUpdates'; $check.IsChecked=(Read-ProductSetting 'checkUpdates' 'true') -eq 'true'; $check.Margin=[Windows.Thickness]::new(0,18,0,18); $panel.Children.Add($check)|Out-Null; $check.Add_Click({param($sender,$e) try { Save-AppSetting 'checkUpdates' ([string]([bool]$sender.IsChecked)).ToLowerInvariant() } catch { Show-Status $_.Exception.Message } })
    $button=[Windows.Controls.Button]::new(); $button.Content=T 'checkNow'; $button.Add_Click({ Start-ProductUpdateCheck $false }); $panel.Children.Add($button)|Out-Null
    $download=[Windows.Controls.Button]::new(); $download.Content=T 'autoUpdate'; $download.IsEnabled=[bool]$script:availableVersion; $download.Margin=[Windows.Thickness]::new(0,10,0,0); $panel.Children.Add($download)|Out-Null; $download.Add_Click({ Invoke-GuidedDownload })
    $script:updateLabel=$label; $script:updateDownload=$download; $dialog.Content=$panel; $script:updateDialog=$dialog; if ($script:availableVersion) { $label.Text=(T 'updateAvailable')+' '+$script:availableVersion }
    Initialize-GuidedUpdate $dialog $panel
    if ($UITest -and $script:productDialogTest) { $dialog.Add_ContentRendered({
        Add-Type -AssemblyName System.Net.Http
        $completion=[Threading.Tasks.TaskCompletionSource[string]]::new(); if ($script:productUpdateFailure) { $completion.SetException([Exception]::new('Offline test')) } else { $completion.SetResult('99.0.0-beta.1') }
        $script:updateTask=$completion.Task; $script:updateClient=[Net.Http.HttpClient]::new(); $script:updateQuiet=$true; $script:updateTimer.Start()
        $script:updateTestTimer=[Windows.Threading.DispatcherTimer]::new(); $script:updateTestTimer.Interval=[TimeSpan]::FromMilliseconds(350); $script:updateTestTimer.Add_Tick({ $script:updateTestTimer.Stop(); $script:productUpdateText=$script:updateLabel.Text; $script:productUpdateEnabled=$script:updateDownload.IsEnabled; $script:updateDialog.Close() }); $script:updateTestTimer.Start()
    }) }
    try { [void](Show-AdaptiveDialog $dialog) } finally { Stop-GuidedUpdate; $script:updateLabel=$null; $script:updateDownload=$null; $script:updateDialog=$null }
}
function Invoke-ProductAction([string]$Action) {
    switch ($Action) { 'background' { Show-BackgroundDialog } 'backup' { Show-LibraryBackup } 'redo' { Show-ProductList 'redo' } 'presets' { Show-ProductList 'presets' } 'history' { Show-ProductList 'history' } 'managed' { Show-ProductList 'managed' } 'iconSizes' { Show-IconSizes } 'visualSettings' { Show-VisualSettings } 'updates' { Show-UpdateDialog } }
}
function Initialize-ProductInterface {
    $script:appearance=Read-AppearancePreference
    $script:badgeHex='#233755'; $script:themeMode=if ($Theme -ne 'System') { $Theme } else { [string](Read-ProductSetting 'theme' 'System') }; if ($script:themeMode -notin @('System','Light','Dark')) { $script:themeMode='System' }; $script:glassOpacity=[Math]::Max(0,[Math]::Min(100,[double](Read-ProductSetting 'glassOpacity' 55))); $script:glassDepth=[Math]::Max(0,[Math]::Min(100,[double](Read-ProductSetting 'glassDepth' 50))); $script:productVersion=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'VERSION')).Trim()
    $window.AllowDrop=$true
    $window.Add_PreviewDragOver({ param($sender,$e)
        if (!$e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) { return }
        $paths=[string[]]$e.Data.GetData([Windows.DataFormats]::FileDrop)
        $e.Effects=if (Test-ProductDrop $paths) { [Windows.DragDropEffects]::Copy } else { [Windows.DragDropEffects]::None }; $e.Handled=$true
    })
    $window.Add_PreviewDrop({ param($sender,$e)
        if (!$e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) { return }; $e.Handled=$true
        try { Invoke-ProductDrop ([string[]]$e.Data.GetData([Windows.DataFormats]::FileDrop)) } catch { Show-Status $_.Exception.Message }
    })
    Initialize-PngLoader
    $script:themeTimer=[Windows.Threading.DispatcherTimer]::new(); $script:themeTimer.Interval=[TimeSpan]::FromSeconds(3); $script:themeTimer.Add_Tick({ if ($script:themeMode -eq 'System') { try { $value=(Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme) -eq 0; if ($value -ne $script:dark) { Update-ProductTheme } } catch {} } }); if (!$UITest -and !$Preview) { $script:themeTimer.Start() }
    $script:updateTimer=[Windows.Threading.DispatcherTimer]::new(); $script:updateTimer.Interval=[TimeSpan]::FromMilliseconds(150); $script:updateTimer.Add_Tick({ if (!$script:updateTask.IsCompleted) { return }; $script:updateTimer.Stop(); try { $remote=$script:updateTask.GetAwaiter().GetResult().Trim(); $new=Test-NewProductVersion $remote $script:productVersion; $text=if ($new) { (T 'updateAvailable')+' '+$remote } else { T 'upToDate' }; if ($new) { $script:availableVersion=$remote } else { $script:availableVersion=$null }; Sync-UpdateButton; Refresh-GuidedRelease; if ($script:updateLabel) { $script:updateLabel.Text=$text; $script:updateDownload.IsEnabled=$new }; if (!$script:updateQuiet) { Show-Toast $text } } catch { if ($script:updateLabel) { $script:updateLabel.Text=T 'updateError' }; if (!$script:updateQuiet) { Show-Status (T 'updateError') } } finally { $script:updateClient.Dispose(); $script:updateClient=$null } })
    $window.Add_Closed({ $script:themeTimer.Stop(); $script:updateTimer.Stop(); if ($script:updateClient) { $script:updateClient.CancelPendingRequests(); $script:updateClient.Dispose() } })
    if (!$UITest -and !$Preview -and (Read-ProductSetting 'checkUpdates' 'true') -eq 'true') { Start-ProductUpdateCheck $true }; Update-ProductTheme
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
        $null=Save-CompletePreset 'UI color preset' '#00AACC' '' 'check' '#123456'
        Show-ProductList 'presets'; if ($script:productDialogCount -lt 1) { throw 'Preset dialog empty' }
        Test-PngDropInterface $Png
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

function Initialize-ProPreview { $script:proEdition=[pscustomobject]@{Mode='Free';LegacyBatch=$true} }
function Assert-ProBatch([int]$Count) { }
function Get-ProFolderPreview([string]$Base,[string]$Pattern='*',[string]$Exclude='') {
    $queue=[Collections.Generic.Queue[string]]::new(); $queue.Enqueue((Get-Item -LiteralPath $Base -ErrorAction Stop).FullName)
    $results=@(); while ($queue.Count) {
        $directory=$queue.Dequeue(); foreach ($child in @(Get-ChildItem -LiteralPath $directory -Directory -ErrorAction Stop)) {
            if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if ($Exclude -and $child.Name -like $Exclude) { continue }
            $queue.Enqueue($child.FullName); if ($child.Name -like $Pattern) { $results+=$child.FullName }
            if ($results.Count -gt 5000) { throw 'Anteprima troppo grande: restringi la cartella o il filtro.' }
        }
    }; return $results
}
function Show-ProPreview {
    Initialize-ProPreview
    $dialog=New-ProductWindow 'Seleziona sottocartelle' 490 610
    $panel=[Windows.Controls.StackPanel]::new(); $panel.Margin=[Windows.Thickness]::new(18)
    $label=[Windows.Controls.TextBlock]::new(); $label.Text='Sottocartelle: filtro nome (* e ?). Ctrl+clic per escludere righe.'; $label.Margin=[Windows.Thickness]::new(0,16,0,4); $panel.Children.Add($label)|Out-Null
    $pattern=[Windows.Controls.TextBox]::new(); $pattern.Text=if($script:proPendingOperation){$script:proPendingOperation.Pattern}else{'*'}; $panel.Children.Add($pattern)|Out-Null
    $label=[Windows.Controls.TextBlock]::new(); $label.Text='Escludi cartelle e discendenti (es. Backup*)'; $label.Margin=[Windows.Thickness]::new(0,10,0,4); $panel.Children.Add($label)|Out-Null
    $exclude=[Windows.Controls.TextBox]::new(); if($script:proPendingOperation){$exclude.Text=$script:proPendingOperation.Exclude}; $panel.Children.Add($exclude)|Out-Null
    $preview=[Windows.Controls.ListBox]::new(); $preview.SelectionMode='Multiple'; $preview.Height=100; [Windows.Controls.ScrollViewer]::SetHorizontalScrollBarVisibility($preview,[Windows.Controls.ScrollBarVisibility]::Disabled); $preview.HorizontalContentAlignment='Stretch'; $preview.ItemTemplate=[Windows.Markup.XamlReader]::Parse('<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><TextBlock Text="{Binding}" TextWrapping="Wrap" FontSize="11"/></DataTemplate>'); $rowStyle=[Windows.Style]::new([Windows.Controls.ListBoxItem],$window.Resources[[Windows.Controls.ListBoxItem]]); $rowStyle.Setters.Add([Windows.Setter]::new([Windows.FrameworkElement]::MaxWidthProperty,[double]::PositiveInfinity)); $rowStyle.Setters.Add([Windows.Setter]::new([Windows.Controls.Control]::HorizontalContentAlignmentProperty,[Windows.HorizontalAlignment]::Stretch)); $rowStyle.Setters.Add([Windows.Setter]::new([Windows.FrameworkElement]::MaxWidthProperty,[double]400)); $preview.ItemContainerStyle=$rowStyle; $preview.Margin=[Windows.Thickness]::new(0,12,0,10); $panel.Children.Add($preview)|Out-Null
    $scan=[Windows.Controls.Button]::new(); $scan.Content='Mostra anteprima delle sottocartelle'; $panel.Children.Add($scan)|Out-Null
    $select=[Windows.Controls.Button]::new(); $select.Content='Seleziona le cartelle evidenziate'; $select.Margin=[Windows.Thickness]::new(0,8,0,0); $select.IsEnabled=$false; $panel.Children.Add($select)|Out-Null
    $status=[Windows.Controls.TextBlock]::new(); $status.TextWrapping='Wrap'; $status.Margin=[Windows.Thickness]::new(0,10,0,0); $panel.Children.Add($status)|Out-Null
    $script:proDialog=@{Dialog=$dialog;Scan=$scan;Pattern=$pattern;Exclude=$exclude;Preview=$preview;Select=$select;Status=$status;Targets=@()}
    $scan.Add_Click({ try {
        $script:proDialog.Targets=@(Get-ProFolderPreview $script:currentFolder $script:proDialog.Pattern.Text $script:proDialog.Exclude.Text)
        $script:proDialog.Preview.ItemsSource=$script:proDialog.Targets; $script:proDialog.Preview.SelectAll(); $script:proDialog.Select.IsEnabled=$script:proDialog.Targets.Count -gt 0
        $script:proDialog.Status.Text=([string]$script:proDialog.Targets.Count)+' cartelle. Nessuna icona modificata. Collegamenti esclusi.'
    } catch { $script:proDialog.Select.IsEnabled=$false; $script:proDialog.Status.Text=$_.Exception.Message } })
    $select.Add_Click({try { Select-ProductFolders @($script:proDialog.Preview.SelectedItems); $script:proDialog.Dialog.Close() }catch{$script:proDialog.Status.Text=$_.Exception.Message}})
    $dialog.Content=$panel; Show-AdaptiveDialog $dialog|Out-Null
}



function Update-ProBanner { }
function Assert-ProFeature([string]$Feature) { return $true }
function Save-ProOperation([string]$Name,[string]$Base,[string]$Pattern,[string]$Exclude,[string]$Hex) {
    if (!$Name.Trim() -or $Name.Length -gt 80 -or $Hex -notmatch '^#[a-fA-F0-9]{6}$' -or ![IO.Directory]::Exists($Base)) { throw 'Nome, percorso o colore non valido.' }
    $items=@(Read-ProductList 'pro-operazioni.json' | Where-Object Name -ne $Name.Trim())
    $item=[pscustomobject]@{Name=$Name.Trim();Base=$Base;Pattern=$Pattern;Exclude=$Exclude;Hex=$Hex}
    Write-AdvancedJson (Join-Path $root 'pro-operazioni.json') ($items+@($item))
}
function New-ProProject([string]$Base,[string]$Profile) {
    $names=switch ($Profile) {'Studio'{@('Appunti','Materiale','Consegne')} 'Foto'{@('Originali','Selezionate','Esportate')} default {@('Documenti','Immagini','Fatture')}}
    $colors=@('#477FE7','#45B99A','#E5A044'); $targets=@($names|ForEach-Object{Join-Path $Base $_})
    foreach($path in $targets){if(Test-Path -LiteralPath $path){throw 'Una cartella del profilo esiste gia. Scegli una cartella vuota.'}}
    $created=@(); try {for($i=0;$i -lt $targets.Count;$i++){[IO.Directory]::CreateDirectory($targets[$i])|Out-Null; $created+=$targets[$i]; Set-FolderColor $targets[$i] $colors[$i]}}catch{throw ('Creazione interrotta. Controlla le cartelle create: '+($_.Exception.Message))}
    return $targets
}
function Install-ProCollection([string]$Pack) {
    $colors=if($Pack -eq 'Natura'){@('#268C68','#7AAF54','#CE9E44')}else{@('#507CE0','#9965CF','#E28848')}
    $badges=@('document','photo','star'); for($i=0;$i -lt 3;$i++){$null=Save-CompletePreset ($Pack+' '+($i+1)) $colors[$i] '' $badges[$i] '#FFFFFF'}
}
function Start-ProRule([string]$Base,[string]$Pattern,[string]$Exclude,[string]$Hex) {
    if($Hex -notmatch '^#[a-fA-F0-9]{6}$'){throw 'Colore non valido.'}
    $baseItem=Get-Item -LiteralPath $Base -ErrorAction Stop; if(!$baseItem.PSIsContainer -or ($baseItem.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Percorso della regola non valido.'}
    $script:proRule=[pscustomobject]@{Base=$baseItem.FullName;Pattern=$Pattern;Exclude=$Exclude;Hex=$Hex;Enabled=$true}
    $script:proRuleSeen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($item in Get-ChildItem -LiteralPath $Base -Directory){$null=$script:proRuleSeen.Add($item.FullName)}
    Write-AdvancedJson (Join-Path $root 'pro-regola.json') $script:proRule
    if(!$script:proRuleTimer){$script:proRuleTimer=[Windows.Threading.DispatcherTimer]::new();$script:proRuleTimer.Interval=[TimeSpan]::FromSeconds(4);$script:proRuleTimer.Add_Tick({Invoke-ProRuleTick})}
    $script:proRuleTimer.Start()
}
function Invoke-ProRuleTick {
    if($script:proBatchBusy -or !(Test-ProAccess) -or !$script:proRule.Enabled){return}
    try { $targets=@(); foreach($item in Get-ChildItem -LiteralPath $script:proRule.Base -Directory -ErrorAction Stop){
        if($script:proRuleSeen.Add($item.FullName) -and !($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $item.Name -like $script:proRule.Pattern -and (!$script:proRule.Exclude -or $item.Name -notlike $script:proRule.Exclude)){$targets+=$item.FullName}
    }; if($targets.Count){Invoke-FolderBatch $targets $script:proRule.Hex ''; Show-Toast ('Regola automatica: '+$targets.Count+' cartelle aggiornate.');Update-UndoButton} }
    catch {$script:proRule.Enabled=$false;$script:proRuleTimer.Stop();Show-Status ('Regola sospesa: '+$_.Exception.Message)}
}
function Show-ProTools {
    if(!(Assert-ProFeature 'tools')){return}
    $dialog=New-ProductWindow 'Strumenti' 450 560
    $panel=[Windows.Controls.StackPanel]::new();$panel.Margin=[Windows.Thickness]::new(14);$panel.Children.Add((New-ProBackButton {Invoke-ProToolAction 'close'}))|Out-Null
    $intro=[Windows.Controls.TextBlock]::new();$intro.Text='Scegli uno strumento. Le regole operano soltanto mentre questa app e aperta.';$intro.TextWrapping='Wrap';$panel.Children.Add($intro)|Out-Null
    Add-ProFieldLabel $panel 'Profilo progetto';$selector=[Windows.Controls.ComboBox]::new();foreach($name in @('Lavoro','Studio','Foto')){$selector.Items.Add($name)|Out-Null};$selector.SelectedIndex=0;$selector.Margin=[Windows.Thickness]::new(0,12,0,8);$panel.Children.Add($selector)|Out-Null
    Add-ProFieldLabel $panel 'Filtro dei nomi per regole e operazioni (* e ?)';$rulePattern=[Windows.Controls.TextBox]::new();$rulePattern.Text='Foto*';$rulePattern.ToolTip='Regola: filtro dei nomi';$panel.Children.Add($rulePattern)|Out-Null
    Add-ProFieldLabel $panel 'Nome per salvare l operazione';$name=[Windows.Controls.TextBox]::new();$name.Text='La mia operazione';$name.ToolTip='Nome operazione salvata';$name.Margin=[Windows.Thickness]::new(0,8,0,8);$panel.Children.Add($name)|Out-Null
    Add-ProFieldLabel $panel 'Operazione da caricare';$saved=[Windows.Controls.ComboBox]::new();$saved.ItemsSource=@(Read-ProductList 'pro-operazioni.json');$saved.DisplayMemberPath='Name';$panel.Children.Add($saved)|Out-Null
    $status=[Windows.Controls.TextBlock]::new();$status.TextWrapping='Wrap';$status.Margin=[Windows.Thickness]::new(0,10,0,0)
    $script:proTools=@{Dialog=$dialog;Profile=$selector;Pattern=$rulePattern;Name=$name;Saved=$saved;Status=$status;ConfirmProfile=$false;ConfirmRule=$false}
    foreach($entry in @(
        @('preview','Anteprima modificabile delle cartelle'),@('save','Salva operazione corrente'),@('load','Carica operazione salvata'),@('project','Anteprima e creazione profilo progetto'),@('pack','Aggiungi raccolta Studio'),@('nature','Aggiungi raccolta Natura'),@('rule','Anteprima / attiva regola sulle nuove cartelle'),@('stop','Ferma regola automatica'),@('background','Personalizza lo sfondo')
    )){$button=New-ProListButton $entry[1];$button.Tag=$entry[0];$button.Add_Click({param($sender)Invoke-ProToolAction ([string]$sender.Tag)});$panel.Children.Add($button)|Out-Null}
    $panel.Children.Add($status)|Out-Null;$dialog.Content=$panel;Show-AdaptiveDialog $dialog|Out-Null
}
function Invoke-ProToolAction([string]$Action) {
    $ctx=$script:proTools;try {switch($Action){
        'preview'{Show-ProPreview}
        'save'{Save-ProOperation $ctx.Name.Text $script:currentFolder $ctx.Pattern.Text $(if($script:proDialog){$script:proDialog.Exclude.Text}else{''}) (Valid-Hex);$ctx.Saved.ItemsSource=@(Read-ProductList 'pro-operazioni.json');$ctx.Status.Text='Operazione salvata.'}
        'load'{ $item=$ctx.Saved.SelectedItem;if(!$item){throw 'Scegli una operazione.'};Select-ProductFolders @($item.Base);$ui.Hex.Text=$item.Hex;$ctx.Pattern.Text=$item.Pattern;$script:proPendingOperation=$item;$ctx.Status.Text='Operazione caricata. Apri l''anteprima prima di applicare.'}
        'project'{if(!$ctx.ConfirmProfile -or $ctx.ProjectBase -ne $script:currentFolder -or $ctx.ProjectProfile -ne [string]$ctx.Profile.SelectedItem){$ctx.ConfirmProfile=$true;$ctx.ProjectBase=$script:currentFolder;$ctx.ProjectProfile=[string]$ctx.Profile.SelectedItem;$ctx.Status.Text='Profilo '+$ctx.Profile.SelectedItem+' in '+$script:currentFolder+'. Crea tre cartelle con colori coordinati. Premi ancora per confermare.'}else{$targets=@(New-ProProject $script:currentFolder $ctx.Profile.SelectedItem);$ctx.ConfirmProfile=$false;$ctx.Status.Text='Profilo creato: '+($targets -join ', ')}}
        'pack'{Install-ProCollection 'Studio';$ctx.Status.Text='Raccolta aggiunta ai preset completi: puoi vederla e applicarla dal menu.'}
        'nature'{Install-ProCollection 'Natura';$ctx.Status.Text='Raccolta aggiunta ai preset completi.'}
        'rule'{if(!$ctx.ConfirmRule -or $ctx.RuleBase -ne $script:currentFolder -or $ctx.RulePattern -ne $ctx.Pattern.Text -or $ctx.RuleHex -ne (Valid-Hex)){$ctx.ConfirmRule=$true;$ctx.RuleBase=$script:currentFolder;$ctx.RulePattern=$ctx.Pattern.Text;$ctx.RuleHex=Valid-Hex;$ctx.Status.Text='Regola in '+$script:currentFolder+': nuove cartelle con nome '+$ctx.Pattern.Text+', colore '+(Valid-Hex)+'. Quelle esistenti non cambiano. Premi ancora per attivare.'}else{Start-ProRule $script:currentFolder $ctx.Pattern.Text '' (Valid-Hex);$ctx.ConfirmRule=$false;$ctx.Status.Text='Regola attiva mentre l''app rimane aperta.'}}
        'stop'{if($script:proRuleTimer){$script:proRuleTimer.Stop()};if($script:proRule){$script:proRule.Enabled=$false};$ctx.Status.Text='Regola fermata.'}
        'background'{Show-BackgroundDialog}
        'close'{$ctx.Dialog.Close()}
    }}catch{$ctx.Status.Text=$_.Exception.Message}
}

function New-ProBatchProgress([int]$Total) {
    $dialog=New-ProductWindow 'Operazione sulle cartelle' 380 280;$panel=[Windows.Controls.StackPanel]::new();$panel.Margin=[Windows.Thickness]::new(18)
    $text=[Windows.Controls.TextBlock]::new();$text.Text='Preparazione di '+$Total+' cartelle';$text.TextWrapping='Wrap';$panel.Children.Add($text)|Out-Null
    $bar=[Windows.Controls.ProgressBar]::new();$bar.Minimum=0;$bar.Maximum=$Total;$bar.Height=10;$bar.Margin=[Windows.Thickness]::new(0,16,0,16);$panel.Children.Add($bar)|Out-Null
    $button=[Windows.Controls.Button]::new();$button.Content='Interrompi e annulla il gruppo';$panel.Children.Add($button)|Out-Null
    $script:proProgress=@{Window=$dialog;Text=$text;Bar=$bar;Cancelled=$false;Complete=$false}
    $button.Add_Click({$script:proProgress.Cancelled=$true});$dialog.Add_Closing({if(!$script:proProgress.Complete){$script:proProgress.Cancelled=$true}});$dialog.Content=$panel;$dialog.Show();return $script:proProgress
}

function Test-ProToolsInterface {
    $script:toolsUiChecked=$false;$script:toolsUiFailure=''
    $script:toolsUiTimer=[Windows.Threading.DispatcherTimer]::new();$script:toolsUiTimer.Interval=[TimeSpan]::FromMilliseconds(250)
    $script:toolsUiTimer.Add_Tick({$script:toolsUiTimer.Stop();try{
        $dialog=$script:proTools.Dialog;$dialog.UpdateLayout();$bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$dialog.ActualWidth,[int]$dialog.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($dialog)
        $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create((Join-Path ([IO.Path]::GetDirectoryName($script:Preview)) 'strumenti-pro.png'));try{$encoder.Save($stream)}finally{$stream.Dispose()}
        $script:toolsUiChecked=$true
    }catch{$script:toolsUiFailure=$_.Exception.Message}finally{Invoke-ProToolAction 'close'}})
    try{$script:toolsUiTimer.Start();Show-ProTools;if(!$script:toolsUiChecked -or $script:toolsUiFailure){throw ('Pro tools UI: '+$script:toolsUiFailure)}}finally{$script:toolsUiTimer.Stop()}
    'OK: pagina strumenti Pro e ritorno alla finestra principale.'
}

function Add-ProFieldLabel($Panel,[string]$Text) {
    $label=[Windows.Controls.TextBlock]::new();$label.Text=$Text;$label.TextWrapping='Wrap';$label.FontSize=11;$label.Margin=[Windows.Thickness]::new(0,8,0,4);$Panel.Children.Add($label)|Out-Null
}
function Test-ProProgressInterface {
    $targets=@('Progress A','Progress B','Progress C'|ForEach-Object{Join-Path $root $_});foreach($target in $targets){[IO.Directory]::CreateDirectory($target)|Out-Null}
    $script:cancelProgressTimer=[Windows.Threading.DispatcherTimer]::new();$script:cancelProgressTimer.Interval=[TimeSpan]::FromMilliseconds(1);$script:cancelProgressTimer.Add_Tick({if($script:proProgress){$script:proProgress.Cancelled=$true;$script:cancelProgressTimer.Stop()}})
    $cancelled=$false;try{$script:cancelProgressTimer.Start();Invoke-FolderBatch $targets '#123456' ''}catch{$cancelled=$_.Exception.Message.Contains('interrotta')}finally{$script:cancelProgressTimer.Stop()}
    if(!$cancelled){throw 'Batch cancellation not handled'};foreach($target in $targets){if(Test-Path (Join-Path $target 'desktop.ini')){throw 'Cancelled batch left modified folder'}}
    'OK: interruzione del gruppo e ripristino delle cartelle.'
}



function New-ProBackButton([scriptblock]$Action) {
    $button=[Windows.Controls.Button]::new();$button.Width=30;$button.Height=30;$button.MinHeight=30;$button.HorizontalAlignment='Left';$button.Margin=[Windows.Thickness]::new(0,0,0,8);$button.Padding=[Windows.Thickness]::new(6);$button.Background=[Windows.Media.Brushes]::Transparent;$button.BorderThickness=[Windows.Thickness]::new(0);$button.ToolTip='Torna indietro';[Windows.Automation.AutomationProperties]::SetName($button,'Torna indietro alla finestra principale')
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button"><Border x:Name="Surface" Background="Transparent" Padding="6"><ContentPresenter/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Background" Value="{DynamicResource Hover}"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Surface" Property="BorderBrush" Value="{DynamicResource Accent}"/><Setter TargetName="Surface" Property="BorderThickness" Value="1"/></Trigger></ControlTemplate.Triggers></ControlTemplate>')
    $arrow=[Windows.Shapes.Path]::new();$arrow.Data=[Windows.Media.Geometry]::Parse('M18,12 L6,12 M11,7 L6,12 L11,17');$arrow.Width=16;$arrow.Height=16;$arrow.Stretch='Uniform';$arrow.StrokeThickness=1.8;$arrow.SetResourceReference([Windows.Shapes.Shape]::StrokeProperty,'Text');$button.Content=$arrow;$button.Add_Click($Action);return $button
}
function New-ProListButton([string]$Title) {
    $button=[Windows.Controls.Button]::new();$button.MinHeight=26;$button.Padding=[Windows.Thickness]::new(5,4,5,4);$button.HorizontalContentAlignment='Left';$button.Margin=[Windows.Thickness]::new(0,1,0,0);$button.Background=[Windows.Media.Brushes]::Transparent;$button.BorderThickness=[Windows.Thickness]::new(0)
    $text=[Windows.Controls.TextBlock]::new();$text.Text=([string][char]0x2022)+'  '+$Title;$text.FontSize=12;$text.TextWrapping='Wrap';$button.Content=$text
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button"><Border x:Name="Row" Background="Transparent" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Left"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Row" Property="Background" Value="{DynamicResource Hover}"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Row" Property="BorderBrush" Value="{DynamicResource Accent}"/><Setter TargetName="Row" Property="BorderThickness" Value="1"/></Trigger></ControlTemplate.Triggers></ControlTemplate>');return $button
}


function Test-ProAccess { return $true }
Initialize-ProPreview
