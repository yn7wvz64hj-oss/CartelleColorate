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
if ($SelfTest) {
    if ($NoConsoleTest) {
        if ([FolderShell]::IsWindowVisible([FolderShell]::GetConsoleWindow())) { throw 'Il processo ha una console visibile.' }
        Write-Output 'OK: nessuna console visibile.'
        [IO.File]::WriteAllText((Join-Path $root 'verifica-avvio.txt'),'OK: nessuna console visibile.')
    }
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
                    if ($lines.Length -eq 3 -and $lines[0] -eq '--color' -and $lines[2] -match '^#[0-9A-Fa-f]{6}$') { Set-FolderColor $lines[1] $lines[2].ToUpperInvariant() }
                    elseif ($lines.Length -eq 2 -and $lines[0] -eq '--restore') { Restore-Folder $lines[1] }
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
        if ($Restore) { Restore-Folder $Folder }
        else {
            if ($Color -notmatch '^#[0-9A-Fa-f]{6}$') { throw (T 'colorInvalid') }
            Set-FolderColor $Folder $Color.ToUpperInvariant()
        }
    } catch { [Windows.Forms.MessageBox]::Show((Translate-Error $_.Exception.Message),'CartelleColorate') | Out-Null; exit 1 }
    exit
}
. (Join-Path $PSScriptRoot 'Interfaccia.ps1')
