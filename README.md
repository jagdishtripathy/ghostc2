# 👻 GhostC2 - Advanced Command & Control Framework

[![GitHub](https://img.shields.io/badge/GitHub-jagdishtripathy-blue?logo=github)](https://github.com/jagdishtripathy)

A modern, feature-rich Command & Control (C2) framework designed for security testing, penetration testing, and red team operations. GhostC2 provides a web-based dashboard for managing multiple agents across different platforms.

---

## 🚀 Features

- **Multi-Platform Support**: Windows PowerShell, Linux Bash, macOS, and Python agents
- **Cross-Platform Python Agent**: Works on Windows, Linux, and macOS
- **Web-Based Dashboard**: Modern, responsive interface with real-time updates
- **Authentication System**: Secure login/logout with session management
- **Command History**: Track all executed commands with status and timestamps
- **File Management**: Upload/download files to/from agents
- **Screenshot & Process Management**: Request screenshots and process lists from agents
- **Quick Actions**: Pre-defined common commands for rapid execution
- **Agent Management**: Easy agent registration and script generation
- **Beautiful UI**: Modern dark theme, responsive design, and toast notifications

---

## 📁 Project Structure

```
ghostc2/
├── server/                 # Go server application
│   ├── main.go            # Main server logic
│   ├── static/            # Web dashboard files
│   │   ├── index.html     # Dashboard interface
│   │   ├── script.js      # Dashboard JavaScript
│   │   └── style.css      # Dashboard styling
│   └── tasks.json         # Task storage
├── agents/                # Agent implementations
│   ├── windows_agent.ps1  # Windows PowerShell agent
│   ├── linux_agent.sh     # Linux Bash agent
│   ├── mac_agent.sh       # macOS Bash agent
│   └── python_agent.py    # Cross-platform Python agent
├── payloads/              # Payload files
│   ├── reverse_shell.js   # JavaScript reverse shell
│   └── xss.html           # XSS payload generator
├── evasion/               # Evasion techniques
│   └── encode_command.bat # Command encoding tool
└── cli/                   # Command-line tools
    └── assign.go          # CLI task assignment tool
```

---

## 🛠️ Installation

### Prerequisites
- **Go** (1.19 or higher) - [Download](https://golang.org/dl/)
- **PowerShell** (for Windows agents)
- **Bash** and **curl** (for Linux/macOS agents)
- **Python 3.6+** (for Python agent - optional but recommended)

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/jagdishtripathy/ghostc2.git
   cd ghostc2
   ```
2. **Start the server**:
   ```bash
   go run server/main.go
   ```
3. **Access the dashboard**:
   Open your browser and navigate to `http://localhost:8080`

---

## 🎯 Usage

### Starting the Server
```bash
# From the project root
go run server/main.go

# Or build and run
go build -o ghostc2 server/main.go
./ghostc2
```
The server will start on `http://localhost:8080` with the following endpoints:
- `GET /` - Web dashboard
- `POST /login` - Login endpoint
- `POST /logout` - Logout endpoint
- `GET /auth-check` - Session check
- `GET /register?id=<agent_id>` - Register agent
- `GET /get-task?id=<agent_id>` - Get command for agent
- `POST /submit-result` - Submit command result
- `GET /api/agents` - List registered agents
- `POST /api/send` - Send command to agent
- `GET /api/results` - Get command results
- `GET /api/history` - Get command history
- `POST /api/upload` - Upload file to agent
- `GET /api/download` - Download file from agent
- `GET /api/screenshot` - Request screenshot from agent
- `GET /api/processes` - Request process list from agent

### Login Credentials
- **Username:** `ghostc2`
- **Password:** `ghostc2`

---

## 🤖 Agent Usage

### Windows Agent (PowerShell)
1. **Run the PowerShell agent**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File agents/windows_agent.ps1
   ```
2. **Or generate a custom script** from the dashboard
3. **Features**:
   - Automatic agent registration
   - Command execution with error handling
   - Result submission to server
   - 15-second polling interval

### Linux Agent (Bash)
1. **Make the script executable**:
   ```bash
   chmod +x agents/linux_agent.sh
   ```
2. **Run the agent**:
   ```bash
   ./agents/linux_agent.sh
   ```
3. **Features**:
   - System information display
   - Automatic dependency checking (curl, jq)
   - Enhanced error handling
   - Platform-specific commands

### macOS Agent (Bash)
1. **Make the script executable**:
   ```bash
   chmod +x agents/mac_agent.sh
   ```
2. **Run the agent**:
   ```bash
   ./agents/mac_agent.sh
   ```
3. **Features**:
   - macOS-specific system information
   - Hardware and software detection
   - macOS tool availability checking
   - Enhanced security features

### Python Agent (Cross-Platform)
1. **Run the Python agent**:
   ```bash
   python3 agents/python_agent.py
   ```
2. **Or on Windows**:
   ```cmd
   python agents/python_agent.py
   ```
3. **Features**:
   - Works on Windows, Linux, and macOS
   - Automatic platform detection
   - Colored output (except Windows)
   - Enhanced error handling and timeouts
   - Detailed system information

### Agent Configuration
All agents can be configured by modifying these variables:
- `SERVER_URL`: The GhostC2 server address (default: `http://localhost:8080`)
- `POLLING_INTERVAL`: How often to check for commands (default: 15 seconds)
- `AGENT_ID`: Unique identifier for the agent (auto-generated)

---

## 🌐 Network Configuration

### Local Testing
- Server: `http://localhost:8080`
- Agents: Use `localhost` or `127.0.0.1`

### Remote Testing
- Server: `http://YOUR_IP:8080`
- Agents: Use your server's IP address
- Ensure firewall allows port 8080

### Example Remote Setup
```bash
# On server machine (192.168.1.100)
go run server/main.go

# On target machines, modify agent scripts:
# Change SERVER_URL to: http://192.168.1.100:8080
```

---

## 🎨 Dashboard Features
- **Login/Logout**: Secure authentication system
- **Agent Management**: Register, view, and select agents
- **Command Execution**: Send commands and view results
- **Command History**: Track all commands with status and output
- **File Management**: Upload/download files to/from agents
- **Screenshot & Process List**: Request screenshots and process lists
- **Quick Actions**: Pre-defined commands for rapid use
- **Beautiful UI**: Modern, responsive, and dark-themed

---

## 🛡️ Security Considerations
- **Authorized Use Only**: Only use this tool on systems you own or have explicit permission to test
- **Legal Compliance**: Ensure compliance with local laws and regulations
- **Network Security**: Use in isolated testing environments
- **Access Control**: Implement proper access controls for the dashboard
- **Agent Security**: Agents run with current user privileges

---

## 🐛 Troubleshooting

### Common Issues

#### Agent Connection Problems
- **Check server URL**: Ensure agents point to correct server address
- **Verify port**: Default port is 8080
- **Network connectivity**: Test with `curl http://server:8080`
- **Firewall settings**: Allow port 8080 through firewall

#### Command Execution Issues
- **Agent registration**: Check if agent appears in dashboard
- **Command syntax**: Verify commands work in local terminal
- **Permissions**: Some commands may require elevated privileges
- **Timeout**: Commands have 30-second timeout (Python agent)

#### Platform-Specific Issues

**Windows**:
- PowerShell execution policy: Use `-ExecutionPolicy Bypass`
- Antivirus interference: May flag PowerShell scripts
- UAC prompts: Some commands require admin privileges

**Linux/macOS**:
- Script permissions: Run `chmod +x agents/*.sh`
- Missing dependencies: Install `curl` and `jq`
- Path issues: Ensure scripts are in correct directory

**Python Agent**:
- Python version: Requires Python 3.6 or higher
- Missing modules: Uses only standard library
- Path issues: Ensure Python is in PATH

### Debug Mode
Enable verbose logging by modifying agent scripts:
- Add `set -x` to bash scripts
- Add `-Verbose` to PowerShell commands
- Python agent has built-in logging

---

## 🤝 Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

---

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

---

## 👤 Author
**Jagadish Tripathy**  
[GitHub: jagdishtripathy](https://github.com/jagdishtripathy)  
VM Management Specialist | VAPT Practitioner | Penetration Tester | SOC Analyst in Training | Kali Linux & Offensive Security Expert

---

**Remember:** Always use this tool responsibly and ethically! 🛡️
