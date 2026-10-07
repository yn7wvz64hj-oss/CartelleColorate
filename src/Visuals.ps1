function Read-BackgroundChoices {
    $path=Join-Path $root 'sfondi.json'; $choices=@{}
    if ([IO.File]::Exists($path)) { $data=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json; foreach ($entry in $data) { if ($entry.Style -in @('Windows','MacOS') -and $entry.Mode -in @('Default','Color','Image') -and $entry.Hex -match '^#[0-9A-Fa-f]{6}$') { $choices[$entry.Style]=$entry } } }
    return $choices
}
function Save-BackgroundChoice([string]$Style,[string]$Mode,[string]$Hex,[string]$Image,[int]$Position=0,[double]$Zoom=1,[int]$Veil=70) {
    if ($Style -notin @('Windows','MacOS') -or $Mode -notin @('Default','Color','Image') -or $Hex -notmatch '^#[0-9A-Fa-f]{6}$') { throw (T 'backgroundError') }
    Assert-BackgroundLayout $Position $Zoom $Veil
    $asset=''; $source=$null; $bitmap=$null; $graphics=$null
    try {
        if ($Mode -eq 'Image') {
            $source=[Drawing.Image]::FromFile($Image); if ([long]$source.Width*$source.Height -gt 67108864) { throw (T 'backgroundError') }
            $scale=[Math]::Min(1,1920.0/[Math]::Max($source.Width,$source.Height)); $bitmap=[Drawing.Bitmap]::new([Math]::Max(1,[int]($source.Width*$scale)),[Math]::Max(1,[int]($source.Height*$scale)))
            $graphics=[Drawing.Graphics]::FromImage($bitmap); $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic; $graphics.DrawImage($source,0,0,$bitmap.Width,$bitmap.Height)
            $asset=Join-Path $root ('background-'+[Guid]::NewGuid().ToString('N')+'.png'); $bitmap.Save($asset,[Drawing.Imaging.ImageFormat]::Png)
        }
        $choices=Read-BackgroundChoices; $choices[$Style]=[pscustomobject]@{Style=$Style;Mode=$Mode;Hex=$Hex.ToUpperInvariant();Image=$asset;Position=$Position;Zoom=$Zoom;Veil=$Veil}
        Write-AdvancedJson (Join-Path $root 'sfondi.json') @($choices.Values)
    } catch { if ($asset -and [IO.File]::Exists($asset)) { [IO.File]::Delete($asset) }; throw }
    finally { if ($graphics) { $graphics.Dispose() }; if ($bitmap) { $bitmap.Dispose() }; if ($source) { $source.Dispose() } }
}
function Get-PortableBackgrounds([hashtable]$Assets) {
    foreach ($entry in (Read-BackgroundChoices).Values) {
        $asset=''; if ($entry.Mode -eq 'Image') { if (![IO.File]::Exists($entry.Image)) { continue }; $bytes=[IO.File]::ReadAllBytes($entry.Image); Assert-BackupPng $bytes; $asset=Get-DataHash $bytes; $Assets[$asset]=$bytes }
        [pscustomobject]@{Style=$entry.Style;Mode=$entry.Mode;Hex=$entry.Hex;Asset=$asset;Position=(Get-BackgroundValue $entry Position 0);Zoom=(Get-BackgroundValue $entry Zoom 1);Veil=(Get-BackgroundValue $entry Veil 70)}
    }
}
function Read-PortableBackgrounds($Entries,$Archive,[hashtable]$Assets) {
    $seen=@{}
    foreach ($entry in $Entries) {
        if ($entry.Style -notin @('Windows','MacOS') -or $seen.ContainsKey($entry.Style) -or $entry.Mode -notin @('Default','Color','Image') -or $entry.Hex -notmatch '^#[0-9A-Fa-f]{6}$') { throw (T 'backupInvalid') }; $seen[$entry.Style]=$true
        if ($entry.Mode -eq 'Image') {
            if ($entry.Asset -notmatch '^[a-f0-9]{64}$') { throw (T 'backupInvalid') }
            if (!$Assets.ContainsKey($entry.Asset)) {
                $file=$Archive.GetEntry('images/'+$entry.Asset+'.png'); if (!$file) { throw (T 'backupInvalid') }; $stream=$file.Open(); $memory=[IO.MemoryStream]::new()
                try { $stream.CopyTo($memory); $bytes=$memory.ToArray() } finally { $memory.Dispose(); $stream.Dispose() }
                if ((Get-DataHash $bytes) -ne $entry.Asset) { throw (T 'backupInvalid') }; Assert-BackupPng $bytes; $Assets[$entry.Asset]=$bytes
            }
        } elseif ($entry.Asset) { throw (T 'backupInvalid') }
        Assert-BackgroundLayout (Get-BackgroundValue $entry Position 0) (Get-BackgroundValue $entry Zoom 1) (Get-BackgroundValue $entry Veil 70)
        $entry
    }
}
function Apply-PersonalBackground {
    if (!$ui.PersonalBackground) { return }
    $ui.PersonalBackground.Background=$null; $ui.BackgroundShade.Background=$null; $window.Resources['BackdropText']=$window.Resources['Text']
    if ([Windows.SystemParameters]::HighContrast) { return }; $entry=if ($script:backgroundDraft -and $script:backgroundDraft.Style -eq $script:appearance) { $script:backgroundDraft } else { (Read-BackgroundChoices)[$script:appearance] }; if (!$entry -or $entry.Mode -eq 'Default') { return }
    try {
        if ($entry.Mode -eq 'Color') {
            $ui.PersonalBackground.Background=Brush $entry.Hex; $c=[Drawing.ColorTranslator]::FromHtml($entry.Hex); $luma=0
            $weights=@(0.2126,0.7152,0.0722); $channels=@($c.R,$c.G,$c.B); for ($i=0;$i -lt 3;$i++) { $value=$channels[$i]/255.0; $linear=if ($value -le 0.04045) { $value/12.92 } else { [Math]::Pow(($value+0.055)/1.055,2.4) }; $luma+=$linear*$weights[$i] }
            $window.Resources['BackdropText']=Brush $(if ($luma -gt 0.179) { '#000000' } else { '#FFFFFF' })
        } elseif ([IO.File]::Exists($entry.Image)) {
            $ui.PersonalBackground.Background=New-BackgroundBrush $entry
            $safeVeil=if ($script:dark) { 80 } else { 90 }; $alpha=[byte][Math]::Round(255*[Math]::Max($safeVeil,(Get-BackgroundValue $entry Veil 70))/100.0); $color=if ($script:dark) { [Windows.Media.Color]::FromArgb($alpha,0,0,0) } else { [Windows.Media.Color]::FromArgb($alpha,255,255,255) }; $shade=[Windows.Media.SolidColorBrush]::new($color); $shade.Freeze(); $ui.BackgroundShade.Background=$shade
        }
        if ($script:appearance -eq 'MacOS') { $brush=$window.Resources['Card'].Clone(); foreach ($stop in $brush.GradientStops) { $color=$stop.Color; $minimum=if ($entry.Mode -eq 'Color') { 248 } else { 210 }; $color.A=[byte][Math]::Max($minimum,$color.A); $stop.Color=$color }; $brush.Freeze(); $window.Resources['Card']=$brush; $inputBrush=$window.Resources['Input'].Clone(); $inputColor=$inputBrush.Color; $inputColor.A=255; $inputBrush.Color=$inputColor; $inputBrush.Freeze(); $window.Resources['Input']=$inputBrush }
    } catch { $ui.PersonalBackground.Background=$null; $ui.BackgroundShade.Background=$null; $window.Resources['BackdropText']=$window.Resources['Text'] }
}
function Initialize-ModernControls {
    [xml]$markup=@'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
 <Style TargetType="CheckBox"><Setter Property="FontFamily" Value="Segoe UI Variable, Segoe UI"/><Setter Property="FontSize" Value="13"/><Setter Property="Foreground" Value="{DynamicResource Text}"/><Setter Property="ContentTemplate"><Setter.Value><DataTemplate><TextBlock Text="{Binding}" TextWrapping="Wrap" Foreground="{DynamicResource Text}"/></DataTemplate></Setter.Value></Setter></Style>
 <Style TargetType="Slider"><Setter Property="MinHeight" Value="22"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Slider"><Grid><Border Height="3" VerticalAlignment="Center" CornerRadius="2" Background="{DynamicResource Accent}" Opacity="0.35"/><Track x:Name="PART_Track" Minimum="{TemplateBinding Minimum}" Maximum="{TemplateBinding Maximum}" Value="{TemplateBinding Value}"><Track.DecreaseRepeatButton><RepeatButton Command="Slider.DecreaseLarge" Opacity="0"/></Track.DecreaseRepeatButton><Track.IncreaseRepeatButton><RepeatButton Command="Slider.IncreaseLarge" Opacity="0"/></Track.IncreaseRepeatButton><Track.Thumb><Thumb Width="14" Height="14"><Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="{DynamicResource Input}" BorderBrush="{DynamicResource Accent}" BorderThickness="2" CornerRadius="7"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb></Track></Grid></ControlTemplate></Setter.Value></Setter></Style>
 <Style x:Key="FluentContextMenu" TargetType="ContextMenu">
  <Setter Property="FontFamily" Value="Segoe UI Variable, Segoe UI"/><Setter Property="FontSize" Value="13"/><Setter Property="Foreground" Value="{DynamicResource MenuText}"/><Setter Property="Background" Value="{DynamicResource MenuSurface}"/><Setter Property="BorderBrush" Value="{DynamicResource MenuLine}"/><Setter Property="OverridesDefaultStyle" Value="True"/>
  <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ContextMenu"><Border Background="Transparent" Padding="10"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="8" Padding="5" Effect="{DynamicResource MenuShadow}"><ScrollViewer MaxHeight="480" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" CanContentScroll="True"><ItemsPresenter KeyboardNavigation.DirectionalNavigation="Cycle"/></ScrollViewer></Border></Border></ControlTemplate></Setter.Value></Setter>
 </Style>
 <Style x:Key="FluentMenuItem" TargetType="MenuItem">
  <Setter Property="FontFamily" Value="Segoe UI Variable, Segoe UI"/><Setter Property="FontSize" Value="13"/><Setter Property="FontWeight" Value="Normal"/><Setter Property="Foreground" Value="{DynamicResource MenuText}"/><Setter Property="Margin" Value="1"/><Setter Property="Padding" Value="10,7"/><Setter Property="MinHeight" Value="34"/>
  <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="MenuItem"><Grid>
   <Border x:Name="Row" Background="Transparent" CornerRadius="5" Padding="{TemplateBinding Padding}"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="24"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="12"/></Grid.ColumnDefinitions>
    <ContentPresenter x:Name="Icon" ContentSource="Icon" Width="16" Height="16" VerticalAlignment="Center" HorizontalAlignment="Left"/>
    <Path x:Name="Check" Data="M1,6 L5,10 L12,2" Stroke="{DynamicResource MenuText}" StrokeThickness="1.6" Width="14" Height="14" VerticalAlignment="Center" Visibility="Collapsed"/>
    <ContentPresenter Grid.Column="1" ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center" Margin="0,0,12,0"/>
    <TextBlock Grid.Column="2" Text="{TemplateBinding InputGestureText}" Foreground="{DynamicResource Secondary}" FontSize="11" VerticalAlignment="Center" Margin="8,0,8,0"/>
    <Path x:Name="Arrow" Grid.Column="3" Data="M1,1 L5,5 L1,9" Stroke="{DynamicResource MenuText}" StrokeThickness="1.2" Width="6" Height="10" VerticalAlignment="Center" Visibility="Collapsed"/>
   </Grid></Border>
   <Popup x:Name="PART_Popup" Placement="Right" IsOpen="{Binding IsSubmenuOpen,RelativeSource={RelativeSource TemplatedParent}}" AllowsTransparency="True" Focusable="False" PopupAnimation="Fade"><Border Padding="10" Background="Transparent"><Border Background="{DynamicResource MenuSurface}" BorderBrush="{DynamicResource MenuLine}" BorderThickness="1" CornerRadius="8" Padding="5" Effect="{DynamicResource MenuShadow}"><ScrollViewer MaxHeight="420" VerticalScrollBarVisibility="Auto" CanContentScroll="True"><ItemsPresenter KeyboardNavigation.DirectionalNavigation="Cycle"/></ScrollViewer></Border></Border></Popup>
  </Grid><ControlTemplate.Triggers><Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Row" Property="Background" Value="{DynamicResource MenuHover}"/></Trigger><Trigger Property="HasItems" Value="True"><Setter TargetName="Arrow" Property="Visibility" Value="Visible"/></Trigger><Trigger Property="IsChecked" Value="True"><Setter TargetName="Check" Property="Visibility" Value="Visible"/><Setter TargetName="Icon" Property="Visibility" Value="Collapsed"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
 </Style>
 <Style TargetType="MenuItem" BasedOn="{StaticResource FluentMenuItem}"/>
 <Style TargetType="Separator"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Separator"><Border Height="1" Background="{DynamicResource MenuLine}" Margin="10,5"/></ControlTemplate></Setter.Value></Setter></Style>
 <Style TargetType="ComboBoxItem"><Setter Property="Foreground" Value="{DynamicResource MenuText}"/><Setter Property="FontFamily" Value="Segoe UI Variable, Segoe UI"/><Setter Property="FontSize" Value="13"/><Setter Property="Padding" Value="10,7"/><Setter Property="Margin" Value="1"/><Setter Property="HorizontalContentAlignment" Value="Stretch"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBoxItem"><Border x:Name="Row" Background="Transparent" CornerRadius="5" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border><ControlTemplate.Triggers><Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Row" Property="Background" Value="{DynamicResource MenuHover}"/></Trigger><Trigger Property="IsSelected" Value="True"><Setter TargetName="Row" Property="Background" Value="{DynamicResource MenuHover}"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
 <Style TargetType="ComboBox"><Setter Property="FontFamily" Value="Segoe UI Variable, Segoe UI"/><Setter Property="FontSize" Value="13"/><Setter Property="Foreground" Value="{DynamicResource Text}"/><Setter Property="MinHeight" Value="34"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBox"><Grid>
  <Border x:Name="Frame" Background="{DynamicResource Input}" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="6"/>
  <ContentPresenter Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}" Margin="10,6,30,6" VerticalAlignment="Center" IsHitTestVisible="False"/>
  <Path Data="M1,1 L5,5 L9,1" Stroke="{DynamicResource Text}" StrokeThickness="1.2" Width="10" Height="6" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,10,0" IsHitTestVisible="False"/>
  <ToggleButton Focusable="False" IsChecked="{Binding IsDropDownOpen,RelativeSource={RelativeSource TemplatedParent},Mode=TwoWay}" Background="Transparent"><ToggleButton.Template><ControlTemplate TargetType="ToggleButton"><Border Background="Transparent"/></ControlTemplate></ToggleButton.Template></ToggleButton>
  <Popup x:Name="PART_Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="Fade"><Border Background="Transparent" Padding="6"><Border MinWidth="{Binding ActualWidth,RelativeSource={RelativeSource TemplatedParent}}" Background="{DynamicResource MenuSurface}" BorderBrush="{DynamicResource MenuLine}" BorderThickness="1" CornerRadius="8" Padding="4" Effect="{DynamicResource MenuShadow}"><ScrollViewer MaxHeight="300" VerticalScrollBarVisibility="Auto" CanContentScroll="True"><ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained"/></ScrollViewer></Border></Border></Popup>
 </Grid><ControlTemplate.Triggers><Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter TargetName="Frame" Property="BorderBrush" Value="{DynamicResource Accent}"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
