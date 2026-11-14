Option Explicit

Dim fso, shell, folderPath, startupPath, shortcutPath, startScript, shortcut
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
folderPath = fso.GetParentFolderName(WScript.ScriptFullName)
startupPath = shell.SpecialFolders("Startup")
shortcutPath = fso.BuildPath(startupPath, "MXRIG Miner (CPU + GPU).lnk")
startScript = fso.BuildPath(folderPath, "Start MXRIG Miner.vbs")

Set shortcut = shell.CreateShortcut(shortcutPath)
shortcut.TargetPath = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\wscript.exe")
shortcut.Arguments = Chr(34) & startScript & Chr(34)
shortcut.WorkingDirectory = folderPath
shortcut.Description = "Starts the MXRIG miner hidden; output is logged beside the miner."
shortcut.Save

MsgBox "Added MXRIG Miner to your Windows Startup folder. To remove it, double-click Remove MXRIG from Windows Startup.vbs.", vbInformation, "MXRIG Miner"
