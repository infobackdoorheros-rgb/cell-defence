import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import dotenv from "dotenv";
import express from "express";
import cors from "cors";
import passport from "passport";
import { Strategy as GoogleStrategy } from "passport-google-oauth20";
import { createEmailProvider } from "./email_provider.js";
import {
  cleanupExpiredEntries,
  createGoogleDeviceSession,
  deleteAccountDeletionRequest,
  deleteBackdoorRequest,
  deletePlayGamesProfile,
  deleteUserProfileByEmail,
  createCommunityPod,
  getDailyLeaderboard,
  getCommunityPod,
  getCommunityProfile,
  getWeeklyLeaderboard,
  getAccountDeletionRequest,
  getBackdoorRequest,
  getGoogleDeviceSession,
  getGoogleDeviceSessionByUserCode,
  getPlayGamesProfile,
  getStoreDiagnostics,
  getStoreMode,
  getTelemetryDigestReport,
  incrementAccountDeletionVerifyAttempts,
  incrementBackdoorVerifyAttempts,
  initStore,
  insertTelemetrySession,
  joinCommunityPod,
  leaveCommunityPod,
  hasTelemetryDigestBeenSent,
  markTelemetryDigestSent,
  probeStoreConnectivity,
  redeemCommunityReferral,
  submitDailyScore,
  submitWeeklyScore,
  updateGoogleDeviceSession,
  upsertCommunityProfile,
  upsertAccountDeletionRequest,
  upsertPlayGamesProfile,
  upsertBackdoorRequest,
  upsertUserProfile
} from "./store.js";

dotenv.config();

const app = express();
const port = Number(process.env.PORT || 8787);
const nodeEnv = process.env.NODE_ENV || "development";
const publicBaseUrl = process.env.PUBLIC_BASE_URL || process.env.RENDER_EXTERNAL_URL || `http://127.0.0.1:${port}`;
const supportEmail = process.env.SUPPORT_EMAIL || "info.backdoorheros@gmail.com";
const devExposeCodes = String(process.env.DEV_EXPOSE_CODES || "false") === "true";
const allowedOrigins = String(process.env.ALLOWED_ORIGINS || "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);
const backdoorCodeTtlMs = 15 * 60 * 1000;
const backdoorMaxVerifyAttempts = Number(process.env.BACKDOOR_MAX_VERIFY_ATTEMPTS || 5);
const backdoorMinRequestIntervalMs = Number(process.env.BACKDOOR_MIN_REQUEST_INTERVAL_MS || 60000);
const trustProxy = String(process.env.TRUST_PROXY || (process.env.RENDER ? "true" : "false")) === "true";
const googleCallbackUrl = process.env.GOOGLE_CALLBACK_URL || `${publicBaseUrl}/auth/google/web/callback`;
const storeInitRetryMs = Number(process.env.STORE_INIT_RETRY_MS || 15000);
const playGamesServerClientId = String(process.env.PLAY_GAMES_SERVER_CLIENT_ID || "").trim();
const playGamesServerClientSecret = String(process.env.PLAY_GAMES_SERVER_CLIENT_SECRET || "").trim();
const playGamesConfigured = Boolean(playGamesServerClientId && playGamesServerClientSecret);
const adminApiToken = String(process.env.ADMIN_API_TOKEN || "").trim();
const adminApiConfigured = Boolean(adminApiToken);
const authCodeSecret = String(process.env.AUTH_CODE_SECRET || process.env.SESSION_SECRET || "cell-defense-dev-auth-code-secret");
const exposeHealthDiagnostics = String(process.env.EXPOSE_HEALTH_DIAGNOSTICS || "false") === "true";
const telemetryDigestEnabled = String(process.env.TELEMETRY_DIGEST_ENABLED || "true") === "true";
const requestDocsRoot = path.resolve(process.cwd(), "..", "docs");

const emailProvider = createEmailProvider({ supportEmail });
const runtimeRateLimits = new Map();
const storeState = {
  ready: false,
  initializing: false,
  lastError: "",
  lastCheckedAt: "",
  diagnostics: getStoreDiagnostics(),
  probe: {
    dnsOk: false,
    tcpOk: false,
    dnsAddress: "",
    probeError: ""
  }
};

if (nodeEnv === "production" && !authCodeSecret) {
  throw new Error("AUTH_CODE_SECRET is required in production.");
}

if (trustProxy) {
  app.set("trust proxy", 1);
}

app.use(cors({
  origin(origin, callback) {
    if (!origin) {
      return callback(null, true);
    }
    if (nodeEnv !== "production") {
      return callback(null, true);
    }
    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    return callback(new Error("Origin not allowed by CORS"));
  }
}));
app.use((req, res, next) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Referrer-Policy", "no-referrer");
  res.setHeader("X-Frame-Options", "DENY");
  next();
});
app.use(express.json());
app.use(passport.initialize());

const googleConfigured = Boolean(
  process.env.GOOGLE_CLIENT_ID &&
  process.env.GOOGLE_CLIENT_SECRET
);

if (googleConfigured) {
  passport.use(new GoogleStrategy({
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: googleCallbackUrl
  }, (_accessToken, _refreshToken, profile, done) => {
    const primaryEmail = profile.emails?.[0]?.value || "";
    done(null, {
      provider: "google",
      id: profile.id,
      displayName: profile.displayName || "Google Pilot",
      email: primaryEmail
    });
  }));
}

function jsonError(res, status, messageKey, extra = {}) {
  return res.status(status).json({
    ok: false,
    messageKey,
    ...extra
  });
}

function handleAsync(handler) {
  return (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch(next);
  };
}

function generateSixDigitCode() {
  return String(crypto.randomInt(100000, 1000000));
}

function sanitizeLocation(rawLocation) {
  return String(rawLocation || "").trim().slice(0, 96);
}

function getClientIp(req) {
  const forwarded = String(req.headers["x-forwarded-for"] || "")
    .split(",")
    .map((part) => part.trim())
    .find(Boolean);
  return forwarded || req.ip || req.socket?.remoteAddress || "unknown";
}

