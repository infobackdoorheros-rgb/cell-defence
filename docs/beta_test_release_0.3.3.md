# Beta Test Release 0.3.3

## Scope

Questa beta test consolida il gioco in uno stato pronto per distribuzione controllata a tester Android.

Include:

- account center con gestione privacy e cancellazione account
- save migration e backend auth piu robusti
- laboratorio reso scrollabile e usabile su mobile
- autosave partita su pause, focus loss e chiusura app
- fix del wave manager sui pesi virus/batteri
- shop, social hub e live ops messi in stato beta-safe senza claim fittizi
- Play Games disattivato localmente finche i parametri reali non vengono inseriti

## Beta notes

Per questa release:

- login backend email e google restano testabili contro Render
- Play Games non va riattivato finche Game ID, Web Client ID, Web Client Secret e SHA-1 non sono allineati
- rewarded ads, IAP e social link pubblici restano in preview

## Android packaging

Script di build aggiornato a:

- Version name: `0.3.3`
- Version code: `15`

Build script:

```powershell
.\tools\build_android_release.ps1 -KeystoreFile "PERCORSO_KEYSTORE" -KeystorePassword "PASSWORD" -KeyAlias "ALIAS"
```

## Publishing note

Questa release e pensata per beta test chiuso e validazione UX/gameplay prima della prossima build con monetizzazione reale e Play Games live.
