param([Parameter(Mandatory=$true)][string]$Package)
$ErrorActionPreference='Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Questo test modifica il menu solo sul runner Windows isolato di GitHub Actions.' }
$root=Join-Path $env:LOCALAPPDATA 'CartelleColorate'
if (Test-Path -LiteralPath $root) { throw 'Il runner contiene già dati di CartelleColorate.' }
$menuKey='HKCU:\Software\Classes\Directory\shell\CartelleColorate'
if (Test-Path -LiteralPath $menuKey) { throw 'Il runner contiene già un menu di CartelleColorate.' }
New-Item -ItemType Directory -Path $root|Out-Null
Get-ChildItem -LiteralPath $Package -File|ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $root }
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
Add-Type -Path (Join-Path $root 'FolderShell.dll')
. (Join-Path $root 'Localization.ps1')
Initialize-Language $root 'en'
$palettePath=Join-Path $root 'colori.json'; $SelfTest=$true; $Preview='registry-test'
$tokens=$null; $errors=$null; $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'CartelleColorate.ps1'),[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw 'Sorgente non valido.' }
foreach ($statement in $ast.EndBlock.Statements) { if ($statement -is [Management.Automation.Language.FunctionDefinitionAst]) { . ([ScriptBlock]::Create($statement.Extent.Text)) } }
. (Join-Path $root 'Advanced.ps1')
$png=Join-Path $root 'menu-test.png'; $bitmap=[Drawing.Bitmap]::new(32,32); $graphics=[Drawing.Graphics]::FromImage($bitmap)
try { $graphics.Clear([Drawing.Color]::RoyalBlue); $bitmap.Save($png,[Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
$preset=Save-CompletePreset 'Favorite & PNG' '#1278AC' $png 'heart' '#FF2255'; Set-PresetFavorite $preset.Id
$presetStore='HKCU:\Software\Classes\CartelleColorate.Presets'
try {
    Update-Menu
    $entry=Join-Path $presetStore ('shell\'+$preset.Id); $label=Get-ItemPropertyValue -LiteralPath $entry -Name MUIVerb
    $command=(Get-Item -LiteralPath ($entry+'\command')).GetValue('')
    if ($label -ne 'Favorite && PNG' -or !$command.Contains('--preset') -or !$command.Contains($preset.Id)) { throw 'Il menu non contiene il preset preferito.' }
    $folder=Join-Path $root 'Menu target 日本語'; [IO.Directory]::CreateDirectory($folder)|Out-Null; [IO.File]::WriteAllText((Join-Path $folder 'contenuto.txt'),'intatto')
    $output=& cscript.exe '//Nologo' (Join-Path $root 'Rapido.vbs') '--preset' $folder $preset.Id 2>&1
    if ($LASTEXITCODE -ne 0 -or $output) { throw ('Il launcher rapido non è valido: '+($output -join ' ')) }
    $expectedIcon=Get-CompletePresetIcon $preset; $deadline=[DateTime]::UtcNow.AddSeconds(20); $actualIcon=''
    while ($actualIcon -ne $expectedIcon -and [DateTime]::UtcNow -lt $deadline) { try { $actualIcon=Get-FolderIconPath $folder } catch {}; if ($actualIcon -ne $expectedIcon) { Start-Sleep -Milliseconds 100 } }
    if ($actualIcon -ne $expectedIcon -or [IO.File]::ReadAllText((Join-Path $folder 'contenuto.txt')) -ne 'intatto') { throw 'Il preset del menu non è stato applicato dal worker.' }
    $deadline=[DateTime]::UtcNow.AddSeconds(5); while (!@(Read-FolderActivities).Count -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    $null=Undo-FolderEdit $folder
    if ([IO.File]::Exists((Join-Path $folder 'desktop.ini'))) { throw 'Preset rapido non annullabile.' }
    Set-PresetFavorite $preset.Id; Update-Menu
    if (Test-Path -LiteralPath 'HKCU:\Software\Classes\CartelleColorate.Menu\shell\pPresets') { throw 'Il menu dei preset non scompare quando è vuoto.' }
    Write-Output 'OK: menu Windows, anteprima PNG, nome con &, avvio Rapido.vbs, worker su cartella Unicode, annullamento e rimozione del preferito.'
} finally {
    [IO.File]::WriteAllText((Join-Path $root 'worker.stop'),'stop')
    foreach ($key in @($menuKey,'HKCU:\Software\Classes\CartelleColorate.Menu',$presetStore)) { if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse } }
}
