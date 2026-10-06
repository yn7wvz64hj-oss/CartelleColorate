# Verifiche

## Controlli automatici

La build con `-Test` verifica:

- Generazione ICO e cambio/ripristino con e senza `desktop.ini` precedente.
- Conservazione dei metadati originari e degli attributi della cartella.
- PNG in sette dimensioni, trasparenza e proporzioni.
- Palette di 150 colori e rinomina persistente.
- Riquadro cliccabile, valori intermedi, estremi e trascinamento fuori bordo.
- Salvataggio/modifica/eliminazione dei colori e validazione HEX.
- Anteprima PNG e ritorno alla modalità colore.
- Conversione dei valori della pipetta, zoom aggiornabile e attivazione/disattivazione del gestore del mouse.
- Gestori che nascondono la freccia dentro il riquadro e la ripristinano all'uscita.

Sono verifiche funzionali nell'ambiente di sviluppo, non una certificazione Windows o un'analisi antivirus.

## Da verificare prima di dichiarare una versione stabile

Su almeno un altro PC Windows 11, con una cartella di prova contenente copie di file:

- Installazione dello ZIP scaricato, esecuzione dal menu, aggiornamento e rimozione.
- Pipetta: clic reale, Esc, monitor multipli e fattori di scala diversi.
- Fluidità reale del riquadro e dello zoom.
- Icona aggiornata nella vista corrente di Esplora file e sul desktop.
- Processo rapido caldo/freddo e chiusura dopo inattività.
- Nomi di cartelle con spazi, apostrofi e caratteri non ASCII.
- Cartelle non scrivibili: errore comprensibile senza perdita della configurazione originale.
- Ripristino di una cartella già personalizzata da un altro programma.
- Conservazione dei dati quando si rimuove soltanto il menu.

## Evidenza locale

Il 6 ottobre 2026 la compilazione dai sorgenti, i test sulle icone e i test dell'interfaccia sono passati. Il controllo di Windows Script Host ha restituito “Accesso negato” nell'ambiente di esecuzione: l'avvio VBS e l'installazione completa non sono stati verificati in questa sessione. L'installer mantiene un controllo esplicito per segnalare tale requisito sul PC destinatario. La build non aggira le restrizioni del sistema e non considera quel controllo superato.

Il workflow GitHub Actions è incluso. Lo stato delle esecuzioni sul repository pubblico è consultabile nella scheda Actions; i risultati locali sopra indicati non certificano il successo del workflow su GitHub.

Durante lo sviluppo, tre comandi riutilizzando il processo hanno scritto la configurazione e notificato la shell in circa 189–219 ms. Questo non misura il ridisegno visivo di Esplora file e non è una promessa di prestazioni su altri computer.
