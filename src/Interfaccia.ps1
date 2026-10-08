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
$dark=$true
if ($Theme -eq 'Dark') { $dark=$true }
elseif ($Theme -eq 'System') {
    try { $dark=(Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme) -eq 0 } catch {}
}
$tokens=@{Page='#F1F5FA';Card='#B3FFFFFF';Text='#18212F';Secondary='#526174';Line='#300D2440';Hover='#DCFFFFFF';Selected='#350078EA';Accent='#006BD6';AccentHover='#0068DF';OnAccent='#FFFFFF';Input='#A6FFFFFF'}
if ($dark) { $tokens=@{Page='#202832';Card='#493F5066';Text='#F6F8FC';Secondary='#BBC7D8';Line='#38FFFFFF';Hover='#65556B85';Selected='#554D9EFF';Accent='#65B5FF';AccentHover='#85C6FF';OnAccent='#071C31';Input='#503E5067'} }
$script:glassEnabled=$false
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Nova Prism • Olografica" Width="1280" Height="900" MinHeight="740" MinWidth="1060" ResizeMode="CanResize" WindowStartupLocation="CenterScreen" FontFamily="Segoe UI Variable, Segoe UI" FontSize="13" Background="#090D1A" Foreground="{DynamicResource Text}" UseLayoutRounding="True" SnapsToDevicePixels="True" WindowStyle="None">
 <Window.Resources>
  <Style TargetType="Button">
   <Setter Property="Background" Value="{DynamicResource Card}" /><Setter Property="Foreground" Value="{DynamicResource Text}" />
   <Setter Property="BorderBrush" Value="{DynamicResource Line}" /><Setter Property="BorderThickness" Value="1" />
   <Setter Property="Padding" Value="12,6" /><Setter Property="MinHeight" Value="34" />
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
    <Grid><Border Background="{TemplateBinding Background}" CornerRadius="{DynamicResource ControlRadius}" Effect="{DynamicResource ButtonShadow}" IsHitTestVisible="False" /><Border x:Name="Surface" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="14" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" /></Border></Grid>
    <ControlTemplate.Triggers>
     <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Background" Value="{DynamicResource Hover}" /></Trigger>
     <Trigger Property="IsPressed" Value="True"><Setter TargetName="Surface" Property="Opacity" Value="0.7" /></Trigger>
     <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Surface" Property="BorderBrush" Value="{DynamicResource Accent}" /></Trigger>
     <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Surface" Property="Opacity" Value="0.4" /></Trigger>
    </ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
   <Setter Property="Background" Value="{DynamicResource PrimaryFill}" /><Setter Property="Foreground" Value="{DynamicResource OnAccent}" /><Setter Property="BorderThickness" Value="0" />
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
    <Border x:Name="Surface" Background="{TemplateBinding Background}" CornerRadius="{DynamicResource ControlRadius}" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" /></Border>
    <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Background" Value="{DynamicResource AccentHover}" /></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="Surface" Property="Opacity" Value="0.75" /></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Surface" Property="BorderBrush" Value="{DynamicResource Text}" /><Setter TargetName="Surface" Property="BorderThickness" Value="2" /></Trigger></ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="TextBox">
   <Setter Property="Height" Value="34" />
   <Setter Property="Background" Value="{DynamicResource Input}" /><Setter Property="Foreground" Value="{DynamicResource Text}" /><Setter Property="CaretBrush" Value="{DynamicResource Text}" />
   <Setter Property="Padding" Value="10,6" /><Setter Property="BorderBrush" Value="{DynamicResource Line}" /><Setter Property="BorderThickness" Value="1" />
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TextBox"><Grid>
    <Border x:Name="Box" CornerRadius="{DynamicResource ControlRadius}" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" Padding="10,0">
     <ScrollViewer x:Name="PART_ContentHost" Padding="0" VerticalAlignment="Center" />
    </Border>
    
   </Grid><ControlTemplate.Triggers><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Accent}" /><Setter TargetName="Box" Property="BorderThickness" Value="2" /></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="ListBoxItem">
   <Setter Property="HorizontalContentAlignment" Value="Stretch" /><Setter Property="Padding" Value="5,4" /><Setter Property="Margin" Value="2,2" /><Setter Property="MaxWidth" Value="190" />
   <Setter Property="ToolTip" Value="{Binding Name}" />
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem"><Grid>
    <Border Background="{DynamicResource Card}" CornerRadius="{DynamicResource ControlRadius}" Effect="{DynamicResource ButtonShadow}" IsHitTestVisible="False" />
    <Border x:Name="Row" CornerRadius="{DynamicResource ControlRadius}" Background="{DynamicResource Card}" BorderBrush="{Binding Hex}" BorderThickness="1" Padding="{TemplateBinding Padding}"><ContentPresenter /></Border>
    </Grid><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Row" Property="Background" Value="{DynamicResource Hover}" /></Trigger><Trigger Property="IsSelected" Value="True"><Setter TargetName="Row" Property="Background" Value="{DynamicResource Selected}" /><Setter TargetName="Row" Property="BorderBrush" Value="{DynamicResource Accent}" /></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Row" Property="BorderBrush" Value="{DynamicResource Accent}" /></Trigger></ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="ScrollBar">
   <Setter Property="Width" Value="6" /><Setter Property="Background" Value="Transparent" />
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar">
    <Track x:Name="PART_Track" Orientation="Vertical" IsDirectionReversed="True" Minimum="{TemplateBinding Minimum}" Maximum="{TemplateBinding Maximum}" Value="{TemplateBinding Value}" ViewportSize="{TemplateBinding ViewportSize}">
     <Track.DecreaseRepeatButton><RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False" /></Track.DecreaseRepeatButton>
     <Track.IncreaseRepeatButton><RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False" /></Track.IncreaseRepeatButton>
     <Track.Thumb><Thumb><Thumb.Template><ControlTemplate TargetType="Thumb"><Border x:Name="ThumbSurface" Background="{DynamicResource Line}" CornerRadius="3" Margin="1,3" /><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ThumbSurface" Property="Background" Value="{DynamicResource Secondary}" /></Trigger></ControlTemplate.Triggers></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>
    </Track>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style x:Key="GlassScroll" TargetType="ScrollViewer">
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollViewer"><Grid>
    <Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="8" /></Grid.ColumnDefinitions>
    <ScrollContentPresenter x:Name="PART_ScrollContentPresenter" Content="{TemplateBinding Content}" ContentTemplate="{TemplateBinding ContentTemplate}" CanContentScroll="{TemplateBinding CanContentScroll}" Margin="{TemplateBinding Padding}" />
    <ScrollBar x:Name="PART_VerticalScrollBar" Grid.Column="1" Width="6" Orientation="Vertical" Visibility="{TemplateBinding ComputedVerticalScrollBarVisibility}" Maximum="{TemplateBinding ScrollableHeight}" ViewportSize="{TemplateBinding ViewportHeight}" Value="{Binding VerticalOffset, RelativeSource={RelativeSource TemplatedParent}, Mode=OneWay}" />
   </Grid></ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="ListBox"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBox"><ScrollViewer x:Name="PaletteScroll" Focusable="False" Padding="{TemplateBinding Padding}" CanContentScroll="False" VerticalScrollBarVisibility="Auto" Style="{StaticResource GlassScroll}"><ItemsPresenter /></ScrollViewer></ControlTemplate></Setter.Value></Setter></Style>
 </Window.Resources>
 <Grid><Border x:Name="PersonalBackground" IsHitTestVisible="False" /><Border x:Name="BackgroundShade" IsHitTestVisible="False" />
 <Viewbox Stretch="Fill" IsHitTestVisible="False" Opacity="0.48"><Canvas x:Name="HoloSky" Width="1280" Height="900" ClipToBounds="True" /></Viewbox><Grid IsHitTestVisible="False"><Grid.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#BD060D21" Offset="0" /><GradientStop Color="#870B1029" Offset="0.6" /><GradientStop Color="#B310102A" Offset="1" /></LinearGradientBrush></Grid.Background></Grid><Grid x:Name="Root" Margin="28,22,28,22"><Grid.RowDefinitions><RowDefinition Height="Auto" /><RowDefinition Height="*" /><RowDefinition Height="Auto" /></Grid.RowDefinitions><Grid Margin="0,0,0,6" x:Name="NovaHeader" Background="Transparent"><Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /><ColumnDefinition Width="Auto" /><ColumnDefinition Width="Auto" /><ColumnDefinition Width="Auto" /><ColumnDefinition Width="Auto" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions><StackPanel><TextBlock Text="N O V A  P R I S M" FontSize="34" FontWeight="Light" Foreground="#F2F7FF" /><TextBlock Text="C A R T E L L E C O L O R A T E" FontSize="10" Foreground="#97A8C8" Margin="0,4,0,0" /></StackPanel><Button x:Name="ChooseFolder" Grid.Column="1" Content="＋  Scegli cartella" Margin="0,0,10,0" Padding="14,8" VerticalAlignment="Center" BorderBrush="#546B7DF0" /><Button x:Name="LanguageButton" Grid.Column="2" VerticalAlignment="Center" Padding="9,6" ToolTip="{DynamicResource L_language}" AutomationProperties.Name="{DynamicResource L_language}" Margin="0,0,8,0"><StackPanel Orientation="Horizontal"><Viewbox Width="16" Height="16" Margin="0,0,7,0"><Canvas Width="24" Height="24"><Ellipse Width="22" Height="22" Canvas.Left="1" Canvas.Top="1" Stroke="{DynamicResource Text}" StrokeThickness="1.5" /><Ellipse Width="9" Height="22" Canvas.Left="7.5" Canvas.Top="1" Stroke="{DynamicResource Text}" StrokeThickness="1.5" /><Path Data="M1,12 L23,12 M3,6 L21,6 M3,18 L21,18" Stroke="{DynamicResource Text}" StrokeThickness="1.5" /></Canvas></Viewbox><TextBlock x:Name="LanguageName" /></StackPanel></Button><Button x:Name="PaletteTools" Grid.Column="3" Content="⋯" Padding="9,4" MinHeight="30" ToolTip="{DynamicResource L_collection}" Margin="0,0,8,0" VerticalAlignment="Center" /><Button x:Name="NovaMotion" Grid.Column="4" Content="◉  Effetti" Margin="0,0,8,0" VerticalAlignment="Center" ToolTip="Attiva o riduci le animazioni" /><Button x:Name="NovaClose" Grid.Column="6" Content="×" FontSize="22" Width="34" Padding="0" VerticalAlignment="Center" ToolTip="Chiudi Nova" /><Button x:Name="NovaMinimize" Grid.Column="5" Width="36" Height="34" Padding="0" Margin="0,0,6,0" VerticalAlignment="Center" ToolTip="Riduci a icona" AutomationProperties.Name="Riduci a icona"><Path Data="M0,0 L12,0" Stroke="{DynamicResource Text}" StrokeThickness="1.5" HorizontalAlignment="Center" VerticalAlignment="Center" /></Button></Grid><Grid Grid.Row="1"><Viewbox Stretch="Uniform" HorizontalAlignment="Center" VerticalAlignment="Center"><Canvas Width="1170" Height="640"><Ellipse Canvas.Left="330" Canvas.Top="78" Width="510" Height="410" IsHitTestVisible="False"><Ellipse.Fill><RadialGradientBrush><GradientStop Color="#266FDAD3" Offset="0" /><GradientStop Color="#158C7DDC" Offset="0.55" /><GradientStop Color="#008C7DDC" Offset="1" /></RadialGradientBrush></Ellipse.Fill></Ellipse><Canvas Width="1170" Height="640" IsHitTestVisible="False">
