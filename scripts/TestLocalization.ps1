param([Parameter(Mandatory=$true)][string]$Package,[Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
. (Join-Path $Package 'Localization.ps1')
$testRoot=Join-Path $OutputDirectory ('languages-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
Initialize-Language $testRoot '' 'it-IT'
if ($script:hasLanguagePreference -or $script:activeLanguage.code -ne 'it') { throw 'Prima apertura: lingua non confermata o lingua iniziale errata.' }
$keys=@($script:languageMap['en'].strings.PSObject.Properties.Name)
if ($script:languageCatalog.languages.Count -ne 15) { throw 'Numero lingue errato.' }
if ((Resolve-LanguageCode 'zh-CN') -ne 'zh' -or (Resolve-LanguageCode 'pt-BR') -ne 'pt' -or (Resolve-LanguageCode 'nl-NL') -ne 'en') { throw 'Rilevamento lingua errato.' }
foreach ($language in $script:languageCatalog.languages) {
    if (@($language.strings.PSObject.Properties).Count -ne $keys.Count) { throw ('Chiavi mancanti: '+$language.code) }
    foreach ($key in $keys) {
        $property=$language.strings.PSObject.Properties[$key]
        if (!$property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) { throw ('Traduzione mancante: '+$language.code+'/'+$key) }
        $basePlaceholders=@([regex]::Matches($script:languageMap['en'].strings.$key,'\{\d+\}') | ForEach-Object {$_.Value}) -join ','
        $placeholders=@([regex]::Matches($property.Value,'\{\d+\}') | ForEach-Object {$_.Value}) -join ','
        if ($basePlaceholders -ne $placeholders) { throw ('Segnaposti errati: '+$language.code+'/'+$key) }
    }
    Save-LanguagePreference $language.code
    Initialize-Language $testRoot '' 'en-US'
    if (!$script:hasLanguagePreference -or $script:activeLanguage.code -ne $language.code -or (T 'change') -ne $language.strings.change) { throw ('Preferenza non ripristinata: '+$language.code) }
    if (!(T 'missingFiles' @('hello.png')).Contains('hello.png')) { throw ('Parametro non tradotto: '+$language.code) }
}
# Saving preferences must preserve unknown settings and leave palette bytes intact.
$palette=Join-Path $testRoot 'colori.json'
[IO.File]::WriteAllText($palette,'[{"Name":"Lavoro 日本語 العربية","Hex":"#123ABC"}]',[Text.Encoding]::UTF8)
$before=[Convert]::ToBase64String([IO.File]::ReadAllBytes($palette))
[IO.File]::WriteAllText($script:languageSettingsPath,'{"language":"en","extra":"preserve me"}',[Text.Encoding]::UTF8)
Save-LanguagePreference 'ar'
$settings=Get-Content -LiteralPath $script:languageSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($settings.extra -ne 'preserve me' -or $before -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($palette))) { throw 'Impostazioni o palette alterate.' }
if ((Translate-Error 'Impossibile attivare la pipetta.') -ne (T 'hookError')) { throw 'Errore nativo non tradotto.' }
if ((Translate-Error 'Exception calling Begin: Impossibile attivare la pipetta.') -ne (T 'hookError')) { throw 'Errore nativo incapsulato non tradotto.' }
[IO.File]::WriteAllText($script:languageSettingsPath,'{not json',[Text.Encoding]::UTF8)
Initialize-Language $testRoot '' 'ja-JP'
if ($script:hasLanguagePreference -or $script:activeLanguage.code -ne 'ja') { throw 'Preferenze danneggiate: ripristino errato.' }
Save-LanguagePreference 'ja'
[IO.File]::WriteAllText($script:languageSettingsPath,'{"language":"xx"}',[Text.Encoding]::UTF8)
Initialize-Language $testRoot '' 'en-US'
if ($script:hasLanguagePreference) { throw 'Lingua sconosciuta accettata.' }
$unknownFailed=$false
try { Save-LanguagePreference 'xx' } catch { $unknownFailed=$true }
if (!$unknownFailed) { throw 'Codice lingua sconosciuto accettato.' }
# Closing the first-run dialog keeps the preference unset; confirming writes it.
$dialog=New-LanguageDialog $null
$dialog.WindowStartupLocation='Manual'; $dialog.Left=-3000; $dialog.Top=-3000; $dialog.ShowInTaskbar=$false
$dialog.Add_ContentRendered({ $script:languageDialog.Window.Close() })
$null=$dialog.ShowDialog()
Read-LanguagePreference
if ($script:hasLanguagePreference) { throw 'Annullamento salva una preferenza.' }
$dialog=New-LanguageDialog $null
$dialog.WindowStartupLocation='Manual'; $dialog.Left=-3000; $dialog.Top=-3000; $dialog.ShowInTaskbar=$false
$dialog.Add_ContentRendered({
    $script:languageDialog.List.SelectedItem=$script:languageMap['ar']
    $script:languageDialog.Continue.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
})
if ($dialog.ShowDialog() -ne $true -or !$script:hasLanguagePreference -or $script:activeLanguage.code -ne 'ar') { throw 'Scelta iniziale non salvata.' }
# Preview the real first-run language dialog without creating a user preference.
$Theme='Dark'
Initialize-Language $testRoot 'it'
$dialog=New-LanguageDialog $null
$dialog.WindowStartupLocation='Manual'; $dialog.Left=-3000; $dialog.Top=-3000; $dialog.ShowInTaskbar=$false
$dialog.Show(); $dialog.UpdateLayout()
$bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$dialog.ActualWidth,[int]$dialog.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
$bitmap.Render($dialog)
$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$stream=[IO.File]::Create((Join-Path $OutputDirectory 'scelta-lingua.png'))
try { $encoder.Save($stream) } finally { $stream.Dispose(); $dialog.Close() }
$ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
foreach ($code in @('en','de','ar','ur','hi','bn','zh','ru','fr','ja','ko','pt','es','id')) {
    & $ps -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $Package 'CartelleColorate.ps1') -Folder $Package -Theme Dark -Language $code -UITest -Preview (Join-Path $OutputDirectory ('lingua-'+$code+'.png'))
    if ($LASTEXITCODE -ne 0) { throw ('Test interfaccia localizzata falliti: '+$code) }
}
Write-Output 'OK: 15 cataloghi completi, preferenza persistente, annullamento/conferma iniziale, palette conservata e 14 interfacce localizzate.'
