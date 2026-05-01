import crypto from "node:crypto";
import dns from "node:dns/promises";
import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import { Pool } from "pg";

const DATA_DIR = path.resolve(process.cwd(), "data");
const STORE_PATH = path.join(DATA_DIR, "auth-store.json");
const DATABASE_URL = String(process.env.DATABASE_URL || "").trim();
const STORE_MODE = DATABASE_URL ? "postgres" : "file";
const DATABASE_CONNECTION_TIMEOUT_MS = Number(process.env.DATABASE_CONNECTION_TIMEOUT_MS || 10000);
const DATABASE_IDLE_TIMEOUT_MS = Number(process.env.DATABASE_IDLE_TIMEOUT_MS || 30000);
const DATABASE_POOL_MAX = Number(process.env.DATABASE_POOL_MAX || 4);
const DATABASE_SSL_ENABLED = String(process.env.DATABASE_SSL || "").toLowerCase() === "true";
const parsedDatabaseUrl = DATABASE_URL ? new URL(DATABASE_URL) : null;
const STORE_TARGET_HOST = parsedDatabaseUrl?.hostname || "";
const STORE_TARGET_PORT = Number(parsedDatabaseUrl?.port || 5432);
const STORE_TARGET_DATABASE = parsedDatabaseUrl?.pathname?.replace(/^\//, "") || "";

const DEFAULT_STORE = {
  backdoorRequests: {},
  accountDeletionRequests: {},
  userProfiles: {},
  googleDeviceSessions: {},
  playGamesProfiles: {},
  communityProfiles: {},
  communityPods: {},
  dailyScores: {},
  weeklyScores: {},
  telemetrySessions: [],
  telemetryDailyDigests: {}
};

let pool = null;
let initialized = false;

function ensureLocalStore() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
  if (!fs.existsSync(STORE_PATH)) {
    fs.writeFileSync(STORE_PATH, JSON.stringify(DEFAULT_STORE, null, 2), "utf8");
  }
}

function readLocalStore() {
  ensureLocalStore();
  try {
    const raw = fs.readFileSync(STORE_PATH, "utf8");
    const parsed = JSON.parse(raw);
    return {
      ...DEFAULT_STORE,
      ...parsed
    };
  } catch {
    return structuredClone(DEFAULT_STORE);
  }
}

function writeLocalStore(nextStore) {
  ensureLocalStore();
  fs.writeFileSync(STORE_PATH, JSON.stringify(nextStore, null, 2), "utf8");
}

function toIsoString(value) {
  if (!value) {
    return "";
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return "";
  }
  return parsed.toISOString();
}

function getPool() {
  if (!DATABASE_URL) {
    return null;
  }
  if (!pool) {
    pool = new Pool({
      connectionString: DATABASE_URL,
      connectionTimeoutMillis: DATABASE_CONNECTION_TIMEOUT_MS,
      idleTimeoutMillis: DATABASE_IDLE_TIMEOUT_MS,
      max: DATABASE_POOL_MAX,
      ssl: DATABASE_SSL_ENABLED
        ? { rejectUnauthorized: false }
        : undefined
    });
  }
  return pool;
}

export function getStoreMode() {
  return STORE_MODE;
}

export function getStoreDiagnostics() {
  return {
    configured: Boolean(DATABASE_URL),
    targetHost: STORE_TARGET_HOST,
    targetPort: STORE_TARGET_PORT,
    targetDatabase: STORE_TARGET_DATABASE,
    sslEnabled: DATABASE_SSL_ENABLED,
    connectionTimeoutMs: DATABASE_CONNECTION_TIMEOUT_MS,
    poolMax: DATABASE_POOL_MAX
  };
}

export async function probeStoreConnectivity() {
  const diagnostics = getStoreDiagnostics();
  if (!diagnostics.configured || STORE_MODE !== "postgres") {
    return {
      dnsOk: false,
      tcpOk: false,
      dnsAddress: "",
      probeError: diagnostics.configured ? "" : "DATABASE_URL missing"
    };
  }

  let dnsAddress = "";
  try {
    const lookup = await dns.lookup(STORE_TARGET_HOST);
    dnsAddress = lookup.address || "";
  } catch (error) {
    return {
      dnsOk: false,
      tcpOk: false,
      dnsAddress: "",
      probeError: error instanceof Error ? error.message : String(error)
    };
  }

  try {
    await new Promise((resolve, reject) => {
      const socket = net.createConnection({
        host: STORE_TARGET_HOST,
        port: STORE_TARGET_PORT,
        timeout: Math.min(DATABASE_CONNECTION_TIMEOUT_MS, 5000)
      });
      socket.once("connect", () => {
        socket.destroy();
        resolve(true);
      });
      socket.once("timeout", () => {
        socket.destroy();
        reject(new Error("TCP probe timeout"));
      });
      socket.once("error", (error) => {
        socket.destroy();
        reject(error);
      });
    });

    return {
      dnsOk: true,
      tcpOk: true,
      dnsAddress,
      probeError: ""
    };
  } catch (error) {
    return {
      dnsOk: true,
      tcpOk: false,
      dnsAddress,
      probeError: error instanceof Error ? error.message : String(error)
    };
  }
}

