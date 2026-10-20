# Plan de sauvegarde — lane myia-po-2023:roo-extensions

**Version:** 1.0.0 (inventaire + tests de restauration, 2026-10-20)
**Issue :** Maintenance#126 (mandat user 2026-10-20 : « un plan de sauvegarde des configs et de tout ce qui n'est pas sous git… suivi de long terme avec tests de restauration »)
**Portée :** siège `myia-po-2023:roo-extensions` uniquement. Les volets harnais global et flotte sont portés par `myia-ai-01:roo-extensions` (commentaire #126 du 20/10 11:06Z).

---

## 1. Inventaire — famille × canal × test (mesuré 2026-10-20 13:11–13:20)

| Famille | Données (mesure) | Canal actuel | Test de restauration |
|---|---|---|---|
| **Harnais** | `~/.claude/rules/**`, `CLAUDE.md` global, settings canon | **git** (roo-extensions) + `Deploy-GlobalConfig.ps1` — exercé le 20/10 (19 fichiers redéployés, c.591) | ✅ canal exercé en réel le 20/10 (redistribution) |
| **Secrets MCP** | `mcps/internal/servers/roo-state-manager/.env` (5 201 o) | `scripts/mcp/backup-mcp-env.ps1` → primaire local hors-git `~/.roo-state-manager/.env` + 10 snapshots + blob offsite `<shared>/mcp-env/myia-po-2023.env` ; restore par `scripts/mcp/restore-mcp-env.ps1` (bootstrap-safe) | ✅ **PASS 20/10 13:20** — script réel en bac à sable, octet-pour-octet (voir §3) |
| **Jeton stall-detector (RX110)** | `~/.roo-state-manager/stall-detector.env` (228 o) | aucun backup — **reconstruction par re-propagation** (procédure RX110 du 20/10, message autodestructeur + PJ) | n/a par conception (jeton re-émis, pas restauré) |
| **Mémoire de lane** | `~/.claude/projects/d--Dev-roo-extensions/memory/**` — 116 fichiers / 720,3 Ko | **aucun canal** — vérifié : `backup-claude-transcripts.ps1:162` ne prend que `-Filter *.jsonl`, les `*.md` de `memory/` ne sont couverts par rien | ✅ **PASS 20/10 13:20** — archive ZIP (376,8 Ko) → extraction → 116/116 empreintes sha256 identiques (voir §3) |
| **Orchestration OS** | 10 tâches `Claude-*` (StallDetector, TranscriptArchive, DashboardListener…) + launchers VBS cachés | launchers **générés par `harden-hidden-tasks.ps1`** (sous git) ; **définitions XML : aucun canal** — volet H2 d'ai-01 (outil d'export XML, échéance 03/11) | à venir avec H2 — pas de duplication ici |
| **Configs applicatives** | `~/.claude.json` (87,7 Ko), `~/.claude/settings.json` (6 180 o) | pas de canal réel (settings : instantané masqué de comparaison seulement) — volet H3 d'ai-01 (proposition 27/10) | à venir avec H3 |
| **Crons de session** | cron `ae15e7e1` (`41 */4`) | **session-only** — meurt avec la session ; ce n'est pas une donnée mais un état reconstruit (procédure du skill `/executor`, Phase 0 étape 6) | n/a |
| **Données de service RSM** | Qdrant (vecteurs), skeletons, `tier3-stub-snapshot.json` (36 Mo) | régénérables (réindexation) — pas de sauvegarde | n/a |

## 2. Écarts trouvés (mesurés, pas supposés)

1. **`backup-mcp-env.ps1` n'est branché sur aucun déclencheur** — ni tâche planifiée, ni appelant dans le dépôt (grep 20/10 : seules auto-références + 1 mention doc dans `set-mcp-env-var.ps1`). Conséquence mesurée : backup primaire daté 20/10 02:20 pour un `.env` modifié à 02:58, blob offsite daté **06/10 (14 jours de retard)** alors que les blobs web2 (20/10 13:17) et ai-01 (20/10 09:17) étaient frais le jour même. **Atténué ce cycle** : exécution manuelle du script — primaire, snapshot `.env.bak.20261020-131937` et blob offsite rafraîchis (13:19). **Reste : la périodicité (P1).**
2. **Mémoire de lane : zéro canal** — corroboré par lecture du code, pas par oui-dire (cf. tableau).
3. **Blob offsite `.env` = secrets en clair sur GDrive** — design assumé de #2772 (bootstrap-safe : le chemin GDrive vit DANS le `.env`). Court-circuite la doctrine #53 « pas de secrets en clair sur GDrive », consciemment (commentaire du script). À re-qualifier par le pilote, pas un incident.

