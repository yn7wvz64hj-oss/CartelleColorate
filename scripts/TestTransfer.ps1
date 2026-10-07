param([Parameter(Mandatory=$true)][string]$Package)
$ErrorActionPreference='Stop'
. (Join-Path $Package 'Localization.ps1'); $script:activeLanguage=$script:languageMap['en']
. (Join-Path $Package 'Productivity.ps1'); Initialize-Transfer
Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll','System.Net.Http.dll') -TypeDefinition @'
using System; using System.IO; using System.Net; using System.Net.Http; using System.Threading; using System.Threading.Tasks;
public sealed class TransferFixture : HttpMessageHandler {
 readonly int length; public TransferFixture(int size) { length=size; }
 protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken cancel) {
  return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content=new StreamContent(new SlowFixture(length)) });
 }
 class SlowFixture : Stream {
  int position, length; public SlowFixture(int size) { length=size; }
  public override bool CanRead { get { return true; } } public override bool CanSeek { get { return false; } } public override bool CanWrite { get { return false; } }
  public override long Length { get { throw new NotSupportedException(); } } public override long Position { get { return position; } set { throw new NotSupportedException(); } }
  public override async Task<int> ReadAsync(byte[] b,int o,int n,CancellationToken cancel) {
   await Task.Delay(70,cancel).ConfigureAwait(false); int count=Math.Min(n,length-position); for(int i=0;i<count;i++) b[o+i]=(byte)((position+i)%251); position+=count; return count;
  }
  public override int Read(byte[] b,int o,int n) { throw new NotSupportedException(); } public override void Flush() {} public override long Seek(long o,SeekOrigin origin) { throw new NotSupportedException(); }
  public override void SetLength(long n) { throw new NotSupportedException(); } public override void Write(byte[] b,int o,int n) { throw new NotSupportedException(); }
 }
}
'@
$transfer=[CartelleColorate.Transfer]::new([TransferFixture]::new(131072)); $task=$transfer.DownloadAsync('https://fixture.invalid/package',131072); $observed=$false; $previous=0
try { while (!$task.IsCompleted) { $value=$transfer.Received; if ($value -lt $previous) { throw 'Progress went backwards' }; if ($value -gt 0 -and $value -lt 131072) { $observed=$true }; $previous=$value; Start-Sleep -Milliseconds 30 }; $bytes=$task.GetAwaiter().GetResult(); if (!$observed -or $bytes.Length -ne 131072 -or $bytes[20000] -ne (20000%251)) { throw 'Streamed download or progress failed' } } finally { $transfer.Dispose() }
foreach ($expected in @(1000,140000)) { $transfer=[CartelleColorate.Transfer]::new([TransferFixture]::new(131072)); $failed=$false; try { $null=$transfer.DownloadAsync('https://fixture.invalid/package',$expected).GetAwaiter().GetResult() } catch { $failed=$true } finally { $transfer.Dispose() }; if (!$failed) { throw 'Wrong transfer size accepted' } }
$transfer=[CartelleColorate.Transfer]::new([TransferFixture]::new(131072)); $task=$transfer.DownloadAsync('https://fixture.invalid/package',131072); Start-Sleep -Milliseconds 120; $transfer.Dispose(); $failed=$false; try { $null=$task.GetAwaiter().GetResult() } catch { $failed=$true }; if (!$failed) { throw 'Cancelled transfer completed' }
Write-Output 'OK: avanzamento reale durante il download, dati integri, trasferimenti incompleti o eccessivi respinti e annullamento.'
