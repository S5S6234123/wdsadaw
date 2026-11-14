Option Explicit

Dim fso, shell, folderPath, cmdPath, commandLine, exitCode
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
folderPath = fso.GetParentFolderName(WScript.ScriptFullName)
cmdPath = fso.BuildPath(folderPath, "MXRIG Miner.cmd")
shell.CurrentDirectory = folderPath
commandLine = "cmd.exe /c " & Chr(34) & Chr(34) & cmdPath & Chr(34) & Chr(34)
exitCode = shell.Run(commandLine, 0, True)
WScript.Quit exitCode