function applyRateLimit(res, scopeKey, maxRequests, windowMs, messageKey) {
  const now = Date.now();
  const existing = runtimeRateLimits.get(scopeKey);
  if (!existing || existing.resetAt <= now) {
    runtimeRateLimits.set(scopeKey, {
      count: 1,
      resetAt: now + windowMs
    });
    return null;
  }

  existing.count += 1;
  runtimeRateLimits.set(scopeKey, existing);
  if (existing.count <= maxRequests) {
    return null;
  }

  res.setHeader("Retry-After", Math.max(1, Math.ceil((existing.resetAt - now) / 1000)));
  return jsonError(res, 429, messageKey);
}

function hashVerificationCode(email, code, scope) {
  return crypto
    .createHmac("sha256", authCodeSecret)
    .update(`${scope}:${String(email || "").trim().toLowerCase()}:${String(code || "").trim()}`)
    .digest("hex");
}

function verifyHashedCode(storedHash, email, code, scope) {
  const safeStoredHash = String(storedHash || "").trim();
  if (!safeStoredHash) {
    return false;
  }
  const candidateHash = hashVerificationCode(email, code, scope);
  const storedBuffer = Buffer.from(safeStoredHash, "utf8");
  const candidateBuffer = Buffer.from(candidateHash, "utf8");
  if (storedBuffer.length !== candidateBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(storedBuffer, candidateBuffer);
}

function generateDeviceCode() {
  return crypto.randomBytes(24).toString("hex");
}

function generateUserCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let value = "";
  for (let index = 0; index < 8; index += 1) {
    if (index === 4) {
      value += "-";
    }
    value += alphabet[crypto.randomInt(0, alphabet.length)];
  }
  return value;
}

function escapeHtml(value) {
  return String(value || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;")
    .replaceAll("'", "&#39;");
}

function loadDocText(filename, fallback) {
  const candidates = [
    path.join(requestDocsRoot, filename),
    path.join(process.cwd(), "docs", filename),
    path.join(process.cwd(), "..", "docs", filename)
  ];
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return fs.readFileSync(candidate, "utf8");
    }
  }
  return fallback;
}

function clampInt(value, minValue, maxValue) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) {
    return minValue;
  }
  return Math.min(maxValue, Math.max(minValue, Math.round(numeric)));
}

function clampFloat(value, minValue, maxValue) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) {
    return minValue;
  }
  return Math.min(maxValue, Math.max(minValue, numeric));
}

function sanitizeShortText(value, maxLength = 48) {
  return String(value || "").trim().slice(0, maxLength);
}

function readAdminToken(req) {
  const authHeader = String(req.headers.authorization || "").trim();
  if (authHeader.toLowerCase().startsWith("bearer ")) {
    return authHeader.slice(7).trim();
  }
  return String(req.headers["x-admin-token"] || req.query.adminToken || "").trim();
}

function requireAdminAccess(req, res) {
  if (!adminApiConfigured) {
    jsonError(res, 503, "admin.unavailable");
    return false;
  }
  if (readAdminToken(req) !== adminApiToken) {
    jsonError(res, 401, "admin.unauthorized");
    return false;
  }
  return true;
}