<Ellipse Canvas.Left="334" Canvas.Top="64" Width="500" Height="390" Stroke="#305CB7D7" StrokeThickness="1" StrokeDashArray="2 9" />
<Path Data="M309,140 L309,97 L352,97 M816,97 L859,97 L859,140 M309,427 L309,470 L352,470 M816,470 L859,470 L859,427" Stroke="#456EACC6" StrokeThickness="1.2" />
<Path Data="M292,280 L317,280 M852,280 L877,280 M584,54 L584,72" Stroke="#859FBAFF" StrokeThickness="1" />
<TextBlock Canvas.Left="341" Canvas.Top="10" Text="P R I S M   /   C O L O R   S T U D I O" FontSize="15" FontWeight="Light" Foreground="#DCEBFAFF" />
<TextBlock Canvas.Left="344" Canvas.Top="36" Text="Il tuo spazio, un colore alla volta." FontSize="11" Foreground="#A7B6C8E0" />
<TextBlock Canvas.Left="744" Canvas.Top="447" Text="{Binding Text,ElementName=Hex}" FontFamily="Consolas" FontSize="12" Foreground="#A0A7DDE9" />
<TextBlock Canvas.Left="8" Canvas.Top="118" Text="01 / COLORE" FontSize="10" Foreground="#ABC2DCEF" />
<TextBlock Canvas.Left="885" Canvas.Top="83" Text="02 / PERSONALIZZA" FontSize="10" Foreground="#ABC2DCEF" />
</Canvas><Border CornerRadius="36" BorderBrush="#222B4B77" BorderThickness="0" Background="Transparent" Grid.Column="1" Margin="0" Canvas.Left="245" Canvas.Top="0" Width="620" Height="640"><Grid Margin="0"><Grid.RowDefinitions><RowDefinition Height="0" /><RowDefinition Height="*" /><RowDefinition Height="0" /></Grid.RowDefinitions><TextBlock Text="01   /   IL TUO NUOVO MONDO" FontSize="10" FontWeight="SemiBold" Foreground="#93A3C2" Visibility="Collapsed" /><Grid x:Name="NovaStage" Grid.Row="1" IsHitTestVisible="False" ClipToBounds="True">
<Grid VerticalAlignment="Bottom" Height="110" Margin="0,0,0,160"><Ellipse Width="530" Height="66" Stroke="#526CACFC" StrokeThickness="1" /><Ellipse Width="430" Height="58" Stroke="#897E9BFA" StrokeThickness="1.5" /><Ellipse Width="360" Height="42" Stroke="#C180EFE2" StrokeThickness="2"><Ellipse.Effect><DropShadowEffect Color="#80EFE2" BlurRadius="22" ShadowDepth="0" Opacity="0.7" /></Ellipse.Effect></Ellipse><Ellipse Width="320" Height="40" Fill="{DynamicResource NovaAura}" /></Grid><Ellipse Width="520" Height="520" Fill="{DynamicResource NovaAura}" Opacity="0.9" />
<Ellipse Width="370" Height="176" Stroke="#55738AD1" StrokeThickness="1" RenderTransformOrigin="0.5,0.5" Visibility="Collapsed"><Ellipse.RenderTransform><RotateTransform Angle="-24" /></Ellipse.RenderTransform></Ellipse>
<Ellipse Width="390" Height="168" Stroke="#4266E3DD" StrokeThickness="1" RenderTransformOrigin="0.5,0.5" Visibility="Collapsed"><Ellipse.RenderTransform><RotateTransform Angle="29" /></Ellipse.RenderTransform></Ellipse>
<Ellipse Width="310" Height="310" Stroke="#263F587E" StrokeThickness="1" StrokeDashArray="2 8" Visibility="Collapsed" />
<Canvas x:Name="NovaStars" />
<Ellipse Width="224" Height="30" VerticalAlignment="Bottom" Margin="0,0,0,65"><Ellipse.Fill><RadialGradientBrush><GradientStop Color="#453BE3E0" Offset="0" /><GradientStop Color="#003BE3E0" Offset="1" /></RadialGradientBrush></Ellipse.Fill></Ellipse>
<TextBlock Text="PERSONALITÀ, IN ORBITA." HorizontalAlignment="Center" VerticalAlignment="Bottom" Margin="0,0,0,23" FontSize="10" Foreground="#7385A8" Visibility="Collapsed" />
</Grid><Border x:Name="ImageDrop" Height="430" ToolTip="{DynamicResource L_pngTitle}" CornerRadius="14" Background="Transparent" Margin="0,20,0,0" Grid.Row="1" Width="430" RenderTransformOrigin="0.5,0.5" VerticalAlignment="Top"><Border.RenderTransform><TransformGroup><SkewTransform AngleX="0" /><RotateTransform Angle="-5" /><TranslateTransform /></TransformGroup></Border.RenderTransform><Viewbox Margin="8"><Viewport3D Width="256" Height="256"><Viewport3D.Camera><PerspectiveCamera Position="0,0,2.8" LookDirection="0,0,-2.8" UpDirection="0,1,0" FieldOfView="36" /></Viewport3D.Camera><ModelVisual3D><ModelVisual3D.Content><Model3DGroup x:Name="FolderModel"><Model3DGroup.Transform><Transform3DGroup><RotateTransform3D><RotateTransform3D.Rotation><AxisAngleRotation3D x:Name="HoloTurn" Axis="0,1,0" Angle="0" /></RotateTransform3D.Rotation></RotateTransform3D><RotateTransform3D><RotateTransform3D.Rotation><AxisAngleRotation3D x:Name="FolderPitch" Axis="1,0,0" Angle="0" /></RotateTransform3D.Rotation></RotateTransform3D></Transform3DGroup></Model3DGroup.Transform><AmbientLight Color="#FFFFFF" /><GeometryModel3D><GeometryModel3D.Geometry><MeshGeometry3D Positions="-1,1,0 -1,-1,0 1,-1,0 1,1,0" TriangleIndices="0 1 2 0 2 3" TextureCoordinates="0,0 0,1 1,1 1,0" /></GeometryModel3D.Geometry><GeometryModel3D.Material><DiffuseMaterial><DiffuseMaterial.Brush><VisualBrush ViewboxUnits="Absolute" Viewbox="0,0,256,256"><VisualBrush.Visual><Grid Width="256" Height="256" FlowDirection="LeftToRight">
         <Path x:Name="FolderBack" Fill="#60A0E6" Data="M26,112 L26,69.68 Q26,60.48 37,60.48 L97,60.48 Q103,60.48 107,65.08 L123,80.72 Q126,84.4 133,84.4 L218,84.4 Q230,84.4 230,95.44 L230,112 Z" Stroke="#708FA5E0" StrokeThickness="0.6" />
         <Path x:Name="FolderFront" Fill="#4A90E2" Data="M30,103.72 L233,103.72 Q243,103.72 241,113.84 L225,196.64 Q223,208.6 210,208.6 L40,208.6 Q29,208.6 28,197.56 L20,114.76 Q19,103.72 30,103.72 Z" StrokeThickness="0.9"><Path.Effect><DropShadowEffect Color="#081321" Opacity="0.32" BlurRadius="17" ShadowDepth="5" Direction="270" /></Path.Effect><Path.Stroke><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#DCEFFFFF" Offset="0" /><GradientStop Color="#4080EFE2" Offset="0.55" /><GradientStop Color="#A8B4A4FF" Offset="1" /></LinearGradientBrush></Path.Stroke></Path>
         <Grid IsHitTestVisible="False" Visibility="{Binding Visibility,ElementName=FolderFront}"><Path Data="M31,104.64 L231,104.64 Q239,104.64 237,112.92 L236,121.2 L22,121.2 L22,114.76 Q21,104.64 31,104.64 Z"><Path.Fill><LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#30FFFFFF" Offset="0" /><GradientStop Color="#00FFFFFF" Offset="1" /></LinearGradientBrush></Path.Fill></Path><Path Data="M33,105.56 L230,105.56" Stroke="#65FFFFFF" StrokeThickness="1" /></Grid><Grid IsHitTestVisible="False" Visibility="{Binding Visibility,ElementName=FolderFront}">
