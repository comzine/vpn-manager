package vpn

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
	"vpn-web/internal/keychain"
	"vpn-web/internal/models"
)

type Manager struct {
	Settings     models.Settings
	settingsFile string
	certDir      string
	keychain     *keychain.KeychainManager
}

func NewVPNManager() *Manager {
	homeDir, _ := os.UserHomeDir()
	vm := &Manager{
		settingsFile: filepath.Join(homeDir, ".vpn_web_settings.json"),
		certDir:      filepath.Join(homeDir, ".vpn_certificates"),
		keychain:     keychain.NewKeychainManager(),
		Settings: models.Settings{
			VPNServer:   "vpn.server.de",
			AuthGroup:   "",
			Networks:    "172.16.1.0/24 192.168.13.0/24 10.33.38.0/24",
			UseKeychain: true, // Standard: Keychain verwenden
		},
	}
	os.MkdirAll(vm.certDir, 0700) // Restriktivere Berechtigung
	vm.loadSettings()
	return vm
}

func (vm *Manager) loadSettings() {
	if data, err := os.ReadFile(vm.settingsFile); err == nil {
		json.Unmarshal(data, &vm.Settings)
	}

	// Sicherstellen dass UseKeychain aktiviert ist
	if !vm.Settings.UseKeychain {
		vm.Settings.UseKeychain = true
		vm.SaveSettings()
	}
}

func (vm *Manager) SaveSettings() error {
	// Timestamps setzen
	vm.Settings.LastModified = time.Now().Format(time.RFC3339)
	if vm.Settings.CreatedAt == "" {
		vm.Settings.CreatedAt = vm.Settings.LastModified
	}

	data, err := json.MarshalIndent(vm.Settings, "", "  ")
	if err != nil {
		return err
	}

	// Datei mit restriktiven Berechtigungen speichern
	return os.WriteFile(vm.settingsFile, data, 0600)
}

// Passwort-Management Methoden
func (vm *Manager) SaveVPNPassword(password string) error {
	if vm.Settings.Username == "" {
		return fmt.Errorf("Benutzername muss gesetzt sein")
	}
	return vm.keychain.StorePassword(vm.Settings.Username+"_vpn", password)
}

func (vm *Manager) SaveCertPassword(password string) error {
	if vm.Settings.Username == "" {
		return fmt.Errorf("Benutzername muss gesetzt sein")
	}
	return vm.keychain.StorePassword(vm.Settings.Username+"_cert", password)
}

func (vm *Manager) SaveSudoPassword(password string) error {
	if vm.Settings.Username == "" {
		return fmt.Errorf("Benutzername muss gesetzt sein")
	}
	return vm.keychain.StorePassword(vm.Settings.Username+"_sudo", password)
}

func (vm *Manager) GetVPNPassword() (string, error) {
	if vm.Settings.Username == "" {
		return "", fmt.Errorf("Benutzername nicht gesetzt")
	}
	return vm.keychain.GetPassword(vm.Settings.Username + "_vpn")
}

func (vm *Manager) GetCertPassword() (string, error) {
	if vm.Settings.Username == "" {
		return "", fmt.Errorf("Benutzername nicht gesetzt")
	}
	return vm.keychain.GetPassword(vm.Settings.Username + "_cert")
}

func (vm *Manager) GetSudoPassword() (string, error) {
	if vm.Settings.Username == "" {
		return "", fmt.Errorf("Benutzername nicht gesetzt")
	}
	return vm.keychain.GetPassword(vm.Settings.Username + "_sudo")
}

// Passwort-Status prüfen
func (vm *Manager) HasStoredPasswords() map[string]bool {
	if vm.Settings.Username == "" {
		return map[string]bool{
			"vpn_password":  false,
			"cert_password": false,
			"sudo_password": false,
		}
	}

	vpnPassword, _ := vm.keychain.GetPassword(vm.Settings.Username + "_vpn")
	certPassword, _ := vm.keychain.GetPassword(vm.Settings.Username + "_cert")
	sudoPassword, _ := vm.keychain.GetPassword(vm.Settings.Username + "_sudo")

	return map[string]bool{
		"vpn_password":  vpnPassword != "",
		"cert_password": certPassword != "",
		"sudo_password": sudoPassword != "",
	}
}