function getUtcDayOffset(days) {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function getWeekKey() {
  const now = new Date();
  const utcDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const day = utcDate.getUTCDay() || 7;
  utcDate.setUTCDate(utcDate.getUTCDate() - day + 1);
  return utcDate.toISOString().slice(0, 10);
}

function getDayKey() {
  return new Date().toISOString().slice(0, 10);
}

async function buildCommunityPayload(playerId, limit = 10) {
  const profile = playerId ? await getCommunityProfile(playerId) : null;
  const pod = profile?.podId ? await getCommunityPod(profile.podId) : null;
  const dayKey = getDayKey();
  const weekKey = getWeekKey();
  const dailyLeaderboard = await getDailyLeaderboard(dayKey, limit);
  const weeklyLeaderboard = await getWeeklyLeaderboard(weekKey, limit);
  return {
    profile,
    pod,
    dailyLeaderboard,
    weeklyLeaderboard,
    dayKey,
    weekKey
  };
}

function sanitizeTelemetrySession(payload) {
  const categoryLevels = payload?.runtime_category_levels && typeof payload.runtime_category_levels === "object"
    ? payload.runtime_category_levels
    : {};
  const topRuntimeUpgrades = Array.isArray(payload?.top_runtime_upgrades)
    ? payload.top_runtime_upgrades
    : [];

  return {
    app_version: sanitizeShortText(payload?.app_version, 24),
    build_number: clampInt(payload?.build_number, 0, 999999),
    platform: sanitizeShortText(payload?.platform, 24),
    language: sanitizeShortText(payload?.language, 12),
    graphics_mode: sanitizeShortText(payload?.graphics_mode, 24),
    wave_reached: clampInt(payload?.wave_reached, 1, 999),
    highest_boss_wave_killed: clampInt(payload?.highest_boss_wave_killed, 0, 999),
    kills: clampInt(payload?.kills, 0, 500000),
    elite_kills: clampInt(payload?.elite_kills, 0, 50000),
    boss_kills: clampInt(payload?.boss_kills, 0, 999),
    dna_earned: clampInt(payload?.dna_earned, 0, 100000),
    dna_pickups: clampInt(payload?.dna_pickups, 0, 10000),
    duration_seconds: clampInt(payload?.duration_seconds, 1, 86400),
    archetype_id: sanitizeShortText(payload?.archetype_id, 48),
    chapter_id: sanitizeShortText(payload?.chapter_id, 48),
    mutation_picks: clampInt(payload?.mutation_picks, 0, 999),
    active_mutation_count: clampInt(payload?.active_mutation_count, 0, 99),
    infection_phases: clampInt(payload?.infection_phases, 0, 99),
    revive_used: Boolean(payload?.revive_used),
    dna_boost_used: Boolean(payload?.dna_boost_used),
    runtime_category_levels: {
      attack: clampInt(categoryLevels.attack, 0, 500),
      defense: clampInt(categoryLevels.defense, 0, 500),
      utility: clampInt(categoryLevels.utility, 0, 500)
    },
    top_runtime_upgrades: topRuntimeUpgrades
      .slice(0, 8)
      .map((entry) => ({
        id: sanitizeShortText(entry?.id, 48),
        category: sanitizeShortText(entry?.category, 24),
        level: clampInt(entry?.level, 0, 99)
      }))
      .filter((entry) => entry.id),
    reported_at: sanitizeShortText(payload?.reported_at, 40)
  };
}

function buildTelemetryDigestLines(report) {
  const sessionCount = Number(report?.sessionCount || 0);
  const lines = [
    `Sessions: ${sessionCount}`,
    `Avg wave: ${clampFloat(report?.avgWave, 0, 999).toFixed(2)}`,
    `Max wave: ${clampInt(report?.maxWave, 0, 999)}`,
    `Avg duration: ${clampFloat(report?.avgDuration, 0, 86400).toFixed(1)}s`,
    `Avg DNA: ${clampFloat(report?.avgDna, 0, 100000).toFixed(2)}`,
    `Avg kills: ${clampFloat(report?.avgKills, 0, 500000).toFixed(2)}`,
    `Avg mutations picked: ${clampFloat(report?.avgMutations, 0, 999).toFixed(2)}`,
    `Avg infection phases: ${clampFloat(report?.avgInfections, 0, 999).toFixed(2)}`,
    `Revive usage: ${clampInt(report?.reviveRuns, 0, sessionCount)}/${sessionCount}`,
    `DNA boost usage: ${clampInt(report?.dnaBoostRuns, 0, sessionCount)}/${sessionCount}`
  ];

  const topLoadouts = Array.isArray(report?.topLoadouts) ? report.topLoadouts : [];
  if (topLoadouts.length > 0) {
    lines.push("", "Top loadouts:");
    for (const loadout of topLoadouts) {
      lines.push(
        `- ${sanitizeShortText(loadout.chapterId, 48) || "unknown"} | ${sanitizeShortText(loadout.archetypeId, 48) || "unknown"} ` +
        `(${clampInt(loadout.sessionCount, 0, sessionCount)} sessions, avg wave ${clampFloat(loadout.avgWave, 0, 999).toFixed(2)})`
      );
    }
  }

  const topUpgrades = Array.isArray(report?.topUpgrades) ? report.topUpgrades : [];
  if (topUpgrades.length > 0) {
    lines.push("", "Top upgrades:");
    for (const upgrade of topUpgrades) {
      lines.push(
        `- ${sanitizeShortText(upgrade.upgradeId, 48)} ` +
        `(avg level ${clampFloat(upgrade.avgLevel, 0, 99).toFixed(2)}, appearances ${clampInt(upgrade.appearances, 0, sessionCount)})`
      );
    }
  }

  return lines;
}

async function maybeSendTelemetryDigest(targetDay) {
  if (!telemetryDigestEnabled || !storeState.ready || !emailProvider.isConfigured()) {
    return false;
  }
  const digestDay = sanitizeShortText(targetDay, 10);
  if (!digestDay) {
    return false;
  }
  if (await hasTelemetryDigestBeenSent(digestDay)) {
    return true;
  }
  const report = await getTelemetryDigestReport(digestDay);
  if (!report || Number(report.sessionCount || 0) <= 0) {
    return false;
  }
  await emailProvider.sendTelemetryDigestEmail({
    date: digestDay,
    summaryLines: buildTelemetryDigestLines(report)
  });
  await markTelemetryDigestSent(digestDay, new Date().toISOString());
  return true;
}

function renderDocumentPage(title, markdownBody, subtitle = "") {
  return `
  <html>
    <head>
      <title>${escapeHtml(title)}</title>
      <meta name="viewport" content="width=device-width, initial-scale=1" />
    </head>
    <body style="margin:0;background:#071019;color:#e9fffb;font-family:Arial,sans-serif;">
      <main style="max-width:960px;margin:0 auto;padding:32px 22px 56px;">
        <div style="display:inline-block;padding:8px 14px;border-radius:999px;border:1px solid rgba(63,176,255,.45);color:#7ee9ff;background:rgba(18,31,43,.82);font-size:13px;letter-spacing:.12em;">CELL DEFENCE | CORE IMMUNITY</div>
        <h1 style="margin:18px 0 8px;font-size:34px;line-height:1.05;">${escapeHtml(title)}</h1>
        <p style="margin:0 0 20px;color:#b8d9e9;font-size:16px;">${escapeHtml(subtitle)}</p>
        <section style="padding:22px;border-radius:22px;border:1px solid rgba(126,233,255,.35);background:rgba(11,20,30,.92);box-shadow:0 18px 48px rgba(0,0,0,.28);">
          <pre style="margin:0;white-space:pre-wrap;word-wrap:break-word;font-family:Arial,sans-serif;font-size:15px;line-height:1.6;color:#eefafd;">${escapeHtml(markdownBody)}</pre>
        </section>
      </main>
    </body>
  </html>
  `;
}

setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of runtimeRateLimits.entries()) {
    if (entry.resetAt <= now) {
      runtimeRateLimits.delete(key);
    }
  }
}, 30000).unref();

async function readJsonSafe(response) {
  try {
    return await response.json();
  } catch {
    return {};
  }
}

async function exchangePlayGamesServerAuthCode(serverAuthCode) {
  const params = new URLSearchParams();
  params.set("client_id", playGamesServerClientId);
  params.set("client_secret", playGamesServerClientSecret);
  params.set("code", serverAuthCode);
  params.set("grant_type", "authorization_code");
  params.set("redirect_uri", "");

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: params
  });
  const payload = await readJsonSafe(response);
  const accessToken = String(payload.access_token || "").trim();
  if (!response.ok || !accessToken) {
    throw new Error(`play_games_token_exchange_failed:${response.status}:${JSON.stringify(payload)}`);
  }
  return accessToken;
}