</ResourceDictionary>
'@
    if (![Windows.SystemParameters]::ClientAreaAnimation) { $markup.InnerXml=$markup.InnerXml.Replace('PopupAnimation="Fade"','PopupAnimation="None"') }; $dictionary=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($markup)); $window.Resources.MergedDictionaries.Add($dictionary)
}
function Update-ModernMenuResources {
    $window.Resources['MenuSurface']=Brush $(if ($script:dark) { '#FF292929' } else { '#FFF9F9F9' }); $window.Resources['MenuText']=Brush $(if ($script:dark) { '#FFF5F5F5' } else { '#FF202020' }); $window.Resources['MenuLine']=Brush $(if ($script:dark) { '#FF424242' } else { '#FFE3E3E3' }); $window.Resources['MenuHover']=Brush $(if ($script:dark) { '#FF3A3A3A' } else { '#FFEDEDED' })
    $shadow=[Windows.Media.Effects.DropShadowEffect]::new(); $shadow.ShadowDepth=3; $shadow.BlurRadius=14; $shadow.Opacity=0.18; $shadow.Freeze(); $window.Resources['MenuShadow']=$shadow
}
function New-ModernMenu($Target) {
    $menu=[Windows.Controls.ContextMenu]::new(); $menu.Resources.MergedDictionaries.Add($window.Resources); $menu.Style=$window.FindResource('FluentContextMenu'); $menu.ItemContainerStyle=$window.FindResource('FluentMenuItem'); $menu.FlowDirection=$window.FlowDirection; $menu.PlacementTarget=$Target; $menu.Placement='Bottom'; return $menu
}
function Sync-UpdateButton {
    $visible=$false; if ($script:availableVersion) { try { $visible=Test-NewProductVersion $script:availableVersion $script:productVersion } catch {} }
    if (!$ui.UpdateAvailable) { return }
    $ui.UpdateAvailable.Visibility=if ($visible) { 'Visible' } else { 'Collapsed' }; $ui.UpdateAvailable.ToolTip=if ($visible) { (T 'updateAvailable')+' '+$script:availableVersion } else { T 'updates' }
}
function Initialize-VisualInterface {
    Initialize-ModernControls; Update-ModernMenuResources; $ui.UpdateAvailable.Add_Click({ Show-UpdateDialog }); Sync-UpdateButton
}
function Update-BackgroundColor([string]$Hex) {
    if ($Hex -notmatch '^#[0-9A-Fa-f]{6}$' -or $script:backgroundDialog.Syncing) { return }
    $ctx=$script:backgroundDialog; $ctx.Syncing=$true
    try {
        $color=[Drawing.ColorTranslator]::FromHtml($Hex); $maximum=[Math]::Max($color.R,[Math]::Max($color.G,$color.B)); $minimum=[Math]::Min($color.R,[Math]::Min($color.G,$color.B))
        $ctx.Saturation=if ($maximum) { ($maximum-$minimum)/[double]$maximum } else { 0 }; $ctx.Brightness=$maximum/255.0; $ctx.Hue.Value=$color.GetHue(); $ctx.HueBase.Background=Brush (Get-HsvHex $ctx.Hue.Value 1 1); if ($ctx.Mode.SelectedIndex -eq 1) { $ctx.Preview.Background=Brush $Hex }
        [Windows.Controls.Canvas]::SetLeft($ctx.Pointer,$ctx.Saturation*$ctx.Plane.ActualWidth-6); [Windows.Controls.Canvas]::SetTop($ctx.Pointer,(1-$ctx.Brightness)*$ctx.Plane.ActualHeight-6)
    } finally { $ctx.Syncing=$false }; Request-BackgroundPreview
}
function Set-BackgroundPoint($Point) {
    $ctx=$script:backgroundDialog; $ctx.Saturation=[Math]::Max(0,[Math]::Min(1,$Point.X/[Math]::Max(1,$ctx.Plane.ActualWidth))); $ctx.Brightness=1-[Math]::Max(0,[Math]::Min(1,$Point.Y/[Math]::Max(1,$ctx.Plane.ActualHeight)))
    $ctx.Hex.Text=Get-HsvHex $ctx.Hue.Value $ctx.Saturation $ctx.Brightness
}
function Show-BackgroundDialog {
    $dialog=New-ProductWindow (T 'background') 400 530; $dialog.ResizeMode='CanResizeWithGrip'
    [xml]$markup=@'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions><ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel Margin="18,14,18,6">
 <TextBlock x:Name="Scope" TextWrapping="Wrap" Foreground="{DynamicResource Secondary}" Margin="0,0,0,8"/>
 <ComboBox x:Name="Mode" Margin="0,0,0,12"/>
 <Border x:Name="Preview" Height="60" CornerRadius="10" BorderBrush="{DynamicResource Line}" BorderThickness="1" Margin="0,0,0,12"/>
 <StackPanel x:Name="ColorPanel"><Grid Height="76" ClipToBounds="True" FlowDirection="LeftToRight">
  <Border x:Name="HueBase" Background="Red" CornerRadius="6"/>
  <Border CornerRadius="6"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="White" Offset="0"/><GradientStop Color="#00FFFFFF" Offset="1"/></LinearGradientBrush></Border.Background></Border>
  <Border CornerRadius="6"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#00000000" Offset="0"/><GradientStop Color="Black" Offset="1"/></LinearGradientBrush></Border.Background></Border>
  <Canvas x:Name="Plane" Background="Transparent" Cursor="None"><Ellipse x:Name="Pointer" Width="12" Height="12" Stroke="White" StrokeThickness="2" IsHitTestVisible="False"/></Canvas>
 </Grid><Grid Height="22" Margin="0,8,0,8" FlowDirection="LeftToRight"><Border Height="10" CornerRadius="5" VerticalAlignment="Center"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="Red" Offset="0"/><GradientStop Color="Yellow" Offset="0.167"/><GradientStop Color="Lime" Offset="0.333"/><GradientStop Color="Cyan" Offset="0.5"/><GradientStop Color="Blue" Offset="0.667"/><GradientStop Color="Magenta" Offset="0.833"/><GradientStop Color="Red" Offset="1"/></LinearGradientBrush></Border.Background></Border><Slider x:Name="Hue" Minimum="0" Maximum="359.99" Background="Transparent"><Slider.Template><ControlTemplate TargetType="Slider"><Track x:Name="PART_Track" Minimum="{TemplateBinding Minimum}" Maximum="{TemplateBinding Maximum}" Value="{TemplateBinding Value}"><Track.DecreaseRepeatButton><RepeatButton Command="Slider.DecreaseLarge" Opacity="0"/></Track.DecreaseRepeatButton><Track.IncreaseRepeatButton><RepeatButton Command="Slider.IncreaseLarge" Opacity="0"/></Track.IncreaseRepeatButton><Track.Thumb><Thumb Width="18" Height="22"><Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="White" BorderBrush="#66000000" BorderThickness="1" CornerRadius="{DynamicResource ControlRadius}"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb></Track></ControlTemplate></Slider.Template></Slider></Grid><TextBox x:Name="Hex" MaxLength="7" FlowDirection="LeftToRight" FontFamily="Consolas"/></StackPanel>
 <StackPanel x:Name="ImagePanel"><Button x:Name="Browse" Content="{DynamicResource L_backgroundImage}"/><TextBlock x:Name="ImageName" TextTrimming="CharacterEllipsis" Foreground="{DynamicResource Secondary}" Margin="0,6,0,0"/><TextBlock Text="{DynamicResource L_backgroundPosition}" Margin="0,12,0,6"/><ComboBox x:Name="Position"/><TextBlock Text="{DynamicResource L_backgroundZoom}" Margin="0,12,0,4"/><Slider x:Name="Zoom" Minimum="1" Maximum="3" SmallChange="0.05"/><TextBlock Text="{DynamicResource L_backgroundVeil}" Margin="0,12,0,4"/><Slider x:Name="Veil" Minimum="0" Maximum="100" SmallChange="1"/></StackPanel>
 </StackPanel></ScrollViewer><Grid Grid.Row="1" Margin="18,8,18,16"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Button x:Name="Cancel" Content="{DynamicResource L_cancel}" Margin="0,0,6,0"/><Button x:Name="Save" Grid.Column="1" Content="{DynamicResource L_saveChanges}"/></Grid>
</Grid>
'@
    $panel=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($markup)); $dialog.Content=$panel
    $ctx=@{Window=$dialog;Style=$script:appearance;Path='';Syncing=$false;Saturation=0;Brightness=1}
    foreach ($key in @('Scope','Mode','Preview','ColorPanel','ImagePanel','Browse','ImageName','Hue','HueBase','Plane','Pointer','Hex','Cancel','Save','Position','Zoom','Veil')) { $ctx[$key]=$panel.FindName($key) }; $script:backgroundDialog=$ctx
    Initialize-BackgroundPreview $ctx
    foreach ($key in @('positionCenter','positionTop','positionBottom','positionLeft','positionRight')) { $null=$ctx.Position.Items.Add((T $key)) }
    $ctx.Scope.Text=T 'backgroundFor' @($ui.AppearanceName.Text); foreach ($key in @('backgroundDefault','backgroundColor','backgroundImage')) { $null=$ctx.Mode.Items.Add((T $key)) }
    $entry=(Read-BackgroundChoices)[$script:appearance]; $ctx.Hex.Text=if ($entry) { $entry.Hex } else { '#4A90E2' }; $ctx.Path=if ($entry) { $entry.Image } else { '' }; $ctx.Position.SelectedIndex=Get-BackgroundValue $entry Position 0; $ctx.Zoom.Value=Get-BackgroundValue $entry Zoom 1; $ctx.Veil.Value=Get-BackgroundValue $entry Veil 70
    $ctx.Position.Add_SelectionChanged({ Request-BackgroundPreview }); $ctx.Zoom.Add_ValueChanged({ Request-BackgroundPreview }); $ctx.Veil.Add_ValueChanged({ Request-BackgroundPreview })
    $ctx.Mode.Add_SelectionChanged({ $ctx=$script:backgroundDialog; $mode=@('Default','Color','Image')[$ctx.Mode.SelectedIndex]; $ctx.ColorPanel.Visibility=if ($mode -eq 'Color') { 'Visible' } else { 'Collapsed' }; $ctx.ImagePanel.Visibility=if ($mode -eq 'Image') { 'Visible' } else { 'Collapsed' }; if ($mode -eq 'Default') { $ctx.Preview.Background=$window.Resources['Page'] } elseif ($mode -eq 'Color') { Update-BackgroundColor $ctx.Hex.Text } else { Set-BackgroundImagePreview $ctx.Path }; Request-BackgroundPreview })
    $ctx.Hex.Add_TextChanged({ param($sender,$e) Update-BackgroundColor $sender.Text })
    $ctx.Hue.Add_ValueChanged({ if (!$script:backgroundDialog.Syncing) { $script:backgroundDialog.HueBase.Background=Brush (Get-HsvHex $script:backgroundDialog.Hue.Value 1 1); $script:backgroundDialog.Hex.Text=Get-HsvHex $script:backgroundDialog.Hue.Value $script:backgroundDialog.Saturation $script:backgroundDialog.Brightness } })
    $ctx.Plane.Add_MouseLeftButtonDown({param($sender,$e) $null=$sender.CaptureMouse(); Set-BackgroundPoint ($e.GetPosition($sender)); $e.Handled=$true })
    $ctx.Plane.Add_MouseMove({param($sender,$e) if ($sender.IsMouseCaptured) { Set-BackgroundPoint ($e.GetPosition($sender)) } })
    $ctx.Plane.Add_MouseLeftButtonUp({param($sender,$e) if ($sender.IsMouseCaptured) { Set-BackgroundPoint ($e.GetPosition($sender)); $sender.ReleaseMouseCapture() } })
    $ctx.Plane.Add_SizeChanged({ Update-BackgroundColor $script:backgroundDialog.Hex.Text })
    $ctx.Browse.Add_Click({ $picker=[Microsoft.Win32.OpenFileDialog]::new(); $picker.Filter=T 'backgroundFilter'; $picker.Title=T 'backgroundImage'; if ($picker.ShowDialog($script:backgroundDialog.Window)) { try { Set-BackgroundImagePreview $picker.FileName;  $script:backgroundDialog.Path=$picker.FileName; Request-BackgroundPreview } catch { [Windows.MessageBox]::Show((T 'backgroundError'),(T 'background'))|Out-Null } } })
    $ctx.Cancel.Add_Click({ $script:backgroundDialog.Window.Close() })
    $ctx.Save.Add_Click({ try { $ctx=$script:backgroundDialog; Save-BackgroundChoice $ctx.Style (@('Default','Color','Image')[$ctx.Mode.SelectedIndex]) $ctx.Hex.Text $ctx.Path $ctx.Position.SelectedIndex $ctx.Zoom.Value ([int]$ctx.Veil.Value); $script:backgroundDraft=$null; Apply-Appearance $script:appearance; $ctx.Window.DialogResult=$true } catch { [Windows.MessageBox]::Show((T 'backgroundError'),(T 'background'))|Out-Null } })
    Update-BackgroundColor $ctx.Hex.Text; $ctx.Mode.SelectedIndex=if ($entry) { @('Default','Color','Image').IndexOf($entry.Mode) } else { 0 }
    if ($UITest -and $script:visualDialogTest) { $dialog.Add_ContentRendered({ $ctx=$script:backgroundDialog; $ctx.Mode.SelectedIndex=1; $ctx.Hex.Text='#123456'; $ctx.Save.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }) }
    if ($UITest -and $script:visualCancelTest) { $dialog.Add_ContentRendered({
        $ctx=$script:backgroundDialog; $ctx.Mode.SelectedIndex=1; $ctx.Hex.Text='#FEDCBA'; Apply-BackgroundDraft
        if ($ui.PersonalBackground.Background.Color.ToString() -ne '#FFFEDCBA') { throw 'Live background preview failed' }
        $ctx.Cancel.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    }) }
    Place-PreviewWindow $dialog
    try { [void](Show-AdaptiveDialog $dialog) } finally { $ctx.Timer.Stop(); $script:backgroundDraft=$null; $script:backgroundDialog=$null; Apply-Appearance $script:appearance }
}
function Set-BackgroundImagePreview([string]$Path) {
    $ctx=$script:backgroundDialog
    if (!$Path -or ![IO.File]::Exists($Path)) { $ctx.Preview.Background=$window.Resources['Page']; $ctx.ImageName.Text=''; return }
    $entry=[pscustomobject]@{Image=$Path;Position=$ctx.Position.SelectedIndex;Zoom=$ctx.Zoom.Value}; $ctx.Preview.Background=New-BackgroundBrush $entry; $ctx.ImageName.Text=[IO.Path]::GetFileName($Path)
}
function Test-VisualBackend {
    $savedRoot=$root; $savedPalette=$palettePath; $savedSettings=$script:languageSettingsPath; $savedLanguage=$script:activeLanguage.code
    $case=Join-Path $root ('visuals-'+[Guid]::NewGuid().ToString('N')); $origin=Join-Path $case 'origin'; $target=Join-Path $case 'target'; [IO.Directory]::CreateDirectory($origin)|Out-Null; [IO.Directory]::CreateDirectory($target)|Out-Null
    try {
        $script:root=$origin; $script:palettePath=Join-Path $root 'colori.json'; Initialize-Language $root 'it'
        $source=Join-Path $case 'wallpaper.png'; $bitmap=[Drawing.Bitmap]::new(80,50); $graphics=[Drawing.Graphics]::FromImage($bitmap); try { $graphics.Clear([Drawing.Color]::Orange); $bitmap.Save($source,[Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
        Save-BackgroundChoice 'Windows' 'Color' '#ABCDEF' ''; Save-BackgroundChoice 'MacOS' 'Image' '#123456' $source 4 2 35; [IO.File]::Move($source,$source+'.moved')
        $choices=Read-BackgroundChoices; if ($choices['Windows'].Hex -ne '#ABCDEF' -or ![IO.File]::Exists($choices['MacOS'].Image)) { throw 'Background depends on original image' }
        $before=Get-DataHash ([IO.File]::ReadAllBytes((Join-Path $root 'sfondi.json'))); $rejected=$false; try { Save-BackgroundChoice 'MacOS' 'Image' '#123456' 'missing-file' } catch { $rejected=$true }; if (!$rejected -or (Get-DataHash ([IO.File]::ReadAllBytes((Join-Path $root 'sfondi.json')))) -ne $before) { throw 'Invalid background changed preferences' }
        $backup=Join-Path $case 'visuals.ccbackup'; Export-LibraryBackup $backup
        $script:root=$target; $script:palettePath=Join-Path $root 'colori.json'; Initialize-Language $root 'it'; Import-LibraryBackup $backup
        $choices=Read-BackgroundChoices; if ($choices['Windows'].Mode -ne 'Color' -or $choices['Windows'].Hex -ne '#ABCDEF' -or $choices['MacOS'].Mode -ne 'Image' -or $choices['MacOS'].Position -ne 4 -or $choices['MacOS'].Zoom -ne 2 -or $choices['MacOS'].Veil -ne 35 -or ![IO.File]::Exists($choices['MacOS'].Image) -or !$choices['MacOS'].Image.StartsWith($root+'\')) { throw 'Portable background lost after import' }
    } finally { $script:root=$savedRoot; $script:palettePath=$savedPalette; Initialize-Language $savedRoot $savedLanguage; $script:languageSettingsPath=$savedSettings }
    Write-Output 'OK: sfondi separati per stile, immagini indipendenti, errore senza perdita di dati e backup portatile degli sfondi.'
}
function Test-VisualInterface([string]$Png) {
    $style=$script:appearance; $path=Join-Path $root 'sfondi.json'; $saved=$null; if ([IO.File]::Exists($path)) { $saved=[IO.File]::ReadAllBytes($path) }
    try {
        Save-BackgroundChoice 'Windows' 'Color' '#102030' ''; Save-BackgroundChoice 'MacOS' 'Image' '#123456' $Png
        Apply-Appearance 'Windows'; if ($ui.PersonalBackground.Background.Color.ToString() -ne '#FF102030' -or $window.Resources['BackdropText'].Color.ToString() -ne '#FFFFFFFF') { throw 'Solid background/contrast failed' }
        Apply-Appearance 'MacOS'; if ($ui.PersonalBackground.Background -isnot [Windows.Media.ImageBrush] -or !$ui.PersonalBackground.Background.ImageSource.IsFrozen) { throw 'Image background failed' }
        $script:visualDialogTest=$true; Show-BackgroundDialog; $script:visualDialogTest=$false; if ((Read-BackgroundChoices)['MacOS'].Hex -ne '#123456' -or (Read-BackgroundChoices)['Windows'].Hex -ne '#102030') { throw 'Background dialog changed other style' }
        $ui.PaletteTools.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)); $menu=$ui.PaletteTools.ContextMenu; $menu.UpdateLayout()
        if ($menu.Style -ne $window.FindResource('FluentContextMenu') -or $menu.Items[0].FontFamily.ToString() -notlike '*Segoe UI*') { throw 'Modern context menu missing' }; $menu.IsOpen=$false
        Test-ExperienceInterface $Png
        $script:availableVersion='99.0.0'; Sync-UpdateButton; if ($ui.UpdateAvailable.Visibility -ne 'Visible') { throw 'Available update button missing' }
        $script:availableVersion=$script:productVersion; Sync-UpdateButton; if ($ui.UpdateAvailable.Visibility -ne 'Collapsed') { throw 'Current version shows download button' }
        $script:availableVersion=$null; Sync-UpdateButton
    } finally { $script:visualDialogTest=$false; if ($null -ne $saved) { [IO.File]::WriteAllBytes($path,$saved) } elseif ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }; Apply-Appearance $style }
}

. (Join-Path $PSScriptRoot 'Experience.ps1')
