import fs from "node:fs/promises";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, "..");
const publicDir = path.join(__dirname, "public");
const configDir = path.join(rootDir, "data", "config");
const localSettingsPath = path.join(__dirname, "config.local.json");
const localSettingsExamplePath = path.join(__dirname, "config.local.example.json");
const remoteConfigPath = path.join(configDir, "remote_config.json");
const seasonConfigPath = path.join(configDir, "season_event_live.json");
const notificationConfigPath = path.join(configDir, "notification_campaigns.json");

const defaultSettings = {
  backendUrl: "https://cell-defense-auth-backend.onrender.com",
  adminApiToken: "",
  requestTimeoutMs: 15000
};

const portArgIndex = process.argv.findIndex((value) => value === "--port");
const requestedPort = portArgIndex >= 0 ? Number(process.argv[portArgIndex + 1]) : Number(process.env.CONTROL_CENTER_PORT || 4311);
const port = Number.isFinite(requestedPort) && requestedPort > 0 ? requestedPort : 4311;

function jsonResponse(res, statusCode, payload) {
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store"
  });
  res.end(JSON.stringify(payload, null, 2));
}

async function ensureLocalSettings() {
  try {
    await fs.access(localSettingsPath);
  } catch {
    let seed = defaultSettings;
    try {
      const exampleRaw = await fs.readFile(localSettingsExamplePath, "utf8");
      seed = {
        ...defaultSettings,
        ...JSON.parse(exampleRaw)
      };
    } catch {
      seed = defaultSettings;
    }
    await fs.writeFile(localSettingsPath, JSON.stringify(seed, null, 2), "utf8");
  }
}

async function readJsonFile(filePath, fallback = {}) {
  try {
    const raw = await fs.readFile(filePath, "utf8");
    return JSON.parse(raw);
  } catch {
    return structuredClone(fallback);
  }
}

async function writeJsonFile(filePath, payload) {
  await fs.writeFile(filePath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
}

async function readRequestBody(req) {
  return await new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 2_000_000) {
        reject(new Error("payload_too_large"));
      }
    });
    req.on("end", () => resolve(body));
    req.on("error", reject);
  });
}

async function readJsonBody(req) {
  const raw = await readRequestBody(req);
  if (!raw.trim()) {
    return {};
  }
  return JSON.parse(raw);
}

async function getLocalSettings() {
  await ensureLocalSettings();
  const stored = await readJsonFile(localSettingsPath, defaultSettings);
  return {
    ...defaultSettings,
    ...stored
  };
}

function maskToken(value) {
  const safe = String(value || "");
  if (safe.length <= 8) {
    return safe ? "configured" : "";
  }
  return `${safe.slice(0, 4)}...${safe.slice(-4)}`;
}

async function proxyBackend(endpoint, method = "GET", body = null) {
  const settings = await getLocalSettings();
  const baseUrl = String(settings.backendUrl || "").trim().replace(/\/+$/, "");
  if (!baseUrl) {
    return {
      ok: false,
      status: 400,
      error: "Backend URL mancante nelle impostazioni locali."
    };
  }

  const headers = {
    Accept: "application/json"
  };
  if (settings.adminApiToken) {
    headers.Authorization = `Bearer ${settings.adminApiToken}`;
  }
  let payload = undefined;
  if (body != null) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }

  try {
    const response = await fetch(`${baseUrl}${endpoint}`, {
      method,
      headers,
      body: payload,
      signal: AbortSignal.timeout(Math.max(2000, Number(settings.requestTimeoutMs || 15000)))
    });
    const text = await response.text();
    let parsed = {};
    try {
      parsed = text ? JSON.parse(text) : {};
    } catch {
      parsed = { raw: text };
    }
    return {
      ok: response.ok,
      status: response.status,
      payload: parsed
    };
  } catch (error) {
    return {
      ok: false,
      status: 502,
      error: error instanceof Error ? error.message : String(error)
    };
  }
}

async function serveStatic(req, res, pathname) {
  const resolvedPath = pathname === "/" ? "/index.html" : pathname;
  const filePath = path.normalize(path.join(publicDir, resolvedPath));
  if (!filePath.startsWith(publicDir)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }
  try {
    const stat = await fs.stat(filePath);
    if (stat.isDirectory()) {
      return await serveStatic(req, res, path.join(resolvedPath, "index.html"));
    }
    const ext = path.extname(filePath).toLowerCase();
    const contentTypes = {
      ".html": "text/html; charset=utf-8",
      ".css": "text/css; charset=utf-8",
      ".js": "application/javascript; charset=utf-8",
      ".json": "application/json; charset=utf-8",
      ".svg": "image/svg+xml"
    };
    const data = await fs.readFile(filePath);
    res.writeHead(200, {
      "Content-Type": contentTypes[ext] || "application/octet-stream",
      "Cache-Control": "no-store"
    });
    res.end(data);
  } catch {
    res.writeHead(404);
    res.end("Not found");
  }
}

