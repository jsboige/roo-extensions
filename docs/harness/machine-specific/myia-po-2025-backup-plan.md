# Plan de sauvegarde — données hors-git de `myia-po-2025:roo-extensions`

**Lane :** `myia-po-2025:roo-extensions` · **Établi :** 2026-10-20 · **Relecture :** à chaque test de restauration, au minimum trimestrielle
**Mandat :** user 2026-10-20 — « un plan de sauvegarde des configs et de tout ce qui n'est pas sous git […] tous les workspaces doivent avoir un plan de sauvegarde de leurs données critiques […] ça mérite une issue et un suivi de long terme avec tests de restauration. »
**Point de rendez-vous flotte :** [`jsboige/Maintenance#126`](https://github.com/jsboige/Maintenance/issues/126) — l'inventaire publié et les preuves de test vivent sur l'issue ; **ce document est le plan du workspace**.

Fil conducteur : **ce qui n'est pas sous git n'existe qu'une fois**, et **un backup jamais restauré est une hypothèse, pas une sauvegarde**.

---

## 1. Familles hors-git — mesurées firsthand le 2026-10-20

| Id | Famille | Contenu mesuré | Criticité | Canal retenu |
|---|---|---|---|---|
| **F1** | Mémoire de lane | `~/.claude/projects/d--dev-roo-extensions/memory/` — **96 fichiers / 1 272,5 Ko** | **critique** — non reproductible (cycles, registres, références) | local **+ hors-machine** (7z) |
| **F2** | Config harnais machine | `~/.claude.json` 82,4 Ko · `~/.claude/settings.json` 4,1 Ko · `keybindings.json` 0,3 Ko · `~/.claude/rules/` 4 f / 8,6 Ko | critique | **aucun canal de restauration aujourd'hui** — `roosync_config` n'en est pas un (§5) |
| **F3** | Secrets locaux | `.env` 584 o · `.env.pre-vllm-rotation-20260930` 499 o · `~/.roo-state-manager/stall-detector.env` 228 o · **`.env` RSM du submodule (3 646 o)** avec sa chaîne primaire + snapshot + blob offsite — **réparée et testée le 20/10** (§3 T4) | critique | chaîne `backup-mcp-env.ps1` (primaire local + blob offsite, design #2772) pour le `.env` RSM ; **local seul** pour le reste (§5) |
| **F4** | Définitions de tâches planifiées | **7 tâches = le périmètre de cette lane** = 11,8 Ko d'XML : `Claude-ApprovalStallDetector`, `Claude-DashboardListener`, `ClaudeTranscriptArchive`, `Claude-MetaAudit`, `Vibe-Feeder`, `Vibe-Worker`, `roo-rotate-scheduling-logs` (6 en `RunLevel=Limited`, 1 en `Highest`). **La machine porte 19 tâches au total** — les 12 autres (`Claudish*` ×7, `Copilot-*` ×2, `Claude-DashboardWatcher`, `GDriveFS-Watchdog`, `WMI-Startup-Capture`) appartiennent aux lanes claudish/copilot ou au niveau machine : elles sont du ressort de leurs plans respectifs, pas de celui-ci | critique — l'orchestration OS meurt avec | local **+ hors-machine** (7z, avec F7) |
| **F5** | État Vibe/Zoo hors git | `outputs/vibe/feeder-queue.json` 343,6 Ko (+ `outputs/scheduling/logs/`) — `/outputs/` gitignoré (`.gitignore:250`) | moyenne — état partiellement régénérable | local ; hors-machine **à trancher par le pilote** |
| **F6** | Extension zoo forkée (installée) | `~/.vscode/extensions/jsboige.zoo-scheduler-0.0.11-zoo.4` — 72 f / 7 130,5 Ko | **faible — reconstructible** : source trackée (`zoo-code/`, `scripts/zoo-scheduler`) ; les `.vsix` sous `outputs/` sont gitignorés | source git = canal ; pas de copie dédiée |
| **F7** | Lanceurs cachés — **deux répertoires** | ① `%LOCALAPPDATA%\claude-hidden-launchers\` — 1 f / 603 o (`Claude-ApprovalStallDetector.vbs`). ② **`C:\ProgramData\claude-hidden-launchers\`** — répertoire **partagé machine** (20+ fichiers de plusieurs lanes) dont **cette lane en possède 6** : `Claude-DashboardListener.vbs`+`.orig.json`, `Claude-MetaAudit.vbs`+`.orig.json`, `Vibe-Worker.vbs`+`.orig.json`. Les deux autres tâches à lanceur (`Vibe-Feeder` → script tracké dans le dépôt) et à action directe (`ClaudeTranscriptArchive`, `roo-rotate-scheduling-logs` → scripts trackés) sont reconstructibles via git | critique — **une tâche restaurée sans son lanceur ne fait rien** (§4) ; 3 des 7 tâches F4 pointent dans ② | lié à F4 : même archive (nos 6 fichiers de ② + le fichier de ①) |
| — | Transcripts de session | `~/.claude/projects/d--dev-roo-extensions/` complet = **385 f / 644 728 Ko** | — | canal existant : tâche `ClaudeTranscriptArchive` (quotidien 04:41, 7z → GDrive) ; **RX46 : purge interdite** |

F1, F4, F5 et F7 sont **propres à cette lane** — F7 partiellement : le répertoire ProgramData est partagé machine, l'archive n'emporte que les 6 fichiers de cette lane (les autres fichiers de ce répertoire relèvent des lanes qui les possèdent). F2 est **au niveau machine** (partagée avec `po-2025:CoursIA`) — son volet est porté par la lane harnais, pas dupliqué ici.

---

## 2. Canaux, cadence, rétention

**T1 — local** : `D:\dev\backups\po2025-roo-extensions\<AAAAMMJJ>\` — une archive par famille + manifeste. Hors dépôt, jamais dans git.

**T2 — hors-machine** : `G:\Mon Drive\Backups-Cloud\po2025-roo-extensions\<AAAAMMJJ>\` — **même doctrine que les transcripts** ([`claude-transcript-archiving.md`](../reference/claude-transcript-archiving.md)) : archive unique `.7z`, vérifiée par `7z t`, **jamais d'arbre brut** sur DriveFS. Familles éligibles : F1, F4+F7 (vérifiées sans motif secret). Créneau hebdomadaire décalé (dimanche), pour ne pas se disputer la fenêtre d'upload avec les tâches 04:17 / 04:41.

**Cadence proposée** : T1 quotidien · T2 hebdomadaire · rétention 7 quotidiennes + 4 hebdomadaires, purge des plus anciennes au-delà.

**Interdit** : `D:\dev\backups` ne doit jamais être placé dans un dossier synchronisé. **F3 sur T2 est autorisé depuis le 23/10** — décision user explicite (« secrets sur Drive partagé = décision user explicite », mandat backup du 23/10 ; un emplacement restreint reste possible sur proposition de lane). Le `.env` RSM du submodule est désormais capturé par l'organe mutualisé (§6) ; les **autres** secrets locaux restent hors-machine subordonnés à l'escrow chiffré.

**Automatisation : organe mutualisé ARMÉ le 2026-10-24** (§6) — premier run vérifié le 2026-10-23 (§6), tâche planifiée `Claude-Backup-NonGit` posée au merge de l'organe (#4328 mergée `c44fe571`).

---

## 3. Tests de restauration — preuves datées (2026-10-20)

Tous les tests restaurent **pour de vrai**, sur une **cible jetable**, et comparent les empreintes sha256 fichier par fichier.

| # | Heure (UTC) | Familles | Résultat | Empreinte de l'artefact |
|---|---|---|---|---|
| T1 | `20261020T111653Z` | F1, F6, F3 | **PASS** — F1 96/96 · F6 72/72 · F3 3/3, 0 manquant, 0 différent | F1 `a253a14d9b250388` · F6 `35bfca0913cdcc4e` · F3 `535c8b389b8e707c` |
| T2 | `20261020T112224Z` | F1, F4+F7 | **PASS** — F1 96/96 · F4+F7 8/8, **restaurés depuis la copie hors-machine** | F1 `08f99fe5c110548e` · F4+F7 `52e537fc714fee56` |
| T3 | `20261020T111807Z` | F4 (définition) | **PASS** — aller-retour XML sur cible jetable (`TestRestore-po2025-20261020T111807Z`, `State=Disabled`) : définition **identique** hors `<Enabled>false</Enabled>` inséré par la désactivation volontaire ; action résolvable (`wscript.exe` → `C:\WINDOWS\system32\wscript.exe`, script cible présent) ; 1 déclencheur restauré ; cible **retirée** (présente après retrait : `False`) | XML `8F4540625E3A9E36` |
| T-lanceur | (inclus T2) | F7 | **PASS** — 603 o → artefact → restauré, empreinte identique `5c232faba50f9e69` ; 0 motif secret dans le lanceur | idem T2 |
| **T4** | `20261020T112610Z` → ~`T112900Z` | F3 (`.env` RSM du submodule) | **PASS** — chaîne **réparée** (primaire + snapshot + blob offsite) puis **restauration réelle en bac à sable** : `restore-mcp-env.ps1` exécuté pour de vrai (`USERPROFILE` détourné, faux dépôt vide), **exit 0**, « vars dures présentes », fichier restauré **3 646 o, `62532D13`** = identique au vivant ; le `.env` vivant est **inchangé** après le test | vivant = primaire = blob : `62532d13…` |
| **T5** | `20261020T154207Z` | F7 ② (ProgramData) | **PASS** — les **6 fichiers** lanceurs de la lane (`Claude-DashboardListener`, `Claude-MetaAudit`, `Vibe-Worker` — `.vbs` + `.orig.json`) archivés puis restaurés sur cible jetable, **6/6 empreintes identiques** | zip `1D3C8C6E93BA8908` |

**Qualification honnête de T2** : la restauration lit le **montage** `G:\` — elle prouve que l'archive écrite sur le chemin hors-machine est complète, vérifiée et restaurable ; elle ne prouve pas que les octets ont atteint les serveurs Google (cache DriveFS). C'est le même montage que celui utilisé quotidiennement par l'archivage des transcripts.

**Méthode — un faux négatif à connaître** : un comparateur qui retire le premier segment de chemin pour recoller « racine d'archive » et « racine source » produit de faux *manquants* dès qu'il y a des sous-dossiers (96 fichiers → 84 « identiques » + 12 « manquants » alors que l'archive en contenait bien 96). L'archive est construite avec `<src>\*` : **la racine de l'archive est la racine de la source, la comparaison est directe**.

---

## 4. Procédures de restauration

**F1 — mémoire de lane** (local) :
```powershell
7z x -y "-oD:\restauration\memoire" "D:\dev\backups\po2025-roo-extensions\<date>\memoire-lane-<date>.7z"
# recopier vers l'emplacement cible, puis comparer fichier par fichier (sha256)
```

**F1 — hors-machine** : identique en lisant l'archive sur `G:\Mon Drive\Backups-Cloud\po2025-roo-extensions\<date>\`.

**F4 — définitions de tâches** (là où l'orchestration doit être reconstruite) :
```powershell
Register-ScheduledTask -TaskName "<nom>" -Xml (Get-Content "<...>\<nom>.xml" -Raw)
# échec attendu en non-élevé pour une tâche RunLevel=Highest : passer par une fenêtre UAC
```

**F7 — lanceurs cachés** : copier `Claude-ApprovalStallDetector.vbs` vers `%LOCALAPPDATA%\claude-hidden-launchers\`, et les 6 fichiers de la lane (`.vbs` + `.orig.json` de `Claude-DashboardListener`, `Claude-MetaAudit`, `Vibe-Worker`) vers `C:\ProgramData\claude-hidden-launchers\`. **F4 sans F7 ne restaure pas le service** : la tâche se déclenche et meurt sur un fichier absent — 3 des 7 tâches de cette lane (DashboardListener, MetaAudit, Vibe-Worker) sont exactement dans ce cas.

**F3 — `.env` RSM du submodule** (le seul secret qui a une chaîne) :
```powershell
powershell -ExecutionPolicy Bypass -File scripts\mcp\backup-mcp-env.ps1    # primaire + snapshot + blob offsite
powershell -ExecutionPolicy Bypass -File scripts\mcp\restore-mcp-env.ps1 -VerifyVars
```
`restore-mcp-env.ps1` écrit dans le **working tree** (`mcps/internal/servers/roo-state-manager/.env`) et **no-op** si le fichier est présent et non vide (sauf `-Force`) : ne jamais le tester en réel sur un `.env` vivant — tester en bac à sable (`USERPROFILE` détourné + faux dépôt, recette de T4).

**F3 — autres secrets** : canal **local uniquement** à ce stade. Hors-machine subordonné à une décision user (escrow chiffré) — §5.

---

## 5. Écarts connus et itérations suivantes

1. **F2 — aucun canal de restauration aujourd'hui.** La qualification H1 du volet harnais (commentaire du 20/10 sur #126) établit le contraire de ce qui circulait : aucune charge `~/.claude.json` ni définition de tâche n'a jamais été publiée sur le Drive, et `latest.json` n'est qu'un instantané masqué **de comparaison**. L'aller-retour de restauration de `~/.claude.json` / `settings.json` n'existe donc **pas** — inventaire H1 attendu le 22/10, définitions de tâches le 03/11. **Correction assumée** : la première rédaction de ce document citait `roosync_config` comme canal de restauration sur la foi d'un propos antérieur ; la mesure firsthand l'a démenti, la ligne est corrigée avant merge.
2. **F3 — `.env` RSM : trou mesuré, réparé et testé le 20/10 ; le reste des secrets ne survit pas à une perte matérielle.**
   - **Mesuré avant réparation** : `.env` vivant **3 646 o** (mtime 15/10) ; **primaire absent** (`~/.roo-state-manager/.env` n'existait pas) ; **aucun snapshot** ; blob offsite **350 o figé au 06/10**, empreinte différente de la source. `restore-mcp-env.ps1` — la voie bootstrap née de l'incident web1 — aurait donc restauré un fichier **périmé et dix fois plus petit**. Réparé avec l'outil de la flotte (`backup-mcp-env.ps1`) : primaire + snapshot + blob à **3 646 o**, empreintes identiques (T4).
   - **Reste ouvert** : le `.env` du checkout, `.env.pre-vllm-rotation-20260930` et `stall-detector.env` n'ont **aucun** canal hors-machine — délibéré tant que l'escrow chiffré n'est pas tranché au niveau flotte. La copie locale protège d'un effacement accidentel, **pas** d'une mort de disque.
   - **Contexte flotte (RAPPORTÉ, non re-vérifié ici)** : le déclencheur de `backup-mcp-env.ps1` n'est branché nulle part, et le blob en clair sur le Drive est un design #2772 à re-qualifier par le pilote.
3. **F5 (état Vibe/Zoo)** : canal à trancher par le pilote — arbitrer entre « régénérable, pas de copie » et « coûteux à reconstruire, copie hebdomadaire ».
4. **Automatisation : organe mutualisé ARMÉ.** La convention flotte a été fixée le 23/10 par `po-2027:roo-extensions` (`G:\...\RooSync\<lane>-backups\daily\`, rotation bornée + manifeste sha256 + garde anti-archive-vide) et livrée en **PR [#4328](https://github.com/jsboige/roo-extensions/pull/4328)** (**mergée `c44fe571` le 24/10** — `scripts/claude/backup-lane-essentials.ps1`, paramétrable). **Ce plan s'y aligne au lieu d'écrire un second organe.** Premier run vérifié le 23/10 (§6). **Tâche `Claude-Backup-NonGit` armée le 24/10** au merge de l'organe : quotidienne 04:57 (ancrée 02:57Z ; 03:57 loc après bascule heure d'hiver 25/10 — hors des fenêtres 04:17/04:41), `RunLevel=Limited` non élevée, `StartWhenAvailable`, `LogonType Interactive` (**volontaire** : `G:` est un montage DriveFS par session, un tir sans session n'aurait pas de cible), limite 20 min, paramètres de lane explicites dont `-LaneLabel 'myia-po-2025:roo-extensions'`. **Premier run via la tâche vérifié** : `LastTaskResult=0`, archive 653 697 o sha256 `B0C94E62F95DC517…`, manifeste par archive `manifest-20261024-032555.txt` + étiquette de lane correcte. Le dossier `po2025-roo-extensions` suit désormais cette convention.
5. **Volet `.env` déjà couvert ailleurs** : la lane `po-2023:roo-extensions` a testé la restauration `.env` MCP par le script réel `restore-mcp-env.ps1` en bac à sable, et relevé deux écarts (aucun déclencheur branché sur `backup-mcp-env.ps1` ; blob offsite en clair sur GDrive). **Ne pas refaire** — à reprendre par le pilote.
6. **Suivi (itération 4)** : ce document est relu à chaque test de restauration ; un test qui échoue **rouvre** le plan au lieu d'être contourné.
7. **Correction assumée (itération 4, avant merge)** : la première rédaction ne connaissait que le répertoire lanceur `%LOCALAPPDATA%` (1 fichier). La vérification périmètre du 20/10 soir — déclenchée par l'incident GDriveFS du cycle (la tâche `GDriveFS-Watchdog` pointait elle-même dans `C:\ProgramData\claude-hidden-launchers\`) — a révélé que **3 des 7 tâches de la lane pointent dans ce second répertoire**, absent de l'inventaire initial : sans la correction, la restauration de F4 aurait laissé DashboardListener, MetaAudit et Vibe-Worker mortes au premier déclencheur. F7 couvre désormais les deux répertoires (test T5), et F4 précise son périmètre (7 des 19 tâches de la machine).

---

## 6. Itération 5 (2026-10-23) — organe mutualisé, premier run vérifié

**Mandat :** user 23/10 soir (« Absolument tout doit être backupé sur GDrive […] **backup de ce qui compte** »), relayé par le siège `myia-ai-01:hermes-agent` le 23/10 22:58Z.

**Organe :** `scripts/claude/backup-lane-essentials.ps1` — **PR [#4328](https://github.com/jsboige/roo-extensions/pull/4328)** (`po-2027:roo-extensions`), paramétrable (`-TargetRoot`, `-MemoryDir`, `-RsmEnvFile`, `-LocalNotes`, `-Keep`). Rotation sur fichiers nommés, manifeste sha256 par fichier, garde anti-archive-vide (<1 Ko / <3 fichiers — le piège mesuré du 23/10), `-WhatIf` propre, ne jamais imprimer de valeur secrète. **Aucun second organe écrit par cette lane.**

**Premier run vérifié — 2026-10-23T23:22:25Z**

| Mesure | Valeur |
|---|---|
| Cible | `G:\Mon Drive\Synchronisation\RooSync\po2025-roo-extensions-backups\daily\lane-essentials-20261023-232225.zip` |
| Contenu | **99 entrées** — 97 fichiers de mémoire de lane (dont `_archives/`) + `CLAUDE.local.md` (1 237 o) + `rsm-server.env` (3 851 o) |
| Taille / empreinte | **651 658 o** · sha256 `1A64B3C1FBFFD8E1…` — **relue indépendamment** (ouverture du zip), identique à la sortie du script |
| Registres critiques présents | `MEMORY.md` 17 079 o · `user-question-registry.md` 35 595 o · `outcome-mandates.md` 23 255 o |
| Dry-run préalable | `-WhatIf` exit 0 — 99 sources résolues, aucune écriture |
| Rotation | keep 14, 0 élaguée (première archive) |

**Couverture honnête de ce run** : F1 (mémoire de lane) ✅ · volet F3 `.env` RSM ✅ · notes locales ✅. **Non couvert par cet organe** : F4 (définitions de tâches, 11,8 Ko d'XML), F7 (lanceurs cachés — sans eux une tâche restaurée meurt au premier déclencheur), F5 (état Vibe), F2 (niveau machine, porté par la lane harnais). Ces familles restent sur les canaux T1/T2 du §2 : le backup n'est donc pas « complet », il est **borné et nommé**.

**Cadence** : quotidienne **armée le 2026-10-24** — #4328 mergée (`c44fe571`), tâche `Claude-Backup-NonGit` posée et prouvée (§5.4 : premier run via la tâche `LastTaskResult=0`, sha256 `B0C94E62…`, manifeste `lane: myia-po-2025:roo-extensions`).

**Note de méthode** : le premier run (23/10) a été exécuté depuis le contenu de la branche de PR (lue intégralement avant exécution, `-WhatIf` d'abord), pour ne pas bloquer sur un merge ; la bascule sur le chemin canonique s'est faite au merge (24/10) avec ré-armement complet — dry-run `-WhatIf` exit 0 (99 sources), assemblage de la tâche montré avant enregistrement (discipline UAC), enregistrement, puis exécution manuelle de contrôle.
