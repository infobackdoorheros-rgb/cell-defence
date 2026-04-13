# Play Games Go-Live Checklist

Usa questa checklist prima di generare la prossima build Android con login Play Giochi attivo.

## Fase B - Configurazione

1. In Google Play Console crea o aggiorna il progetto Play Giochi del gioco.
2. Verifica package name Android:
   - `com.backdoorheroes.celldefensecoreimmunity`
3. Crea o controlla i client OAuth:
   - Android debug
   - Android release
   - Android Play App Signing
   - Web client per backend
4. Copia questi valori:
   - `Game ID`
   - `Web Client ID`
   - `Web Client Secret`

## Fase C - Allineamento progetto e backend

1. Aggiorna [`auth_backend.json`](C:/Users/matte/Desktop/CELL%20DEFENCE/data/config/auth_backend.json):
   - `play_games_enabled: true`
   - `play_games_server_client_id: WEB_CLIENT_ID`
   - `play_games_android_game_id: GAME_ID`
2. Aggiorna Render env vars:
   - `PLAY_GAMES_SERVER_CLIENT_ID`
   - `PLAY_GAMES_SERVER_CLIENT_SECRET`
3. Attendi il redeploy di Render.
4. Controlla:
   - `https://cell-defense-auth-backend.onrender.com/api/health`
   - `storeReady: true`
   - `playGamesConfigured: true`
5. Esegui il check locale:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\check_play_games_setup.ps1
```

## Test su device

1. Installa una build firmata con la stessa chiave registrata in Play Console.
2. Apri `Account Center`.
3. Controlla che il bottone `Accedi con Play Giochi` sia attivo.
4. Esegui il login.
5. Verifica che il provider autenticato diventi `Play Giochi`.

## Quando non partire con i test

Non ha senso testare il login Play Giochi se uno di questi punti e ancora falso:

- `play_games_server_client_id` vuoto
- `play_games_android_game_id` vuoto
- `playGamesConfigured` falso su Render
- SHA-1 della build non registrato in Google Play Console
