param([switch]$Test)
$ErrorActionPreference='Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or [Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    throw 'Usa Windows PowerShell 5.1 in STA: powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File scripts\Build.ps1 -Test'
}
$repo=Split-Path $PSScriptRoot -Parent
$version=(Get-Content -LiteralPath (Join-Path $repo 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?$') { throw 'Versione non valida.' }
$work=Join-Path $repo ('work\build-'+[Guid]::NewGuid().ToString('N'))
$package=Join-Path $work 'CartelleColorate'
$dist=Join-Path $repo 'dist'
New-Item -ItemType Directory -Path $package,$dist -Force | Out-Null
$files=@('CartelleColorate.ps1','Advanced.ps1','Interfaccia.ps1','Localization.ps1','Avvio.ps1','NativeLibraries.ps1','Languages.json','LauncherMessages.txt','Avvio.vbs','Rapido.vbs','Setup.ps1','Installa.cmd','Rimuovi-menu.cmd','Verifica.vbs','FolderShell.cs','DesktopPicker.cs')
foreach ($file in $files) { Copy-Item -LiteralPath (Join-Path $repo ('src\'+$file)) -Destination $package }
foreach ($name in @('FolderShell','DesktopPicker')) {
    $source=Join-Path $package ($name+'.cs')
    Add-Type -TypeDefinition ([IO.File]::ReadAllText($source)) -OutputAssembly (Join-Path $package ($name+'.dll')) -OutputType Library
}
Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination $package
Copy-Item -LiteralPath (Join-Path $repo 'docs\LEGGIMI.txt') -Destination $package
Copy-Item -LiteralPath (Join-Path $repo 'VERSION') -Destination $package
if ($Test) {
    $ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    Write-Warning 'La build verifica icone e interfaccia; Windows Script Host va verificato sul PC di installazione.'
    & $ps -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $package 'CartelleColorate.ps1') -SelfTest
    if ($LASTEXITCODE -ne 0) { throw 'Test icone falliti.' }
    & $ps -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $repo 'scripts/TestLocalization.ps1') -Package $package -OutputDirectory $work
    if ($LASTEXITCODE -ne 0) { throw 'Test lingue falliti.' }
    & $ps -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $repo 'scripts/TestDownloadedPackage.ps1') -Package $package -OutputDirectory $work
    if ($LASTEXITCODE -ne 0) { throw 'Test pacchetto scaricato falliti.' }
    $preview=Join-Path $work 'anteprima.png'
    & $ps -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $package 'CartelleColorate.ps1') -Folder $package -Theme Dark -Language it -UITest -Preview $preview
    if ($LASTEXITCODE -ne 0) { throw 'Test interfaccia falliti.' }
    $testData=Join-Path $package 'test-data'
    if (Test-Path -LiteralPath $testData) {
        $resolved=(Resolve-Path -LiteralPath $testData).Path
        if ($resolved -ne $testData) { throw 'Percorso test inatteso.' }
        Move-Item -LiteralPath $testData -Destination (Join-Path $work 'test-data')
    }
    Copy-Item -LiteralPath $preview -Destination (Join-Path $repo 'docs\images\interfaccia.png') -Force
}
$manifest=@()
foreach ($file in (Get-ChildItem -LiteralPath $package -File | Sort-Object Name)) {
    $manifest+=((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+$file.Name)
}
[IO.File]::WriteAllLines((Join-Path $package 'MANIFEST-SHA256.txt'),$manifest,[Text.Encoding]::ASCII)
$zip=Join-Path $dist ('CartelleColorate-'+$version+'-windows.zip')
Compress-Archive -Path $package -DestinationPath $zip -Force
$checksum=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($zip)
[IO.File]::WriteAllText((Join-Path $dist 'SHA256SUMS.txt'),$checksum+[Environment]::NewLine,[Text.Encoding]::ASCII)
Write-Output ('Pacchetto pronto: '+$zip)
