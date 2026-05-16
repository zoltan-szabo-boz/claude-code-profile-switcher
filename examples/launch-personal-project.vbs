' Example launcher: opens a workspace with the "personal" profile.
' Copy this file, rename it, and change the profile and workspace path.

Set WshShell = CreateObject("WScript.Shell")
scriptDir = Replace(WScript.ScriptFullName, WScript.ScriptName, "")

' If examples/ is a subfolder, go up one level to find claude-switch-and-launch.vbs
parentDir = scriptDir & "..\"

WshShell.Run "wscript """ & parentDir & "claude-switch-and-launch.vbs"" personal ""C:\Users\Me\my-personal-project""", 0, False
