' Example launcher: opens a workspace with the "work" profile.
' Copy this file, rename it, and change the profile and workspace path.

Set WshShell = CreateObject("WScript.Shell")
scriptDir = Replace(WScript.ScriptFullName, WScript.ScriptName, "")

' If examples/ is a subfolder, go up one level to find claude-switch-and-launch.vbs
parentDir = scriptDir & "..\"

WshShell.Run "wscript """ & parentDir & "claude-switch-and-launch.vbs"" work ""D:\my-work-project""", 0, False