export async function initStore() {
  if (initialized) {
    return;
  }

  if (STORE_MODE === "postgres") {
    const activePool = getPool();
    await activePool.query(`
      CREATE TABLE IF NOT EXISTS backdoor_requests (
        email TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        location TEXT NOT NULL,
        code TEXT NOT NULL,
        requested_at TIMESTAMPTZ NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        verify_attempts INTEGER NOT NULL DEFAULT 0
      );
    `);
    await activePool.query(`
      CREATE TABLE IF NOT EXISTS user_profiles (
        email TEXT PRIMARY KEY,
        player_id TEXT NOT NULL,
        provider TEXT NOT NULL,
        display_name TEXT NOT NULL,
        location TEXT,
        registered_at TIMESTAMPTZ,
        authenticated_at TIMESTAMPTZ NOT NULL,
        google_id TEXT
      );
    `);
    await activePool.query(`
      CREATE TABLE IF NOT EXISTS account_deletion_requests (
        email TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        provider TEXT NOT NULL,
        code TEXT NOT NULL,
        requested_at TIMESTAMPTZ NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        verify_attempts INTEGER NOT NULL DEFAULT 0
      );
    `);
    await activePool.query(`
      CREATE TABLE IF NOT EXISTS google_device_sessions (
        device_code TEXT PRIMARY KEY,
        user_code TEXT UNIQUE NOT NULL,
        status TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        profile_json JSONB
      );
    `);
    await activePool.query(`
      CREATE TABLE IF NOT EXISTS play_games_profiles (
        play_games_player_id TEXT PRIMARY KEY,
        player_id TEXT NOT NULL,
        display_name TEXT NOT NULL,
        title TEXT,
        icon_image_uri TEXT,
        registered_at TIMESTAMPTZ,
        authenticated_at TIMESTAMPTZ NOT NULL
      );
    `);
    await activePool.query(`
      CREATE TABLE IF NOT EXISTS community_profiles (
        player_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        provider TEXT NOT NULL,
        email TEXT,
        referral_code TEXT UNIQUE NOT NULL,
        referred_by_code TEXT,
        pod_id TEXT,
        created_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL
      );
    `);
    await activePool.query(`
      CREATE TABLE IF NOT EXISTS community_pods (
        pod_id TEXT PRIMARY KEY,
        invite_code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        captain_player_id TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL
      );
    `);
    await activePool.query(`
      CREATE TABLE IF NOT EXISTS daily_scores (
        day_key TEXT NOT NULL,
        player_id TEXT NOT NULL,
        display_name TEXT NOT NULL,
        score_value INTEGER NOT NULL,
        best_wave INTEGER NOT NULL,
        dna_earned INTEGER NOT NULL DEFAULT 0,
        archetype_id TEXT,
        chapter_id TEXT,
        challenge_label TEXT,
        submitted_at TIMESTAMPTZ NOT NULL,
        PRIMARY KEY (day_key, player_id)
      );
    `);
    await activePool.query(`
      CREATE TABLE IF NOT EXISTS weekly_scores (
        week_key TEXT NOT NULL,
        player_id TEXT NOT NULL,
        display_name TEXT NOT NULL,
        score_value INTEGER NOT NULL,
        best_wave INTEGER NOT NULL,
        dna_earned INTEGER NOT NULL DEFAULT 0,
        archetype_id TEXT,
        chapter_id TEXT,
        challenge_label TEXT,
        submitted_at TIMESTAMPTZ NOT NULL,
        PRIMARY KEY (week_key, player_id)
      );
    `);
    await activePool.query(`
      CREATE TABLE IF NOT EXISTS telemetry_sessions (
        id BIGSERIAL PRIMARY KEY,
        received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        session_day DATE NOT NULL,
        app_version TEXT,
        build_number INTEGER,
        platform TEXT,
        language TEXT,
        graphics_mode TEXT,
        wave_reached INTEGER NOT NULL,
        highest_boss_wave_killed INTEGER NOT NULL DEFAULT 0,
        kills INTEGER NOT NULL DEFAULT 0,
        elite_kills INTEGER NOT NULL DEFAULT 0,
        boss_kills INTEGER NOT NULL DEFAULT 0,
        dna_earned INTEGER NOT NULL DEFAULT 0,
        dna_pickups INTEGER NOT NULL DEFAULT 0,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        archetype_id TEXT,
        chapter_id TEXT,
        mutation_picks INTEGER NOT NULL DEFAULT 0,
        active_mutation_count INTEGER NOT NULL DEFAULT 0,
        infection_phases INTEGER NOT NULL DEFAULT 0,
        revive_used BOOLEAN NOT NULL DEFAULT FALSE,
        dna_boost_used BOOLEAN NOT NULL DEFAULT FALSE,
        runtime_category_levels JSONB,
        top_runtime_upgrades JSONB,
        payload_json JSONB
      );
    `);
    await activePool.query(`
      CREATE TABLE IF NOT EXISTS telemetry_daily_digests (
        digest_day DATE PRIMARY KEY,
        sent_at TIMESTAMPTZ NOT NULL
      );
    `);
    await activePool.query("CREATE INDEX IF NOT EXISTS idx_backdoor_requests_expires_at ON backdoor_requests (expires_at);");
    await activePool.query("CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_expires_at ON account_deletion_requests (expires_at);");
    await activePool.query("CREATE INDEX IF NOT EXISTS idx_google_device_sessions_expires_at ON google_device_sessions (expires_at);");
    await activePool.query("CREATE INDEX IF NOT EXISTS idx_community_profiles_referral_code ON community_profiles (referral_code);");
    await activePool.query("CREATE INDEX IF NOT EXISTS idx_community_profiles_pod_id ON community_profiles (pod_id);");
    await activePool.query("CREATE INDEX IF NOT EXISTS idx_community_pods_invite_code ON community_pods (invite_code);");
    await activePool.query("CREATE INDEX IF NOT EXISTS idx_daily_scores_day_key ON daily_scores (day_key);");
    await activePool.query("CREATE INDEX IF NOT EXISTS idx_weekly_scores_week_key ON weekly_scores (week_key);");
    await activePool.query("CREATE INDEX IF NOT EXISTS idx_telemetry_sessions_session_day ON telemetry_sessions (session_day);");
  } else {
    ensureLocalStore();
  }

  initialized = true;
}

export async function cleanupExpiredEntries() {
  await initStore();
  if (STORE_MODE === "postgres") {
    const activePool = getPool();
    await activePool.query("DELETE FROM backdoor_requests WHERE expires_at < NOW();");
    await activePool.query("DELETE FROM account_deletion_requests WHERE expires_at < NOW();");
    await activePool.query("DELETE FROM google_device_sessions WHERE expires_at < NOW();");
    return;
  }

  const store = readLocalStore();
  const now = Date.now();
  for (const [email, request] of Object.entries(store.backdoorRequests)) {
    if (Number(request.expiresAt || 0) < now) {
      delete store.backdoorRequests[email];
    }
  }
  for (const [email, request] of Object.entries(store.accountDeletionRequests)) {
    if (Number(request.expiresAt || 0) < now) {
      delete store.accountDeletionRequests[email];
    }
  }
  for (const [deviceCode, entry] of Object.entries(store.googleDeviceSessions)) {
    if (Number(entry.expiresAt || 0) < now) {
      delete store.googleDeviceSessions[deviceCode];
    }
  }
  writeLocalStore(store);
}

