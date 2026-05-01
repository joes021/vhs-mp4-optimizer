Option Explicit

Dim shell
Dim fileSystem
Dim scriptDir
Dim command

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptDir = fileSystem.GetParentFolderName(WScript.ScriptFullName)
shell.CurrentDirectory = scriptDir

command = "powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File " & Chr(34) & scriptDir & "\optimize-vhs-mp4-gui.ps1" & Chr(34)
shell.Run command, 0, False
