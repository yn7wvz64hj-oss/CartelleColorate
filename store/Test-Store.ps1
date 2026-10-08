param([Parameter(Mandatory=$true)][string]$Output,[switch]$Native,[string]$Repository=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$payload=[IO.File]::ReadAllText((Join-Path $Output 'payload-path.txt'))
$fixture=Join-Path $Output ('t-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $fixture -Force|Out-Null
Copy-Item -Path (Join-Path $payload '*') -Destination $fixture -Recurse
# Core self-test exercises ordinary updater fixtures; include its fixture dependency only here.
$repo=$Repository
Copy-Item -LiteralPath (Join-Path $repo 'src\AutoUpdate.ps1') -Destination $fixture
$p=Start-Process -FilePath (Join-Path $payload 'NovaPrism.exe') -ArgumentList @('--test',('"'+$fixture+'"')) -PassThru
if(!$p.WaitForExit(120000)){ $p.Kill();throw 'Launcher self-test timed out.' }
if($p.ExitCode -ne 0){throw ('Launcher self-test failed: '+[IO.File]::ReadAllText((Join-Path $fixture 'launcher-error.txt')))}
$marker=Join-Path $fixture 'test-data\verifica-avvio.txt'
if(!(Test-Path -LiteralPath $marker)){throw 'No-console test did not complete.'}
$preview=Join-Path $Output 'Store-Screenshot.png'
$p=Start-Process -FilePath (Join-Path $payload 'NovaPrism.exe') -ArgumentList @('--preview',('"'+$fixture+'"'),('"'+$preview+'"')) -PassThru
if(!$p.WaitForExit(60000)){$p.Kill();throw 'UI launch timed out.'}
if($p.ExitCode -ne 0 -or !(Test-Path -LiteralPath $preview)){throw 'UI preview failed.'}
[xml]$manifest=Get-Content -LiteralPath (Join-Path $payload 'AppxManifest.xml') -Raw
if($manifest.Package.Applications.Application.Executable -ne 'NovaPrism.exe'){throw 'Invalid entry point.'}
if($Native){
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class StoreDllTest {
 [DllImport("kernel32",CharSet=CharSet.Unicode)]static extern IntPtr LoadLibrary(string path);
 [DllImport("kernel32")]static extern IntPtr GetProcAddress(IntPtr h,string name);
 [UnmanagedFunctionPointer(CallingConvention.StdCall)]delegate int GetClass(ref Guid clsid,ref Guid iid,out IntPtr obj);
 public static void Test(string path){
  IntPtr h=LoadLibrary(path);if(h==IntPtr.Zero)throw new Exception("Cannot load Explorer DLL");
  var get=(GetClass)Marshal.GetDelegateForFunctionPointer(GetProcAddress(h,"DllGetClassObject"),typeof(GetClass));
  Guid id=new Guid("B0CCF71B-A843-4D3A-A62C-09BE0D364371"), iid=new Guid("00000001-0000-0000-C000-000000000046");IntPtr obj;
  Marshal.ThrowExceptionForHR(get(ref id,ref iid,out obj));Marshal.Release(obj);
  id=Guid.NewGuid();if(get(ref id,ref iid,out obj)!=unchecked((int)0x80040111))throw new Exception("Unknown CLSID accepted");
 }
}
'@
    [StoreDllTest]::Test((Join-Path $payload 'NovaPrismCommand.dll'))
}
Write-Output 'PASS: WinExe launcher, no visible console, folder backend, WPF preview and package manifest.'
