param([Parameter(Mandatory=$true)][string]$Package)
$ErrorActionPreference='Stop'
. (Join-Path $Package 'Localization.ps1')
$script:activeLanguage=$script:languageMap['en']
. (Join-Path $Package 'Productivity.ps1')
Add-Type -AssemblyName System.Net.Http
$client=[Net.Http.HttpClient]::new(); $client.Timeout=[TimeSpan]::FromSeconds(30); $client.DefaultRequestHeaders.UserAgent.ParseAdd('CartelleColorate-update-test')
try {
    $task=$client.GetStringAsync('https://raw.githubusercontent.com/yn7wvz64hj-oss/CartelleColorate/main/VERSION')
    $remote=$task.GetAwaiter().GetResult().Trim()
    $local=[IO.File]::ReadAllText((Join-Path $Package 'VERSION')).Trim()
    $null=Test-NewProductVersion $remote $local
    Write-Output ('OK: controllo HTTPS della versione '+$remote)
    $release=$client.GetStringAsync('https://api.github.com/repos/yn7wvz64hj-oss/CartelleColorate/releases/latest').GetAwaiter().GetResult() | ConvertFrom-Json
    $offer=Get-ReleaseOffer $release ($release.tag_name.Substring(1))
    $bytes=$client.GetByteArrayAsync($offer.Url).GetAwaiter().GetResult()
    $destination=Join-Path $Package ('test-data/remote-update-'+[Guid]::NewGuid().ToString('N'))
    $installer=Expand-VerifiedUpdate $bytes $offer $destination
    if (![IO.File]::Exists($installer)) { throw 'Pacchetto remoto non preparato.' }
    Write-Output 'OK: note della release e pacchetto ufficiale scaricato, verificato e preparato senza eseguire installazione.'
} finally { $client.Dispose() }
