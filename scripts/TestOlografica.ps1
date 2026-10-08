param([string]$Package,[string]$OutputDirectory)
$ErrorActionPreference='Stop'
$fixture=Join-Path $OutputDirectory ('studio-fixture-'+[Guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $fixture -Force|Out-Null
$source=Join-Path $Package 'Interfaccia.ps1';$original=[IO.File]::ReadAllText($source)
$hook=@'

    $script:proEdition.Mode='Free';$script:proEdition.LegacyBatch=$false
    $env:CC_LICENSE_SERVER='http://127.0.0.1:1'
    Assert-ProBatch 100; if(!(Assert-ProFeature 'background') -or !(Test-ProAccess)){throw 'Free features gated'}

    if($ui.ColorPage.Visibility -ne 'Visible' -or $ui.CustomPage.Visibility -ne 'Visible'){throw 'Initial page wrong'}
    if(!$ui.NovaMinimize){throw 'Minimize button missing'}
    $ui.NovaMinimize.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if($window.WindowState -ne 'Minimized'){throw 'Minimize failed'}
    $window.WindowState='Normal'
    Set-NovaMotion $false
    if(!$ui.ImageDrop.RenderTransform.Children[2].HasAnimatedProperties){throw 'Holographic animations unavailable'}
    Set-NovaMotion $true
    if($ui.ImageDrop.RenderTransform.Children[2].HasAnimatedProperties -or $ui.QuickColors.Children[0].RenderTransform.Children[1].HasAnimatedProperties){throw 'Reduced motion failed'}
    if(!$ui.HoloSky.Background.ImageSource -or $ui.HoloTurn.Angle -ne 0){throw 'Atmosphere or perspective missing'}
    if($script:closedFrontMesh.TriangleIndices.Count -lt 12 -or $script:closedBackMesh.TriangleIndices.Count -ne $script:closedFrontMesh.TriangleIndices.Count){throw 'Closed 3D surfaces missing'}
    Set-FolderRotation 180 70
    if(!$script:folderRear.Geometry -or !$script:folderSide.Geometry){throw 'Rear or side surface missing'}
    Set-FolderRotation 60 25
    if($ui.HoloTurn.Angle -ne 60 -or $ui.FolderPitch.Angle -ne 25 -or $script:folderSide.Geometry.Positions.Count -lt 20){throw '3D rotation or depth missing'}
    Set-FolderRotation 0 0
    Set-DockHover $ui.QuickColors.Children[4]
    if(!$ui.QuickColors.Children[4].RenderTransform.Children[0].HasAnimatedProperties){throw 'Dock magnification missing'}
    Set-DockHover $null
    Set-NovaMotion $false
    Invoke-DockBounce $ui.QuickColors.Children[4]
    if(!$ui.QuickColors.Children[4].RenderTransform.Children[1].HasAnimatedProperties){throw 'Dock bounce missing'}
    Set-NovaMotion $true
    foreach($dimensions in @(@(1280,900),@(1060,740))){
        $window.Width=$dimensions[0];$window.Height=$dimensions[1];$window.UpdateLayout()
        foreach($control in @($ui.Pick,$ui.Save,$ui.Upload,$ui.Apply,$ui.RenameFolder)){
            if(!$control.IsVisible){throw 'Main control hidden'}
            $bottom=$control.TransformToAncestor($ui.Root).Transform([Windows.Point]::new($control.ActualWidth,$control.ActualHeight))
            if($bottom.X -gt $ui.Root.ActualWidth+1 -or $bottom.Y -gt $ui.Root.ActualHeight+1){throw 'Main control outside window'}
        }
    }
    $window.Width=1280;$window.Height=900;$window.UpdateLayout()
    $ui.QuickColors.Children[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if($ui.Hex.Text -ne '#A89BFF' -or $ui.FolderFront.Fill.GradientStops[1].Color.ToString() -ne '#FFA89BFF'){throw 'Quick color failed'}
    $ui.CustomColor.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));$window.UpdateLayout()
    if($ui.CustomPage.Visibility -ne 'Visible' -or $ui.ColorPlane.ActualWidth -lt 80){throw 'Custom picker hidden or too small'}
    Set-PlanePoint 0 0;if((Valid-Hex) -ne '#FFFFFF'){throw 'Precise selector failed'}
    $ui.Hex.Text='#A89BFF';$ui.BackToColors.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
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
    $script:badge='none';Update-BadgePreview
    $ui.QuickColors.Children[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    $ui.FolderName.Text='La mia galassia'
    Set-NovaMotion $false
    'OK: holographic layout, resizing, perspective, motion, precise colors, PNG styles, real apply and undo.'

'@
try{
 [IO.File]::WriteAllText($source,$original.Replace('$window.Show(); $window.UpdateLayout()','$window.Show(); $window.UpdateLayout()'+[Environment]::NewLine+$hook),[Text.UTF8Encoding]::new($true))
 & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $Package 'CartelleColorate.ps1') -Folder $fixture -Theme Dark -Language it -Preview (Join-Path $OutputDirectory 'anteprima.png')
 if($LASTEXITCODE -ne 0){throw 'Studio interaction tests failed'}
}finally{[IO.File]::WriteAllText($source,$original,[Text.UTF8Encoding]::new($true))}
