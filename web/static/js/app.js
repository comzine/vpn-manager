let isConnected = false;
let isConnecting = false;
let isDisconnecting = false;

function showToast(message, type = "success", duration = 10000) {
  const container = document.getElementById("toast-container");
  const toast = document.createElement("div");
  toast.className = `toast ${type}`;
  toast.innerHTML = `<div style="padding-right: 30px;">${message}</div><button class="toast-close" onclick="hideToast(this)">×</button>`;

  container.appendChild(toast);
  setTimeout(() => toast.classList.add("show"), 10);

  if (duration > 0) {
    setTimeout(() => hideToast(toast.querySelector(".toast-close")), duration);
  }
}

function hideToast(btn) {
  const toast = btn.parentElement;
  toast.style.display = "none";
  setTimeout(() => toast.remove(), 100);
}

function setButtonLoading(buttonId, loading) {
  const button = document.getElementById(buttonId);
  if (!button) return;

  if (loading) {
    button.classList.add("loading");
    button.disabled = true;
  } else {
    button.classList.remove("loading");
    button.disabled = false;
  }
}

function updateStatus() {
  console.log("Updating status...");

  fetch("/status")
    .then((r) => {
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return r.json();
    })
    .then((data) => {
      console.log("Status response:", data);

      // Status aktualisieren
      isConnected = data.connected;

      const status = document.getElementById("status");
      if (status) {
        status.textContent = data.connected ? "✅ Verbunden" : "❌ Getrennt";
        status.className = `status ${
          data.connected ? "connected" : "disconnected"
        }`;
      }

      // Buttons direkt hier aktualisieren - NICHT in separater Funktion
      const connectBtn = document.getElementById("connect-btn");
      const disconnectBtn = document.getElementById("disconnect-btn");

      if (connectBtn && disconnectBtn) {
        // Connect Button: Aktiviert wenn NICHT verbunden UND NICHT connecting/disconnecting
        connectBtn.disabled = isConnected || isConnecting || isDisconnecting;

        // Disconnect Button: Aktiviert wenn verbunden UND NICHT disconnecting
        disconnectBtn.disabled = !isConnected || isDisconnecting;

        // Loading-Klassen entfernen wenn nicht aktiv
        if (!isConnecting) {
          connectBtn.classList.remove("loading");
        }
        if (!isDisconnecting) {
          disconnectBtn.classList.remove("loading");
        }

        console.log(
          `Buttons updated - Connect: ${
            connectBtn.disabled ? "disabled" : "enabled"
          }, Disconnect: ${disconnectBtn.disabled ? "disabled" : "enabled"}`
        );
        console.log(
          `States - Connected: ${isConnected}, Connecting: ${isConnecting}, Disconnecting: ${isDisconnecting}`
        );
      }
    })
    .catch((err) => {
      console.error("Status update failed:", err);
      showToast("Fehler beim Status-Update: " + err.message, "error", 5000);
    });
}

function connectVPN() {
  console.log("Connect VPN clicked");

  if (isConnecting || isConnected || isDisconnecting) {
    console.log("Connect blocked:", {
      isConnecting,
      isConnected,
      isDisconnecting,
    });
    return;
  }

  isConnecting = true;

  // Button sofort deaktivieren
  const connectBtn = document.getElementById("connect-btn");
  if (connectBtn) {
    connectBtn.disabled = true;
    connectBtn.classList.add("loading");
  }

  fetch("/connect", { method: "POST" })
    .then((r) => {
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return r.json();
    })
    .then((data) => {
      console.log("Connect response:", data);
      showToast(
        data.message,
        data.success ? "success" : "error",
        data.success ? 5000 : 10000
      );

      if (data.success) {
        // Häufigere Status-Updates für die nächsten 60 Sekunden
        let pollCount = 0;
        const maxPolls = 30; // 30 * 2s = 60s

        const pollInterval = setInterval(() => {
          updateStatus();
          pollCount++;

          if (pollCount >= maxPolls || isConnected) {
            clearInterval(pollInterval);
            console.log("Stopped frequent polling");
          }
        }, 2000);

        showToast(
          "Verbindung wird aufgebaut... Bitte warten Sie bis zu 60 Sekunden.",
          "info",
          5000
        );
      }
    })
    .catch((err) => {
      console.error("Connect failed:", err);
      showToast("Verbindungsfehler: " + err.message, "error", 10000);
    })
    .finally(() => {
      isConnecting = false;
      console.log("Connect operation finished");
      // Status nach kurzer Verzögerung aktualisieren
      setTimeout(updateStatus, 2000);
    });
}

function disconnectVPN() {
  console.log("Disconnect VPN clicked");

  if (isDisconnecting || !isConnected) {
    console.log("Disconnect blocked:", { isDisconnecting, isConnected });
    return;
  }

  isDisconnecting = true;

  // Button sofort deaktivieren
  const disconnectBtn = document.getElementById("disconnect-btn");
  if (disconnectBtn) {
    disconnectBtn.disabled = true;
    disconnectBtn.classList.add("loading");
  }

  fetch("/disconnect", { method: "POST" })
    .then((r) => {
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return r.json();
    })
    .then((data) => {
      console.log("Disconnect response:", data);
      showToast(
        data.message,
        data.success ? "success" : "error",
        data.success ? 5000 : 10000
      );

      // Status mehrfach aktualisieren
      setTimeout(updateStatus, 500);
      setTimeout(updateStatus, 2000);
      setTimeout(updateStatus, 5000);
    })
    .catch((err) => {
      console.error("Disconnect failed:", err);
      showToast("Trennungsfehler: " + err.message, "error", 10000);
    })
    .finally(() => {
      isDisconnecting = false;
      console.log("Disconnect operation finished, updating status...");
      setTimeout(updateStatus, 1000);
    });
}

