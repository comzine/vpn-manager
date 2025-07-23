package main

import (
	"log"
	"net/http"
	"os"
	"path/filepath"
	"vpn-web/internal/handlers"
	"vpn-web/internal/vpn"
)

func main() {
	vm := vpn.NewVPNManager()
	h := handlers.NewHandlers(vm)

	// Web assets
	webDir := getWebDir()
	h.SetTemplatePath(filepath.Join(webDir, "templates"))
	http.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir(filepath.Join(webDir, "static")))))

	// Routes
	http.HandleFunc("/", h.IndexHandler)
	http.HandleFunc("/status", h.StatusHandler)
	http.HandleFunc("/settings", h.SettingsHandler)
	http.HandleFunc("/connect", h.ConnectHandler)
	http.HandleFunc("/disconnect", h.DisconnectHandler)

	log.Println("🔐 VPN Manager: http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func getWebDir() string {
	paths := []string{"web", "/usr/local/share/vpn-web/web"}
	for _, path := range paths {
		if _, err := os.Stat(filepath.Join(path, "templates")); err == nil {
			return path
		}
	}
	return "web"
}
