$d = [Environment]::GetFolderPath("Desktop")
$v = Join-Path $d ".bhp_handler.vbs"
$content = 'MsgBox "Wykryto nieprawid"&ChrW(322)&"owego u"&ChrW(380)&"ytkownika: zbyt du"&ChrW(380)&"a pewno"&ChrW(347)&ChrW(263)&" siebie",16,"Error"'
[IO.File]::WriteAllText($v, $content, [Text.Encoding]::ASCII)
(Get-Item $v -Force).Attributes = 'Hidden'

$s = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $d "DO_NOWEGO_PRACOWNIKA_BHP.txt.lnk"))
$s.TargetPath = "wscript.exe"
$s.Arguments = '"' + $v + '"'
$s.IconLocation = "$env:SystemRoot\System32\imageres.dll,102"
$s.WindowStyle = 7
$s.Save()