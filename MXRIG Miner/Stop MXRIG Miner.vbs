Option Explicit

Dim fso, folderPath, runtimePrefix, wmi, processes, process, exePath, stopped
Set fso = CreateObject("Scripting.FileSystemObject")
folderPath = LCase(fso.GetParentFolderName(WScript.ScriptFullName))
runtimePrefix = folderPath & "\.mxrig-runtime\"
Set wmi = GetObject("winmgmts:\\.\root\cimv2")
Set processes = wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name='xmrig.exe'")
stopped = False

For Each process In processes
    If Not IsNull(process.ExecutablePath) Then
        exePath = LCase(CStr(process.ExecutablePath))
        If Left(exePath, Len(runtimePrefix)) = runtimePrefix Then
            process.Terminate 0
            stopped = True
        End If
    End If
Next

If stopped Then
    MsgBox "MXRIG Miner was stopped.", vbInformation, "MXRIG Miner"
Else
    MsgBox "No MXRIG Miner process was found in this folder's runtime directory.", vbInformation, "MXRIG Miner"
End If
