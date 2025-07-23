// internal/keychain/keychain.go
package keychain

import (
	"os/exec"
	"strings"
)

type KeychainManager struct {
	serviceName string
}

func NewKeychainManager() *KeychainManager {
	return &KeychainManager{serviceName: "vpn-web-manager"}
}

func (k *KeychainManager) StorePassword(account, password string) error {
	cmd := exec.Command("security", "add-generic-password",
		"-s", k.serviceName,
		"-a", account,
		"-w", password,
		"-U") // Update if exists
	return cmd.Run()
}

func (k *KeychainManager) GetPassword(account string) (string, error) {
	cmd := exec.Command("security", "find-generic-password",
		"-s", k.serviceName,
		"-a", account,
		"-w") // Only return password

	output, err := cmd.Output()
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(string(output)), nil
}

func (k *KeychainManager) DeletePassword(account string) error {
	cmd := exec.Command("security", "delete-generic-password",
		"-s", k.serviceName,
		"-a", account)
	return cmd.Run()
}