<Path Data="M33,106 L231,106 Q238,106 236,116 L230,149 C160,123 99,153 24,137 L23,115 Q22,106 33,106 Z"><Path.Fill><LinearGradientBrush StartPoint="0,0" EndPoint="0.8,1"><GradientStop Color="#40FFFFFF" Offset="0" /><GradientStop Color="#00FFFFFF" Offset="1" /></LinearGradientBrush></Path.Fill></Path>
<Path Data="M31,119 L38,189 Q39,200 49,203" Stroke="#A0EEFFFF" StrokeThickness="0.9" StrokeStartLineCap="Round" StrokeEndLineCap="Round" />
<Path Data="M233,118 L222,189 Q220,202 209,205" Stroke="#65ABA0FF" StrokeThickness="1.2" StrokeStartLineCap="Round" StrokeEndLineCap="Round" />
<Path Data="M40,66 L90,66" Stroke="#A0FFFFFF" StrokeThickness="1.3" StrokeStartLineCap="Round" StrokeEndLineCap="Round" />
<Path Data="M47,185 L64,185 M47,189 L58,189" Stroke="#60FFFFFF" StrokeThickness="1" StrokeStartLineCap="Round" StrokeEndLineCap="Round" />
</Grid><Image x:Name="UploadedPreview" Visibility="Collapsed" Stretch="Uniform" Margin="8" /><Border x:Name="BadgePreview" Visibility="Collapsed" Width="64" Height="64" CornerRadius="32" Background="#F5F8FF" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,8,8"><TextBlock x:Name="BadgeGlyph" FontSize="38" FontFamily="Segoe UI Symbol" Foreground="#233755" HorizontalAlignment="Center" VerticalAlignment="Center" /></Border>
       </Grid></VisualBrush.Visual></VisualBrush></DiffuseMaterial.Brush></DiffuseMaterial></GeometryModel3D.Material></GeometryModel3D></Model3DGroup></ModelVisual3D.Content></ModelVisual3D></Viewport3D></Viewbox></Border>
       <StackPanel Grid.Row="2" Visibility="Collapsed"><TextBlock Text="Trascina una cartella qui. Il resto è immaginazione." FontSize="12" Foreground="#AAB9D6" TextWrapping="Wrap" Margin="0,0,0,14" /></StackPanel></Grid></Border><Border Canvas.Left="270" Canvas.Top="508" Width="560" Height="120" CornerRadius="16" Background="#CC0A1428" BorderBrush="#5083AECF" BorderThickness="1" IsHitTestVisible="False" /><StackPanel x:Name="ColorPage" Visibility="Visible" Width="540" Height="92" Canvas.Left="285" Canvas.Top="525"><TextBlock Text="PALETTE RAPIDA" FontSize="10" FontWeight="SemiBold" Foreground="#C1D2E7FA" Margin="6,0,0,0" /><Canvas x:Name="QuickColors" Width="540" Height="92" Background="Transparent" /></StackPanel><Border Canvas.Left="0" Canvas.Top="155" Width="260" Height="375" Padding="15" CornerRadius="12" BorderThickness="1" BorderBrush="#857D83DD"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#EB1E2340" Offset="0" /><GradientStop Color="#C511172D" Offset="1" /></LinearGradientBrush></Border.Background><Border.Effect><DropShadowEffect Color="#8172F4" BlurRadius="20" ShadowDepth="0" Opacity="0.22" /></Border.Effect><StackPanel x:Name="CustomPage" Visibility="Visible"><Button x:Name="BackToColors" Content="←  Torna ai colori" HorizontalAlignment="Left" Margin="0,0,0,18" Visibility="Collapsed" /><TextBlock Text="Colore" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,10" /><Grid Margin="0,0,0,12"><Border Background="{DynamicResource Card}" CornerRadius="{DynamicResource CardRadius}" Effect="{DynamicResource PanelShadow}" IsHitTestVisible="False" />
    <Border Background="{DynamicResource Card}" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="{DynamicResource CardRadius}" Padding="10">
     <Grid>
      <Grid.ColumnDefinitions><ColumnDefinition Width="*" /></Grid.ColumnDefinitions><StackPanel>
       <Grid Height="150" ClipToBounds="True" FlowDirection="LeftToRight">
        <Border x:Name="HueBase" Background="Red" CornerRadius="{DynamicResource ControlRadius}" />
        <Border CornerRadius="{DynamicResource ControlRadius}"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="White" Offset="0" /><GradientStop Color="#00FFFFFF" Offset="1" /></LinearGradientBrush></Border.Background></Border>
        <Border CornerRadius="{DynamicResource ControlRadius}"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#00000000" Offset="0" /><GradientStop Color="Black" Offset="1" /></LinearGradientBrush></Border.Background></Border>
        <Canvas x:Name="ColorPlane" Background="Transparent" Cursor="None" Focusable="True" AutomationProperties.Name="{DynamicResource L_planeName}" ToolTip="{DynamicResource L_planeHelp}" Height="150">
         <Ellipse x:Name="ColorPointer" Width="14" Height="14" Stroke="White" StrokeThickness="2" IsHitTestVisible="False"><Ellipse.Effect><DropShadowEffect ShadowDepth="0" BlurRadius="3" Opacity="0.8" /></Ellipse.Effect></Ellipse>
         <Grid x:Name="HoverPoint" Width="16" Height="16" IsHitTestVisible="False" Visibility="Collapsed"><Ellipse Margin="1" Stroke="Black" StrokeThickness="3" /><Ellipse Margin="1" Stroke="White" StrokeThickness="1" /><Ellipse Width="3" Height="3" Fill="White" Stroke="Black" StrokeThickness="1" /></Grid>
        </Canvas>
        <Rectangle Stroke="{DynamicResource Accent}" StrokeThickness="2" RadiusX="4" RadiusY="4" IsHitTestVisible="False"><Rectangle.Style><Style TargetType="Rectangle"><Setter Property="Visibility" Value="Collapsed" /><Style.Triggers><DataTrigger Binding="{Binding IsKeyboardFocused, ElementName=ColorPlane}" Value="True"><Setter Property="Visibility" Value="Visible" /></DataTrigger></Style.Triggers></Style></Rectangle.Style></Rectangle>
       </Grid>
       <Grid Margin="0,6,0,0" Height="24" FlowDirection="LeftToRight">
        <Border Height="10" VerticalAlignment="Center" CornerRadius="{DynamicResource ControlRadius}"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="Red" Offset="0" /><GradientStop Color="Yellow" Offset="0.1667" /><GradientStop Color="Lime" Offset="0.3333" /><GradientStop Color="Cyan" Offset="0.5" /><GradientStop Color="Blue" Offset="0.6667" /><GradientStop Color="Magenta" Offset="0.8333" /><GradientStop Color="Red" Offset="1" /></LinearGradientBrush></Border.Background></Border>
        <Slider x:Name="Hue" Minimum="0" Maximum="359.99" SmallChange="1" LargeChange="15" Background="Transparent" ToolTip="{DynamicResource L_hue}" AutomationProperties.Name="{DynamicResource L_hue}">
         <Slider.Template><ControlTemplate TargetType="Slider"><Track x:Name="PART_Track" Minimum="{TemplateBinding Minimum}" Maximum="{TemplateBinding Maximum}" Value="{TemplateBinding Value}"><Track.DecreaseRepeatButton><RepeatButton Command="Slider.DecreaseLarge" Opacity="0" /></Track.DecreaseRepeatButton><Track.IncreaseRepeatButton><RepeatButton Command="Slider.IncreaseLarge" Opacity="0" /></Track.IncreaseRepeatButton><Track.Thumb><Thumb Width="18" Height="22"><Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="White" BorderBrush="#66000000" BorderThickness="1" CornerRadius="{DynamicResource ControlRadius}" /></ControlTemplate></Thumb.Template></Thumb></Track.Thumb></Track></ControlTemplate></Slider.Template>
        </Slider>
       </Grid>
      </StackPanel>
      <StackPanel Grid.Column="0" Grid.Row="1" Margin="0,8,0,0">
       <TextBlock Text="{DynamicResource L_hex}" TextWrapping="Wrap" Foreground="{DynamicResource Secondary}" Margin="0,0,0,4" /><TextBox x:Name="Hex" FlowDirection="LeftToRight" Text="#4A90E2" FontFamily="Consolas" MaxLength="7" AutomationProperties.Name="{DynamicResource L_hex}" FontSize="14" Height="32" />
      </StackPanel>
     <Grid.RowDefinitions><RowDefinition Height="Auto" /><RowDefinition Height="Auto" /></Grid.RowDefinitions></Grid>
    </Border></Grid>
    <Button x:Name="Pick" ToolTip="Campiona qualsiasi pixel dello schermo" AutomationProperties.Name="{DynamicResource L_pick}" Padding="10,6" HorizontalAlignment="Stretch" Height="32" MinHeight="30" Margin="0,4,0,0"><StackPanel Orientation="Horizontal"><Viewbox Width="20" Height="20"><Path Width="24" Height="24" Stretch="Uniform" Fill="{DynamicResource Text}" Data="M 16,2 Q 17,1 18,2 L 22,6 Q 23,7 22,8 L 19,11 L 20,12 L 18,14 L 16,12 L 8,20 L 3,21 L 4,16 L 12,8 L 10,6 L 12,4 L 13,5 Z M 6,17 L 5.5,18.5 L 7,18 L 14.5,10.5 L 13,9 Z" /></Viewbox><TextBlock Text="  Campiona dallo schermo" VerticalAlignment="Center" FontSize="12" /></StackPanel></Button></StackPanel></Border><Border Canvas.Left="880" Canvas.Top="120" Width="290" Height="230" Padding="15" CornerRadius="12" BorderThickness="1" BorderBrush="#506C89AC"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#EB1E2340" Offset="0" /><GradientStop Color="#C511172D" Offset="1" /></LinearGradientBrush></Border.Background><Border.Effect><DropShadowEffect Color="#8172F4" BlurRadius="20" ShadowDepth="0" Opacity="0.22" /></Border.Effect><StackPanel x:Name="ImagePage" Visibility="Visible"><TextBlock Text="Immagine" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,8" /><TextBlock Text="Usa un PNG: una foto, un simbolo, un piccolo mondo. Puoi anche trascinarlo sull’anteprima." TextWrapping="Wrap" Foreground="{DynamicResource Secondary}" Margin="0,0,0,22" Visibility="Collapsed" /><Button x:Name="Upload" Content="↑  Carica PNG" Margin="0,4,0,8" Padding="12,6" HorizontalAlignment="Stretch" Height="40" /><Button x:Name="UseColor" Content="{DynamicResource L_use}" HorizontalAlignment="Stretch" Padding="12,6" Visibility="Collapsed" Margin="0,0,0,4" /><Button x:Name="EditImage" Content="Ritaglio e simboli" Margin="0,2,0,0" /><Button x:Name="SaveImageStyle" Content="Salva immagine nei miei stili" Margin="0,4,0,0" FontSize="11" /></StackPanel></Border><Border Canvas.Left="880" Canvas.Top="377" Width="290" Height="250" Padding="15" CornerRadius="12" BorderThickness="1" BorderBrush="#506C89AC"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#EB1E2340" Offset="0" /><GradientStop Color="#C511172D" Offset="1" /></LinearGradientBrush></Border.Background><Border.Effect><DropShadowEffect Color="#8172F4" BlurRadius="20" ShadowDepth="0" Opacity="0.22" /></Border.Effect><ScrollViewer x:Name="StylesPage" Visibility="Visible" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel><TextBlock Text="I tuoi stili" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,8" /><TextBlock Text="Colori salvati da ritrovare e riutilizzare." Foreground="{DynamicResource Secondary}" Margin="0,0,0,18" Visibility="Collapsed" /><TextBox x:Name="ColorName" AutomationProperties.Name="{DynamicResource L_name}" Margin="0,0,0,8" Height="30" /><Button x:Name="Save" MinWidth="112" Content="＋  Salva colore" VerticalAlignment="Bottom" Height="30" Margin="0,0,0,8" MinHeight="30" />
    <Grid x:Name="SearchRow" Visibility="Collapsed" Margin="0,0,0,8"><Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="130" /></Grid.ColumnDefinitions><TextBox x:Name="SearchText" AutomationProperties.Name="{DynamicResource L_search}" /><ComboBox x:Name="CollectionFilter" Grid.Column="1" Margin="6,0,0,0" VerticalContentAlignment="Center" AutomationProperties.Name="{DynamicResource L_collection}" /></Grid>
    <StackPanel x:Name="RecentArea" Visibility="Collapsed" Margin="0,0,0,8"><TextBlock Text="{DynamicResource L_recent}" FontSize="11" Foreground="{DynamicResource BackdropText}" /><WrapPanel x:Name="RecentColors" /></StackPanel>
    <ListBox x:Name="Colors" MaxHeight="130" Padding="0" Background="Transparent" Foreground="{DynamicResource Text}" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled" VirtualizingPanel.IsVirtualizing="True" VirtualizingPanel.VirtualizationMode="Recycling" Margin="0,0,0,8">
     <ListBox.ItemsPanel><ItemsPanelTemplate><WrapPanel /></ItemsPanelTemplate></ListBox.ItemsPanel><ListBox.ItemTemplate><DataTemplate><StackPanel Width="62" Height="74"><Viewbox Height="42" Margin="4,0,4,3"><Grid Width="256" Height="256"><Path Data="M24,88 L24,68 Q24,56 36,56 L96,56 Q102,56 107,62 L122,78 Q126,81 134,81 L220,81 Q232,81 232,94 L232,200 Q232,214 218,214 L38,214 Q24,214 24,200 Z" Fill="{Binding Hex}" Opacity="0.65" /><Path Data="M32,94 L229,94 Q240,94 238,106 L230,204 Q229,218 215,218 L41,218 Q27,218 26,204 L19,107 Q17,94 32,94 Z" Fill="{Binding Hex}" /></Grid></Viewbox><TextBlock Text="{Binding DisplayName}" TextAlignment="Center" TextTrimming="CharacterEllipsis" /></StackPanel></DataTemplate></ListBox.ItemTemplate></ListBox>
    <TextBlock x:Name="Empty" Text="{DynamicResource L_empty}" TextWrapping="Wrap" Foreground="{DynamicResource BackdropText}" Margin="0,0,0,8" Visibility="Collapsed" />
   <WrapPanel x:Name="ImageStyles" Margin="0,12,0,0" /></StackPanel></ScrollViewer></Border></Canvas></Viewbox></Grid><Grid Grid.Row="2" Margin="0,0,0,0" Height="118"><Grid.RowDefinitions><RowDefinition Height="Auto" /><RowDefinition Height="*" /></Grid.RowDefinitions><Grid Width="380" HorizontalAlignment="Center" Grid.Row="0"><Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions><TextBox x:Name="FolderName" MaxLength="255" AutomationProperties.Name="{DynamicResource L_folderName}" /><Button x:Name="RenameFolder" Grid.Column="1" ToolTip="{DynamicResource L_renameFolder}" AutomationProperties.Name="{DynamicResource L_renameFolder}" Margin="6,0,0,0" Padding="9,5"><Viewbox Width="16" Height="16"><Path Data="M16,3 L21,8 L8,21 L3,21 L3,16 Z M14,5 L19,10 M3,16 L8,21" Stroke="{DynamicResource Text}" StrokeThickness="1.8" Fill="Transparent" /></Viewbox></Button></Grid>
  <Button x:Name="Apply" Content="Applica alla cartella   →" ToolTip="{DynamicResource L_applyHelp}" Style="{StaticResource Primary}" Height="50" FontSize="15" Grid.Row="1" Width="370" HorizontalAlignment="Center" Margin="0,10,0,0" />
  <Button x:Name="Undo" Content="{DynamicResource L_undo}" Visibility="Collapsed" Margin="0,10,150,0" Grid.Row="1" HorizontalAlignment="Right" /><TextBlock x:Name="StudioState" Text="Una cartella. Infinite possibilità." Foreground="{DynamicResource Secondary}" VerticalAlignment="Center" TextWrapping="Wrap" Margin="0,0,20,0" FontSize="11" Width="285" HorizontalAlignment="Left" Grid.Row="1" /></Grid><Border Grid.Row="1" VerticalAlignment="Bottom" HorizontalAlignment="Center" Background="{DynamicResource Card}" Padding="14,9" CornerRadius="14" Visibility="{Binding Visibility, ElementName=Status}"><TextBlock x:Name="Status" TextWrapping="Wrap" MaxWidth="340" Visibility="Collapsed" Foreground="{DynamicResource Text}" /></Border><Canvas Visibility="Collapsed"><Button x:Name="AppearanceButton" Margin="0,0,6,0" Padding="9,6" AutomationProperties.Name="{DynamicResource L_appearance}"><StackPanel Orientation="Horizontal"><TextBlock x:Name="AppearanceName" FontSize="12" /><Path Data="M0,0 L4,4 L8,0" Stroke="{DynamicResource Text}" StrokeThickness="1.4" Width="8" Height="4" Margin="6,0,0,0" VerticalAlignment="Center" /></StackPanel></Button><Button x:Name="UpdateAvailable" Visibility="Collapsed" Width="32" Padding="7" Margin="0,0,6,0" ToolTip="{DynamicResource L_downloadUpdate}" AutomationProperties.Name="{DynamicResource L_downloadUpdate}"><Viewbox Width="16" Height="16"><Path Data="M12,3 L12,15 M7,10 L12,15 L17,10 M4,18 L4,21 L20,21 L20,18" Stroke="{DynamicResource Text}" StrokeThickness="1.7" Width="24" Height="24" /></Viewbox></Button><Button x:Name="Delete" Visibility="Collapsed" /><ScrollViewer x:Name="MainScroll" /><Button x:Name="CustomColor" Content="↗  Esplora il colore" Margin="0,10,0,0" HorizontalContentAlignment="Left" /><Button x:Name="SaveCurrentStyle" Content="＋  Salva il tuo stile" Margin="0,6,0,0" HorizontalContentAlignment="Left" FontSize="11" /><Button x:Name="ColorTab" Grid.Column="0" Content="Precisione" Margin="0,0,5,0" Padding="8,8" /><Button x:Name="ImageTab" Grid.Column="1" Content="Immagine" Margin="0,0,5,0" Padding="8,8" /><Button x:Name="StylesTab" Grid.Column="2" Content="Libreria" Margin="0,0,5,0" Padding="8,8" /><Button x:Name="New" Content="Nuovo stile" Margin="0,0,0,8" Padding="9,4" MinHeight="30" Visibility="Collapsed" /><Button x:Name="SearchToggle" Content="⌕" FontSize="19" Padding="8,2" MinHeight="30" Margin="0,0,0,8" ToolTip="{DynamicResource L_search}" Visibility="Collapsed" /></Canvas></Grid></Grid>
