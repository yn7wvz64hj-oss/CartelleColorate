# Store owns binary updates and Explorer registration. No GitHub polling or legacy registration.
function Update-Menu { }
function Start-ProductUpdateCheck([bool]$Quiet=$false) { }
function Invoke-GuidedDownload { Show-UpdateDialog }
function Start-UpdateInstaller { throw 'Updates are managed by Microsoft Store.' }
function Show-UpdateDialog {
    $dialog=New-ProductWindow (T 'updates') 420 200
    $panel=[Windows.Controls.StackPanel]::new();$panel.Margin=[Windows.Thickness]::new(24)
    $label=[Windows.Controls.TextBlock]::new();$label.TextWrapping='Wrap'
    $label.Text=if($script:activeLanguage.code -eq 'it'){ 'Gli aggiornamenti di Nova Prism sono gestiti dal Microsoft Store.' }else{ 'Nova Prism updates are managed by Microsoft Store.' }
    $panel.Children.Add($label)|Out-Null
    $button=[Windows.Controls.Button]::new();$button.Content='Microsoft Store';$button.Margin=[Windows.Thickness]::new(0,20,0,0)
    $button.Add_Click({Start-Process 'ms-windows-store://downloadsandupdates'})
    $panel.Children.Add($button)|Out-Null;$dialog.Content=$panel;[void]$dialog.ShowDialog()
}
