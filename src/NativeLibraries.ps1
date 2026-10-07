function Install-NativeLibraries([string]$SourceDirectory,[string]$DestinationDirectory) {
    $buildDirectory=Join-Path $DestinationDirectory ('native-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
    try {
        # Build both first. Newly generated local DLLs do not inherit the ZIP's Internet zone.
        foreach ($name in @('FolderShell','DesktopPicker')) {
            $source=Join-Path $SourceDirectory ($name+'.cs')
            Add-Type -TypeDefinition ([IO.File]::ReadAllText($source)) -OutputAssembly (Join-Path $buildDirectory ($name+'.dll')) -OutputType Library -ReferencedAssemblies System.dll,System.Core.dll,System.Drawing.dll
        }
        foreach ($name in @('FolderShell','DesktopPicker')) {
            $target=Join-Path $DestinationDirectory ($name+'.dll')
            if ([IO.File]::Exists($target)) { [IO.File]::Delete($target) }
            [IO.File]::Move((Join-Path $buildDirectory ($name+'.dll')),$target)
        }
    } finally {
        # Exact generated directory; no recursive deletion of user files.
        foreach ($name in @('FolderShell','DesktopPicker')) {
            $temporary=Join-Path $buildDirectory ($name+'.dll')
            if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
        }
        if ([IO.Directory]::Exists($buildDirectory)) { [IO.Directory]::Delete($buildDirectory,$false) }
    }
}
