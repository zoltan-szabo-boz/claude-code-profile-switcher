' Claude Code Profile Switcher — Launch Wrapper
'
' Usage: wscript claude-switch-and-launch.vbs <profile> <workspace-path>
'
' Detects the current profile, prompts the user if VS Code needs to close,
' runs the profile switch, then opens VS Code with the workspace.

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

If WScript.Arguments.Count < 2 Then
    MsgBox "Usage: claude-switch-and-launch.vbs <profile> <workspace-path>", vbCritical, "Claude Profile Switcher"
    WScript.Quit 1
End If

profile = WScript.Arguments(0)
workspace = WScript.Arguments(1)
home = WshShell.ExpandEnvironmentStrings("%USERPROFILE%")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName) & "\"

vscode = home & "\AppData\Local\Programs\Microsoft VS Code\Code.exe"
settingsFile = home & "\.claude\settings.json"
iniFile = scriptDir & "profiles.ini"

' --- Read profiles from INI ---
Dim profileNames()
Dim detectStrings()
profileCount = 0

Set iniStream = fso.OpenTextFile(iniFile, 1)
currentSection = ""
Do While Not iniStream.AtEndOfStream
    line = Trim(iniStream.ReadLine)
    If Left(line, 1) = "[" And Right(line, 1) = "]" Then
        currentSection = Mid(line, 2, Len(line) - 2)
        profileCount = profileCount + 1
        ReDim Preserve profileNames(profileCount - 1)
        ReDim Preserve detectStrings(profileCount - 1)
        profileNames(profileCount - 1) = currentSection
        detectStrings(profileCount - 1) = ""
    ElseIf currentSection <> "" And Left(line, 7) = "detect=" Then
        detectStrings(profileCount - 1) = Mid(line, 8)
    End If
Loop
iniStream.Close

' --- Detect current profile ---
current = "unknown"
If fso.FileExists(settingsFile) Then
    Set f = fso.OpenTextFile(settingsFile, 1)
    content = f.ReadAll
    f.Close
    For i = 0 To profileCount - 1
        If detectStrings(i) <> "" Then
            If InStr(content, detectStrings(i)) > 0 Then
                If current = "unknown" Then current = profileNames(i)
            End If
        End If
    Next
    ' Fallback to last profile if no detect string matched
    If current = "unknown" And profileCount > 0 Then
        current = profileNames(profileCount - 1)
    End If
End If

' --- Already on correct profile — just open VS Code ---
If current = profile Then
    WshShell.Run """" & vscode & """ """ & workspace & """", 1, False
    WScript.Quit 0
End If

' --- Check if VS Code is running ---
Set wmi = GetObject("winmgmts:\\.\root\cimv2")
Set procs = wmi.ExecQuery("SELECT Name FROM Win32_Process WHERE Name='Code.exe'")

If procs.Count > 0 Then
    msg = "VS Code is running with the " & current & " profile." & vbCrLf & vbCrLf _
        & "Switching to " & profile & " requires closing all VS Code windows." & vbCrLf _
        & "Unsaved work will prompt to save." & vbCrLf & vbCrLf _
        & "Close VS Code and switch profile?"

    result = MsgBox(msg, vbOKCancel + vbExclamation, "Claude Profile Switch")

    If result <> vbOK Then
        WScript.Quit 0
    End If

    ' Close VS Code gracefully
    WshShell.Run "taskkill /im Code.exe", 0, True

    ' Wait up to 10 seconds
    For i = 1 To 10
        Set procs = wmi.ExecQuery("SELECT Name FROM Win32_Process WHERE Name='Code.exe'")
        If procs.Count = 0 Then Exit For
        WScript.Sleep 1000
    Next

    ' Force kill if still running
    Set procs = wmi.ExecQuery("SELECT Name FROM Win32_Process WHERE Name='Code.exe'")
    If procs.Count > 0 Then
        WshShell.Run "taskkill /f /im Code.exe", 0, True
        WScript.Sleep 2000
    End If
End If

' --- Run the profile switch ---
WshShell.Run """" & scriptDir & "claude-switch.bat"" " & profile, 0, True

' --- Launch VS Code ---
WshShell.Run """" & vscode & """ """ & workspace & """", 1, False

WScript.Quit 0
