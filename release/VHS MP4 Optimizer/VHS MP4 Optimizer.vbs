Option Explicit

Dim shell
Dim fileSystem
Dim rootDir
Dim command

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

rootDir = fileSystem.GetParentFolderName(WScript.ScriptFullName)
shell.CurrentDirectory = rootDir

command = "powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File " & Chr(34) & rootDir & "\scripts\optimize-vhs-mp4-gui.ps1" & Chr(34)
shell.Run command, 0, False