async function fetchPlayGamesCurrentPlayer(accessToken) {
  const response = await fetch("https://games.googleapis.com/games/v1/players/me", {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: "application/json"
    }
  });
  const payload = await readJsonSafe(response);
  if (!response.ok) {
    throw new Error(`play_games_player_fetch_failed:${response.status}:${JSON.stringify(payload)}`);
  }
  return payload;
}

app.get("/api/health", (_req, res) => {
  const mode = googleConfigured && playGamesConfigured
    ? "google+playgames+email"
    : (playGamesConfigured ? "playgames+email" : (googleConfigured ? "google+email" : "email-only"));
  const payload = {
      ok: true,
      mode,
      publicBaseUrl,
      storageMode: getStoreMode(),
      emailMode: emailProvider.getMode(),
      emailConfigured: emailProvider.isConfigured(),
      storeReady: storeState.ready,
      storeInitializing: storeState.initializing,
    storeError: exposeHealthDiagnostics || nodeEnv !== "production"
      ? storeState.lastError
      : (storeState.lastError ? "storage_unavailable" : ""),
    storeLastCheckedAt: storeState.lastCheckedAt,
    googleConfigured,
    playGamesConfigured,
    telemetryDigestEnabled,
    adminApiConfigured
  };
  if (exposeHealthDiagnostics || nodeEnv !== "production") {
    payload.storeDiagnostics = storeState.diagnostics;
    payload.storeProbe = storeState.probe;
  }
  res.json(payload);
});

app.get("/api/admin/overview", handleAsync(async (req, res) => {
  if (!requireAdminAccess(req, res)) {
    return;
  }
  const limit = clampInt(req.query.limit, 5, 50);
  const dayKey = getDayKey();
  const yesterdayKey = getUtcDayOffset(-1);
  const weekKey = getWeekKey();
  const [dailyLeaderboard, weeklyLeaderboard, telemetryToday, telemetryYesterday] = await Promise.all([
    getDailyLeaderboard(dayKey, limit),
    getWeeklyLeaderboard(weekKey, limit),
    getTelemetryDigestReport(dayKey),
    getTelemetryDigestReport(yesterdayKey)
  ]);
  return res.json({
    ok: true,
    generatedAt: new Date().toISOString(),
    dayKey,
    yesterdayKey,
    weekKey,
    health: {
      publicBaseUrl,
      storageMode: getStoreMode(),
      emailMode: emailProvider.getMode(),
      emailConfigured: emailProvider.isConfigured(),
      storeReady: storeState.ready,
      storeInitializing: storeState.initializing,
      storeError: storeState.lastError,
      storeLastCheckedAt: storeState.lastCheckedAt,
      googleConfigured,
      playGamesConfigured,
      telemetryDigestEnabled
    },
    community: {
      dailyLeaderboard,
      weeklyLeaderboard
    },
    telemetry: {
      today: telemetryToday,
      yesterday: telemetryYesterday
    }
  });
}));

app.get("/api/admin/telemetry/digest", handleAsync(async (req, res) => {
  if (!requireAdminAccess(req, res)) {
    return;
  }
  const digestDay = sanitizeShortText(req.query.day, 10) || getDayKey();
  const report = await getTelemetryDigestReport(digestDay);
  return res.json({
    ok: true,
    digestDay,
    report
  });
}));

app.post("/api/admin/telemetry/digest/send", handleAsync(async (req, res) => {
  if (!requireAdminAccess(req, res)) {
    return;
  }
  const digestDay = sanitizeShortText(req.body?.day, 10) || getUtcDayOffset(-1);
  const sent = await maybeSendTelemetryDigest(digestDay);
  return res.json({
    ok: true,
    digestDay,
    sent
  });
}));

app.post("/api/community/profile/sync", handleAsync(async (req, res) => {
  const playerId = sanitizeShortText(req.body?.playerId, 64);
  const displayName = sanitizeShortText(req.body?.displayName, 64) || "Cell Pilot";
  const provider = sanitizeShortText(req.body?.provider, 24) || "guest";
  const email = String(req.body?.email || "").trim().toLowerCase().slice(0, 160);
  if (!playerId) {
    return jsonError(res, 400, "community.player_id_required");
  }

  const profile = await upsertCommunityProfile({
    playerId,
    displayName,
    provider,
    email
  });
  const payload = await buildCommunityPayload(playerId);
  return res.json({
    ok: true,
    messageKey: "community.profile_synced",
    ...payload,
    profile
  });
}));

app.get("/api/community/status", handleAsync(async (req, res) => {
  const playerId = sanitizeShortText(req.query.playerId, 64);
  if (!playerId) {
    return jsonError(res, 400, "community.player_id_required");
  }
  const payload = await buildCommunityPayload(playerId);
  return res.json({
    ok: true,
    messageKey: "community.status_ready",
    ...payload
  });
}));

app.post("/api/community/referral/redeem", handleAsync(async (req, res) => {
  const playerId = sanitizeShortText(req.body?.playerId, 64);
  const referralCode = sanitizeShortText(req.body?.referralCode, 24).toUpperCase();
  if (!playerId || !referralCode) {
    return jsonError(res, 400, "community.referral_invalid");
  }
  const outcome = await redeemCommunityReferral(playerId, referralCode);
  if (!outcome?.ok) {
    return jsonError(res, 400, `community.${String(outcome?.reason || "referral_invalid")}`);
  }
  const payload = await buildCommunityPayload(playerId);
  return res.json({
    ok: true,
    messageKey: "community.referral_redeemed",
    ...payload
  });
}));

app.post("/api/community/pod/create", handleAsync(async (req, res) => {
  const playerId = sanitizeShortText(req.body?.playerId, 64);
  const displayName = sanitizeShortText(req.body?.displayName, 64) || "Cell Pilot";
  const podName = sanitizeShortText(req.body?.podName, 64);
  if (!playerId || !podName) {
    return jsonError(res, 400, "community.pod_invalid");
  }
  await upsertCommunityProfile({
    playerId,
    displayName,
    provider: "community",
    email: ""
  });
  const outcome = await createCommunityPod(playerId, podName);
  if (!outcome?.ok) {
    return jsonError(res, 400, `community.${String(outcome?.reason || "pod_invalid")}`);
  }
  const payload = await buildCommunityPayload(playerId);
  return res.json({
    ok: true,
    messageKey: "community.pod_created",
    ...payload
  });
}));