</Window>
'@
$reader=New-Object Xml.XmlNodeReader $xaml
$window=[Windows.Markup.XamlReader]::Load($reader)
$ui=@{}
foreach ($id in @('FolderModel','FolderPitch','NovaMinimize','HoloTurn','HoloSky','NovaStage','NovaStars','NovaMotion','NovaClose','NovaHeader','ChooseFolder','ColorTab','ImageTab','StylesTab','ColorPage','ImagePage','StylesPage','CustomPage','QuickColors','CustomColor','BackToColors','SaveCurrentStyle','EditImage','StudioState','SaveImageStyle','ImageStyles','PersonalBackground','BackgroundShade','UpdateAvailable','ImageDrop','Root','MainScroll','FolderName','HueBase','ColorPlane','ColorPointer','Hue','FolderBack','FolderFront','Hex','ColorName','Save','Colors','New','Delete','Empty','Apply','Status','Upload','UseColor','UploadedPreview','Pick','HoverPoint','LanguageButton','LanguageName','RenameFolder','AppearanceButton','AppearanceName','PaletteTools','Undo','SearchToggle','SearchRow','SearchText','CollectionFilter','RecentArea','RecentColors','BadgePreview','BadgeGlyph')) { $ui[$id]=$window.FindName($id) }
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
    foreach ($c in @(@{Name='Aurora';Hex='#80EFE2'},@{Name='Prisma';Hex='#A89BFF'},@{Name='Plasma';Hex='#FF75B8'})) { $script:collection.Add([pscustomobject]$c) }
}
foreach ($entry in $script:collection) { $entry | Add-Member -NotePropertyName DisplayName -NotePropertyValue $(if ($entry.Favorite) { '★ '+$entry.Name } else { $entry.Name }) -Force }; $ui.Colors.ItemsSource=$script:collection
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
    $script:pngRequest=$null; $script:pngSelection=$null; $ui.UploadedPreview.Visibility='Collapsed'
    $ui.FolderFront.Visibility='Visible'; $ui.FolderBack.Visibility='Visible'
    $ui.UseColor.Visibility='Collapsed'; $ui.Save.IsEnabled=$true; $ui.Upload.Content=(T 'upload')
    $c=[Drawing.ColorTranslator]::FromHtml($HexValue)
    foreach($part in @('FolderFront','FolderBack')){
        $fill=[Windows.Media.LinearGradientBrush]::new();$fill.StartPoint=[Windows.Point]::new(0,0);$fill.EndPoint=[Windows.Point]::new(0,1)
        $tones=if($part -eq 'FolderFront'){@(0.16,0,-0.10)}else{@(-0.16,-0.22,-0.28)}
        for($i=0;$i -lt 3;$i++){$tone=Get-FolderShade $c $tones[$i];$fill.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Color]::FromArgb($(if($part -eq 'FolderFront'){255}else{255}),$tone.R,$tone.G,$tone.B),@(0,0.55,1)[$i]))}
        $fill.Freeze();$ui[$part].Fill=$fill
    }
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
function Show-Status([string]$Text) { if ($script:toastTimer) { $script:toastTimer.Stop() }; $ui.Status.Text=Translate-Error $Text; $ui.Status.Visibility='Visible' }
function Update-Empty { $ui.Empty.Visibility='Collapsed'; $ui.Colors.Visibility='Visible'; if ($script:collection.Count -eq 0) { $ui.Empty.Visibility='Visible'; $ui.Colors.Visibility='Collapsed' } }
function Save-Colors {
    foreach ($entry in $script:collection) { $entry | Add-Member -NotePropertyName DisplayName -NotePropertyValue $(if ($entry.Favorite) { '★ '+$entry.Name } else { $entry.Name }) -Force }
    $items=@($script:collection | ForEach-Object { [pscustomobject]@{Name=$_.Name;Hex=$_.Hex;Favorite=[bool]$_.Favorite;Group=[string]$_.Group} })
    $json=ConvertTo-Json -InputObject $items -Depth 4; $tmp=$palettePath+'.tmp'
    [IO.File]::WriteAllText($tmp,$json,[Text.Encoding]::UTF8); Move-Item -LiteralPath $tmp -Destination $palettePath -Force
    if (!$Preview) { Update-Menu }; Update-Empty; if (Get-Command Refresh-CollectionChoices -ErrorAction SilentlyContinue) { Refresh-CollectionChoices }; $ui.Colors.Items.Refresh()
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
    if ($c -and !$UITest -and [Windows.SystemParameters]::ClientAreaAnimation) { $container=$ui.Colors.ItemContainerGenerator.ContainerFromItem($c); if ($container) { $animation=[Windows.Media.Animation.DoubleAnimation]::new(0.65,1,[Windows.Duration]::new([TimeSpan]::FromMilliseconds(120))); $animation.FillBehavior='Stop'; $container.BeginAnimation([Windows.UIElement]::OpacityProperty,$animation) } }
    if ($c) { $ui.ColorName.Text=$c.Name; $ui.Hex.Text=$c.Hex; $ui.Save.Content=(T 'saveChanges'); $ui.Delete.Visibility='Collapsed' }
    else { $ui.Save.Content=(T 'save'); $ui.Delete.Visibility='Collapsed' }; $ui.Status.Visibility='Collapsed'
})
$ui.New.Add_Click({ $ui.Colors.SelectedIndex=-1; $ui.ColorName.Clear(); [void]$ui.ColorName.Focus(); $ui.Status.Visibility='Collapsed' })
$ui.Save.Add_Click({ try {
    $v=Valid-Hex; $n=$ui.ColorName.Text.Trim(); if (!$n) { $n=$v }; $idx=$script:collection.IndexOf($ui.Colors.SelectedItem)
    $favorite=if ($idx -ge 0) { [bool]$script:collection[$idx].Favorite } else { $false }; $item=[pscustomobject]@{Name=$n;Hex=$v;Favorite=$favorite;Group=$(if ($idx -ge 0) { [string]$script:collection[$idx].Group } else { [string]$script:filterGroup });DisplayName=$(if ($favorite) { '★ '+$n } else { $n })}
    if ($idx -ge 0) { $script:collection[$idx]=$item } else { $script:collection.Add($item); $idx=$script:collection.Count-1 }
    Save-Colors; $ui.Colors.SelectedItem=$item; $ui.ColorName.Text=$n; $ui.Save.Content=(T 'saveChanges'); $ui.Delete.Visibility='Collapsed'; $ui.Status.Visibility='Collapsed'; Show-Toast (T 'saved')
} catch { Show-Status $_.Exception.Message } })
$ui.Delete.Add_Click({ try { $idx=$script:collection.IndexOf($ui.Colors.SelectedItem); if ($idx -ge 0) { $script:collection.RemoveAt($idx); Save-Colors; $ui.ColorName.Clear() } } catch { Show-Status $_.Exception.Message } })
function Order-Colors {
    $ordered=@($script:collection | Where-Object { $_.Favorite })+@($script:collection | Where-Object { !$_.Favorite })
    $script:collection.Clear(); foreach ($entry in $ordered) { $script:collection.Add($entry) }
}
function Move-Color($Item,[int]$Destination) {
    $old=$script:collection.IndexOf($Item); if ($old -lt 0 -or $Destination -lt 0 -or $Destination -ge $script:collection.Count) { return }
    if ([bool]$Item.Favorite -ne [bool]$script:collection[$Destination].Favorite) { return }
    $script:collection.Move($old,$Destination); Save-Colors; $ui.Colors.SelectedItem=$Item
}
function Import-Colors([string]$Path) {
    $raw=Get-Content -LiteralPath $Path -Raw -Encoding UTF8; $document=$raw | ConvertFrom-Json
    $entries=if ($raw.TrimStart().StartsWith('[')) { @($document) } elseif ($document.schemaVersion -eq 1 -and $null -ne $document.colors) { @($document.colors) } else { throw (T 'paletteError') }
    $validated=@(); foreach ($entry in $entries) {
        if ($entry.Name -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.Name) -or $entry.Hex -isnot [string] -or $entry.Hex -notmatch '^#[0-9A-Fa-f]{6}$' -or ($null -ne $entry.Favorite -and $entry.Favorite -isnot [bool]) -or ($null -ne $entry.Group -and $entry.Group -isnot [string])) { throw (T 'paletteError') }
        $validated += [pscustomobject]@{Name=$entry.Name;Hex=$entry.Hex.ToUpperInvariant();Favorite=[bool]$entry.Favorite;Group=[string]$entry.Group}
    }
    $previous=@($script:collection)
    try {
        foreach ($entry in $validated) { if (!@($script:collection | Where-Object { $_.Name -ceq $entry.Name -and $_.Hex -eq $entry.Hex -and [string]$_.Group -ceq [string]$entry.Group }).Count) { $script:collection.Add($entry) } }
        Order-Colors; Save-Colors
    } catch { $script:collection.Clear(); foreach ($entry in $previous) { $script:collection.Add($entry) }; throw }
}
function Export-Colors([string]$Path) {
    $colors=@($script:collection | ForEach-Object { [pscustomobject]@{Name=$_.Name;Hex=$_.Hex;Favorite=[bool]$_.Favorite;Group=[string]$_.Group} })
    [IO.File]::WriteAllText($Path,([pscustomobject]@{schemaVersion=1;colors=$colors} | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($true))
}
$ui.Colors.Add_ContextMenuOpening({ param($sender,$e)
    $container=[Windows.Controls.ItemsControl]::ContainerFromElement($ui.Colors,$e.OriginalSource)
    if (!$container) { $e.Handled=$true; return }; $ui.Colors.SelectedItem=$container.DataContext
    $menu=New-ModernMenu $ui.Colors
    foreach ($action in @('editColor','renameColor','favorite','moveEarlier','moveLater','assignCollection','delete')) {
        $item=[Windows.Controls.MenuItem]::new(); $item.Header=T $action; $item.Tag=$action
        if ($action -eq 'favorite') { $item.IsCheckable=$true; $item.IsChecked=[bool]$container.DataContext.Favorite }
        $item.Add_Click({ param($sender,$e) try {
            $selected=$ui.Colors.SelectedItem; if (!$selected) { return }
            switch ($sender.Tag) {
                'editColor' { [void]$ui.Hex.Focus(); $ui.Hex.SelectAll() }
                'renameColor' { [void]$ui.ColorName.Focus(); $ui.ColorName.SelectAll() }
                'favorite' { $selected | Add-Member -NotePropertyName Favorite -NotePropertyValue (![bool]$selected.Favorite) -Force; Order-Colors; Save-Colors; $ui.Colors.SelectedItem=$selected }
                'moveEarlier' { Move-Color $selected ($script:collection.IndexOf($selected)-1) }
                'moveLater' { Move-Color $selected ($script:collection.IndexOf($selected)+1) }
                'assignCollection' { $group=Show-AdvancedText (T 'collectionName') ([string]$selected.Group); if ($null -ne $group) { $selected | Add-Member -NotePropertyName Group -NotePropertyValue $group -Force; Save-Colors; Refresh-CollectionChoices } }
                'delete' { $ui.Delete.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }
            }
        } catch { Show-Status $_.Exception.Message } }); $null=$menu.Items.Add($item)
    }
    $ui.Colors.ContextMenu=$menu
})
$ui.Colors.ContextMenu=[Windows.Controls.ContextMenu]::new()
$ui.Colors.AllowDrop=$true
$ui.Colors.Add_PreviewMouseLeftButtonDown({ param($sender,$e) $script:dragStart=$e.GetPosition($ui.Colors); $origin=[Windows.Controls.ItemsControl]::ContainerFromElement($ui.Colors,$e.OriginalSource); $script:dragItem=if ($origin) { $origin.DataContext } else { $null } })
$ui.Colors.Add_PreviewMouseMove({ param($sender,$e)
    if ($e.LeftButton -ne [Windows.Input.MouseButtonState]::Pressed -or !$script:dragStart) { return }
    $point=$e.GetPosition($ui.Colors)
    if ([Math]::Abs($point.X-$script:dragStart.X)+[Math]::Abs($point.Y-$script:dragStart.Y) -lt 8) { return }
    $entry=$script:dragItem; $script:dragStart=$null; $script:dragItem=$null
    if ($entry) { $data=[Windows.DataObject]::new('CartelleColorate.Color',$entry); [void][Windows.DragDrop]::DoDragDrop($ui.Colors,$data,[Windows.DragDropEffects]::Move) }
})
$ui.Colors.Add_Drop({ param($sender,$e) try {
    if (!$e.Data.GetDataPresent('CartelleColorate.Color')) { return }; $entry=$e.Data.GetData('CartelleColorate.Color')
    $container=[Windows.Controls.ItemsControl]::ContainerFromElement($ui.Colors,$e.OriginalSource)
    if ($container) { Move-Color $entry ($script:collection.IndexOf($container.DataContext)); $e.Handled=$true }
} catch { Show-Status $_.Exception.Message } })
Update-ProBanner
$ui.PaletteTools.Add_Click({
    $menu=New-ModernMenu $ui.PaletteTools
    foreach ($action in @('presets','folderTools','iconTools','libraryTools','visualSettings','background')) {
        $item=[Windows.Controls.MenuItem]::new(); $item.Header=T $action; $item.Tag=$action
        if ($action -in @('folderTools','iconTools','libraryTools')) { Add-GroupedActions $item $action; $null=$menu.Items.Add($item); continue }
        if ($action -eq 'editPng') { $item.IsEnabled=[bool]$script:pngSelection }; if ($action -eq 'singleFolder') { $item.IsEnabled=$script:batchTargets.Count -gt 1 }
        $item.Add_Click({ param($sender,$e) try {
            if ($sender.Tag -notin @('importColors','exportColors')) { Invoke-AdvancedAction ([string]$sender.Tag); return }
            $dialog=if ($sender.Tag -eq 'importColors') { [Microsoft.Win32.OpenFileDialog]::new() } else { [Microsoft.Win32.SaveFileDialog]::new() }; $dialog.Filter='JSON (*.json)|*.json'; $dialog.DefaultExt='.json'
            if ($dialog.ShowDialog($window)) { if ($sender.Tag -eq 'importColors') { Import-Colors $dialog.FileName } else { Export-Colors $dialog.FileName } }
        } catch { Show-Status $_.Exception.Message } }); $null=$menu.Items.Add($item)
    }; $proItem=[Windows.Controls.MenuItem]::new(); $proItem.Header='Strumenti'; $proItem.Add_Click({ try { Show-ProTools } catch { Show-Status $_.Exception.Message } }); $null=$menu.Items.Add($proItem); $ui.PaletteTools.ContextMenu=$menu; $menu.IsOpen=$true
})
function Set-PngPreview([string]$Path) {
    $script:pngRequest=$null
    $image=[Windows.Media.Imaging.BitmapImage]::new()
    $image.BeginInit(); $image.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $image.DecodePixelWidth=256; $image.UriSource=[Uri]::new($Path); $image.EndInit(); $image.Freeze()
    $ui.UploadedPreview.Source=$image; $ui.UploadedPreview.Visibility='Visible'
    $ui.FolderFront.Visibility='Collapsed'; $ui.FolderBack.Visibility='Collapsed'
    $script:pngSelection=$Path; $ui.UseColor.Visibility='Visible'; $ui.Save.IsEnabled=$false
    $ui.Upload.Content=(T 'changePng'); $ui.Status.Visibility='Collapsed'
}
$ui.Upload.Add_Click({
    $dialog=[Microsoft.Win32.OpenFileDialog]::new()
    $dialog.Filter=(T 'pngFilter'); $dialog.Title=(T 'pngTitle')
    if ($dialog.ShowDialog($window)) { try { Start-PngPreview $dialog.FileName } catch { Show-Status (T 'pngError') } }
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
function Update-UndoButton {
    $ui.Undo.Visibility='Collapsed'
    try { $record=Get-Content -LiteralPath (Join-Path $root 'ultima-modifica.json') -Raw -Encoding UTF8 | ConvertFrom-Json; if ($record.Current -eq $script:currentFolder -or @($record.Batch | Where-Object { $_.Current -eq $script:currentFolder }).Count) { $ui.Undo.Visibility='Visible' } } catch {}
}
function Edit-SelectedFolder([bool]$OnlyName) {
    $hexValue=$null; if (!$OnlyName -and !$script:pngSelection) { $hexValue=Valid-Hex }
    $prepared=$null; if (!$OnlyName) { $prepared=Get-PreparedIcon $script:badge }
    if (!$OnlyName -and $script:batchTargets.Count -gt 1) { Invoke-FolderBatch $script:batchTargets $hexValue $prepared; Update-UndoButton; return }
    $before=New-FolderUndo $script:currentFolder
    $script:currentFolder=Rename-Folder $script:currentFolder $ui.FolderName.Text
    $before.Current=$script:currentFolder; Save-FolderUndo $before
    $ui.FolderName.Text=[IO.Path]::GetFileName($script:currentFolder); $ui.FolderName.ToolTip=$script:currentFolder
    Update-UndoButton
    if (!$OnlyName) { if ($prepared) { Set-FolderPng $script:currentFolder $prepared } else { Set-FolderColor $script:currentFolder $hexValue } }; Save-FolderActivity $before $(if ($OnlyName) { 'folderRenamed' } else { 'apply' })
}
$ui.RenameFolder.Add_Click({ try { Edit-SelectedFolder $true; Show-Status (T 'folderRenamed') } catch { Show-Status $_.Exception.Message } })
$ui.Apply.Add_Click({ try { Edit-SelectedFolder $false; Update-UndoButton; $ui.StudioState.Text='Fatto. La tua cartella ha un nuovo carattere.'; Show-Toast 'Cartella aggiornata.' } catch { Show-Status $_.Exception.Message } })
$ui.Undo.Add_Click({ try { $script:currentFolder=Undo-FolderEdit $script:currentFolder; $ui.FolderName.Text=if ($script:batchTargets.Count -gt 1) { T 'folderCount' @($script:batchTargets.Count) } else { [IO.Path]::GetFileName($script:currentFolder) }; $ui.FolderName.ToolTip=$script:currentFolder; Update-UndoButton } catch { Show-Status $_.Exception.Message } })
Update-UndoButton
function Set-GlassSurface([bool]$Transparent) {
    $page=[Windows.Media.LinearGradientBrush]::new(); $page.StartPoint=[Windows.Point]::new(0,0); $page.EndPoint=[Windows.Point]::new(1,1)
    $colors=if ($dark) { if ($Transparent) { @('#603F404B','#42232630','#603B3244') } else { @('#FF353640','#FF252831','#FF35303F') } } else { if ($Transparent) { @('#85FFFFFF','#55EAF3FF','#72F3E9FF') } else { @('#FFF6F8FD','#FFECF2FA','#FFF4EDF9') } }
    for ($i=0; $i -lt 3; $i++) { $page.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($colors[$i]),$i/2.0)) }
    if ($Transparent) { foreach ($stop in $page.GradientStops) { $color=$stop.Color; $color.A=[byte][Math]::Min(255,[Math]::Round($color.A*$script:glassOpacity/55)); $stop.Color=$color } }; $page.Freeze(); $window.Resources['Page']=$page
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
function Set-StudioTheme {
    if([Windows.SystemParameters]::HighContrast){return}
    foreach($pair in @{Page='#060B1B';Card='#B5161B32';Text='#EFF4FF';Secondary='#AAB9D6';Line='#38465779';Hover='#27364F';Selected='#324863';Accent='#80EFE2';AccentHover='#C0FFF2';OnAccent='#081B26';Input='#131E33'}.GetEnumerator()){$window.Resources[$pair.Key]=Brush $pair.Value}
    $hero=[Windows.Media.LinearGradientBrush]::new();$hero.StartPoint=[Windows.Point]::new(0,0);$hero.EndPoint=[Windows.Point]::new(1,1)
    foreach($pair in @(@('#13152D',0),@('#101E32',0.5),@('#112737',1))){$hero.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($pair[0]),$pair[1]))}
    $window.Resources['StudioHeroFill']=$hero;$window.Resources['StudioHeroText']=Brush '#AAB9D6'
    $primary=[Windows.Media.LinearGradientBrush]::new();$primary.StartPoint=[Windows.Point]::new(0,0);$primary.EndPoint=[Windows.Point]::new(1,1)
    $primary.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#80EFE2'),0));$primary.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#A89BFF'),1));$window.Resources['PrimaryFill']=$primary
    $window.Resources['ControlRadius']=[Windows.CornerRadius]::new(14);$window.Resources['CardRadius']=[Windows.CornerRadius]::new(22)
    foreach($name in @('PanelShadow','ButtonShadow')){$shadow=[Windows.Media.Effects.DropShadowEffect]::new();$shadow.Color=[Windows.Media.Colors]::Black;$shadow.Opacity=0.1;$shadow.BlurRadius=14;$shadow.ShadowDepth=4;$window.Resources[$name]=$shadow}
    $window.Title='Nova Prism'
}

