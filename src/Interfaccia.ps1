Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -Path (Join-Path $PSScriptRoot 'DesktopPicker.dll')
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class FluentWindow {
 [StructLayout(LayoutKind.Sequential)] public struct Margins { public int Left, Right, Top, Bottom; }
 [DllImport("dwmapi.dll")] public static extern int DwmExtendFrameIntoClientArea(IntPtr hwnd, ref Margins margins);
 [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
}
'@
$dark=$false
if ($Theme -eq 'Dark') { $dark=$true }
elseif ($Theme -eq 'System') {
    try { $dark=(Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme) -eq 0 } catch {}
}
$tokens=@{Page='#F1F5FA';Card='#B3FFFFFF';Text='#18212F';Secondary='#526174';Line='#300D2440';Hover='#DCFFFFFF';Selected='#350078EA';Accent='#007AFF';AccentHover='#0068DF';OnAccent='#FFFFFF';Input='#A6FFFFFF'}
if ($dark) { $tokens=@{Page='#202832';Card='#493F5066';Text='#F6F8FC';Secondary='#BBC7D8';Line='#38FFFFFF';Hover='#65556B85';Selected='#554D9EFF';Accent='#65B5FF';AccentHover='#85C6FF';OnAccent='#071C31';Input='#503E5067'} }
$script:glassEnabled=$false
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="{DynamicResource L_change}" Width="456" Height="616" MinHeight="560" MinWidth="440" ResizeMode="CanResize" WindowStartupLocation="CenterScreen" FontFamily="Segoe UI Variable, Segoe UI" FontSize="13" Background="{DynamicResource Page}" Foreground="{DynamicResource Text}" UseLayoutRounding="True" SnapsToDevicePixels="True">
 <Window.Resources>
  <Style TargetType="Button">
   <Setter Property="Background" Value="{DynamicResource Card}"/><Setter Property="Foreground" Value="{DynamicResource Text}"/>
   <Setter Property="BorderBrush" Value="{DynamicResource Line}"/><Setter Property="BorderThickness" Value="1"/>
   <Setter Property="Padding" Value="12,6"/><Setter Property="MinHeight" Value="34"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
    <Grid><Border Background="{TemplateBinding Background}" CornerRadius="{DynamicResource ControlRadius}" Effect="{DynamicResource ButtonShadow}" IsHitTestVisible="False"/><Border x:Name="Surface" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="{DynamicResource ControlRadius}" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></Grid>
    <ControlTemplate.Triggers>
     <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Background" Value="{DynamicResource Hover}"/></Trigger>
     <Trigger Property="IsPressed" Value="True"><Setter TargetName="Surface" Property="Opacity" Value="0.7"/></Trigger>
     <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Surface" Property="BorderBrush" Value="{DynamicResource Accent}"/></Trigger>
     <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Surface" Property="Opacity" Value="0.4"/></Trigger>
    </ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
   <Setter Property="Background" Value="{DynamicResource PrimaryFill}"/><Setter Property="Foreground" Value="{DynamicResource OnAccent}"/><Setter Property="BorderThickness" Value="0"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
    <Border x:Name="Surface" Background="{TemplateBinding Background}" CornerRadius="{DynamicResource ControlRadius}" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
    <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Background" Value="{DynamicResource AccentHover}"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="Surface" Property="Opacity" Value="0.75"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Surface" Property="BorderBrush" Value="{DynamicResource Text}"/><Setter TargetName="Surface" Property="BorderThickness" Value="2"/></Trigger></ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="TextBox">
   <Setter Property="Height" Value="34"/>
   <Setter Property="Background" Value="{DynamicResource Input}"/><Setter Property="Foreground" Value="{DynamicResource Text}"/><Setter Property="CaretBrush" Value="{DynamicResource Text}"/>
   <Setter Property="Padding" Value="10,6"/><Setter Property="BorderBrush" Value="{DynamicResource Line}"/><Setter Property="BorderThickness" Value="1"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TextBox"><Grid>
    <Border x:Name="Box" CornerRadius="{DynamicResource ControlRadius}" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" Padding="10,0">
     <ScrollViewer x:Name="PART_ContentHost" Padding="0" VerticalAlignment="Center"/>
    </Border>
    
   </Grid><ControlTemplate.Triggers><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Accent}"/><Setter TargetName="Box" Property="BorderThickness" Value="2"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="ListBoxItem">
   <Setter Property="HorizontalContentAlignment" Value="Stretch"/><Setter Property="Padding" Value="10,4"/><Setter Property="Margin" Value="3,3"/>
   <Setter Property="ToolTip" Value="{Binding Name}"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem"><Grid>
    <Border Background="{DynamicResource Card}" CornerRadius="{DynamicResource ControlRadius}" Effect="{DynamicResource ButtonShadow}" IsHitTestVisible="False"/>
    <Border x:Name="Row" CornerRadius="{DynamicResource ControlRadius}" Background="{DynamicResource Card}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border>
    </Grid><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Row" Property="Background" Value="{DynamicResource Hover}"/></Trigger><Trigger Property="IsSelected" Value="True"><Setter TargetName="Row" Property="Background" Value="{DynamicResource Selected}"/><Setter TargetName="Row" Property="BorderBrush" Value="{DynamicResource Accent}"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Row" Property="BorderBrush" Value="{DynamicResource Accent}"/></Trigger></ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="ScrollBar">
   <Setter Property="Width" Value="6"/><Setter Property="Background" Value="Transparent"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar">
    <Track x:Name="PART_Track" Orientation="Vertical" IsDirectionReversed="True" Minimum="{TemplateBinding Minimum}" Maximum="{TemplateBinding Maximum}" Value="{TemplateBinding Value}" ViewportSize="{TemplateBinding ViewportSize}">
     <Track.DecreaseRepeatButton><RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/></Track.DecreaseRepeatButton>
     <Track.IncreaseRepeatButton><RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/></Track.IncreaseRepeatButton>
     <Track.Thumb><Thumb><Thumb.Template><ControlTemplate TargetType="Thumb"><Border x:Name="ThumbSurface" Background="{DynamicResource Line}" CornerRadius="3" Margin="1,3"/><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ThumbSurface" Property="Background" Value="{DynamicResource Secondary}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>
    </Track>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style x:Key="GlassScroll" TargetType="ScrollViewer">
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollViewer"><Grid>
    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="8"/></Grid.ColumnDefinitions>
    <ScrollContentPresenter x:Name="PART_ScrollContentPresenter" Content="{TemplateBinding Content}" ContentTemplate="{TemplateBinding ContentTemplate}" CanContentScroll="{TemplateBinding CanContentScroll}" Margin="{TemplateBinding Padding}"/>
    <ScrollBar x:Name="PART_VerticalScrollBar" Grid.Column="1" Width="6" Orientation="Vertical" Visibility="{TemplateBinding ComputedVerticalScrollBarVisibility}" Maximum="{TemplateBinding ScrollableHeight}" ViewportSize="{TemplateBinding ViewportHeight}" Value="{Binding VerticalOffset, RelativeSource={RelativeSource TemplatedParent}, Mode=OneWay}"/>
   </Grid></ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="ListBox"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBox"><ScrollViewer x:Name="PaletteScroll" Focusable="False" Padding="{TemplateBinding Padding}" CanContentScroll="True" VerticalScrollBarVisibility="Auto" Style="{StaticResource GlassScroll}"><ItemsPresenter/></ScrollViewer></ControlTemplate></Setter.Value></Setter></Style>
 </Window.Resources>
 <Grid x:Name="Root" Margin="16,10,16,12">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <StackPanel Margin="0,0,0,8">
   <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBlock Text="{DynamicResource L_heading}" TextWrapping="Wrap" FontSize="19" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,8,0"/><Button x:Name="AppearanceButton" Grid.Column="1" Margin="0,0,6,0" Padding="9,6" AutomationProperties.Name="{DynamicResource L_appearance}"><StackPanel Orientation="Horizontal"><TextBlock x:Name="AppearanceName" FontSize="12"/><Path Data="M0,0 L4,4 L8,0" Stroke="{DynamicResource Text}" StrokeThickness="1.4" Width="8" Height="4" Margin="6,0,0,0" VerticalAlignment="Center"/></StackPanel></Button><Button x:Name="LanguageButton" Grid.Column="2" VerticalAlignment="Top" Padding="9,6" ToolTip="{DynamicResource L_language}" AutomationProperties.Name="{DynamicResource L_language}"><StackPanel Orientation="Horizontal"><Viewbox Width="16" Height="16" Margin="0,0,7,0"><Canvas Width="24" Height="24"><Ellipse Width="22" Height="22" Canvas.Left="1" Canvas.Top="1" Stroke="{DynamicResource Text}" StrokeThickness="1.5"/><Ellipse Width="9" Height="22" Canvas.Left="7.5" Canvas.Top="1" Stroke="{DynamicResource Text}" StrokeThickness="1.5"/><Path Data="M1,12 L23,12 M3,6 L21,6 M3,18 L21,18" Stroke="{DynamicResource Text}" StrokeThickness="1.5"/></Canvas></Viewbox><TextBlock x:Name="LanguageName"/></StackPanel></Button></Grid>
   <TextBlock Text="{DynamicResource L_folderName}" FontSize="11" Foreground="{DynamicResource Secondary}" Margin="0,5,0,3"/>
   <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBox x:Name="FolderName" MaxLength="255" AutomationProperties.Name="{DynamicResource L_folderName}"/><Button x:Name="RenameFolder" Grid.Column="1" ToolTip="{DynamicResource L_renameFolder}" AutomationProperties.Name="{DynamicResource L_renameFolder}" Margin="6,0,0,0" Padding="9,5"><Viewbox Width="16" Height="16"><Path Data="M16,3 L21,8 L8,21 L3,21 L3,16 Z M14,5 L19,10 M3,16 L8,21" Stroke="{DynamicResource Text}" StrokeThickness="1.8" Fill="Transparent"/></Viewbox></Button></Grid>
  </StackPanel>
  <ScrollViewer x:Name="MainScroll" Padding="6,2,6,4" Style="{StaticResource GlassScroll}" Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
   <StackPanel>
    <Grid Margin="2,2,2,6"><Border Background="{DynamicResource Card}" CornerRadius="{DynamicResource CardRadius}" Effect="{DynamicResource PanelShadow}" IsHitTestVisible="False"/>
    <Border Background="{DynamicResource Card}" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="{DynamicResource CardRadius}" Padding="10">
     <Grid>
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="10"/><ColumnDefinition Width="98"/></Grid.ColumnDefinitions>
      <StackPanel>
       <Grid Height="98" ClipToBounds="True" FlowDirection="LeftToRight">
        <Border x:Name="HueBase" Background="Red" CornerRadius="{DynamicResource ControlRadius}"/>
        <Border CornerRadius="{DynamicResource ControlRadius}"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="White" Offset="0"/><GradientStop Color="#00FFFFFF" Offset="1"/></LinearGradientBrush></Border.Background></Border>
        <Border CornerRadius="{DynamicResource ControlRadius}"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#00000000" Offset="0"/><GradientStop Color="Black" Offset="1"/></LinearGradientBrush></Border.Background></Border>
        <Canvas x:Name="ColorPlane" Background="Transparent" Cursor="None" Focusable="True" AutomationProperties.Name="{DynamicResource L_planeName}" ToolTip="{DynamicResource L_planeHelp}">
         <Ellipse x:Name="ColorPointer" Width="14" Height="14" Stroke="White" StrokeThickness="2" IsHitTestVisible="False"><Ellipse.Effect><DropShadowEffect ShadowDepth="0" BlurRadius="3" Opacity="0.8"/></Ellipse.Effect></Ellipse>
         <Grid x:Name="HoverPoint" Width="16" Height="16" IsHitTestVisible="False" Visibility="Collapsed"><Ellipse Margin="1" Stroke="Black" StrokeThickness="3"/><Ellipse Margin="1" Stroke="White" StrokeThickness="1"/><Ellipse Width="3" Height="3" Fill="White" Stroke="Black" StrokeThickness="1"/></Grid>
        </Canvas>
       </Grid>
       <Grid Margin="0,6,0,0" Height="24" FlowDirection="LeftToRight">
        <Border Height="10" VerticalAlignment="Center" CornerRadius="{DynamicResource ControlRadius}"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="Red" Offset="0"/><GradientStop Color="Yellow" Offset="0.1667"/><GradientStop Color="Lime" Offset="0.3333"/><GradientStop Color="Cyan" Offset="0.5"/><GradientStop Color="Blue" Offset="0.6667"/><GradientStop Color="Magenta" Offset="0.8333"/><GradientStop Color="Red" Offset="1"/></LinearGradientBrush></Border.Background></Border>
        <Slider x:Name="Hue" Minimum="0" Maximum="359.99" SmallChange="1" LargeChange="15" Background="Transparent" ToolTip="{DynamicResource L_hue}" AutomationProperties.Name="{DynamicResource L_hue}">
         <Slider.Template><ControlTemplate TargetType="Slider"><Track x:Name="PART_Track" Minimum="{TemplateBinding Minimum}" Maximum="{TemplateBinding Maximum}" Value="{TemplateBinding Value}"><Track.DecreaseRepeatButton><RepeatButton Command="Slider.DecreaseLarge" Opacity="0"/></Track.DecreaseRepeatButton><Track.IncreaseRepeatButton><RepeatButton Command="Slider.IncreaseLarge" Opacity="0"/></Track.IncreaseRepeatButton><Track.Thumb><Thumb Width="18" Height="22"><Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="White" BorderBrush="#66000000" BorderThickness="1" CornerRadius="{DynamicResource ControlRadius}"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb></Track></ControlTemplate></Slider.Template>
        </Slider>
       </Grid>
      </StackPanel>
      <StackPanel Grid.Column="2">
       <Border Height="60" CornerRadius="14" Background="{DynamicResource Input}" Margin="0,0,0,8"><Viewbox Margin="8"><Grid Width="256" Height="256" FlowDirection="LeftToRight">
         <Path x:Name="FolderFront" Fill="#4A90E2" Data="M 52,10 L 192,10 L 192,139 L 204,152 L 204,208 L 52,208 Z"/>
         <Path x:Name="FolderBack" Fill="#60A0E6" Data="M 52,10 L 101,47 L 101,245 L 52,208 Z"/>
         <Image x:Name="UploadedPreview" Visibility="Collapsed" Stretch="Uniform" Margin="8"/>
       </Grid></Viewbox></Border>
       <TextBlock Text="{DynamicResource L_hex}" TextWrapping="Wrap" Foreground="{DynamicResource Secondary}" Margin="0,0,0,4"/><TextBox x:Name="Hex" FlowDirection="LeftToRight" Text="#4A90E2" FontFamily="Consolas" MaxLength="7" AutomationProperties.Name="{DynamicResource L_hex}"/>
      </StackPanel>
     </Grid>
    </Border></Grid>
    <Grid Margin="0,5,0,5"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="10"/><ColumnDefinition Width="Auto" MinWidth="112"/></Grid.ColumnDefinitions>
     <StackPanel><TextBlock Text="{DynamicResource L_name}" Margin="0,0,0,4" FontSize="11" Foreground="{DynamicResource Secondary}"/><TextBox x:Name="ColorName" AutomationProperties.Name="{DynamicResource L_name}"/></StackPanel><Button x:Name="Save" Grid.Column="2" MinWidth="112" Content="{DynamicResource L_save}" VerticalAlignment="Bottom" Height="34"/>
    </Grid>
    <Grid Margin="0,0,0,3"><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBlock Text="{DynamicResource L_saved}" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/><Button x:Name="New" Grid.Column="1" Content="{DynamicResource L_new}" Margin="8,0,0,0" Padding="9,4" MinHeight="30"/><Button x:Name="Delete" Grid.Column="3" Content="{DynamicResource L_delete}" Margin="5,0,0,0" Padding="9,4" MinHeight="30" Visibility="Collapsed"/></Grid>
    <ListBox x:Name="Colors" MaxHeight="104" Padding="1,2" Background="Transparent" Foreground="{DynamicResource Text}" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled" VirtualizingPanel.IsVirtualizing="True" VirtualizingPanel.VirtualizationMode="Recycling">
     <ListBox.ItemTemplate><DataTemplate><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="24"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Ellipse Width="14" Height="14" Fill="{Binding Hex}" HorizontalAlignment="Left" VerticalAlignment="Center"/><TextBlock Text="{Binding Name}" Grid.Column="1" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/></Grid></DataTemplate></ListBox.ItemTemplate>
    </ListBox>
    <TextBlock x:Name="Empty" Text="{DynamicResource L_empty}" TextWrapping="Wrap" Foreground="{DynamicResource Secondary}" Margin="0,6,0,0" Visibility="Collapsed"/>
   </StackPanel>
  </ScrollViewer>
  <StackPanel Grid.Row="2" Margin="0,8,0,0">
   <Grid Margin="0,0,0,8"><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Button x:Name="Pick" ToolTip="{DynamicResource L_pickHelp}" AutomationProperties.Name="{DynamicResource L_pick}" Padding="10,6"><Viewbox Width="20" Height="20"><Path Width="24" Height="24" Stretch="Uniform" Fill="{DynamicResource Text}" Data="M 16,2 Q 17,1 18,2 L 22,6 Q 23,7 22,8 L 19,11 L 20,12 L 18,14 L 16,12 L 8,20 L 3,21 L 4,16 L 12,8 L 10,6 L 12,4 L 13,5 Z M 6,17 L 5.5,18.5 L 7,18 L 14.5,10.5 L 13,9 Z"/></Viewbox></Button><Button x:Name="Upload" Grid.Column="1" Content="{DynamicResource L_upload}" Margin="8,0,0,0" Padding="12,6"/><Button x:Name="UseColor" Grid.Column="2" Content="{DynamicResource L_use}" HorizontalAlignment="Right" Padding="12,6" Visibility="Collapsed"/></Grid>
   <TextBlock x:Name="Status" TextWrapping="Wrap" Margin="0,0,0,10" Visibility="Collapsed" Foreground="{DynamicResource Text}"/>
   <Button x:Name="Apply" Content="{DynamicResource L_apply}" ToolTip="{DynamicResource L_applyHelp}" Style="{StaticResource Primary}" Height="38"/>
  </StackPanel>
 </Grid>
