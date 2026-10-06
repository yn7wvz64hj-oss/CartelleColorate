function Write-AdvancedJson([string]$Path,$Data) {
    $temporary=$Path+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
    try { [IO.File]::WriteAllText($temporary,(ConvertTo-Json -InputObject $Data -Depth 12),[Text.UTF8Encoding]::new($true)); if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary,$Path,[NullString]::Value) } else { [IO.File]::Move($temporary,$Path) } }
    finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Read-RecentColors {
    try { $loaded=Get-Content -LiteralPath (Join-Path $root 'recenti.json') -Raw -Encoding UTF8 | ConvertFrom-Json; foreach ($entry in $loaded) { if ($entry -is [string] -and $entry -match '^#[0-9A-Fa-f]{6}$') { $entry } } } catch {}
}
function Save-RecentColor([string]$Hex) {
    $colors=@($Hex.ToUpperInvariant())+@(Read-RecentColors | Where-Object { $_ -ne $Hex } | Select-Object -First 7)
    Write-AdvancedJson (Join-Path $root 'recenti.json') $colors
}
function Invoke-FolderBatch([string[]]$Targets,[string]$Hex,[string]$Png) {
    $unique=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $records=@(); foreach ($target in $Targets) { $entry=Get-Item -LiteralPath $target -Force; if (!$entry.PSIsContainer) { throw (T 'folderInvalid') }; if ($unique.Add($entry.FullName)) { $records+=New-FolderUndo $entry.FullName } }
    if (!$records.Count) { throw (T 'folderInvalid') }
    $path=Join-Path $root 'ultima-modifica.json'; $previous=$null; if ([IO.File]::Exists($path)) { $previous=[IO.File]::ReadAllBytes($path) }
    Save-FolderUndo ([pscustomobject]@{Batch=$records})
    try { foreach ($record in $records) { if ($Png) { Set-FolderPng $record.Current $Png } else { Set-FolderColor $record.Current $Hex } } }
    catch {
        $failure=$_; $rolledBack=$true
        foreach ($record in $records) { try { $null=Restore-UndoRecord $record } catch { $rolledBack=$false } }
        if ($rolledBack) { if ($null -ne $previous) { [IO.File]::WriteAllBytes($path,$previous) } else { [IO.File]::Delete($path) } }
        throw $failure
    }
    Save-FolderActivity ([pscustomobject]@{Batch=$records}) 'apply'
}
function Render-PreparedImage([Drawing.Image]$Source,[double]$Zoom=1,[double]$X=0,[double]$Y=0,[bool]$Crop=$false,[ValidateSet('none','star','check','lock','heart','document','music','photo')][string]$Badge='none',[string]$BadgeHex='#233755') {
    $bitmap=[Drawing.Bitmap]::new(256,256,[Drawing.Imaging.PixelFormat]::Format32bppArgb); $graphics=[Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([Drawing.Color]::Transparent); $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic; $graphics.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $scale=if ($Crop) { 256.0/[Math]::Min($Source.Width,$Source.Height) } else { 256.0/[Math]::Max($Source.Width,$Source.Height) }; $scale*=$Zoom
        $w=[single]($Source.Width*$scale); $h=[single]($Source.Height*$scale)
        $graphics.DrawImage($Source,[Drawing.RectangleF]::new([single]((256-$w)/2+$X*1.28),[single]((256-$h)/2+$Y*1.28),$w,$h))
        if ($Badge -ne 'none') {
            $plate=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(245,245,248,255)); $ink=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml($BadgeHex),7)
            try {
                $graphics.FillEllipse($plate,168,168,78,78)
                if ($Badge -eq 'check') { $graphics.DrawLines($ink,[Drawing.PointF[]]@([Drawing.PointF]::new(184,207),[Drawing.PointF]::new(199,222),[Drawing.PointF]::new(230,189))) }
                elseif ($Badge -eq 'lock') { $graphics.DrawArc($ink,193,185,28,34,180,180); $graphics.DrawRectangle($ink,188,203,38,27) }
                elseif ($Badge -eq 'star') { $points=[Drawing.PointF[]]::new(10); for ($i=0;$i -lt 10;$i++) { $angle=($i*36-90)*[Math]::PI/180; $radius=if ($i%2 -eq 0) { 25 } else { 11 }; $points[$i]=[Drawing.PointF]::new([single](207+[Math]::Cos($angle)*$radius),[single](207+[Math]::Sin($angle)*$radius)) }; $brush=[Drawing.SolidBrush]::new($ink.Color); try { $graphics.FillPolygon($brush,$points) } finally { $brush.Dispose() } }
                elseif ($Badge -in @('heart','document','music','photo')) { $font=[Drawing.Font]::new('Segoe UI Symbol',40,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel); $brush=[Drawing.SolidBrush]::new($ink.Color); $format=[Drawing.StringFormat]::new(); $format.Alignment='Center'; $format.LineAlignment='Center'; try { $graphics.DrawString((Get-BadgeGlyph $Badge),$font,$brush,[Drawing.RectangleF]::new(170,169,74,74),$format) } finally { $font.Dispose(); $brush.Dispose(); $format.Dispose() } }
            } finally { $plate.Dispose(); $ink.Dispose() }
        }
        return $bitmap
    } catch { $bitmap.Dispose(); throw } finally { $graphics.Dispose() }
}
function Show-AdvancedText([string]$Title,[string]$Value='') {
    $dialog=[Windows.Window]::new(); $dialog.Title=$Title; $dialog.Width=350; $dialog.SizeToContent='Height'; $dialog.ResizeMode='NoResize'; $dialog.Owner=$window; $dialog.Resources.MergedDictionaries.Add($window.Resources); $dialog.FontFamily=$window.FontFamily; $dialog.WindowStartupLocation='CenterOwner'; $dialog.Background=$window.Resources['Page']; $dialog.Foreground=$window.Resources['Text']
    $panel=[Windows.Controls.StackPanel]::new(); $panel.Margin=[Windows.Thickness]::new(16); $text=[Windows.Controls.TextBox]::new(); $text.Text=$Value; $text.Margin=[Windows.Thickness]::new(0,0,0,10); $button=[Windows.Controls.Button]::new(); $button.Content=T 'apply'; $button.IsDefault=$true
    $panel.Children.Add($text)|Out-Null; $panel.Children.Add($button)|Out-Null; $dialog.Content=$panel; $script:advancedTextWindow=$dialog; $button.Add_Click({ $script:advancedTextWindow.DialogResult=$true })
    if ($UITest -and $script:advancedDialogTest) { $dialog.Add_ContentRendered({ $script:advancedTextWindow.Content.Children[0].Text='Test collection'; $script:advancedTextWindow.Content.Children[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }) }
    try { if ($dialog.ShowDialog()) { return $text.Text.Trim() }; return $null } finally { $script:advancedTextWindow=$null }
}
function Show-FolderSelection {
    [xml]$markup=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Width="520" Height="460" WindowStartupLocation="CenterOwner">
 <Grid Margin="16"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <Grid Margin="0,0,0,10"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBox Name="Address" Height="32"/><Button Name="Open" Grid.Column="1" Margin="6,0" Padding="10,5"/><Button Name="Up" Grid.Column="2" Content="↑" Padding="10,5"/></Grid>
 <ListBox Name="Folders" Grid.Row="1" SelectionMode="Extended" DisplayMemberPath="Name"/>
 <Button Name="Confirm" Grid.Row="2" Margin="0,10,0,0" Padding="12,8" IsDefault="True"/>
 </Grid>
</Window>
'@
    $dialog=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($markup)); $dialog.Owner=$window; $dialog.Resources.MergedDictionaries.Add($window.Resources); $dialog.FontFamily=$window.FontFamily; $dialog.Title=T 'batch'; $dialog.Background=$window.Resources['Page']; $dialog.Foreground=$window.Resources['Text']; $dialog.FindName('Open').Content=T 'open'; $dialog.FindName('Confirm').Content=T 'apply'; $dialog.FindName('Up').ToolTip=T 'up'
    $script:folderChooser=@{Window=$dialog;Address=$dialog.FindName('Address');List=$dialog.FindName('Folders')}
    $script:folderChooser.Address.Text=[IO.Path]::GetDirectoryName($script:currentFolder)
    $load={ try { $address=Get-Item -LiteralPath $script:folderChooser.Address.Text -Force; if (!$address.PSIsContainer) { throw (T 'folderInvalid') }; $script:folderChooser.Address.Text=$address.FullName; $script:folderChooser.List.ItemsSource=[IO.DirectoryInfo[]]@(Get-ChildItem -LiteralPath $address.FullName -Directory -ErrorAction Stop | Sort-Object Name) } catch { [Windows.MessageBox]::Show($_.Exception.Message,$script:folderChooser.Window.Title)|Out-Null } }
    $dialog.FindName('Open').Add_Click($load)
    $dialog.FindName('Up').Add_Click({ $parent=[IO.Directory]::GetParent($script:folderChooser.Address.Text); if ($parent) { $script:folderChooser.Address.Text=$parent.FullName; $script:folderChooser.Window.FindName('Open').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) } })
    $dialog.FindName('Folders').Add_MouseDoubleClick({ if ($script:folderChooser.List.SelectedItem) { $script:folderChooser.Address.Text=$script:folderChooser.List.SelectedItem.FullName; $script:folderChooser.Window.FindName('Open').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) } })
    $dialog.FindName('Confirm').Add_Click({ if ($script:folderChooser.List.SelectedItems.Count) { $script:folderChooser.Window.Tag=@($script:folderChooser.List.SelectedItems | ForEach-Object { $_.FullName }); $script:folderChooser.Window.DialogResult=$true } })
    & $load
    if ($UITest -and $script:advancedDialogTest) {
        $script:chooserTestTimer=[Windows.Threading.DispatcherTimer]::new(); $script:chooserTestTimer.Interval=[TimeSpan]::FromMilliseconds(150)
        $script:chooserTestTimer.Add_Tick({
            if (!$script:folderChooser.Window.IsVisible) { return }; $script:chooserTestTimer.Stop(); $list=$script:folderChooser.List
            if ($list.Items.Count -lt 2) { $script:folderChooser.Window.DialogResult=$false; return }
            $list.SelectAll()
            if ($list.SelectedItems.Count -lt 2) { $script:folderChooser.Window.DialogResult=$false; return }
            $script:folderChooser.Window.FindName('Confirm').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        }); $script:chooserTestTimer.Start()
    }

    try { if ($dialog.ShowDialog()) { return @($dialog.Tag) } } finally { if ($script:chooserTestTimer) { $script:chooserTestTimer.Stop() }; $script:folderChooser=$null }
}
function Show-PngEditor {
    if (!$script:pngSelection) { return }
    [xml]$markup=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Width="380" Height="530" ResizeMode="NoResize" WindowStartupLocation="CenterOwner">
 <StackPanel Margin="18"><Border Height="230" Background="#283344" CornerRadius="12"><Image Name="Preview" Stretch="Uniform"/></Border>
 <TextBlock Name="ZoomLabel" Margin="0,8,0,0"/><Slider Name="Zoom" Minimum="100" Maximum="400" Value="100"/>
 <TextBlock Name="XLabel"/><Slider Name="X" Minimum="-100" Maximum="100" Value="0"/>
 <TextBlock Name="YLabel"/><Slider Name="Y" Minimum="-100" Maximum="100" Value="0"/>
 <CheckBox Name="Crop" Margin="0,8,0,0"/><Button Name="Confirm" Margin="0,12,0,0" Padding="10,8" IsDefault="True"/>
 </StackPanel>
</Window>
'@
    $dialog=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($markup)); $dialog.Owner=$window; $dialog.Resources.MergedDictionaries.Add($window.Resources); $dialog.FontFamily=$window.FontFamily; $dialog.Title=T 'editPng'; $dialog.Background=$window.Resources['Page']; $dialog.Foreground=$window.Resources['Text']
    foreach ($pair in @(@('ZoomLabel','zoom'),@('XLabel','horizontal'),@('YLabel','vertical'))) { $dialog.FindName($pair[0]).Text=T $pair[1] }; $dialog.FindName('Crop').Content=T 'crop'; $dialog.FindName('Confirm').Content=T 'apply'
    $source=[Drawing.Image]::FromFile($script:pngSelection); $script:pngEditor=@{Window=$dialog;Source=$source;Dirty=$true}
    $timer=[Windows.Threading.DispatcherTimer]::new(); $timer.Interval=[TimeSpan]::FromMilliseconds(50)
    $timer.Add_Tick({ if (!$script:pngEditor.Dirty) { return }; $script:pngEditor.Dirty=$false
        $d=$script:pngEditor.Window; $d.FindName('ZoomLabel').Text=(T 'zoom')+' '+[int]$d.FindName('Zoom').Value+'%'; $d.FindName('XLabel').Text=(T 'horizontal')+' '+[int]$d.FindName('X').Value+'%'; $d.FindName('YLabel').Text=(T 'vertical')+' '+[int]$d.FindName('Y').Value+'%'; $bitmap=Render-PreparedImage $script:pngEditor.Source ($d.FindName('Zoom').Value/100) $d.FindName('X').Value $d.FindName('Y').Value ([bool]$d.FindName('Crop').IsChecked)
        $memory=[IO.MemoryStream]::new(); try { $bitmap.Save($memory,[Drawing.Imaging.ImageFormat]::Png); $image=[Windows.Media.Imaging.BitmapImage]::new(); $image.BeginInit(); $image.CacheOption='OnLoad'; $memory.Position=0; $image.StreamSource=$memory; $image.EndInit(); $image.Freeze(); $d.FindName('Preview').Source=$image } finally { $memory.Dispose(); $bitmap.Dispose() }
    })
    foreach ($name in @('Zoom','X','Y')) { $dialog.FindName($name).Add_ValueChanged({ $script:pngEditor.Dirty=$true }) }; $dialog.FindName('Crop').Add_Click({ $script:pngEditor.Dirty=$true })
    $dialog.FindName('Confirm').Add_Click({ $script:pngEditor.Window.DialogResult=$true }); $timer.Start()
    if ($UITest -and $script:advancedDialogTest) {
        $script:editorTestError=$null
        $dialog.Add_ContentRendered({
            $d=$script:pngEditor.Window; $d.FindName('Zoom').Value=180; $d.FindName('X').Value=10; $d.FindName('Crop').IsChecked=$true; $script:pngEditor.Dirty=$true
            $script:editorTestTimer=[Windows.Threading.DispatcherTimer]::new(); $script:editorTestTimer.Interval=[TimeSpan]::FromMilliseconds(250)
            $script:editorTestTimer.Add_Tick({ $script:editorTestTimer.Stop(); if (!$script:pngEditor.Window.FindName('Preview').Source) { $script:editorTestError='PNG preview missing' }; $script:pngEditor.Window.FindName('Confirm').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }); $script:editorTestTimer.Start()
        })
    }
    try { if ($dialog.ShowDialog()) { $bitmap=Render-PreparedImage $source ($dialog.FindName('Zoom').Value/100) $dialog.FindName('X').Value $dialog.FindName('Y').Value ([bool]$dialog.FindName('Crop').IsChecked); $path=Join-Path $root ('png-edit-'+[Guid]::NewGuid().ToString('N')+'.png'); try { $bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }; Set-PngPreview $path } }
    finally { $timer.Stop(); $source.Dispose(); $script:pngEditor=$null; if ($script:editorTestTimer) { $script:editorTestTimer.Stop() } }; if ($script:editorTestError) { throw $script:editorTestError }
}
function Get-PreparedIcon([string]$Badge) {
    if ($Badge -eq 'none') { return $script:pngSelection }
    $source=$null; $icon=$null
    try {
        if ($script:pngSelection) { $source=[Drawing.Image]::FromFile($script:pngSelection) }
        else { $path=Join-Path $root ('badge-base-'+(Valid-Hex).TrimStart('#')+'.ico'); if (![IO.File]::Exists($path)) { New-ColorIcon (Valid-Hex) $path }; $icon=[Drawing.Icon]::new($path,256,256); $source=$icon.ToBitmap() }
        $bitmap=Render-PreparedImage $source 1 0 0 $false $Badge $script:badgeHex; $path=Join-Path $root ('badge-'+[Guid]::NewGuid().ToString('N')+'.png'); try { $bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }; return $path
    } finally { if ($source) { $source.Dispose() }; if ($icon) { $icon.Dispose() } }
}
function Refresh-CollectionChoices {
    if (!$script:advancedReady) { return }
    $script:refreshingGroups=$true
    try {
        $names=@(); try { $loaded=Get-Content -LiteralPath (Join-Path $root 'raccolte.json') -Raw -Encoding UTF8 | ConvertFrom-Json; $names=@($loaded | Where-Object { $_ -is [string] -and $_ }) } catch {}
        $names=@($names)+@($script:collection | ForEach-Object { [string]$_.Group } | Where-Object { $_ }); $names=@($names | Sort-Object -Unique)
        $ui.CollectionFilter.Items.Clear(); $null=$ui.CollectionFilter.Items.Add((T 'allCollections')); foreach ($name in $names) { $null=$ui.CollectionFilter.Items.Add($name) }
        $index=$ui.CollectionFilter.Items.IndexOf($script:filterGroup); $ui.CollectionFilter.SelectedIndex=if ($index -gt 0) { $index } else { 0 }
        if ($index -le 0) { $script:filterGroup='' }
    } finally { $script:refreshingGroups=$false }
    $script:colorView.Refresh()
}
function Show-Toast([string]$Text) {
    Show-Status $Text; $script:toastTimer.Start()
}
function Invoke-AdvancedAction([string]$Action) {
    if ($Action -in @('presets','history','managed','iconSizes','visualSettings','updates')) { Invoke-ProductAction $Action; return }
    switch ($Action) {
        'batch' { $targets=@(Show-FolderSelection); if ($targets.Count) { $script:singleFolder=$script:currentFolder; $script:batchTargets=$targets; $script:currentFolder=$targets[0]; $ui.FolderName.IsEnabled=$targets.Count -eq 1; $ui.RenameFolder.IsEnabled=$targets.Count -eq 1; $ui.FolderName.Text=if ($targets.Count -gt 1) { T 'folderCount' @($targets.Count) } else { [IO.Path]::GetFileName($targets[0]) }; Update-UndoButton } }
        'singleFolder' { $script:batchTargets=@($script:singleFolder); $script:currentFolder=$script:singleFolder; $ui.FolderName.IsEnabled=$true; $ui.RenameFolder.IsEnabled=$true; $ui.FolderName.Text=[IO.Path]::GetFileName($script:currentFolder); Update-UndoButton }
        'editPng' { Show-PngEditor }
        'badge' { Show-BadgePicker }
        'collections' {
            $menu=[Windows.Controls.ContextMenu]::new(); $menu.PlacementTarget=$ui.PaletteTools
            foreach ($name in @('newCollection','renameCollection','deleteCollection')) {
                $item=[Windows.Controls.MenuItem]::new(); $item.Header=T $name; $item.Tag=$name; if ($name -ne 'newCollection') { $item.IsEnabled=[bool]$script:filterGroup }
                $item.Add_Click({ param($sender,$e) try {
                    $old=$script:filterGroup; $new=if ($sender.Tag -eq 'deleteCollection') { '' } else { Show-AdvancedText (T 'collectionName') $(if ($sender.Tag -eq 'renameCollection') { $old } else { '' }) }
                    if ($null -eq $new -or ($sender.Tag -ne 'deleteCollection' -and !$new)) { return }
                    $groups=@(); try { $loaded=Get-Content -LiteralPath (Join-Path $root 'raccolte.json') -Raw -Encoding UTF8 | ConvertFrom-Json; $groups=@($loaded) } catch {}
                    if ($sender.Tag -ne 'newCollection') { foreach ($entry in $script:collection) { if ($entry.Group -eq $old) { $entry | Add-Member -NotePropertyName Group -NotePropertyValue $new -Force } }; $groups=@($groups | Where-Object { $_ -ne $old }) }
                    if ($new) { $groups=@($groups)+@($new) }; Write-AdvancedJson (Join-Path $root 'raccolte.json') @($groups | Sort-Object -Unique); $script:filterGroup=$new; Save-Colors; $ui.SearchRow.Visibility='Visible'; Refresh-CollectionChoices
                } catch { Show-Status $_.Exception.Message } }); $null=$menu.Items.Add($item)
            }; $ui.PaletteTools.ContextMenu=$menu; $menu.IsOpen=$true
        }
    }
}
function Initialize-AdvancedInterface {
    $script:advancedReady=$false; $script:filterGroup=''; $script:searchQuery=''; $script:badge='none'; $script:batchTargets=@($script:currentFolder); $script:singleFolder=$script:currentFolder
    $script:toastTimer=[Windows.Threading.DispatcherTimer]::new(); $script:toastTimer.Interval=[TimeSpan]::FromSeconds(3); $script:toastTimer.Add_Tick({ $script:toastTimer.Stop(); $ui.Status.Visibility='Collapsed' }); $window.Add_Closed({ $script:toastTimer.Stop() })
    $script:colorView=[Windows.Data.CollectionViewSource]::GetDefaultView($script:collection)
    $script:colorView.Filter=[Predicate[object]]{ param($entry) (!$script:filterGroup -or [string]$entry.Group -eq $script:filterGroup) -and (!$script:searchQuery -or ([string]$entry.Name).IndexOf($script:searchQuery,[StringComparison]::OrdinalIgnoreCase) -ge 0 -or ([string]$entry.Hex).IndexOf($script:searchQuery,[StringComparison]::OrdinalIgnoreCase) -ge 0) }
    $ui.SearchText.Add_TextChanged({ $script:searchQuery=$ui.SearchText.Text.Trim(); $script:colorView.Refresh() })
    $ui.CollectionFilter.Add_SelectionChanged({ if ($script:refreshingGroups) { return }; $script:filterGroup=if ($ui.CollectionFilter.SelectedIndex -gt 0) { [string]$ui.CollectionFilter.SelectedItem } else { '' }; $script:colorView.Refresh() })
    $ui.SearchToggle.Add_Click({ if ($ui.SearchRow.Visibility -eq 'Visible') { $ui.SearchRow.Visibility='Collapsed'; $ui.SearchText.Clear(); $ui.CollectionFilter.SelectedIndex=0 } else { $ui.SearchRow.Visibility='Visible'; [void]$ui.SearchText.Focus() } })
    $script:advancedReady=$true; Refresh-CollectionChoices
    foreach ($hex in @(Read-RecentColors)) {
        $button=[Windows.Controls.Button]::new(); $button.Tag=$hex; $button.ToolTip=$hex; $button.Width=24; $button.MinHeight=22; $button.Padding=[Windows.Thickness]::new(3); $button.Margin=[Windows.Thickness]::new(0,3,4,0)
        $swatch=[Windows.Shapes.Ellipse]::new(); $swatch.Width=14; $swatch.Height=14; $swatch.Fill=Brush $hex; $button.Content=$swatch
        $button.Add_Click({ param($sender,$e) $ui.Hex.Text=[string]$sender.Tag }); $ui.RecentColors.Children.Add($button)|Out-Null
    }; if ($ui.RecentColors.Children.Count) { $ui.RecentArea.Visibility='Visible' }
}

. (Join-Path $PSScriptRoot 'Productivity.ps1')
