package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
)

type Task struct {
	AgentID string `json:"agent_id"`
	Command string `json:"command"`
}

func main() {
	reader := bufio.NewReader(os.Stdin)

	fmt.Print("Enter Agent ID: ")
	agentID, _ := reader.ReadString('\n')
	agentID = strings.TrimSpace(agentID)

	fmt.Print("Enter Command to Assign: ")
	command, _ := reader.ReadString('\n')
	command = strings.TrimSpace(command)

	url := fmt.Sprintf("http://localhost:8080/assign-task?id=%s", agentID)

	task := Task{
		AgentID: agentID,
		Command: command,
	}
	jsonBody, err := json.Marshal(task)
	if err != nil {
		fmt.Println("Error encoding JSON:", err)
		return
	}

	req, err := http.NewRequest("POST", url, strings.NewReader(string(jsonBody)))
	if err != nil {
		fmt.Println("Error creating request:", err)
		return
	}

	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Println("Error sending request:", err)
		return
	}
	defer resp.Body.Close()

	fmt.Println("Command assigned successfully.")
}
