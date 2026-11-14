Option Explicit

Dim fso, shell, startupPath, shortcutPath
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
startupPath = shell.SpecialFolders("Startup")
shortcutPath = fso.BuildPath(startupPath, "MXRIG Miner (CPU + GPU).lnk")

If fso.FileExists(shortcutPath) Then
    fso.DeleteFile shortcutPath, True
    MsgBox "Removed MXRIG Miner from Windows Startup.", vbInformation, "MXRIG Miner"
Else
    MsgBox "MXRIG Miner is not in the Windows Startup folder.", vbInformation, "MXRIG Miner"
End If
