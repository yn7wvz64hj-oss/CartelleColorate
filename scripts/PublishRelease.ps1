param([switch]$VerifyOnly)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$version=([IO.File]::ReadAllText((Join-Path $repo 'VERSION'))).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { Write-Output 'Pubblicazione automatica riservata alle release stabili.'; exit 0 }
$name='CartelleColorate-'+$version+'-windows.zip'
$zip=Join-Path $repo ('downloads/'+$name)
$digest=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
$lines=@([IO.File]::ReadAllLines((Join-Path $repo 'downloads/SHA256SUMS.txt')) | Where-Object { $_.EndsWith('  '+$name) })
if ($lines.Count -ne 1 -or $lines[0] -ne ($digest+'  '+$name)) { throw 'Checksum del pacchetto ufficiale non valido.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
function Read-ReleaseEntry([string]$Name) {
    $entry=$archive.GetEntry('CartelleColorate/'+$Name); if (!$entry) { $entry=$archive.GetEntry('CartelleColorate\'+$Name) }; if (!$entry) { throw ('File mancante nel pacchetto: '+$Name) }
    $stream=$entry.Open(); $memory=[IO.MemoryStream]::new()
    try { $stream.CopyTo($memory); return ,$memory.ToArray() } finally { $memory.Dispose(); $stream.Dispose() }
}
function Get-ReleaseHash([byte[]]$Bytes) {
    $sha=[Security.Cryptography.SHA256]::Create(); try { return [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Get-ComparableReleaseHash([byte[]]$Bytes,[string]$File) {
    # Git applies .gitattributes on checkout. Only text line endings may differ.
    if ($File -ne 'LauncherMessages.txt' -and [IO.Path]::GetExtension($File) -in @('.ps1','.vbs','.cmd','.cs','.md','.json','.txt')) {
        $encoding=[Text.UTF8Encoding]::new($false,$true)
        $Bytes=$encoding.GetBytes($encoding.GetString($Bytes).Replace("`r`n","`n"))
    }
    return Get-ReleaseHash $Bytes
}
try {
    $packedVersion=[Text.Encoding]::UTF8.GetString((Read-ReleaseEntry 'VERSION')).Trim()
    if ($packedVersion -ne $version) { throw 'Versione dello ZIP diversa dai sorgenti.' }
    foreach ($entry in $archive.Entries) { if ($entry.FullName.Replace('\','/') -match '(?i)(test-data|/work/|/dist/|\.exe$)') { throw 'Dati di sviluppo presenti nel pacchetto.' } }
    $manifest=[Text.Encoding]::ASCII.GetString((Read-ReleaseEntry 'MANIFEST-SHA256.txt')) -split '\r?\n'
    foreach ($line in $manifest) {
        if (!$line) { continue }
        if ($line -notmatch '^([a-f0-9]{64})  ([A-Za-z0-9_.-]+)$') { throw 'Manifest non valido.' }
        $expected=$matches[1]; $file=$matches[2]
        if ((Get-ReleaseHash (Read-ReleaseEntry $file)) -ne $expected) { throw ('File del pacchetto modificato: '+$file) }
        $source=Join-Path $repo ('src/'+$file)
        if ([IO.File]::Exists($source) -and (Get-ComparableReleaseHash ([IO.File]::ReadAllBytes($source)) $file) -ne (Get-ComparableReleaseHash (Read-ReleaseEntry $file) $file)) { throw ('Sorgente diverso dal pacchetto: '+$file) }
    }
    if ((Get-ComparableReleaseHash (Read-ReleaseEntry 'LEGGIMI.txt') 'LEGGIMI.txt') -ne (Get-ComparableReleaseHash ([IO.File]::ReadAllBytes((Join-Path $repo 'docs/LEGGIMI.txt'))) 'LEGGIMI.txt')) { throw 'Guida installabile non aggiornata.' }
} finally { $archive.Dispose() }
Write-Output ('OK: pacchetto ufficiale '+$version+', sorgenti, manifest e SHA256 verificati.')
if ($VerifyOnly) { exit 0 }
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:GITHUB_REPOSITORY -ne 'yn7wvz64hj-oss/CartelleColorate' -or $env:GITHUB_REF -ne 'refs/heads/main' -or $env:GITHUB_SHA -notmatch '^[a-f0-9]{40}$') { throw 'La pubblicazione richiede il workflow del repository ufficiale su main.' }
$tag='v'+$version
$displayVersion=if (([version]$version).Build -eq 0) { ([version]$version).ToString(2) } else { $version }; $releaseTitle='CartelleColorate '+$displayVersion+' — Official Release / Release ufficiale'
$notesPath=Join-Path $repo ('docs/RELEASE-'+$version+'.md')
$stage=Join-Path $repo ('work/release-'+[Guid]::NewGuid().ToString('N')); [IO.Directory]::CreateDirectory($stage)|Out-Null
$sums=Join-Path $stage 'SHA256SUMS.txt'; [IO.File]::WriteAllText($sums,$lines[0]+[Environment]::NewLine,[Text.Encoding]::ASCII)
$known=& gh release list --repo $env:GITHUB_REPOSITORY --limit 100 --json tagName
if ($LASTEXITCODE -ne 0) { throw 'Impossibile leggere le release esistenti.' }
$existing=@(($known | ConvertFrom-Json) | Where-Object { $_.tagName -eq $tag })
if (!$existing.Count) {
    & gh release create $tag $zip $sums --repo $env:GITHUB_REPOSITORY --target $env:GITHUB_SHA --title $releaseTitle --notes-file $notesPath --latest
    if ($LASTEXITCODE -ne 0) { throw 'Pubblicazione della release fallita.' }
} else {
    & gh release edit $tag --repo $env:GITHUB_REPOSITORY --title $releaseTitle --notes-file $notesPath
    if ($LASTEXITCODE -ne 0) { throw 'Aggiornamento del titolo e delle note fallito.' }
}
$result=& gh release view $tag --repo $env:GITHUB_REPOSITORY --json isDraft,isPrerelease,assets,url,name,body
if ($LASTEXITCODE -ne 0) { throw 'Impossibile verificare la release pubblicata.' }
$release=$result | ConvertFrom-Json
if ($release.name -ne $releaseTitle -or $release.body.Replace("`r`n","`n").Trim() -ne [IO.File]::ReadAllText($notesPath).Replace("`r`n","`n").Trim()) { throw 'Titolo o descrizione pubblicati diversi dalle note bilingui.' }
if ($release.isDraft -or $release.isPrerelease -or !(@($release.assets | Where-Object { $_.name -eq $name }).Count) -or !(@($release.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' }).Count)) { throw 'Release ufficiale incompleta.' }
$download=Join-Path $stage 'download'; [IO.Directory]::CreateDirectory($download)|Out-Null
& gh release download $tag --repo $env:GITHUB_REPOSITORY --pattern $name --pattern 'SHA256SUMS.txt' --dir $download
if ($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath (Join-Path $download $name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $digest -or [IO.File]::ReadAllText((Join-Path $download 'SHA256SUMS.txt')).Trim() -ne $lines[0]) { throw 'Allegati pubblicati diversi dal pacchetto verificato.' }
Write-Output ('OK: release ufficiale pubblicata e allegati riscaricati e verificati: '+$release.url)
