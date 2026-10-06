param([Parameter(Mandatory=$true)][string]$Package)
$ErrorActionPreference='Stop'
. (Join-Path $Package 'Localization.ps1')
$script:activeLanguage=$script:languageMap['en']
. (Join-Path $Package 'Productivity.ps1')
Add-Type -AssemblyName System.Net.Http
$client=[Net.Http.HttpClient]::new(); $client.Timeout=[TimeSpan]::FromSeconds(15)
try {
    $task=$client.GetStringAsync('https://raw.githubusercontent.com/yn7wvz64hj-oss/CartelleColorate/main/VERSION')
    $remote=$task.GetAwaiter().GetResult().Trim()
    $local=[IO.File]::ReadAllText((Join-Path $Package 'VERSION')).Trim()
    $null=Test-NewProductVersion $remote $local
    Write-Output ('OK: controllo HTTPS della versione '+$remote)
} finally { $client.Dispose() }