app.post("/api/community/pod/join", handleAsync(async (req, res) => {
  const playerId = sanitizeShortText(req.body?.playerId, 64);
  const displayName = sanitizeShortText(req.body?.displayName, 64) || "Cell Pilot";
  const inviteCode = sanitizeShortText(req.body?.inviteCode, 24).toUpperCase();
  if (!playerId || !inviteCode) {
    return jsonError(res, 400, "community.pod_invalid");
  }
  await upsertCommunityProfile({
    playerId,
    displayName,
    provider: "community",
    email: ""
  });
  const outcome = await joinCommunityPod(playerId, inviteCode);
  if (!outcome?.ok) {
    return jsonError(res, 400, `community.${String(outcome?.reason || "pod_invalid")}`);
  }
  const payload = await buildCommunityPayload(playerId);
  return res.json({
    ok: true,
    messageKey: "community.pod_joined",
    ...payload
  });
}));

app.post("/api/community/pod/leave", handleAsync(async (req, res) => {
  const playerId = sanitizeShortText(req.body?.playerId, 64);
  if (!playerId) {
    return jsonError(res, 400, "community.player_id_required");
  }
  const outcome = await leaveCommunityPod(playerId);
  if (!outcome?.ok) {
    return jsonError(res, 400, `community.${String(outcome?.reason || "pod_invalid")}`);
  }
  const payload = await buildCommunityPayload(playerId);
  return res.json({
    ok: true,
    messageKey: "community.pod_left",
    ...payload
  });
}));

app.post("/api/community/weekly/submit", handleAsync(async (req, res) => {
  const playerId = sanitizeShortText(req.body?.playerId, 64);
  const displayName = sanitizeShortText(req.body?.displayName, 64) || "Cell Pilot";
  const scorePayload = {
    playerId,
    displayName,
    scoreValue: clampInt(req.body?.scoreValue, 0, 999999),
    bestWave: clampInt(req.body?.bestWave, 0, 999999),
    dnaEarned: clampInt(req.body?.dnaEarned, 0, 999999),
    archetypeId: sanitizeShortText(req.body?.archetypeId, 48),
    chapterId: sanitizeShortText(req.body?.chapterId, 48),
    challengeLabel: sanitizeShortText(req.body?.challengeLabel, 64)
  };
  if (!playerId) {
    return jsonError(res, 400, "community.player_id_required");
  }
  await submitDailyScore({
    dayKey: getDayKey(),
    ...scorePayload
  });
  await submitWeeklyScore({
    weekKey: getWeekKey(),
    ...scorePayload
  });
  const payload = await buildCommunityPayload(playerId);
  return res.json({
    ok: true,
    messageKey: "community.weekly_submitted",
    ...payload
  });
}));

app.get("/api/community/weekly/leaderboard", handleAsync(async (req, res) => {
  const playerId = sanitizeShortText(req.query.playerId, 64);
  const limit = clampInt(req.query.limit, 3, 20);
  const payload = await buildCommunityPayload(playerId, limit);
  return res.json({
    ok: true,
    messageKey: "community.weekly_ready",
    ...payload
  });
}));

app.get("/privacy", (_req, res) => {
  const markdown = loadDocText(
    "privacy_policy.md",
    "# Privacy Policy\n\nWrite to info.backdoorheros@gmail.com for privacy requests."
  );
  res
    .type("html")
    .send(renderDocumentPage(
      "Privacy Policy",
      markdown,
      "Public privacy notice for Cell Defence: Core Immunity."
    ));
});

app.get("/account-deletion", (_req, res) => {
  const markdown = loadDocText(
    "account_deletion.md",
    "# Account Deletion\n\nOpen the in-app Account Center or write to info.backdoorheros@gmail.com to request deletion."
  );
  res
    .type("html")
    .send(renderDocumentPage(
      "Account Deletion",
      markdown,
      "Public instructions for deleting a Cell Defence profile."
    ));
});

app.post("/api/telemetry/session", handleAsync(async (req, res) => {
  if (!storeState.ready) {
    return jsonError(res, 503, "telemetry.backend_unreachable");
  }

  const clientIp = getClientIp(req);
  const rateLimit = applyRateLimit(res, `telemetry:ip:${clientIp}`, 60, 15 * 60 * 1000, "telemetry.rate_limited");
  if (rateLimit) {
    return rateLimit;
  }

  const payload = sanitizeTelemetrySession(req.body || {});
  if (!payload.wave_reached || !payload.duration_seconds) {
    return jsonError(res, 400, "telemetry.invalid_payload");
  }

  const digestDay = await insertTelemetrySession(payload);
  const previousUtcDay = getUtcDayOffset(-1);
  if (digestDay !== previousUtcDay) {
    try {
      await maybeSendTelemetryDigest(previousUtcDay);
    } catch (error) {
      console.error("Telemetry digest dispatch failed", error);
    }
  }

  return res.json({
    ok: true,
    messageKey: "telemetry.session_recorded"
  });
}));