// Passwörter löschen (z.B. bei Benutzername-Änderung)
func (vm *Manager) ClearStoredPasswords(oldUsername string) error {
	if oldUsername == "" {
		return nil
	}

	vm.keychain.DeletePassword(oldUsername + "_vpn")
	vm.keychain.DeletePassword(oldUsername + "_cert")
	vm.keychain.DeletePassword(oldUsername + "_sudo")

	return nil
}

func (vm *Manager) Connect() (bool, string) {
	if vm.IsConnected() {
		return false, "VPN ist bereits verbunden"
	}

	if vm.Settings.CertFile == "" || !fileExists(vm.Settings.CertFile) {
		return false, "Kein gültiges Zertifikat ausgewählt"
	}

	if vm.Settings.Username == "" {
		return false, "Benutzername erforderlich"
	}

	// Passwörter aus Keychain laden
	vpnPassword, err := vm.GetVPNPassword()
	if err != nil || vpnPassword == "" {
		return false, "VPN-Passwort nicht in Keychain gefunden. Bitte in den Einstellungen speichern."
	}

	certPassword, err := vm.GetCertPassword()
	if err != nil {
		return false, "Fehler beim Laden des Zertifikat-Passworts aus Keychain"
	}

	openconnectPath := vm.findOpenConnectPath()
	vpnSlicePath := vm.findVpnSlicePath()

	if openconnectPath == "" {
		return false, "openconnect nicht gefunden"
	}
	if vpnSlicePath == "" {
		return false, "vpn-slice nicht gefunden"
	}

	// Verbindung asynchron starten
	go vm.connectAsync(openconnectPath, vpnSlicePath, vpnPassword, certPassword)

	return true, "VPN-Verbindung wird gestartet... (Status wird automatisch aktualisiert)"
}

func (vm *Manager) connectAsync(openconnectPath, vpnSlicePath, vpnPassword, certPassword string) {
	fmt.Printf("Starting async VPN connection...\n")

	args := []string{
		openconnectPath,
		vm.Settings.VPNServer,
		"--authgroup=" + vm.Settings.AuthGroup,
		"--user=" + vm.Settings.Username,
		"-c", vm.Settings.CertFile,
		"--pid-file=/tmp/openconnect.pid",
		"-s", vpnSlicePath + " " + vm.Settings.Networks,
	}

	cmd := exec.Command("sudo", args...)

	// Pipes für Output
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		fmt.Printf("Stdout pipe error: %v\n", err)
		return
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		fmt.Printf("Stderr pipe error: %v\n", err)
		return
	}

	stdin, err := cmd.StdinPipe()
	if err != nil {
		fmt.Printf("Stdin pipe error: %v\n", err)
		return
	}

	// Starten
	err = cmd.Start()
	if err != nil {
		fmt.Printf("Start error: %v\n", err)
		return
	}

	fmt.Printf("OpenConnect process started with PID: %d\n", cmd.Process.Pid)

	// Passwörter senden
	go func() {
		defer stdin.Close()
		time.Sleep(2 * time.Second)

		// Zertifikat-Passwort (falls vorhanden)
		if certPassword != "" {
			fmt.Printf("Sending certificate password...\n")
			fmt.Fprintf(stdin, "%s\n", certPassword)
			time.Sleep(2 * time.Second)
		}

		// VPN-Passwort
		fmt.Printf("Sending VPN password...\n")
		fmt.Fprintf(stdin, "%s\n", vpnPassword)
	}()

	// Output überwachen
	connected := make(chan bool, 1)
	failed := make(chan string, 1)

	// Stdout überwachen
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			line := scanner.Text()
			fmt.Printf("VPN Output: %s\n", line)

			if strings.Contains(line, "CSTP connected") ||
				strings.Contains(line, "Configured as") ||
				strings.Contains(line, "VPN tunnel running") ||
				strings.Contains(line, "Connected tun") {
				fmt.Printf("Connection established detected!\n")
				connected <- true
				return
			}
		}
	}()

	// Stderr überwachen
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			line := scanner.Text()
			fmt.Printf("VPN Error: %s\n", line)

			if strings.Contains(line, "Login failed") ||
				strings.Contains(line, "Failed to decrypt") ||
				strings.Contains(line, "Authentication failed") ||
				strings.Contains(line, "Certificate verification failed") {
				fmt.Printf("Connection failed detected!\n")
				failed <- line
				return
			}
		}
	}()

	// Auf Verbindungsstatus warten (aber nicht zu lange)
	select {
	case <-connected:
		fmt.Printf("VPN successfully connected - process continues in background\n")
		// Prozess läuft weiter, wir kehren zurück
		return

	case errMsg := <-failed:
		fmt.Printf("VPN connection failed: %s\n", errMsg)
		cmd.Process.Kill()
		return

	case <-time.After(45 * time.Second):
		fmt.Printf("Connection timeout reached, checking if connected...\n")
		// Nach Timeout prüfen ob Verbindung trotzdem da ist
		time.Sleep(3 * time.Second)
		if vm.IsConnected() {
			fmt.Printf("VPN connected despite timeout\n")
			return
		}

		fmt.Printf("Connection timeout - killing process\n")
		cmd.Process.Kill()
		return
	}

	// Dieser Code wird nie erreicht, aber zur Sicherheit
	// cmd.Wait() NICHT aufrufen - das würde ewig warten!
}

