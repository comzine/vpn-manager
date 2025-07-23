package handlers

import (
	"encoding/json"
	"html/template"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"vpn-web/internal/vpn"
)

type Handlers struct {
	vpnManager   *vpn.Manager
	templatePath string
}

func NewHandlers(vm *vpn.Manager) *Handlers {
	return &Handlers{vpnManager: vm, templatePath: "web/templates"}
}

func (h *Handlers) SetTemplatePath(path string) {
	h.templatePath = path
}

func (h *Handlers) IndexHandler(w http.ResponseWriter, r *http.Request) {
	tmpl, err := template.ParseFiles(filepath.Join(h.templatePath, "index.html"))
	if err != nil {
		http.Error(w, "Template error", http.StatusInternalServerError)
		return
	}

	// Passwort-Status aus Keychain abrufen
	passwordStatus := h.vpnManager.HasStoredPasswords()

	data := struct {
		Settings       interface{}
		PasswordStatus map[string]bool
	}{
		Settings:       h.vpnManager.Settings,
		PasswordStatus: passwordStatus,
	}

	tmpl.Execute(w, data)
}

func (h *Handlers) StatusHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"connected": h.vpnManager.IsConnected()})
}

func (h *Handlers) SettingsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	if err := r.ParseMultipartForm(32 << 20); err != nil {
		h.sendJSON(w, false, "Form error: "+err.Error())
		return
	}

	// Alter Benutzername für Keychain-Bereinigung
	oldUsername := h.vpnManager.Settings.Username

	// Update settings (ohne Passwörter)
	h.vpnManager.Settings.VPNServer = r.FormValue("vpn_server")
	h.vpnManager.Settings.AuthGroup = r.FormValue("auth_group")
	h.vpnManager.Settings.Username = r.FormValue("username")
	h.vpnManager.Settings.Networks = r.FormValue("networks")

	// Bei Benutzername-Änderung alte Passwörter löschen
	if oldUsername != "" && oldUsername != h.vpnManager.Settings.Username {
		h.vpnManager.ClearStoredPasswords(oldUsername)
	}

	// Passwörter in Keychain speichern
	var errors []string

	if vpnPassword := r.FormValue("password"); vpnPassword != "" {
		if err := h.vpnManager.SaveVPNPassword(vpnPassword); err != nil {
			errors = append(errors, "VPN-Passwort: "+err.Error())
		}
	}

	if certPassword := r.FormValue("cert_password"); certPassword != "" {
		if err := h.vpnManager.SaveCertPassword(certPassword); err != nil {
			errors = append(errors, "Zertifikat-Passwort: "+err.Error())
		}
	}

	if sudoPassword := r.FormValue("sudo_password"); sudoPassword != "" {
		if err := h.vpnManager.SaveSudoPassword(sudoPassword); err != nil {
			errors = append(errors, "Sudo-Passwort: "+err.Error())
		}
	}

	// Handle certificate upload
	if file, header, err := r.FormFile("certificate"); err == nil {
		defer file.Close()

		filename := header.Filename
		if !strings.HasSuffix(strings.ToLower(filename), ".pfx") &&
			!strings.HasSuffix(strings.ToLower(filename), ".p12") {
			h.sendJSON(w, false, "Nur .pfx und .p12 Dateien erlaubt")
			return
		}

		certPath := filepath.Join(h.vpnManager.GetCertDir(), filename)
		if outFile, err := os.Create(certPath); err == nil {
			defer outFile.Close()
			io.Copy(outFile, file)
			h.vpnManager.Settings.CertFile = certPath
			h.vpnManager.Settings.CertFileName = filename
		}
	}

	if err := h.vpnManager.SaveSettings(); err != nil {
		h.sendJSON(w, false, "Save error: "+err.Error())
		return
	}

	message := "Einstellungen gespeichert"
	if len(errors) > 0 {
		message += " (Keychain-Fehler: " + strings.Join(errors, ", ") + ")"
	}

	h.sendJSON(w, true, message)
}

func (h *Handlers) ConnectHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	success, message := h.vpnManager.Connect()
	h.sendJSON(w, success, message)
}

func (h *Handlers) DisconnectHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	success, message := h.vpnManager.Disconnect()
	h.sendJSON(w, success, message)
}

func (h *Handlers) sendJSON(w http.ResponseWriter, success bool, message string) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": success,
		"message": message,
	})
}
