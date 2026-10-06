Option Explicit
Dim files, shell, root, queue, request, stream, command, live, heartbeat, powershell
Set files=CreateObject("Scripting.FileSystemObject")
Set shell=CreateObject("WScript.Shell")
root=files.GetParentFolderName(WScript.ScriptFullName)
If WScript.Arguments.Count < 2 Then WScript.Quit 1
command=WScript.Arguments(0)
If command <> "--color" And command <> "--restore" And command <> "--preset" Then WScript.Quit 1
If (command="--color" Or command="--preset") And WScript.Arguments.Count<>3 Then WScript.Quit 1
If command="--restore" And WScript.Arguments.Count<>2 Then WScript.Quit 1
queue=root & "\coda"
If Not files.FolderExists(queue) Then files.CreateFolder queue
request=queue & "\" & files.GetTempName()
Set stream=files.CreateTextFile(request,False,True)
stream.WriteLine command
stream.WriteLine WScript.Arguments(1)
If command="--color" Or command="--preset" Then stream.WriteLine WScript.Arguments(2)
stream.Close
files.MoveFile request,request & ".cmd"
heartbeat=root & "\worker.attivo"
live=False
If files.FileExists(heartbeat) Then live=(DateDiff("s",files.GetFile(heartbeat).DateLastModified,Now)<8)
If Not live Then
    powershell=shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")
    shell.Run Chr(34) & powershell & Chr(34) & " -NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File " & Chr(34) & root & "\CartelleColorate.ps1" & Chr(34) & " -Worker",0,False
End If
