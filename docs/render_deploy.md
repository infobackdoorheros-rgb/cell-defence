# Render Deploy

Questo progetto e gia predisposto per Render tramite [render.yaml](C:/Users/matte/Desktop/CELL%20DEFENCE/render.yaml).

## Cosa crea

- un `Web Service` Node chiamato `cell-defense-auth-backend`
- un database `Render Postgres` chiamato `cell-defense-auth-db`
- root directory `backend`
- health check su `/api/health`
- deploy automatico da commit

## Limite reale

La creazione del servizio su Render non posso farla io direttamente da questa sessione, perche richiede:

- accesso al tuo account Render
- autorizzazione GitHub/GitLab del repository
- eventuali conferme billing/workspace

## Procedura minima

1. Crea un account Render o accedi alla dashboard.
2. Collega il repository del gioco.
3. Scegli `New > Blueprint`.
4. Seleziona questo repository.
5. Render rilevera [render.yaml](C:/Users/matte/Desktop/CELL%20DEFENCE/render.yaml).
6. Inserisci i valori richiesti per le variabili `sync: false`.
7. Completa il deploy.

## Se hai gia creato un normale Web Service

Il log con errore su `/opt/render/project/src/package.json` indica che Render sta buildando dalla root del repository come servizio standard, senza usare il blueprint.

Hai 2 strade:

1. Consigliata: elimina quel servizio e ricrealo con `New > Blueprint`, cosi Render usera [render.yaml](C:/Users/matte/Desktop/CELL%20DEFENCE/render.yaml) e il `rootDir: backend`.
2. Rapida: tieni il servizio attuale ma imposta manualmente:
   - `Root Directory`: `backend`
   - `Build Command`: `npm install`
   - `Start Command`: `npm start`
   - `Health Check Path`: `/api/health`

In piu il repository ora ha anche un [package.json](C:/Users/matte/Desktop/CELL%20DEFENCE/package.json) in root che inoltra `npm start` al backend, quindi dopo il push il deploy dalla root e piu tollerante anche se lasci un servizio standard.

## Variabili richieste

- `ALLOWED_ORIGINS`
- `RESEND_API_KEY`
- `RESEND_FROM`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_CALLBACK_URL`
- `PLAY_GAMES_SERVER_CLIENT_ID`
- `PLAY_GAMES_SERVER_CLIENT_SECRET`

Per una prima attivazione puoi lasciare Google web vuoto e usare solo `BackDoor Heroes` email auth.

Per attivare `Play Giochi` Android:

- `PLAY_GAMES_SERVER_CLIENT_ID` deve essere il `Web OAuth Client ID`
- `PLAY_GAMES_SERVER_CLIENT_SECRET` deve essere il secret dello stesso client
- in [auth_backend.json](C:/Users/matte/Desktop/CELL%20DEFENCE/data/config/auth_backend.json) vanno poi inseriti anche:
  - `play_games_enabled: true`
  - `play_games_server_client_id`
  - `play_games_android_game_id`

Il backend usa automaticamente:

- `DATABASE_URL` dal database Render creato via blueprint
- `DATABASE_SSL=true` per il Postgres gestito da Render
- `RENDER_EXTERNAL_URL` come URL pubblico se `PUBLIC_BASE_URL` non e impostato
- `TRUST_PROXY=true` per cookie e callback dietro proxy Render

Il supporto `SMTP_*` rimane disponibile, ma su un deploy Render iniziale e piu semplice usare un provider email HTTP come `Resend`.

## Dopo il deploy

Render assegnera un URL pubblico tipo:

- `https://cell-defense-auth-backend.onrender.com`

Poi aggiorna [auth_backend.json](C:/Users/matte/Desktop/CELL%20DEFENCE/data/config/auth_backend.json) cosi:

```json
{
  "mode": "remote",
  "base_url": "https://cell-defense-auth-backend.onrender.com",
  "public_base_url": "https://cell-defense-auth-backend.onrender.com",
  "request_timeout_seconds": 15.0,
  "google_device_flow_enabled": true,
  "play_games_enabled": true,
  "play_games_server_client_id": "WEB_CLIENT_ID.apps.googleusercontent.com",
  "play_games_android_game_id": "123456789012",
  "allow_local_fallback": false
}
```

Ricostruisci poi l'APK.

## Diagnostica rapida

Se il deploy compila ma Render segnala `No open ports detected`, il fix gia incluso nel repo piu recente fa partire il server HTTP subito e inizializza il database in background con retry.

Per controllare lo stato reale del backend apri:

- `https://TUO-SERVIZIO.onrender.com/api/health`

Controlla questi campi:

- `ok: true`
- `storeReady: true`
- `storageMode: "postgres"`
- `emailMode: "smtp"` oppure `emailMode: "resend"`

Se `storeReady` e `false`, il servizio e online ma il database o le env vars non sono ancora corretti: in quel caso il campo `storeError` dell'health endpoint ti dira il motivo.

## Note ufficiali

- Render assegna a ogni web service un sottodominio `onrender.com`: https://render.com/docs/web-services
- I servizi free hanno filesystem effimero; per persistenza usa DB o disk supportati: https://render.com/docs/free
- `render.yaml` supporta servizi, database ed env vars: https://render.com/docs/blueprint-spec
- `RENDER_EXTERNAL_URL` e una variabile ambiente di piattaforma: https://render.com/docs/environment-variables
