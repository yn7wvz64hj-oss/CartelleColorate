param([string]$Folder,[string]$Color,[switch]$Restore,[switch]$SelfTest,[switch]$NoConsoleTest)
$ErrorActionPreference='Stop'
try {
    $arguments=@{Folder=$Folder;Color=$Color;Restore=$Restore;SelfTest=$SelfTest;NoConsoleTest=$NoConsoleTest}
    & (Join-Path $PSScriptRoot 'CartelleColorate.ps1') @arguments
} catch {
    $startupException=$_
    $log=Join-Path $PSScriptRoot 'avvio-errore.log'
    try { [IO.File]::WriteAllText($log,([DateTime]::Now.ToString('s')+[Environment]::NewLine+$startupException.ToString()+[Environment]::NewLine+$startupException.ScriptStackTrace),[Text.Encoding]::UTF8) } catch { }
    $message='CartelleColorate could not start. Details: avvio-errore.log'
    try {
        . (Join-Path $PSScriptRoot 'Localization.ps1')
        Initialize-Language $PSScriptRoot
        $message=T 'startupError'
    } catch { }
    if ($NoConsoleTest) { Write-Output ($message+[Environment]::NewLine+$startupException.Exception.Message); exit 1 }
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.MessageBox]::Show(($message+[Environment]::NewLine+[Environment]::NewLine+$startupException.Exception.Message),'CartelleColorate',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit 1
}
