using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
namespace CartelleColorate {
 public sealed class Transfer : IDisposable {
  readonly HttpClient client; readonly CancellationTokenSource cancel = new CancellationTokenSource(); long received;
  public long Received { get { return Interlocked.Read(ref received); } }
  public Transfer(string version) { client = new HttpClient(); client.Timeout = TimeSpan.FromMinutes(2); client.DefaultRequestHeaders.UserAgent.ParseAdd("CartelleColorate/"+version); }
  public Transfer(HttpMessageHandler handler) { client = new HttpClient(handler); }
  public async Task<byte[]> DownloadAsync(string url,long expected) {
   if(expected<1 || expected>33554432) throw new InvalidDataException("Invalid download size");
   using(var response=await client.GetAsync(url,HttpCompletionOption.ResponseHeadersRead,cancel.Token).ConfigureAwait(false)) {
    response.EnsureSuccessStatusCode();
    if(response.Content.Headers.ContentLength.HasValue && response.Content.Headers.ContentLength.Value!=expected) throw new InvalidDataException("Download size differs");
    using(var input=await response.Content.ReadAsStreamAsync().ConfigureAwait(false))
    using(var output=new MemoryStream()) { var buffer=new byte[16384]; int count;
     while((count=await input.ReadAsync(buffer,0,buffer.Length,cancel.Token).ConfigureAwait(false))>0) {
      if(Received+count>expected) throw new InvalidDataException("Download too large"); output.Write(buffer,0,count); Interlocked.Add(ref received,count);
     }
     if(Received!=expected) throw new InvalidDataException("Incomplete download"); return output.ToArray();
    }
   }
  }
  public void Dispose() { cancel.Cancel(); client.CancelPendingRequests(); client.Dispose(); }
 }
}
