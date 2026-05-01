# Cell Defence Control Center

Console locale Windows per:

- monitorare `backend health`, `Play Giochi`, `mail readiness` e `storage`
- leggere `daily/weekly leaderboard` e snapshot telemetria
- modificare `remote_config.json`
- modificare `season_event_live.json`
- modificare `notification_campaigns.json`

## Avvio rapido

Dal root del progetto:

```powershell
npm run dev:control-center
```

Oppure con launcher Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\start_control_center.ps1 -OpenBrowser
```

Il pannello sarà disponibile su:

`http://127.0.0.1:4311`

## Primo setup

1. Apri il pannello.
2. Inserisci `Backend URL`.
3. Inserisci `Admin API Token`.
4. Salva.
5. Premi `Aggiorna tutto`.

## Backend richiesto

Il backend Render deve avere la env var:

- `ADMIN_API_TOKEN`

e deve includere gli endpoint:

- `GET /api/admin/overview`
- `GET /api/admin/telemetry/digest`
- `POST /api/admin/telemetry/digest/send`

## Note operative

- I file configurazione modificati dal pannello sono quelli del progetto locale.
- Le modifiche a `remote_config.json`, `season_event_live.json` e `notification_campaigns.json` servono per sviluppo, tuning e preparazione build.
- Per vedere classifiche e telemetria reali, il backend Render deve essere raggiungibile e l'admin token deve essere corretto.
