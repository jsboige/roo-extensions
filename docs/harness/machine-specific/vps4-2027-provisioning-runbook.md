# Runbook de provisionnement — VPS-4 2027 (nouveau web1)

**Épic :** [#3188](https://github.com/jsboige/roo-extensions/issues/3188) — Phase 0, case « Provisionnement de la machine neuve »
**Lane :** `myia-po-2023:IISManagement` (expertise IIS/ARR, certificats)
**Statut matériel :** VPS **livré le 2026-08-20** (facture FR79847228) — la note owner du 20/08 (« le matériel n'est pas prêt ») est historique, dépassée par les mesures. OOBE déroulé sur console KVM le 24/08 (ai-01) ; SSH 22 + RDP 3389 mesurés ouverts le 28/08 ; administration **exercée par SSH depuis ai-01** (`Administrator@51.75.200.22`, clé, fiche d'accès sur ai-01). §1 et §3 exécutés (23/08, 28/08 + deltas 02/09) ; **§2/§4/§5/§6/§7/§8 non attestés** (état mesuré 07/09 : TZ `Pacific Standard Time`, 91 règles pare-feu par défaut, 0 certificat, `Administrator` seul compte, ni ARR ni URL Rewrite, ni SQL Server, aucun webroot) — **le provisionnement n'est PAS terminé**.
**Date :** 2026-08-21 · **réconcilié le 2026-09-09** contre les commentaires datés de l'Épic (provenances en fin de document)

---

## Cible vs source

| | web1 actuel (source) | VPS-4 2027 (cible) |
|---|---|---|
| OS | Windows Server 2019 Standard (17763) | **Windows Server 2025** (arbitrage owner 25/08 ; mesuré installé 07/09, uptime 13 j) |
| vCPU / RAM | 4 / 15,62 Go (**95 % utilisés**, #3098) | 8 / 24 Go |
| Disque | C: 99,66 Go (86 % utilisés) | 200 Go NVMe |
| Région OVH | `os-sbg8` (Strasbourg) | GRA (Gravelines) |
| Charge | DNN Argumentum (prod) + Default Web Site catch-all | Instance DNN Argumentum mutualisée + **portails DNN dédiés pour tous les domaines** (arbitrage owner 07/09) |
| Extinction | 2027-02-01 (`deleteAtExpiration`) — **rollback target** jusqu'à cette date | — |

Sources : mesures web1 ([commentaire #3188 c.293](https://github.com/jsboige/roo-extensions/issues/3188), 2026-08-20), body de l'Épic, mesures OVH/SSH ai-01 (24/08 → 07/09) — table de provenances en fin de document.

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

## 2. OS baseline (Windows Server 2025) — **non exécuté** (état mesuré 07/09 : TZ `Pacific Standard Time`, 91 règles pare-feu inbound par défaut)

- [ ] Timezone `Romance Standard Time`, NTP actif (`w32tm /query /status`) — **mesuré 07/09 : machine livrée en `Pacific Standard Time`, à corriger**
- [ ] Windows Update : **politique à reprendre de web1** (l'incident autoreboot est couvert flotte par `disable-windows-update-autoreboot.ps1` — décider si le nouveau web1 l'applique : un serveur public DNN ne redémarre pas à 3h du matin pendant une fenêtre ACME)
- [ ] Pagefile : système géré (24 Go RAM ⇒ suffisant), disque unique 200 Go
- [ ] **Canaux d'administration — état actuel : SSH (22) et RDP (3389)**. SSH est le canal **déjà exercé** (ai-01, par clé, depuis le 28/08) — **ne pas fermer le port SSH sans filet de retour** : un second canal d'administration vérifié fonctionnel d'abord. WinRM (5985) : à la parité de web1 — si WinRM HTTPS custom (47001) est en usage pour l'administration distante, le reproduire ; sinon ne pas ouvrir plus que la source
- [ ] Pare-feu inbound : **resserrer les 91 règles par défaut (mesuré 07/09)** vers **80, 443, 3389, 22** (+ 5985 selon le point ci-dessus). SMB (445/135) de web1 n'a aucune raison d'être exposé publiquement sur la neuve — ne pas le reproduire (surface scannée §5 c.293)

## 3. Rôle IIS + features — **exécuté et vérifié (28/08, deltas 02/09)**

**Exécution (ai-01, 28/08, par SSH)** : commande ci-dessous passée telle quelle — 14 → 38 features installées, `W3SVC` Running, `:80` ouvert au sondage. **Deltas (02/09)** : `Web-AppInit`, `Web-Dyn-Compression`, `Web-Scripting-Tools` absentes 3/3 après install (hypothèse « arrivent par dépendance » falsifiée avec contrôle positif), installées explicitement ; module `WebAdministration` vérifié **chargeable** (`New-WebAppPool` présent). **Parité contre la source (web1, 29/08)** : les 4 réconciliations tiennent contre la machine vivante (26 features mesurées sur web1).

Baseline DNN (à **confirmer contre l'extracteur §1**, qui prime). **Écarts réconciliés contre le snapshot web1 du 23/08** (`vps4-snapshot-web1-20260823.txt`) : source en .NET **4.7** (pas 4.8) · `Web-Windows-Auth` **absent** de la source (retiré) · `Web-WebSockets` **présent** dans la source (ajouté). `Web-Digest-Auth` est aussi installé sur la source mais n'est pas requis pour DNN — volontairement absent de la baseline.

```powershell
Install-WindowsFeature Web-Server, Web-Asp-Net45, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter,
  Web-Basic-Auth, Web-WebSockets, Web-Http-Logging, Web-Http-Tracing, Web-Mgmt-Console -Restart
```

- [ ] **.NET Framework — source en 4.7, pas 4.8** : l'extracteur §1 montre `Web-Net-Ext45 = .NET Extensibility 4.7` et `NET-Framework-45-Core = .NET Framework 4.7`. La source n'est **pas** en 4.8. WS2025 embarque 4.8 **in-box** (rétrocompatible avec les apps 4.7, donc DNN 9.x tourne dessus) — `reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release` y retournera ≥ 528040, ce qui est **attendu, pas un écart**. **Confirmé par la mesure du 28/08** : l'installation rend ASP.NET en 4.8. Décision rester en 4.8 (in-box) vs forcer 4.7 : à confirmer par la lane Argumentum avant cutover.
- [ ] Pools : créer `Argumentum` (miroir des settings de l'extracteur — `managedRuntimeVersion`, `startMode`, identité), **pas** DefaultAppPool pour le DNN
- [ ] Logging W3C par site (voir §6 — observabilité par hôte)

## 4. ARR 3.0 + URL Rewrite — **non exécuté** (mesuré 07/09 : ni ARR ni URL Rewrite installés)

L'Épic liste ARR au provisionnement. **État des lieux honnête** : web1 ne sert pas via ARR aujourd'hui (IIS direct, PID 4) ; ARR est le socle des proxies de flotte (po-2023). Sous l'arbitrage owner du 07/09 (tous les domaines en portails DNN sur l'instance mutualisée, cf. §6), l'hébergement des domaines métier **ne requiert plus** un routage vhost direct vs proxy ARR — la question est supprimée, pas tranchée en faveur du proxy.

- [ ] URL Rewrite Module 2.1 (prérequis DNN aussi — redirections canoniques)
- [ ] ARR 3.0 + `netsh http add sslcert` savoir-faire : réutilisable depuis la lane (`D:\Production\IISManagement\scripts\core\IisManagement.psm1` sur po-2023 contient tout le nécessaire) — **à réévaluer sous l'arbitrage 07/09** : à installer seulement si un routage ARR est décidé, sinon inutile pour des portails DNN en direct
- **Décision d'hébergement closée (arbitrage owner 07/09)** : portails DNN dédiés par domaine sur l'instance mutualisée, voir §6.

## 5. Runtimes applicatifs — **non exécuté** (mesuré 07/09 : aucun runtime, ni SQL Server)

À valider contre l'extracteur (§1). Baseline attendue pour DNN 9.x :

- [ ] URL Rewrite 2.1 (cf §4)
- [ ] VC++ 2015-2022 redistributable (x64)
- [ ] SQL Server : **même édition/major que web1** (extracteur §1) — la base DNN migre par backup/restore, pas par export. *(rapporté 07/09 par la coordination : SQL Server 2019 Express à la parité de la source — à confirmer contre l'extracteur avant installation)*
- [ ] Aucun runtime moderne (.NET 6+) sauf preuve dans l'extracteur

## 6. Bindings — un binding explicite par domaine, **pas de catch-all**

C'est la correction structurelle au constat c.293 : le Default Web Site de web1 rattrape `argumentum.fr`, `myia.org`, `www.myia.org` (16k hits/5j dont 95 % de scans PHP/.env — observabilité nulle, surface d'attaque gratuite ; re-mesuré 07/09 : **15 283 requêtes 404 sur 5 jours**, plus que le site de prod lui-même).

**Arbitrage owner 07/09 — l'hébergement de chaque domaine est clos** : tous passent en **portails DNN dédiés sur l'instance Argumentum mutualisée** (« prendre en charge tous les noms de domaine sur l'instance Argumentum mutualisée en créant des portails dnn dédiés »). La question « vhost vitrine / proxy ARR par domaine » (§4) est supprimée par cet arbitrage, pas tranchée en faveur d'une option.

**Règle inchangée : chaque domaine qui pointe vers la machine a son binding explicite (http 80 + https 443, SNI, host header). Jamais de binding rattrapé par le catch-all. Le Default Web Site est arrêté (Stopped) dès la recette passée.**

Ordre de création (avant toute bascule DNS) :

| Domaine | Hébergement (arbitrage 07/09) | Statut DNS aujourd'hui (mesuré 24/08, re-mesuré 07/09) | Rôle |
|---|---|---|---|
| `www.argumentum.games` + `argumentum.games` | Instance DNN `Argumentum` (webroot migré) | → 37.187.180.135 (prod live) | prod DNN, **basculer en dernier** |
| `argumentum.fr` | Portail DNN ou alias du portail Argumentum | → 37.187.180.135 (catch-all) | redirection |
| `myia.org` + `www.myia.org` | Portail DNN dédié — la vitrine ne demande plus qu'un contenu | → 37.187.180.135 (catch-all, aucun binding 443) | Phase 2 |
| `constituons.fr` | Portail DNN dédié (conception produit reste ouverte) | parking Gandi (217.70.184.38) | Phase 4 |
| `democratie.biz` | Portail DNN dédié — le risque de détournement disparaît **en étant utilisé** | `www` → 51.68.117.213 (IP du pool OVH **hors compte**, répond TCP mais sert vide) · apex NXDOMAIN | Phase 3 |

- [ ] Recette **avant DNS** : chaque site répond en `curl --resolve <domaine>:443:<IP_neuve>` avec le bon certificat et le bon contenu (gate de recette, reco #1 de web1)
- [ ] Vérifier `Host header`/SNI sur chaque binding — jamais de binding `*:443` sans host name (c'est ce qui crée les catch-alls)
- [ ] **Bascule « instantanée » (arbitrage owner 07/09) — trois réalités distinctes à ne pas confondre** :
  1. **Préparation à froid** : webroot, base, bindings, certificats installés puis **recettés** sur la neuve (`curl --resolve`, DNS intact) AVANT toute bascule — c'est ce qui réduit la fenêtre de travail à un repointage.
  2. **Repointage DNS** : la bascule elle-même est le changement d'enregistrement. La coupure perçue dépend du **TTL de propagation** des enregistrements (résolveurs intermédiaires qui ont mis en cache l'ancienne IP) — un TTL bas réduit la fenêtre mais **ne la garantit jamais nulle**.
  3. **Synchronisation finale des données** : le snapshot §1 date du **23/08** — la base et le webroot ont vécu en production depuis. La copie finale (backup/restore SQL + web.config vivant unitaire) doit rattraper le delta **juste avant** la bascule, sinon la neuve sert un état périmé.
  **Rollback** : repointer le DNS vers l'ancienne machine — valable **jusqu'au 2027-02-01** uniquement (`deleteAtExpiration: true`, mesuré 24/08). La propagation du TTL s'applique aussi au rollback.

## 7. Certificats — win-acme (wacs) — **non exécuté** (mesuré 07/09 : 0 certificat, 443 fermé)

La lane po-2023 exploite déjà wacs en auto (cert SAN 52 domaines, renew automatique, self-heal de dérive) — `D:\Production\IISManagement\scripts\core\WinAcmeAutomation.psm1` est le module de référence.

- [ ] Installer win-acme sur la neuve, validation **HTTP-01** sur `:80` (les bindings http 80 existent dès §6)
- [ ] Certs distincts par famille (pas un méga-SAN multi-domaines métier) : `argumentum.games`+`www`, `argumentum.fr`, `myia.org`+`www` — un renouvellement ne doit pas toucher les autres domaines
- [ ] **Contrainte ACME — depuis l'arbitrage 07/09, elle ne borne plus que le repointage DNS** : tout le provisionnement (§2-§8, y compris la préparation de la recette `curl --resolve`) s'exécute maintenant ; seul le changement d'enregistrement DNS se place **avant le 05/10 ou après le 04/11** (fenêtre dérivée du cert prod `notAfter 2026-11-04`). **Aucune émission n'a été exécutée à ce jour** (0 certificat au 07/09). La question HTTP-01 pré/post-bascule (le domaine doit résoudre vers la machine qui sert le challenge) **reste ouverte** — le plan exact est à instruire au moment du cutover (Phase 1 Épic). Ne pas inscrire une méthode comme exécutée tant qu'elle ne l'est pas.
- [ ] Renouvellement automatique programmé + vérification (tâche planifiée wacs, miroir du pattern po-2023)

## 8. Comptes — **non exécuté** (mesuré 07/09 : `Administrator` seul compte)

- [ ] Compte admin local nommé (pas `Administrator` par défaut si la source a renommé — extraire §1). **État 07/09** : l'OOBE du 24/08 a créé le compte `Administrator` — canal d'administration actuel : SSH par clé depuis ai-01
- [ ] Identité du pool `Argumentum` : miroir de la source (AppPoolIdentity sauf preuve contraire)
- [ ] Compte agent (Claude worker) : à créer à parité de web1 **seulement quand la machine prend du rôle d'exécutant** — pas nécessaire au premier jour de prod
- [ ] **#1091 au moment du déplacement des credentials** : le mot de passe membership `contact@argumentum.games` stocké en clair depuis 2020 se traite pendant la migration, pas après (l'Épic l'exige explicitement)

## 9. Dépendances ouvertes hors lane (pour mémoire)

| Dépendance | Owner | État (MAJ 09/09) |
|---|---|---|
| Livraison/accès VPS-4 GRA | owner | **clos** — livré 20/08 01:45 (facture FR79847228), OOBE déroulé 24/08, SSH 22 + RDP 3389 mesurés ouverts 28/08, accès SSH exercé depuis ai-01 (clé, compte `Administrator`, fiche d'accès sur ai-01) |
| Audit allowlist vLLM (IP web1) | ai-01 | **clos 24/08** — l'IP figure dans `leaked_key_monitor.py` L74 mais cette liste est du **monitoring, pas un contrôle d'accès** (le gate est la clé API). Seule action au cutover : ajouter la nouvelle IP `51.75.200.22` à la liste pour éviter de fausses alertes |
| Audit IP dans `ArgumentumGames/Argumentum` (fichiers de prod) | lane Argumentum | **clos 22/08** (po-204 c.266 : 0 occurrence) |
| Inventaire IP flotte (web1, po-2023, po-204, po-2025, po-2026, ai-01) | flotte | **clos 24/08 — 0 dépendance bloquante** (body de l'Épic) |
| Snapshot extracteur §1 | web1 | **exécuté 23/08 14:14** (web1 c.318 → `vps4-snapshot-web1-20260823.txt`). ⚠️ **Périmé pour la bascule** : la synchro finale doit rattraper le delta de prod depuis le 23/08 |
| Bascule DNS + fenêtre ACME | coordination Épic | repointage DNS **hors** 05/10→04/11 ; provisionnement non borné (arbitrage 07/09) |

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

*Inventaire IP **clos flotte-wide** (web1 20/08, po-2023 21/08, po-204 + Argumentum 22/08, po-2025/po-2026 22/08, ai-01 24/08) : **0 dépendance bloquante** — body de l'Épic, case clos le 24/08.*

---

## Provenances (réconciliation doc du 2026-09-09)

Tout fait daté ci-dessus provient des commentaires horodatés de l'Épic #3188 — **aucune mesure n'a été refaite par cette révision** (po-2023, lecture seule, zéro accès distant, zéro mutation). Qualification : décision consignée / mesure historique / état non revérifié par cette PR.

| Fait cité | Source (commentaire #3188) | Qualification |
|---|---|---|
| Specs web1, inventaire sites, dépendances IP web1 | web1, 20/08 (c.293) | mesure historique |
| Décision owner : cutover sur web1, migration découplée de la montée de version | lane Argumentum, 20/08 | **décision consignée** (owner) |
| Snapshot extracteur §1 | web1, 23/08 (c.318) | mesure historique |
| Livraison VPS, facture, licence, comparatif, DNS Gandi | ai-01 (API OVH authentifiée), 24/08 | mesure historique |
| Audit allowlist vLLM clos | ai-01, 24/08 | mesure + conclusion |
| OOBE déroulé (console KVM) | ai-01, 24/08 | mesure historique |
| **Arbitrage OS : Windows Server 2025** | ai-01 relais décision owner, 25/08 | **décision consignée** (owner) |
| SSH 22 + RDP 3389 ouverts (correction d'un faux constat) | ai-01, 28/08 | mesure historique |
| §3 IIS exécuté + accès SSH exercé | ai-01, 28/08 | mesure historique + action |
| Parité §3 vérifiée depuis la source | web1, 29/08 | mesure historique |
| Deltas IIS installés 3/3 | ai-01, 02/09 | mesure + action |
| **Arbitrage : migration en l'état, portails DNN tous domaines, état 1/8 mesuré** | ai-01 relais décisions owner, 07/09 | **décision consignée** (owner) + mesure |

🤖 Rédigé par `myia-po-2023:IISManagement` · Epic #3188 · 2026-08-21 · **réconcilié par `myia-po-2023:roo-extensions` le 2026-09-09** ([DISPATCH #3188 c.5592836902](https://github.com/jsboige/roo-extensions/issues/3188#issuecomment-5592836902))
