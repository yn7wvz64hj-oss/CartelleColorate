# Note di versione

## 0.9.0-beta.1 — 6 ottobre 2026

- Backup portatile della libreria con PNG incorporati, fusione dei dati, gestione delle collisioni e rollback degli errori.
- Preset preferiti in una tendina del menu di Windows, con icone e applicazione rapida tramite worker nascosto.
- Ripetizione delle modifiche annullate, compresa la rinomina, con protezione dalle modifiche successive.
- Preferiti conservati durante l’aggiornamento dei preset.
- Nuovi comandi nelle 15 lingue e test completo del menu Windows nel runner isolato.

## 0.8.0-beta.1 — 6 ottobre 2026

- Preset completi con copie indipendenti dei PNG e contrassegni colorati.
- Trascinamento di cartelle anche da percorsi diversi.
- Cronologia con annullamento selettivo e controllo delle modifiche successive.
- Inventario delle cartelle personalizzate e ripristino annullabile.
- Sette simboli, anteprima dimensioni, regolazioni del vetro e tema automatico.
- Controllo aggiornamenti asincrono e facoltativo all’apertura.
- Interfacce e messaggi aggiornati nelle 15 lingue.
- Installer aggiornato per includere Productivity.ps1 e VERSION.

## 0.7.0-beta.1 — 6 ottobre 2026

- Selezione di più cartelle dalla finestra, applicazione di colore/PNG al gruppo, annullamento completo e rollback degli errori.
- Ricerca per nome e HEX, raccolte personali creabili/rinominabili/eliminabili e import/export dei gruppi dei colori.
- Otto colori recenti persistenti, anche per i comandi del menu di Esplora file.
- Editor PNG con anteprima, zoom, posizione e ritaglio quadrato, senza modificare il file originale.
- Contrassegni stella, spunta e lucchetto su colori e PNG.
- Bordi delle nuvole nel colore corrispondente, animazioni brevi e conferme flottanti.
- Nuovi comandi nelle 15 lingue.

## 0.6.0-beta.1 — 6 ottobre 2026

- Nuvole affiancate con menu contestuale per modificare, rinominare, eliminare e segnare i preferiti.
- Preferiti in cima e riordino tramite trascinamento o comandi nel menu.
- Anteprima dell’icona più grande.
- Annullamento persistente dell’ultima modifica di nome e icona dal selettore.
- Importazione ed esportazione della raccolta JSON, con validazione completa prima dell’importazione e protezione dai duplicati.

## 0.5.1-beta.1 — 6 ottobre 2026

- Colori salvati in piccole superfici separate, senza contenitore comune.
- Nuovo accanto al titolo, con comandi più compatti.
- Nessuna superficie vuota: le nuvole compaiono solo per i colori salvati.
- Raccolta scorrevole e virtualizzata, con nomi lunghi consultabili dal tooltip.

## 0.5.0-beta.1 — 6 ottobre 2026

- Stile macOS ispirato a pannelli in vetro rialzati, con ombre morbide e bordi luminosi.
- Pulsante in alto per scegliere Windows classico o macOS, con preferenza salvata.
- Cambio stile immediato, senza perdere nome, colore, palette, lingua o PNG selezionato.
- Stile Windows opaco, senza ombre, con colori e bordi classici.
- Ombre applicate a superfici statiche separate dal selettore per conservare la fluidità.

## 0.4.0-beta.1 — 6 ottobre 2026

- Interfaccia ridotta da 500 × 690 a 456 × 600, con campi e comandi più compatti.
- Pannelli traslucidi, riflessi delicati, bordi arrotondati e pulsante principale sfumato.
- Sfocatura del desktop gestita dal compositore Windows, senza catture dello schermo o blur WPF nel selettore.
- Sfondo opaco automatico se le trasparenze sono disabilitate o il sistema non supporta il materiale.
- Barre di scorrimento sottili, rimozione del colore accanto a Nuovo e schermata lingua coordinata.

## 0.3.0-beta.1 — 6 ottobre 2026

- Rinomina della cartella dal selettore, con matita per cambiare solo il nome.
- Applica conferma insieme nome e colore o immagine PNG.
- Backup aggiornati anche per le sottocartelle, con ripristino conservato.
- Validazione dei nomi Windows, protezione da collisioni e gestione delle modifiche alle sole maiuscole.
- Interfaccia e messaggi di rinomina nelle 15 lingue.

## 0.2.0-beta.2 — 6 ottobre 2026

- Corretto l'avvio dopo il download dello ZIP: l'installer genera le due librerie dai sorgenti sul PC, evitando il blocco .NET 0x80131515 delle DLL marcate come provenienti da Internet.
- Gli errori di avvio vengono mostrati e registrati in avvio-errore.log.
- Aggiunti test sul pacchetto con marcatura Internet e sull'avvio VBS nascosto.

## 0.2.0-beta.1 — 6 ottobre 2026

- Interfaccia e menu contestuale in 15 lingue, con scelta al primo avvio.
- Preferenza salvata e pulsante con globo per cambiarla senza riaprire l'app.
- Disposizione da destra a sinistra per arabo e urdu, con selettore e HEX invariati.
- Messaggi applicativi e del launcher tradotti, disponibili senza Internet.
- Pulsanti adattati alle traduzioni più lunghe.
- Test su scelta iniziale, preferenze, cambio lingua e conservazione della palette.

## 0.1.0-beta.1 — 6 ottobre 2026

Prima anteprima pubblica di CartelleColorate.

- Menu a espansione con i colori salvati.
- Selettore compatto con tema chiaro/scuro, HEX, mirino e regolazione fine.
- Pipetta desktop con zoom 10×.
- Icona verticale personalizzabile e importazione PNG multirisoluzione.
- Backup della configurazione iniziale e ripristino.
- Processo di applicazione riutilizzato per ridurre l'attesa dei comandi.
- Codice sorgente, build riproducibile nei passaggi, verifiche e licenza MIT inclusi.

Non sono ancora certificate la compatibilità su più PC o la fluidità in tutte le configurazioni di desktop e monitor. I tempi di aggiornamento di Esplora file possono variare.