app.post("/api/auth/playgames/android", handleAsync(async (req, res) => {
  if (!playGamesConfigured) {
    return jsonError(res, 503, "account.play_games_backend_unavailable");
  }

  const serverAuthCode = String(req.body?.serverAuthCode || "").trim();
  const clientPlayerId = String(req.body?.playGamesPlayerId || "").trim();
  const clientDisplayName = String(req.body?.displayName || "").trim();
  const clientTitle = String(req.body?.title || "").trim();
  const clientIconImageUri = String(req.body?.iconImageUri || "").trim();

  if (!serverAuthCode) {
    return jsonError(res, 400, "account.play_games_missing_server_code");
  }

  let accessToken = "";
  let verifiedPlayer = {};
  try {
    accessToken = await exchangePlayGamesServerAuthCode(serverAuthCode);
    verifiedPlayer = await fetchPlayGamesCurrentPlayer(accessToken);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return jsonError(res, 401, "account.play_games_invalid_server_code", { detail });
  }

  const verifiedPlayerId = String(verifiedPlayer.playerId || verifiedPlayer.gamePlayerId || "").trim();
  if (!verifiedPlayerId) {
    return jsonError(res, 401, "account.play_games_invalid_server_code");
  }
  if (clientPlayerId && clientPlayerId != verifiedPlayerId) {
    return jsonError(res, 401, "account.play_games_identity_mismatch", {
      detail: `client=${clientPlayerId} verified=${verifiedPlayerId}`
    });
  }

  const existingProfile = await getPlayGamesProfile(verifiedPlayerId);
  const authenticatedAt = new Date().toISOString();
  const storedProfile = await upsertPlayGamesProfile({
    playerId: existingProfile?.playerId || crypto.randomUUID(),
    displayName: String(verifiedPlayer.displayName || clientDisplayName || "Play Games Pilot"),
    authenticatedAt,
    registeredAt: existingProfile?.registeredAt || authenticatedAt,
    playGamesPlayerId: verifiedPlayerId,
    playGamesTitle: String(verifiedPlayer.title || clientTitle || ""),
    playGamesIconImageUri: String(verifiedPlayer.avatarImageUrl || clientIconImageUri || "")
  });

  return res.json({
    ok: true,
    messageKey: "account.play_games_verified",
    profile: storedProfile
  });
}));

app.post("/api/account/delete/playgames", handleAsync(async (req, res) => {
  if (!playGamesConfigured) {
    return jsonError(res, 503, "account.play_games_backend_unavailable");
  }

  const serverAuthCode = String(req.body?.serverAuthCode || "").trim();
  const clientPlayerId = String(req.body?.playGamesPlayerId || "").trim();
  if (!serverAuthCode) {
    return jsonError(res, 400, "account.play_games_missing_server_code");
  }

  let verifiedPlayer = {};
  try {
    const accessToken = await exchangePlayGamesServerAuthCode(serverAuthCode);
    verifiedPlayer = await fetchPlayGamesCurrentPlayer(accessToken);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return jsonError(res, 401, "account.play_games_invalid_server_code", { detail });
  }

  const verifiedPlayerId = String(verifiedPlayer.playerId || verifiedPlayer.gamePlayerId || "").trim();
  if (!verifiedPlayerId) {
    return jsonError(res, 401, "account.play_games_invalid_server_code");
  }
  if (clientPlayerId && clientPlayerId !== verifiedPlayerId) {
    return jsonError(res, 401, "account.play_games_identity_mismatch", {
      detail: `client=${clientPlayerId} verified=${verifiedPlayerId}`
    });
  }

  await deletePlayGamesProfile(verifiedPlayerId);
  return res.json({
    ok: true,
    messageKey: "account.deletion_completed"
  });
}));

app.post("/api/account/delete/email/request", handleAsync(async (req, res) => {
  const displayName = String(req.body?.displayName || "Immune Pilot").trim().slice(0, 64) || "Immune Pilot";
  const email = String(req.body?.email || "").trim().toLowerCase();
  const provider = String(req.body?.provider || "backdoor").trim().toLowerCase() || "backdoor";
  const clientIp = getClientIp(req);

  if (!email.includes("@") || !email.includes(".")) {
    return jsonError(res, 400, "account.error_invalid_email");
  }
  const ipRateLimit = applyRateLimit(res, `delete-request:ip:${clientIp}`, 8, 15 * 60 * 1000, "account.error_request_throttled");
  if (ipRateLimit) {
    return ipRateLimit;
  }
  const emailRateLimit = applyRateLimit(res, `delete-request:email:${email}`, 3, 15 * 60 * 1000, "account.error_request_throttled");
  if (emailRateLimit) {
    return emailRateLimit;
  }

  await cleanupExpiredEntries();
  const existingRequest = await getAccountDeletionRequest(email);
  if (existingRequest && (Date.now() - Date.parse(existingRequest.requestedAt || 0)) < backdoorMinRequestIntervalMs) {
    return jsonError(res, 429, "account.error_request_throttled");
  }

  const code = generateSixDigitCode();
  const hashedCode = hashVerificationCode(email, code, "account-deletion");
  const requestedAt = new Date().toISOString();
  const expiresAt = Date.now() + backdoorCodeTtlMs;

  await upsertAccountDeletionRequest({
    displayName,
    email,
    provider,
    code: hashedCode,
    requestedAt,
    expiresAt,
    verifyAttempts: 0
  });

  try {
    await emailProvider.sendDeletionEmails({
      displayName,
      email,
      provider,
      code,
      requestedAt
    });
  } catch (error) {
    const detail = String(error.message || error);
    if (!devExposeCodes) {
      const messageKey = detail.includes("ENOTFOUND") || detail.includes("EAUTH")
        ? "account.error_email_delivery_unavailable"
        : "account.error_backend_unreachable";
      return jsonError(res, 500, messageKey, {
        detail
      });
    }
  }

  return res.json({
    ok: true,
    messageKey: "account.deletion_request_sent",
    requestedAt,
    devCode: devExposeCodes ? code : undefined
  });
}));

