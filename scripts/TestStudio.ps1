param([string]$Package,[string]$OutputDirectory)
$ErrorActionPreference='Stop'
$fixture=Join-Path $OutputDirectory ('studio-fixture-'+[Guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $fixture -Force|Out-Null
$source=Join-Path $Package 'Interfaccia.ps1';$original=[IO.File]::ReadAllText($source)
$hook=@'

    $script:proEdition.Mode='Free';$script:proEdition.LegacyBatch=$false
    $env:CC_LICENSE_SERVER='http://127.0.0.1:1'
    Assert-ProBatch 100; if(!(Assert-ProFeature 'background') -or !(Test-ProAccess)){throw 'Free features gated'}

    if($ui.ColorPage.Visibility -ne 'Visible' -or $ui.CustomPage.Visibility -ne 'Collapsed'){throw 'Initial page wrong'}
    foreach($mode in @($true,$false)){
        $script:dark=$mode;Apply-Appearance 'Windows';$window.UpdateLayout()
        $hero=$window.Resources['StudioHeroFill'];$text=$window.Resources['StudioHeroText'].Color
        foreach($stop in $hero.GradientStops){if((Get-ContrastRatio $stop.Color $text) -lt 4.5){throw 'Hero text contrast failed'}}
        if($mode -and $hero.GradientStops[0].Color.R -gt 70){throw 'Dark hero remained light'}
    }
    $ui.QuickColors.Children[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if($ui.Hex.Text -ne '#72B69A' -or $ui.FolderFront.Fill.GradientStops[1].Color.ToString() -ne '#FF72B69A'){throw 'Quick color failed'}
    $ui.CustomColor.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));$window.UpdateLayout()
    if($ui.CustomPage.Visibility -ne 'Visible' -or $ui.ColorPlane.ActualWidth -lt 80){throw 'Custom picker hidden or too small'}
    Set-PlanePoint 0 0;if((Valid-Hex) -ne '#FFFFFF'){throw 'Precise selector failed'}
    $ui.Hex.Text='#72B69A';$ui.BackToColors.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    $ui.SaveCurrentStyle.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));$window.UpdateLayout()
    if($ui.StylesPage.Visibility -ne 'Visible'){throw 'Styles navigation failed'}
    $ui.ColorName.Text='Salvia studio';$ui.Save.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if(!@($script:collection | Where-Object Name -eq 'Salvia studio').Count){throw 'Style save failed'}
    $ui.ImageTab.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    $bitmap=[Drawing.Bitmap]::new(64,64);$graphics=[Drawing.Graphics]::FromImage($bitmap)
    try{$graphics.Clear([Drawing.Color]::Coral);$png=Join-Path $root 'studio-image.png';$bitmap.Save($png,[Drawing.Imaging.ImageFormat]::Png)}finally{$graphics.Dispose();$bitmap.Dispose()}
    Set-PngPreview $png
    if($ui.UploadedPreview.Visibility -ne 'Visible' -or $ui.UseColor.Visibility -ne 'Visible'){throw 'PNG preview failed'}
    $ui.SaveImageStyle.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));$window.UpdateLayout()
    if($ui.StylesPage.Visibility -ne 'Visible' -or $ui.ImageStyles.Children.Count -lt 1){throw 'PNG style library save failed'}
    if(!@(Read-ProductList 'preset.json' | Where-Object { $_.Name -eq 'studio-image' -and [IO.File]::Exists($_.Png) }).Count){throw 'Saved PNG preset missing'}
    $imageButton=@($ui.ImageStyles.Children | Where-Object { $_.Tag.Name -eq 'studio-image' })[0]
    $imageButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if($ui.UploadedPreview.Visibility -ne 'Visible'){throw 'Saved image style failed'}
    $ui.UseColor.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if($ui.UploadedPreview.Visibility -ne 'Collapsed'){throw 'Return to color failed'}
    $ui.ColorTab.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    $ui.QuickColors.Children[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    $script:badge='heart';$script:badgeHex='#CC2255';Update-BadgePreview
    Select-ProductFolders @($Folder)
    $ui.Apply.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if(!$window.IsVisible -or !(Test-Path (Join-Path $script:currentFolder 'desktop.ini'))){throw ('Apply failed: '+$ui.Status.Text+' folder='+$script:currentFolder)}
    $ui.Undo.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if(Test-Path (Join-Path $script:currentFolder 'desktop.ini')){throw 'Undo failed'}
    if($ui.Apply.TransformToAncestor($ui.Root).Transform([Windows.Point]::new(0,$ui.Apply.ActualHeight)).Y -gt $ui.Root.ActualHeight){throw 'Apply clipped'}
    $ui.QuickColors.Children[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    'OK: pagine, colori pronti, selettore preciso, salvataggio, PNG, applicazione senza chiusura e annullamento.'

'@
try{
 [IO.File]::WriteAllText($source,$original.Replace('$window.Show(); $window.UpdateLayout()','$window.Show(); $window.UpdateLayout()'+[Environment]::NewLine+$hook),[Text.UTF8Encoding]::new($true))
 & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $Package 'CartelleColorate.ps1') -Folder $fixture -Theme Dark -Language it -Preview (Join-Path $OutputDirectory 'anteprima.png')
 if($LASTEXITCODE -ne 0){throw 'Studio interaction tests failed'}
}finally{[IO.File]::WriteAllText($source,$original,[Text.UTF8Encoding]::new($true))}