</Window>
'@
$reader=New-Object Xml.XmlNodeReader $xaml
$window=[Windows.Markup.XamlReader]::Load($reader)
$ui=@{}
foreach ($id in @('Root','MainScroll','FolderName','HueBase','ColorPlane','ColorPointer','Hue','FolderBack','FolderFront','Hex','ColorName','Save','Colors','New','Delete','Empty','Apply','Status','Upload','UseColor','UploadedPreview','Pick','HoverPoint','LanguageButton','LanguageName','RenameFolder','AppearanceButton','AppearanceName')) { $ui[$id]=$window.FindName($id) }
$script:pngSelection=$null
$ui.ColorPlane.Cursor=[Windows.Input.Cursors]::None
$ui.ColorPlane.ForceCursor=$true
$ui.ColorPlane.Add_MouseEnter({ [Windows.Input.Mouse]::OverrideCursor=[Windows.Input.Cursors]::None; $ui.HoverPoint.Visibility='Visible'; $ui.ColorPointer.Visibility='Collapsed' })
$ui.ColorPlane.Add_MouseLeave({ [Windows.Input.Mouse]::OverrideCursor=$null; $ui.HoverPoint.Visibility='Collapsed'; $ui.ColorPointer.Visibility='Visible' })
$window.Add_QueryCursor({ param($sender,$e)
    if ($ui.ColorPlane.IsMouseOver) { $e.Cursor=[Windows.Input.Cursors]::None; $e.Handled=$true }
})
$ui.FolderName.Text=[IO.Path]::GetFileName($Folder); $ui.FolderName.ToolTip=$Folder
$script:currentFolder=$Folder
$script:collection=New-Object 'Collections.ObjectModel.ObservableCollection[object]'
try { foreach ($c in @(Read-Palette)) { $script:collection.Add($c) } } catch { [Windows.MessageBox]::Show((Translate-Error $_.Exception.Message),'CartelleColorate') | Out-Null; exit 1 }
if ($Preview) {
    $script:collection.Clear()
    foreach ($c in @(@{Name=(T 'projects');Hex='#4A90E2'},@{Name=(T 'personal');Hex='#A78BFA'},@{Name=(T 'todo');Hex='#F59E0B'},@{Name=(T 'archive');Hex='#34B890'})) { $script:collection.Add([pscustomobject]$c) }
}
$ui.Colors.ItemsSource=$script:collection
$script:syncing=$false; $script:saturation=0.67; $script:brightness=0.89
function Brush([string]$Value) { [Windows.Media.BrushConverter]::new().ConvertFromString($Value) }
function Get-HsvHex([double]$Hue,[double]$S,[double]$V) {
    $h=$Hue/60; $chroma=$V*$S; $x=$chroma*(1-[Math]::Abs(($h%2)-1)); $m=$V-$chroma
    $rgb=switch ([int][Math]::Floor($h)) { 0 {@($chroma,$x,0)} 1 {@($x,$chroma,0)} 2 {@(0,$chroma,$x)} 3 {@(0,$x,$chroma)} 4 {@($x,0,$chroma)} default {@($chroma,0,$x)} }
    '#{0:X2}{1:X2}{2:X2}' -f [int][Math]::Round(($rgb[0]+$m)*255),[int][Math]::Round(($rgb[1]+$m)*255),[int][Math]::Round(($rgb[2]+$m)*255)
}
function Update-Pointer {
    [Windows.Controls.Canvas]::SetLeft($ui.ColorPointer,($script:saturation*$ui.ColorPlane.ActualWidth-7))
    [Windows.Controls.Canvas]::SetTop($ui.ColorPointer,((1-$script:brightness)*$ui.ColorPlane.ActualHeight-7))
}
function Update-Preview([string]$HexValue) {
    $script:pngSelection=$null; $ui.UploadedPreview.Visibility='Collapsed'
    $ui.FolderFront.Visibility='Visible'; $ui.FolderBack.Visibility='Visible'
    $ui.UseColor.Visibility='Collapsed'; $ui.Save.IsEnabled=$true; $ui.Upload.Content=(T 'upload')
    $ui.FolderFront.Fill=Brush $HexValue; $c=[Drawing.ColorTranslator]::FromHtml($HexValue)
    $shade='#{0:X2}{1:X2}{2:X2}' -f [int]($c.R+(255-$c.R)*0.12),[int]($c.G+(255-$c.G)*0.12),[int]($c.B+(255-$c.B)*0.12)
    $ui.FolderBack.Fill=Brush $shade
}
function Set-PickerFromHex([string]$HexValue) {
    $c=[Drawing.ColorTranslator]::FromHtml($HexValue)
    $max=[Math]::Max($c.R,[Math]::Max($c.G,$c.B)); $min=[Math]::Min($c.R,[Math]::Min($c.G,$c.B))
    $script:syncing=$true
    try {
        $script:brightness=$max/255.0; $script:saturation=0
        if ($max -gt 0) { $script:saturation=($max-$min)/[double]$max }
        if ($max -ne $min) { $ui.Hue.Value=$c.GetHue() }
        $ui.HueBase.Background=Brush (Get-HsvHex $ui.Hue.Value 1 1)
        Update-Preview $HexValue; Update-Pointer
    } finally { $script:syncing=$false }
}
function Valid-Hex {
    $v=$ui.Hex.Text.Trim().ToUpperInvariant(); if ($v -match '^[0-9A-F]{6}$') { $v='#'+$v }
    if ($v -notmatch '^#[0-9A-F]{6}$') { throw (T 'hexError') }; $v
}
function Show-Status([string]$Text) { $ui.Status.Text=Translate-Error $Text; $ui.Status.Visibility='Visible' }
function Update-Empty { $ui.Empty.Visibility='Collapsed'; $ui.Colors.Visibility='Visible'; if ($script:collection.Count -eq 0) { $ui.Empty.Visibility='Visible'; $ui.Colors.Visibility='Collapsed' } }
function Save-Colors {
    $items=@($script:collection | ForEach-Object { [pscustomobject]@{Name=$_.Name;Hex=$_.Hex} })
    $json=ConvertTo-Json -InputObject $items -Depth 4; $tmp=$palettePath+'.tmp'
    [IO.File]::WriteAllText($tmp,$json,[Text.Encoding]::UTF8); Move-Item -LiteralPath $tmp -Destination $palettePath -Force
    if (!$Preview) { Update-Menu }; Update-Empty
}
function Set-PlanePoint([double]$X,[double]$Y) {
    $script:saturation=[Math]::Max(0.0,[Math]::Min(1.0,$X/[Math]::Max(1.0,$ui.ColorPlane.ActualWidth)))
    $script:brightness=1-[Math]::Max(0.0,[Math]::Min(1.0,$Y/[Math]::Max(1.0,$ui.ColorPlane.ActualHeight)))
    $script:syncing=$true
    try { $ui.Hex.Text=Get-HsvHex $ui.Hue.Value $script:saturation $script:brightness; Update-Preview $ui.Hex.Text; Update-Pointer; $ui.Status.Visibility='Collapsed' } finally { $script:syncing=$false }
}
function Update-FromPlane($MouseEvent) {
    $point=$MouseEvent.GetPosition($ui.ColorPlane)
    Set-PlanePoint $point.X $point.Y
}
$ui.ColorPlane.Add_PreviewMouseLeftButtonDown({ param($sender,$e)
    [void]$ui.ColorPlane.Focus()
    [void]$ui.ColorPlane.CaptureMouse()
    Update-FromPlane $e
    $e.Handled=$true
})
$ui.ColorPlane.Add_PreviewMouseMove({ param($sender,$e)
    $hover=$e.GetPosition($ui.ColorPlane)
    [Windows.Controls.Canvas]::SetLeft($ui.HoverPoint,$hover.X-8)
    [Windows.Controls.Canvas]::SetTop($ui.HoverPoint,$hover.Y-8)
    if ($ui.ColorPlane.IsMouseCaptured -and $e.LeftButton -eq [Windows.Input.MouseButtonState]::Pressed) {
        $script:pendingPlane=$e.GetPosition($ui.ColorPlane); $e.Handled=$true
    }
})
$ui.ColorPlane.Add_PreviewMouseLeftButtonUp({ param($sender,$e)
    if ($ui.ColorPlane.IsMouseCaptured) { $script:pendingPlane=$null; Update-FromPlane $e; $ui.ColorPlane.ReleaseMouseCapture(); $e.Handled=$true }
})
$planeTimer=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Background)
$planeTimer.Interval=[TimeSpan]::FromMilliseconds(33)
$planeTimer.Add_Tick({
    if ($null -ne $script:pendingPlane) {
        $point=$script:pendingPlane; $script:pendingPlane=$null
        Set-PlanePoint $point.X $point.Y
    }
})
$planeTimer.Start()
$ui.ColorPlane.Add_KeyDown({ param($sender,$e)
    $step=1.0
    if ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Shift) { $step=0.1 }
    $x=$script:saturation*$ui.ColorPlane.ActualWidth
    $y=(1-$script:brightness)*$ui.ColorPlane.ActualHeight
    switch ($e.Key.ToString()) {
        'Left' { $x-=$step }
        'Right' { $x+=$step }
        'Up' { $y-=$step }
        'Down' { $y+=$step }
        default { return }
    }
    Set-PlanePoint $x $y; $e.Handled=$true
})
$ui.ColorPlane.Add_SizeChanged({ Update-Pointer })
$ui.Hue.Add_ValueChanged({
    if ($script:syncing) { return }; $script:syncing=$true
    try { $ui.HueBase.Background=Brush (Get-HsvHex $ui.Hue.Value 1 1); $ui.Hex.Text=Get-HsvHex $ui.Hue.Value $script:saturation $script:brightness; Update-Preview $ui.Hex.Text } finally { $script:syncing=$false }
})
$ui.Hex.Add_TextChanged({ if (!$script:syncing) { try { Set-PickerFromHex (Valid-Hex); $ui.Status.Visibility='Collapsed' } catch {} } })
$ui.Colors.Add_SelectionChanged({
    $c=$ui.Colors.SelectedItem
    if ($c) { $ui.ColorName.Text=$c.Name; $ui.Hex.Text=$c.Hex; $ui.Save.Content=(T 'saveChanges'); $ui.Delete.Visibility='Visible' }
    else { $ui.Save.Content=(T 'save'); $ui.Delete.Visibility='Collapsed' }; $ui.Status.Visibility='Collapsed'
})
$ui.New.Add_Click({ $ui.Colors.SelectedIndex=-1; $ui.ColorName.Clear(); [void]$ui.ColorName.Focus(); $ui.Status.Visibility='Collapsed' })
$ui.Save.Add_Click({ try {
    $v=Valid-Hex; $n=$ui.ColorName.Text.Trim(); if (!$n) { $n=$v }; $idx=$ui.Colors.SelectedIndex
    $item=[pscustomobject]@{Name=$n;Hex=$v}
    if ($idx -ge 0) { $script:collection[$idx]=$item } else { $script:collection.Add($item); $idx=$script:collection.Count-1 }
    Save-Colors; $ui.Colors.SelectedIndex=$idx; $ui.ColorName.Text=$n; $ui.Save.Content=(T 'saveChanges'); $ui.Delete.Visibility='Visible'; $ui.Status.Visibility='Collapsed'
} catch { Show-Status $_.Exception.Message } })
$ui.Delete.Add_Click({ try { $idx=$ui.Colors.SelectedIndex; if ($idx -ge 0) { $script:collection.RemoveAt($idx); Save-Colors; $ui.ColorName.Clear() } } catch { Show-Status $_.Exception.Message } })
function Set-PngPreview([string]$Path) {
    $image=[Windows.Media.Imaging.BitmapImage]::new()
    $image.BeginInit(); $image.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $image.UriSource=[Uri]::new($Path); $image.EndInit(); $image.Freeze()
    $ui.UploadedPreview.Source=$image; $ui.UploadedPreview.Visibility='Visible'
    $ui.FolderFront.Visibility='Collapsed'; $ui.FolderBack.Visibility='Collapsed'
    $script:pngSelection=$Path; $ui.UseColor.Visibility='Visible'; $ui.Save.IsEnabled=$false
    $ui.Upload.Content=(T 'changePng'); $ui.Status.Visibility='Collapsed'
}
$ui.Upload.Add_Click({
    $dialog=[Microsoft.Win32.OpenFileDialog]::new()
    $dialog.Filter=(T 'pngFilter'); $dialog.Title=(T 'pngTitle')
    if ($dialog.ShowDialog($window)) { try { Set-PngPreview $dialog.FileName } catch { Show-Status (T 'pngError') } }
})
$ui.UseColor.Add_Click({ try { Update-Preview (Valid-Hex) } catch { Show-Status $_.Exception.Message } })
[xml]$lensXaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Width="194" Height="220" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Topmost="True" IsHitTestVisible="False" WindowStartupLocation="Manual">
 <Border Background="#ED202020" BorderBrush="#606060" BorderThickness="1" CornerRadius="10" Padding="13">
  <StackPanel>
   <Grid Width="150" Height="150" ClipToBounds="True" FlowDirection="LeftToRight">
    <Image x:Name="Magnified" Stretch="Fill" FlowDirection="LeftToRight" RenderOptions.BitmapScalingMode="NearestNeighbor"/>
    <Rectangle Width="14" Height="14" Stroke="Black" StrokeThickness="3" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    <Rectangle Width="12" Height="12" Stroke="White" StrokeThickness="1" HorizontalAlignment="Center" VerticalAlignment="Center"/>
   </Grid>
   <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,9,0,0"><Border x:Name="SampleSwatch" Width="14" Height="14" CornerRadius="3" Margin="0,0,8,0"/><TextBlock x:Name="SampleHex" Foreground="White" FontFamily="Consolas" FontSize="14"/></StackPanel>
   <TextBlock Text="{DynamicResource L_lensHint}" Foreground="#BBBBBB" FontFamily="Segoe UI" FontSize="10" HorizontalAlignment="Center" Margin="0,6,0,0"/>
  </StackPanel>
 </Border>
