# Plan de sauvegarde hors-git — lane myia-po-2027:roo-extensions (Maintenance#126)

**Mandat :** user 20/10 — inventaire des données critiques hors-git par siège, plan,
tests de restauration datés, échéance **27/10**.
**Rédigé :** 2026-10-20 par la lane `myia-po-2027:roo-extensions` (mesures firsthand, ce siège).
**Périmètre :** ce qui ne vit dans **aucun dépôt git** — un `git clone` + `pull` ne le rend pas.

---

## 1. Inventaire mesuré (20/10/2026, lecture seule)

| # | Famille | Chemin (ce siège) | Mesure | Canal de sauvegarde existant |
|---|---------|-------------------|--------|------------------------------|
| 1 | Mémoire de lane | `~\.claude\projects\d--dev-roo-extensions\memory\` | 50 fichiers, 182 250 o | **AUCUN** (voir trou (c)) |
| 2 | Config harnais | `~\.claude.json` | 73 465 o | canon flotte (bloc `env` roster 9/9 conforme) |
| 3 | Config harnais | `~\.claude\settings.json` | 6 363 o | canon `claude-settings` (masqué) |
| 4 | Config harnais | `~\.claude\CLAUDE.md` + `~\.claude\rules\` | 19 029 o + 3 f / 6 818 o | source versionnée `roo-extensions/.claude/configs/` |
| 5 | Secret `.env` RSM | `mcps\internal\...\roo-state-manager\.env` (vivant) + `~\.roo-state-manager\` (copies) | 5 332 o, 23 clefs | `backup-mcp-env.ps1` — **réparé ce jour** (voir §2) |
| 6 | Définitions de tâches planifiées | `Get-ScheduledTask` | 6 tâches à nous (Claude-ApprovalStallDetector, Claude-DashboardListener, Claude-ListenerZombieWatchdog, ClaudeTranscriptArchive, roo-rotate-scheduling-logs, RooSync-Weekly-Seed) | **aucun canal automatisé** (export XML manuel) |
| 7 | Lanceurs cachés | `%LOCALAPPDATA%\claude-hidden-launchers\` | 1 fichier, 603 o | aucun — mais **indissociable** de la famille 6 (voir (e)) |
| 8 | Transcripts Claude Code | `~\.claude\projects\d--dev-roo-extensions\*.jsonl` | 33 fichiers, 223 280 Ko | `ClaudeTranscriptArchive` → `Backups-Cloud/claude-transcripts` |
| 9 | Extension Zoo forkée | `~\.vscode\extensions\zoocodeorganization.zoo-code-3.90.0\` | 161 370 Ko | reconstructible (source trackée) — priorité basse |
| 10 | Roster flotte | `~\.claude.json` `env.ROO_FLEET_ROSTER` + `.env` RSM | **9/9 des deux côtés** | conforme (ligne « reste à vérifier » du blocage flotte soldée) |

---

## 2. Trou réel mesuré et réparé — le `.env` RSM (20/10 13:33)

**Mesure avant** (hashes SHA256 firsthand) :

| Copie | Taille | Date | Verdict |
|---|---|---|---|
| `.env` vivant (submodule) | 5 332 o | 20/10 03:05 | source |
| backup primaire `~\.roo-state-manager\.env` | 2 969 o | **06/10** | **périmé, −44 %, hash ≠** |
| snapshots `.env.bak.*` | 2 931-2 971 o | **23/08** | périmés (2 mois) |
| blob cloud po-2027 | — | — | **absent** (`Backups-Cloud/` n'avait aucun dossier po-2027) |

Conséquence mesurée : un `restore-mcp-env.ps1` aurait restauré un fichier **périmé et
incomplet**, sans qu'aucune alarme ne le signale. Le déclencheur `backup-mcp-env.ps1`
n'est branché sur **aucun** cron/heartbeat — même constat que po-2023 et po-2025
(indépendamment).

**Réparation** (outil de la flotte, pas de geste ad hoc) :
`powershell -File scripts/mcp/backup-mcp-env.ps1` →

- primaire `~\.roo-state-manager\.env` (5 332 o, 20/10 13:33)
- snapshot `.env.bak.20261020-133339`
- blob offsite `G:\Mon Drive\Synchronisation\RooSync\.shared-state\mcp-env\myia-po-2027.env`

**4/4 identiques** (vivant = primaire = snapshot = blob), sha256 `F5A58FE3D3DEA693…`.

---

## 3. Tests de restauration datés — `20261020T113428Z` (cible jetable)

- **T1 — mémoire de lane** : `Compress-Archive` des 50 fichiers → archive 102,5 Ko →
  extraction → **50/50 empreintes SHA256 fichier par fichier identiques**.
- **T2 — `.env` RSM, script RÉEL `restore-mcp-env.ps1`** en bac à sable complet
  (faux repo + `USERPROFILE` détourné — le script écrit dans le working tree de son
  repo, jamais le vivant) : **exit 0**, 5 332 o restaurés, **identique octet-pour-octet**
  à la source, vars dures présentes (`ROOSYNC_SHARED_PATH`, `ROOSYNC_MACHINE_ID`,
  clé embeddings). Vivant vérifié intact après le test (hash inchangé).

Non testés (dits, pas sous-entendus) : restauration d'une **définition de tâche**
(XML), et le canal transcripts (existant, hors périmètre de ces 2 tests).

---

## 4. Constats pour le pilote (flotte)

- **(a) Déclencheur non branché** : `backup-mcp-env.ps1` n'a aucun déclencheur automatisé ;
  constaté gelé sur po-2023, po-2025 et po-2027 (réparés manuellement les 20/10). Si le
  pilote ne fixe pas une convention **unique**, chaque siège improvisera la sienne.
- **(b) `restore-mcp-env.ps1` écrit dans le working tree vivant** — tout test réel exige
  un bac à sable (faux repo + `USERPROFILE` détourné). Recette R2 ci-dessous.
- **(c) Mémoire de lane : 0 canal** — 50 f / 178 Ko ici. Le canal transcripts
  (`ClaudeTranscriptArchive`) filtre `*.jsonl` : la mémoire n'est pas dedans.
- **(d) Extension Zoo (158 Mo) reconstructible** depuis la source trackée — priorité basse.
- **(e) Une définition de tâche restaurée sans son lanceur `.vbs` ne fait rien** (leçon
  po-2025) — la famille 6 et la famille 7 se restaurent **ensemble**.

---

## 5. Recettes

| Id | Geste | Commande (depuis le checkout principal, jamais un worktree) |
|----|-------|------------------------------------------------------------|
| R1 | Backup `.env` RSM (après toute rotation de clé) | `powershell -File scripts/mcp/backup-mcp-env.ps1` |
| R2 | Restore `.env` (perte totale) — bootstrap-safe, ne dépend PAS de GDrive | `powershell -File scripts/mcp/restore-mcp-env.ps1 -VerifyVars` |
| R3 | Test de restauration (sans toucher le vivant) | faux repo + copie du script + `USERPROFILE` détourné (patron du T2) |
| R4 | Mémoire de lane (canal non automatisé) | `Compress-Archive` de `memory\` vers un support hors machine — convention à cadrer (constat (c)) |

---

**État :** inventaire mesuré · 1 trou réparé (preuve 4/4) · 2 tests datés PASS ·
roster 9/9. **Attend du pilote :** convention flotte pour (a) et (c).