export async function getBackdoorRequest(email) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      SELECT
        email,
        display_name,
        location,
        code,
        requested_at,
        expires_at,
        verify_attempts
      FROM backdoor_requests
      WHERE email = $1
      LIMIT 1;
    `, [email]);
    if (result.rowCount === 0) {
      return null;
    }
    const row = result.rows[0];
    return {
      displayName: row.display_name,
      email: row.email,
      location: row.location,
      code: row.code,
      requestedAt: toIsoString(row.requested_at),
      expiresAt: new Date(row.expires_at).getTime(),
      verifyAttempts: Number(row.verify_attempts || 0)
    };
  }

  const store = readLocalStore();
  return store.backdoorRequests[email] || null;
}

export async function upsertBackdoorRequest(request) {
  await initStore();
  if (STORE_MODE === "postgres") {
    await getPool().query(`
      INSERT INTO backdoor_requests (
        email,
        display_name,
        location,
        code,
        requested_at,
        expires_at,
        verify_attempts
      ) VALUES ($1, $2, $3, $4, $5::timestamptz, $6::timestamptz, $7)
      ON CONFLICT (email) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        location = EXCLUDED.location,
        code = EXCLUDED.code,
        requested_at = EXCLUDED.requested_at,
        expires_at = EXCLUDED.expires_at,
        verify_attempts = EXCLUDED.verify_attempts;
    `, [
      request.email,
      request.displayName,
      request.location,
      request.code,
      request.requestedAt,
      new Date(Number(request.expiresAt || 0)).toISOString(),
      Number(request.verifyAttempts || 0)
    ]);
    return;
  }

  const store = readLocalStore();
  store.backdoorRequests[request.email] = request;
  writeLocalStore(store);
}

export async function incrementBackdoorVerifyAttempts(email) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      UPDATE backdoor_requests
      SET verify_attempts = verify_attempts + 1
      WHERE email = $1
      RETURNING verify_attempts;
    `, [email]);
    return result.rowCount > 0 ? Number(result.rows[0].verify_attempts || 0) : 0;
  }

  const store = readLocalStore();
  if (!store.backdoorRequests[email]) {
    return 0;
  }
  store.backdoorRequests[email].verifyAttempts = Number(store.backdoorRequests[email].verifyAttempts || 0) + 1;
  writeLocalStore(store);
  return Number(store.backdoorRequests[email].verifyAttempts || 0);
}

export async function deleteBackdoorRequest(email) {
  await initStore();
  if (STORE_MODE === "postgres") {
    await getPool().query("DELETE FROM backdoor_requests WHERE email = $1;", [email]);
    return;
  }

  const store = readLocalStore();
  delete store.backdoorRequests[email];
  writeLocalStore(store);
}

export async function getAccountDeletionRequest(email) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      SELECT
        email,
        display_name,
        provider,
        code,
        requested_at,
        expires_at,
        verify_attempts
      FROM account_deletion_requests
      WHERE email = $1
      LIMIT 1;
    `, [email]);
    if (result.rowCount === 0) {
      return null;
    }
    const row = result.rows[0];
    return {
      displayName: row.display_name,
      email: row.email,
      provider: row.provider,
      code: row.code,
      requestedAt: toIsoString(row.requested_at),
      expiresAt: new Date(row.expires_at).getTime(),
      verifyAttempts: Number(row.verify_attempts || 0)
    };
  }

  const store = readLocalStore();
  return store.accountDeletionRequests[email] || null;
}

export async function upsertAccountDeletionRequest(request) {
  await initStore();
  if (STORE_MODE === "postgres") {
    await getPool().query(`
      INSERT INTO account_deletion_requests (
        email,
        display_name,
        provider,
        code,
        requested_at,
        expires_at,
        verify_attempts
      ) VALUES ($1, $2, $3, $4, $5::timestamptz, $6::timestamptz, $7)
      ON CONFLICT (email) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        provider = EXCLUDED.provider,
        code = EXCLUDED.code,
        requested_at = EXCLUDED.requested_at,
        expires_at = EXCLUDED.expires_at,
        verify_attempts = EXCLUDED.verify_attempts;
    `, [
      request.email,
      request.displayName,
      request.provider,
      request.code,
      request.requestedAt,
      new Date(Number(request.expiresAt || 0)).toISOString(),
      Number(request.verifyAttempts || 0)
    ]);
    return;
  }

  const store = readLocalStore();
  store.accountDeletionRequests[request.email] = request;
  writeLocalStore(store);
}

export async function incrementAccountDeletionVerifyAttempts(email) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      UPDATE account_deletion_requests
      SET verify_attempts = verify_attempts + 1
      WHERE email = $1
      RETURNING verify_attempts;
    `, [email]);
    return result.rowCount > 0 ? Number(result.rows[0].verify_attempts || 0) : 0;
  }

  const store = readLocalStore();
  if (!store.accountDeletionRequests[email]) {
    return 0;
  }
  store.accountDeletionRequests[email].verifyAttempts = Number(store.accountDeletionRequests[email].verifyAttempts || 0) + 1;
  writeLocalStore(store);
  return Number(store.accountDeletionRequests[email].verifyAttempts || 0);
}

export async function deleteAccountDeletionRequest(email) {
  await initStore();
  if (STORE_MODE === "postgres") {
    await getPool().query("DELETE FROM account_deletion_requests WHERE email = $1;", [email]);
    return;
  }

  const store = readLocalStore();
  delete store.accountDeletionRequests[email];
  writeLocalStore(store);
}

export async function upsertUserProfile(profile) {
  await initStore();
  if (STORE_MODE === "postgres") {
    await getPool().query(`
      INSERT INTO user_profiles (
        email,
        player_id,
        provider,
        display_name,
        location,
        registered_at,
        authenticated_at,
        google_id
      ) VALUES ($1, $2, $3, $4, $5, $6::timestamptz, $7::timestamptz, $8)
      ON CONFLICT (email) DO UPDATE SET
        player_id = EXCLUDED.player_id,
        provider = EXCLUDED.provider,
        display_name = EXCLUDED.display_name,
        location = EXCLUDED.location,
        registered_at = EXCLUDED.registered_at,
        authenticated_at = EXCLUDED.authenticated_at,
        google_id = EXCLUDED.google_id;
    `, [
      profile.email,
      profile.playerId,
      profile.provider,
      profile.displayName,
      profile.location || null,
      profile.registeredAt || profile.authenticatedAt,
      profile.authenticatedAt,
      profile.googleId || null
    ]);
    return;
  }

  const store = readLocalStore();
  store.userProfiles[profile.email] = profile;
  writeLocalStore(store);
}

export async function deleteUserProfileByEmail(email) {
  await initStore();
  if (STORE_MODE === "postgres") {
    await getPool().query("DELETE FROM user_profiles WHERE email = $1;", [email]);
    return;
  }

  const store = readLocalStore();
  delete store.userProfiles[email];
  writeLocalStore(store);
}

