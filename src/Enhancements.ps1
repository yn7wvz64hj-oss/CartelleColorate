function Get-DataHash([byte[]]$Bytes) {
    $sha=[Security.Cryptography.SHA256]::Create(); try { return [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Assert-CompletePreset($Preset) {
    if ($Preset.Id -notmatch '^[a-f0-9]{32}$' -or $Preset.Name -isnot [string] -or !$Preset.Name.Trim() -or $Preset.Hex -isnot [string] -or $Preset.Hex -notmatch '^#[0-9A-Fa-f]{6}$' -or $Preset.BadgeHex -isnot [string] -or $Preset.BadgeHex -notmatch '^#[0-9A-Fa-f]{6}$' -or $Preset.Badge -notin @('none','star','check','lock','heart','document','music','photo') -or ($null -ne $Preset.Favorite -and $Preset.Favorite -isnot [bool])) { throw (T 'backupInvalid') }
}
function Get-CompletePresetIcon($Preset) {
    Assert-CompletePreset $Preset
    $pngHash=if ($Preset.Png) { Get-DataHash ([IO.File]::ReadAllBytes($Preset.Png)) } else { '' }
    $hash=Get-DataHash ([Text.Encoding]::UTF8.GetBytes(($Preset.Hex+'|'+$Preset.Badge+'|'+$Preset.BadgeHex+'|'+$pngHash)))
    $path=Join-Path $root ('preset-icon-'+$hash+'.ico'); if ([IO.File]::Exists($path)) { return $path }
    if ($Preset.Badge -eq 'none') { if ($Preset.Png) { New-PngIcon $Preset.Png $path } else { New-ColorIcon $Preset.Hex $path }; return $path }
    $source=$null; $icon=$null; $bitmap=$null; $temporary=Join-Path $root ('preset-render-'+[Guid]::NewGuid().ToString('N')+'.png')
    try {
        if ($Preset.Png) { $source=[Drawing.Image]::FromFile($Preset.Png) }
        else { $base=Join-Path $root ('verticale-grande-'+$Preset.Hex.TrimStart('#')+'.ico'); if (![IO.File]::Exists($base)) { New-ColorIcon $Preset.Hex $base }; $icon=[Drawing.Icon]::new($base,256,256); $source=$icon.ToBitmap() }
        $bitmap=Render-PreparedImage $source 1 0 0 $false $Preset.Badge $Preset.BadgeHex; $bitmap.Save($temporary,[Drawing.Imaging.ImageFormat]::Png); New-PngIcon $temporary $path; return $path
    } finally { if ($bitmap) { $bitmap.Dispose() }; if ($source) { $source.Dispose() }; if ($icon) { $icon.Dispose() }; if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Get-PinnedPresetEntries {
    foreach ($preset in @(Read-ProductList 'preset.json' | Where-Object { $_.Favorite })) { Assert-CompletePreset $preset; [pscustomobject]@{Id=$preset.Id;Name=$preset.Name;Icon=(Get-CompletePresetIcon $preset)} }
}
function Apply-PresetToFolder([string]$Target,[string]$Id) {
    if ($Id -notmatch '^[a-f0-9]{32}$') { throw (T 'backupInvalid') }; $preset=@(Read-ProductList 'preset.json' | Where-Object { $_.Id -eq $Id }); if ($preset.Count -ne 1) { throw (T 'presetMissing') }
    $icon=Get-CompletePresetIcon $preset[0]; $before=New-FolderUndo $Target; Save-FolderUndo $before; Set-FolderIcon $Target $icon; Save-FolderActivity $before 'apply'; try { Save-RecentColor $preset[0].Hex } catch {}
}
function Set-PresetFavorite([string]$Id) {
    $items=@(Read-ProductList 'preset.json'); $found=$false; foreach ($preset in $items) { if ($preset.Id -eq $Id) { $preset | Add-Member -NotePropertyName Favorite -NotePropertyValue (![bool]$preset.Favorite) -Force; $found=$true } }; if (!$found) { throw (T 'presetMissing') }
    Write-AdvancedJson (Join-Path $root 'preset.json') $items; Sync-PresetMenu
}
function Sync-PresetMenu { if (!$SelfTest -and !$Preview) { Update-Menu } }
function Save-ReversibleActivity($Activity,[object[]]$Records,[bool]$Repeat) {
    $after=@(); foreach ($record in $Records) { $after+=Get-SnapshotSignature (New-FolderUndo $record.Current) }
    $directory=Join-Path $root $(if ($Repeat) { 'cronologia' } else { 'ripeti' }); [IO.Directory]::CreateDirectory($directory)|Out-Null
    Write-AdvancedJson (Join-Path $directory ($Activity.Id+'.json')) ([pscustomobject]@{Id=$Activity.Id;Date=[DateTime]::UtcNow.ToString('o');Kind=$Activity.Kind;Records=@($Records);After=@($after)})
}
function Read-RepeatActivities {
    $directory=Join-Path $root 'ripeti'; if (![IO.Directory]::Exists($directory)) { return }
    foreach ($file in (Get-ChildItem -LiteralPath $directory -Filter '*.json' -File | Sort-Object LastWriteTimeUtc -Descending)) { try { $entry=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json; if ($entry.Id -match '^[a-f0-9]{32}$' -and @($entry.Records).Count) { $entry } } catch {} }
}
function Undo-RecordedFolderEdit($Record,[string]$Target) {
    $records=@(); if ($Record.Batch) { $records=@($Record.Batch) } else { $records=@($Record) }; $index=-1
    for ($i=0;$i -lt $records.Count;$i++) { if ($records[$i].Current -eq [IO.Path]::GetFullPath($Target)) { $index=$i } }; if ($index -lt 0) { throw (T 'backupError') }
    $signature=Get-SnapshotSignature $records; $activity=@(Read-FolderActivities | Where-Object { (Get-SnapshotSignature @($_.Records)) -eq $signature } | Select-Object -First 1)
    if (!$activity.Count) { $after=@(); foreach ($entry in $records) { $after+=Get-SnapshotSignature (New-FolderUndo $entry.Current) }; $activity=@([pscustomobject]@{Id=[Guid]::NewGuid().ToString('N');Kind='apply';Records=$records;After=$after}) }
    $paths=@(Restore-FolderActivity $activity[0]); return $paths[$index]
}
function Assert-BackupPng([byte[]]$Bytes) {
    if (!$Bytes.Length -or $Bytes.Length -gt 33554432) { throw (T 'backupInvalid') }; $stream=[IO.MemoryStream]::new($Bytes,$false); $image=$null
    try { $image=[Drawing.Image]::FromStream($stream,$true,$true); if ($image.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Png.Guid -or [long]$image.Width*$image.Height -gt 67108864) { throw (T 'backupInvalid') } } finally { if ($image) { $image.Dispose() }; $stream.Dispose() }
}
function Export-LibraryBackup([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
    $settings=[pscustomobject]@{}; foreach ($key in @('language','appearance','theme','glassOpacity','glassDepth','checkUpdates')) { $value=Read-ProductSetting $key $null; if ($null -ne $value) { $settings | Add-Member -NotePropertyName $key -NotePropertyValue $value } }
    $assets=@{}; $presets=@(); foreach ($preset in @(Read-ProductList 'preset.json')) {
        Assert-CompletePreset $preset; $asset=''; if ($preset.Png) { $bytes=[IO.File]::ReadAllBytes($preset.Png); Assert-BackupPng $bytes; $asset=Get-DataHash $bytes; $assets[$asset]=$bytes }
        $presets+=[pscustomobject]@{Name=$preset.Name;Hex=$preset.Hex;Badge=$preset.Badge;BadgeHex=$preset.BadgeHex;Favorite=[bool]$preset.Favorite;Asset=$asset}
    }
    $backgrounds=@(Get-PortableBackgrounds $assets)
    $document=[pscustomobject]@{Backgrounds=$backgrounds;Format='CartelleColorateBackup';Version=1;Colors=@(Read-Palette);Groups=@(Read-ProductList 'raccolte.json');Recent=@(Read-RecentColors);Settings=$settings;Presets=$presets}
    $target=[IO.Path]::GetFullPath($Path); $temporary=$target+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'; $stream=$null; $zip=$null
    try { $stream=[IO.File]::Create($temporary); $zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
        $entry=$zip.CreateEntry('backup.json'); $output=$entry.Open(); try { $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $document -Depth 12)); $output.Write($bytes,0,$bytes.Length) } finally { $output.Dispose() }
        foreach ($hash in $assets.Keys) { $entry=$zip.CreateEntry('images/'+$hash+'.png'); $output=$entry.Open(); try { $bytes=$assets[$hash]; $output.Write($bytes,0,$bytes.Length) } finally { $output.Dispose() } }
        $zip.Dispose(); $zip=$null; $stream.Dispose(); $stream=$null; if ([IO.File]::Exists($target)) { [IO.File]::Replace($temporary,$target,[NullString]::Value) } else { [IO.File]::Move($temporary,$target) }
    } finally { if ($zip) { $zip.Dispose() }; if ($stream) { $stream.Dispose() }; if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Import-LibraryBackup([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::OpenRead($Path); $assets=@{}; $document=$null
    try {
        $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase); $total=0L
        foreach ($entry in $zip.Entries) { $total+=$entry.Length; if (!$seen.Add($entry.FullName) -or $entry.FullName -notmatch '^(backup\.json|images/[a-f0-9]{64}\.png)$' -or $entry.Length -gt 33554432 -or $total -gt 536870912) { throw (T 'backupInvalid') } }
        $manifest=$zip.GetEntry('backup.json'); if (!$manifest -or $manifest.Length -gt 16777216) { throw (T 'backupInvalid') }; $reader=[IO.StreamReader]::new($manifest.Open(),[Text.Encoding]::UTF8); try { $document=$reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        if ($document.Format -cne 'CartelleColorateBackup' -or $document.Version -ne 1 -or $null -eq $document.Colors -or $null -eq $document.Presets) { throw (T 'backupInvalid') }
        foreach ($preset in $document.Presets) { $preset | Add-Member -NotePropertyName Id -NotePropertyValue ([Guid]::NewGuid().ToString('N')) -Force; Assert-CompletePreset $preset; if ($preset.Asset) { if ($preset.Asset -notmatch '^[a-f0-9]{64}$') { throw (T 'backupInvalid') }; if (!$assets.ContainsKey($preset.Asset)) { $entry=$zip.GetEntry('images/'+$preset.Asset+'.png'); if (!$entry) { throw (T 'backupInvalid') }; $input=$entry.Open(); $memory=[IO.MemoryStream]::new(); try { $input.CopyTo($memory); $bytes=$memory.ToArray() } finally { $input.Dispose(); $memory.Dispose() }; if ((Get-DataHash $bytes) -cne $preset.Asset) { throw (T 'backupInvalid') }; Assert-BackupPng $bytes; $assets[$preset.Asset]=$bytes } } }
        $backgrounds=@(Read-PortableBackgrounds $document.Backgrounds $zip $assets)
    } finally { $zip.Dispose() }
    $colors=@(Read-Palette); foreach ($entry in $document.Colors) { if ($entry.Name -isnot [string] -or !$entry.Name.Trim() -or $entry.Hex -notmatch '^#[0-9A-Fa-f]{6}$' -or ($null -ne $entry.Favorite -and $entry.Favorite -isnot [bool]) -or ($null -ne $entry.Group -and $entry.Group -isnot [string])) { throw (T 'backupInvalid') }; if (!@($colors | Where-Object { $_.Name -ceq $entry.Name -and $_.Hex -eq $entry.Hex -and [string]$_.Group -ceq [string]$entry.Group }).Count) { $colors+=[pscustomobject]@{Name=$entry.Name;Hex=$entry.Hex.ToUpperInvariant();Favorite=[bool]$entry.Favorite;Group=[string]$entry.Group} } }
    $groups=@(Read-ProductList 'raccolte.json'); foreach ($group in $document.Groups) { if ($group -isnot [string] -or !$group.Trim()) { throw (T 'backupInvalid') }; $groups+=$group }
    $recent=@(); foreach ($hex in $document.Recent) { if ($hex -notmatch '^#[0-9A-Fa-f]{6}$') { throw (T 'backupInvalid') }; $recent+=$hex.ToUpperInvariant() }
    $settings=[pscustomobject]@{}; if ([IO.File]::Exists($script:languageSettingsPath)) { $settings=Get-Content -LiteralPath $script:languageSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    foreach ($key in @('language','appearance','theme','glassOpacity','glassDepth','checkUpdates')) { $value=$document.Settings.$key; if ($null -eq $value) { continue }; $valid=switch($key) { 'language' { $script:languageMap.ContainsKey([string]$value) } 'appearance' { $value -in @('Windows','MacOS') } 'theme' { $value -in @('System','Light','Dark') } 'checkUpdates' { $value -in @('true','false') } default { ([string]$value -match '^\d{1,3}$') -and [int]$value -le 100 } }; if (!$valid) { throw (T 'backupInvalid') }; $settings | Add-Member -NotePropertyName $key -NotePropertyValue ([string]$value) -Force }
    $presets=@(Read-ProductList 'preset.json'); $pendingAssets=@{}; foreach ($preset in $document.Presets) {
        $duplicate=@($presets | Where-Object { ($_.Name -ceq $preset.Name -or $_.OriginName -ceq $preset.Name) -and $_.Hex -eq $preset.Hex -and $_.Badge -eq $preset.Badge -and $_.BadgeHex -eq $preset.BadgeHex -and $(if ($_.Png) { (Get-DataHash ([IO.File]::ReadAllBytes($_.Png))) -eq $preset.Asset } else { !$preset.Asset }) }); if ($duplicate.Count) { if ($preset.Favorite) { $duplicate[0] | Add-Member -NotePropertyName Favorite -NotePropertyValue $true -Force }; continue }
        $name=$preset.Name; $number=2; while (@($presets | Where-Object { $_.Name -eq $name }).Count) { $name=$preset.Name+' ('+$number+')'; $number++ }
        $png=''; if ($preset.Asset) { $png=Join-Path $root ('preset-import-'+$preset.Id+'.png'); $pendingAssets[$png]=$assets[$preset.Asset] }
        $presets+=[pscustomobject]@{Id=$preset.Id;Name=$name;OriginName=$preset.Name;Hex=$preset.Hex.ToUpperInvariant();Badge=$preset.Badge;BadgeHex=$preset.BadgeHex.ToUpperInvariant();Favorite=[bool]$preset.Favorite;Png=$png}
    }
    $backgroundChoices=Read-BackgroundChoices; foreach ($entry in $backgrounds) { $image=''; if ($entry.Mode -eq 'Image') { $image=Join-Path $root ('background-'+[Guid]::NewGuid().ToString('N')+'.png'); $pendingAssets[$image]=$assets[$entry.Asset] }; $backgroundChoices[$entry.Style]=[pscustomobject]@{Style=$entry.Style;Mode=$entry.Mode;Hex=$entry.Hex;Image=$image} }
    $writes=@{'colori.json'=$colors;'preset.json'=$presets;'raccolte.json'=@($groups | Sort-Object -Unique);'recenti.json'=@($recent | Select-Object -Unique -First 8);'impostazioni.json'=$settings}; if ($backgrounds.Count) { $writes['sfondi.json']=@($backgroundChoices.Values) }; $previous=@{}; $created=@()
    foreach ($name in $writes.Keys) { $file=Join-Path $root $name; $previous[$file]=if ([IO.File]::Exists($file)) { [IO.File]::ReadAllBytes($file) } else { $null } }
    try { foreach ($file in $pendingAssets.Keys) { [IO.File]::WriteAllBytes($file,$pendingAssets[$file]); $created+=$file }; foreach ($name in $writes.Keys) { Write-AdvancedJson (Join-Path $root $name) $writes[$name] } }
    catch { foreach ($file in $previous.Keys) { if ($null -ne $previous[$file]) { [IO.File]::WriteAllBytes($file,$previous[$file]) } elseif ([IO.File]::Exists($file)) { [IO.File]::Delete($file) } }; foreach ($file in $created) { [IO.File]::Delete($file) }; throw }
}
function Show-LibraryBackup {
    $menu=New-ModernMenu $ui.PaletteTools
    foreach ($action in @('exportBackup','importBackup')) { $item=[Windows.Controls.MenuItem]::new(); $item.Header=T $action; $item.Tag=$action; $item.Add_Click({ param($sender,$e) try {
        $dialog=if ($sender.Tag -eq 'importBackup') { [Microsoft.Win32.OpenFileDialog]::new() } else { [Microsoft.Win32.SaveFileDialog]::new() }; $dialog.Filter='CartelleColorate (*.ccbackup)|*.ccbackup'; $dialog.DefaultExt='.ccbackup'; $dialog.FileName='CartelleColorate-backup'
        if ($dialog.ShowDialog($window)) { if ($sender.Tag -eq 'exportBackup') { Export-LibraryBackup $dialog.FileName; Show-Toast (T 'backupSaved') } else { Import-LibraryBackup $dialog.FileName; Reload-LibraryInterface; Show-Toast (T 'backupLoaded') } }
    } catch { Show-Status $_.Exception.Message } }); $menu.Items.Add($item)|Out-Null }; $ui.PaletteTools.ContextMenu=$menu; $menu.IsOpen=$true
}
function Reload-LibraryInterface {
    $script:collection.Clear(); foreach ($color in @(Read-Palette)) { $color | Add-Member -NotePropertyName DisplayName -NotePropertyValue $(if ($color.Favorite) { '★ '+$color.Name } else { $color.Name }) -Force; $script:collection.Add($color) }; Order-Colors; Update-Empty; Refresh-CollectionChoices; $ui.Colors.Items.Refresh()
    Initialize-Language $root ''; Apply-InterfaceLanguage; $script:themeMode=[string](Read-ProductSetting 'theme' 'System'); $script:glassOpacity=[double](Read-ProductSetting 'glassOpacity' 55); $script:glassDepth=[double](Read-ProductSetting 'glassDepth' 50); $script:appearance=Read-AppearancePreference; Update-ProductTheme
    $ui.RecentColors.Children.Clear(); foreach ($hex in @(Read-RecentColors)) { $button=[Windows.Controls.Button]::new(); $button.Tag=$hex; $button.ToolTip=$hex; $button.Width=24; $button.MinHeight=22; $button.Padding=[Windows.Thickness]::new(3); $button.Margin=[Windows.Thickness]::new(0,3,4,0); $swatch=[Windows.Shapes.Ellipse]::new(); $swatch.Width=14; $swatch.Height=14; $swatch.Fill=Brush $hex; $button.Content=$swatch; $button.Add_Click({param($sender,$e) $ui.Hex.Text=[string]$sender.Tag}); $ui.RecentColors.Children.Add($button)|Out-Null }; $ui.RecentArea.Visibility=if ($ui.RecentColors.Children.Count) { 'Visible' } else { 'Collapsed' }; Sync-PresetMenu
}
function Test-EnhancementBackend {
    $target=Join-Path $root 'Redo cartella 日本語'; [IO.Directory]::CreateDirectory($target)|Out-Null; [IO.File]::WriteAllText((Join-Path $target 'contenuto.txt'),'preservato')
    $before=New-FolderUndo $target; Save-FolderUndo $before; Set-FolderColor $target '#1278AC'; Save-FolderActivity $before 'apply'; $expected=[IO.File]::ReadAllBytes((Join-Path $target 'desktop.ini'))
    $null=Undo-FolderEdit $target; if ([IO.File]::Exists((Join-Path $target 'desktop.ini'))) { throw 'Undo did not restore the original' }
    $redo=@(Read-RepeatActivities | Where-Object { $_.Records[0].Current -eq $target })[0]; $null=Restore-FolderActivity $redo $true
    if ((Get-DataHash ([IO.File]::ReadAllBytes((Join-Path $target 'desktop.ini')))) -ne (Get-DataHash $expected)) { throw 'Redo changed icon bytes' }
    $before=New-FolderUndo $target; $renamed=Rename-Folder $target 'Redo rinominata 日本語'; $before.Current=$renamed; Save-FolderUndo $before; Save-FolderActivity $before 'folderRenamed'; $restored=Undo-FolderEdit $renamed
    if ($restored -ne $target) { throw 'Rename undo failed' }; $redo=@(Read-RepeatActivities | Where-Object { $_.Records[0].Current -eq $target })[0]; $null=Restore-FolderActivity $redo $true
    if (![IO.Directory]::Exists($renamed) -or [IO.File]::ReadAllText((Join-Path $renamed 'contenuto.txt')) -ne 'preservato') { throw 'Rename redo lost contents' }
    $null=Undo-FolderEdit $renamed; $redo=@(Read-RepeatActivities | Where-Object { $_.Records[0].Current -eq $target })[0]; Set-FolderColor $target '#ABCDEF'; $signature=Get-SnapshotSignature (New-FolderUndo $target); $rejected=$false
    try { $null=Restore-FolderActivity $redo $true } catch { $rejected=$true }; if (!$rejected -or (Get-SnapshotSignature (New-FolderUndo $target)) -ne $signature) { throw 'Redo overwrote a later edit' }
    $oldRoot=$script:root; $oldPalette=$script:palettePath; $oldSettings=$script:languageSettingsPath; $oldLanguage=$script:activeLanguage.code
    $case=Join-Path $root ('backup-case-'+[Guid]::NewGuid().ToString('N')); $source=Join-Path $case 'source'; $destination=Join-Path $case 'destination'; [IO.Directory]::CreateDirectory($source)|Out-Null; [IO.Directory]::CreateDirectory($destination)|Out-Null
    try {
        $script:root=$source; $script:palettePath=Join-Path $source 'colori.json'; Initialize-Language $source 'it'
        Write-AdvancedJson $palettePath @([pscustomobject]@{Name='Lavoro 日本語';Hex='#AB1234';Favorite=$true;Group='Raccolta العربية'})
        Write-AdvancedJson (Join-Path $root 'raccolte.json') @('Raccolta العربية','Vuota'); Save-LanguagePreference 'it'; Save-AppSetting 'appearance' 'MacOS'; Save-AppSetting 'theme' 'Dark'; Save-AppSetting 'glassOpacity' '45'; Save-AppSetting 'glassDepth' '75'; Save-AppSetting 'checkUpdates' 'false'; Save-RecentColor '#AB1234'
        $png=Join-Path $root 'original.png'; $bitmap=[Drawing.Bitmap]::new(18,12); $graphics=[Drawing.Graphics]::FromImage($bitmap); try { $graphics.Clear([Drawing.Color]::Blue); $bitmap.Save($png,[Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
        $preset=Save-CompletePreset 'Preset 日本語' '#AB1234' $png 'heart' '#FF2255'; Set-PresetFavorite $preset.Id
        $preset=Save-CompletePreset 'Preset 日本語' '#AB1234' $png 'heart' '#FF2255'; if (!$preset.Favorite) { throw 'Saving a preset loses its favorite' }
        $pinned=@(Get-PinnedPresetEntries); if ($pinned.Count -ne 1 -or ![IO.File]::Exists($pinned[0].Icon)) { throw 'Pinned preset icon missing' }; $iconHash=Get-DataHash ([IO.File]::ReadAllBytes($pinned[0].Icon)); if ((Get-CompletePresetIcon $preset) -ne $pinned[0].Icon) { throw 'Preset cache mismatch' }
        $folder=Join-Path $root 'Direct preset'; [IO.Directory]::CreateDirectory($folder)|Out-Null; Apply-PresetToFolder $folder $preset.Id
        if ((Get-FolderIconPath $folder) -ne $pinned[0].Icon -or (Get-DataHash ([IO.File]::ReadAllBytes($pinned[0].Icon))) -ne $iconHash) { throw 'Direct preset application failed' }; $null=Undo-FolderEdit $folder
        $backup=Join-Path $case 'library.ccbackup'; Export-LibraryBackup $backup
        [IO.File]::Move($preset.Png,$preset.Png+'.moved')
        $script:root=$destination; $script:palettePath=Join-Path $root 'colori.json'; Initialize-Language $root 'en'; Write-AdvancedJson $palettePath @([pscustomobject]@{Name='Esistente';Hex='#113355';Favorite=$false;Group=''})
        $existing=Save-CompletePreset 'Preset 日本語' '#113355' '' 'none' '#233755'; $runtime=Join-Path $root 'Avvio.ps1'; [IO.File]::WriteAllText($runtime,'non modificare')
        Import-LibraryBackup $backup; Import-LibraryBackup $backup
        if (@(Read-Palette).Count -ne 2 -or @(Read-ProductList 'preset.json').Count -ne 2) { throw 'Repeated backup import creates duplicates' }
        $imported=@(Read-ProductList 'preset.json' | Where-Object { $_.Hex -eq '#AB1234' })[0]
        if (!$imported.Favorite -or $imported.Name -ne 'Preset 日本語 (2)' -or !$imported.Png.StartsWith($root+'\') -or ![IO.File]::Exists($imported.Png) -or (Read-ProductSetting 'glassOpacity' '') -ne '45') { throw 'Portable backup loses images, names or settings' }
        $paletteHash=Get-DataHash ([IO.File]::ReadAllBytes($palettePath)); $presetHash=Get-DataHash ([IO.File]::ReadAllBytes((Join-Path $root 'preset.json')))
        $bad=Join-Path $case 'unsafe.ccbackup'; $archive=[IO.Compression.ZipFile]::Open($bad,[IO.Compression.ZipArchiveMode]::Create); try { $null=$archive.CreateEntry('../Avvio.ps1') } finally { $archive.Dispose() }
        $rejected=$false; try { Import-LibraryBackup $bad } catch { $rejected=$true }; if (!$rejected -or (Get-DataHash ([IO.File]::ReadAllBytes($palettePath))) -ne $paletteHash -or [IO.File]::ReadAllText($runtime) -ne 'non modificare') { throw 'Unsafe backup changed application files' }
        $script:originalBackupWriter=(Get-Command Write-AdvancedJson).ScriptBlock
        try {
            function Write-AdvancedJson([string]$Path,$Data) { if ($Path.EndsWith('preset.json')) { throw 'Simulated import write error' }; & $script:originalBackupWriter $Path $Data }
            $failed=$false; try { Import-LibraryBackup $backup } catch { $failed=$true }
            if (!$failed -or (Get-DataHash ([IO.File]::ReadAllBytes($palettePath))) -ne $paletteHash -or (Get-DataHash ([IO.File]::ReadAllBytes((Join-Path $root 'preset.json')))) -ne $presetHash) { throw 'Import rollback failed' }
        } finally { Set-Item -Path Function:Write-AdvancedJson -Value $script:originalBackupWriter }
    } finally { $script:root=$oldRoot; $script:palettePath=$oldPalette; Initialize-Language $oldRoot $oldLanguage; $script:languageSettingsPath=$oldSettings }
    Write-Output 'OK: ripeti colore e rinomina, protezione dalle modifiche successive, preset preferiti, backup portatile, collisioni, import ripetuto e rollback.'
}
function Test-EnhancementInterface {
    $script:productDialogTest=$true
    try {
        $presets=@(Read-ProductList 'preset.json'); if (!$presets.Count) { throw 'Missing UI preset fixture' }; $id=$presets[0].Id; $wasFavorite=[bool]$presets[0].Favorite; $script:productDialogId=$id; $script:productDialogAction='pinPreset'; Show-ProductList 'presets'; $script:productDialogAction=$null
        $changed=@(Read-ProductList 'preset.json' | Where-Object { $_.Id -eq $id })[0]; if ([bool]$changed.Favorite -eq $wasFavorite) { throw 'Favorite UI button failed' }
        if ($script:productDialogCount -lt 1) { throw 'Favorite preset dialog failed' }; Show-ProductList 'redo'
        Show-LibraryBackup; if ($ui.PaletteTools.ContextMenu.Items.Count -ne 2 -or $ui.PaletteTools.ContextMenu.Items[0].Header -ne (T 'exportBackup')) { throw 'Backup menu failed' }; $ui.PaletteTools.ContextMenu.IsOpen=$false
        $settingsPath=$script:languageSettingsPath; $savedSettings=$null; if ([IO.File]::Exists($settingsPath)) { $savedSettings=[IO.File]::ReadAllBytes($settingsPath) }; $code=$script:activeLanguage.code; $originalNames=@($script:collection | ForEach-Object { $_.Name }) -join '|'
        try { Save-LanguagePreference $code; Save-Colors; $backup=Join-Path $root 'ui-library.ccbackup'; Export-LibraryBackup $backup; $script:collection.Clear(); Save-Colors; Import-LibraryBackup $backup; Reload-LibraryInterface
            if ((@($script:collection | ForEach-Object { $_.Name }) -join '|') -ne $originalNames -or $script:activeLanguage.code -ne $code -or $ui.LanguageName.Text -ne $script:activeLanguage.nativeName) { throw 'Backup reload loses library or language' }
        } finally { if ($null -ne $savedSettings) { [IO.File]::WriteAllBytes($settingsPath,$savedSettings) } elseif ([IO.File]::Exists($settingsPath)) { [IO.File]::Delete($settingsPath) }; $script:activeLanguage=$script:languageMap[$code]; Apply-InterfaceLanguage }
    } finally { $script:productDialogTest=$false; $script:productDialogAction=$null; $script:productDialogId=$null }
}

# Small previews are cached per source revision; one uncached preset is drawn per idle tick.
function Start-PresetPreviews {
    if (!$script:presetPreviewCache) { $script:presetPreviewCache=@{} }
    if (!$script:presetPreviewTimer) {
        $script:presetPreviewTimer=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Background)
        $script:presetPreviewTimer.Interval=[TimeSpan]::FromMilliseconds(25)
        $script:presetPreviewTimer.Add_Tick({ Invoke-PresetPreviewTick })
    }
    $script:presetPreviewIndex=0; $script:presetPreviewTimer.Start()
}
function Invoke-PresetPreviewTick {
    if (!$script:productList -or $script:productList.Mode -ne 'presets') { $script:presetPreviewTimer.Stop(); return }
    $list=$script:productList.List
    if ($script:presetPreviewIndex -ge $list.Items.Count) { $script:presetPreviewTimer.Stop(); return }
    $index=$script:presetPreviewIndex; $script:presetPreviewIndex++; $row=$list.Items[$index]; $p=$row.Value
    $stamp=if ($p.Png -and [IO.File]::Exists($p.Png)) { [IO.File]::GetLastWriteTimeUtc($p.Png).Ticks.ToString()+':'+[IO.FileInfo]::new($p.Png).Length } else { '' }
    $key=($p | ConvertTo-Json -Compress)+$stamp
    if (!$script:presetPreviewCache.ContainsKey($key)) {
        $source=$null; $bitmap=$null; $stream=$null; $icon=$null; $image=$null
        try {
            if ($p.Png) {
                $small=[Windows.Media.Imaging.BitmapImage]::new(); $small.BeginInit(); $small.CacheOption='OnLoad'; $small.DecodePixelWidth=256; $small.UriSource=[Uri]::new($p.Png); $small.EndInit(); $small.Freeze()
                $stream=[IO.MemoryStream]::new(); $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($small)); $encoder.Save($stream); $stream.Position=0; $source=[Drawing.Image]::FromStream($stream)
            } else {
                $path=Join-Path $root ('preset-preview-'+$p.Hex.TrimStart('#')+'.ico'); if (![IO.File]::Exists($path)) { New-ColorIcon $p.Hex $path }; $small=Read-IconFrame $path 256; $stream=[IO.MemoryStream]::new(); $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($small)); $encoder.Save($stream); $stream.Position=0; $source=[Drawing.Image]::FromStream($stream)
            }
            $bitmap=Render-PreparedImage $source 1 0 0 $false $p.Badge $p.BadgeHex; $image=Convert-ProductBitmap $bitmap
        } catch {} finally { if ($bitmap) { $bitmap.Dispose() }; if ($source) { $source.Dispose() }; if ($icon) { $icon.Dispose() }; if ($stream) { $stream.Dispose() } }
        if ($script:presetPreviewCache.Count -ge 256) { $script:presetPreviewCache.Clear() }; $script:presetPreviewCache[$key]=$image
    }
    $updated=[pscustomobject]@{Title=$row.Title;Detail=$row.Detail;Image=$script:presetPreviewCache[$key];Value=$p}
    $selected=$list.SelectedIndex -eq $index; $list.ItemsSource[$index]=$updated; if ($selected) { $list.SelectedItem=$updated }

}
function Test-ProductDrop([string[]]$Paths) {
    if (!$Paths.Count) { return $false }
    if ($Paths.Count -eq 1 -and [IO.File]::Exists($Paths[0]) -and [IO.Path]::GetExtension($Paths[0]) -ieq '.png') { return $true }
    foreach ($path in $Paths) { if (![IO.Directory]::Exists($path)) { return $false } }; return $true
}
function Invoke-ProductDrop([string[]]$Paths) {
    if (!(Test-ProductDrop $Paths)) { throw (T 'folderInvalid') }
    if ($Paths.Count -eq 1 -and [IO.File]::Exists($Paths[0])) { Start-PngPreview $Paths[0] }
    else { Select-ProductFolders $Paths; Show-Toast (T 'folderCount' @($script:batchTargets.Count)) }
}
function Initialize-PngLoader {
    $script:pngLoaderScript={
        param($Path)
        Add-Type -AssemblyName PresentationCore,WindowsBase
        $stream=[IO.File]::OpenRead($Path)
        try {
            $signature=New-Object byte[] 8; if ($stream.Read($signature,0,8) -ne 8 -or [BitConverter]::ToString($signature) -ne '89-50-4E-47-0D-0A-1A-0A') { throw 'Invalid PNG' }; $stream.Position=0
            $header=New-Object byte[] 24; if ($stream.Read($header,0,24) -ne 24) { throw 'Invalid PNG' }; $width=[double]$header[16]*16777216+$header[17]*65536+$header[18]*256+$header[19]; $height=[double]$header[20]*16777216+$header[21]*65536+$header[22]*256+$header[23]; if ($width -lt 1 -or $height -lt 1 -or $width*$height -gt 64000000) { throw 'Invalid PNG dimensions' }; $stream.Position=0
            $image=[Windows.Media.Imaging.BitmapImage]::new(); $image.BeginInit(); $image.CacheOption='OnLoad'; if ($width -ge $height) { $image.DecodePixelWidth=256 } else { $image.DecodePixelHeight=256 }; $image.StreamSource=$stream; $image.EndInit(); $image.Freeze(); return $image
        } finally { $stream.Dispose() }
    }
    $script:pngLoadTimer=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Background); $script:pngLoadTimer.Interval=[TimeSpan]::FromMilliseconds(40)
    $script:pngLoadTimer.Add_Tick({ Complete-PngPreview })
    $window.Add_Closed({ $script:pngLoadTimer.Stop(); if ($script:pngLoadPowerShell) { $script:pngLoadPowerShell.Dispose(); $script:pngLoadPowerShell=$null } })
}
function Start-PngPreview([string]$Path) {
    if (![IO.File]::Exists($Path)) { throw (T 'pngError') }
    $script:pngRequest=$Path
    if (!$script:pngLoadPowerShell) {
        $script:pngLoadingPath=$Path; $script:pngLoadPowerShell=[Management.Automation.PowerShell]::Create()
        $null=$script:pngLoadPowerShell.AddScript($script:pngLoaderScript.ToString()).AddArgument($Path); $script:pngLoadHandle=$script:pngLoadPowerShell.BeginInvoke()
    }
    $ui.Apply.IsEnabled=$false; $script:pngLoadTimer.Start()
}
function Complete-PngPreview {
    if (!$script:pngLoadPowerShell -or !$script:pngLoadHandle.IsCompleted) { return }
    $image=$null; $errorLoading=$false
    try { $result=$script:pngLoadPowerShell.EndInvoke($script:pngLoadHandle); if ($script:pngLoadPowerShell.HadErrors -or !$result.Count) { $errorLoading=$true } else { $image=$result[0].PSObject.BaseObject } } catch { $errorLoading=$true }
    finally { $script:pngLoadPowerShell.Dispose(); $script:pngLoadPowerShell=$null }
    if ($script:pngRequest -and $script:pngRequest -ne $script:pngLoadingPath) { Start-PngPreview $script:pngRequest; return }
    $script:pngLoadTimer.Stop(); $ui.Apply.IsEnabled=$true
    if (!$script:pngRequest) { return }
    if ($errorLoading) { $script:pngRequest=$null; Show-Status (T 'pngError'); return }
    $ui.UploadedPreview.Source=$image; $ui.UploadedPreview.Visibility='Visible'; $ui.FolderFront.Visibility='Collapsed'; $ui.FolderBack.Visibility='Collapsed'
    $script:pngSelection=$script:pngLoadingPath; $script:pngRequest=$null; $ui.UseColor.Visibility='Visible'; $ui.Save.IsEnabled=$false; $ui.Upload.Content=T 'changePng'; $ui.Status.Visibility='Collapsed'
}
function Test-RefinementList {
    $search=$script:productList.Search; $search.Text='missing-'+[Guid]::NewGuid().ToString('N')
    if ($script:productList.List.Items.Count -ne 0 -or $script:productList.Empty.Visibility -ne 'Visible') { throw 'Preset empty search failed' }
    $search.Text=''; $list=$script:productList.List; $seenNormal=$false
    foreach ($row in $list.Items) { if (!$row.Value.Favorite) { $seenNormal=$true } elseif ($seenNormal) { throw 'Favorites are not first' } }
    if ($list.Items.Count) {
        $name=$list.Items[0].Value.Name; $search.Text=$name.ToUpperInvariant(); if (!$list.Items.Count) { throw 'Case insensitive search failed' }
        $search.Text=''; for ($i=0; $i -lt $list.Items.Count; $i++) { Invoke-PresetPreviewTick }; foreach ($entry in $list.Items) { if (!$entry.Image) { throw 'Preset thumbnail missing' } }; if (!$list.Items[0].Image) { throw 'Progressive preview missing' }
        $first=$list.Items[0].Image; Refresh-ProductList; Invoke-PresetPreviewTick; if (![object]::ReferenceEquals($first,$list.Items[0].Image)) { throw 'Preset thumbnail cache missed' }
    }
}
function Test-PngDropInterface([string]$Png) {
    $original=$script:currentFolder; $batch=@($script:batchTargets); $originalSource=$ui.UploadedPreview.Source
    Invoke-ProductDrop @($Png)
    $timeout=[DateTime]::UtcNow.AddSeconds(15)
    while ($script:pngLoadPowerShell -and [DateTime]::UtcNow -lt $timeout) { [Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Background); Start-Sleep -Milliseconds 15 }
    if ($script:pngLoadPowerShell -or $script:pngSelection -ne $Png -or !$ui.Apply.IsEnabled -or !$ui.UploadedPreview.Source.IsFrozen -or $script:currentFolder -ne $original) { throw ('Asynchronous PNG drop failed: pending='+[bool]$script:pngLoadPowerShell+' selection='+$script:pngSelection+' frozen='+$ui.UploadedPreview.Source.IsFrozen+' enabled='+$ui.Apply.IsEnabled+' status='+$ui.Status.Text) }
    $source=$ui.UploadedPreview.Source; $invalid=Join-Path $root 'invalid.png'; [IO.File]::WriteAllText($invalid,'bad image'); Invoke-ProductDrop @($invalid)
    $timeout=[DateTime]::UtcNow.AddSeconds(15)
    while ($script:pngLoadPowerShell -and [DateTime]::UtcNow -lt $timeout) { [Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Background); Start-Sleep -Milliseconds 15 }
    if ($script:pngLoadPowerShell -or ![object]::ReferenceEquals($source,$ui.UploadedPreview.Source) -or $script:pngSelection -ne $Png -or !$ui.Apply.IsEnabled) { throw 'Invalid PNG replaces current preview' }
    $rejected=$false; try { Invoke-ProductDrop @($Png,$original) } catch { $rejected=$true }; if (!$rejected -or $script:currentFolder -ne $original -or @($script:batchTargets).Count -ne $batch.Count) { throw 'Mixed PNG drop changes target' }
    Start-PngPreview $Png; $ui.UseColor.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    $timeout=[DateTime]::UtcNow.AddSeconds(15)
    while ($script:pngLoadPowerShell -and [DateTime]::UtcNow -lt $timeout) { [Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Background); Start-Sleep -Milliseconds 15 }
    if ($script:pngSelection -or !$ui.Apply.IsEnabled) { throw 'Stale asynchronous preview replaces chosen color' }
    Set-PngPreview $Png
}

. (Join-Path $PSScriptRoot 'Visuals.ps1')
