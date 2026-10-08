param(
    [string]$Repository=(Split-Path $PSScriptRoot -Parent),
    [string]$Output=(Join-Path (Split-Path $PSScriptRoot -Parent) 'dist\store'),
    [string]$PackageName='NovaPrism.Development',
    [string]$Publisher='CN=NovaPrismDevelopment',
    [string]$PublisherDisplayName='Nova Prism Development',
    [string]$Version='3.0.0.0',
    [switch]$Submission,[switch]$SkipNative,[switch]$SkipPack
)
$ErrorActionPreference='Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1.' }
if ($Submission -and ($PackageName -eq 'NovaPrism.Development' -or $Publisher -eq 'CN=NovaPrismDevelopment')) { throw 'Submission requires the exact Partner Center identity.' }
if ($PackageName -notmatch '^[A-Za-z0-9.-]{3,50}$' -or $Version -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw 'Invalid package identity or version.' }
if ([version]$Version -lt [version]'3.0.0.0') { throw 'Package version must be at least 3.0.0.0.' }
$payload=Join-Path $Output ('payload-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $payload,$Output -Force|Out-Null
$exclude=@('Setup.ps1','Avvio.ps1','Avvio.vbs','Rapido.vbs','Installa.cmd','Rimuovi-menu.cmd','Verifica.vbs','AutoUpdate.ps1')
Get-ChildItem -LiteralPath (Join-Path $Repository 'src') -File | Where-Object {$_.Name -notin $exclude} | Copy-Item -Destination $payload
Copy-Item -LiteralPath (Join-Path $Repository 'VERSION'),(Join-Path $Repository 'LICENSE') -Destination $payload
$utf8=[Text.UTF8Encoding]::new($true)
# Changes are applied to this payload only; the ordinary installer stays unchanged.
$main=Join-Path $payload 'CartelleColorate.ps1'
$content=[IO.File]::ReadAllText($main)
$content=$content.Replace('param([string]$Folder,','param([string[]]$SelectedFolders, [string]$Folder,')
$content=$content.Replace(". (Join-Path `$PSScriptRoot 'Interfaccia.ps1')", ". (Join-Path `$PSScriptRoot 'StoreOverrides.ps1')`r`n. (Join-Path `$PSScriptRoot 'Interfaccia.ps1')")
[IO.File]::WriteAllText($main,$content,$utf8)
$uiFile=Join-Path $payload 'Interfaccia.ps1'
$content=[IO.File]::ReadAllText($uiFile)
$content=$content.Replace('Initialize-ProductInterface', "Initialize-ProductInterface`r`nif (`$SelectedFolders.Count -gt 0) { Select-ProductFolders `$SelectedFolders }")
[IO.File]::WriteAllText($uiFile,$content,$utf8)
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'StoreOverrides.ps1') -Destination $payload
foreach($name in @('FolderShell','DesktopPicker')) {
    Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $payload ($name+'.cs')))) -OutputAssembly (Join-Path $payload ($name+'.dll')) -OutputType Library -ReferencedAssemblies System.dll,System.Core.dll,System.Drawing.dll
}
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$automation=Get-ChildItem -LiteralPath (Join-Path $env:WINDIR 'Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation') -Recurse -Filter System.Management.Automation.dll | Select-Object -First 1 -ExpandProperty FullName
& $csc /nologo /target:winexe /platform:x64 /optimize+ /reference:System.Core.dll /reference:System.Windows.Forms.dll ('/reference:'+$automation) ('/out:'+(Join-Path $payload 'NovaPrism.exe')) (Join-Path $PSScriptRoot 'Launcher.cs')
if ($LASTEXITCODE -ne 0) { throw 'Launcher compilation failed.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'NovaPrism.exe.config') -Destination $payload
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Assets') -Destination $payload -Recurse
if (!$SkipNative) {
    Push-Location $payload
    try {
        & cl.exe /nologo /LD /MT /EHsc /std:c++17 /W4 (Join-Path $PSScriptRoot 'Command.cpp') /link /OUT:NovaPrismCommand.dll shell32.lib shlwapi.lib ole32.lib runtimeobject.lib
        if ($LASTEXITCODE -ne 0) { throw 'Explorer command compilation failed.' }
    } finally { Pop-Location }
    foreach ($name in @('Command.obj','NovaPrismCommand.lib','NovaPrismCommand.exp')) { $file=Join-Path $payload $name; if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file} }
}
[xml]$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'AppxManifest.xml') -Raw
$manifest.Package.Identity.Name=$PackageName; $manifest.Package.Identity.Publisher=$Publisher; $manifest.Package.Identity.Version=$Version
$manifest.Package.Properties.PublisherDisplayName=$PublisherDisplayName
$manifest.Save((Join-Path $payload 'AppxManifest.xml'))
if (!$SkipPack) {
    if($SkipNative){throw 'Cannot package without the native Explorer command.'}
    $makeappx=Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\makeappx.exe" | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
    if(!$makeappx){throw 'Windows SDK MakeAppx is required.'}
    $package=Join-Path $Output ('NovaPrism-'+$Version+'-x64.msix')
    & $makeappx pack /d $payload /p $package /o
    if($LASTEXITCODE -ne 0){throw 'MSIX validation/packaging failed.'}
    (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($package) | Set-Content -LiteralPath (Join-Path $Output 'SHA256SUMS.txt') -Encoding ASCII
}
[IO.File]::WriteAllText((Join-Path $Output 'payload-path.txt'),$payload)
@{submissionIdentity=[bool]$Submission;packageName=$PackageName;publisher=$Publisher;publisherDisplayName=$PublisherDisplayName;version=$Version;architecture='x64';signed=$false;storeUpdates=$true} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Output 'BUILD-INFO.json') -Encoding UTF8
Write-Output ('Payload: '+$payload)