function Apply-Appearance([ValidateSet('Windows','MacOS')][string]$Style) {
    $script:appearance=$Style; $mac=$Style -eq 'MacOS'
    $colors=if ($mac) { if ($dark) { @{Page='#292C35';Card='#704A5060';Text='#F6F8FC';Secondary='#C0C6D4';Line='#55FFFFFF';Hover='#80556378';Selected='#605799DA';Accent='#74BCFF';AccentHover='#92CDFF';OnAccent='#092039';Input='#603B4353'} } else { @{Page='#F1F5FA';Card='#B3FFFFFF';Text='#18212F';Secondary='#526174';Line='#300D2440';Hover='#DCFFFFFF';Selected='#350078EA';Accent='#006BD6';AccentHover='#0068DF';OnAccent='#FFFFFF';Input='#A6FFFFFF'} } } else { if ($dark) { @{Page='#202020';Card='#2B2B2B';Text='#F5F5F5';Secondary='#ADADAD';Line='#414141';Hover='#383838';Selected='#344452';Accent='#60CDFF';AccentHover='#78D5FF';OnAccent='#00304A';Input='#333333'} } else { @{Page='#F3F3F3';Card='#FFFFFF';Text='#1A1A1A';Secondary='#666666';Line='#E4E4E4';Hover='#F0F0F0';Selected='#E8F0FB';Accent='#0067C0';AccentHover='#005AAB';OnAccent='#FFFFFF';Input='#FAFAFA'} } }
    foreach ($key in $colors.Keys) { $window.Resources[$key]=[Windows.Media.BrushConverter]::new().ConvertFromString($colors[$key]) }
    $window.Resources['ControlRadius']=[Windows.CornerRadius]::new($(if ($mac) { 12 } else { 5 }))
    $window.Resources['CardRadius']=[Windows.CornerRadius]::new($(if ($mac) { 20 } else { 8 }))
    foreach ($name in @('PanelShadow','ButtonShadow')) {
        $shadow=[Windows.Media.Effects.DropShadowEffect]::new(); $shadow.Color=[Windows.Media.Colors]::Black; $shadow.Direction=270
        $shadow.ShadowDepth=if ($name -eq 'PanelShadow') { 5 } else { 2 }; $shadow.BlurRadius=if ($name -eq 'PanelShadow') { 16 } else { 7 }
        $shadow.Opacity=if ($mac) { if ($dark) { 0.32 } else { 0.16 } } else { 0 }; if ($mac) { $shadow.Opacity*=(0.5+$script:glassDepth/100); $shadow.BlurRadius*=(0.5+$script:glassDepth/100) }; $shadow.Freeze(); $window.Resources[$name]=$shadow
    }
    if ($mac) {
        foreach ($surface in @('Card','Line','PrimaryFill')) {
            $gradient=[Windows.Media.LinearGradientBrush]::new(); $gradient.StartPoint=[Windows.Point]::new(0,0); $gradient.EndPoint=[Windows.Point]::new(0,1)
            $stops=switch ($surface) { 'Card' { if ($dark) { @('#9A454C5A','#45303644') } else { @('#ECFFFFFF','#80FFFFFF') } } 'Line' { if ($dark) { @('#A0FFFFFF','#28FFFFFF') } else { @('#FFFFFFFF','#350D2440') } } 'PrimaryFill' { if ($dark) { @('#A1D3FF','#69B4FA') } else { @('#0070DF','#0056BC') } } }
            $gradient.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($stops[0]),0)); $gradient.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($stops[1]),1)); $gradient.Freeze(); $window.Resources[$surface]=$gradient
        }
        Set-GlassSurface $false
    } else { $window.Resources['PrimaryFill']=$window.Resources['Accent'] }
    $ui.AppearanceName.Text=if ($mac) { T 'macStyle' } else { T 'windowsStyle' }
    $ui.AppearanceButton.ToolTip=(T 'appearance')+': '+$ui.AppearanceName.Text
    Set-AppearanceMaterial
    Set-StudioTheme; Update-ModernMenuResources; Apply-PersonalBackground; Apply-AccessibleAppearance
}
$ui.AppearanceButton.Add_Click({
    $menu=New-ModernMenu $ui.AppearanceButton
    foreach ($style in @('Windows','MacOS')) {
        $item=[Windows.Controls.MenuItem]::new(); $item.Header=if ($style -eq 'Windows') { T 'windowsStyle' } else { T 'macStyle' }; $item.Tag=$style; $item.IsCheckable=$true; $item.IsChecked=$script:appearance -eq $style
        $item.Add_Click({ param($sender,$e) try { Save-AppearancePreference ([string]$sender.Tag); Apply-Appearance ([string]$sender.Tag) } catch { Show-Status $_.Exception.Message } }); $null=$menu.Items.Add($item)
    }
    $ui.AppearanceButton.ContextMenu=$menu; $menu.IsOpen=$true
})
Initialize-AdvancedInterface
Initialize-ProductInterface
Initialize-VisualInterface
Initialize-AdaptiveLayout
Initialize-ComfortInterface
$ui.Colors.ContextMenu=New-ModernMenu $ui.Colors
Order-Colors
Apply-Appearance (Read-AppearancePreference)
$window.Add_SourceInitialized({
    $hwnd=[Windows.Interop.WindowInteropHelper]::new($window).Handle
    $corner=2; [void][FluentWindow]::DwmSetWindowAttribute($hwnd,33,[ref]$corner,4)
    $mode=[int]$dark; [void][FluentWindow]::DwmSetWindowAttribute($hwnd,20,[ref]$mode,4)
    Set-AppearanceMaterial
    Set-StudioTheme; Update-ModernMenuResources; Apply-PersonalBackground
})

