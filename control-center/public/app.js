const state = {
  settings: null,
  dashboard: null,
  remoteConfig: null,
  seasonConfig: null,
  notificationConfig: null
};

const els = {
  statusBar: document.querySelector("#statusBar"),
  lastRefreshLabel: document.querySelector("#lastRefreshLabel"),
  todayKeyLabel: document.querySelector("#todayKeyLabel"),
  yesterdayKeyLabel: document.querySelector("#yesterdayKeyLabel"),
  dailyMeta: document.querySelector("#dailyMeta"),
  weeklyMeta: document.querySelector("#weeklyMeta"),
  healthCards: document.querySelector("#healthCards"),
  todayTelemetry: document.querySelector("#todayTelemetry"),
  yesterdayTelemetry: document.querySelector("#yesterdayTelemetry"),
  todayLoadouts: document.querySelector("#todayLoadouts"),
  todayUpgrades: document.querySelector("#todayUpgrades"),
  yesterdayLoadouts: document.querySelector("#yesterdayLoadouts"),
  yesterdayUpgrades: document.querySelector("#yesterdayUpgrades"),
  dailyLeaderboard: document.querySelector("#dailyLeaderboard"),
  weeklyLeaderboard: document.querySelector("#weeklyLeaderboard"),
  backendUrlInput: document.querySelector("#backendUrlInput"),
  adminTokenInput: document.querySelector("#adminTokenInput"),
  requestTimeoutInput: document.querySelector("#requestTimeoutInput"),
  settingsPathLabel: document.querySelector("#settingsPathLabel"),
  remotePathLabel: document.querySelector("#remotePathLabel"),
  seasonPathLabel: document.querySelector("#seasonPathLabel"),
  notificationPathLabel: document.querySelector("#notificationPathLabel"),
  remoteConfigEditor: document.querySelector("#remoteConfigEditor"),
  seasonConfigEditor: document.querySelector("#seasonConfigEditor"),
  notificationConfigEditor: document.querySelector("#notificationConfigEditor"),
  remoteSummary: document.querySelector("#remoteSummary"),
  seasonSummary: document.querySelector("#seasonSummary"),
  notificationSummary: document.querySelector("#notificationSummary"),
  refreshAllButton: document.querySelector("#refreshAllButton"),
  sendDigestButton: document.querySelector("#sendDigestButton"),
  settingsForm: document.querySelector("#settingsForm"),
  saveRemoteConfigButton: document.querySelector("#saveRemoteConfigButton"),
  saveSeasonConfigButton: document.querySelector("#saveSeasonConfigButton"),
  saveNotificationConfigButton: document.querySelector("#saveNotificationConfigButton")
};

async function request(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: {
      Accept: "application/json",
      ...(options.body ? { "Content-Type": "application/json" } : {}),
      ...(options.headers || {})
    }
  });
  const payload = await response.json();
  if (!response.ok || payload.ok === false) {
    const message = payload.error || payload.message || payload.messageKey || `Request failed: ${response.status}`;
    throw new Error(message);
  }
  return payload;
}

function formatNumber(value, digits = 0) {
  const numeric = Number(value || 0);
  return new Intl.NumberFormat("it-IT", {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits
  }).format(numeric);
}

function notify(message, type = "good") {
  const pill = document.createElement("div");
  pill.className = `status-pill ${type}`;
  pill.textContent = message;
  els.statusBar.prepend(pill);
  setTimeout(() => pill.remove(), 5000);
}

