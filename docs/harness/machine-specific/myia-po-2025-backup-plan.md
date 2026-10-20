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
| **F4** | Définitions de tâches planifiées | **7 tâches** = 11,8 Ko d'XML : `Claude-ApprovalStallDetector`, `Claude-DashboardListener`, `ClaudeTranscriptArchive`, `Claude-MetaAudit`, `Vibe-Feeder`, `Vibe-Worker`, `roo-rotate-scheduling-logs` (6 en `RunLevel=Limited`, 1 en `Highest`) | critique — l'orchestration OS meurt avec | local **+ hors-machine** (7z, avec F7) |
| **F5** | État Vibe/Zoo hors git | `outputs/vibe/feeder-queue.json` 343,6 Ko (+ `outputs/scheduling/logs/`) — `/outputs/` gitignoré (`.gitignore:250`) | moyenne — état partiellement régénérable | local ; hors-machine **à trancher par le pilote** |
| **F6** | Extension zoo forkée (installée) | `~/.vscode/extensions/jsboige.zoo-scheduler-0.0.11-zoo.4` — 72 f / 7 130,5 Ko | **faible — reconstructible** : source trackée (`zoo-code/`, `scripts/zoo-scheduler`) ; les `.vsix` sous `outputs/` sont gitignorés | source git = canal ; pas de copie dédiée |
| **F7** | Lanceurs cachés | `%LOCALAPPDATA%\claude-hidden-launchers\` — 1 f / 603 o (`Claude-ApprovalStallDetector.vbs`) | critique — **une tâche restaurée sans son lanceur ne fait rien** (§4) | lié à F4 : même archive |
| — | Transcripts de session | `~/.claude/projects/d--dev-roo-extensions/` complet = **385 f / 644 728 Ko** | — | canal existant : tâche `ClaudeTranscriptArchive` (quotidien 04:41, 7z → GDrive) ; **RX46 : purge interdite** |

F1, F4, F5 et F7 sont **propres à cette lane**. F2 est **au niveau machine** (partagée avec `po-2025:CoursIA`) — son volet est porté par la lane harnais, pas dupliqué ici.

---

## 2. Canaux, cadence, rétention

**T1 — local** : `D:\dev\backups\po2025-roo-extensions\<AAAAMMJJ>\` — une archive par famille + manifeste. Hors dépôt, jamais dans git.

**T2 — hors-machine** : `G:\Mon Drive\Backups-Cloud\po2025-roo-extensions\<AAAAMMJJ>\` — **même doctrine que les transcripts** ([`claude-transcript-archiving.md`](../reference/claude-transcript-archiving.md)) : archive unique `.7z`, vérifiée par `7z t`, **jamais d'arbre brut** sur DriveFS. Familles éligibles : F1, F4+F7 (vérifiées sans motif secret). Créneau hebdomadaire décalé (dimanche), pour ne pas se disputer la fenêtre d'upload avec les tâches 04:17 / 04:41.

**Cadence proposée** : T1 quotidien · T2 hebdomadaire · rétention 7 quotidiennes + 4 hebdomadaires, purge des plus anciennes au-delà.

**Interdit** : F3 sur T2, et `D:\dev\backups` ne doit jamais être placé dans un dossier synchronisé.

**Automatisation : non armée à ce stade** (aucune tâche `Claude-Backup-NonGit`). Voir §5 — l'écart est nommé, pas masqué.

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

**F7 — lanceur caché** : copier `Claude-ApprovalStallDetector.vbs` vers `%LOCALAPPDATA%\claude-hidden-launchers\`. **F4 sans F7 ne restaure pas le service** : la tâche se déclenche et meurt sur un fichier absent.

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
4. **Automatisation non armée.** Tant qu'aucune tâche ne capture, ce plan tient par des gestes manuels. À armer en tâche `Claude-Backup-NonGit` (`RunLevel=Limited`, non élevée) **dès que le pilote a fixé la convention flotte** — pour éviter sept conventions divergentes. Le nom du dossier hors-machine (`po2025-roo-extensions`) est une **proposition de lane**, à aligner sur cette convention.
5. **Volet `.env` déjà couvert ailleurs** : la lane `po-2023:roo-extensions` a testé la restauration `.env` MCP par le script réel `restore-mcp-env.ps1` en bac à sable, et relevé deux écarts (aucun déclencheur branché sur `backup-mcp-env.ps1` ; blob offsite en clair sur GDrive). **Ne pas refaire** — à reprendre par le pilote.
6. **Suivi (itération 4)** : ce document est relu à chaque test de restauration ; un test qui échoue **rouvre** le plan au lieu d'être contourné.