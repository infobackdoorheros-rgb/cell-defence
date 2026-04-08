# Auth Backend Setup

Questa implementazione aggiunge un backend Node.js per:

- registrazione `BackDoor Heroes` con invio email automatico del codice al giocatore
- notifica della richiesta a `info.backdoorheros@gmail.com` con `nome`, `email` e `localita`
- `Google login` via device flow con polling dal client Godot
- persistenza account su `Postgres` quando `DATABASE_URL` e disponibile, con fallback file locale per sviluppo

## 1. Installazione

Da [package.json](C:/Users/matte/Desktop/CELL%20DEFENCE/backend/package.json):

```bash
cd backend
npm install
```

## 2. Configurazione

Copia `backend/.env.example` in `.env` e compila:

- `PUBLIC_BASE_URL`
- `DATABASE_URL` opzionale ma raccomandato per Render
- `DATABASE_SSL` se il tuo provider DB richiede SSL
- `SESSION_SECRET`
- `TRUST_PROXY`
- `ALLOWED_ORIGINS`
- `EMAIL_PROVIDER`
- `RESEND_*` oppure `SMTP_*`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_CALLBACK_URL`
- `BACKDOOR_MAX_VERIFY_ATTEMPTS`
- `BACKDOOR_MIN_REQUEST_INTERVAL_MS`

Per test locale rapido puoi usare:

- `DEV_EXPOSE_CODES=true`

Questo permette al backend di restituire il codice anche in risposta JSON se il provider mail non e ancora pronto. Non usarlo in produzione.

Per Render la configurazione consigliata e:

- `DATABASE_URL` tramite Render Postgres
- `EMAIL_PROVIDER=resend`
- `RESEND_API_KEY`
- `RESEND_FROM`

## 3. Avvio backend

```bash
cd backend
npm run start
```

Health check:

```bash
GET http://127.0.0.1:8787/api/health
```

La risposta ora indica anche:

- `storageMode`: `file` oppure `postgres`
- `emailMode`: `none`, `smtp` oppure `resend`

## 4. Collegare il gioco

Aggiorna [auth_backend.json](C:/Users/matte/Desktop/CELL%20DEFENCE/data/config/auth_backend.json):

```json
{
  "mode": "remote",
  "base_url": "http://127.0.0.1:8787",
  "public_base_url": "http://127.0.0.1:8787",
  "request_timeout_seconds": 15.0,
  "google_device_flow_enabled": true,
  "allow_local_fallback": false
}
```

Su Android reale usa l'URL pubblico del backend, non `127.0.0.1`.

## 5. Note Google

Il client Godot usa un `device flow` applicativo:

1. Il gioco chiede una device session al backend.
2. Il backend restituisce `user code` e `verification URL`.
3. Il browser completa il login Google sul backend web.
4. Il gioco fa polling e chiude l'autenticazione.

Questo evita deep link fragili lato app mobile.

Se `GOOGLE_CALLBACK_URL` e vuoto, il backend usa automaticamente:

`PUBLIC_BASE_URL/auth/google/web/callback`

## 6. Produzione

Da completare prima del go-live:

- deploy backend HTTPS
- callback Google sul dominio pubblico
- provider email HTTP o SMTP funzionante
- rotazione segreti
- allowlist CORS, rate limit e audit log
- verifica del backend in modalita `Postgres`
