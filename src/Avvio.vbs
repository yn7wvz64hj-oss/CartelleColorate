Option Explicit
Dim shell, files, root, powershell, command, mode, folder, color, result
Set shell = CreateObject("WScript.Shell")
Set files = CreateObject("Scripting.FileSystemObject")
root = files.GetParentFolderName(WScript.ScriptFullName)
powershell = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")
command = Quote(powershell) & " -NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File " & Quote(root & "\CartelleColorate.ps1")
If WScript.Arguments.Count = 1 And WScript.Arguments(0) = "--self-test" Then
    command = command & " -SelfTest -NoConsoleTest"
Else
    If WScript.Arguments.Count < 1 Or WScript.Arguments.Count > 3 Then Fail "Apri Cambia colore dal menu di una cartella."
    folder = WScript.Arguments(0)
    command = command & " -Folder " & Quote(folder)
    If WScript.Arguments.Count > 1 Then
        mode = WScript.Arguments(1)
        If mode = "--restore" And WScript.Arguments.Count = 2 Then
            command = command & " -Restore"
        ElseIf mode = "--color" And WScript.Arguments.Count = 3 Then
            color = WScript.Arguments(2)
            Dim regex
            Set regex = New RegExp
            regex.Pattern = "^#[0-9A-Fa-f]{6}$"
            If Not regex.Test(color) Then Fail "Colore non valido."
            command = command & " -Color " & Quote(color)
        Else
            Fail "Comando non valido."
        End If
    End If
End If
On Error Resume Next
result = shell.Run(command, 0, True)
If Err.Number <> 0 Then
    MsgBox "Impossibile avviare Cambia colore: " & Err.Description, 16, "CartelleColorate"
    WScript.Quit 1
End If
On Error GoTo 0
WScript.Quit result

Sub Fail(message)
    MsgBox message, 16, "CartelleColorate"
    WScript.Quit 1
End Sub

Function Quote(value)
    Dim i, char, slashes, output
    output = Chr(34)
    slashes = 0
    For i = 1 To Len(value)
        char = Mid(value, i, 1)
        If char = "\" Then
            slashes = slashes + 1
        Else
            If char = Chr(34) Then
                output = output & String(slashes * 2 + 1, "\") & char
            Else
                output = output & String(slashes, "\") & char
            End If
            slashes = 0
        End If
    Next
    Quote = output & String(slashes * 2, "\") & Chr(34)
End Function
