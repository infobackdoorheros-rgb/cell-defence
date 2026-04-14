# Google Play Data Safety Notes

Ultimo aggiornamento: 14 aprile 2026

Questo documento serve come guida operativa per compilare la sezione **Data safety** di Google Play per la build attuale del progetto.

## Stato attuale del gioco

Alla data di questo documento:

- e presente autenticazione account con email / BackDoor Heroes
- e presente autenticazione Google / Play Games lato progetto
- i salvataggi di gameplay restano principalmente locali
- non sono ancora attive integrazioni pubblicitarie rewarded reali
- non sono ancora attivi acquisti in-app reali collegati a Google Play Billing

Se in futuro verranno attivati ads, billing, analytics remoti o altri SDK, la Data Safety dovra essere aggiornata prima della pubblicazione.

## Dati da dichiarare come raccolti

Per la build attuale, i dati piu rilevanti da valutare come **raccolti** sono:

- **Personal info**
  - nome o display name
  - indirizzo email
- **Location**
  - localita inserita volontariamente dall'utente nel form BackDoor Heroes
- **App activity / In-app info**
  - progresso profilo e dati di gioco collegati all'account
- **Identifiers**
  - user ID interni
  - identificativi Google / Play Games quando il login viene usato

## Finalita tipiche da selezionare

In base allo stato attuale del progetto:

- App functionality
- Account management
- Security / fraud prevention / abuse prevention
- Developer communications, solo per email transazionali di verifica o conferma

## Dati non ancora da dichiarare come raccolti in questa fase

Salvo future integrazioni, al momento non risultano raccolti:

- dati finanziari o di pagamento reali
- contatti
- foto o video
- audio registrato
- messaggi SMS
- posizione precisa del dispositivo
- cronologia web

## Condivisione dati

Valutare come condivisi solo i dati strettamente necessari ai fornitori tecnici coinvolti, ad esempio:

- backend hosting
- database
- provider email transazionale
- provider login Google / Play Games

Non dichiarare condivisioni extra non realmente presenti.

## Crittografia in transito

Se il backend e configurato in HTTPS, la risposta corretta e:

- **I dati sono criptati in transito: SI**

## Richiesta di eliminazione dati

Con il flusso di eliminazione account attivo, la risposta corretta e:

- **Gli utenti possono richiedere l'eliminazione dei dati: SI**

Supporto da indicare:

- eliminazione in-app da Account Center
- email `info.backdoorheros@gmail.com`

## Nota pratica

Prima di inviare la scheda definitiva su Play Console, confronta sempre questo documento con:

- la build realmente caricata
- gli SDK realmente inclusi
- la Privacy Policy pubblica