function Apply-InterfaceLanguage {
    Set-LanguageResources $window
    Set-LanguageResources $lens
    Sync-UpdateButton
    $ui.AppearanceButton.ToolTip=(T 'appearance')+': '+$ui.AppearanceName.Text
    if ($script:advancedReady) { Refresh-CollectionChoices }
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

Set-PickerFromHex '#80EFE2'; Update-Empty
function Show-StudioPage([string]$Page) {
    foreach($name in @('ColorPage','CustomPage','ImagePage','StylesPage')){$ui[$name].Visibility='Visible'}
    $window.UpdateLayout();Update-Pointer
    if($Page -eq 'Styles'){Refresh-StudioImageStyles;$ui.ColorName.Focus()|Out-Null}
}

function Refresh-StudioImageStyles {
    $ui.ImageStyles.Children.Clear()
    foreach($preset in @(Read-ProductList 'preset.json' | Where-Object {$_.Png -and [IO.File]::Exists($_.Png)})){
        $button=[Windows.Controls.Button]::new();$button.Width=145;$button.Margin=[Windows.Thickness]::new(0,0,8,8);$button.Tag=$preset;$panel=[Windows.Controls.StackPanel]::new()
        $image=[Windows.Controls.Image]::new();$image.Height=70;$image.Stretch='Uniform';$bitmap=[Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption='OnLoad';$bitmap.UriSource=[Uri]$preset.Png;$bitmap.EndInit();$bitmap.Freeze();$image.Source=$bitmap;$panel.Children.Add($image)|Out-Null
        $label=[Windows.Controls.TextBlock]::new();$label.Text=$preset.Name;$label.TextTrimming='CharacterEllipsis';$label.TextAlignment='Center';$label.Margin=[Windows.Thickness]::new(0,6,0,0);$panel.Children.Add($label)|Out-Null;$button.Content=$panel
        $button.Add_Click({param($sender)try{Apply-CompletePreset $sender.Tag;$ui.StudioState.Text='Stile caricato. Applica per confermare.'}catch{Show-Status $_.Exception.Message}});$ui.ImageStyles.Children.Add($button)|Out-Null
    }
}
$ui.SaveImageStyle.Add_Click({
    try{if(!$script:pngSelection){throw 'Carica prima un PNG.'};$name=[IO.Path]::GetFileNameWithoutExtension($script:pngSelection);$null=Save-CompletePreset $name (Valid-Hex) $script:pngSelection $script:badge $script:badgeHex;Show-StudioPage 'Styles';Show-Toast 'Stile immagine salvato.'}catch{Show-Status $_.Exception.Message}
})
$ui.ColorTab.Add_Click({Show-StudioPage 'Color'})
$ui.ImageTab.Add_Click({Show-StudioPage 'Image'})
$ui.StylesTab.Add_Click({Show-StudioPage 'Styles'})
$ui.CustomColor.Add_Click({Show-StudioPage 'Custom'})
$ui.BackToColors.Add_Click({Show-StudioPage 'Color'})
$ui.SaveCurrentStyle.Add_Click({Show-StudioPage 'Styles';$ui.ColorName.Focus()|Out-Null})
$ui.EditImage.Add_Click({try{if(!$script:pngSelection){Show-Status 'Carica prima un PNG.';return};Invoke-AdvancedAction 'editPng'}catch{Show-Status $_.Exception.Message}})
$ui.ChooseFolder.Add_Click({
    $dialog=[Windows.Forms.FolderBrowserDialog]::new();$dialog.Description='Scegli la cartella da personalizzare';$dialog.SelectedPath=$script:currentFolder
    try{if($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){Select-ProductFolders @($dialog.SelectedPath);$ui.StudioState.Text='Cartella selezionata. Scegli il suo stile.'}}finally{$dialog.Dispose()}
})
function Update-DockPointer([double]$pointerX,[bool]$inside){
    $scales=[Collections.Generic.List[double]]::new();$extra=0.0
    for($i=0;$i -lt $ui.QuickColors.Children.Count;$i++){
        $distance=[Math]::Abs($pointerX-(33+$i*58));$weight=0.0
        if($inside -and $distance -lt 135){$weight=(1+[Math]::Cos([Math]::PI*$distance/135))/2}
        $scale=1+0.34*$weight;$scales.Add($scale);$extra+=50*($scale-1)
    }
    $offset=-$extra/2
    for($i=0;$i -lt $ui.QuickColors.Children.Count;$i++){
        $item=$ui.QuickColors.Children[$i];$scale=$scales[$i];$added=50*($scale-1)
        $shift=$offset+$added/2;$offset+=$added
        $item.RenderTransformOrigin=[Windows.Point]::new(0.5,1)
        [Windows.Controls.Panel]::SetZIndex($item,[int](100*($scale-1)))
        foreach($entry in @(@($item.RenderTransform.Children[0],[Windows.Media.ScaleTransform]::ScaleXProperty,$scale),@($item.RenderTransform.Children[0],[Windows.Media.ScaleTransform]::ScaleYProperty,$scale),@($item.RenderTransform.Children[1],[Windows.Media.TranslateTransform]::XProperty,$shift),@($item.RenderTransform.Children[1],[Windows.Media.TranslateTransform]::YProperty,(-12*($scale-1)/0.34)))){
            $animation=[Windows.Media.Animation.DoubleAnimation]::new([double]$entry[2],[Windows.Duration]::new([TimeSpan]::FromMilliseconds(95)))
            $ease=[Windows.Media.Animation.CubicEase]::new();$ease.EasingMode='EaseOut';$animation.EasingFunction=$ease
            $entry[0].BeginAnimation($entry[1],$animation)
        }
    }
}
function Set-DockHover($active){
    $index=$ui.QuickColors.Children.IndexOf($active)
    Update-DockPointer (33+$index*58) ($index -ge 0)
}
function Invoke-DockBounce($item){
    if($script:novaReduced){return}
    $baseline=if($item.IsMouseOver){-9.0}else{0.0}
    $motion=[Windows.Media.Animation.DoubleAnimationUsingKeyFrames]::new()
    foreach($frame in @(@(0,$baseline),@(120,($baseline-13)),@(250,$baseline),@(330,($baseline-4)),@(440,$baseline))){
        $key=[Windows.Media.Animation.SplineDoubleKeyFrame]::new();$key.Value=$frame[1];$key.KeyTime=[Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::FromMilliseconds($frame[0]));$key.KeySpline=[Windows.Media.Animation.KeySpline]::new(0.25,0.1,0.25,1);$motion.KeyFrames.Add($key)|Out-Null
    }
    $item.RenderTransform.Children[1].BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$motion)
}
function Update-OrbSelection($selected){
    foreach($orb in $ui.QuickColors.Children){
        $active=$orb -eq $selected
        $orb.Content.Children[2].Opacity=$(if($active){1}else{0})
        $orb.Content.Children[3].Opacity=$(if($active){1}else{0})
    }
}
$orbPositions=@(@(0,22),@(58,22),@(116,22),@(174,22),@(232,22),@(290,22),@(348,22),@(406,22),@(464,22))
$orbChoices=@(@('Aurora','#80EFE2'),@('Prisma','#A89BFF'),@('Plasma','#FF75B8'),@('Solar','#FFB05D'),@('Ion','#68BCFF'),@('Corallo','#FF766C'),@('Ice','#D5EDFF'),@('Obsidian','#7587A9'),@('Pulse','#C2FA60'))
for($i=0;$i -lt $orbChoices.Count;$i++){
    $choice=$orbChoices[$i];$button=[Windows.Controls.Button]::new();$button.Width=58;$button.Height=58;$button.Tag=$choice;$button.Padding=[Windows.Thickness]::new(0);$button.Background=[Windows.Media.Brushes]::Transparent;$button.BorderThickness=[Windows.Thickness]::new(0);$button.ToolTip=$choice[0]+' '+$choice[1]
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></ControlTemplate>')
    $group=[Windows.Media.TransformGroup]::new();$group.Children.Add([Windows.Media.ScaleTransform]::new(1,1));$group.Children.Add([Windows.Media.TranslateTransform]::new());$button.RenderTransform=$group;$button.RenderTransformOrigin=[Windows.Point]::new(0.5,0.5)
    $panel=[Windows.Controls.Grid]::new();$panel.Width=50;$panel.Height=58
    $color=[Windows.Media.ColorConverter]::ConvertFromString($choice[1]);$fill=[Windows.Media.LinearGradientBrush]::new();$fill.StartPoint=[Windows.Point]::new(0,0);$fill.EndPoint=[Windows.Point]::new(1,1)
    $fill.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Color]::FromRgb([byte]($color.R+((255-$color.R)*0.18)),[byte]($color.G+((255-$color.G)*0.18)),[byte]($color.B+((255-$color.B)*0.18))),0));$fill.GradientStops.Add([Windows.Media.GradientStop]::new($color,1))
    $swatch=[Windows.Controls.Border]::new();$swatch.CornerRadius=[Windows.CornerRadius]::new(10);$swatch.Background=[Windows.Media.SolidColorBrush]::new($color);$swatch.BorderBrush=Brush '#45FFFFFF';$swatch.BorderThickness=[Windows.Thickness]::new(1);$panel.Children.Add($swatch)|Out-Null
    $rim=[Windows.Controls.Border]::new();$rim.CornerRadius=[Windows.CornerRadius]::new(9);$rim.Margin=[Windows.Thickness]::new(2);$rim.BorderBrush=Brush '#18FFFFFF';$rim.BorderThickness=[Windows.Thickness]::new(1);$rim.IsHitTestVisible=$false;$panel.Children.Add($rim)|Out-Null
    $halo=[Windows.Controls.Border]::new();$halo.CornerRadius=[Windows.CornerRadius]::new(13);$halo.Margin=[Windows.Thickness]::new(-3);$halo.BorderBrush=Brush '#EEF4F8FF';$halo.BorderThickness=[Windows.Thickness]::new(1.5);$halo.Opacity=0;$halo.IsHitTestVisible=$false;$panel.Children.Add($halo)|Out-Null
    $check=[Windows.Controls.Border]::new();$check.Width=19;$check.Height=19;$check.CornerRadius=[Windows.CornerRadius]::new(10);$check.Background=Brush '#FFEEF8FF';$check.HorizontalAlignment='Right';$check.VerticalAlignment='Bottom';$check.Margin=[Windows.Thickness]::new(0,0,4,4);$check.Opacity=0;$check.IsHitTestVisible=$false
    $glyph=[Windows.Controls.TextBlock]::new();$glyph.Text=[char]0x2713;$glyph.FontSize=12;$glyph.FontWeight='Bold';$glyph.Foreground=Brush '#FF142039';$glyph.HorizontalAlignment='Center';$glyph.VerticalAlignment='Center';$check.Child=$glyph;$panel.Children.Add($check)|Out-Null
    $label=[Windows.Controls.TextBlock]::new();$label.Text=$choice[0];$label.FontSize=10;$label.Foreground=Brush '#DDEAF2FF';$label.HorizontalAlignment='Center';$label.VerticalAlignment='Bottom';$label.Margin=[Windows.Thickness]::new(0,0,0,0);$label.IsHitTestVisible=$false;$panel.Children.Add($label)|Out-Null
    $panel.Children[0].Height=32;$panel.Children[0].VerticalAlignment='Top';$panel.Children[1].Height=28;$panel.Children[1].VerticalAlignment='Top';$panel.Children[2].Height=38;$panel.Children[2].VerticalAlignment='Top';$check.VerticalAlignment='Top';$check.Margin=[Windows.Thickness]::new(0,10,4,0);$button.Content=$panel
    [Windows.Controls.Canvas]::SetLeft($button,($orbPositions[$i][0]+4));[Windows.Controls.Canvas]::SetTop($button,$orbPositions[$i][1])
    
    
    $button.Add_Click({param($sender)Invoke-DockBounce $sender;Update-OrbSelection $sender;$ui.Colors.SelectedIndex=-1;$ui.ColorName.Text=$sender.Tag[0];$ui.Hex.Text=$sender.Tag[1];$ui.StudioState.Text='Colore '+$sender.Tag[0]+'. Applica per confermare.'})
    $ui.QuickColors.Children.Add($button)|Out-Null
}