function setStatusPills() {
  els.statusBar.innerHTML = "";
  if (!state.dashboard) {
    return;
  }
  const health = state.dashboard.backendHealth?.payload || {};
  const admin = state.dashboard.adminOverview || {};
  const overview = admin.payload || {};
  const pills = [
    {
      text: `Backend ${health.ok ? "raggiungibile" : "offline"}`,
      type: health.ok ? "good" : "bad"
    },
    {
      text: `Store ${health.storeReady ? "ready" : "not ready"}`,
      type: health.storeReady ? "good" : "warn"
    },
    {
      text: `Play Giochi ${health.playGamesConfigured ? "on" : "off"}`,
      type: health.playGamesConfigured ? "good" : "warn"
    },
    {
      text: `Mail ${health.emailConfigured ? "ready" : "not ready"}`,
      type: health.emailConfigured ? "good" : "warn"
    },
    {
      text: `Admin ${admin.ok ? "linked" : "not linked"}`,
      type: admin.ok ? "good" : "warn"
    }
  ];
  for (const pill of pills) {
    const el = document.createElement("div");
    el.className = `status-pill ${pill.type}`;
    el.textContent = pill.text;
    els.statusBar.appendChild(el);
  }
  if (overview.generatedAt) {
    els.lastRefreshLabel.textContent = `Ultimo refresh: ${new Date(overview.generatedAt).toLocaleString("it-IT")}`;
  }
}

function renderHealthCards() {
  const health = state.dashboard?.backendHealth?.payload || {};
  els.healthCards.innerHTML = "";
  const cards = [
    ["Backend mode", health.mode || "n/d"],
    ["Storage", health.storageMode || "n/d"],
    ["Email mode", health.emailMode || "n/d"],
    ["Store ready", health.storeReady ? "SI" : "NO"],
    ["Google", health.googleConfigured ? "ON" : "OFF"],
    ["Play Giochi", health.playGamesConfigured ? "ON" : "OFF"],
    ["Telemetry digest", health.telemetryDigestEnabled ? "ON" : "OFF"],
    ["Store check", health.storeLastCheckedAt ? new Date(health.storeLastCheckedAt).toLocaleTimeString("it-IT") : "n/d"]
  ];
  for (const [label, value] of cards) {
    const card = document.createElement("div");
    card.className = "metric-card";
    card.innerHTML = `<strong>${label}</strong><span>${value}</span>`;
    els.healthCards.appendChild(card);
  }
}

function renderTelemetry(target, report) {
  target.innerHTML = "";
  const metrics = [
    ["Sessioni", report.sessionCount],
    ["Wave media", formatNumber(report.avgWave, 1)],
    ["Wave max", report.maxWave],
    ["DNA medio", formatNumber(report.avgDna, 1)],
    ["Kill medi", formatNumber(report.avgKills, 1)],
    ["Mutazioni", formatNumber(report.avgMutations, 1)],
    ["Infections", formatNumber(report.avgInfections, 1)],
    ["Revive", report.reviveRuns],
    ["DNA x2", report.dnaBoostRuns]
  ];
  for (const [label, value] of metrics) {
    const item = document.createElement("div");
    item.className = "telemetry-item";
    item.innerHTML = `<small>${label}</small><strong>${value}</strong>`;
    target.appendChild(item);
  }
}

function renderList(target, entries, formatter) {
  target.innerHTML = "";
  if (!entries || entries.length === 0) {
    const li = document.createElement("li");
    li.textContent = "Nessun dato disponibile.";
    target.appendChild(li);
    return;
  }
  for (const entry of entries) {
    const li = document.createElement("li");
    li.textContent = formatter(entry);
    target.appendChild(li);
  }
}

function renderLeaderboard(target, entries) {
  target.innerHTML = "";
  if (!entries || entries.length === 0) {
    target.innerHTML = `<div class="leaderboard-row"><div class="rank">--</div><div>Nessun punteggio</div><div>Wave --</div><div>DNA --</div></div>`;
    return;
  }
  for (const entry of entries) {
    const row = document.createElement("div");
    row.className = "leaderboard-row";
    row.innerHTML = `
      <div class="rank">#${entry.rank}</div>
      <div>
        <strong>${entry.displayName}</strong>
        <div class="muted">${entry.archetypeId || "core"} | ${entry.chapterId || "sector"}</div>
      </div>
      <div>Wave ${entry.bestWave}</div>
      <div>DNA ${entry.dnaEarned}</div>
    `;
    target.appendChild(row);
  }
}