async function handleApi(req, res, url) {
  if (req.method === "GET" && url.pathname === "/api/settings") {
    const settings = await getLocalSettings();
    return jsonResponse(res, 200, {
      ok: true,
      settings: {
        ...settings,
        adminApiTokenMasked: maskToken(settings.adminApiToken)
      },
      paths: {
        remoteConfigPath,
        seasonConfigPath,
        notificationConfigPath,
        localSettingsPath
      }
    });
  }

  if (req.method === "POST" && url.pathname === "/api/settings") {
    const incoming = await readJsonBody(req);
    const nextSettings = {
      backendUrl: String(incoming.backendUrl || defaultSettings.backendUrl).trim(),
      adminApiToken: String(incoming.adminApiToken || "").trim(),
      requestTimeoutMs: Math.max(2000, Number(incoming.requestTimeoutMs || defaultSettings.requestTimeoutMs))
    };
    await writeJsonFile(localSettingsPath, nextSettings);
    return jsonResponse(res, 200, {
      ok: true,
      settings: {
        ...nextSettings,
        adminApiTokenMasked: maskToken(nextSettings.adminApiToken)
      }
    });
  }

  if (req.method === "GET" && url.pathname === "/api/dashboard") {
    const [settingsPayload, healthResult, overviewResult] = await Promise.all([
      getLocalSettings(),
      proxyBackend("/api/health"),
      proxyBackend("/api/admin/overview?limit=12")
    ]);
    return jsonResponse(res, 200, {
      ok: true,
      settings: {
        backendUrl: settingsPayload.backendUrl,
        adminApiTokenMasked: maskToken(settingsPayload.adminApiToken),
        requestTimeoutMs: settingsPayload.requestTimeoutMs
      },
      backendHealth: healthResult,
      adminOverview: overviewResult
    });
  }

  if (req.method === "GET" && url.pathname === "/api/backend/telemetry-digest") {
    const day = url.searchParams.get("day") || "";
    const result = await proxyBackend(`/api/admin/telemetry/digest?day=${encodeURIComponent(day)}`);
    return jsonResponse(res, 200, result);
  }

  if (req.method === "POST" && url.pathname === "/api/backend/telemetry-digest-send") {
    const payload = await readJsonBody(req);
    const result = await proxyBackend("/api/admin/telemetry/digest/send", "POST", payload);
    return jsonResponse(res, 200, result);
  }

  if (req.method === "GET" && url.pathname === "/api/config/remote") {
    return jsonResponse(res, 200, {
      ok: true,
      filePath: remoteConfigPath,
      data: await readJsonFile(remoteConfigPath, {})
    });
  }

  if (req.method === "POST" && url.pathname === "/api/config/remote") {
    const incoming = await readJsonBody(req);
    if (typeof incoming !== "object" || Array.isArray(incoming) || incoming == null) {
      return jsonResponse(res, 400, { ok: false, error: "Remote config non valido." });
    }
    await writeJsonFile(remoteConfigPath, incoming);
    return jsonResponse(res, 200, { ok: true });
  }

  if (req.method === "GET" && url.pathname === "/api/config/season") {
    return jsonResponse(res, 200, {
      ok: true,
      filePath: seasonConfigPath,
      data: await readJsonFile(seasonConfigPath, {})
    });
  }

  if (req.method === "POST" && url.pathname === "/api/config/season") {
    const incoming = await readJsonBody(req);
    if (typeof incoming !== "object" || Array.isArray(incoming) || incoming == null) {
      return jsonResponse(res, 400, { ok: false, error: "Season config non valido." });
    }
    await writeJsonFile(seasonConfigPath, incoming);
    return jsonResponse(res, 200, { ok: true });
  }

  if (req.method === "GET" && url.pathname === "/api/config/notifications") {
    return jsonResponse(res, 200, {
      ok: true,
      filePath: notificationConfigPath,
      data: await readJsonFile(notificationConfigPath, {})
    });
  }

  if (req.method === "POST" && url.pathname === "/api/config/notifications") {
    const incoming = await readJsonBody(req);
    if (typeof incoming !== "object" || Array.isArray(incoming) || incoming == null) {
      return jsonResponse(res, 400, { ok: false, error: "Notification config non valido." });
    }
    await writeJsonFile(notificationConfigPath, incoming);
    return jsonResponse(res, 200, { ok: true });
  }

  return jsonResponse(res, 404, {
    ok: false,
    error: "Endpoint non trovato."
  });
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || "/", `http://${req.headers.host || `127.0.0.1:${port}`}`);
    if (url.pathname.startsWith("/api/")) {
      await handleApi(req, res, url);
      return;
    }
    await serveStatic(req, res, url.pathname);
  } catch (error) {
    jsonResponse(res, 500, {
      ok: false,
      error: error instanceof Error ? error.message : String(error)
    });
  }
});

await ensureLocalSettings();

server.listen(port, "127.0.0.1", () => {
  console.log(`Cell Defence Control Center attivo su http://127.0.0.1:${port}`);
});
