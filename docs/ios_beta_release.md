# iOS Beta Release

## Stato attuale

Il progetto e stato preparato per una prima release iOS beta in formato **Xcode-ready source package**.

Cosa include:

- preset `iOS Beta` in `export_presets.cfg`
- orientamento portrait gia coerente con il gioco mobile
- profilo grafico `Auto` reso sicuro anche su iOS
- intro con logo BackDoor Heroes, FTUE, menu principale, laboratorio, run, pause menu e account center
- URL backend auth gia puntato a `https://cell-defense-auth-backend.onrender.com`

## Cosa possiamo fare da Windows

Da questo ambiente Windows possiamo:

- preparare il progetto
- generare il pacchetto sorgente pulito per iOS
- mantenere preset, versioning e backend config allineati

La build finale firmata `.ipa` per TestFlight **non puo essere chiusa qui**: va esportata da un Mac con Xcode installato.

## Pacchetto pronto

Genera il pacchetto con:

```powershell
.\tools\prepare_ios_beta_release.ps1
```

Output previsto:

- `dist/ios/cell-defense-core-immunity-ios-beta-0.3.2-source`
- `dist/ios/cell-defense-core-immunity-ios-beta-0.3.2-source.zip`

## Procedura su Mac

1. Installa Godot 4.5.1 e i relativi export templates.
2. Apri il progetto o lo zip preparato.
3. Vai in `Project > Export` e seleziona `iOS Beta`.
4. Inserisci:
   - `App Store Team ID`
   - eventuale provisioning profile se usi firma manuale
5. Lascia `Export Project Only = true`.
6. Esporta verso una cartella vuota.
7. Apri il progetto generato in Xcode.
8. In `Signing & Capabilities` seleziona team e profilo.
9. Esegui `Product > Archive`.
10. Carica l'archivio in TestFlight tramite Organizer.

## Valori iOS gia impostati

- Bundle identifier: `com.backdoorheroes.celldefensecoreimmunity`
- Short version: `0.3.2`
- Build version: `14`
- Minimum iOS version: `12.0`
- Export mode: `project only`
- Architecture: `arm64`

## Note operative

- `App Store Team ID` e obbligatorio: se e vuoto Godot blocca l'export.
- Il backend auth remoto e gia configurato, quindi account center e login browser-based possono essere testati anche su iPhone.
- La monetizzazione e volutamente lasciata in stato prototipale: questa release serve per beta test gameplay e UX, non per validare IAP o rewarded ads.

## Fonti ufficiali

- Godot iOS export: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html
- Godot iOS export options: https://docs.godotengine.org/en/stable/classes/class_editorexportplatformios.html
- Godot system requirements: https://docs.godotengine.org/en/stable/about/system_requirements.html