// Verbesserte IsConnected Methode
func (vm *Manager) IsConnected() bool {
	// PID-Datei prüfen
	if fileExists("/tmp/openconnect.pid") {
		if pidData, err := os.ReadFile("/tmp/openconnect.pid"); err == nil {
			pid := strings.TrimSpace(string(pidData))
			if pid != "" && exec.Command("kill", "-0", pid).Run() == nil {
				return true
			}
		}
		os.Remove("/tmp/openconnect.pid")
	}

	// Prozess-Suche
	if output, err := exec.Command("pgrep", "-f", "openconnect").Output(); err == nil {
		return len(strings.TrimSpace(string(output))) > 0
	}

	// Netzwerk-Interface prüfen
	if output, err := exec.Command("ifconfig").Output(); err == nil {
		return strings.Contains(string(output), "192.168.255.")
	}

	return false
}

func (vm *Manager) connectDirect(openconnectPath, vpnSlicePath, vpnPassword, certPassword string) (bool, string) {
	args := []string{
		openconnectPath,
		vm.Settings.VPNServer,
		"--authgroup=" + vm.Settings.AuthGroup,
		"--user=" + vm.Settings.Username,
		"-c", vm.Settings.CertFile,
		"--pid-file=/tmp/openconnect.pid",
		"-s", vpnSlicePath + " " + vm.Settings.Networks,
	}

	cmd := exec.Command("sudo", args...)

	// Pipes für Output
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return false, fmt.Sprintf("Stdout pipe error: %v", err)
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		return false, fmt.Sprintf("Stderr pipe error: %v", err)
	}

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return false, fmt.Sprintf("Stdin pipe error: %v", err)
	}

	// Starten
	err = cmd.Start()
	if err != nil {
		return false, fmt.Sprintf("Start error: %v", err)
	}

	// Passwörter senden
	go func() {
		defer stdin.Close()
		time.Sleep(2 * time.Second)

		// Zertifikat-Passwort (falls vorhanden)
		if certPassword != "" {
			fmt.Fprintf(stdin, "%s\n", certPassword)
			time.Sleep(2 * time.Second)
		}

		// VPN-Passwort
		fmt.Fprintf(stdin, "%s\n", vpnPassword)
	}()

	// Output überwachen bis Verbindung hergestellt
	connected := make(chan bool, 1)
	failed := make(chan string, 1)

	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			line := scanner.Text()
			fmt.Printf("VPN Output: %s\n", line)

			if strings.Contains(line, "CSTP connected") ||
				strings.Contains(line, "Configured as") {
				connected <- true
				return
			}
		}
	}()

	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			line := scanner.Text()
			fmt.Printf("VPN Error: %s\n", line)

			if strings.Contains(line, "Login failed") ||
				strings.Contains(line, "Failed to decrypt") ||
				strings.Contains(line, "Authentication failed") {
				failed <- line
				return
			}
		}
	}()

	// Warten auf Erfolg oder Fehler
	select {
	case <-connected:
		fmt.Printf("VPN erfolgreich verbunden - Prozess läuft weiter\n")
		// NICHT cmd.Wait() aufrufen - Prozess soll weiterlaufen!
		return true, "VPN erfolgreich verbunden"

	case errMsg := <-failed:
		cmd.Process.Kill()
		return false, fmt.Sprintf("Verbindung fehlgeschlagen: %s", errMsg)

	case <-time.After(60 * time.Second):
		cmd.Process.Kill()
		return false, "Timeout beim Verbinden"
	}
}