$script:dockPointerClock=[Diagnostics.Stopwatch]::StartNew()
$ui.QuickColors.Add_MouseMove({param($sender,$eventArgs)
    if($script:dockPointerClock.ElapsedMilliseconds -lt 20){return}
    $script:dockPointerClock.Restart();$point=$eventArgs.GetPosition($ui.QuickColors)
    Update-DockPointer $point.X $true
})
$ui.QuickColors.Add_MouseLeave({Update-DockPointer 0 $false})
$script:novaReduced=([string](Read-ProductSetting 'novaReducedMotion' 'false')) -eq 'true'
if(![Windows.SystemParameters]::ClientAreaAnimation -or [Windows.SystemParameters]::HighContrast){$script:novaReduced=$true}
$script:novaMouseClock=[Diagnostics.Stopwatch]::StartNew()
function Update-NovaAura {
    if($ui.Hex.Text -notmatch '^#[0-9A-Fa-f]{6}$'){return}
    $color=[Windows.Media.ColorConverter]::ConvertFromString($ui.Hex.Text)
    $aura=[Windows.Media.RadialGradientBrush]::new();$aura.RadiusX=0.5;$aura.RadiusY=0.5
    $aura.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Color]::FromArgb(80,$color.R,$color.G,$color.B),0))
    $aura.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Color]::FromArgb(30,$color.R,$color.G,$color.B),0.5))
    $aura.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Color]::FromArgb(0,$color.R,$color.G,$color.B),1));$aura.Freeze();$window.Resources['NovaAura']=$aura
    
}
function Set-NovaMotion([bool]$Reduced) {
    $script:novaReduced=$Reduced;$ui.HoloTurn.Angle=0;$transform=$ui.ImageDrop.RenderTransform.Children[2]
    $transform.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$null)
    $ui.ImageDrop.RenderTransform.Children[1].Angle=0;$transform.X=0;$transform.Y=0
    $ui.NovaMotion.Content=if($Reduced){'◉  Effetti ridotti'}else{'◉  Effetti attivi'}
    $ui.NovaMotion.ToolTip=if($Reduced){'Attiva il movimento della cartella e le transizioni'}else{'Riduci il movimento mantenendo lo stile Nova'}
    if(!$Reduced){
        $float=[Windows.Media.Animation.DoubleAnimation]::new(0,-12,[Windows.Duration]::new([TimeSpan]::FromSeconds(3)))
        $float.AutoReverse=$true;$float.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever
        $transform.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$float)
    }
    for($i=0;$i -lt $ui.QuickColors.Children.Count;$i++){$drift=$ui.QuickColors.Children[$i].RenderTransform.Children[1];$drift.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$null);$drift.Y=0;if($false){$motion=[Windows.Media.Animation.DoubleAnimation]::new(0,-4,[Windows.Duration]::new([TimeSpan]::FromSeconds(2.8+$i*0.15)));$motion.AutoReverse=$true;$motion.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever;$drift.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$motion)}}
    foreach($entry in @('Image','Styles','Custom')){$ui[$entry+'Page'].BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$ui[$entry+'Page'].Opacity=1}
}
$random=[Random]::new(17)
for($i=0;$i -lt 40;$i++){
    $star=[Windows.Shapes.Ellipse]::new();$star.Width=if($i%7 -eq 0){3}else{1.5};$star.Height=$star.Width;$star.Fill=Brush '#D0DDFF';$star.Opacity=0.15+($i%5)*0.07
    [Windows.Controls.Canvas]::SetLeft($star,$random.Next(0,390));[Windows.Controls.Canvas]::SetTop($star,$random.Next(20,440));$ui.NovaStars.Children.Add($star)|Out-Null
}
$ui.NovaClose.Add_Click({$window.Close()})
$ui.NovaMinimize.Add_Click({$window.WindowState=[Windows.WindowState]::Minimized})
$ui.NovaHeader.Add_MouseLeftButtonDown({param($sender,$e)
    $source=$e.OriginalSource;$buttonAncestor=$false
    while($source -and $source -ne $ui.NovaHeader){if($source -is [Windows.Controls.Button]){$buttonAncestor=$true;break};if($source -is [Windows.Media.Visual]){$source=[Windows.Media.VisualTreeHelper]::GetParent($source)}else{break}}
    if(!$buttonAncestor -and $e.ButtonState -eq 'Pressed'){$window.DragMove()}
})
$ui.NovaMotion.Add_Click({Set-NovaMotion (!$script:novaReduced);Save-AppSetting 'novaReducedMotion' $script:novaReduced})
function Set-FolderRotation([double]$yaw,[double]$pitch){
    $ui.HoloTurn.Angle=$yaw%360;$ui.FolderPitch.Angle=[Math]::Max(-75,[Math]::Min(75,$pitch))
}
$script:folderDragging=$false
$ui.ImageDrop.Cursor=[Windows.Input.Cursors]::Hand
$ui.ImageDrop.ToolTip='Trascina per ruotare · Doppio clic per ripristinare'
$ui.ImageDrop.Add_MouseLeftButtonDown({param($sender,$e)
    if($e.ClickCount -eq 2){Set-FolderRotation 0 0;$e.Handled=$true;return}
    $script:folderDragging=$true;$script:folderDragStart=$e.GetPosition($ui.ImageDrop)
    $script:folderYawStart=$ui.HoloTurn.Angle;$script:folderPitchStart=$ui.FolderPitch.Angle
    $ui.ImageDrop.CaptureMouse()|Out-Null;$e.Handled=$true
})
$ui.ImageDrop.Add_MouseMove({param($sender,$e)
    if(!$script:folderDragging){return}
    $point=$e.GetPosition($ui.ImageDrop)
    Set-FolderRotation ($script:folderYawStart+($point.X-$script:folderDragStart.X)*0.7) ($script:folderPitchStart+($point.Y-$script:folderDragStart.Y)*0.5)
    $e.Handled=$true
})
$ui.ImageDrop.Add_MouseLeftButtonUp({param($sender,$e)$script:folderDragging=$false;$ui.ImageDrop.ReleaseMouseCapture();$e.Handled=$true})
$ui.ImageDrop.Add_LostMouseCapture({$script:folderDragging=$false})
$ui.Hex.Add_TextChanged({
    Update-NovaAura
    $matching=$null
    foreach($orb in $ui.QuickColors.Children){if($orb.Tag[1] -eq $ui.Hex.Text){$matching=$orb;break}}
    Update-OrbSelection $matching
})
$ui.Apply.Add_Click({
    if(!$script:novaReduced -and [IO.File]::Exists((Join-Path $script:currentFolder 'desktop.ini'))){$ui.NovaStage.BeginAnimation([Windows.UIElement]::OpacityProperty,[Windows.Media.Animation.DoubleAnimation]::new(0.4,1,[Windows.Duration]::new([TimeSpan]::FromMilliseconds(500))))}
})
$window.Add_Closed({Set-NovaMotion $true})
Update-NovaAura;Set-NovaMotion $script:novaReduced
$ui.Apply.Content='Applica alla cartella  →'
$nebulaPath=Join-Path $PSScriptRoot 'Nebulosa.png'
if([IO.File]::Exists($nebulaPath)){
    $bitmap=[Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption='OnLoad';$bitmap.UriSource=[Uri]$nebulaPath;$bitmap.EndInit();$bitmap.Freeze()
    $background=[Windows.Media.ImageBrush]::new($bitmap);$background.Stretch='UniformToFill';$ui.HoloSky.Background=$background
}
if($script:collection.Count -eq 0){
    foreach($pair in @(@('Aurora','#80EFE2'),@('Prisma','#A89BFF'),@('Plasma','#FF75B8'))){$script:collection.Add([pscustomobject]@{Name=$pair[0];DisplayName=$pair[0];Hex=$pair[1]})};Save-Colors;Update-Empty
}
Refresh-StudioImageStyles

if(!$Preview){$ui.Root.BeginAnimation([Windows.UIElement]::OpacityProperty,[Windows.Media.Animation.DoubleAnimation]::new(0.1,1,[Windows.Duration]::new([TimeSpan]::FromMilliseconds(400))))}

Add-Type -TypeDefinition @"
using System;using System.Collections.Generic;
public static class NovaPolygon {
 public static int[] Triangulate(double[] xy){
  int n=xy.Length/2;var ring=new List<int>();double area=0;
  for(int i=0;i<n;i++){int j=(i+1)%n;area+=xy[2*i]*xy[2*j+1]-xy[2*j]*xy[2*i+1];}
  if(area>0){for(int i=0;i<n;i++)ring.Add(i);}else{for(int i=n-1;i>=0;i--)ring.Add(i);}
  var result=new List<int>();int guard=n*n;
  while(ring.Count>2 && guard-->0){bool cut=false;
   for(int k=0;k<ring.Count;k++){int a=ring[(k+ring.Count-1)%ring.Count],b=ring[k],c=ring[(k+1)%ring.Count];
    if(Cross(xy,a,b,c)<=0.000001)continue;bool inside=false;
    foreach(int q in ring){if(q==a||q==b||q==c)continue;if(Cross(xy,a,b,q)>=-0.000001&&Cross(xy,b,c,q)>=-0.000001&&Cross(xy,c,a,q)>=-0.000001){inside=true;break;}}
    if(inside)continue;result.Add(a);result.Add(c);result.Add(b);ring.RemoveAt(k);cut=true;break;
   }if(!cut)throw new Exception("Unable to close folder geometry");
  }return result.ToArray();
 }
 static double Cross(double[] p,int a,int b,int c){return (p[2*b]-p[2*a])*(p[2*c+1]-p[2*a+1])-(p[2*b+1]-p[2*a+1])*(p[2*c]-p[2*a]);}
}
"@
$outline=[Windows.Media.Geometry]::Combine($ui.FolderFront.Data,$ui.FolderBack.Data,[Windows.Media.GeometryCombineMode]::Union,$null).GetFlattenedPathGeometry(0.35,[Windows.Media.ToleranceType]::Absolute)
$frontMesh=[Windows.Media.Media3D.MeshGeometry3D]::new();$backMesh=[Windows.Media.Media3D.MeshGeometry3D]::new();$sideMesh=[Windows.Media.Media3D.MeshGeometry3D]::new()
foreach($figure in $outline.Figures){
    $points=[Collections.Generic.List[Windows.Point]]::new();$points.Add($figure.StartPoint)
    foreach($segment in $figure.Segments){foreach($point in $segment.Points){if(($point-$points[$points.Count-1]).Length -gt 0.001){$points.Add($point)}}}
    if(($points[0]-$points[$points.Count-1]).Length -lt 0.001){$points.RemoveAt($points.Count-1)}
    $xy=[Collections.Generic.List[double]]::new();$baseIndex=$frontMesh.Positions.Count
    foreach($point in $points){$xy.Add($point.X);$xy.Add($point.Y);$frontMesh.Positions.Add([Windows.Media.Media3D.Point3D]::new(($point.X/128-1),(1-$point.Y/128),0));$backMesh.Positions.Add([Windows.Media.Media3D.Point3D]::new(($point.X/128-1),(1-$point.Y/128),-0.12));$frontMesh.TextureCoordinates.Add([Windows.Point]::new($point.X/256,$point.Y/256));$frontMesh.Normals.Add([Windows.Media.Media3D.Vector3D]::new(0,0,1));$backMesh.Normals.Add([Windows.Media.Media3D.Vector3D]::new(0,0,-1))}
    $triangles=[NovaPolygon]::Triangulate($xy.ToArray())
    for($i=0;$i -lt $triangles.Length;$i+=3){foreach($j in @(0,1,2)){$frontMesh.TriangleIndices.Add($baseIndex+$triangles[$i+$j])};foreach($j in @(2,1,0)){$backMesh.TriangleIndices.Add($baseIndex+$triangles[$i+$j])}}
    for($i=0;$i -lt $points.Count;$i++){
        $a=$points[$i];$b=$points[($i+1)%$points.Count];$index=$sideMesh.Positions.Count
        foreach($vertex in @(@($a,0),@($a,-0.12),@($b,-0.12),@($b,0))){$point=$vertex[0];$sideMesh.Positions.Add([Windows.Media.Media3D.Point3D]::new(($point.X/128-1),(1-$point.Y/128),$vertex[1]))}
        foreach($triangle in @(0,1,2,0,2,3)){$sideMesh.TriangleIndices.Add($index+$triangle)}
    }
}
$frontModel=$ui.FolderModel.Children[1];$script:originalFlatMesh=$frontModel.Geometry
$surface=[Windows.Media.Media3D.MaterialGroup]::new();$script:solidSurface=[Windows.Media.Media3D.DiffuseMaterial]::new((Brush '#80EFE2'));$surface.Children.Add($script:solidSurface);$surface.Children.Add($frontModel.Material)
$textureBrush=$frontModel.Material.Brush
$textureBrush.ViewportUnits=[Windows.Media.BrushMappingMode]::Absolute;$textureBrush.Viewport=[Windows.Rect]::new(0,0,1,1)
$frontModel.Geometry=$frontMesh;$frontModel.Material=$surface
$script:folderSide=[Windows.Media.Media3D.GeometryModel3D]::new($sideMesh,[Windows.Media.Media3D.DiffuseMaterial]::new((Brush '#59AFA8')));$script:folderSide.BackMaterial=$script:folderSide.Material
$script:folderRear=[Windows.Media.Media3D.GeometryModel3D]::new($backMesh,[Windows.Media.Media3D.DiffuseMaterial]::new((Brush '#70CFC5')));$script:folderRear.BackMaterial=$script:folderRear.Material
$ui.FolderModel.Children.Add($script:folderRear);$ui.FolderModel.Children.Add($script:folderSide)
$ui.FolderModel.Children[0].Color=[Windows.Media.ColorConverter]::ConvertFromString('#B8B8B8')
$ui.FolderModel.Children.Add([Windows.Media.Media3D.DirectionalLight]::new([Windows.Media.ColorConverter]::ConvertFromString('#606060'),[Windows.Media.Media3D.Vector3D]::new(-1,-1,-2)))
$ui.Hex.Add_TextChanged({
    try{$color=[Windows.Media.ColorConverter]::ConvertFromString($ui.Hex.Text);$script:solidSurface.Brush=[Windows.Media.SolidColorBrush]::new($color);$shade=[Windows.Media.Color]::FromRgb([byte]($color.R*0.72),[byte]($color.G*0.72),[byte]($color.B*0.72));$material=[Windows.Media.Media3D.DiffuseMaterial]::new([Windows.Media.SolidColorBrush]::new($shade));$script:folderSide.Material=$material;$script:folderSide.BackMaterial=$material;$script:folderRear.Material=$material;$script:folderRear.BackMaterial=$material}catch{}
})
$script:folderSideMesh=$sideMesh;$script:closedFrontMesh=$frontMesh;$script:closedBackMesh=$backMesh;$script:closedSurface=$surface;$script:textureSurface=$surface.Children[1];$script:folderFrontModel=$frontModel
$visibilityWatcher=[ComponentModel.DependencyPropertyDescriptor]::FromProperty([Windows.UIElement]::VisibilityProperty,[Windows.Shapes.Path])
$visibilityWatcher.AddValueChanged($ui.FolderFront,[EventHandler]{
 if($ui.FolderFront.Visibility -eq 'Visible'){$script:folderSide.Geometry=$script:folderSideMesh;$script:folderRear.Geometry=$script:closedBackMesh;$script:folderFrontModel.Geometry=$script:closedFrontMesh;$script:folderFrontModel.Material=$script:closedSurface}
 else{$script:folderSide.Geometry=$null;$script:folderRear.Geometry=$null;$script:folderFrontModel.Geometry=$script:originalFlatMesh;$script:folderFrontModel.Material=$script:textureSurface;$script:folderFrontModel.BackMaterial=$script:textureSurface}
})

Show-StudioPage 'Color'
$ui.QuickColors.Children[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))

if ($Preview) {
    $window.WindowStartupLocation='Manual'; $window.Left=-3000; $window.Top=-3000; $window.ShowInTaskbar=$false
    $window.Show(); $window.UpdateLayout()
    if ($UITest) {
        if ($ui.ColorPage.Visibility -ne 'Visible' -or $ui.QuickColors.Children.Count -ne 9 -or !$ui.Apply.IsVisible) { throw 'Studio main controls unavailable' }
        Show-StudioPage 'Custom';$window.UpdateLayout()
        Set-PlanePoint 0 0;if((Valid-Hex) -ne '#FFFFFF'){throw 'Precise selector unavailable'}
        Show-StudioPage 'Color';$ui.QuickColors.Children[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        Assert-ProBatch 100;if(!(Test-ProAccess)){throw 'Features must be free'}
        Write-Output 'OK: Studio layout, precise picker and free features.'
    } else { $ui.QuickColors.Children[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }
    foreach($entry in @('Image','Styles','Custom')){$ui[$entry+'Page'].BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$ui[$entry+'Page'].Opacity=1}
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
