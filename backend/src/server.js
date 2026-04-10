import crypto from "node:crypto";
import dotenv from "dotenv";
import express from "express";
import cors from "cors";
import session from "express-session";
import passport from "passport";
import { Strategy as GoogleStrategy } from "passport-google-oauth20";
import { createEmailProvider } from "./email_provider.js";
import {
  cleanupExpiredEntries,
  createGoogleDeviceSession,
  deleteBackdoorRequest,
  getBackdoorRequest,
  getGoogleDeviceSession,
  getGoogleDeviceSessionByUserCode,
  getStoreDiagnostics,
  getStoreMode,
  incrementBackdoorVerifyAttempts,
  initStore,
  probeStoreConnectivity,
  updateGoogleDeviceSession,
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

const emailProvider = createEmailProvider({ supportEmail });
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

if (nodeEnv === "production" && !process.env.SESSION_SECRET) {
  throw new Error("SESSION_SECRET is required in production.");
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
app.use(session({
  secret: process.env.SESSION_SECRET || "cell-defense-dev-session-secret",
  resave: false,
  saveUninitialized: false,
  cookie: {
    sameSite: "lax",
    secure: nodeEnv === "production"
  }
}));
app.use(passport.initialize());
app.use(passport.session());

passport.serializeUser((user, done) => done(null, user));
passport.deserializeUser((user, done) => done(null, user));

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
  return String(Math.floor(100000 + Math.random() * 900000));
}

function sanitizeLocation(rawLocation) {
  return String(rawLocation || "").trim().slice(0, 96);
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
    value += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return value;
}

app.get("/api/health", (_req, res) => {
  res.json({
    ok: true,
    mode: googleConfigured ? "google+email" : "email-only",
    publicBaseUrl,
    storageMode: getStoreMode(),
    emailMode: emailProvider.getMode(),
    storeReady: storeState.ready,
    storeInitializing: storeState.initializing,
    storeError: storeState.lastError,
    storeLastCheckedAt: storeState.lastCheckedAt,
    storeDiagnostics: storeState.diagnostics,
    storeProbe: storeState.probe
  });
});

app.post("/api/auth/backdoor/register", handleAsync(async (req, res) => {
  const displayName = String(req.body?.displayName || "").trim();
  const email = String(req.body?.email || "").trim().toLowerCase();
  const location = sanitizeLocation(req.body?.location);
  if (!displayName) {
    return jsonError(res, 400, "account.error_name_required");
  }
  if (!email.includes("@") || !email.includes(".")) {
    return jsonError(res, 400, "account.error_invalid_email");
  }
  if (!location) {
    return jsonError(res, 400, "account.error_location_required");
  }

  await cleanupExpiredEntries();
  const existingRequest = await getBackdoorRequest(email);
  if (existingRequest && (Date.now() - Date.parse(existingRequest.requestedAt || 0)) < backdoorMinRequestIntervalMs) {
    return jsonError(res, 429, "account.error_request_throttled");
  }

  const code = generateSixDigitCode();
  const requestedAt = new Date().toISOString();
  const expiresAt = Date.now() + backdoorCodeTtlMs;

  await upsertBackdoorRequest({
    displayName,
    email,
    location,
    code,
    requestedAt,
    expiresAt,
    verifyAttempts: 0
  });

  try {
    await emailProvider.sendRegistrationEmails({ displayName, email, location, code, requestedAt });
  } catch (error) {
    if (!devExposeCodes) {
      return jsonError(res, 500, "account.error_backend_unreachable", {
        detail: String(error.message || error)
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
  if (!code) {
    return jsonError(res, 400, "account.error_code_required");
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
  if (pending.code !== code) {
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
        <p>Device code: <strong>${userCode}</strong></p>
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
  console.log(`Email provider mode: ${emailProvider.getMode()}`);
  console.log(`Storage mode: ${getStoreMode()}`);
  warmStore();
});