export async function createGoogleDeviceSession(entry) {
  await initStore();
  if (STORE_MODE === "postgres") {
    await getPool().query(`
      INSERT INTO google_device_sessions (
        device_code,
        user_code,
        status,
        created_at,
        expires_at,
        profile_json
      ) VALUES ($1, $2, $3, $4::timestamptz, $5::timestamptz, $6::jsonb)
      ON CONFLICT (device_code) DO UPDATE SET
        user_code = EXCLUDED.user_code,
        status = EXCLUDED.status,
        created_at = EXCLUDED.created_at,
        expires_at = EXCLUDED.expires_at,
        profile_json = EXCLUDED.profile_json;
    `, [
      entry.deviceCode,
      entry.userCode,
      entry.status,
      entry.createdAt,
      new Date(Number(entry.expiresAt || 0)).toISOString(),
      entry.profile ? JSON.stringify(entry.profile) : null
    ]);
    return;
  }

  const store = readLocalStore();
  store.googleDeviceSessions[entry.deviceCode] = entry;
  writeLocalStore(store);
}

function mapGoogleSession(row) {
  if (!row) {
    return null;
  }
  return {
    deviceCode: row.device_code,
    userCode: row.user_code,
    status: row.status,
    createdAt: toIsoString(row.created_at),
    expiresAt: new Date(row.expires_at).getTime(),
    profile: row.profile_json || null
  };
}

export async function getGoogleDeviceSession(deviceCode) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      SELECT
        device_code,
        user_code,
        status,
        created_at,
        expires_at,
        profile_json
      FROM google_device_sessions
      WHERE device_code = $1
      LIMIT 1;
    `, [deviceCode]);
    return result.rowCount > 0 ? mapGoogleSession(result.rows[0]) : null;
  }

  const store = readLocalStore();
  return store.googleDeviceSessions[deviceCode] || null;
}

export async function getGoogleDeviceSessionByUserCode(userCode) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      SELECT
        device_code,
        user_code,
        status,
        created_at,
        expires_at,
        profile_json
      FROM google_device_sessions
      WHERE user_code = $1
      LIMIT 1;
    `, [userCode]);
    return result.rowCount > 0 ? mapGoogleSession(result.rows[0]) : null;
  }

  const store = readLocalStore();
  const match = Object.values(store.googleDeviceSessions).find((entry) => entry.userCode === userCode);
  return match || null;
}

export async function updateGoogleDeviceSession(deviceCode, patch) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const existing = await getGoogleDeviceSession(deviceCode);
    if (!existing) {
      return null;
    }
    const next = {
      ...existing,
      ...patch
    };
    await createGoogleDeviceSession(next);
    return next;
  }

  const store = readLocalStore();
  const existing = store.googleDeviceSessions[deviceCode];
  if (!existing) {
    return null;
  }
  const next = {
    ...existing,
    ...patch
  };
  store.googleDeviceSessions[deviceCode] = next;
  writeLocalStore(store);
  return next;
}

function mapPlayGamesProfile(row) {
  if (!row) {
    return null;
  }
  return {
    playerId: row.player_id,
    provider: "play_games",
    displayName: row.display_name,
    email: "",
    location: "",
    registeredAt: toIsoString(row.registered_at),
    authenticatedAt: toIsoString(row.authenticated_at),
    playGamesPlayerId: row.play_games_player_id,
    playGamesTitle: row.title || "",
    playGamesIconImageUri: row.icon_image_uri || ""
  };
}

export async function getPlayGamesProfile(playGamesPlayerId) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      SELECT
        play_games_player_id,
        player_id,
        display_name,
        title,
        icon_image_uri,
        registered_at,
        authenticated_at
      FROM play_games_profiles
      WHERE play_games_player_id = $1
      LIMIT 1;
    `, [playGamesPlayerId]);
    return result.rowCount > 0 ? mapPlayGamesProfile(result.rows[0]) : null;
  }

  const store = readLocalStore();
  return store.playGamesProfiles[playGamesPlayerId] || null;
}

export async function upsertPlayGamesProfile(profile) {
  await initStore();
  const existing = await getPlayGamesProfile(profile.playGamesPlayerId);
  const nextProfile = {
    ...existing,
    ...profile,
    provider: "play_games",
    playerId: String(existing?.playerId || profile.playerId || ""),
    registeredAt: existing?.registeredAt || profile.registeredAt || profile.authenticatedAt
  };

  if (STORE_MODE === "postgres") {
    await getPool().query(`
      INSERT INTO play_games_profiles (
        play_games_player_id,
        player_id,
        display_name,
        title,
        icon_image_uri,
        registered_at,
        authenticated_at
      ) VALUES ($1, $2, $3, $4, $5, $6::timestamptz, $7::timestamptz)
      ON CONFLICT (play_games_player_id) DO UPDATE SET
        player_id = EXCLUDED.player_id,
        display_name = EXCLUDED.display_name,
        title = EXCLUDED.title,
        icon_image_uri = EXCLUDED.icon_image_uri,
        registered_at = EXCLUDED.registered_at,
        authenticated_at = EXCLUDED.authenticated_at;
    `, [
      nextProfile.playGamesPlayerId,
      nextProfile.playerId,
      nextProfile.displayName,
      nextProfile.playGamesTitle || null,
      nextProfile.playGamesIconImageUri || null,
      nextProfile.registeredAt || nextProfile.authenticatedAt,
      nextProfile.authenticatedAt
    ]);
    return nextProfile;
  }

  const store = readLocalStore();
  store.playGamesProfiles[nextProfile.playGamesPlayerId] = nextProfile;
  writeLocalStore(store);
  return nextProfile;
}

export async function deletePlayGamesProfile(playGamesPlayerId) {
  await initStore();
  if (STORE_MODE === "postgres") {
    await getPool().query("DELETE FROM play_games_profiles WHERE play_games_player_id = $1;", [playGamesPlayerId]);
    return;
  }

  const store = readLocalStore();
  delete store.playGamesProfiles[playGamesPlayerId];
  writeLocalStore(store);
}

function buildReferralCode(playerId) {
  const suffix = crypto
    .createHash("sha1")
    .update(`${String(playerId || "")}:${Date.now()}:${Math.random()}`)
    .digest("hex")
    .slice(0, 8)
    .toUpperCase();
  return `CELL-${suffix}`;
}

function buildPodId() {
  return `pod_${crypto.randomBytes(8).toString("hex")}`;
}

function buildInviteCode() {
  return crypto.randomBytes(5).toString("hex").toUpperCase();
}

function mapCommunityProfile(row) {
  if (!row) {
    return null;
  }
  return {
    playerId: row.player_id,
    displayName: row.display_name,
    provider: row.provider,
    email: row.email || "",
    referralCode: row.referral_code,
    referredByCode: row.referred_by_code || "",
    podId: row.pod_id || "",
    createdAt: toIsoString(row.created_at),
    updatedAt: toIsoString(row.updated_at)
  };
}

function mapCommunityPod(row, members = []) {
  if (!row) {
    return null;
  }
  return {
    podId: row.pod_id,
    inviteCode: row.invite_code,
    name: row.name,
    captainPlayerId: row.captain_player_id,
    createdAt: toIsoString(row.created_at),
    members
  };
}

export async function getCommunityProfile(playerId) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      SELECT
        player_id,
        display_name,
        provider,
        email,
        referral_code,
        referred_by_code,
        pod_id,
        created_at,
        updated_at
      FROM community_profiles
      WHERE player_id = $1
      LIMIT 1;
    `, [playerId]);
    return result.rowCount > 0 ? mapCommunityProfile(result.rows[0]) : null;
  }

  const store = readLocalStore();
  return store.communityProfiles[playerId] || null;
}