function renderConfigSummary(target, items) {
  target.innerHTML = "";
  for (const [label, value] of items) {
    const card = document.createElement("div");
    card.className = "summary-card";
    card.innerHTML = `<strong>${label}</strong><div>${value}</div>`;
    target.appendChild(card);
  }
}

function renderDashboard() {
  const overview = state.dashboard?.adminOverview?.payload || {};
  const telemetryToday = overview.telemetry?.today || {};
  const telemetryYesterday = overview.telemetry?.yesterday || {};
  const community = overview.community || {};
  els.todayKeyLabel.textContent = overview.dayKey || "";
  els.yesterdayKeyLabel.textContent = overview.yesterdayKey || "";
  els.dailyMeta.textContent = overview.dayKey ? `Top ${community.dailyLeaderboard?.length || 0} | ${overview.dayKey}` : "";
  els.weeklyMeta.textContent = overview.weekKey ? `Top ${community.weeklyLeaderboard?.length || 0} | ${overview.weekKey}` : "";
  renderHealthCards();
  renderTelemetry(els.todayTelemetry, telemetryToday);
  renderTelemetry(els.yesterdayTelemetry, telemetryYesterday);
  renderList(els.todayLoadouts, telemetryToday.topLoadouts, (entry) => `${entry.chapterId} | ${entry.archetypeId} - ${entry.sessionCount} sessioni - wave media ${formatNumber(entry.avgWave, 1)}`);
  renderList(els.todayUpgrades, telemetryToday.topUpgrades, (entry) => `${entry.upgradeId} - lv medio ${formatNumber(entry.avgLevel, 1)} - apparizioni ${entry.appearances}`);
  renderList(els.yesterdayLoadouts, telemetryYesterday.topLoadouts, (entry) => `${entry.chapterId} | ${entry.archetypeId} - ${entry.sessionCount} sessioni - wave media ${formatNumber(entry.avgWave, 1)}`);
  renderList(els.yesterdayUpgrades, telemetryYesterday.topUpgrades, (entry) => `${entry.upgradeId} - lv medio ${formatNumber(entry.avgLevel, 1)} - apparizioni ${entry.appearances}`);
  renderLeaderboard(els.dailyLeaderboard, community.dailyLeaderboard || []);
  renderLeaderboard(els.weeklyLeaderboard, community.weeklyLeaderboard || []);
  setStatusPills();
}

function renderSettings() {
  const payload = state.settings;
  if (!payload) return;
  els.backendUrlInput.value = payload.settings.backendUrl || "";
  els.adminTokenInput.value = "";
  els.requestTimeoutInput.value = payload.settings.requestTimeoutMs || 15000;
  els.settingsPathLabel.textContent = payload.paths.localSettingsPath;
  els.remotePathLabel.textContent = payload.paths.remoteConfigPath;
  els.seasonPathLabel.textContent = payload.paths.seasonConfigPath;
  els.notificationPathLabel.textContent = payload.paths.notificationConfigPath;
}