</Window>
'@
$lens=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($lensXaml))
$lens.FindName('SampleHex').FlowDirection='LeftToRight'
$lensImage=$lens.FindName('Magnified'); $lensHex=$lens.FindName('SampleHex'); $lensSwatch=$lens.FindName('SampleSwatch')
$lens.Add_SourceInitialized({ [DesktopPicker]::MakeOverlay([Windows.Interop.WindowInteropHelper]::new($lens).Handle) })
function Set-LensImage([byte[]]$Bytes,[string]$HexValue) {
    $memory=[IO.MemoryStream]::new($Bytes)
    try {
        $image=[Windows.Media.Imaging.BitmapImage]::new()
        $image.BeginInit(); $image.CacheOption='OnLoad'; $image.StreamSource=$memory; $image.EndInit(); $image.Freeze()
        $lensImage.Source=$image; $lensHex.Text=$HexValue; $lensSwatch.Background=Brush $HexValue
    } finally { $memory.Dispose() }
}
function Set-LensPixels([byte[]]$Pixels,[string]$HexValue) {
    if (!$script:lensBitmap) {
        $script:lensBitmap=[Windows.Media.Imaging.WriteableBitmap]::new(15,15,96,96,[Windows.Media.PixelFormats]::Bgr32,$null)
        $lensImage.Source=$script:lensBitmap
    }
    $script:lensBitmap.WritePixels([Windows.Int32Rect]::new(0,0,15,15),$Pixels,60,0)
    $lensHex.Text=$HexValue; $lensSwatch.Background=Brush $HexValue
}
function Update-Lens {
    $frame=[DesktopPicker]::Capture()
    if (!$frame) { return }
    Set-LensPixels $frame.Bgra $frame.Hex
    $right=[Windows.SystemParameters]::VirtualScreenLeft+[Windows.SystemParameters]::VirtualScreenWidth
    $bottom=[Windows.SystemParameters]::VirtualScreenTop+[Windows.SystemParameters]::VirtualScreenHeight
    $left=$frame.X+28; $top=$frame.Y+28
    if ($left+194 -gt $right) { $left=$frame.X-222 }
    if ($top+220 -gt $bottom) { $top=$frame.Y-248 }
    $lens.Left=[Math]::Max([Windows.SystemParameters]::VirtualScreenLeft,$left)
    $lens.Top=[Math]::Max([Windows.SystemParameters]::VirtualScreenTop,$top)
}
$pickerTimer=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Background)
$pickerTimer.Interval=[TimeSpan]::FromMilliseconds(40)
$pickerTimer.Add_Tick({
    if ([DesktopPicker]::Ready -or [DesktopPicker]::EscapePressed) {
        $cancel=[DesktopPicker]::EscapePressed
        $color=$null
        if (!$cancel -and [DesktopPicker]::Ready) {
            try { $color=[DesktopPicker]::CompleteSelection() } catch {}
        }
        $pickerTimer.Stop(); [DesktopPicker]::Stop(); $lens.Hide()
        $window.Show(); [void]$window.Activate()
        if (!$cancel -and $color) { $ui.Hex.Text=$color; Set-PickerFromHex $color; $ui.Status.Visibility='Collapsed' }
        elseif (!$cancel) { Show-Status (T 'pixelError') }
    } else {
        try { Update-Lens } catch {
            $pickerTimer.Stop(); [DesktopPicker]::Stop(); $lens.Hide(); $window.Show()
            Show-Status (T 'pixelError')
        }
    }
})
$ui.Pick.Add_Click({
    try {
        $ui.Status.Visibility='Collapsed'
        $window.Hide()
        [DesktopPicker]::Begin(); Update-Lens; $lens.Show(); $pickerTimer.Start()
    } catch { [DesktopPicker]::Stop(); $lens.Hide(); $window.Show(); Show-Status $_.Exception.Message }
})
$window.Add_Closed({ [Windows.Input.Mouse]::OverrideCursor=$null; $planeTimer.Stop(); $pickerTimer.Stop(); [DesktopPicker]::Stop(); $lens.Close() })
function Rename-SelectedFolder {
    $script:currentFolder=Rename-Folder $script:currentFolder $ui.FolderName.Text
    $ui.FolderName.Text=[IO.Path]::GetFileName($script:currentFolder)
    $ui.FolderName.ToolTip=$script:currentFolder
}
$ui.RenameFolder.Add_Click({ try { Rename-SelectedFolder; Show-Status (T 'folderRenamed') } catch { Show-Status $_.Exception.Message } })
$ui.Apply.Add_Click({ try {
    $hexValue=$null
    if (!$script:pngSelection) { $hexValue=Valid-Hex }
    Rename-SelectedFolder
    if ($script:pngSelection) { Set-FolderPng $script:currentFolder $script:pngSelection } else { Set-FolderColor $script:currentFolder $hexValue }
    if (!$UITest) { $window.Close() }
} catch { Show-Status $_.Exception.Message } })
function Set-GlassSurface([bool]$Transparent) {
    $page=[Windows.Media.LinearGradientBrush]::new(); $page.StartPoint=[Windows.Point]::new(0,0); $page.EndPoint=[Windows.Point]::new(1,1)
    $colors=if ($dark) { if ($Transparent) { @('#603F404B','#42232630','#603B3244') } else { @('#FF353640','#FF252831','#FF35303F') } } else { if ($Transparent) { @('#85FFFFFF','#55EAF3FF','#72F3E9FF') } else { @('#FFF6F8FD','#FFECF2FA','#FFF4EDF9') } }
    for ($i=0; $i -lt 3; $i++) { $page.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($colors[$i]),$i/2.0)) }
    $page.Freeze(); $window.Resources['Page']=$page
}
function Set-AppearanceMaterial {
    $script:glassEnabled=$false
    $hwnd=[Windows.Interop.WindowInteropHelper]::new($window).Handle
    if ($hwnd -eq [IntPtr]::Zero) { return }
    $source=[Windows.Interop.HwndSource]::FromHwnd($hwnd)
    $margins=[FluentWindow+Margins]::new(); $backdrop=1
    [void][FluentWindow]::DwmSetWindowAttribute($hwnd,38,[ref]$backdrop,4)
    [void][FluentWindow]::DwmExtendFrameIntoClientArea($hwnd,[ref]$margins)
    $source.CompositionTarget.BackgroundColor=[Windows.Media.Colors]::Transparent
    $transparency=$true
    try { $transparency=(Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name EnableTransparency) -ne 0 } catch {}
    if ($script:appearance -eq 'MacOS' -and !$Preview -and $transparency -and ![Windows.SystemParameters]::HighContrast) {
        $backdrop=3
        if ([FluentWindow]::DwmSetWindowAttribute($hwnd,38,[ref]$backdrop,4) -eq 0) {
            $margins.Left=-1; $margins.Right=-1; $margins.Top=-1; $margins.Bottom=-1
            if ([FluentWindow]::DwmExtendFrameIntoClientArea($hwnd,[ref]$margins) -eq 0) { Set-GlassSurface $true; $script:glassEnabled=$true }
            else { $backdrop=1; [void][FluentWindow]::DwmSetWindowAttribute($hwnd,38,[ref]$backdrop,4) }
        }
    }
}
function Apply-Appearance([ValidateSet('Windows','MacOS')][string]$Style) {
    $script:appearance=$Style; $mac=$Style -eq 'MacOS'
    $colors=if ($mac) { if ($dark) { @{Page='#292C35';Card='#704A5060';Text='#F6F8FC';Secondary='#C0C6D4';Line='#55FFFFFF';Hover='#80556378';Selected='#605799DA';Accent='#74BCFF';AccentHover='#92CDFF';OnAccent='#092039';Input='#603B4353'} } else { @{Page='#F1F5FA';Card='#B3FFFFFF';Text='#18212F';Secondary='#526174';Line='#300D2440';Hover='#DCFFFFFF';Selected='#350078EA';Accent='#007AFF';AccentHover='#0068DF';OnAccent='#FFFFFF';Input='#A6FFFFFF'} } } else { if ($dark) { @{Page='#202020';Card='#2B2B2B';Text='#F5F5F5';Secondary='#ADADAD';Line='#414141';Hover='#383838';Selected='#344452';Accent='#60CDFF';AccentHover='#78D5FF';OnAccent='#00304A';Input='#333333'} } else { @{Page='#F3F3F3';Card='#FFFFFF';Text='#1A1A1A';Secondary='#666666';Line='#E4E4E4';Hover='#F0F0F0';Selected='#E8F0FB';Accent='#0067C0';AccentHover='#005AAB';OnAccent='#FFFFFF';Input='#FAFAFA'} } }
    foreach ($key in $colors.Keys) { $window.Resources[$key]=[Windows.Media.BrushConverter]::new().ConvertFromString($colors[$key]) }
    $window.Resources['ControlRadius']=[Windows.CornerRadius]::new($(if ($mac) { 12 } else { 5 }))
    $window.Resources['CardRadius']=[Windows.CornerRadius]::new($(if ($mac) { 20 } else { 8 }))
    foreach ($name in @('PanelShadow','ButtonShadow')) {
        $shadow=[Windows.Media.Effects.DropShadowEffect]::new(); $shadow.Color=[Windows.Media.Colors]::Black; $shadow.Direction=270
        $shadow.ShadowDepth=if ($name -eq 'PanelShadow') { 5 } else { 2 }; $shadow.BlurRadius=if ($name -eq 'PanelShadow') { 16 } else { 7 }
        $shadow.Opacity=if ($mac) { if ($dark) { 0.32 } else { 0.16 } } else { 0 }; $shadow.Freeze(); $window.Resources[$name]=$shadow
    }
    if ($mac) {
        foreach ($surface in @('Card','Line','PrimaryFill')) {
            $gradient=[Windows.Media.LinearGradientBrush]::new(); $gradient.StartPoint=[Windows.Point]::new(0,0); $gradient.EndPoint=[Windows.Point]::new(0,1)
            $stops=switch ($surface) { 'Card' { if ($dark) { @('#9A626877','#45404A5A') } else { @('#ECFFFFFF','#80FFFFFF') } } 'Line' { if ($dark) { @('#A0FFFFFF','#28FFFFFF') } else { @('#FFFFFFFF','#350D2440') } } 'PrimaryFill' { if ($dark) { @('#A1D3FF','#69B4FA') } else { @('#47A2FF','#087CF5') } } }
            $gradient.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($stops[0]),0)); $gradient.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($stops[1]),1)); $gradient.Freeze(); $window.Resources[$surface]=$gradient
        }
        Set-GlassSurface $false
    } else { $window.Resources['PrimaryFill']=$window.Resources['Accent'] }
    $ui.AppearanceName.Text=if ($mac) { T 'macStyle' } else { T 'windowsStyle' }
    $ui.AppearanceButton.ToolTip=(T 'appearance')+': '+$ui.AppearanceName.Text
    Set-AppearanceMaterial
}
$ui.AppearanceButton.Add_Click({
    $menu=[Windows.Controls.ContextMenu]::new(); $menu.PlacementTarget=$ui.AppearanceButton; $menu.Placement='Bottom'; $menu.FlowDirection=$window.FlowDirection
    $menu.Background=Brush $(if ($dark) { '#FF30343E' } else { '#FFF6F8FC' }); $menu.Foreground=$window.Resources['Text']; $menu.BorderBrush=$window.Resources['Line']; $menu.BorderThickness=[Windows.Thickness]::new(1); $menu.Padding=[Windows.Thickness]::new(4)
    $menuTemplate='<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="ContextMenu"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="12" Padding="4"><ItemsPresenter/></Border></ControlTemplate>'
    if ($script:appearance -eq 'Windows') { $menuTemplate=$menuTemplate.Replace('CornerRadius="12"','CornerRadius="5"') }
    $menu.Template=[Windows.Markup.XamlReader]::Parse($menuTemplate)
    foreach ($style in @('Windows','MacOS')) {
        $item=[Windows.Controls.MenuItem]::new(); $item.Header=if ($style -eq 'Windows') { T 'windowsStyle' } else { T 'macStyle' }; $item.Tag=$style; $item.IsCheckable=$true; $item.IsChecked=$script:appearance -eq $style
        $item.Add_Click({ param($sender,$e) try { Save-AppearancePreference ([string]$sender.Tag); Apply-Appearance ([string]$sender.Tag) } catch { Show-Status $_.Exception.Message } }); $null=$menu.Items.Add($item)
    }
    $ui.AppearanceButton.ContextMenu=$menu; $menu.IsOpen=$true
})
Apply-Appearance (Read-AppearancePreference)
$window.Add_SourceInitialized({
    $hwnd=[Windows.Interop.WindowInteropHelper]::new($window).Handle
    $corner=2; [void][FluentWindow]::DwmSetWindowAttribute($hwnd,33,[ref]$corner,4)
    $mode=[int]$dark; [void][FluentWindow]::DwmSetWindowAttribute($hwnd,20,[ref]$mode,4)
    Set-AppearanceMaterial
})