export async function getCommunityProfileByReferralCode(referralCode) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      SELECT
        player_id,
        display_name,
        provider,
        email,
        referral_code,
        referred_by_code,
        pod_id,
        created_at,
        updated_at
      FROM community_profiles
      WHERE referral_code = $1
      LIMIT 1;
    `, [referralCode]);
    return result.rowCount > 0 ? mapCommunityProfile(result.rows[0]) : null;
  }

  const store = readLocalStore();
  return Object.values(store.communityProfiles).find((profile) => profile.referralCode === referralCode) || null;
}

export async function upsertCommunityProfile(profile) {
  await initStore();
  const existing = await getCommunityProfile(profile.playerId);
  const nextProfile = {
    playerId: String(existing?.playerId || profile.playerId || ""),
    displayName: String(profile.displayName || existing?.displayName || "Cell Pilot"),
    provider: String(profile.provider || existing?.provider || "guest"),
    email: String(profile.email || existing?.email || ""),
    referralCode: String(existing?.referralCode || profile.referralCode || buildReferralCode(profile.playerId)),
    referredByCode: String(existing?.referredByCode || profile.referredByCode || ""),
    podId: String(profile.podId || existing?.podId || ""),
    createdAt: existing?.createdAt || profile.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };

  if (STORE_MODE === "postgres") {
    await getPool().query(`
      INSERT INTO community_profiles (
        player_id,
        display_name,
        provider,
        email,
        referral_code,
        referred_by_code,
        pod_id,
        created_at,
        updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8::timestamptz, $9::timestamptz)
      ON CONFLICT (player_id) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        provider = EXCLUDED.provider,
        email = EXCLUDED.email,
        referral_code = EXCLUDED.referral_code,
        referred_by_code = EXCLUDED.referred_by_code,
        pod_id = EXCLUDED.pod_id,
        created_at = EXCLUDED.created_at,
        updated_at = EXCLUDED.updated_at;
    `, [
      nextProfile.playerId,
      nextProfile.displayName,
      nextProfile.provider,
      nextProfile.email || null,
      nextProfile.referralCode,
      nextProfile.referredByCode || null,
      nextProfile.podId || null,
      nextProfile.createdAt,
      nextProfile.updatedAt
    ]);
    return nextProfile;
  }

  const store = readLocalStore();
  store.communityProfiles[nextProfile.playerId] = nextProfile;
  writeLocalStore(store);
  return nextProfile;
}

export async function redeemCommunityReferral(playerId, referralCode) {
  await initStore();
  const profile = await getCommunityProfile(playerId);
  if (!profile) {
    return { ok: false, reason: "profile_not_found" };
  }
  if (profile.referredByCode) {
    return { ok: false, reason: "referral_already_used" };
  }
  const referrer = await getCommunityProfileByReferralCode(referralCode);
  if (!referrer) {
    return { ok: false, reason: "referral_not_found" };
  }
  if (referrer.playerId === playerId) {
    return { ok: false, reason: "referral_self" };
  }
  profile.referredByCode = referralCode;
  await upsertCommunityProfile(profile);
  return { ok: true, profile };
}

export async function getCommunityPod(podId) {
  await initStore();
  if (!podId) {
    return null;
  }
  if (STORE_MODE === "postgres") {
    const podResult = await getPool().query(`
      SELECT
        pod_id,
        invite_code,
        name,
        captain_player_id,
        created_at
      FROM community_pods
      WHERE pod_id = $1
      LIMIT 1;
    `, [podId]);
    if (podResult.rowCount === 0) {
      return null;
    }
    const membersResult = await getPool().query(`
      SELECT player_id, display_name
      FROM community_profiles
      WHERE pod_id = $1
      ORDER BY updated_at DESC, display_name ASC;
    `, [podId]);
    return mapCommunityPod(podResult.rows[0], membersResult.rows.map((row) => ({
      playerId: row.player_id,
      displayName: row.display_name
    })));
  }

  const store = readLocalStore();
  const pod = store.communityPods[podId];
  if (!pod) {
    return null;
  }
  const members = Object.values(store.communityProfiles)
    .filter((profile) => profile.podId === podId)
    .map((profile) => ({
      playerId: profile.playerId,
      displayName: profile.displayName
    }));
  return {
    ...pod,
    members
  };
}

export async function getCommunityPodByInviteCode(inviteCode) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      SELECT
        pod_id,
        invite_code,
        name,
        captain_player_id,
        created_at
      FROM community_pods
      WHERE invite_code = $1
      LIMIT 1;
    `, [inviteCode]);
    return result.rowCount > 0 ? result.rows[0] : null;
  }

  const store = readLocalStore();
  return Object.values(store.communityPods).find((pod) => pod.inviteCode === inviteCode) || null;
}

export async function createCommunityPod(playerId, podName) {
  await initStore();
  const profile = await getCommunityProfile(playerId);
  if (!profile) {
    return { ok: false, reason: "profile_not_found" };
  }
  const podId = buildPodId();
  const inviteCode = buildInviteCode();
  const createdAt = new Date().toISOString();

  if (STORE_MODE === "postgres") {
    await getPool().query(`
      INSERT INTO community_pods (
        pod_id,
        invite_code,
        name,
        captain_player_id,
        created_at
      ) VALUES ($1, $2, $3, $4, $5::timestamptz);
    `, [podId, inviteCode, podName, playerId, createdAt]);
  } else {
    const store = readLocalStore();
    store.communityPods[podId] = {
      podId,
      inviteCode,
      name: podName,
      captainPlayerId: playerId,
      createdAt
    };
    writeLocalStore(store);
  }

  profile.podId = podId;
  await upsertCommunityProfile(profile);
  return {
    ok: true,
    pod: await getCommunityPod(podId)
  };
}

