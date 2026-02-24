package main

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

// teamsPayload matches the MS Teams MessageCard format.
type teamsPayload struct {
	Type     string         `json:"@type"`
	Context  string         `json:"@context"`
	Theme    string         `json:"themeColor"`
	Summary  string         `json:"summary"`
	Sections []teamsSection `json:"sections"`
}

type teamsSection struct {
	ActivityTitle    string      `json:"activityTitle"`
	ActivitySubtitle string      `json:"activitySubtitle"`
	Facts            []teamsFact `json:"facts"`
	Markdown         bool        `json:"markdown"`
}

type teamsFact struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

func main() {
	dbHost := requireEnv("DB_HOST")
	dbPort := getEnv("DB_PORT", "3306")
	dbName := requireEnv("DB_NAME")
	dbUser := requireEnv("MYSQL_USER")
	dbPass := requireEnv("MYSQL_PASSWORD")
	webhook := requireEnv("MSTEAMS_WEBHOOK_URL")

	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?timeout=10s&parseTime=true",
		dbUser, dbPass, dbHost, dbPort, dbName)

	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("[Reporting] Failed to open DB connection: %v", err)
	}
	defer db.Close()

	db.SetConnMaxLifetime(30 * time.Second)
	db.SetMaxOpenConns(5)
	db.SetMaxIdleConns(2)

	if err := db.Ping(); err != nil {
		log.Fatalf("[Reporting] Failed to ping MySQL at %s:%s: %v", dbHost, dbPort, err)
	}
	log.Printf("[Reporting] Connected to MySQL at %s:%s/%s", dbHost, dbPort, dbName)

	count, err := countProducts(db)
	if err != nil {
		log.Fatalf("[Reporting] Failed to count products: %v", err)
	}
	log.Printf("[Reporting] Products in database: %d", count)

	payload := buildTeamsPayload(count, dbHost, dbName)
	body, err := json.Marshal(payload)
	if err != nil {
		log.Fatalf("[Reporting] Failed to marshal Teams payload: %v", err)
	}

	if err := postTeams(webhook, body); err != nil {
		log.Fatalf("[Reporting] Failed to send report: %v", err)
	}

	log.Printf("[Reporting] Report sent successfully. Products: %d", count)
}

func countProducts(db *sql.DB) (int, error) {
	var count int
	if err := db.QueryRow("SELECT COUNT(*) FROM products").Scan(&count); err != nil {
		return 0, err
	}
	return count, nil
}

func buildTeamsPayload(count int, dbHost, dbName string) teamsPayload {
	now := time.Now().UTC().Format("2006-01-02 15:04 UTC")

	return teamsPayload{
		Type:    "MessageCard",
		Context: "http://schema.org/extensions",
		Theme:   "0076D7",
		Summary: "KubiQuest Daily Report",
		Sections: []teamsSection{
			{
				ActivityTitle:    "KubiQuest Daily Report",
				ActivitySubtitle: "Automated midnight report",
				Facts: []teamsFact{
					{Name: "Products in database:", Value: fmt.Sprintf("%d", count)},
					{Name: "Report date:", Value: now},
					{Name: "Database:", Value: fmt.Sprintf("%s/%s", dbHost, dbName)},
				},
				Markdown: true,
			},
		},
	}
}

func postTeams(webhook string, body []byte) error {
	client := &http.Client{Timeout: 15 * time.Second}

	resp, err := client.Post(webhook, "application/json", bytes.NewBuffer(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("teams webhook returned unexpected status: %d", resp.StatusCode)
	}

	return nil
}

// requireEnv reads an environment variable and exits if it is missing.
func requireEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("[Reporting] Required environment variable %q is not set", key)
	}
	return v
}

// getEnv reads an environment variable with a fallback default.
func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
