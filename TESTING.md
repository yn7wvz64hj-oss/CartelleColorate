# Verifiche

## Controlli automatici

La build con `-Test` verifica:

- Riproduzione del blocco 0x80131515 su DLL con ZoneId=3, segnalazione/log dell'errore e ricompilazione locale delle librerie.

- Cambio tra Windows e macOS, salvataggio dello stile e conservazione della lingua e della selezione.
- Completezza dei 15 cataloghi e coerenza dei segnaposti.
- Lingua di Windows, preferenze mancanti o danneggiate e salvataggio atomico.
- Annullamento e conferma della schermata iniziale, con nome dei colori conservato.
- Cambio lingua senza riaprire la finestra; disposizione RTL e HEX/riquadro LTR.
- Test dell’interfaccia e anteprime in tutte le 15 lingue.

- Rinomina Unicode e solo maiuscole; rifiuto di nomi riservati, destinazioni esistenti e backup in conflitto.
- Conservazione dei file e ripristino delle icone della cartella rinominata e delle sottocartelle.
- Matita per rinominare e Applica per nome e colore nelle 15 interfacce.
- Generazione ICO e cambio/ripristino con e senza `desktop.ini` precedente.
- Conservazione dei metadati originari e degli attributi della cartella.
- PNG in sette dimensioni, trasparenza e proporzioni.
- Palette di 150 colori e rinomina persistente.
- Scorrimento della raccolta con la nuova barra sottile e raccolta affiancata nelle 15 lingue.
- Riquadro cliccabile, valori intermedi, estremi e trascinamento fuori bordo.
- Cambio multiplo, annullamento completo e rollback simulato dopo una prima cartella già modificata.
- Recenti senza duplicati, ritaglio, proporzioni e rendering dei tre contrassegni.
- Ricerca, filtri delle raccolte e finestre reali di testo, selezione cartelle ed editor PNG in tutte le lingue.
- Importazione ed esportazione JSON, deduplicazione e rifiuto completo di file invalidi.
- Preferiti in cima, riordino e annullamento di nome e icona immediatamente precedenti.
- Nuovo senza creazione anticipata di una nuvola; raccolta vuota nascosta e ripristino della lista.
- Salvataggio/modifica/eliminazione dei colori e validazione HEX.
- Anteprima PNG e ritorno alla modalità colore.
- Conversione dei valori della pipetta, zoom aggiornabile e attivazione/disattivazione del gestore del mouse.
- Gestori che nascondono la freccia dentro il riquadro e la ripristinano all'uscita.

Sono verifiche funzionali nell'ambiente di sviluppo, non una certificazione Windows o un'analisi antivirus.

## Da verificare prima di dichiarare una versione stabile

Su almeno un altro PC Windows 11, con una cartella di prova contenente copie di file:

- Installazione dello ZIP scaricato, esecuzione dal menu, aggiornamento e rimozione.
- Schermata lingua al primo avvio, scelta ricordata e menu contestuale tradotto.
- Revisione delle traduzioni da parte di parlanti madrelingua e font su un altro PC.
- Pipetta: clic reale, Esc, monitor multipli e fattori di scala diversi.
- Fluidità reale del riquadro e dello zoom.
- Icona aggiornata nella vista corrente di Esplora file e sul desktop.
- Processo rapido caldo/freddo e chiusura dopo inattività.
- Nomi di cartelle con spazi, apostrofi e caratteri non ASCII.
- Cartelle non scrivibili: errore comprensibile senza perdita della configurazione originale.
- Ripristino di una cartella già personalizzata da un altro programma.
- Conservazione dei dati quando si rimuove soltanto il menu.

## Evidenza locale

La mancata apertura della 0.2.0-beta.1 è stata riprodotta sui file installati: le DLL ereditavano ZoneId=3 dal download dello ZIP. La 0.2.0-beta.2 genera DLL locali durante l'installazione; il test con la stessa marcatura Internet ora passa. Il launcher VBS è stato verificato con successo anche in GitHub Actions.

Il 6 ottobre 2026 la compilazione dai sorgenti, i test sulle icone e i test dell'interfaccia sono passati. Il controllo di Windows Script Host ha restituito “Accesso negato” nell'ambiente di esecuzione: l'avvio VBS e l'installazione completa non sono stati verificati in questa sessione. L'installer mantiene un controllo esplicito per segnalare tale requisito sul PC destinatario. La build non aggira le restrizioni del sistema e non considera quel controllo superato.

Il workflow GitHub Actions è incluso. Lo stato delle esecuzioni sul repository pubblico è consultabile nella scheda Actions; i risultati locali sopra indicati non certificano il successo del workflow su GitHub.

Durante lo sviluppo, tre comandi riutilizzando il processo hanno scritto la configurazione e notificato la shell in circa 189–219 ms. Questo non misura il ridisegno visivo di Esplora file e non è una promessa di prestazioni su altri computer.

Verificati localmente attivazione del materiale DWM con superfici semitrasparenti e avvio con sfondo opaco, in tema chiaro e scuro. L’aspetto della sfocatura sul desktop e i cambi delle impostazioni di trasparenza vanno controllati anche su altri PC.

## Verifiche della versione 0.8

- Cronologia: due modifiche consecutive, rifiuto dell’annullamento fuori ordine, ripristino in ordine e inventario coerente.
- Preset: testo Unicode, copia del PNG e caricamento dopo lo spostamento dell’originale; array JSON vuoti validi.
- Sette simboli con verifica dei pixel nel colore scelto.
- Confronto delle versioni beta/stabili, aggiornamento asincrono e errore offline senza bloccare la finestra.
- Finestre reali dei preset, simboli, dimensioni, cronologia, inventario e impostazioni, per tutte le lingue.
- Selezione di cartelle da percorsi diversi e rifiuto di trascinamenti misti con file.
- Opacità e rilievo persistenti; anteprima PNG conservata durante i cambi di stile.
- GitHub Actions legge la fonte VERSION attraverso lo stesso client HTTP usato dall’app.