app.post("/api/account/delete/email/confirm", handleAsync(async (req, res) => {
  const email = String(req.body?.email || "").trim().toLowerCase();
  const code = String(req.body?.code || "").trim();
  const clientIp = getClientIp(req);
  if (!code) {
    return jsonError(res, 400, "account.error_code_required");
  }
  const ipRateLimit = applyRateLimit(res, `delete-verify:ip:${clientIp}`, 18, 15 * 60 * 1000, "account.error_too_many_attempts");
  if (ipRateLimit) {
    return ipRateLimit;
  }
  const emailRateLimit = applyRateLimit(res, `delete-verify:email:${email}`, 8, 15 * 60 * 1000, "account.error_too_many_attempts");
  if (emailRateLimit) {
    return emailRateLimit;
  }

  await cleanupExpiredEntries();
  const pending = await getAccountDeletionRequest(email);
  if (!pending) {
    return jsonError(res, 404, "account.deletion_invalid_code");
  }
  if (Number(pending.verifyAttempts || 0) >= backdoorMaxVerifyAttempts) {
    await deleteAccountDeletionRequest(email);
    return jsonError(res, 429, "account.error_too_many_attempts");
  }
  if (!verifyHashedCode(pending.code, email, code, "account-deletion")) {
    await incrementAccountDeletionVerifyAttempts(email);
    return jsonError(res, 400, "account.deletion_invalid_code");
  }

  await deleteUserProfileByEmail(email);
  await deleteBackdoorRequest(email);
  await deleteAccountDeletionRequest(email);

  return res.json({
    ok: true,
    messageKey: "account.deletion_completed"
  });
}));

app.post("/api/auth/backdoor/register", handleAsync(async (req, res) => {
  const displayName = String(req.body?.displayName || "").trim();
  const email = String(req.body?.email || "").trim().toLowerCase();
  const location = sanitizeLocation(req.body?.location);
  const clientIp = getClientIp(req);
  if (!displayName) {
    return jsonError(res, 400, "account.error_name_required");
  }
  if (!email.includes("@") || !email.includes(".")) {
    return jsonError(res, 400, "account.error_invalid_email");
  }
  if (!location) {
    return jsonError(res, 400, "account.error_location_required");
  }
  const ipRateLimit = applyRateLimit(res, `backdoor-request:ip:${clientIp}`, 8, 15 * 60 * 1000, "account.error_request_throttled");
  if (ipRateLimit) {
    return ipRateLimit;
  }
  const emailRateLimit = applyRateLimit(res, `backdoor-request:email:${email}`, 3, 15 * 60 * 1000, "account.error_request_throttled");
  if (emailRateLimit) {
    return emailRateLimit;
  }

  await cleanupExpiredEntries();
  const existingRequest = await getBackdoorRequest(email);
  if (existingRequest && (Date.now() - Date.parse(existingRequest.requestedAt || 0)) < backdoorMinRequestIntervalMs) {
    return jsonError(res, 429, "account.error_request_throttled");
  }

  const code = generateSixDigitCode();
  const hashedCode = hashVerificationCode(email, code, "backdoor-register");
  const requestedAt = new Date().toISOString();
  const expiresAt = Date.now() + backdoorCodeTtlMs;

  await upsertBackdoorRequest({
    displayName,
    email,
    location,
    code: hashedCode,
    requestedAt,
    expiresAt,
    verifyAttempts: 0
  });

  try {
    await emailProvider.sendRegistrationEmails({ displayName, email, location, code, requestedAt });
  } catch (error) {
    const detail = String(error.message || error);
    if (!devExposeCodes) {
      const messageKey = detail.includes("ENOTFOUND") || detail.includes("EAUTH")
        ? "account.error_email_delivery_unavailable"
        : "account.error_backend_unreachable";
      return jsonError(res, 500, messageKey, {
        detail
      });
    }
  }

  return res.json({
    ok: true,
    messageKey: "account.backdoor_mail_opened",
    requestedAt,
    devCode: devExposeCodes ? code : undefined
  });
}));

app.post("/api/auth/backdoor/verify", (req, res) => {
  void (async () => {
  const email = String(req.body?.email || "").trim().toLowerCase();
  const code = String(req.body?.code || "").trim();
  const clientIp = getClientIp(req);
  if (!code) {
    return jsonError(res, 400, "account.error_code_required");
  }
  const ipRateLimit = applyRateLimit(res, `backdoor-verify:ip:${clientIp}`, 18, 15 * 60 * 1000, "account.error_too_many_attempts");
  if (ipRateLimit) {
    return ipRateLimit;
  }
  const emailRateLimit = applyRateLimit(res, `backdoor-verify:email:${email}`, 8, 15 * 60 * 1000, "account.error_too_many_attempts");
  if (emailRateLimit) {
    return emailRateLimit;
  }

  await cleanupExpiredEntries();
  const pending = await getBackdoorRequest(email);
  if (!pending) {
    return jsonError(res, 404, "account.error_invalid_code");
  }
  if (Number(pending.verifyAttempts || 0) >= backdoorMaxVerifyAttempts) {
    await deleteBackdoorRequest(email);
    return jsonError(res, 429, "account.error_too_many_attempts");
  }
  if (!verifyHashedCode(pending.code, email, code, "backdoor-register")) {
    await incrementBackdoorVerifyAttempts(email);
    return jsonError(res, 400, "account.error_invalid_code");
  }

  const profile = {
    playerId: crypto.randomUUID(),
    provider: "backdoor",
    displayName: pending.displayName,
    email,
    location: pending.location,
    registeredAt: new Date().toISOString(),
    authenticatedAt: new Date().toISOString()
  };
  await upsertUserProfile(profile);
  await deleteBackdoorRequest(email);

  return res.json({
    ok: true,
    messageKey: "account.verified",
    profile
  });
  })().catch((error) => {
    console.error("BackDoor verify error", error);
    return jsonError(res, 500, "account.error_backend_unreachable");
  });
});

app.post("/api/auth/google/device/start", (_req, res) => {
  void (async () => {
  if (!googleConfigured) {
    return jsonError(res, 503, "account.google_unavailable");
  }

  await cleanupExpiredEntries();

  const deviceCode = generateDeviceCode();
  const userCode = generateUserCode();
  const expiresAt = Date.now() + (10 * 60 * 1000);

  await createGoogleDeviceSession({
    deviceCode,
    userCode,
    status: "pending",
    createdAt: new Date().toISOString(),
    expiresAt
  });

  res.json({
    ok: true,
    messageKey: "account.google_device_started",
    deviceCode,
    userCode,
    verificationUrl: `${publicBaseUrl}/auth/google/device?code=${encodeURIComponent(userCode)}`
  });
  })().catch((error) => {
    console.error("Google device start error", error);
    return jsonError(res, 500, "account.error_backend_unreachable");
  });
});