export async function joinCommunityPod(playerId, inviteCode) {
  await initStore();
  const profile = await getCommunityProfile(playerId);
  if (!profile) {
    return { ok: false, reason: "profile_not_found" };
  }
  const podRow = await getCommunityPodByInviteCode(inviteCode);
  if (!podRow) {
    return { ok: false, reason: "pod_not_found" };
  }
  const podId = podRow.pod_id || podRow.podId;
  profile.podId = podId;
  await upsertCommunityProfile(profile);
  return {
    ok: true,
    pod: await getCommunityPod(podId)
  };
}

export async function leaveCommunityPod(playerId) {
  await initStore();
  const profile = await getCommunityProfile(playerId);
  if (!profile) {
    return { ok: false, reason: "profile_not_found" };
  }
  const previousPodId = profile.podId;
  profile.podId = "";
  await upsertCommunityProfile(profile);
  return {
    ok: true,
    pod: previousPodId ? await getCommunityPod(previousPodId) : null
  };
}

export async function submitWeeklyScore(entry) {
  await initStore();
  const normalized = {
    weekKey: String(entry.weekKey || ""),
    playerId: String(entry.playerId || ""),
    displayName: String(entry.displayName || "Cell Pilot"),
    scoreValue: Number(entry.scoreValue || entry.bestWave || 0),
    bestWave: Number(entry.bestWave || entry.scoreValue || 0),
    dnaEarned: Number(entry.dnaEarned || 0),
    archetypeId: String(entry.archetypeId || ""),
    chapterId: String(entry.chapterId || ""),
    challengeLabel: String(entry.challengeLabel || ""),
    submittedAt: new Date().toISOString()
  };
  if (!normalized.weekKey || !normalized.playerId) {
    return null;
  }

  if (STORE_MODE === "postgres") {
    await getPool().query(`
      INSERT INTO weekly_scores (
        week_key,
        player_id,
        display_name,
        score_value,
        best_wave,
        dna_earned,
        archetype_id,
        chapter_id,
        challenge_label,
        submitted_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::timestamptz)
      ON CONFLICT (week_key, player_id) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        score_value = GREATEST(weekly_scores.score_value, EXCLUDED.score_value),
        best_wave = GREATEST(weekly_scores.best_wave, EXCLUDED.best_wave),
        dna_earned = GREATEST(weekly_scores.dna_earned, EXCLUDED.dna_earned),
        archetype_id = EXCLUDED.archetype_id,
        chapter_id = EXCLUDED.chapter_id,
        challenge_label = EXCLUDED.challenge_label,
        submitted_at = EXCLUDED.submitted_at;
    `, [
      normalized.weekKey,
      normalized.playerId,
      normalized.displayName,
      normalized.scoreValue,
      normalized.bestWave,
      normalized.dnaEarned,
      normalized.archetypeId || null,
      normalized.chapterId || null,
      normalized.challengeLabel || null,
      normalized.submittedAt
    ]);
    return normalized;
  }

  const store = readLocalStore();
  const scoreKey = `${normalized.weekKey}:${normalized.playerId}`;
  const existing = store.weeklyScores[scoreKey];
  if (!existing || Number(existing.scoreValue || 0) <= normalized.scoreValue) {
    store.weeklyScores[scoreKey] = normalized;
    writeLocalStore(store);
  }
  return normalized;
}

export async function submitDailyScore(entry) {
  await initStore();
  const normalized = {
    dayKey: String(entry.dayKey || ""),
    playerId: String(entry.playerId || ""),
    displayName: String(entry.displayName || "Cell Pilot"),
    scoreValue: Number(entry.scoreValue || entry.bestWave || 0),
    bestWave: Number(entry.bestWave || entry.scoreValue || 0),
    dnaEarned: Number(entry.dnaEarned || 0),
    archetypeId: String(entry.archetypeId || ""),
    chapterId: String(entry.chapterId || ""),
    challengeLabel: String(entry.challengeLabel || ""),
    submittedAt: new Date().toISOString()
  };
  if (!normalized.dayKey || !normalized.playerId) {
    return null;
  }

  if (STORE_MODE === "postgres") {
    await getPool().query(`
      INSERT INTO daily_scores (
        day_key,
        player_id,
        display_name,
        score_value,
        best_wave,
        dna_earned,
        archetype_id,
        chapter_id,
        challenge_label,
        submitted_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::timestamptz)
      ON CONFLICT (day_key, player_id) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        score_value = GREATEST(daily_scores.score_value, EXCLUDED.score_value),
        best_wave = GREATEST(daily_scores.best_wave, EXCLUDED.best_wave),
        dna_earned = GREATEST(daily_scores.dna_earned, EXCLUDED.dna_earned),
        archetype_id = EXCLUDED.archetype_id,
        chapter_id = EXCLUDED.chapter_id,
        challenge_label = EXCLUDED.challenge_label,
        submitted_at = EXCLUDED.submitted_at;
    `, [
      normalized.dayKey,
      normalized.playerId,
      normalized.displayName,
      normalized.scoreValue,
      normalized.bestWave,
      normalized.dnaEarned,
      normalized.archetypeId || null,
      normalized.chapterId || null,
      normalized.challengeLabel || null,
      normalized.submittedAt
    ]);
    return normalized;
  }

  const store = readLocalStore();
  const scoreKey = `${normalized.dayKey}:${normalized.playerId}`;
  const existing = store.dailyScores[scoreKey];
  if (!existing || Number(existing.scoreValue || 0) <= normalized.scoreValue) {
    store.dailyScores[scoreKey] = normalized;
    writeLocalStore(store);
  }
  return normalized;
}

export async function getWeeklyLeaderboard(weekKey, limit = 10) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      SELECT
        week_key,
        player_id,
        display_name,
        score_value,
        best_wave,
        dna_earned,
        archetype_id,
        chapter_id,
        challenge_label,
        submitted_at
      FROM weekly_scores
      WHERE week_key = $1
      ORDER BY score_value DESC, submitted_at ASC
      LIMIT $2;
    `, [weekKey, limit]);
    return result.rows.map((row, index) => ({
      rank: index + 1,
      weekKey: row.week_key,
      playerId: row.player_id,
      displayName: row.display_name,
      scoreValue: Number(row.score_value || 0),
      bestWave: Number(row.best_wave || 0),
      dnaEarned: Number(row.dna_earned || 0),
      archetypeId: row.archetype_id || "",
      chapterId: row.chapter_id || "",
      challengeLabel: row.challenge_label || "",
      submittedAt: toIsoString(row.submitted_at)
    }));
  }

  const store = readLocalStore();
  return Object.values(store.weeklyScores)
    .filter((entry) => entry.weekKey === weekKey)
    .sort((left, right) => Number(right.scoreValue || 0) - Number(left.scoreValue || 0))
    .slice(0, limit)
    .map((entry, index) => ({
      ...entry,
      rank: index + 1
    }));
}

export async function getDailyLeaderboard(dayKey, limit = 10) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      SELECT
        day_key,
        player_id,
        display_name,
        score_value,
        best_wave,
        dna_earned,
        archetype_id,
        chapter_id,
        challenge_label,
        submitted_at
      FROM daily_scores
      WHERE day_key = $1
      ORDER BY score_value DESC, submitted_at ASC
      LIMIT $2;
    `, [dayKey, limit]);
    return result.rows.map((row, index) => ({
      rank: index + 1,
      dayKey: row.day_key,
      playerId: row.player_id,
      displayName: row.display_name,
      scoreValue: Number(row.score_value || 0),
      bestWave: Number(row.best_wave || 0),
      dnaEarned: Number(row.dna_earned || 0),
      archetypeId: row.archetype_id || "",
      chapterId: row.chapter_id || "",
      challengeLabel: row.challenge_label || "",
      submittedAt: toIsoString(row.submitted_at)
    }));
  }

  const store = readLocalStore();
  return Object.values(store.dailyScores)
    .filter((entry) => entry.dayKey === dayKey)
    .sort((left, right) => Number(right.scoreValue || 0) - Number(left.scoreValue || 0))
    .slice(0, limit)
    .map((entry, index) => ({
      ...entry,
      rank: index + 1
    }));
}

