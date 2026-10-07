# Language packages / Pacchetti di lingua

## Italiano

Apri il globo e premi **Esporta modello**. Il file `.cclang` è un documento JSON in UTF-8: puoi aprirlo con un editor di testo, tradurre le voci e condividerlo. Nell’app premi **Importa lingua**, scegli il file, seleziona la lingua e premi **Continua**. La sola importazione non cambia la lingua attiva.

- `schemaVersion`: mantieni `1`.
- `code`: codice della lingua, per esempio `it`, `pt-br`, `zh-hant` o un codice ISO a tre lettere. Usa lettere, numeri e trattini, senza spazi o percorsi. `en` è riservato al catalogo inglese di riserva; una variante come `en-gb` è ammessa.
- `nativeName`: nome della lingua nella lingua stessa.
- `englishName`: nome inglese, utilizzato anche nella ricerca.
- `rtl`: `true` per le lingue da destra a sinistra, altrimenti `false`.
- `strings`: traduci i valori e lascia invariati i nomi delle chiavi. Conserva segnaposti come `{0}`, `{1}` e `{2}`. Puoi eliminare una voce non ancora tradotta o lasciarla vuota: verrà usato l’inglese.

I pacchetti importati sono indicati come provvisori: l’app non può verificarne la qualità linguistica. Si possono usare anche lingue non riconosciute da Windows, senza limitare l’elenco ai 35 cataloghi inclusi. La disponibilità dei caratteri dipende dai font presenti sul computer.

I file vengono salvati in `%LOCALAPPDATA%\CartelleColorate\languages\lang-CODICE.json`. Un pacchetto con lo stesso codice aggiorna quello precedente dopo la convalida; un errore lascia intatto il file già salvato. L’inglese di riserva non può essere sostituito. Per trasferire una lingua su un altro PC, importa lo stesso `.cclang`; i pacchetti personali non sono inclusi nei backup `.ccbackup` della libreria.

Non servono account o servizi di traduzione. I pacchetti non contengono script e vengono letti solo come dati. Il limite di un file è 1 MB. Le 20 nuove lingue incluse nella 1.5 hanno traduzioni parziali dei comandi principali; le voci mancanti restano in inglese.

## English

Open the globe button and choose **Export template**. A `.cclang` file is UTF-8 JSON: edit its text values and share it. Choose **Import language**, select the file, select the language and press **Continue**. Importing alone does not change the active language.

Keep `schemaVersion: 1`, use a language `code` such as `it`, `pt-br`, `zh-hant` or a three-letter ISO code, and set `nativeName`, `englishName` and the Boolean `rtl`. Translate the values in `strings`, preserving key names and placeholders such as `{0}`. Omitted or empty entries use English. Code `en` is reserved; variants such as `en-gb` are allowed.

Imported packages are marked Draft because the app cannot assess linguistic quality. Languages outside the 35 built-in catalogs can be added, including languages Windows does not recognize. Fonts installed on the computer determine character coverage.

Packages are kept under `%LOCALAPPDATA%\CartelleColorate\languages\lang-CODE.json`, survive app updates, and require no account or online translation service. Same-code imports replace the previous file only after validation. Personal language packages are not included in library `.ccbackup` files: import the same `.cclang` on the other computer. Files are read only as data, with a 1 MB size limit. The 20 new built-in catalogs are partial draft translations; missing entries use English.
