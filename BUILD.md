# Creare il pacchetto

Usa Windows con **Windows PowerShell 5.1**. Non servono compilatori da installare: `Add-Type` compila le due librerie C# con gli strumenti .NET Framework presenti.

Da Windows PowerShell, nella cartella del repository:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\Build.ps1 -Test
```

Il risultato è in `dist`: ZIP per Windows e file SHA256. Le cartelle di lavoro sono in `work`, escluse dal repository e dal pacchetto. I sorgenti C# sono inclusi nel pacchetto utenti per trasparenza. I file DLL non devono essere caricati separatamente nel repository: vengono generati dalla build.

`-Test` esegue controlli su cartelle temporanee e una renderizzazione dell'interfaccia fuori schermo, senza installare il menu o cambiare cartelle personali. Non sostituisce i test manuali su altri PC.

La compilazione segue gli stessi passaggi in locale e in GitHub Actions, ma il compilatore non garantisce file DLL identici byte per byte tra build. Confronta il checksum con il file SHA256 della specifica release scaricata.
