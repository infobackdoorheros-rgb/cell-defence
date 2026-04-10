import fs from "node:fs";
import path from "node:path";
import { Pool } from "pg";

const DATA_DIR = path.resolve(process.cwd(), "data");
const STORE_PATH = path.join(DATA_DIR, "auth-store.json");
const DATABASE_URL = String(process.env.DATABASE_URL || "").trim();
const STORE_MODE = DATABASE_URL ? "postgres" : "file";

const DEFAULT_STORE = {
  backdoorRequests: {},
  userProfiles: {},
  googleDeviceSessions: {}
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
      connectionTimeoutMillis: Number(process.env.DATABASE_CONNECTION_TIMEOUT_MS || 10000),
      idleTimeoutMillis: Number(process.env.DATABASE_IDLE_TIMEOUT_MS || 30000),
      max: Number(process.env.DATABASE_POOL_MAX || 4),
      ssl: String(process.env.DATABASE_SSL || "").toLowerCase() === "true"
        ? { rejectUnauthorized: false }
        : undefined
    });
  }
  return pool;
}

export function getStoreMode() {
  return STORE_MODE;
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
      CREATE TABLE IF NOT EXISTS google_device_sessions (
        device_code TEXT PRIMARY KEY,
        user_code TEXT UNIQUE NOT NULL,
        status TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        profile_json JSONB
      );
    `);
    await activePool.query("CREATE INDEX IF NOT EXISTS idx_backdoor_requests_expires_at ON backdoor_requests (expires_at);");
    await activePool.query("CREATE INDEX IF NOT EXISTS idx_google_device_sessions_expires_at ON google_device_sessions (expires_at);");
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
