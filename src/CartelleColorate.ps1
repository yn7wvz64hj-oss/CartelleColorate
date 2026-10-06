param([string]$Folder, [string]$Color, [switch]$Restore, [switch]$RefreshMenu, [switch]$SelfTest, [string]$Preview, [ValidateSet('System','Light','Dark')][string]$Theme='System', [switch]$UITest, [switch]$NoConsoleTest, [switch]$Worker, [string]$Language)
if ($UITest -and !$Preview) { throw 'UITest richiede Preview.' }
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'FolderShell.dll')) {
    Add-Type -Path (Join-Path $PSScriptRoot 'FolderShell.dll')
} else { Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class FolderShell {
 [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
 [DllImport("shell32.dll", CharSet=CharSet.Unicode)] public static extern void SHChangeNotify(uint e, uint f, string a, IntPtr b);
 [DllImport("shell32.dll", EntryPoint="SHChangeNotify", CharSet=CharSet.Unicode)] public static extern void SHRenameNotify(uint e, uint f, string a, string b);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern uint WritePrivateProfileString(string section, string key, string value, string file);
}
'@
}
$root = Join-Path $env:LOCALAPPDATA 'CartelleColorate'
if ($SelfTest -or $Preview) { $root = Join-Path $PSScriptRoot 'test-data' }
New-Item -ItemType Directory -Path $root -Force | Out-Null
$palettePath = Join-Path $root 'colori.json'
. (Join-Path $PSScriptRoot 'Localization.ps1')
Initialize-Language $root $Language
function Read-Palette {
    $items = @()
    if (Test-Path -LiteralPath $palettePath) { $items = @(Get-Content -LiteralPath $palettePath -Raw | ConvertFrom-Json) }
    foreach ($c in $items) {
        if (!$c -or $c.Hex -notmatch '^#[0-9A-Fa-f]{6}$') { throw (T 'paletteError') }
        $c
    }
}
function Get-MenuEntries {
    $index=0
    foreach ($c in @(Read-Palette)) {
        [pscustomobject]@{ Key=('c{0:D8}' -f $index); Name=[string]$c.Name; Hex=$c.Hex.ToUpperInvariant() }
        $index++
    }
}
function Update-Menu {
    $key = 'HKCU:\Software\Classes\Directory\shell\CartelleColorate'
    $entries = @(Get-MenuEntries)
    # Only this application's own menu is replaced.
    if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse }
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -LiteralPath $key -Name MUIVerb -Value (T 'change') -Force | Out-Null
    New-ItemProperty -LiteralPath $key -Name Icon -Value 'shell32.dll,3' -Force | Out-Null
    New-ItemProperty -LiteralPath $key -Name MultiSelectModel -Value 'Single' -Force | Out-Null
    New-ItemProperty -LiteralPath $key -Name ExtendedSubCommandsKey -Value 'CartelleColorate.Menu' -Force | Out-Null
    $store='HKCU:\Software\Classes\CartelleColorate.Menu'
    if (Test-Path -LiteralPath $store) { Remove-Item -LiteralPath $store -Recurse }
    $shell="$store\shell"
    New-Item -Path $shell -Force | Out-Null
    $app=Join-Path $root 'Avvio.vbs'
    $hostPath=Join-Path $env:SystemRoot 'System32\wscript.exe'
    $base='"{0}" //B //Nologo "{1}" "%1"' -f $hostPath,$app
    $fast=Join-Path $root 'Rapido.vbs'
    foreach ($entry in $entries) {
        $child="$shell\$($entry.Key)"
        $icon=Join-Path $root ('verticale-grande-'+$entry.Hex.TrimStart('#')+'.ico')
        if (!(Test-Path -LiteralPath $icon)) { New-ColorIcon $entry.Hex $icon }
        New-Item -Path "$child\command" -Force | Out-Null
        New-ItemProperty -LiteralPath $child -Name MUIVerb -Value ($entry.Name.Replace('&','&&')) -Force | Out-Null
        New-ItemProperty -LiteralPath $child -Name Icon -Value ($icon+',0') -Force | Out-Null
        Set-Item -LiteralPath "$child\command" -Value ('"{0}" //B //Nologo "{1}" --color "%1" "{2}"' -f $hostPath,$fast,$entry.Hex)
    }
    $manage="$shell\yManage"
    New-Item -Path "$manage\command" -Force | Out-Null
    New-ItemProperty -LiteralPath $manage -Name MUIVerb -Value (T 'menuCustomize') -Force | Out-Null
    Set-Item -LiteralPath "$manage\command" -Value $base
    $original="$shell\zRestore"
    New-Item -Path "$original\command" -Force | Out-Null
    New-ItemProperty -LiteralPath $original -Name MUIVerb -Value (T 'menuRestore') -Force | Out-Null
    Set-Item -LiteralPath "$original\command" -Value ('"{0}" //B //Nologo "{1}" --restore "%1"' -f $hostPath,$fast)
    [FolderShell]::SHChangeNotify(0x08000000,0,[string]$null,[IntPtr]::Zero)
}
function New-ColorIcon([string]$Hex, [string]$Path) {
    $color = [Drawing.ColorTranslator]::FromHtml($Hex)
    $bmp = New-Object Drawing.Bitmap 256,256
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([Drawing.Color]::Transparent)
    $side = [Drawing.Color]::FromArgb(255,[int]($color.R+(255-$color.R)*0.12),[int]($color.G+(255-$color.G)*0.12),[int]($color.B+(255-$color.B)*0.12))
    $back = New-Object Drawing.SolidBrush $side
    $front = New-Object Drawing.SolidBrush $color
    try {
        $face=[Drawing.PointF[]]@([Drawing.PointF]::new(52,10),[Drawing.PointF]::new(192,10),[Drawing.PointF]::new(192,139),[Drawing.PointF]::new(204,152),[Drawing.PointF]::new(204,208),[Drawing.PointF]::new(52,208))
        $fold=[Drawing.PointF[]]@([Drawing.PointF]::new(52,10),[Drawing.PointF]::new(101,47),[Drawing.PointF]::new(101,245),[Drawing.PointF]::new(52,208))
        $g.FillPolygon($front,$face)
        $g.FillPolygon($back,$fold)
        $png = New-Object IO.MemoryStream
        try {
            $bmp.Save($png,[Drawing.Imaging.ImageFormat]::Png)
            $data = $png.ToArray()
            $stream = [IO.File]::Create($Path)
            $writer = New-Object IO.BinaryWriter $stream
            try {
                $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]1)
                $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0)
                $writer.Write([uint16]1); $writer.Write([uint16]32)
                $writer.Write([uint32]$data.Length); $writer.Write([uint32]22); $writer.Write($data)
            } finally { $writer.Dispose(); $stream.Dispose() }
        } finally { $png.Dispose() }
    } finally { $g.Dispose(); $bmp.Dispose(); $back.Dispose(); $front.Dispose() }
}
function Get-StatePath([string]$Target) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Target.ToLowerInvariant()))).Replace('-','') } finally { $sha.Dispose() }
    return Join-Path $root ($hash + '.json')
}
function Update-FolderIcon([string]$Target) {
    # PATHW plus FLUSH delivers a targeted notification before returning.
    [FolderShell]::SHChangeNotify(0x00002000,0x00003005,$Target,[IntPtr]::Zero)
    $parent=[IO.Directory]::GetParent($Target)
    if ($parent) { [FolderShell]::SHChangeNotify(0x00001000,0x00003005,$parent.FullName,[IntPtr]::Zero) }
}
function Set-FolderColor([string]$Target,[string]$Hex) {
    $iconPath = Join-Path $root ('verticale-grande-'+$Hex.TrimStart('#') + '.ico')
    if (!(Test-Path -LiteralPath $iconPath)) { New-ColorIcon $Hex $iconPath }
    Set-FolderIcon $Target $iconPath
    try { Save-RecentColor $Hex } catch {}
}
function Set-FolderPng([string]$Target,[string]$PngPath) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { $hash=[BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($PngPath))).Replace('-','') } finally { $sha.Dispose() }
    $iconPath=Join-Path $root ('immagine-'+$hash+'.ico')
    if (!(Test-Path -LiteralPath $iconPath)) { New-PngIcon $PngPath $iconPath }
    Set-FolderIcon $Target $iconPath
}
function New-PngIcon([string]$PngPath,[string]$IconPath) {
    $source=[Drawing.Image]::FromFile($PngPath)
    try {
        if ($source.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Png.Guid) { throw (T 'pngInvalid') }
        $frames=New-Object Collections.ArrayList
        foreach ($size in @(16,24,32,48,64,128,256)) {
            $bitmap=[Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics=[Drawing.Graphics]::FromImage($bitmap)
            $memory=[IO.MemoryStream]::new()
            try {
                $graphics.Clear([Drawing.Color]::Transparent)
                $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $scale=($size*0.94)/[Math]::Max($source.Width,$source.Height)
                $width=[int][Math]::Max(1.0,[Math]::Round($source.Width*$scale))
                $height=[int][Math]::Max(1.0,[Math]::Round($source.Height*$scale))
                $rect=[Drawing.Rectangle]::new([int](($size-$width)/2),[int](($size-$height)/2),$width,$height)
                $graphics.DrawImage($source,$rect)
                $bitmap.Save($memory,[Drawing.Imaging.ImageFormat]::Png)
                [void]$frames.Add([pscustomobject]@{Size=$size;Bytes=$memory.ToArray()})
            } finally { $memory.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
        }
        $stream=[IO.File]::Create($IconPath); $writer=[IO.BinaryWriter]::new($stream)
        try {
            $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$frames.Count)
            $offset=6+16*$frames.Count
            foreach ($frame in $frames) {
                $dimension=$frame.Size; if ($dimension -eq 256) { $dimension=0 }
                $writer.Write([byte]$dimension); $writer.Write([byte]$dimension); $writer.Write([byte]0); $writer.Write([byte]0)
                $writer.Write([uint16]1); $writer.Write([uint16]32); $writer.Write([uint32]$frame.Bytes.Length); $writer.Write([uint32]$offset)
                $offset+=$frame.Bytes.Length
            }
            foreach ($frame in $frames) { $writer.Write([byte[]]$frame.Bytes) }
        } finally { $writer.Dispose(); $stream.Dispose() }
    } finally { $source.Dispose() }
}
function Set-FolderIcon([string]$Target,[string]$iconPath) {
    $dir = Get-Item -LiteralPath $Target -Force
    if (!$dir.PSIsContainer) { throw (T 'folderInvalid') }
    $ini = Join-Path $Target 'desktop.ini'
    $statePath = Get-StatePath $Target
    if (!(Test-Path -LiteralPath $statePath)) {
        $state = @{ Folder=$Target; Attributes=[int]$dir.Attributes; HadIni=(Test-Path -LiteralPath $ini); IniAttributes=0; IniBytes='' }
        if ($state.HadIni) {
            $state.IniAttributes = [int](Get-Item -LiteralPath $ini -Force).Attributes
            $state.IniBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($ini))
        }
        $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    }
    if (Test-Path -LiteralPath $ini) { [IO.File]::SetAttributes($ini,[IO.FileAttributes]::Normal) }
    else { [IO.File]::WriteAllText($ini,"[.ShellClassInfo]`r`n",[Text.Encoding]::Unicode) }
    if (![FolderShell]::WritePrivateProfileString('.ShellClassInfo','IconResource',($iconPath + ',0'),$ini)) { throw (T 'iniError') }
    [IO.File]::SetAttributes($ini,([IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System))
    [IO.File]::SetAttributes($Target,($dir.Attributes -bor [IO.FileAttributes]::ReadOnly))
    Update-FolderIcon $Target
}
function Get-RenameDestination([string]$Target,[string]$Name) {
    $directory=Get-Item -LiteralPath $Target -Force
    if (!$directory.PSIsContainer -or !$directory.Parent) { throw (T 'invalidFolderName') }
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Length -gt 255 -or $Name -match '[<>:"/\\|?*\x00-\x1F]' -or $Name -match '[ .]$' -or $Name -in @('.','..')) { throw (T 'invalidFolderName') }
    $base=($Name -split '\.')[0].TrimEnd(' ')
    if ($base -match '^(CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])$') { throw (T 'invalidFolderName') }
    $destination=[IO.Path]::GetFullPath((Join-Path $directory.Parent.FullName $Name))
    if (![string]::Equals([IO.Path]::GetDirectoryName($destination),$directory.Parent.FullName,[StringComparison]::OrdinalIgnoreCase)) { throw (T 'invalidFolderName') }
    if (![string]::Equals($destination,$directory.FullName,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $destination)) { throw (T 'folderNameExists') }
    return $destination
}
function Move-RenamedDirectory([string]$Source,[string]$Destination) {
    # Both absolute paths must be siblings; this operation never moves into another folder.
    $sourceFull=[IO.Path]::GetFullPath($Source); $destinationFull=[IO.Path]::GetFullPath($Destination)
    $parent=[IO.Path]::GetDirectoryName($sourceFull)
    if (![string]::Equals($parent,[IO.Path]::GetDirectoryName($destinationFull),[StringComparison]::OrdinalIgnoreCase)) { throw (T 'invalidFolderName') }
    if ([string]::Equals($sourceFull,$destinationFull,[StringComparison]::Ordinal)) { return }
    if ([string]::Equals($sourceFull,$destinationFull,[StringComparison]::OrdinalIgnoreCase)) {
        $temporary=Join-Path $parent ('.cc-rename-'+[Guid]::NewGuid().ToString('N'))
        if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($temporary)) -ne $parent -or (Test-Path -LiteralPath $temporary)) { throw (T 'invalidFolderName') }
        [IO.Directory]::Move($sourceFull,$temporary)
        try { [IO.Directory]::Move($temporary,$destinationFull) }
        catch { [IO.Directory]::Move($temporary,$sourceFull); throw }
    } else { [IO.Directory]::Move($sourceFull,$destinationFull) }
}
function Rename-Folder([string]$Target,[string]$Name) {
    $source=(Get-Item -LiteralPath $Target -Force).FullName
    $destination=Get-RenameDestination $source $Name
    if ([string]::Equals($source,$destination,[StringComparison]::Ordinal)) { return $source }
    $oldState=Get-StatePath $source; $newState=Get-StatePath $destination
    $sameState=[string]::Equals($oldState,$newState,[StringComparison]::OrdinalIgnoreCase)
    $records=New-Object Collections.Generic.List[object]
    $moved=$false
    try {
        if (!$sameState -and (Test-Path -LiteralPath $newState)) { throw (T 'renameBackupConflict') }
        foreach ($file in (Get-ChildItem -LiteralPath $root -Filter '*.json' -File)) {
            if ($file.Name -notmatch '^[0-9A-Fa-f]{64}\.json$') { continue }
            try { $state=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
            catch { if ($file.FullName -eq $oldState) { throw }; continue }
            if (!$state.Folder -or $state.Folder -isnot [string]) { continue }
            $isFolder=[string]::Equals($state.Folder,$source,[StringComparison]::OrdinalIgnoreCase)
            $isChild=$state.Folder.StartsWith($source+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)
            if (!$isFolder -and !$isChild) { continue }
            $newFolder=$destination+$state.Folder.Substring($source.Length)
            $newPath=Get-StatePath $newFolder
            $same=[string]::Equals($file.FullName,$newPath,[StringComparison]::OrdinalIgnoreCase)
            if (!$same -and (Test-Path -LiteralPath $newPath)) { throw (T 'renameBackupConflict') }
            $original=[IO.File]::ReadAllBytes($file.FullName)
            $state.Folder=$newFolder
            $record=[pscustomobject]@{Old=$file.FullName;New=$newPath;Same=$same;Original=$original;Temporary=($newPath+'.'+[Guid]::NewGuid().ToString('N').Substring(0,8)+'.tmp');Committed=$false;Created=$false}
            $records.Add($record)
            [IO.File]::WriteAllText($record.Temporary,($state | ConvertTo-Json -Depth 8),[Text.Encoding]::UTF8)
        }
        Move-RenamedDirectory $source $destination; $moved=$true
        foreach ($record in $records) {
            if ($record.Same) { [IO.File]::Replace($record.Temporary,$record.Old,[NullString]::Value) }
            else {
                [IO.File]::Move($record.Temporary,$record.New); $record.Created=$true
                [IO.File]::Delete($record.Old)
            }
            $record.Committed=$true
        }
    } catch {
        $failure=$_
        foreach ($record in $records) {
            if ($record.Committed -or $record.Created) {
                [IO.File]::WriteAllBytes($record.Old,$record.Original)
                if (!$record.Same -and [IO.File]::Exists($record.New)) { [IO.File]::Delete($record.New) }
            }
        }
        if ($moved) { Move-RenamedDirectory $destination $source }
        throw $failure
    } finally {
        foreach ($record in $records) { if ([IO.File]::Exists($record.Temporary)) { [IO.File]::Delete($record.Temporary) } }
    }
    [FolderShell]::SHRenameNotify(0x00020000,0x00003005,$source,$destination)
    Update-FolderIcon $destination
    return $destination
}
function Restore-Folder([string]$Target) {
    $statePath = Get-StatePath $Target
    if (!(Test-Path -LiteralPath $statePath)) { throw (T 'backupError') }
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $ini = Join-Path $Target 'desktop.ini'
    if (Test-Path -LiteralPath $ini) { [IO.File]::SetAttributes($ini,[IO.FileAttributes]::Normal) }
    if ($state.HadIni) {
        [IO.File]::WriteAllBytes($ini,[Convert]::FromBase64String($state.IniBytes))
        [IO.File]::SetAttributes($ini,[IO.FileAttributes]$state.IniAttributes)
    } elseif (Test-Path -LiteralPath $ini) { Remove-Item -LiteralPath $ini -Force }
    [IO.File]::SetAttributes($Target,[IO.FileAttributes]$state.Attributes)
    Remove-Item -LiteralPath $statePath
    Update-FolderIcon $Target
}
function New-FolderUndo([string]$Target) {
    $folder=Get-Item -LiteralPath $Target -Force; $ini=Join-Path $folder.FullName 'desktop.ini'; $state=Get-StatePath $folder.FullName
    [pscustomobject]@{Original=$folder.FullName;Current=$folder.FullName;Attributes=[int]$folder.Attributes;HadIni=[IO.File]::Exists($ini);IniBytes=$(if ([IO.File]::Exists($ini)) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($ini)) } else { '' });IniAttributes=$(if ([IO.File]::Exists($ini)) { [int][IO.File]::GetAttributes($ini) } else { 0 });HadState=[IO.File]::Exists($state);StateBytes=$(if ([IO.File]::Exists($state)) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($state)) } else { '' })}
}
function Save-FolderUndo($Record) {
    $path=Join-Path $root 'ultima-modifica.json'; $temporary=$path+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
    try { [IO.File]::WriteAllText($temporary,($Record | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($true)); if ([IO.File]::Exists($path)) { [IO.File]::Replace($temporary,$path,[NullString]::Value) } else { [IO.File]::Move($temporary,$path) } } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Restore-UndoRecord($record) {
    $Target=$record.Current
    if ($record.Current -ne [IO.Path]::GetFullPath($Target) -or [IO.Path]::GetDirectoryName($record.Original) -ne [IO.Path]::GetDirectoryName($record.Current)) { throw (T 'backupError') }
    $iniBytes=[byte[]]::new(0); $stateBytes=[byte[]]::new(0); if ($record.HadIni) { $iniBytes=[Convert]::FromBase64String($record.IniBytes) }; if ($record.HadState) { $stateBytes=[Convert]::FromBase64String($record.StateBytes) }
    $restored=Rename-Folder $Target ([IO.Path]::GetFileName($record.Original)); $ini=Join-Path $restored 'desktop.ini'
    if ([IO.File]::Exists($ini)) { [IO.File]::SetAttributes($ini,[IO.FileAttributes]::Normal) }
    if ($record.HadIni) { [IO.File]::WriteAllBytes($ini,$iniBytes); [IO.File]::SetAttributes($ini,[IO.FileAttributes]$record.IniAttributes) } elseif ([IO.File]::Exists($ini)) { [IO.File]::Delete($ini) }
    $state=Get-StatePath $restored
    if ($record.HadState) { [IO.File]::WriteAllBytes($state,$stateBytes) } elseif ([IO.File]::Exists($state)) { [IO.File]::Delete($state) }
    [IO.File]::SetAttributes($restored,[IO.FileAttributes]$record.Attributes); Update-FolderIcon $restored; return $restored
}
function Undo-FolderEdit([string]$Target) {
    $path=Join-Path $root 'ultima-modifica.json'; $record=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($record.Batch) {
        if (!@($record.Batch | Where-Object { $_.Current -eq $Target }).Count) { throw (T 'backupError') }
        foreach ($entry in $record.Batch) { $null=Restore-UndoRecord $entry }; [IO.File]::Delete($path); Remove-ActivityForRecord $record; return $Target
    }
    if ($record.Current -ne [IO.Path]::GetFullPath($Target)) { throw (T 'backupError') }
    $restored=Restore-UndoRecord $record; [IO.File]::Delete($path); Remove-ActivityForRecord $record; return $restored
}
. (Join-Path $PSScriptRoot 'Advanced.ps1')
if ($SelfTest) {
    Test-ProductBackend
    if ($NoConsoleTest) {
        if ([FolderShell]::IsWindowVisible([FolderShell]::GetConsoleWindow())) { throw 'Il processo ha una console visibile.' }
        Write-Output 'OK: nessuna console visibile.'
        [IO.File]::WriteAllText((Join-Path $root 'verifica-avvio.txt'),'OK: nessuna console visibile.')
    }
    $batchA=Join-Path $root 'Batch A'; $batchB=Join-Path $root 'Batch B'; New-Item -ItemType Directory -Path $batchA,$batchB -Force|Out-Null
    [IO.File]::WriteAllText((Join-Path $batchB 'desktop.ini'),''); $previousAttrs=[IO.File]::GetAttributes($batchB)
    Invoke-FolderBatch @($batchA,$batchB,$batchA) '#123456' ''
    if (![IO.File]::Exists((Join-Path $batchA 'desktop.ini')) -or ![IO.File]::Exists((Join-Path $batchB 'desktop.ini'))) { throw 'Cambio multiplo fallito.' }
    $null=Undo-FolderEdit $batchA
    if ([IO.File]::Exists((Join-Path $batchA 'desktop.ini')) -or [IO.File]::ReadAllBytes((Join-Path $batchB 'desktop.ini')).Length -ne 0 -or [IO.File]::GetAttributes($batchB) -ne $previousAttrs) { throw 'Annullamento multiplo fallito.' }
    $invalidBatch=$false; try { Invoke-FolderBatch @($batchA,(Join-Path $root 'missing-folder')) '#ABCDEF' '' } catch { $invalidBatch=$true }; if (!$invalidBatch -or [IO.File]::Exists((Join-Path $batchA 'desktop.ini'))) { throw 'Batch non valido modifica una cartella.' }
    $script:originalIconSetter=(Get-Command Set-FolderIcon).ScriptBlock; $script:batchFailureTarget=$batchB
    try {
        function Set-FolderIcon([string]$Target,[string]$iconPath) { if ($Target -eq $script:batchFailureTarget) { throw 'Simulated batch failure' }; & $script:originalIconSetter $Target $iconPath }
        $batchFailed=$false; try { Invoke-FolderBatch @($batchA,$batchB) '#ABCDEF' '' } catch { $batchFailed=$true }
        if (!$batchFailed -or [IO.File]::Exists((Join-Path $batchA 'desktop.ini')) -or [IO.File]::ReadAllBytes((Join-Path $batchB 'desktop.ini')).Length -ne 0) { throw 'Rollback parziale del batch non riuscito.' }
    } finally { Set-Item Function:Set-FolderIcon $script:originalIconSetter }
    for ($i=0;$i -lt 10;$i++) { Save-RecentColor ('#{0:X6}' -f $i) }; Save-RecentColor '#000009'; $recent=@(Read-RecentColors); if ($recent.Count -ne 8 -or $recent[0] -ne '#000009') { throw 'Colori recenti non corretti.' }
    $photo=[Drawing.Bitmap]::new(80,40); $g=[Drawing.Graphics]::FromImage($photo); $g.Clear([Drawing.Color]::Red); $g.Dispose()
    try {
        $fit=Render-PreparedImage $photo 1 0 0 $false 'none'; $cropped=Render-PreparedImage $photo 1 0 0 $true 'none'
        try { if ($fit.GetPixel(128,0).A -ne 0 -or $cropped.GetPixel(128,8).R -lt 240 -or $cropped.GetPixel(128,8).A -lt 240) { throw 'Ritaglio o proporzioni errati.' } } finally { $fit.Dispose(); $cropped.Dispose() }
        foreach ($badge in @('star','check','lock')) { $marked=Render-PreparedImage $photo 1 0 0 $false $badge; try { if ($marked.GetPixel(239,207).B -lt 200) { throw 'Contrassegno non disegnato.' } } finally { $marked.Dispose() } }
    } finally { $photo.Dispose() }
    Write-Output 'OK: batch e annullamento, convalida completa, recenti, ritaglio e tre contrassegni.'
    $undoTarget=Join-Path $root 'Test annulla'; New-Item -ItemType Directory -Path $undoTarget -Force | Out-Null
    Set-FolderColor $undoTarget '#123456'; $originalIcon=[IO.File]::ReadAllBytes((Join-Path $undoTarget 'desktop.ini')); $snapshot=New-FolderUndo $undoTarget
    $changed=Rename-Folder $undoTarget 'Test annulla rinominato'; $snapshot.Current=$changed; Save-FolderUndo $snapshot; Set-FolderColor $changed '#ABCDEF'
    $returned=Undo-FolderEdit $changed
    if ($returned -ne $undoTarget -or [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $returned 'desktop.ini'))) -ne [Convert]::ToBase64String($originalIcon)) { throw 'Annulla non ripristina nome e icona precedenti.' }
    Restore-Folder $returned
    $target = Join-Path $root 'Cartella prova' 
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    $ini = Join-Path $target 'desktop.ini'
    [IO.File]::WriteAllText($ini,"[.ShellClassInfo]`r`nInfoTip=Test originale`r`n",[Text.Encoding]::Unicode)
    $before = [IO.File]::ReadAllBytes($ini)
    $attributes = (Get-Item -LiteralPath $target -Force).Attributes
    Set-FolderColor $target '#12ABEF'
    $icon = New-Object Drawing.Icon (Join-Path $root 'verticale-grande-12ABEF.ico')
    if ($icon.Width -ne 256) { throw 'Dimensione icona errata' }; $icon.Dispose()
    if (!(Get-Content -LiteralPath $ini -Raw).Contains('InfoTip=Test originale')) { throw 'Metadati persi' }
    Set-FolderColor $target '#FF0000'
    Restore-Folder $target
    if ([Convert]::ToBase64String($before) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($ini))) { throw 'Ripristino errato' }
    if ((Get-Item -LiteralPath $target -Force).Attributes -ne $attributes) { throw 'Attributi errati' }
    $empty = Join-Path $root 'Senza configurazione'
    New-Item -ItemType Directory -Path $empty -Force | Out-Null
    Set-FolderColor $empty '#00FF00'; Restore-Folder $empty
    if (Test-Path -LiteralPath (Join-Path $empty 'desktop.ini')) { throw 'Ripristino cartella nuova errato' }
    $pngPath=Join-Path $root 'prova-trasparente.png'
    $bmp=[Drawing.Bitmap]::new(120,60)
    $g=[Drawing.Graphics]::FromImage($bmp)
    try { $g.Clear([Drawing.Color]::Transparent); $g.FillRectangle([Drawing.Brushes]::Red,20,10,80,40); $bmp.Save($pngPath,[Drawing.Imaging.ImageFormat]::Png) } finally { $g.Dispose(); $bmp.Dispose() }
    $pngIcon=Join-Path $root 'prova-png.ico'
    New-PngIcon $pngPath $pngIcon
    $bytes=[IO.File]::ReadAllBytes($pngIcon)
    if ([BitConverter]::ToUInt16($bytes,4) -ne 7) { throw 'Dimensioni PNG mancanti' }
    $offset=[BitConverter]::ToUInt32($bytes,6+6*16+12)
    $imageStream=[IO.MemoryStream]::new($bytes,[int]$offset,($bytes.Length-[int]$offset))
    $decoded=[Drawing.Bitmap]::new($imageStream)
    try {
        if ($decoded.GetPixel(0,0).A -ne 0 -or $decoded.GetPixel(128,128).R -ne 255) { throw 'Trasparenza PNG errata' }
        if ($decoded.GetPixel(128,40).A -ne 0) { throw 'Proporzioni PNG errate' }
    } finally { $decoded.Dispose(); $imageStream.Dispose() }
    Set-FolderPng $empty $pngPath
    if (!(Get-Content -LiteralPath (Join-Path $empty 'desktop.ini') -Raw).Contains('immagine-')) { throw 'Icona PNG non applicata' }
    Restore-Folder $empty
    if (Test-Path -LiteralPath (Join-Path $empty 'desktop.ini')) { throw 'Ripristino PNG errato' }
    $testPalette=@(0..149 | ForEach-Object { [pscustomobject]@{Name=('Nome libero '+$_);Hex='#12ABEF'} })
    ConvertTo-Json -InputObject $testPalette | Set-Content -LiteralPath $palettePath -Encoding UTF8
    $entries=@(Get-MenuEntries)
    if ($entries.Count -ne 150) { throw 'Colori mancanti nel menu' }
    $testPalette[0].Name='Nome rinominato & personale'
    ConvertTo-Json -InputObject $testPalette | Set-Content -LiteralPath $palettePath -Encoding UTF8
    if (@(Get-MenuEntries)[0].Name -ne 'Nome rinominato & personale') { throw 'Rinomina errata' }
    $renameTarget=Join-Path $root 'Rinomina [prova]'
    New-Item -ItemType Directory -Path $renameTarget -Force | Out-Null
    $payload=Join-Path $renameTarget 'contenuto.txt'
    [IO.File]::WriteAllText($payload,'contenuto invariato',[Text.Encoding]::UTF8)
    $renameIni=Join-Path $renameTarget 'desktop.ini'
    [IO.File]::WriteAllText($renameIni,"[.ShellClassInfo]`r`nInfoTip=Prima della rinomina`r`n",[Text.Encoding]::Unicode)
    $originalIni=[IO.File]::ReadAllBytes($renameIni)
    Set-FolderColor $renameTarget '#112233'
    $childTarget=Join-Path $renameTarget 'Sottocartella'
    New-Item -ItemType Directory -Path $childTarget -Force | Out-Null
    Set-FolderColor $childTarget '#445566'
    $childBackup=Get-StatePath $childTarget
    $oldBackup=Get-StatePath $renameTarget
    $renamed=Rename-Folder $renameTarget 'Nuovo nome 日本語 [test]'
    $newBackup=Get-StatePath $renamed
    if ((Test-Path -LiteralPath $renameTarget) -or !(Test-Path -LiteralPath $renamed) -or (Test-Path -LiteralPath $oldBackup) -or !(Test-Path -LiteralPath $newBackup)) { throw 'Rinomina o migrazione backup non riuscita.' }
    $renamedState=Get-Content -LiteralPath $newBackup -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($renamedState.Folder -ne $renamed -or [IO.File]::ReadAllText((Join-Path $renamed 'contenuto.txt')) -ne 'contenuto invariato') { throw 'Rinomina altera stato o contenuto.' }
    Restore-Folder $renamed
    $renamedChild=Join-Path $renamed 'Sottocartella'
    if ((Test-Path -LiteralPath $childBackup) -or !(Test-Path -LiteralPath (Get-StatePath $renamedChild))) { throw 'Backup della sottocartella non trasferito.' }
    Restore-Folder $renamedChild
    if (Test-Path -LiteralPath (Join-Path $renamedChild 'desktop.ini')) { throw 'Ripristino sottocartella dopo rinomina errato.' }
    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $renamed 'desktop.ini'))) -ne [Convert]::ToBase64String($originalIni)) { throw 'Ripristino dopo rinomina errato.' }
    foreach ($badName in @('','..','CON.txt','LPT1','COM¹','a/b','a\b','a:b','nome.','nome ')) {
        $rejected=$false
        try { Rename-Folder $renamed $badName | Out-Null } catch { $rejected=$true }
        if (!$rejected -or !(Test-Path -LiteralPath $renamed)) { throw ('Nome non valido accettato: '+$badName) }
    }
    $occupied=Join-Path $root 'Nome occupato'
    New-Item -ItemType Directory -Path $occupied -Force | Out-Null
    $rejected=$false
    try { Rename-Folder $renamed 'Nome occupato' | Out-Null } catch { $rejected=$true }
    if (!$rejected -or !(Test-Path -LiteralPath $renamed) -or !(Test-Path -LiteralPath $occupied)) { throw 'Collisione di nomi non protetta.' }
    $caseTarget=Join-Path $root 'CaseTest'
    New-Item -ItemType Directory -Path $caseTarget -Force | Out-Null
    Set-FolderColor $caseTarget '#ABCDEF'
    $caseRenamed=Rename-Folder $caseTarget 'CASETEST'
    if ((Get-Item -LiteralPath $caseRenamed).Name -cne 'CASETEST') { throw 'Rinomina delle sole maiuscole non riuscita.' }
    Restore-Folder $caseRenamed
    if (Test-Path -LiteralPath (Join-Path $caseRenamed 'desktop.ini')) { throw 'Ripristino delle sole maiuscole errato.' }
    $conflicting=Join-Path $root 'Backup preesistente'
    $conflictingState=Get-StatePath $conflicting
    [IO.File]::WriteAllText($conflictingState,'backup da conservare',[Text.Encoding]::UTF8)
    $rejected=$false
    try { Rename-Folder $renamed 'Backup preesistente' | Out-Null } catch { $rejected=$true }
    if (!$rejected -or !(Test-Path -LiteralPath $renamed) -or [IO.File]::ReadAllText($conflictingState) -ne 'backup da conservare') { throw 'Backup preesistente sovrascritto.' }
    Write-Output 'OK: rinomina Unicode, contenuti conservati, backup trasferito, ripristino, nomi vietati, collisioni e sole maiuscole.'
    Write-Output 'OK: icone colore e PNG, 7 dimensioni, trasparenza, proporzioni, ripristino e palette.'
    exit
}
if ($Worker) {
    $mutex=[Threading.Mutex]::new($false,'Local\CartelleColorate.Worker')
    $owned=$false
    try {
        try { $owned=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned=$true }
        if (!$owned) { exit }
        $queue=Join-Path $root 'coda'; New-Item -ItemType Directory -Path $queue -Force | Out-Null
        $heartbeat=Join-Path $root 'worker.attivo'; $stop=Join-Path $root 'worker.stop'
        $lastRequest=[DateTime]::UtcNow; $lastBeat=[DateTime]::MinValue
        while (([DateTime]::UtcNow-$lastRequest).TotalMinutes -lt 20 -and !(Test-Path -LiteralPath $stop)) {
            if (([DateTime]::UtcNow-$lastBeat).TotalSeconds -gt 2) { [IO.File]::WriteAllText($heartbeat,'ready'); $lastBeat=[DateTime]::UtcNow }
            foreach ($request in [IO.Directory]::GetFiles($queue,'*.cmd')) {
                Read-LanguagePreference
                try {
                    $lines=[IO.File]::ReadAllLines($request,[Text.Encoding]::Unicode)
                    if ($lines.Length -eq 3 -and $lines[0] -eq '--color' -and $lines[2] -match '^#[0-9A-Fa-f]{6}$') { $undo=New-FolderUndo $lines[1]; Save-FolderUndo $undo; Set-FolderColor $lines[1] $lines[2].ToUpperInvariant(); Save-FolderActivity $undo 'apply' }
                    elseif ($lines.Length -eq 2 -and $lines[0] -eq '--restore') { $undo=New-FolderUndo $lines[1]; Restore-Folder $lines[1]; Save-FolderUndo $undo; Save-FolderActivity $undo 'restoreOriginal' }
                    else { throw (T 'requestError') }
                } catch { [Windows.Forms.MessageBox]::Show((Translate-Error $_.Exception.Message),'CartelleColorate') | Out-Null }
                finally { [IO.File]::Delete($request); $lastRequest=[DateTime]::UtcNow }
            }
            Start-Sleep -Milliseconds 40
        }
    } finally {
        if ($owned) {
            if ($heartbeat -and [IO.File]::Exists($heartbeat)) { [IO.File]::Delete($heartbeat) }
            if ($stop -and [IO.File]::Exists($stop)) { [IO.File]::Delete($stop) }
            $mutex.ReleaseMutex()
        }
        $mutex.Dispose()
    }
    exit
}
if ($RefreshMenu) { Update-Menu; exit }
[Windows.Forms.Application]::EnableVisualStyles()
if (!$Folder -or !(Test-Path -LiteralPath $Folder -PathType Container)) { [Windows.Forms.MessageBox]::Show((T 'openFromFolder'),'CartelleColorate') | Out-Null; exit }
$Folder = (Get-Item -LiteralPath $Folder -Force).FullName
if ($Color -or $Restore) {
    try {
        if ($Restore) { $undo=New-FolderUndo $Folder; Restore-Folder $Folder; Save-FolderUndo $undo; Save-FolderActivity $undo 'restoreOriginal' }
        else {
            if ($Color -notmatch '^#[0-9A-Fa-f]{6}$') { throw (T 'colorInvalid') }
            $undo=New-FolderUndo $Folder; Save-FolderUndo $undo; Set-FolderColor $Folder $Color.ToUpperInvariant(); Save-FolderActivity $undo 'apply'
        }
    } catch { [Windows.Forms.MessageBox]::Show((Translate-Error $_.Exception.Message),'CartelleColorate') | Out-Null; exit 1 }
    exit
}
. (Join-Path $PSScriptRoot 'Interfaccia.ps1')