function renderEditors() {
  els.remoteConfigEditor.value = JSON.stringify(state.remoteConfig?.data || {}, null, 2);
  els.seasonConfigEditor.value = JSON.stringify(state.seasonConfig?.data || {}, null, 2);
  els.notificationConfigEditor.value = JSON.stringify(state.notificationConfig?.data || {}, null, 2);

  const remote = state.remoteConfig?.data || {};
  renderConfigSummary(els.remoteSummary, [
    ["ATP scale", formatNumber(remote.economy?.runtime_atp_scale, 2)],
    ["DNA scale", formatNumber(remote.economy?.dna_payout_scale, 2)],
    ["Enemy HP", formatNumber(remote.combat?.enemy_health_scale, 2)],
    ["Enemy Speed", formatNumber(remote.combat?.enemy_speed_scale, 2)],
    ["Spawn density", formatNumber(remote.combat?.spawn_density_scale, 2)],
    ["Revive charges", remote.reward_flow?.revive_charges ?? 0]
  ]);

  const season = state.seasonConfig?.data || {};
  renderConfigSummary(els.seasonSummary, [
    ["Event ID", season.event_id || "n/d"],
    ["Milestone", `${season.milestones?.length || 0} step`],
    ["Obiettivi attivi", season.active_objective_count || 0],
    ["Template archivio", season.objective_templates?.length || 0],
    ["Currency IT", season.currency_name_it || "n/d"],
    ["Currency EN", season.currency_name_en || "n/d"]
  ]);

  const notifications = state.notificationConfig?.data || {};
  const enabledCampaigns = (notifications.campaigns || []).filter((entry) => entry.enabled).length;
  renderConfigSummary(els.notificationSummary, [
    ["Channel", notifications.channel_id || "n/d"],
    ["Campagne", notifications.campaigns?.length || 0],
    ["Attive", enabledCampaigns],
    ["Prima finestra", notifications.campaigns?.[0]?.delay_seconds ? `${formatNumber(notifications.campaigns[0].delay_seconds / 3600, 1)} ore` : "n/d"]
  ]);
}

async function loadAll() {
  const [settings, dashboard, remoteConfig, seasonConfig, notificationConfig] = await Promise.all([
    request("/api/settings"),
    request("/api/dashboard"),
    request("/api/config/remote"),
    request("/api/config/season"),
    request("/api/config/notifications")
  ]);
  state.settings = settings;
  state.dashboard = dashboard;
  state.remoteConfig = remoteConfig;
  state.seasonConfig = seasonConfig;
  state.notificationConfig = notificationConfig;
  renderSettings();
  renderDashboard();
  renderEditors();
}

async function saveJsonEditor(editor, endpoint, successMessage) {
  const parsed = JSON.parse(editor.value);
  await request(endpoint, {
    method: "POST",
    body: JSON.stringify(parsed)
  });
  notify(successMessage);
}

els.refreshAllButton.addEventListener("click", async () => {
  try {
    await loadAll();
    notify("Snapshot aggiornato.");
  } catch (error) {
    notify(error.message, "bad");
  }
});

els.sendDigestButton.addEventListener("click", async () => {
  try {
    const result = await request("/api/backend/telemetry-digest-send", {
      method: "POST",
      body: JSON.stringify({})
    });
    notify(result.payload?.sent ? "Digest inviato." : "Digest non inviato: nessun dato o provider mail non pronto.", result.payload?.sent ? "good" : "warn");
  } catch (error) {
    notify(error.message, "bad");
  }
});

els.settingsForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    await request("/api/settings", {
      method: "POST",
      body: JSON.stringify({
        backendUrl: els.backendUrlInput.value,
        adminApiToken: els.adminTokenInput.value,
        requestTimeoutMs: Number(els.requestTimeoutInput.value || 15000)
      })
    });
    notify("Impostazioni salvate.");
    await loadAll();
  } catch (error) {
    notify(error.message, "bad");
  }
});

els.saveRemoteConfigButton.addEventListener("click", async () => {
  try {
    await saveJsonEditor(els.remoteConfigEditor, "/api/config/remote", "Remote config salvata.");
  } catch (error) {
    notify(error.message, "bad");
  }
});

els.saveSeasonConfigButton.addEventListener("click", async () => {
  try {
    await saveJsonEditor(els.seasonConfigEditor, "/api/config/season", "Season config salvata.");
  } catch (error) {
    notify(error.message, "bad");
  }
});

els.saveNotificationConfigButton.addEventListener("click", async () => {
  try {
    await saveJsonEditor(els.notificationConfigEditor, "/api/config/notifications", "Notification config salvata.");
  } catch (error) {
    notify(error.message, "bad");
  }
});

loadAll().catch((error) => notify(error.message, "bad"));
