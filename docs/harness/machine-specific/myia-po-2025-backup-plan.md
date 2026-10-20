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
| **F2** | Config harnais machine | `~/.claude.json` 82,4 Ko · `~/.claude/settings.json` 4,1 Ko · `keybindings.json` 0,3 Ko · `~/.claude/rules/` 4 f / 8,6 Ko | critique | `roosync_config` (canal de **restauration**, qualifié au niveau flotte — voir §5) |
| **F3** | Secrets locaux | `.env` 584 o · `.env.pre-vllm-rotation-20260930` 499 o · `~/.roo-state-manager/stall-detector.env` 228 o | critique | **local seul** — hors-machine interdit sans décision user (§5) |
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

**F3 — secrets** : canal **local uniquement** à ce stade. Hors-machine subordonné à une décision user (escrow chiffré) — §5.

---

## 5. Écarts connus et itérations suivantes

1. **F2 non testée par cette lane.** Le canal `roosync_config` a été qualifié comme canal de **restauration** au niveau flotte (volet harnais, commentaire sur #126) — **RAPPORTÉ, non re-vérifié ici** ; l'aller-retour de restauration de `~/.claude.json` / `settings.json` reste à tester par le volet harnais. Cette lane ne le duplique pas.
2. **F3 ne survit pas à une perte matérielle.** C'est l'écart principal du plan : les secrets n'ont **aucun** canal hors-machine, et c'est délibéré tant que la question de l'escrow chiffré n'est pas tranchée au niveau flotte. La copie locale protège d'un effacement accidentel, **pas** d'une mort de disque.
3. **F5 (état Vibe/Zoo)** : canal à trancher par le pilote — arbitrer entre « régénérable, pas de copie » et « coûteux à reconstruire, copie hebdomadaire ».
4. **Automatisation non armée.** Tant qu'aucune tâche ne capture, ce plan tient par des gestes manuels. À armer en tâche `Claude-Backup-NonGit` (`RunLevel=Limited`, non élevée) **dès que le pilote a fixé la convention flotte** — pour éviter sept conventions divergentes. Le nom du dossier hors-machine (`po2025-roo-extensions`) est une **proposition de lane**, à aligner sur cette convention.
5. **Volet `.env` déjà couvert ailleurs** : la lane `po-2023:roo-extensions` a testé la restauration `.env` MCP par le script réel `restore-mcp-env.ps1` en bac à sable, et relevé deux écarts (aucun déclencheur branché sur `backup-mcp-env.ps1` ; blob offsite en clair sur GDrive). **Ne pas refaire** — à reprendre par le pilote.
6. **Suivi (itération 4)** : ce document est relu à chaque test de restauration ; un test qui échoue **rouvre** le plan au lieu d'être contourné.