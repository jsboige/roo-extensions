# Runbook de provisionnement — VPS-4 2027 (nouveau web1)

**Épic :** [#3188](https://github.com/jsboige/roo-extensions/issues/3188) — Phase 0, case « Provisionnement de la machine neuve »
**Lane :** `myia-po-2023:IISManagement` (expertise IIS/ARR, certificats)
**Statut matériel :** VPS commandé et réglé, **non encore livré/accesssible** (« le matériel n'est pas prêt », owner 20/08). Ce runbook est prêt à exécuter dès réception des accès.
**Date :** 2026-08-21

---

## Cible vs source

| | web1 actuel (source) | VPS-4 2027 (cible) |
|---|---|---|
| OS | Windows Server 2019 Standard (17763) | Windows Server 2022 |
| vCPU / RAM | 4 / 15,62 Go (**95 % utilisés**, #3098) | 8 / 24 Go |
| Disque | C: 99,66 Go (86 % utilisés) | 200 Go NVMe |
| Région OVH | `os-sbg8` (Strasbourg) | GRA (Gravelines) |
| Charge | DNN Argumentum (prod) + Default Web Site catch-all | DNN Argumentum + 3 domaines pré-positionnés |
| Extinction | 2027-02-01 (`deleteAtExpiration`) — **rollback target** jusqu'à cette date | — |

Sources : mesures web1 ([commentaire #3188 c.293](https://github.com/jsboige/roo-extensions/issues/3188), 2026-08-20), body de l'Épic.

## Principe directeur : miroir, pas réinvention

Chaque état de la source qui compte pour la prod doit être **extrait de web1 puis reproduit**, pas deviné. Le runbook commence donc par un extracteur. Deux mines connues conditionnent tout le reste :

- **#1049** : `DNNPlatform/web.config` versionné ≠ config vivante. Tout mécanisme qui écrit l'arbre git dans le webroot produit un **500 déterministe**. → Le web.config **vivant** de web1 est copié comme fichier unitaire, jamais via une synchro d'arbre git.
- **Fenêtre ACME 05/10 → 04/11** (dérivée du certificat prod `notAfter 2026-11-04`) : **aucune bascule DNS** dans cette fenêtre.

---

## 1. Extracteur — photographier web1 avant tout

À exécuter **sur web1** (lecture seule), sortie archivée dans `$ROOSYNC_SHARED_PATH` puis versée au ticket :

```powershell
# Features IIS/Windows réellement installées
Get-WindowsFeature | Where-Object Installed | Select-Object Name, DisplayName

# Version .NET réelle du pool Argumentum
Get-IISAppPool Argumentum | Select-Object managedRuntimeVersion, startMode, processModel

# Bindings exacts (le tableau c.293 dit : *:80 x4 + *:443 x3, SNI — reproduire à l'identique + host headers explicites)
Get-WebBinding

# Certificats en place (sujet, SANs, empreinte, store)
Get-ChildItem Cert:\LocalMachine\WebHosting, Cert:\LocalMachine\My |
  Where-Object { $_.NotAfter -gt (Get-Date) } |
  Select-Object Subject, Thumbprint, NotAfter, @{n='SANs';e={$_.DnsNameList -join ','}}

# SQL Server : édition + version + bases (la DB DNN doit migrer, ce n'est pas que du filesystem)
sqlcmd -S localhost -Q "SELECT @@VERSION; SELECT name, recovery_model_desc, state_desc FROM sys.databases"

# Tâches planifiées & comptes de service éventuels
Get-ScheduledTask | Where-Object State -ne 'Disabled' | Select-Object TaskName, TaskPath
```

**Livrable :** snapshot web1 horodaté. Aucun provisioning ne démarre sans lui.

## 2. OS baseline (Windows Server 2022)

- [ ] Timezone `Romance Standard Time`, NTP actif (`w32tm /query /status`)
- [ ] Windows Update : **politique à reprendre de web1** (l'incident autoreboot est couvert flotte par `disable-windows-update-autoreboot.ps1` — décider si le nouveau web1 l'applique : un serveur public DNN ne redémarre pas à 3h du matin pendant une fenêtre ACME)
- [ ] Pagefile : système géré (24 Go RAM ⇒ suffisant), disque unique 200 Go
- [ ] **RDP (3389) + WinRM (5985)** : à la parité de web1 — si WinRM HTTPS custom (47001) est en usage pour l'administration distante, le reproduire ; sinon ne pas ouvrir plus que la source
- [ ] Pare-feu inbound : **80, 443, 3389, 5985 uniquement**. SMB (445/135) de web1 n'a aucune raison d'être exposé publiquement sur la neuve — ne pas le reproduire (surface scannée §5 c.293)

## 3. Rôle IIS + features

Baseline DNN (à **confirmer contre l'extracteur §1**, qui prime). **Écarts réconciliés contre le snapshot web1 du 23/08** (`vps4-snapshot-web1-20260823.txt`) : source en .NET **4.7** (pas 4.8) · `Web-Windows-Auth` **absent** de la source (retiré) · `Web-WebSockets` **présent** dans la source (ajouté). `Web-Digest-Auth` est aussi installé sur la source mais n'est pas requis pour DNN — volontairement absent de la baseline.

```powershell
Install-WindowsFeature Web-Server, Web-Asp-Net45, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter,
  Web-Basic-Auth, Web-WebSockets, Web-Http-Logging, Web-Http-Tracing, Web-Mgmt-Console -Restart
```

- [ ] **.NET Framework — source en 4.7, pas 4.8** : l'extracteur §1 montre `Web-Net-Ext45 = .NET Extensibility 4.7` et `NET-Framework-45-Core = .NET Framework 4.7`. La source n'est **pas** en 4.8. WS2022 embarque 4.8 **in-box** (rétrocompatible avec les apps 4.7, donc DNN 9.x tourne dessus) — `reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release` y retournera ≥ 528040, ce qui est **attendu, pas un écart**. Décision rester en 4.8 (in-box) vs forcer 4.7 : à confirmer par la lane Argumentum avant cutover.
- [ ] Pools : créer `Argumentum` (miroir des settings de l'extracteur — `managedRuntimeVersion`, `startMode`, identité), **pas** DefaultAppPool pour le DNN
- [ ] Logging W3C par site (voir §6 — observabilité par hôte)

## 4. ARR 3.0 + URL Rewrite

L'Épic liste ARR au provisionnement. **État des lieux honnête** : web1 ne sert pas via ARR aujourd'hui (IIS direct, PID 4) ; ARR est le socle des proxies de flotte (po-2023) et l'option naturelle si les nouveaux domaines (`constituons.fr`, `democratie.biz`) sont servis derrière des proxys plutôt qu'en direct.

- [ ] URL Rewrite Module 2.1 (prérequis DNN aussi — redirections canoniques)
- [ ] ARR 3.0 + `netsh http add sslcert` savoir-faire : réutilisable depuis la lane (`D:\Production\IISManagement\scripts\core\IisManagement.psm1` sur po-2023 contient tout le nécessaire)
- **Décision ouverte (à trancher avant la Phase 2 de l'Épic)** : vhost direct vs proxy ARR par domaine. Ne bloque pas le provisioning — installer les deux modules, décider du routage par domaine ensuite.

## 5. Runtimes applicatifs

À valider contre l'extracteur (§1). Baseline attendue pour DNN 9.x :

- [ ] URL Rewrite 2.1 (cf §4)
- [ ] VC++ 2015-2022 redistributable (x64)
- [ ] SQL Server : **même édition/major que web1** (extracteur §1) — la base DNN migre par backup/restore, pas par export
- [ ] Aucun runtime moderne (.NET 6+) sauf preuve dans l'extracteur

## 6. Bindings — un vhost par domaine, **pas de catch-all**

C'est la correction structurelle au constat c.293 : le Default Web Site de web1 rattrape `argumentum.fr`, `myia.org`, `www.myia.org` (16k hits/5j dont 95 % de scans PHP/.env — observabilité nulle, surface d'attaque gratuite).

**Règle : chaque domaine qui pointe vers la machine a son site IIS + binding explicite (http 80 + https 443, SNI). Le Default Web Site est arrêté (Stopped) dès la recette passée.**

Ordre de création (avant toute bascule DNS) :

| Domaine | Site IIS | Statut DNS aujourd'hui | Rôle |
|---|---|---|---|
| `www.argumentum.games` + `argumentum.games` | `Argumentum` (webroot migré) | → 37.187.180.135 (prod live) | prod DNN, **basculer en dernier** |
| `argumentum.fr` | `Argumentum` (binding ajouté ou vhost redirect → .games) | → 37.187.180.135 (catch-all) | redirection |
| `myia.org` + `www.myia.org` | vhost vitrine (Phase 2 Épic) | → 37.187.180.135 (catch-all) | Phase 2 |
| `constituons.fr` | (Phase 4) | parking Gandi | — |
| `democratie.biz` | (Phase 3) | apex NXDOMAIN | — |

- [ ] Recette **avant DNS** : chaque site répond en `curl --resolve <domaine>:443:<IP_neuve>` avec le bon certificat et le bon contenu (gate de recette, reco #1 de web1)
- [ ] Vérifier `Host header`/SNI sur chaque binding — jamais de binding `*:443` sans host name (c'est ce qui crée les catch-alls)

## 7. Certificats — win-acme (wacs)

La lane po-2023 exploite déjà wacs en auto (cert SAN 52 domaines, renew automatique, self-heal de dérive) — `D:\Production\IISManagement\scripts\core\WinAcmeAutomation.psm1` est le module de référence.

- [ ] Installer win-acme sur la neuve, validation **HTTP-01** sur `:80` (les bindings http 80 existent dès §6)
- [ ] Certs distincts par famille (pas un méga-SAN multi-domaines métier) : `argumentum.games`+`www`, `argumentum.fr`, `myia.org`+`www` — un renouvellement ne doit pas toucher les autres domaines
- [ ] **Contrainte ACME (l'Épic la porte) : pas de bascule DNS du 05/10 au 04/11** (fenêtre dérivée du cert prod `notAfter 2026-11-04`). Premier émission **avant** basculement DNS : HTTP-01 exige que le domaine résolve encore vers l'ANCIENNE machine… **sauf si l'émission se fait via la neuve en `--challenge` pré-DNS impossible** — donc : soit émettre avant bascule via DNS temporaire, soit basculer hors fenêtre et émettre immédiatement après. Le plan exact est à instruire au moment du cutover (Phase 1 Épic).
- [ ] Renouvellement automatique programmé + vérification (tâche planifiée wacs, miroir du pattern po-2023)

## 8. Comptes

- [ ] Compte admin local nommé (pas `Administrator` par défaut si la source a renommé — extraire §1)
- [ ] Identité du pool `Argumentum` : miroir de la source (AppPoolIdentity sauf preuve contraire)
- [ ] Compte agent (Claude worker) : à créer à parité de web1 **seulement quand la machine prend du rôle d'exécutant** — pas nécessaire au premier jour de prod
- [ ] **#1091 au moment du déplacement des credentials** : le mot de passe membership `contact@argumentum.games` stocké en clair depuis 2020 se traite pendant la migration, pas après (l'Épic l'exige explicitement)

## 9. Dépendances ouvertes hors lane (pour mémoire)

| Dépendance | Owner | État (MAJ 24/08) |
|---|---|---|
| Livraison/acccès VPS-4 GRA | owner | **matériel pas prêt** (20/08) |
| Audit allowlist vLLM (IP web1) | ai-01 | ouvert — **seule surface restante** (reco #3 web1 c.293, répétée ×2) |
| Audit IP dans `ArgumentumGames/Argumentum` (fichiers de prod) | lane Argumentum | **clos 22/08** (po-204 c.266 : 0 occurrence) |
| Snapshot extracteur §1 | web1 | **exécuté 23/08 14:14** (web1 c.318 → `vps4-snapshot-web1-20260823.txt`) |
| Bascule DNS + fenêtre ACME | coordination Épic | fenêtre interdite 05/10→04/11 |

---

## Annexe A — Inventaire des dépendances à l'IP web1 côté po-2023 (livré 2026-08-21)

Recherche exhaustive `37.187.180.135` sur **myia-po-2023** (lane IISManagement = l'edge ARR de la flotte, 52 sites `*.myia.io`) :

| Surface scannée | Méthode | Résultat |
|---|---|---|
| `applicationHost.config` (52 sites, farms, rewrites) | parse regex IP-littérales + `37.187` | **0** |
| `hosts` | grep | **0** |
| `D:\Production\*` (tous webroots proxy + web.config + scripts + watchdog state + admin-runner) | grep récursif | **0** |
| `C:\ProgramData\maint-scripts` | grep | **0** |
| `D:\Dev\Argumentum` fichiers trackés | `git grep` | **0** (hits `37.187` = coordonnées SVG) |
| `D:\Dev\Argumentum\DNNPlatform\web.config` (préprod vivant, non tracké) | grep | **0** (2 hits = subtrings publicKeyToken `537f1870…`) |

**Conclusion : po-2023 ne dépend pas de l'IP web1.** Les sites Argumentum locaux (`argumentum.myia.io`, `dnn.argumentum.myia.io`) servent la **préprod locale** (`D:\Dev\Argumentum\*`), pas la prod web1. La bascule d'IP web1 n'impacte aucune config de cette machine.

*Il reste l'audit côté ai-01 (allowlist vLLM) et le dépôt ArgumentumGames — voir §9.*

---

🤖 Rédigé par `myia-po-2023:IISManagement` · Epic #3188 · 2026-08-21
