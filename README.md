# VPN Manager für macOS

Ein einfacher VPN-Manager mit Web-Interface für sichere VPN-Verbindungen.

## 🚀 Installation (3 Schritte)

### 1. ZIP-Datei entpacken

- Laden Sie `vpn-manager-v1.0.zip` herunter
- Doppelklick zum Entpacken
- Ordner an gewünschten Ort verschieben (z.B. `~/Applications/vpn-manager/`)

### 2. Installation ausführen

```bash
cd vpn-manager
./install-macos.sh
```

Das Script installiert automatisch alle benötigten Komponenten (Homebrew, OpenConnect, etc.).

### 3. Autostart aktivieren (empfohlen)

```bash
./setup-autostart.sh
```

**Fertig!** 🎉 Der VPN Manager startet automatisch und ist unter http://localhost:8080 erreichbar.

## 📱 Verwendung

1. **Web-Interface öffnen**: http://localhost:8080
2. **Einstellungen konfigurieren**:
   - VPN-Server eingeben
   - Benutzername und Passwort
   - Zertifikat-Datei (.pfx/.p12) hochladen
3. **"Verbinden" klicken** ✅

## 🔒 Sicherheit

- **Passwörter werden** in der macOS Keychain gespeichert

## ❓ Häufige Probleme

**"Verbindung fehlgeschlagen"**
→ Prüfen Sie Benutzername, Passwort und Zertifikat in den Einstellungen

**"Web-Interface nicht erreichbar"**
→ Terminal öffnen und eingeben: `launchctl start com.vpnweb`

**"Sudo-Passwort erforderlich"**
→ Ihr macOS-Benutzer-Passwort in den Einstellungen speichern

## 🛠️ Deinstallation

```bash
cd vpn-manager
./uninstall-macos.sh
```

## 💡 Support

Bei Problemen:

1. Web-Interface → Einstellungen → alle Felder prüfen
2. Terminal: `tail -f ~/Library/Logs/vpn-web.error.log`

---

**Systemanforderungen**: macOS 10.15+ • Administratorrechte für Installation
