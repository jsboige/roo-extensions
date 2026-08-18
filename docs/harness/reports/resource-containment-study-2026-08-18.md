# Étude #3156 — Contenir l'empreinte ressources des instances Claude Code

**Issue :** [#3156](https://github.com/jsboige/roo-extensions/issues/3156) (réveil étude #464)
**Date :** 2026-08-18 (mesures ai-01 ~01:30–02:30 local)
**Auteur :** myia-ai-01 (coordinateur), session interactive
**Statut :** PROPOSITION DE DÉCISION — requiert arbitrage user (directive 18/08)
**Qualification :** tout chiffre ci-dessous est **VERIFIE** sur ai-01 à l'heure indiquée, sauf mention contraire (RAPPORTE/SUPPOSE).

---

## 1. Résumé exécutif

1. **Le poste dominant n'est ni VS Code ni le terminal — c'est le serveur MCP `roo-state-manager` (RSM), un par session Claude Code.** Re-mesuré ce jour : 33 instances / **37,2 GB** (moyenne 1,15 GB, max 2,6 GB) contre 141 process `Code.exe` / 28,0 GB. Confirme la mesure du 17/08 23:12Z (31 instances / 45,3 GB).
2. **Le POC monter-G:-dans-Docker échoue sur ai-01** : au-delà de ~3 niveaux, l'arborescence DriveFS apparaît **vide ou tronquée** à travers le bind mount (0/47 entrées, opens → ENOENT), stable sur conteneurs neufs, retries, et via junction. **La précondition de l'option A (A') ne tient pas aujourd'hui.**
3. **Le « précédent nanoclaw » cité dans #3156 n'existe pas en prod** : le conteneur nanoclaw réellement en exécution ne monte AUCUN chemin G:, et `docs/nanoclaw/docker-compose.yml` référence `G:/roosync` — chemin inexistant sur ce host.
4. **Cascade #1379 tranchée pour ai-01 : option A = NO-GO** (double disqualifiant : mount cassé + dépendance commune WSL/Docker dont le protocole documente le kill simultané de toutes les fenêtres).
5. **Trois leviers natifs, sans conteneur et sans toucher au workflow fenêtre↔workspace↔Peacock** : hygiène des sessions idle (~17 GB récupérables sur ai-01 immédiatement), plafond heap par instance RSM, Job Objects Windows pour les sessions schedulées (suite structurelle déjà identifiée #2675/#2676).
6. **Option B (CLI terminal) rejetée par les données** : la masse est dans RSM + sessions idle, pas dans le shell ; migrer en CLI conserverait N×RSM et casserait le mapping fenêtre/couleur.

---

## 2. Baseline ai-01 (VERIFIE, 2026-08-18 ~01:30)

| poste | process | RAM |
|---|---|---|
| `Code.exe` (tous) | 141 | **27,95 GB** |
| serveurs `roo-state-manager` | **33** | **37,2 GB** (min 0,4 / moy 1,15 / max 2,62) |
| `claude.exe` (toutes = sessions extension VS Code) | 22 | 7,36 GB |
| DriveFS (`GoogleDriveFS`) | 2 | 0,42 GB |
| RAM machine | — | 72,3 GB libres / 191,8 GB |

Réseau de processus par session Claude Code (VERIFIE via `Win32_Process` parents) :

```
claude.exe (~300 MB, extension VS Code)  →  node.exe (runtime claude)  →  node.exe RSM (~1,1 GB, stdio)
```

Cohortes de démarrage RSM : **13 instances du 08-14** (4 jours) · 2 du 08-15 · 2 du 08-16 · 15 du 17/08 18:26–27 (salve executor) · 2 du 18/08 · 1 parent mort (0 MB).

Les 22 `claude.exe` sont **toutes** des sessions de l'extension VS Code (chemin `.vscode\extensions\anthropic.claude-code-2.1.23x\...\claude.exe`), dont **12 démarrées le 08-14 05:29–06:35 toujours vivantes** → ~17 GB immobilisés par des sessions panels jamais fermées (≈ 4 GB de claude.exe + ≈ 13 GB de RSM enfants).

## 3. POC — G: (DriveFS) depuis un conteneur Docker : ÉCHEC (VERIFIE)

Environnement : Docker Desktop 29.7.2 (backend WSL2), host ai-01, 2026-08-18 ~01:40–02:00.

| # | test | résultat |
|---|---|---|
| 1 | `-v "G:\Mon Drive\...\ .shared-state:/mnt/shared:ro"` | montage **silencieusement vide** (0 entrées ; host : 47) |
| 2 | `-v "G:\:/mnt/g:ro"` puis parcours | racine OK (`Mon Drive`), niveaux 1–3 OK, `.shared-state` → **0/47 entrées**, `MyIA` → **1/37 entrées** |
| 3 | open direct de fichiers connus (`DASHBOARD.md`, 2 messages inbox) | **FileNotFoundError** ×2 essais chacun |
| 4 | stabilité | identique sur 3 conteneurs neufs, retries, délais ≥5 s |
| 5 | contournement junction (`D:\...\glink` → G: path) monté | **même échec** (0 entrées, open ENOENT) |
| 6 | mount source `G:\Mon Drive` (racine différente) | **même échec** sur les mêmes chemins |
| 7 | WSL | `G:` non monté par défaut dans Ubuntu (`/mnt/g` absent) |
| 8 | contrôle `D:\` (incl. répertoits pointés `.dotdir`) | **fonctionne** — le problème est spécifique aux chemins DriveFS profonds |

Cause racine **non diagnostiquée** (grpc-fuse vs provider DriveFS) — seul le comportement est établi, reproductible. Conséquence : la question « le mount container est-il au prix du DriveFS natif ? » est sans objet — **le mount ne deliver pas les données du tout**.

### Vérification du « précédent nanoclaw »

- `docker inspect nanoclaw-v2-telegram_main-…` (conteneur en prod sur ai-01) : **aucun montage G:** — uniquement `D:\nanoclaw\…` et fichiers tmp.
- `docs/nanoclaw/docker-compose.yml:49` monte `G:/roosync` — **chemin inexistant** sur ce host (l'état partagé réel est `G:\Mon Drive\Synchronisation\RooSync\.shared-state`).
- Conclusion : l'affirmation « l'accès G: depuis un container Docker fonctionne (NanoClaw en prod depuis des mois) » est **réfutée pour l'état actuel**. Le compose des docs n'est pas ce qui tourne.

## 4. Cascade #1379 — tranché pour ai-01

Même si le mount fonctionnait : containeriser les fenêtres rend **toutes** les fenêtres dépendantes d'un même WSL2/Docker VM. Le protocole `wsl-docker-cascade-protocol.md` documente le pattern observé (#1379, 2026-04-14) : kill sélectif de tout `Code.exe` tenant des pipes WSL cassés — « Node MCP processes survived » — sans reboot, récupération manuelle. Sur la machine qui porte coordinateur + conteneurs (vLLM, nanoclaw, claudish), **aggraver volontairement cette classe d'incident est disqualifiant**. ai-01 est la machine où l'option A est le plus dangereuse — c'est aussi celle où la précondition mount vient d'échouer. Double NO-GO.

## 5. Options A / A' / B — évaluation

| | A (fenêtres dev containers) | A' (headless conteneurisés) | B (CLI terminal) |
|---|---|---|---|
| Précondition G: mount | **ÉCHEC** (§3) | **ÉCHEC** (même mécanisme, RSM dans le conteneur) | n/a (RSM reste host-side) |
| Cascade #1379 | NO-GO ai-01 (§4) | neutre (fenêtres natives) | neutre |
| Attaque le poste dominant (RSM 37 GB) | oui, par effet de bord (mem_limit borne RSM) | partiellement | **non** — N×RSM conservé |
| Workflow user (fenêtre↔Peacock) | préservé en théorie (UI extensions host-side — non testé, moot) | préservé (fenêtres intactes) | **cassé** |
| Verdict | **NO-GO aujourd'hui** | **différé** — à rouvrir post-#3151 Phase B | **rejeté** |

Ce qui changerait le verdict A/A' : (1) store PG (#2427/#3151 Phase B) supprimant la dépendance G: des lectures RSM — le mount devient inutile ; (2) ou diagnostic+fix du mount (drvfs manuel en mode privileged = exotique, non recommandé) ; (3) transport HTTP partagé pour RSM (1 instance/machine) — n'existe pas aujourd'hui (`StdioServerTransport` seul, `src/index.ts:33`).

## 6. Leviers natifs recommandés (ordonnés)

1. **Hygiène des sessions idle** — les 12 panels démarrés le 08-14 et jamais fermés immobilisent ~17 GB sur ai-01. Fermeture manuelle ou reaper basé sur l'âge d'inactivité. ⚠️ Classe distincte des zombies #2675 : ici les parents sont **vivants** — le script `cleanup-mcp-stdio-zombies.ps1` (parents morts) ne mord pas. Coût ≈ 0.
2. **Plafond heap par instance RSM** — `NODE_OPTIONS=--max-old-space-size=768` dans l'env du serveur MCP (`~/.claude.json` → `mcpServers.roo-state-manager.env`). À l'échelle actuelle : 33 × ~0,8 GB au lieu de 37 GB. **POC requis sur une session** : RSM a une garde mémoire à 1,5 GB heap (background-services.ts:369) qui suggère des pics d'indexation — risque OOM-crash à borner trop bas. La croissance avec l'âge (12 instances J-4 ≈ 1,4 GB moy) indique une rétention qui ne se libère pas — le cap force le GC au lieu de laisser croître.
3. **Job Objects Windows pour les sessions schedulées** (`claude -p`, worker, listener) — bornage mémoire natif par arbre de processus, sans Docker, sans cascade, sans mount. Déjà identifié comme suite structurelle dans #2675/#2676 (« Job Object wrapper gated post-slowdown ») : #3156 fournit la motivation ressource pour débloquer ce follow-up.
4. **Structurel (moyen terme)** — transport HTTP partagé RSM (33→1 instance/machine) et/ou aboutissement du store PG. Change complètement l'économie : c'est la trajectoire déjà engagée (#3151 Phase A mergée côté submod).

Les leviers 1–3 ne touchent ni aux fenêtres, ni à Peacock, ni au mapping workspace — la contrainte non négociable est respectée par construction.

## 7. Reproduction

Baseline (toute machine — déjà en commentaire #3156) :

```powershell
$srv = Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
       Where-Object { $_.CommandLine -like '*roo-state-manager*index.js*' }
$mem = ($srv | ForEach-Object { Get-Process -Id $_.ProcessId -EA SilentlyContinue } | Measure-Object WorkingSet64 -Sum).Sum
"RSM instances : $($srv.Count) — RAM : $([math]::Round($mem/1GB,2)) GB"
```

POC mount (ai-01) :

```bash
docker run --rm -v "G:\:/mnt/g:ro" python:3-slim python -c "
import os; p='/mnt/g/Mon Drive/Synchronisation/RooSync/.shared-state'
print(len(os.listdir(p)), 'entries — attendu 47 côté host')"
```

Chaîne parentale RSM / classification sessions : voir `Win32_Process` ParentProcessId (scripts de mesure jetables : `D:\temp-poc-3156\step*.ps1`, non versionnés).

## 8. Ce que cette étude n'affirme pas

- Pas de preuve causale entre les 33 instances RSM et les timeouts MCP constatés le 17/08 (corrélation mesurée, déjà qualifiée dans le commentaire baseline).
- Cause racine du mount vide non diagnostiquée (comportement seul établi).
- La décomposition par fenêtre VS Code (96 process « main » détectés, cmdline tronquée → décompte non fiable) n'est pas chiffrée ; le chiffre utile est le total 141/28 GB.
- po-204 : la mesure « 64 Code.exe / 7 GB / 0,6 GB libres » (motivation initiale de #3156) n'incluait **pas** le recensement RSM — même requalification nécessaire sur cette machine (dispatch coordo déjà parti le 17/08).

---

## 9. Décision proposée (arbitrage user)

| question | proposition |
|---|---|
| Option A sur ai-01 | **NO-GO** (mount G: cassé §3 + cascade §4) |
| Option A' | **différée** jusqu'à #3151 Phase B (PG store) ou fix du mount — réévaluer alors |
| Option B | **rejetée** (n'attaque pas le poste dominant, casse le workflow) |
| Action immédiate | leviers 1–3 (hygiène sessions, cap heap POC, Job Objects POC) — aucun changement de workflow user |
| Ré-ouverture conteneurs | conditionnée à : store PG opérationnel ET protocole de réponse cascade durci |

## Références

- #3156 (étude) · #464 (étude d'origine, fermée 02/2026) · #2992 (OOM ai-01) · #1379 (cascade WSL/Docker + protocole) · #2675/#2676 (zombies MCP stdio + Job Object wrapper) · #2427/#3151 (store PG) · #2532 (croissance sessions) · #3150 (mailbox 45k fichiers)
- Commentaire baseline ai-01 du 17/08 23:12Z sur #3156 (mesure initiale 31 instances / 45,3 GB)
