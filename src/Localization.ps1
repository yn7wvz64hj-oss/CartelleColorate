# Language resources are loaded once, including in the persistent color worker.
$script:languageCatalog=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Languages.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$script:languageMap=@{}
foreach ($entry in $script:languageCatalog.languages) { $script:languageMap[$entry.code]=$entry }

function Resolve-LanguageCode([string]$CultureName) {
    $base=($CultureName -split '[-_]')[0].ToLowerInvariant()
    if ($script:languageMap.ContainsKey($base)) { return $base }
    return 'en'
}
function Initialize-Language([string]$DataRoot,[string]$Override,[string]$CultureName=[Globalization.CultureInfo]::CurrentUICulture.Name) {
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
    foreach ($property in $Language.strings.PSObject.Properties) { $Window.Resources['L_'+$property.Name]=[string]$property.Value }
    $Window.FlowDirection=if ($Language.rtl) { 'RightToLeft' } else { 'LeftToRight' }
    $Window.Language=[Windows.Markup.XmlLanguage]::GetLanguage($Language.code)
}
function New-LanguageDialog($Owner) {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    [xml]$languageXaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="CartelleColorate" Width="416" Height="480" ResizeMode="NoResize" WindowStartupLocation="CenterScreen" FontFamily="Segoe UI Variable, Segoe UI" FontSize="14" Background="{DynamicResource Page}" Foreground="{DynamicResource Text}" UseLayoutRounding="True">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Foreground" Value="{DynamicResource OnAccent}"/><Setter Property="Background" Value="{DynamicResource Accent}"/><Setter Property="Height" Value="36"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="Surface" CornerRadius="12" Background="{TemplateBinding Background}" Padding="14,8"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Opacity" Value="0.85"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Surface" Property="BorderBrush" Value="{DynamicResource Text}"/><Setter TargetName="Surface" Property="BorderThickness" Value="2"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
  <Style TargetType="ListBoxItem"><Setter Property="HorizontalContentAlignment" Value="Stretch"/><Setter Property="Padding" Value="12,7"/><Setter Property="Margin" Value="4,2"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem"><Border x:Name="Row" CornerRadius="12" Background="Transparent" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Row" Property="Background" Value="{DynamicResource Hover}"/></Trigger><Trigger Property="IsSelected" Value="True"><Setter TargetName="Row" Property="Background" Value="{DynamicResource Selected}"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Row" Property="BorderBrush" Value="{DynamicResource Accent}"/><Setter TargetName="Row" Property="BorderThickness" Value="1"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
 </Window.Resources>
 <Grid Margin="18,14"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <StackPanel Margin="0,0,0,14"><TextBlock Text="{DynamicResource L_chooseLanguage}" FontSize="21" FontWeight="SemiBold" TextWrapping="Wrap"/><TextBlock Text="Language" Foreground="{DynamicResource Secondary}" FontSize="12" Margin="0,4,0,0"/><TextBlock Text="{DynamicResource L_languageHelp}" Foreground="{DynamicResource Secondary}" TextWrapping="Wrap" Margin="0,10,0,0"/></StackPanel>
  <Border Grid.Row="1" Background="{DynamicResource Card}" CornerRadius="18" BorderBrush="{DynamicResource Line}" BorderThickness="1"><ListBox x:Name="LanguageList" Background="Transparent" Foreground="{DynamicResource Text}" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled" AutomationProperties.Name="{DynamicResource L_language}" FlowDirection="LeftToRight"><ListBox.ItemTemplate><DataTemplate><StackPanel><TextBlock Text="{Binding nativeName}" FontSize="15"/><TextBlock Text="{Binding englishName}" Foreground="{DynamicResource Secondary}" FontSize="11" Margin="0,2,0,0"/></StackPanel></DataTemplate></ListBox.ItemTemplate></ListBox></Border>
  <StackPanel Grid.Row="2" Margin="0,16,0,0"><TextBlock x:Name="LanguageError" Foreground="{DynamicResource Text}" TextWrapping="Wrap" Visibility="Collapsed" Margin="0,0,0,8"/><Button x:Name="LanguageContinue" IsDefault="True" Content="{DynamicResource L_continue}"/></StackPanel>
 </Grid>
</Window>
'@
    $classic=(Read-AppearancePreference) -eq 'Windows'
    if ($classic) { $languageXaml=[xml]$languageXaml.OuterXml.Replace('CornerRadius="12"','CornerRadius="5"').Replace('CornerRadius="18"','CornerRadius="8"') }
    $dialog=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($languageXaml))
    $colors=@{Page='#F1F5FA';Card='#C0FFFFFF';Text='#18212F';Secondary='#526174';Line='#300D2440';Hover='#DCFFFFFF';Selected='#350078EA';Accent='#007AFF';OnAccent='#FFFFFF'}
    $isDark=$false
    try { $isDark=(Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme) -eq 0 } catch { }
    if ($Theme -eq 'Dark') { $isDark=$true }; if ($Theme -eq 'Light') { $isDark=$false }
    if ($isDark) { $colors=@{Page='#202832';Card='#493F5066';Text='#F6F8FC';Secondary='#BBC7D8';Line='#38FFFFFF';Hover='#65556B85';Selected='#554D9EFF';Accent='#65B5FF';OnAccent='#071C31'} }
    if ($classic) { $colors=if ($isDark) { @{Page='#202020';Card='#2B2B2B';Text='#F5F5F5';Secondary='#ADADAD';Line='#414141';Hover='#383838';Selected='#344452';Accent='#60CDFF';OnAccent='#00304A'} } else { @{Page='#F3F3F3';Card='#FFFFFF';Text='#1A1A1A';Secondary='#666666';Line='#E4E4E4';Hover='#F0F0F0';Selected='#E8F0FB';Accent='#0067C0';OnAccent='#FFFFFF'} } }
    foreach ($key in $colors.Keys) { $dialog.Resources[$key]=[Windows.Media.BrushConverter]::new().ConvertFromString($colors[$key]) }
    Set-LanguageResources $dialog
    if ($Owner) { $dialog.Owner=$Owner; $dialog.WindowStartupLocation='CenterOwner'; $dialog.ShowInTaskbar=$false }
    $script:languageDialog=@{Window=$dialog;List=$dialog.FindName('LanguageList');Error=$dialog.FindName('LanguageError');Continue=$dialog.FindName('LanguageContinue')}
    $script:languageDialog.List.ItemsSource=@($script:languageCatalog.languages)
    $script:languageDialog.List.SelectedItem=$script:activeLanguage
    $script:languageDialog.List.Add_SelectionChanged({
        $selected=$script:languageDialog.List.SelectedItem
        if ($selected) { Set-LanguageResources $script:languageDialog.Window $selected; $script:languageDialog.Error.Visibility='Collapsed' }
    })
    $script:languageDialog.Continue.Add_Click({
        try {
            $selected=$script:languageDialog.List.SelectedItem
            if (!$selected) { return }
            Save-LanguagePreference $selected.code
            $script:languageDialog.Window.DialogResult=$true
        } catch { $script:languageDialog.Error.Text=$selected.strings.settingsError; $script:languageDialog.Error.Visibility='Visible' }
    })
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
