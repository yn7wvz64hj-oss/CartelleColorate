# Language resources are loaded once, including in the persistent color worker.
$script:languageCatalog=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Languages.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$script:builtInLanguages=@($script:languageCatalog.languages)
$script:languageMap=@{}
foreach ($entry in $script:languageCatalog.languages) { $script:languageMap[$entry.code]=$entry }

function Resolve-LanguageCode([string]$CultureName) {
    if ([string]::IsNullOrWhiteSpace($CultureName)) { return 'en' }; $code=$CultureName.Replace('_','-').ToLowerInvariant()
    if ($script:languageMap.ContainsKey($code)) { return $code }
    try { $culture=[Globalization.CultureInfo]::GetCultureInfo($code); while ($culture.Parent.Name) { $culture=$culture.Parent; $parent=$culture.Name.ToLowerInvariant(); if ($script:languageMap.ContainsKey($parent)) { return $parent } } } catch {}
    while ($code.Contains('-')) { $code=$code.Substring(0,$code.LastIndexOf('-')); if ($script:languageMap.ContainsKey($code)) { return $code } }
    return 'en'
}
function Initialize-Language([string]$DataRoot,[string]$Override,[string]$CultureName=[Globalization.CultureInfo]::CurrentUICulture.Name) {
    Load-LanguagePacks $DataRoot
    $script:languageSettingsPath=Join-Path $DataRoot 'impostazioni.json'
    $script:defaultLanguageCode=Resolve-LanguageCode $CultureName
    $script:activeLanguage=$script:languageMap[$script:defaultLanguageCode]
    $script:hasLanguagePreference=$false
    Read-LanguagePreference
    if ($Override) {
        if (!$script:languageMap.ContainsKey($Override)) { throw ('Unsupported language: '+$Override) }
        $script:activeLanguage=$script:languageMap[$Override]
    }
}
function Read-LanguagePreference {
    try {
        if (Test-Path -LiteralPath $script:languageSettingsPath) {
            $settings=Get-Content -LiteralPath $script:languageSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($settings.language -is [string] -and $script:languageMap.ContainsKey($settings.language)) {
                $script:activeLanguage=$script:languageMap[$settings.language]
                $script:hasLanguagePreference=$true
                return
            }
        }
    } catch { }
    $script:hasLanguagePreference=$false
    $script:activeLanguage=$script:languageMap[$script:defaultLanguageCode]
}
function T([string]$Key,[object[]]$Values=@()) {
    $property=$script:activeLanguage.strings.PSObject.Properties[$Key]
    if (!$property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
        $property=$script:languageMap['en'].strings.PSObject.Properties[$Key]
    }
    if (!$property) { throw ('Unknown language resource: '+$Key) }
    $text=[string]$property.Value
    if ($Values.Count) { return [string]::Format([Globalization.CultureInfo]::InvariantCulture,$text,$Values) }
    return $text
}
function Translate-Error([string]$Message) {
    # Translate known application errors while keeping Windows' own diagnostics intact.
    foreach ($property in $script:languageMap['it'].strings.PSObject.Properties) {
        if ($Message -eq [string]$property.Value) { return T $property.Name }
    }
    foreach ($key in @('hookError','screenError','pixelsUnreadable')) {
        if ($Message.Contains([string]$script:languageMap['it'].strings.$key)) { return T $key }
    }
    if ($Message -eq 'Non riesco a leggere quel punto. Riprova con la pipetta.') { return T 'pixelError' }
    return $Message
}
function Save-AppSetting([string]$Key,[string]$Value) {
    $temporary=$null
    try {
        $settings=[pscustomobject]@{}
        if (Test-Path -LiteralPath $script:languageSettingsPath) {
            try { $saved=Get-Content -LiteralPath $script:languageSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json; if ($saved -is [pscustomobject]) { $settings=$saved } } catch {}
        }
        $settings | Add-Member -NotePropertyName $Key -NotePropertyValue $Value -Force
        New-Item -ItemType Directory -Path (Split-Path $script:languageSettingsPath -Parent) -Force | Out-Null
        $temporary=$script:languageSettingsPath+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
        [IO.File]::WriteAllText($temporary,($settings | ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($true))
        if ([IO.File]::Exists($script:languageSettingsPath)) { [IO.File]::Replace($temporary,$script:languageSettingsPath,[NullString]::Value) } else { [IO.File]::Move($temporary,$script:languageSettingsPath) }
    } catch { throw [InvalidOperationException]::new((T 'settingsError'),$_.Exception) }
    finally { if ($temporary -and [IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Save-LanguagePreference([string]$Code) {
    if (!$script:languageMap.ContainsKey($Code)) { throw ('Unsupported language: '+$Code) }
    Save-AppSetting 'language' $Code
    $script:activeLanguage=$script:languageMap[$Code]; $script:hasLanguagePreference=$true
}
function Read-AppearancePreference {
    try {
        $saved=Get-Content -LiteralPath $script:languageSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($saved.appearance -eq 'Windows') { return 'Windows' }
    } catch {}
    return 'MacOS'
}
function Save-AppearancePreference([ValidateSet('Windows','MacOS')][string]$Style) { Save-AppSetting 'appearance' $Style }
function Set-LanguageResources($Window,$Language=$script:activeLanguage) {
    foreach ($property in $script:languageMap['en'].strings.PSObject.Properties) { $Window.Resources['L_'+$property.Name]=[string]$property.Value }; foreach ($property in $Language.strings.PSObject.Properties) { if (![string]::IsNullOrWhiteSpace([string]$property.Value)) { $Window.Resources['L_'+$property.Name]=[string]$property.Value } }
    $Window.FlowDirection=if ($Language.rtl) { 'RightToLeft' } else { 'LeftToRight' }
    $Window.Language=[Windows.Markup.XmlLanguage]::GetLanguage($Language.code)
}
function New-LanguageDialog($Owner) {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    [xml]$languageXaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="CartelleColorate" Width="440" Height="560" MinWidth="360" MinHeight="420" ResizeMode="CanResize" WindowStartupLocation="CenterScreen" FontFamily="Segoe UI Variable, Segoe UI" FontSize="14" Background="{DynamicResource Page}" Foreground="{DynamicResource Text}" UseLayoutRounding="True">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Foreground" Value="{DynamicResource OnAccent}"/><Setter Property="Background" Value="{DynamicResource Accent}"/><Setter Property="Height" Value="36"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="Surface" CornerRadius="12" Background="{TemplateBinding Background}" Padding="14,8"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Opacity" Value="0.85"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Surface" Property="BorderBrush" Value="{DynamicResource Text}"/><Setter TargetName="Surface" Property="BorderThickness" Value="2"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
  <Style TargetType="ListBoxItem"><Setter Property="HorizontalContentAlignment" Value="Stretch"/><Setter Property="Padding" Value="12,7"/><Setter Property="Margin" Value="4,2"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem"><Border x:Name="Row" CornerRadius="12" Background="Transparent" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Row" Property="Background" Value="{DynamicResource Hover}"/></Trigger><Trigger Property="IsSelected" Value="True"><Setter TargetName="Row" Property="Background" Value="{DynamicResource Selected}"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Row" Property="BorderBrush" Value="{DynamicResource Accent}"/><Setter TargetName="Row" Property="BorderThickness" Value="1"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
 </Window.Resources>
 <Grid Margin="18,14"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <StackPanel Margin="0,0,0,14"><TextBlock Text="{DynamicResource L_chooseLanguage}" FontSize="21" FontWeight="SemiBold" TextWrapping="Wrap"/><TextBlock Text="Language" Foreground="{DynamicResource Secondary}" FontSize="12" Margin="0,4,0,0"/><TextBlock Text="{DynamicResource L_languageHelp}" Foreground="{DynamicResource Secondary}" TextWrapping="Wrap" Margin="0,10,0,0"/><Grid Margin="0,10,0,0"><TextBox x:Name="LanguageSearch" Height="34" Padding="8,5" Background="{DynamicResource Card}" Foreground="{DynamicResource Text}" BorderBrush="{DynamicResource Line}" AutomationProperties.Name="{DynamicResource L_searchLanguages}" ToolTip="{DynamicResource L_searchLanguages}"/><TextBlock Text="{DynamicResource L_searchLanguages}" Foreground="{DynamicResource Secondary}" Margin="9,0" VerticalAlignment="Center" IsHitTestVisible="False"><TextBlock.Style><Style TargetType="TextBlock"><Setter Property="Visibility" Value="Collapsed"/><Style.Triggers><DataTrigger Binding="{Binding Text, ElementName=LanguageSearch}" Value=""><Setter Property="Visibility" Value="Visible"/></DataTrigger></Style.Triggers></Style></TextBlock.Style></TextBlock></Grid></StackPanel>
  <Border Grid.Row="1" Background="{DynamicResource Card}" CornerRadius="18" BorderBrush="{DynamicResource Line}" BorderThickness="1"><ListBox x:Name="LanguageList" Background="Transparent" Foreground="{DynamicResource Text}" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled" AutomationProperties.Name="{DynamicResource L_language}" FlowDirection="LeftToRight"><ListBox.ItemTemplate><DataTemplate><StackPanel><TextBlock Text="{Binding nativeName}" FontSize="15"/><TextBlock Text="{Binding detail}" Foreground="{DynamicResource Secondary}" FontSize="11" Margin="0,2,0,0"/></StackPanel></DataTemplate></ListBox.ItemTemplate></ListBox></Border>
  <StackPanel Grid.Row="2" Margin="0,16,0,0"><TextBlock x:Name="LanguageError" Foreground="{DynamicResource Text}" TextWrapping="Wrap" Visibility="Collapsed" Margin="0,0,0,8"/><TextBlock x:Name="LanguageDraft" Text="{DynamicResource L_languageDraft}" Foreground="{DynamicResource Secondary}" TextWrapping="Wrap" Visibility="Collapsed" Margin="0,0,0,8"/><Grid Margin="0,0,0,8"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Button x:Name="ImportLanguage" Content="{DynamicResource L_importLanguage}" Foreground="{DynamicResource Text}" Background="{DynamicResource Card}" Margin="0,0,4,0"/><Button x:Name="ExportLanguage" Grid.Column="1" Content="{DynamicResource L_exportLanguageTemplate}" Foreground="{DynamicResource Text}" Background="{DynamicResource Card}" Margin="4,0,0,0"/></Grid><Button x:Name="LanguageContinue" IsDefault="True" Content="{DynamicResource L_continue}"/></StackPanel>
 </Grid>
</Window>
'@
    $classic=(Read-AppearancePreference) -eq 'Windows'
    if ($classic) { $languageXaml=[xml]$languageXaml.OuterXml.Replace('CornerRadius="12"','CornerRadius="5"').Replace('CornerRadius="18"','CornerRadius="8"') }
    $dialog=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($languageXaml))
    $colors=@{Page='#F1F5FA';Card='#C0FFFFFF';Text='#18212F';Secondary='#526174';Line='#300D2440';Hover='#DCFFFFFF';Selected='#350078EA';Accent='#006BD6';OnAccent='#FFFFFF'}
    $isDark=$false
    try { $isDark=(Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme) -eq 0 } catch { }
    if ($Theme -eq 'Dark') { $isDark=$true }; if ($Theme -eq 'Light') { $isDark=$false }
    if ($isDark) { $colors=@{Page='#202832';Card='#493F5066';Text='#F6F8FC';Secondary='#BBC7D8';Line='#38FFFFFF';Hover='#65556B85';Selected='#554D9EFF';Accent='#65B5FF';OnAccent='#071C31'} }
    if ($classic) { $colors=if ($isDark) { @{Page='#202020';Card='#2B2B2B';Text='#F5F5F5';Secondary='#ADADAD';Line='#414141';Hover='#383838';Selected='#344452';Accent='#60CDFF';OnAccent='#00304A'} } else { @{Page='#F3F3F3';Card='#FFFFFF';Text='#1A1A1A';Secondary='#666666';Line='#E4E4E4';Hover='#F0F0F0';Selected='#E8F0FB';Accent='#0067C0';OnAccent='#FFFFFF'} } }
    foreach ($key in $colors.Keys) { $dialog.Resources[$key]=[Windows.Media.BrushConverter]::new().ConvertFromString($colors[$key]) }
    Set-LanguageResources $dialog
    if ($Owner) { $dialog.Owner=$Owner; $dialog.WindowStartupLocation='CenterOwner'; $dialog.ShowInTaskbar=$false }
    $script:languageDialog=@{Window=$dialog;List=$dialog.FindName('LanguageList');Error=$dialog.FindName('LanguageError');Continue=$dialog.FindName('LanguageContinue');Search=$dialog.FindName('LanguageSearch');Draft=$dialog.FindName('LanguageDraft');Import=$dialog.FindName('ImportLanguage');Export=$dialog.FindName('ExportLanguage')}
    Update-LanguageChoices
    $script:languageDialog.Search.Add_TextChanged({ Update-LanguageChoices; $script:languageDialog.Continue.IsEnabled=$null -ne $script:languageDialog.List.SelectedItem })
    $script:languageDialog.List.SelectedItem=$script:activeLanguage; $script:languageDialog.Draft.Visibility=if ($script:activeLanguage.draft) { 'Visible' } else { 'Collapsed' }
    $script:languageDialog.List.Add_SelectionChanged({
        $selected=$script:languageDialog.List.SelectedItem
        $script:languageDialog.Continue.IsEnabled=$null -ne $selected; $script:languageDialog.Draft.Visibility=if ($selected -and $selected.draft) { 'Visible' } else { 'Collapsed' }
        if ($selected) { Set-LanguageResources $script:languageDialog.Window $selected; $script:languageDialog.Error.Visibility='Collapsed' }
    })
    $script:languageDialog.Continue.Add_Click({
        try {
            $selected=$script:languageDialog.List.SelectedItem
            if (!$selected) { return }
            Save-LanguagePreference $selected.code
            $script:languageDialog.Window.DialogResult=$true
        } catch { $script:languageDialog.Error.Text=T 'settingsError'; $script:languageDialog.Error.Visibility='Visible' }
    })
    $script:languageDialog.Import.Add_Click({
        $picker=[Microsoft.Win32.OpenFileDialog]::new(); $picker.Filter=T 'languagePackFilter'; $picker.Title=T 'importLanguage'
        if ($picker.ShowDialog($script:languageDialog.Window)) { try { $code=Import-LanguagePack $picker.FileName; $script:languageDialog.Search.Clear(); Update-LanguageChoices; $script:languageDialog.List.SelectedItem=$script:languageMap[$code]; $script:languageDialog.List.ScrollIntoView($script:languageMap[$code]); $script:languageDialog.Error.Text=T 'languagePackImported'; $script:languageDialog.Error.Visibility='Visible' } catch { $script:languageDialog.Error.Text=T 'languagePackInvalid'; $script:languageDialog.Error.Visibility='Visible' } }
    })
    $script:languageDialog.Export.Add_Click({
        $picker=[Microsoft.Win32.SaveFileDialog]::new(); $picker.Filter=T 'languagePackFilter'; $picker.DefaultExt='.cclang'; $picker.FileName='language-template.cclang'; $picker.Title=T 'exportLanguageTemplate'
        if ($picker.ShowDialog($script:languageDialog.Window)) { try { Export-LanguageTemplate $picker.FileName } catch { $script:languageDialog.Error.Text=T 'settingsError'; $script:languageDialog.Error.Visibility='Visible' } }
    })
    $area=[Windows.SystemParameters]::WorkArea; $dialog.MaxHeight=[Math]::Max(420,$area.Height-24); $dialog.Height=[Math]::Min($dialog.Height,$dialog.MaxHeight)
    $dialog.Add_Loaded({
        $script:languageDialog.List.ScrollIntoView($script:languageDialog.List.SelectedItem)
        [void]$script:languageDialog.List.Focus()
    })
    $dialog.Add_PreviewKeyDown({ param($sender,$e)
        if ($e.Key -eq [Windows.Input.Key]::Escape) { $script:languageDialog.Window.Close(); $e.Handled=$true }
    })
    return $dialog
}
function Show-LanguageDialog($Owner) {
    $dialog=New-LanguageDialog $Owner
    return $dialog.ShowDialog() -eq $true
}

function Read-LanguagePack([string]$Path) {
    $file=Get-Item -LiteralPath $Path -ErrorAction Stop; if ($file.PSIsContainer -or $file.Length -gt 1048576) { throw 'Invalid language package size' }
    $text=[Text.UTF8Encoding]::new($false,$true).GetString([IO.File]::ReadAllBytes($file.FullName)).TrimStart([char]0xFEFF); $pack=$text | ConvertFrom-Json
    if ($pack -isnot [pscustomobject] -or $pack.schemaVersion -ne 1 -or $pack.code -isnot [string] -or $pack.code.Length -gt 63 -or $pack.code -notmatch '^[a-zA-Z]{2,8}(-[a-zA-Z0-9]{2,8})*$' -or $pack.code -ieq 'en' -or $pack.rtl -isnot [bool] -or $pack.strings -isnot [pscustomobject]) { throw 'Invalid language package metadata' }
    foreach ($key in @('nativeName','englishName')) { if ($pack.$key -isnot [string] -or [string]::IsNullOrWhiteSpace($pack.$key) -or $pack.$key.Length -gt 80 -or $pack.$key -match '[\x00-\x1F]') { throw 'Invalid language name' } }
    $english=$script:builtInLanguages | Where-Object code -eq 'en'; $strings=[pscustomobject]@{}
    foreach ($property in $pack.strings.PSObject.Properties) {
        $base=$english.strings.PSObject.Properties[$property.Name]; $value=$property.Value
        if (!$base -or $value -isnot [string] -or $value.Length -gt 4096 -or $value -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') { throw 'Invalid translation key or value' }; if ([string]::IsNullOrWhiteSpace($value)) { continue }
        $expected=@([regex]::Matches($base.Value,'\{\d+\}')|ForEach-Object Value|Sort-Object) -join ','; $actual=@([regex]::Matches($value,'\{\d+\}')|ForEach-Object Value|Sort-Object) -join ','
        if ($expected -cne $actual) { throw 'Translation placeholders differ' }; [void][string]::Format([Globalization.CultureInfo]::InvariantCulture,$value,[object[]]@('0','1','2','3','4','5','6','7','8','9'))
        $strings | Add-Member -NotePropertyName $property.Name -NotePropertyValue $value
    }; if (!@($strings.PSObject.Properties).Count) { throw 'Empty language package' }
    [pscustomobject]@{schemaVersion=1;code=$pack.code.ToLowerInvariant();nativeName=$pack.nativeName.Trim();englishName=$pack.englishName.Trim();rtl=$pack.rtl;draft=$true;strings=$strings}
}
function Load-LanguagePacks([string]$DataRoot) {
    $script:languagePackDirectory=Join-Path $DataRoot 'languages'; $script:languageMap=@{}; foreach ($language in $script:builtInLanguages) { $script:languageMap[$language.code]=$language }
    if ([IO.Directory]::Exists($script:languagePackDirectory)) { foreach ($file in Get-ChildItem -LiteralPath $script:languagePackDirectory -Filter '*.json' -File) { try { $pack=Read-LanguagePack $file.FullName; if ($file.BaseName -cne ('lang-'+$pack.code)) { continue }; $script:languageMap[$pack.code]=$pack } catch { } } }
    $script:languageCatalog.languages=@($script:languageMap.Values | Sort-Object englishName)
}
function Import-LanguagePack([string]$Path) {
    $pack=Read-LanguagePack $Path; [IO.Directory]::CreateDirectory($script:languagePackDirectory)|Out-Null; $target=Join-Path $script:languagePackDirectory ('lang-'+$pack.code+'.json'); $temporary=$target+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
    try { [IO.File]::WriteAllText($temporary,($pack|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($true)); if ([IO.File]::Exists($target)) { [IO.File]::Replace($temporary,$target,[NullString]::Value) } else { [IO.File]::Move($temporary,$target) } } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
    $script:languageMap[$pack.code]=$pack; $script:languageCatalog.languages=@($script:languageMap.Values|Sort-Object englishName); return $pack.code
}
function Export-LanguageTemplate([string]$Path) {
    $english=$script:builtInLanguages | Where-Object code -eq 'en'; $template=[pscustomobject]@{schemaVersion=1;code='xx';nativeName='Your language';englishName='Your language';rtl=$false;draft=$true;strings=$english.strings}
    [IO.File]::WriteAllText($Path,($template|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($true))
}
function Test-LanguageSearch($Entry,[string]$Query) {
    if ([string]::IsNullOrWhiteSpace($Query)) { return $true }; $display=''; try { $display=[Globalization.CultureInfo]::GetCultureInfo($Entry.code).DisplayName } catch {}
    $haystack=$Entry.nativeName+' '+$Entry.englishName+' '+$Entry.code+' '+$display; return [Globalization.CultureInfo]::CurrentCulture.CompareInfo.IndexOf($haystack,$Query.Trim(),([Globalization.CompareOptions]::IgnoreCase -bor [Globalization.CompareOptions]::IgnoreNonSpace)) -ge 0
}
function Update-LanguageChoices {
    foreach ($entry in $script:languageCatalog.languages) { $entry|Add-Member -NotePropertyName detail -NotePropertyValue ($entry.englishName+$(if ($entry.draft) { ' · '+(T 'languageDraftLabel') } else { '' })) -Force }
    $selected=$script:languageDialog.List.SelectedItem; $matches=@($script:languageCatalog.languages | Where-Object { Test-LanguageSearch $_ $script:languageDialog.Search.Text }); $script:languageDialog.List.ItemsSource=$matches; if ($selected -and @($matches.code) -contains $selected.code) { $script:languageDialog.List.SelectedItem=$selected } elseif ($matches.Count) { $script:languageDialog.List.SelectedItem=$matches[0] }
}