## 3. Tests de restauration (datés, méthode reproductible)

**Méthode commune :** bac à sable jetable, aucune écriture sur les données vivantes, secrets jamais affichés (empreintes seules).

### Test A — `.env` MCP (20/10 13:20:11)

- Copie jetable de `restore-mcp-env.ps1` dans un faux repo, `USERPROFILE` détourné vers un faux home contenant une copie du backup primaire frais.
- Exécution réelle : `restore-mcp-env.ps1 -Force -VerifyVars` → **exit 0**.
- Empreintes : source vivante = backup primaire = fichier restauré = `33E8FE689DC6631C…` (sha256, 16 premiers caractères).
- Sortie : `OK .env restaure depuis <backup primaire>` + `OK vars dures presentes`.
- **Verdict : PASS** — le canal restaure l'état courant octet-pour-octet, y compris les vars requises (`ROOSYNC_SHARED_PATH`, `ROOSYNC_MACHINE_ID`, clé d'embeddings).

### Test B — mémoire de lane (20/10 13:20:15)

- `Compress-Archive` du dossier `memory/` → `lane-memory-20261020.zip` (376,8 Ko) → `Expand-Archive` vers cible jetable.
- Comparaison intégrale : manifeste sha256 des 116 fichiers source vs extraits.
- **Verdict : PASS — 116/116 empreintes identiques, 0 écart.**
- Limite documentée : prouve le canal « archive » (ZIP) ; le canal de production n'existe pas encore (P2). Une archive ZIP **non chiffrée** contenant la mémoire passera par le canal générique #53 (7z chiffré) — ne pas la déposer en clair sur GDrive.

## 4. Plan

| # | Action | Quand | Qui |
|---|---|---|---|
| **P1** | Brancher `backup-mcp-env.ps1` en périodique (quotidien, tâche utilisateur non élevée) **ou** l'appeler depuis `executor-preflight.ps1` | proposition au pilote ; à trancher avec le canal générique | po-2023, arbitrage pilote |
| **P2** | Mémoire de lane → canal générique #53 (archives 7z chiffrées) ; d'ici là, recette R2 ci-dessous | suit la décision pilote #53 | pilote + po-2023 |
| **P3** | `stall-detector.env` : RIEN à prévoir — la reconstruction (RX110) est le canal par conception | — | — |
| **P4** | Vérifier à chaque fin de trimestre que le test A passe (le canal .env est le seul à porter des secrets irrécupérables) | trimestriel | po-2023 |

Alignements : H2 (XML tâches planifiées, 03/11) et H3 (`~/.claude.json`, proposition 27/10) sont portés par ai-01:roo-extensions — ce plan ne les duplique pas.

## 5. Recettes de restauration (testées)

- **R1 — `.env` MCP perdu :**
  `powershell.exe -ExecutionPolicy Bypass -File scripts/mcp/restore-mcp-env.ps1 -VerifyVars`
  (no-op si présent ; `-Force` pour écraser ; échec bruyant exit 1 si aucun backup local — re-propagation manuelle requise).
- **R2 — mémoire de lane perdue :** restaurer l'archive la plus récente dans `~/.claude/projects/d--Dev-roo-extensions/memory/`, puis contrôler par empreintes : `Get-ChildItem -Recurse -File | Get-FileHash -Algorithm SHA256` comparé au manifeste. Ne jamais écraser sans comparaison préalable si des fichiers existent.
- **R3 — rafraîchir le backup `.env` :** `powershell.exe -ExecutionPolicy Bypass -File scripts/mcp/backup-mcp-env.ps1` (primaire + snapshot rotatif + offsite best-effort).

---

**Preuves :** rapport de test horodaté `restore-test-report.txt` (scratchpad de session du 20/10, jetable — les verdicts et empreintes sont recopiés ci-dessus, le document est auto-suffisant).