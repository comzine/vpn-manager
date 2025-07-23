let isConnected = false;
let isConnecting = false;

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
  fetch("/status")
    .then((r) => r.json())
    .then((data) => {
      isConnected = data.connected;
      const status = document.getElementById("status");
      status.textContent = data.connected ? "✅ Verbunden" : "❌ Getrennt";
      status.className = `status ${
        data.connected ? "connected" : "disconnected"
      }`;

      document.getElementById("connect-btn").disabled =
        data.connected || isConnecting;
      document.getElementById("disconnect-btn").disabled = !data.connected;

      ["connect-btn", "disconnect-btn"].forEach((id) =>
        document.getElementById(id).classList.remove("loading")
      );
    })
    .catch((err) => {
      console.error("Status update failed:", err);
      showToast("Fehler beim Status-Update: " + err, "error");
    });
}

function apiCall(endpoint, successMsg, errorPrefix) {
  return fetch(endpoint, { method: "POST" })
    .then((r) => r.json())
    .then((data) => {
      showToast(
        data.message,
        data.success ? "success" : "error",
        data.success ? 5000 : 0
      );
      setTimeout(updateStatus, 1000);
    })
    .catch((err) => {
      console.error("API call failed:", err);
      showToast(errorPrefix + err, "error", 0);
    });
}

function connectVPN() {
  if (isConnecting || isConnected) return;
  isConnecting = true;
  setButtonLoading("connect-btn", true);
  apiCall("/connect", "Verbunden", "Verbindungsfehler: ").finally(() => {
    isConnecting = false;
    setButtonLoading("connect-btn", false);
  });
}

function disconnectVPN() {
  setButtonLoading("disconnect-btn", true);
  apiCall("/disconnect", "Getrennt", "Trennungsfehler: ").finally(() => {
    setButtonLoading("disconnect-btn", false);
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

  if (password) {
    formData.append("password", password);
    console.log("VPN password added");
  }
  if (certPassword) {
    formData.append("cert_password", certPassword);
    console.log("Cert password added");
  }
  if (sudoPassword) {
    formData.append("sudo_password", sudoPassword);
    console.log("Sudo password added");
  }

  // Zertifikat-Upload
  const certFile = document.getElementById("certificate").files[0];
  if (certFile) {
    formData.append("certificate", certFile);
    console.log("Certificate file added:", certFile.name);
  }

  console.log("Sending form data to /settings...");

  fetch("/settings", {
    method: "POST",
    body: formData,
  })
    .then((response) => {
      console.log("Response received:", response.status);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    })
    .then((data) => {
      console.log("Response data:", data);
      setButtonLoading("save-btn", false);
      showToast(data.message, data.success ? "success" : "error");

      if (data.success) {
        // Passwort-Felder leeren nach erfolgreichem Speichern
        document.getElementById("password").value = "";
        document.getElementById("cert_password").value = "";
        document.getElementById("sudo_password").value = "";

        showToast("Passwörter sicher in Keychain gespeichert! 🔐", "success");

        // Seite nach kurzer Verzögerung neu laden um Status zu aktualisieren
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

// Event Listeners
document.addEventListener("DOMContentLoaded", () => {
  console.log("DOM loaded, setting up event listeners");

  // Button Event Listeners
  const connectBtn = document.getElementById("connect-btn");
  const disconnectBtn = document.getElementById("disconnect-btn");
  const saveBtn = document.getElementById("save-btn");
  const settingsToggle = document.getElementById("settings-toggle");

  if (connectBtn) {
    connectBtn.onclick = connectVPN;
    console.log("Connect button listener added");
  } else {
    console.error("Connect button not found");
  }

  if (disconnectBtn) {
    disconnectBtn.onclick = disconnectVPN;
    console.log("Disconnect button listener added");
  } else {
    console.error("Disconnect button not found");
  }

  if (saveBtn) {
    saveBtn.onclick = saveSettings;
    console.log("Save button listener added");
  } else {
    console.error("Save button not found");
  }

  if (settingsToggle) {
    settingsToggle.onclick = () =>
      togglePanel("settings-toggle", "settings-panel");
    console.log("Settings toggle listener added");
  } else {
    console.error("Settings toggle not found");
  }

  // Initial status update
  updateStatus();

  // Periodic status updates
  setInterval(updateStatus, 5000);

  console.log("All event listeners set up successfully");
});
