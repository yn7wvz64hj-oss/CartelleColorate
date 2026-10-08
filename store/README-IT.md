# Pubblicazione di Nova Prism sul Microsoft Store

Il progetto genera un MSIX x64 per Windows 10 e 11. Il menu moderno delle cartelle e destinato a Windows 11. Tutte le funzioni sono gratuite. Gli aggiornamenti sono gestiti dal Microsoft Store; non si usa l'installer della versione GitHub.

## Il tuo prossimo passo

1. Apri https://partner.microsoft.com/dashboard e crea un account sviluppatore per Microsoft Store. Scegli il tipo di account corretto per te e completa la verifica richiesta dal portale.
2. Nella sezione delle app Windows crea un nuovo prodotto e riserva **Nova Prism**, se disponibile. Se il nome risulta occupato, concordiamo il nome prima di cambiare i materiali.
3. Apri **Gestione prodotto / Identita del prodotto**. Recupera **Package/Identity/Name**, **Package/Identity/Publisher** e **Package/Properties/PublisherDisplayName**. Sono dati pubblici del pacchetto, non password.
4. Questi tre valori permettono di generare il MSIX definitivo. La build di sviluppo attuale NON va inviata al posto di quella associata al prodotto.

## Build definitiva

Su GitHub, Actions > Microsoft Store MSIX > Run workflow, inserisci i tre valori esatti e abilita submission. Il controllo rifiuta l'identita provvisoria. Al termine scarica l'artefatto **NovaPrism-Microsoft-Store-x64**, con MSIX, checksum, schermata e testi bilingui.

In alternativa, usa Windows PowerShell 5.1 e un prompt di sviluppo Visual Studio x64 con Windows SDK:

```powershell
./store/Build-Store.ps1 -PackageName 'VALORE_PARTNER_CENTER' -Publisher 'VALORE_PARTNER_CENTER' -PublisherDisplayName 'VALORE_PARTNER_CENTER' -Submission
./store/Test-Store.ps1 -Output ./dist/store -Native
```

Il MSIX e intenzionalmente non firmato: Microsoft firma il pacchetto distribuito dallo Store dopo la certificazione. Non occorre acquistare un certificato per questa modalita. La build non pubblica automaticamente e non richiede chiavi segrete.

## Compilare la scheda

- Prezzo: gratuito. Testi: listing/it-IT.txt e listing/en-US.txt.
- Carica il MSIX con l'identita corretta e la schermata Store-Screenshot.png. Puoi aggiungere ulteriori schermate reali.
- Sito/supporto: repository e pagina Issues. Informativa: URL pubblico di store/PRIVACY.md.
- Completa personalmente il questionario di classificazione eta e i dati del tuo account secondo la situazione reale.
- Per runFullTrust spiega: applicazione desktop WPF che modifica icone e desktop.ini nelle cartelle scelte dall'utente, gestisce rinomina e annullamento, e legge un pixel dello schermo solo quando l'utente usa la pipetta. Non richiede elevazione amministrativa.
- Note per i revisori: avviare da Start, scegliere una cartella di prova scrivibile, applicare un colore, controllare Esplora file, annullare. Su Windows 11 verificare anche il menu contestuale Nova Prism. Provare importazione PNG e palette.

## Verifiche prima dell'invio

La pipeline controlla compilazione C#/C++, manifest MSIX con MakeAppx, avvio senza console, backend cartelle, anteprima WPF e factory COM. Occorre inoltre collaudare il pacchetto con identita reale su Windows 11, verificare il menu in Esplora file, eseguire Windows App Certification Kit e completare la revisione Microsoft. La build CI non sostituisce la certificazione o un test visivo su un PC installato.

Non installare un certificato di sviluppo trovato online. Per test privati il pacchetto richiede firma di prova e certificato fidato; la versione Store sara firmata da Microsoft. La build corrente non include ARM64/x86.

## Documentazione Microsoft

- Firma MSIX tramite Store: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options
- Menu cartelle delle app MSIX: https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/integrate-packaged-app-with-file-explorer
- Pubblicazione: https://learn.microsoft.com/en-us/windows/apps/publish/