function Apply-InterfaceLanguage {
    Set-LanguageResources $window
    Set-LanguageResources $lens
    $ui.AppearanceButton.ToolTip=(T 'appearance')+': '+$ui.AppearanceName.Text
    $ui.LanguageName.Text=$script:activeLanguage.nativeName
    $ui.Save.Content=if ($ui.Colors.SelectedIndex -ge 0) { T 'saveChanges' } else { T 'save' }
    $ui.Upload.Content=if ($script:pngSelection) { T 'changePng' } else { T 'upload' }
    $ui.Status.Visibility='Collapsed'
}
$ui.LanguageButton.Add_Click({
    try {
        if (Show-LanguageDialog $window) {
            Apply-InterfaceLanguage
            if (!$Preview) { Update-Menu }
        }
    } catch { Show-Status $_.Exception.Message }
})
Apply-InterfaceLanguage
if (!$Preview -and !$script:hasLanguagePreference) {
    if (!(Show-LanguageDialog $null)) { $window.Close(); exit }
    Apply-InterfaceLanguage
    Update-Menu
}

Set-PickerFromHex '#4A90E2'; Update-Empty
if ($Preview) {
    $window.WindowStartupLocation='Manual'; $window.Left=-3000; $window.Top=-3000; $window.ShowInTaskbar=$false
    $window.Show(); $window.UpdateLayout()
    if ($UITest) {
        $paletteScroll=$ui.Colors.Template.FindName('PaletteScroll',$ui.Colors)
        $paletteScroll.ScrollToBottom(); $window.UpdateLayout()
        [Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::ApplicationIdle)
        if ($paletteScroll.ScrollableHeight -le 0 -or $paletteScroll.VerticalOffset -le 0) { throw 'Scorrimento dei colori salvati non funzionante.' }
        $paletteScroll.ScrollToTop(); $window.UpdateLayout()
        $initialAppearance=$script:appearance; $initialHex=$ui.Hex.Text; $initialFolder=$ui.FolderName.Text
        $ui.AppearanceButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        $ui.AppearanceButton.ContextMenu.Items[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent)); $ui.AppearanceButton.ContextMenu.IsOpen=$false
        $window.UpdateLayout()
        if ($script:appearance -ne 'Windows' -or $window.Resources['ControlRadius'].TopLeft -ne 5 -or $script:glassEnabled) { throw 'Stile Windows non applicato.' }
        Save-LanguagePreference $script:activeLanguage.code
        if ((Read-AppearancePreference) -ne 'Windows') { throw 'Cambio lingua perde la scelta dello stile.' }
        Save-AppearancePreference 'MacOS'; Apply-Appearance (Read-AppearancePreference); $window.UpdateLayout()
        if ($window.Resources['PanelShadow'].Opacity -le 0 -or $window.Resources['ControlRadius'].TopLeft -ne 12 -or $ui.Hex.Text -ne $initialHex -or $ui.FolderName.Text -ne $initialFolder) { throw 'Stile macOS altera la selezione o non attiva le superfici rialzate.' }
        Save-AppearancePreference $initialAppearance; Apply-Appearance $initialAppearance
        $renameTestId=[Guid]::NewGuid().ToString('N').Substring(0,8)
        $testRenameOnly='UI-'+$renameTestId+' solo rinomina'
        $testRenameColor='UI-'+$renameTestId+' nome e colore'
        $renameTestFolder=Join-Path $root ('UI-'+$renameTestId+' nome originale')
        New-Item -ItemType Directory -Path $renameTestFolder -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $renameTestFolder 'contenuto.txt'),'UI contenuto',[Text.Encoding]::UTF8)
        $script:currentFolder=$renameTestFolder; $ui.FolderName.Text=$testRenameOnly
        $ui.RenameFolder.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        if (!(Test-Path -LiteralPath $script:currentFolder) -or (Test-Path -LiteralPath (Join-Path $script:currentFolder 'desktop.ini')) -or [IO.Path]::GetFileName($script:currentFolder) -ne $testRenameOnly) { throw 'Rinomina dalla matita non riuscita o icona cambiata.' }
        $ui.FolderName.Text=$testRenameColor; $ui.Hex.Text='#123456'
        $ui.Apply.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        if ([IO.Path]::GetFileName($script:currentFolder) -ne $testRenameColor -or !(Test-Path -LiteralPath (Join-Path $script:currentFolder 'desktop.ini')) -or [IO.File]::ReadAllText((Join-Path $script:currentFolder 'contenuto.txt')) -ne 'UI contenuto') { throw 'Nome e colore dalla stessa finestra non applicati.' }
        Restore-Folder $script:currentFolder
        $script:currentFolder=$Folder; $ui.FolderName.Text=[IO.Path]::GetFileName($Folder)
        $originalLanguage=$script:activeLanguage
        $originalHex=$ui.Hex.Text; $originalNames=@($script:collection | ForEach-Object { $_.Name }) -join '|'
        foreach ($localeEntry in $script:languageCatalog.languages) {
            $script:activeLanguage=$localeEntry; Apply-InterfaceLanguage; $window.UpdateLayout()
            if ($window.Title -ne $localeEntry.strings.change -or $ui.Apply.Content -ne $localeEntry.strings.apply -or $ui.LanguageName.Text -ne $localeEntry.nativeName) { throw ('Cambio lingua interfaccia errato: '+$localeEntry.code) }
            $expectedDirection=if ($localeEntry.rtl) { 'RightToLeft' } else { 'LeftToRight' }
            if ($window.FlowDirection.ToString() -ne $expectedDirection -or $ui.ColorPlane.FlowDirection.ToString() -ne 'LeftToRight' -or $ui.Hex.FlowDirection.ToString() -ne 'LeftToRight' -or $lensImage.FlowDirection.ToString() -ne 'LeftToRight') { throw ('Direzione interfaccia errata: '+$localeEntry.code) }
            if ($ui.Hex.Text -ne $originalHex -or (@($script:collection | ForEach-Object { $_.Name }) -join '|') -ne $originalNames) { throw 'Cambio lingua altera colore o nomi personali.' }
        }
        $script:activeLanguage=$originalLanguage; Apply-InterfaceLanguage; $window.UpdateLayout()

        $enter=[Windows.Input.MouseEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice,[Environment]::TickCount)
        $enter.RoutedEvent=[Windows.Input.Mouse]::MouseEnterEvent
        $ui.ColorPlane.RaiseEvent($enter)
        if ([Windows.Input.Mouse]::OverrideCursor -ne [Windows.Input.Cursors]::None -or $ui.HoverPoint.Visibility -ne 'Visible') { throw 'Freccia non nascosta nel selettore' }
        $leave=[Windows.Input.MouseEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice,[Environment]::TickCount)
        $leave.RoutedEvent=[Windows.Input.Mouse]::MouseLeaveEvent
        $ui.ColorPlane.RaiseEvent($leave)
        if ($null -ne [Windows.Input.Mouse]::OverrideCursor -or $ui.HoverPoint.Visibility -ne 'Collapsed') { throw 'Puntatore non ripristinato' }
        if ([DesktopPicker]::PixelToHex(0x00332211) -ne '#112233') { throw 'Conversione colore pipetta errata' }
        $pixels=[uint32[]]::new(225)
        for ($i=0;$i -lt 225;$i++) { $pixels[$i]=0x00332211 }
        $pixels[112]=0x00CC8844
        Set-LensImage ([DesktopPicker]::EncodeBitmap($pixels)) '#4488CC'
        if ($lensImage.Source.PixelWidth -ne 15 -or $lensHex.Text -ne '#4488CC') { throw 'Zoom pipetta errato' }
        $raw=[byte[]]::new(900); $raw[448]=0xCC; $raw[449]=0x88; $raw[450]=0x44
        Set-LensPixels $raw '#4488CC'
        $firstBitmap=$lensImage.Source
        Set-LensPixels $raw '#4488CC'
        $check=[byte[]]::new(900); $script:lensBitmap.CopyPixels($check,60,0)
        if (![Object]::ReferenceEquals($firstBitmap,$lensImage.Source) -or $check[448] -ne 0xCC -or $check[450] -ne 0x44) { throw 'Aggiornamento zoom riutilizzabile errato' }
        try { [DesktopPicker]::Begin() } finally { [DesktopPicker]::Stop() }
        $testPng=Join-Path $root 'ui-png.png'
        $testBitmap=[Drawing.Bitmap]::new(64,64)
        $testGraphics=[Drawing.Graphics]::FromImage($testBitmap)
        try { $testGraphics.Clear([Drawing.Color]::Transparent); $testGraphics.FillEllipse([Drawing.Brushes]::Blue,4,4,56,56); $testBitmap.Save($testPng,[Drawing.Imaging.ImageFormat]::Png) } finally { $testGraphics.Dispose(); $testBitmap.Dispose() }
        Set-PngPreview $testPng
        $pngSource=$ui.UploadedPreview.Source
        Apply-Appearance 'Windows'; Apply-Appearance 'MacOS'; Apply-Appearance $initialAppearance
        if ($script:pngSelection -ne $testPng -or ![Object]::ReferenceEquals($pngSource,$ui.UploadedPreview.Source)) { throw 'Cambio stile perde il PNG selezionato.' }
        if ($script:pngSelection -ne $testPng -or $ui.UploadedPreview.Visibility -ne 'Visible' -or $ui.Save.IsEnabled) { throw 'Anteprima PNG non attivata' }
        $ui.UseColor.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        if ($script:pngSelection -or $ui.UploadedPreview.Visibility -ne 'Collapsed' -or !$ui.Save.IsEnabled) { throw 'Ritorno alla modalita colore errato' }
        $w=$ui.ColorPlane.ActualWidth; $h=$ui.ColorPlane.ActualHeight
        if ($w -le 0 -or $h -le 0) { throw 'Tabella colore senza dimensioni' }
        $hit=$ui.ColorPlane.InputHitTest([Windows.Point]::new($w/2,$h/2))
        if ($hit -ne $ui.ColorPlane) { throw 'Tabella colore non cliccabile' }
        $ui.Hue.Value=0
        Set-PlanePoint 0 0
        if ($ui.Hex.Text -ne '#FFFFFF') { throw 'Selezione bianco errata' }
        Set-PlanePoint $w 0
        if ($ui.Hex.Text -ne '#FF0000') { throw 'Selezione colore pieno errata' }
        Set-PlanePoint ($w/2) ($h/2)
        if ($ui.Hex.Text -ne '#804040') { throw ('Selezione punto intermedio errata: '+$ui.Hex.Text) }
        Set-PlanePoint $w $h
        if ($ui.Hex.Text -ne '#000000') { throw 'Selezione nero errata' }
        Set-PlanePoint (-10) ($h+10)
        if ($ui.Hex.Text -ne '#000000') { throw 'Trascinamento fuori tabella errato' }
        if ((Get-HsvHex 0 1 1) -ne '#FF0000' -or (Get-HsvHex 120 1 1) -ne '#00FF00' -or (Get-HsvHex 240 1 1) -ne '#0000FF') { throw 'Selettore HSV errato' }
        $ui.Colors.SelectedIndex=0; $ui.ColorName.Text='Lavoro personale'; $ui.Hex.Text='#123ABC'
        $ui.Save.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        $saved=@(Read-Palette)
        if ($saved.Count -ne 4 -or $saved[0].Name -ne 'Lavoro personale' -or $saved[0].Hex -ne '#123ABC') { throw 'Modifica colore non riuscita' }
        $beforeNewCount=$script:collection.Count
        $ui.New.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)); if ($script:collection.Count -ne $beforeNewCount) { throw 'Nuovo crea una nuvola prima del salvataggio.' }; $ui.ColorName.Text='Nuovo'; $ui.Hex.Text='#ABCDEF'
        $ui.Save.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        if (@(Read-Palette).Count -ne 5) { throw 'Nuovo colore non salvato' }
        $ui.Delete.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        if (@(Read-Palette).Count -ne 4) { throw 'Eliminazione non riuscita' }
        $ui.Hex.Text='errore'; $ui.Save.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        if ($ui.Status.Visibility -ne 'Visible' -or @(Read-Palette).Count -ne 4) { throw 'Validazione HEX errata' }
        $ui.Colors.SelectedIndex=0; $ui.ColorName.Text=(T 'projects'); $ui.Hex.Text='#4A90E2'; $ui.Save.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        $bubbleItems=@($script:collection); $script:collection.Clear(); Update-Empty
        if ($ui.Colors.Visibility -ne 'Collapsed') { throw 'Contenitore dei colori visibile senza colori salvati.' }
        foreach ($bubbleItem in $bubbleItems) { $script:collection.Add($bubbleItem) }; Update-Empty; $ui.Colors.SelectedIndex=0
        Write-Output 'OK: tabella cliccabile, selezione precisa, estremi e trascinamento fuori bordo; palette e HEX.'
    } else { $ui.Colors.SelectedIndex=0 }
    $ui.Status.Visibility='Collapsed'; $ui.MainScroll.ScrollToHome()
    $window.UpdateLayout()
    [Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::ApplicationIdle)
    $width=[int]($ui.Root.ActualWidth+$ui.Root.Margin.Left+$ui.Root.Margin.Right)
    $height=[int]($ui.Root.ActualHeight+$ui.Root.Margin.Top+$ui.Root.Margin.Bottom)
    $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new($width,$height,96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($window)
    $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create($Preview)
    try { $encoder.Save($stream) } finally { $stream.Dispose(); $window.Close() }; exit
}
$application=[Windows.Application]::new()
$application.ShutdownMode=[Windows.ShutdownMode]::OnMainWindowClose
[void]$application.Run($window)