export async function insertTelemetrySession(session) {
  await initStore();
  const normalized = {
    appVersion: String(session.appVersion || session.app_version || ""),
    buildNumber: Number(session.buildNumber || session.build_number || 0),
    platform: String(session.platform || ""),
    language: String(session.language || ""),
    graphicsMode: String(session.graphicsMode || session.graphics_mode || ""),
    waveReached: Number(session.waveReached || session.wave_reached || 1),
    highestBossWaveKilled: Number(session.highestBossWaveKilled || session.highest_boss_wave_killed || 0),
    kills: Number(session.kills || 0),
    eliteKills: Number(session.eliteKills || session.elite_kills || 0),
    bossKills: Number(session.bossKills || session.boss_kills || 0),
    dnaEarned: Number(session.dnaEarned || session.dna_earned || 0),
    dnaPickups: Number(session.dnaPickups || session.dna_pickups || 0),
    durationSeconds: Number(session.durationSeconds || session.duration_seconds || 0),
    archetypeId: String(session.archetypeId || session.archetype_id || ""),
    chapterId: String(session.chapterId || session.chapter_id || ""),
    mutationPicks: Number(session.mutationPicks || session.mutation_picks || 0),
    activeMutationCount: Number(session.activeMutationCount || session.active_mutation_count || 0),
    infectionPhases: Number(session.infectionPhases || session.infection_phases || 0),
    reviveUsed: Boolean(session.reviveUsed || session.revive_used),
    dnaBoostUsed: Boolean(session.dnaBoostUsed || session.dna_boost_used),
    runtimeCategoryLevels: session.runtimeCategoryLevels || session.runtime_category_levels || {},
    topRuntimeUpgrades: session.topRuntimeUpgrades || session.top_runtime_upgrades || [],
    payload: session.payload || session
  };
  const now = new Date();
  const digestDay = now.toISOString().slice(0, 10);

  if (STORE_MODE === "postgres") {
    await getPool().query(`
      INSERT INTO telemetry_sessions (
        session_day,
        app_version,
        build_number,
        platform,
        language,
        graphics_mode,
        wave_reached,
        highest_boss_wave_killed,
        kills,
        elite_kills,
        boss_kills,
        dna_earned,
        dna_pickups,
        duration_seconds,
        archetype_id,
        chapter_id,
        mutation_picks,
        active_mutation_count,
        infection_phases,
        revive_used,
        dna_boost_used,
        runtime_category_levels,
        top_runtime_upgrades,
        payload_json
      ) VALUES (
        $1::date,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9,
        $10,
        $11,
        $12,
        $13,
        $14,
        $15,
        $16,
        $17,
        $18,
        $19,
        $20,
        $21,
        $22::jsonb,
        $23::jsonb,
        $24::jsonb
      );
    `, [
      digestDay,
      normalized.appVersion,
      normalized.buildNumber,
      normalized.platform,
      normalized.language,
      normalized.graphicsMode,
      normalized.waveReached,
      normalized.highestBossWaveKilled,
      normalized.kills,
      normalized.eliteKills,
      normalized.bossKills,
      normalized.dnaEarned,
      normalized.dnaPickups,
      normalized.durationSeconds,
      normalized.archetypeId || null,
      normalized.chapterId || null,
      normalized.mutationPicks,
      normalized.activeMutationCount,
      normalized.infectionPhases,
      normalized.reviveUsed,
      normalized.dnaBoostUsed,
      JSON.stringify(normalized.runtimeCategoryLevels || {}),
      JSON.stringify(normalized.topRuntimeUpgrades || []),
      JSON.stringify(normalized.payload || {})
    ]);
    return digestDay;
  }

  const store = readLocalStore();
  store.telemetrySessions.push({
    ...normalized,
    receivedAt: now.toISOString(),
    sessionDay: digestDay
  });
  while (store.telemetrySessions.length > 500) {
    store.telemetrySessions.shift();
  }
  writeLocalStore(store);
  return digestDay;
}

export async function hasTelemetryDigestBeenSent(digestDay) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const result = await getPool().query(`
      SELECT digest_day
      FROM telemetry_daily_digests
      WHERE digest_day = $1::date
      LIMIT 1;
    `, [digestDay]);
    return result.rowCount > 0;
  }

  const store = readLocalStore();
  return Boolean(store.telemetryDailyDigests[digestDay]);
}

export async function markTelemetryDigestSent(digestDay, sentAt = new Date().toISOString()) {
  await initStore();
  if (STORE_MODE === "postgres") {
    await getPool().query(`
      INSERT INTO telemetry_daily_digests (digest_day, sent_at)
      VALUES ($1::date, $2::timestamptz)
      ON CONFLICT (digest_day) DO UPDATE SET
        sent_at = EXCLUDED.sent_at;
    `, [digestDay, sentAt]);
    return;
  }

  const store = readLocalStore();
  store.telemetryDailyDigests[digestDay] = sentAt;
  writeLocalStore(store);
}

