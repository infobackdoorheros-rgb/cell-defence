# Play Games Login Setup

Questa integrazione aggiunge il login Android con Google Play Giochi al progetto Godot e al backend Render.

## Cosa e stato integrato

- Plugin Godot `GodotPlayGameServices` incluso in [`addons/GodotPlayGameServices`](c:\Users\matte\Desktop\CELL DEFENCE\addons\GodotPlayGameServices).
- Manager runtime Godot in [`scripts/autoload/play_games_auth_manager.gd`](c:\Users\matte\Desktop\CELL DEFENCE\scripts\autoload\play_games_auth_manager.gd).
- Account Center aggiornato con blocco Play Giochi in [`scripts/ui/account_scene.gd`](c:\Users\matte\Desktop\CELL DEFENCE\scripts\ui\account_scene.gd).
- Endpoint backend Render `/api/auth/playgames/android` che scambia il server auth code e verifica il giocatore.
- Persistenza dedicata dei profili Play Giochi in `play_games_profiles`.
- Build Android aggiornata per includere addon, dipendenze Google Play Games v2 e `APP_ID`.

## Configurazione richiesta in Play Console / Google Cloud

1. Crea o apri il progetto Google Play Games Services del gioco.
2. Usa il package Android:
   `com.backdoorheroes.celldefensecoreimmunity`
3. Configura gli OAuth client Android con package name + SHA-1 per:
   - chiave debug, se vuoi test locale
   - chiave release usata per firmare l'APK/AAB
   - Play App Signing certificate SHA-1, se distribuirai via Play Store
4. Crea anche il Web OAuth client che il backend usera per scambiare il `serverAuthCode`.
5. Inserisci il Game ID in [`data/config/auth_backend.json`](c:\Users\matte\Desktop\CELL DEFENCE\data\config\auth_backend.json) nella chiave `play_games_android_game_id`.
6. Inserisci il Web Client ID nella stessa config, nella chiave `play_games_server_client_id`.

## Configurazione richiesta su Render

Nel web service `cell-defense-auth-backend` aggiungi:

- `PLAY_GAMES_SERVER_CLIENT_ID`
- `PLAY_GAMES_SERVER_CLIENT_SECRET`

Il valore del client id deve essere quello del Web OAuth client, non quello Android.

## Verifica rapida

Quando la configurazione e completa:

- `GET /api/health` deve mostrare `playGamesConfigured: true`
- l'Account Center deve abilitare il bottone "Accedi con Play Giochi" su Android
- la build Android deve avere `game_services_project_id` valorizzato con il Game ID reale

## Note pratiche

- Il login Play Giochi e solo Android.
- Se il Game ID resta vuoto, la build usa il fallback `0` e il login non andra live.
- Se manca il Web Client ID o il relativo secret su Render, il backend rispondera con errore di configurazione.

## Fonti

- Android Developers, Migrate to Play Games Services v2: https://developer.android.com/games/pgs/android/migrate-to-v2
- Android Developers, Server-side access: https://developer.android.com/games/pgs/android/server-access
- Android Developers, Play Games continuity requirements: https://developer.android.com/games/playgames/continuity-requirements
- Android Developers, Play Games FAQ: https://developer.android.com/games/playgames/faq
- Godot Play Games plugin: https://github.com/godot-sdk-integrations/godot-play-game-services