func (vm *Manager) Disconnect() (bool, string) {
	if !vm.IsConnected() {
		return true, "VPN ist bereits getrennt"
	}

	// Prüfe ob passwordless sudo funktioniert
	testCmd := exec.Command("sudo", "-n", "killall", "--help")
	if testCmd.Run() != nil {
		// Sudo-Passwort aus Keychain versuchen
		sudoPassword, err := vm.GetSudoPassword()
		if err == nil && sudoPassword != "" {
			return vm.disconnectWithExpect(sudoPassword)
		}
		return false, "Sudo-Berechtigung erforderlich. Bitte Sudo-Passwort in Einstellungen speichern oder passwordless sudo konfigurieren."
	}

	// Verwende direkte Methode (passwordless sudo)
	return vm.disconnectDirect()
}

func (vm *Manager) disconnectWithExpect(sudoPassword string) (bool, string) {
	// Temporäres expect-Script erstellen
	expectScript, err := os.CreateTemp("", "vpn-disconnect-*.exp")
	if err != nil {
		return false, "Konnte disconnect expect-script nicht erstellen"
	}
	defer os.Remove(expectScript.Name())
	defer expectScript.Close()

	scriptContent := fmt.Sprintf(`#!/usr/bin/expect -f
set timeout 15

# Killall versuchen
spawn sudo killall -KILL openconnect
expect {
    "Password:" {
        send "%s\r"
        expect eof
    }
    eof {}
    timeout {}
}

# PID-Datei löschen
spawn sudo rm -f /tmp/openconnect.pid
expect {
    "Password:" {
        send "%s\r"
        expect eof
    }
    eof {}
    timeout {}
}

# Pkill als Fallback
spawn sudo pkill -KILL -f openconnect
expect {
    "Password:" {
        send "%s\r"
        expect eof
    }
    eof {}
    timeout {}
}

puts "Disconnect-Befehle ausgeführt"
exit 0
`, sudoPassword, sudoPassword, sudoPassword)

	expectScript.WriteString(scriptContent)
	expectScript.Close()
	os.Chmod(expectScript.Name(), 0700)

	// Expect-Script ausführen
	cmd := exec.Command("expect", expectScript.Name())
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err = cmd.Run()

	fmt.Printf("Disconnect Expect Output: %s\n", stdout.String())
	if stderr.Len() > 0 {
		fmt.Printf("Disconnect Expect Error: %s\n", stderr.String())
	}

	// Warten und prüfen
	time.Sleep(3 * time.Second)

	if !vm.IsConnected() {
		return true, "VPN mit expect getrennt"
	}

	return false, "Disconnect mit expect unsicher"
}

func (vm *Manager) disconnectDirect() (bool, string) {
	commands := [][]string{
		{"sudo", "killall", "-KILL", "openconnect"},
		{"sudo", "pkill", "-KILL", "-f", "openconnect"},
		{"sudo", "rm", "-f", "/tmp/openconnect.pid"},
	}

	var messages []string
	for _, cmdArgs := range commands {
		cmd := exec.Command(cmdArgs[0], cmdArgs[1:]...)
		if err := cmd.Run(); err == nil {
			messages = append(messages, strings.Join(cmdArgs, " ")+" OK")
		} else {
			messages = append(messages, strings.Join(cmdArgs, " ")+" FAILED: "+err.Error())
		}
		time.Sleep(time.Second)
	}

	time.Sleep(2 * time.Second)

	if !vm.IsConnected() {
		return true, "VPN getrennt: " + strings.Join(messages, "; ")
	}

	return false, "Disconnect unsicher: " + strings.Join(messages, "; ")
}

func (vm *Manager) findOpenConnectPath() string {
	paths := []string{"/usr/local/bin/openconnect", "/opt/homebrew/bin/openconnect"}
	for _, path := range paths {
		if fileExists(path) {
			return path
		}
	}
	if path, err := exec.LookPath("openconnect"); err == nil {
		return path
	}
	return ""
}

func (vm *Manager) findVpnSlicePath() string {
	homeDir, _ := os.UserHomeDir()
	paths := []string{
		filepath.Join(homeDir, ".bin", "vpnslice"),
		filepath.Join(homeDir, ".local", "bin", "vpn-slice"),
		"/usr/local/bin/vpn-slice",
		"/opt/homebrew/bin/vpn-slice",
	}

	for _, path := range paths {
		if fileExists(path) && exec.Command(path, "--version").Run() == nil {
			return path
		}
	}
	return ""
}

func (vm *Manager) GetCertDir() string {
	return vm.certDir
}

func fileExists(filename string) bool {
	_, err := os.Stat(filename)
	return !os.IsNotExist(err)
}