export async function getTelemetryDigestReport(digestDay) {
  await initStore();
  if (STORE_MODE === "postgres") {
    const summaryResult = await getPool().query(`
      SELECT
        COUNT(*) AS session_count,
        COALESCE(AVG(wave_reached), 0) AS avg_wave,
        COALESCE(MAX(wave_reached), 0) AS max_wave,
        COALESCE(AVG(duration_seconds), 0) AS avg_duration,
        COALESCE(AVG(dna_earned), 0) AS avg_dna,
        COALESCE(AVG(kills), 0) AS avg_kills,
        COALESCE(SUM(CASE WHEN revive_used THEN 1 ELSE 0 END), 0) AS revive_runs,
        COALESCE(SUM(CASE WHEN dna_boost_used THEN 1 ELSE 0 END), 0) AS dna_boost_runs,
        COALESCE(AVG(mutation_picks), 0) AS avg_mutations,
        COALESCE(AVG(infection_phases), 0) AS avg_infections
      FROM telemetry_sessions
      WHERE session_day = $1::date;
    `, [digestDay]);
    const breakdownResult = await getPool().query(`
      SELECT
        chapter_id,
        archetype_id,
        COUNT(*) AS session_count,
        COALESCE(AVG(wave_reached), 0) AS avg_wave
      FROM telemetry_sessions
      WHERE session_day = $1::date
      GROUP BY chapter_id, archetype_id
      ORDER BY session_count DESC, avg_wave DESC
      LIMIT 5;
    `, [digestDay]);
    const topUpgradeResult = await getPool().query(`
      SELECT
        upgrade_item->>'id' AS upgrade_id,
        AVG(COALESCE((upgrade_item->>'level')::int, 0)) AS avg_level,
        COUNT(*) AS appearances
      FROM telemetry_sessions
      CROSS JOIN LATERAL jsonb_array_elements(COALESCE(top_runtime_upgrades, '[]'::jsonb)) AS upgrade_item
      WHERE session_day = $1::date
      GROUP BY upgrade_id
      ORDER BY appearances DESC, avg_level DESC
      LIMIT 5;
    `, [digestDay]);
    const summaryRow = summaryResult.rows[0] || {};
    return {
      sessionCount: Number(summaryRow.session_count || 0),
      avgWave: Number(summaryRow.avg_wave || 0),
      maxWave: Number(summaryRow.max_wave || 0),
      avgDuration: Number(summaryRow.avg_duration || 0),
      avgDna: Number(summaryRow.avg_dna || 0),
      avgKills: Number(summaryRow.avg_kills || 0),
      reviveRuns: Number(summaryRow.revive_runs || 0),
      dnaBoostRuns: Number(summaryRow.dna_boost_runs || 0),
      avgMutations: Number(summaryRow.avg_mutations || 0),
      avgInfections: Number(summaryRow.avg_infections || 0),
      topLoadouts: breakdownResult.rows.map((row) => ({
        chapterId: row.chapter_id || "",
        archetypeId: row.archetype_id || "",
        sessionCount: Number(row.session_count || 0),
        avgWave: Number(row.avg_wave || 0)
      })),
      topUpgrades: topUpgradeResult.rows.map((row) => ({
        upgradeId: row.upgrade_id || "",
        avgLevel: Number(row.avg_level || 0),
        appearances: Number(row.appearances || 0)
      }))
    };
  }

  const store = readLocalStore();
  const daySessions = store.telemetrySessions.filter((entry) => entry.sessionDay === digestDay);
  if (daySessions.length === 0) {
    return {
      sessionCount: 0,
      avgWave: 0,
      maxWave: 0,
      avgDuration: 0,
      avgDna: 0,
      avgKills: 0,
      reviveRuns: 0,
      dnaBoostRuns: 0,
      avgMutations: 0,
      avgInfections: 0,
      topLoadouts: [],
      topUpgrades: []
    };
  }

  const loadouts = new Map();
  const upgrades = new Map();
  let totalWave = 0;
  let maxWave = 0;
  let totalDuration = 0;
  let totalDna = 0;
  let totalKills = 0;
  let reviveRuns = 0;
  let dnaBoostRuns = 0;
  let totalMutations = 0;
  let totalInfections = 0;

  for (const session of daySessions) {
    totalWave += Number(session.waveReached || 0);
    maxWave = Math.max(maxWave, Number(session.waveReached || 0));
    totalDuration += Number(session.durationSeconds || 0);
    totalDna += Number(session.dnaEarned || 0);
    totalKills += Number(session.kills || 0);
    totalMutations += Number(session.mutationPicks || 0);
    totalInfections += Number(session.infectionPhases || 0);
    if (session.reviveUsed) {
      reviveRuns += 1;
    }
    if (session.dnaBoostUsed) {
      dnaBoostRuns += 1;
    }

    const loadoutKey = `${session.chapterId || ""}|${session.archetypeId || ""}`;
    const loadoutEntry = loadouts.get(loadoutKey) || {
      chapterId: session.chapterId || "",
      archetypeId: session.archetypeId || "",
      sessionCount: 0,
      waveTotal: 0
    };
    loadoutEntry.sessionCount += 1;
    loadoutEntry.waveTotal += Number(session.waveReached || 0);
    loadouts.set(loadoutKey, loadoutEntry);

    for (const upgrade of Array.isArray(session.topRuntimeUpgrades) ? session.topRuntimeUpgrades : []) {
      const upgradeId = String(upgrade.id || "");
      if (!upgradeId) {
        continue;
      }
      const upgradeEntry = upgrades.get(upgradeId) || {
        upgradeId,
        appearances: 0,
        levelTotal: 0
      };
      upgradeEntry.appearances += 1;
      upgradeEntry.levelTotal += Number(upgrade.level || 0);
      upgrades.set(upgradeId, upgradeEntry);
    }
  }

  const topLoadouts = Array.from(loadouts.values())
    .sort((a, b) => b.sessionCount - a.sessionCount || b.waveTotal - a.waveTotal)
    .slice(0, 5)
    .map((entry) => ({
      chapterId: entry.chapterId,
      archetypeId: entry.archetypeId,
      sessionCount: entry.sessionCount,
      avgWave: entry.sessionCount > 0 ? entry.waveTotal / entry.sessionCount : 0
    }));

  const topUpgrades = Array.from(upgrades.values())
    .sort((a, b) => b.appearances - a.appearances || b.levelTotal - a.levelTotal)
    .slice(0, 5)
    .map((entry) => ({
      upgradeId: entry.upgradeId,
      appearances: entry.appearances,
      avgLevel: entry.appearances > 0 ? entry.levelTotal / entry.appearances : 0
    }));

  return {
    sessionCount: daySessions.length,
    avgWave: totalWave / daySessions.length,
    maxWave,
    avgDuration: totalDuration / daySessions.length,
    avgDna: totalDna / daySessions.length,
    avgKills: totalKills / daySessions.length,
    reviveRuns,
    dnaBoostRuns,
    avgMutations: totalMutations / daySessions.length,
    avgInfections: totalInfections / daySessions.length,
    topLoadouts,
    topUpgrades
  };
}