app.get("/api/auth/google/device/status", (req, res) => {
  void (async () => {
  const deviceCode = String(req.query.deviceCode || "");
  await cleanupExpiredEntries();
  const sessionEntry = await getGoogleDeviceSession(deviceCode);
  if (!sessionEntry) {
    return jsonError(res, 404, "account.google_expired", { status: "expired" });
  }

  if (sessionEntry.status === "authenticated") {
    return res.json({
      ok: true,
      status: "authenticated",
      messageKey: "account.verified",
      profile: sessionEntry.profile
    });
  }

  res.json({
    ok: true,
    status: "pending",
    messageKey: "account.google_waiting"
  });
  })().catch((error) => {
    console.error("Google device status error", error);
    return jsonError(res, 500, "account.error_backend_unreachable");
  });
});

app.get("/auth/google/device", (req, res) => {
  void (async () => {
    const userCode = String(req.query.code || "");
    await cleanupExpiredEntries();
    const match = await getGoogleDeviceSessionByUserCode(userCode);
    if (!match) {
      return res.status(404).send("<h1>Request expired</h1><p>Return to the game and start a new Google login.</p>");
    }

    const deviceCode = match.deviceCode;
    res.send(`
    <html>
      <head><title>BackDoor Heroes Google Login</title></head>
      <body style="font-family: Arial, sans-serif; background:#08111a; color:#e9fffb; padding:32px;">
        <h1>BackDoor Heroes</h1>
        <p>Device code: <strong>${escapeHtml(userCode)}</strong></p>
        <p>Continue with Google and then return to the game.</p>
        <a href="/auth/google/web/start?deviceCode=${encodeURIComponent(deviceCode)}" style="display:inline-block;padding:14px 22px;background:#3fb0ff;color:#08111a;border-radius:12px;text-decoration:none;font-weight:bold;">Continue with Google</a>
      </body>
    </html>
  `);
  })().catch((error) => {
    console.error("Google device page error", error);
    res.status(500).send("<h1>Temporary backend error</h1><p>Please return to the game and try again.</p>");
  });
});

app.get("/auth/google/web/start", (req, res, next) => {
  if (!googleConfigured) {
    return res.status(503).send("<h1>Google login not configured</h1><p>Add Google OAuth credentials to the backend env file.</p>");
  }
  const deviceCode = String(req.query.deviceCode || "");
  return passport.authenticate("google", {
    scope: ["profile", "email"],
    prompt: "select_account",
    state: deviceCode
  })(req, res, next);
});

app.get("/auth/google/web/callback", (req, res, next) => {
  if (!googleConfigured) {
    return res.status(503).send("<h1>Google login not configured</h1>");
  }
  return passport.authenticate("google", { failureRedirect: "/auth/google/failure", session: false })(req, res, next);
}, (req, res) => {
  void (async () => {
    const deviceCode = String(req.query.state || "");
    await cleanupExpiredEntries();
    const entry = await getGoogleDeviceSession(deviceCode);
    if (!entry) {
      return res.status(404).send("<h1>Device session expired</h1><p>Return to the game and start again.</p>");
    }

    const googleUser = req.user || {};
    const profile = {
      playerId: crypto.randomUUID(),
      provider: "google",
      displayName: String(googleUser.displayName || "Google Pilot"),
      email: String(googleUser.email || ""),
      location: "",
      registeredAt: new Date().toISOString(),
      googleId: String(googleUser.id || ""),
      authenticatedAt: new Date().toISOString()
    };
    await upsertUserProfile(profile);
    await updateGoogleDeviceSession(deviceCode, {
      status: "authenticated",
      profile
    });

    res.send(`
    <html>
      <head><title>Login complete</title></head>
      <body style="font-family: Arial, sans-serif; background:#08111a; color:#e9fffb; padding:32px;">
        <h1>Login complete</h1>
        <p>You can now return to Cell Defense: Core Immunity and tap "I finished in browser".</p>
      </body>
    </html>
  `);
  })().catch((error) => {
    console.error("Google callback error", error);
    res.status(500).send("<h1>Temporary backend error</h1><p>Return to the game and try again.</p>");
  });
});

app.get("/auth/google/failure", (_req, res) => {
  res.status(401).send("<h1>Google login failed</h1><p>Return to the game and try again.</p>");
});

app.use((error, _req, res, _next) => {
  console.error("Unhandled backend error", error);
  return jsonError(res, 500, "account.error_backend_unreachable");
});

async function warmStore() {
  if (storeState.initializing || storeState.ready) {
    return;
  }

  storeState.initializing = true;
  storeState.lastCheckedAt = new Date().toISOString();
  storeState.diagnostics = getStoreDiagnostics();
  try {
    await initStore();
    storeState.ready = true;
    storeState.lastError = "";
    storeState.probe = {
      dnsOk: true,
      tcpOk: true,
      dnsAddress: storeState.probe.dnsAddress,
      probeError: ""
    };
    console.log("Auth store initialized successfully");
  } catch (error) {
    storeState.ready = false;
    storeState.lastError = error instanceof Error ? error.message : String(error);
    storeState.probe = await probeStoreConnectivity();
    console.error("Unable to initialize auth store", error);
    console.error("Auth store diagnostics", {
      diagnostics: storeState.diagnostics,
      probe: storeState.probe
    });
    setTimeout(warmStore, storeInitRetryMs);
  } finally {
    storeState.initializing = false;
    storeState.lastCheckedAt = new Date().toISOString();
  }
}

app.listen(port, "0.0.0.0", () => {
  console.log(`Cell Defense auth backend listening on ${publicBaseUrl}`);
  console.log(`Google configured: ${googleConfigured}`);
  console.log(`Play Games configured: ${playGamesConfigured}`);
  console.log(`Email provider mode: ${emailProvider.getMode()}`);
  console.log(`Storage mode: ${getStoreMode()}`);
  warmStore();
});
