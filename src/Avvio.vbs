Option Explicit
Dim shell, files, root, powershell, command, mode, folder, color, result
Set shell = CreateObject("WScript.Shell")
Set files = CreateObject("Scripting.FileSystemObject")
root = files.GetParentFolderName(WScript.ScriptFullName)
powershell = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")
command = Quote(powershell) & " -NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File " & Quote(root & "\Avvio.ps1")
If WScript.Arguments.Count = 1 And WScript.Arguments(0) = "--self-test" Then
    command = command & " -SelfTest -NoConsoleTest"
Else
    If WScript.Arguments.Count < 1 Or WScript.Arguments.Count > 3 Then Fail "openFromFolder"
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
            If Not regex.Test(color) Then Fail "colorInvalid"
            command = command & " -Color " & Quote(color)
        Else
            Fail "invalidCommand"
        End If
    End If
End If
On Error Resume Next
result = shell.Run(command, 0, True)
If Err.Number <> 0 Then
    Dim launchError
    launchError = Err.Description
    MsgBox TranslateMessage("launchError") & launchError, 16, "CartelleColorate"
    WScript.Quit 1
End If
On Error GoTo 0
WScript.Quit result

Sub Fail(message)
    MsgBox TranslateMessage(message), 16, "CartelleColorate"
    WScript.Quit 1
End Sub


Function TranslateMessage(key)
    Dim code, localeName, settingsFile, text, regex, matches, reader, line, prefix, fallback
    code = "en"
    fallback = key
    On Error Resume Next
    localeName = shell.RegRead("HKCU\Control Panel\International\LocaleName")
    If Err.Number = 0 Then code = LCase(Split(localeName, "-")(0))
    Err.Clear
    settingsFile = root & "\impostazioni.json"
    If files.FileExists(settingsFile) Then
        Set reader = files.OpenTextFile(settingsFile, 1, False, 0)
        text = reader.ReadAll
        reader.Close
        Set regex = New RegExp
        regex.Pattern = Chr(34) & "language" & Chr(34) & "\s*:\s*" & Chr(34) & "([a-z]{2,8}(-[a-z0-9]{2,8})*)" & Chr(34)
        Set matches = regex.Execute(text)
        If matches.Count > 0 Then code = matches(0).SubMatches(0)
    End If
    prefix = code & "." & key & "="
    Err.Clear
    Set reader = files.OpenTextFile(root & "\LauncherMessages.txt", 1, False, -1)
    If Err.Number <> 0 Then
        TranslateMessage = fallback
        Exit Function
    End If
    Do Until reader.AtEndOfStream
        line = reader.ReadLine
        If Left(line, Len("en." & key & "=")) = "en." & key & "=" Then fallback = Mid(line, Len("en." & key & "=") + 1)
        If Left(line, Len(prefix)) = prefix Then
            TranslateMessage = Mid(line, Len(prefix) + 1)
            reader.Close
            Exit Function
        End If
    Loop
    reader.Close
    TranslateMessage = fallback
    On Error GoTo 0
End Function

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
