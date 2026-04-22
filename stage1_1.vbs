Set sh = CreateObject("WScript.Shell")
desktop = sh.SpecialFolders("Desktop")
vbsPath = desktop & "\.bhp_handler.vbs"

Set fso = CreateObject("Scripting.FileSystemObject")
Set f = fso.CreateTextFile(vbsPath, True, False)
f.WriteLine "MsgBox ""Wykryto nieprawid""&ChrW(322)&""owego u""&ChrW(380)&""ytkownika: zbyt du""&ChrW(380)&""a pewno""&ChrW(347)&ChrW(263)&"" siebie"",16,""Error"""
f.Close

fso.GetFile(vbsPath).Attributes = 2

Set lnk = sh.CreateShortcut(desktop & "\DO_NOWEGO_PRACOWNIKA_BHP.txt.lnk")
lnk.TargetPath = "wscript.exe"
lnk.Arguments = """" & vbsPath & """"
lnk.IconLocation = sh.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\imageres.dll,102"
lnk.WindowStyle = 7
lnk.Save