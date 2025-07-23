package models

type Settings struct {
	VPNServer    string `json:"vpn_server"`
	AuthGroup    string `json:"auth_group"`
	Username     string `json:"username"`
	Networks     string `json:"networks"`
	CertFile     string `json:"certificate_file"`
	CertFileName string `json:"certificate_filename"`
	UseKeychain  bool   `json:"use_keychain"`
	CreatedAt    string `json:"created_at"`
	LastModified string `json:"last_modified"`
}