function validateForm() {
  const requiredFields = ["vpn_server", "auth_group", "username"];
  const missingFields = [];

  requiredFields.forEach((fieldId) => {
    const field = document.getElementById(fieldId);
    if (!field || !field.value.trim()) {
      missingFields.push(fieldId.replace("_", " "));
    }
  });

  if (missingFields.length > 0) {
    showToast(`Pflichtfelder fehlen: ${missingFields.join(", ")}`, "error");
    return false;
  }

  return true;
}

function saveSettings() {
  console.log("saveSettings() called");

  if (!validateForm()) {
    return;
  }

  setButtonLoading("save-btn", true);

  const formData = new FormData();

  // Basis-Einstellungen
  formData.append("vpn_server", document.getElementById("vpn_server").value);
  formData.append("auth_group", document.getElementById("auth_group").value);
  formData.append("username", document.getElementById("username").value);
  formData.append("networks", document.getElementById("networks").value);

  // Passwörter (nur wenn eingegeben)
  const password = document.getElementById("password").value;
  const certPassword = document.getElementById("cert_password").value;
  const sudoPassword = document.getElementById("sudo_password").value;

  if (password) formData.append("password", password);
  if (certPassword) formData.append("cert_password", certPassword);
  if (sudoPassword) formData.append("sudo_password", sudoPassword);

  // Zertifikat-Upload
  const certFile = document.getElementById("certificate").files[0];
  if (certFile) formData.append("certificate", certFile);

  fetch("/settings", {
    method: "POST",
    body: formData,
  })
    .then((response) => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    })
    .then((data) => {
      console.log("Settings response:", data);
      setButtonLoading("save-btn", false);
      showToast(data.message, data.success ? "success" : "error");

      if (data.success) {
        // Passwort-Felder leeren
        document.getElementById("password").value = "";
        document.getElementById("cert_password").value = "";
        document.getElementById("sudo_password").value = "";

        showToast("Passwörter sicher in Keychain gespeichert! 🔐", "success");
        setTimeout(() => location.reload(), 2000);
      }
    })
    .catch((err) => {
      console.error("Save settings error:", err);
      setButtonLoading("save-btn", false);
      showToast("Fehler beim Speichern: " + err.message, "error");
    });
}

function togglePanel(toggleId, panelId) {
  const toggle = document.getElementById(toggleId);
  const panel = document.getElementById(panelId);
  const isActive = panel.classList.toggle("active");
  toggle.classList.toggle("active", isActive);
}

// Manuelle Button-Aktivierung für Debugging
function forceUpdateButtons() {
  console.log("Force updating buttons...");
  const connectBtn = document.getElementById("connect-btn");
  const disconnectBtn = document.getElementById("disconnect-btn");

  if (connectBtn && disconnectBtn) {
    connectBtn.disabled = false;
    disconnectBtn.disabled = true;
    connectBtn.classList.remove("loading");
    disconnectBtn.classList.remove("loading");
    console.log("Buttons force-updated: Connect enabled, Disconnect disabled");
  }
}

// Event Listeners
document.addEventListener("DOMContentLoaded", () => {
  console.log("DOM loaded, setting up event listeners");

  const connectBtn = document.getElementById("connect-btn");
  const disconnectBtn = document.getElementById("disconnect-btn");
  const saveBtn = document.getElementById("save-btn");
  const settingsToggle = document.getElementById("settings-toggle");

  if (connectBtn) {
    connectBtn.onclick = connectVPN;
    console.log("Connect button found and listener added");
  }

  if (disconnectBtn) {
    disconnectBtn.onclick = disconnectVPN;
    console.log("Disconnect button found and listener added");
  }

  if (saveBtn) {
    saveBtn.onclick = saveSettings;
  }

  if (settingsToggle) {
    settingsToggle.onclick = () =>
      togglePanel("settings-toggle", "settings-panel");
  }

  // Initial status update
  updateStatus();

  // Periodic status updates
  setInterval(updateStatus, 5000);

  // Debug: Button-Status alle 10 Sekunden loggen
  setInterval(() => {
    const connectBtn = document.getElementById("connect-btn");
    const disconnectBtn = document.getElementById("disconnect-btn");
    console.log("Button status check:", {
      connectDisabled: connectBtn?.disabled,
      disconnectDisabled: disconnectBtn?.disabled,
      isConnected,
      isConnecting,
      isDisconnecting,
    });
  }, 10000);

  console.log("Setup complete");
});

// Debug-Funktion für die Browser-Konsole
window.debugVPN = {
  forceUpdateButtons,
  getStatus: () => ({ isConnected, isConnecting, isDisconnecting }),
  updateStatus,
};
