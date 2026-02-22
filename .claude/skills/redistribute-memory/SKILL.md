---
name: redistribute-memory
description: Audite et redistribue les connaissances, règles et mémoires entre les niveaux de configuration Claude Code et Roo Code. Utilise ce skill quand CLAUDE.md est saturé, quand les règles sont mal placées, ou pour nettoyer la configuration. Phrase déclencheur : "/redistribute-memory", "redistribue la mémoire", "audite les règles", "nettoie CLAUDE.md".
metadata:
  author: "Roo Extensions Team"
  version: "2.0.0"
  compatibility:
    surfaces: ["claude-code", "claude.ai"]
    restrictions: "Requiert accès aux fichiers de configuration Claude/Roo"
---

# Skill : Redistribution Memoire & Regles

**Version:** 2.0.0 (2026-02-19)
**Usage:** `/redistribute-memory` ou "redistribue la memoire", "audite les regles", "nettoie CLAUDE.md"

Ce skill audite et redistribue les connaissances, regles et memoires entre les differents niveaux de configuration de Claude Code et Roo Code.

---

## Objectif

Les informations s'accumulent dans des fichiers qui ne sont pas toujours au bon niveau. Ce skill :
1. Inventorie tous les fichiers de memoire/regles/instructions
2. Analyse le contenu pour identifier les mauvais placements, doublons et saturation
3. Propose des deplacements/consolidations/creations de fichiers
4. Applique les changements apres validation utilisateur

**Seuils d'alerte :**
- `CLAUDE.md` (projet) > 500 lignes → EXTRAIRE des sections en rules
- `MEMORY.md` (auto) > 150 lignes → TRONQUE dans le system prompt, risque perte
- Rules individuels > 150 lignes → TROP VERBEUX, condenser
- Doublons entre niveaux → DEDUPLICATION obligatoire

---

## Niveaux de configuration

### Claude Code

| Niveau | Fichier | Portee | Versionne |
|--------|---------|--------|-----------|
| **User global** | `~/.claude/CLAUDE.md` | Toutes les sessions, tous les projets | Non (local) |
| **Project instructions** | `{workspace}/CLAUDE.md` | Ce projet, toutes les sessions | Oui (git) |
| **Project rules** | `{workspace}/.claude/rules/*.md` | Ce projet, regles auto-chargees | Oui (git) |
| **Auto-memory** | `~/.claude/projects/{project-slug}/memory/MEMORY.md` | Ce projet, privee a cette machine | Non (local) |
| **Auto-memory (topics)** | `~/.claude/projects/{project-slug}/memory/*.md` | Sous-fichiers de memoire par topic | Non (local) |
| **Shared memory** | `{workspace}/.claude/memory/PROJECT_MEMORY.md` | Ce projet, partagee via git | Oui (git) |

### Roo Code

| Niveau | Fichier | Portee | Versionne |
|--------|---------|--------|-----------|
| **Rules** | `{workspace}/.roo/rules/*.md` | Toutes les conversations Roo | Oui (git) |
| **Rules orchestrator** | `{workspace}/.roo/rules-orchestrator/*.md` | Orchestrateur uniquement | Oui (git) |
| **Modes** | `{workspace}/.roomodes` (genere) | Modes disponibles | Oui (git) |
| **Mode config** | `roo-config/modes/modes-config.json` | Source des modes | Oui (git) |
| **Settings** | `roo-config/settings/settings.json` | Preferences | Oui (git) |
| **Scheduler workflows** | `{workspace}/.roo/scheduler-workflow-*.md` | Instructions scheduler | Oui (git) |

### Fichiers supplementaires (roo-extensions)

| Niveau | Fichier | Portee | Versionne |
|--------|---------|--------|-----------|
| **Machine overrides** | `.claude/machines/{machine}/CLAUDE.md` | Instructions specifiques machine | Oui (git) |
| **Global configs source** | `.claude/configs/**/*` | Templates deployables vers `~/.claude/` | Oui (git) |
| **Feedback system** | `.claude/feedback/*.md` | Log des propositions d'amelioration | Oui (git) |
| **INTERCOM local** | `.claude/local/INTERCOM-*.md` | Communication Roo local (gitignore) | Non |
| **Guides standalone** | `.claude/ESCALATION_MECHANISM.md`, `bootstrap-checklist.md` | Docs techniques | Oui (git) |

---

## Workflow en 4 phases

### Phase 0 : Vérification Préalable (NOUVEAU)

**CRITIQUE :** Vérifier que le fichier global `~/.claude/CLAUDE.md` existe et est à jour.

**0a. Vérifier l'existence du fichier global :**
```
Read: ~/.claude/CLAUDE.md
```

**Si le fichier n'existe pas ou est vide (< 50 lignes) :**
```
1. Lire le template : Read: {workspace}/.claude/configs/user-global-claude.md
2. Proposer à l'utilisateur : "Le fichier ~/.claude/CLAUDE.md n'existe pas ou est vide. Veux-tu le créer depuis le template ?"
3. Si oui, copier le template vers ~/.claude/CLAUDE.md
4. Documenter dans le rapport : "Fichier global créé depuis template (336 lignes)"
```

**Si le fichier existe mais est obsolète :**
```
1. Comparer les dates de modification
2. Si template > fichier global de plus de 30 jours : proposer mise à jour
3. Afficher les différences principales (sections nouvelles/retirées)
```

**Raison :** Sans fichier global correctement déployé, toute redistribution est inefficace. Les règles universelles (Git, safety, tool discipline) doivent être présentes pour que les règles de projet soient correctement hiérarchisées.

---

### Phase 1 : Inventaire

Collecter TOUS les fichiers de memoire/regles dans le workspace courant, les niveaux utilisateur, ET tous les autres workspaces de cette machine.

**Actions :**

1. **Claude Code - Workspace courant :**
   ```
   Glob: {workspace}/CLAUDE.md
   Glob: {workspace}/.claude/rules/*.md
   Glob: {workspace}/.claude/memory/*.md
   Glob: {workspace}/.claude/agents/**/*.md
   Glob: {workspace}/.claude/skills/*/SKILL.md
   Glob: {workspace}/.claude/commands/*.md
   Glob: {workspace}/.claude/configs/**/*.md
   ```

2. **Claude Code - User level :**
   ```
   Read: ~/.claude/CLAUDE.md (doit exister après Phase 0)
   Read: ~/.claude/settings.json (permissions, MCPs)
   Glob: ~/.claude/agents/**/*.md (agents globaux deployes)
   Glob: ~/.claude/skills/*/SKILL.md (skills globaux deployes)
   Glob: ~/.claude/commands/*.md (commands globaux deployes)
   Glob: ~/.claude/projects/*/memory/MEMORY.md
   Glob: ~/.claude/projects/*/memory/*.md
   ```

3. **Roo Code - Workspace courant :**
   ```
   Glob: {workspace}/.roo/rules/*.md
   Read: {workspace}/.roomodes
   Read: roo-config/modes/modes-config.json (si existe)
   Read: roo-config/settings/settings.json (si existe)
   ```

4. **Decouverte des autres workspaces (SCAN COMPLET) :**

   **4a. Decoder les slugs de projets Claude :**
   ```bash
   # Lister tous les projets connus
   ls ~/.claude/projects/
   # Chaque dossier est un slug : d--roo-extensions → D:\roo-extensions
   # Decodage : remplacer '--' par ':/' (racine) puis '-' par '/' ou '\' (separateur)
   ```

   **4b. Pour chaque workspace decouvert, scanner :**
   ```
   # Memoire privee de ce workspace (dans ~/.claude/projects/{slug}/)
   Read: ~/.claude/projects/{slug}/memory/MEMORY.md
   Glob: ~/.claude/projects/{slug}/memory/*.md
   Read: ~/.claude/projects/{slug}/settings.json (permissions locales)

   # Fichiers locaux du workspace (dans le dossier workspace lui-meme)
   Read: {workspace_path}/CLAUDE.md (si existe)
   Glob: {workspace_path}/.claude/rules/*.md
   Glob: {workspace_path}/.claude/memory/*.md
   Glob: {workspace_path}/.claude/agents/**/*.md
   Glob: {workspace_path}/.claude/skills/*/SKILL.md
   Glob: {workspace_path}/.claude/commands/*.md
   Glob: {workspace_path}/.roo/rules/*.md (si Roo present)
   ```

   **4c. Decoder un slug de projet :**

   Le slug encode le chemin absolu du workspace. Regles de decodage :
   - Premiere lettre + `--` = lettre de lecteur + `:\` (Windows). Ex: `d--` → `D:\`
   - `-` simple = separateur de chemin `\`. Ex: `roo-extensions` → `roo-extensions` (pas de sous-dossier)
   - Quand ambiguite (tiret dans nom vs separateur) : verifier l'existence du chemin

   Exemples courants :
   | Slug | Chemin |
   |------|--------|
   | `d--roo-extensions` | `D:\roo-extensions` |
   | `d--Open-WebUI-myia-open-webui` | `D:\Open-WebUI\myia-open-webui` |
   | `d--qdrant` | `D:\qdrant` |
   | `d--vllm` | `D:\vllm` |
   | `g--Mon-Drive-Maintenance` | `G:\Mon Drive\Maintenance` |

   **Astuce :** Utiliser `Test-Path` pour valider les chemins ambigus :
   ```powershell
   # Tester si le chemin existe
   Test-Path "D:\Open-WebUI\myia-open-webui"
   ```

**Output :**
```
## Inventaire

### Claude Code
| Fichier | Taille | Lignes | Derniere MAJ |
|---------|--------|--------|-------------|
| CLAUDE.md | 25KB | 700 | 2026-02-07 |
| .claude/rules/testing.md | 1KB | 40 | ... |
| ...

### Roo Code
| Fichier | Taille | Lignes | Derniere MAJ |
| ...

### Memoire privee
| Fichier | Taille | Lignes |
| ...
```

### Phase 2 : Analyse (avec grounding SDDD)

**Methodologie :** Triple grounding SDDD (voir `.claude/rules/sddd-conversational-grounding.md`).

**2-preambule. Grounding semantique (chercher les connaissances non documentees) :**
```
codebase_search(query: "lessons learned patterns conventions", workspace: "d:\\roo-extensions")
roosync_search(action: "semantic", search_query: "lecons apprises decisions architecture")
```
But : Trouver des connaissances enfouies dans le code ou les conversations Roo qui n'ont jamais ete formalisees dans les fichiers de memoire/regles.

**2-preambule-b. Grounding conversationnel (traces Roo recentes) :**
```
conversation_browser(action: "tree", output_format: "ascii-tree")
```
But : Identifier les taches Roo recentes dont les resultats/lecons n'ont pas ete captures.

Pour chaque fichier, analyser le contenu et identifier :

**2a. Doublons et contradictions :**
- Meme information dans CLAUDE.md ET une rule
- Meme regle dans `.claude/rules/` ET `.roo/rules/`
- Information dans MEMORY.md qui devrait etre dans CLAUDE.md (ou vice-versa)

**2b. Mauvais placements :**

| Contenu | Devrait etre dans | Pas dans |
|---------|-------------------|----------|
| Preferences utilisateur permanentes | `~/.claude/CLAUDE.md` (user) | CLAUDE.md project |
| Regles techniques du projet | `.claude/rules/*.md` ou `.roo/rules/*.md` | CLAUDE.md (trop gros) |
| Etat transitoire (issues, commits) | `MEMORY.md` (auto-memory) | CLAUDE.md |
| Architecture/conventions stables | `CLAUDE.md` project | MEMORY.md |
| Instructions de build/test | `.claude/rules/testing.md` | CLAUDE.md |
| Lessons learned recentes | `MEMORY.md` | CLAUDE.md (sauf si stable) |
| Conventions partagees multi-machines | `.claude/memory/PROJECT_MEMORY.md` | MEMORY.md local |
| Info specifique machine | `MEMORY.md` local | PROJECT_MEMORY.md partage |

**2c. Taille et complexite :**
- CLAUDE.md > 500 lignes = candidat a l'extraction de rules
- MEMORY.md > 200 lignes = tronque dans le system prompt, risque perte
- Rules > 100 lignes = trop verbeux, condenser

**2d. Information perimee :**
- Etat qui ne correspond plus a la realite (commits, issues fermees)
- Sections "Current State" avec dates > 7 jours
- Lessons learned qui sont maintenant dans les rules

**2e. Contenu universel mal place (CRITIQUE) :**
Pour chaque regle/lecon dans CLAUDE.md project, MEMORY.md, et PROJECT_MEMORY.md, poser la question :
**"Est-ce que cette regle serait utile dans un AUTRE workspace ?"**

Si oui → elle doit aller dans `~/.claude/CLAUDE.md` (user global) via le template `.claude/configs/user-global-claude.md`.

Categories typiquement universelles :
- Git workflow (pull strategy, commits, submodules, force push)
- Tool discipline (Read before Edit, test commands, build verification)
- Investigation methodology (code > docs, announce work)
- Safety rules (backup, no secrets, verify before delete)
- OS/platform gotchas (PowerShell BOM, line endings, paths)
- Knowledge preservation (consolidation, memory hierarchy)
- Terminology (definitions de l'utilisateur applicables partout)

**2f. Agents, Skills et Commands cross-workspace (CRITIQUE) :**
Pour chaque agent, skill et command du workspace :
**"Est-ce generique (tout projet) ou specifique (ce projet uniquement) ?"**

1. **Inventorier :**
   ```
   Glob: {workspace}/.claude/agents/**/*.md
   Glob: {workspace}/.claude/skills/*/SKILL.md
   Glob: {workspace}/.claude/commands/*.md
   ```

2. **Pour chaque element, verifier :**
   - Contient-il des chemins hardcodes specifiques au projet ? (ex: `mcps/internal/servers/...`)
   - Contient-il des noms de projets/repos specifiques ? (ex: `roo-extensions`, `jsboige`)
   - La methodologie est-elle universelle ? (applicable a tout projet)

3. **Classifier :**
   | Type | Critere | Action |
   |------|---------|--------|
   | Generique pur | Aucune reference projet-specifique | → `.claude/configs/{type}s/` (template global) |
   | Generalisable | Refs specifiques mais methodo universelle | → Creer version generique + override projet |
   | Projet-specifique | Intrinsequement lie au projet | → Rester au niveau projet |

4. **Pour les autres workspaces (scan systematique, pas optionnel) :**
   - Decoder les slugs de projets via Phase 1, etape 4c
   - Pour chaque workspace accessible (Test-Path) :
     - Lire CLAUDE.md, chercher agents/skills/commands
     - Lire `.claude/local/` (INTERCOM, notes locales)
     - Identifier les patterns ou workflows qui meritent un agent/skill generique
     - Verifier si les templates globaux deployes seraient utiles dans ces workspaces

5. **Deployer les templates generiques :**
   ```powershell
   powershell -ExecutionPolicy Bypass -File .claude/configs/scripts/Deploy-GlobalConfig.ps1
   ```

6. **Requalifier les overrides projet :**
   Pour chaque element qui a une version generique ET une version projet, ajouter :
   ```markdown
   > **Override projet** : Surcharge la version globale `~/.claude/{type}s/{name}/`.
   > Template generique : `.claude/configs/{type}s/{name}/`
   ```

**Output :**
```
## Analyse

### Doublons detectes : X
| Contenu | Present dans | Action |
|---------|-------------|--------|
| "npx vitest run" | CLAUDE.md + rules/testing.md + MEMORY.md | Garder rules/testing.md, retirer des autres |

### Mauvais placements : Y
| Contenu | Actuellement dans | Devrait etre dans | Raison |
|---------|------------------|-------------------|--------|
| Issue tracker | CLAUDE.md | MEMORY.md | Etat transitoire |

### Fichiers trop gros : Z
| Fichier | Lignes | Limite | Action |
|---------|--------|--------|--------|
| CLAUDE.md | 700 | 500 | Extraire sections en rules |

### Info perimee : W
| Contenu | Fichier | Raison |
|---------|---------|--------|
| "Git: f4630171" | MEMORY.md | Commit obsolete |
```

### Phase 3 : Proposition

Generer un plan de redistribution concret :

```
## Plan de redistribution

### Deplacements proposes

1. CLAUDE.md → .claude/rules/roosync-protocol.md
   Extraire la section "RooSync MCP - Configuration" (lignes X-Y)
   Raison : Regle technique, pas instruction de haut niveau

2. CLAUDE.md → .claude/rules/scheduler.md
   Extraire la section "Taches Planifiees Roo" (lignes X-Y)
   Raison : Documentation technique du scheduler

3. MEMORY.md : Retirer section "Issue Tracker"
   Raison : Etat transitoire, consulter GitHub directement

4. MEMORY.md → .claude/memory/PROJECT_MEMORY.md
   Deplacer "Lessons Learned" stables
   Raison : Partageable entre machines via git

### Validation utilisateur requise
- [ ] Approuver les deplacements ci-dessus
- [ ] Confirmer la creation de nouveaux fichiers rules
- [ ] Valider les suppressions de contenu perime
```

**IMPORTANT : NE RIEN APPLIQUER SANS VALIDATION UTILISATEUR EXPLICITE.**

### Phase 4 : Application

Apres validation, appliquer les changements :

1. Creer les nouveaux fichiers rules (Write)
2. Retirer le contenu deplace des fichiers source (Edit)
3. Mettre a jour les references croisees
4. Nettoyer le contenu perime
5. Verifier la coherence finale

**Output :**
```
## Changements appliques

| Action | Fichier | Detail |
|--------|---------|--------|
| Cree | .claude/rules/scheduler.md | Extrait de CLAUDE.md |
| Modifie | CLAUDE.md | -200 lignes (sections extraites) |
| Modifie | MEMORY.md | Retire etat perime |
| ...

### Verification
- CLAUDE.md : X lignes (avant: Y)
- MEMORY.md : X lignes (avant: Y)
- Nouveaux fichiers : Z
```

---

## Scan multi-workspace complet

Le scan multi-workspace est integre dans Phase 1 (etape 4) et Phase 2. Ce scan est **systematique** (pas optionnel) pour une redistribution vraiment globale.

### Decouverte automatique des workspaces

```powershell
# 1. Lister les projets Claude Code connus
$projects = Get-ChildItem "$env:USERPROFILE\.claude\projects" -Directory

# 2. Decoder chaque slug en chemin workspace
foreach ($p in $projects) {
    $slug = $p.Name
    # d--roo-extensions → D:\roo-extensions
    # Premier caractere = lettre lecteur, -- = :\
    $drive = $slug[0].ToString().ToUpper()
    $rest = $slug.Substring(3) -replace '-', '\'
    $path = "${drive}:\$rest"
    # Valider l'existence
    if (Test-Path $path) { Write-Host "OK: $path" }
}
```

**Note :** Le decodage des slugs peut etre ambigu (tirets dans les noms de dossiers). Toujours valider avec `Test-Path`.

### Ce que le scan collecte pour chaque workspace

| Niveau | Ce qui est scanne | Informations extraites |
|--------|-------------------|------------------------|
| **Memoire privee** | `~/.claude/projects/{slug}/memory/*.md` | Lessons learned, etat courant, patterns |
| **Instructions projet** | `{path}/CLAUDE.md` | Architecture, conventions, regles |
| **Rules projet** | `{path}/.claude/rules/*.md` | Regles techniques auto-chargees |
| **Memoire partagee** | `{path}/.claude/memory/*.md` | Connaissances multi-machines |
| **Agents projet** | `{path}/.claude/agents/**/*.md` | Agents specifiques au projet |
| **Skills projet** | `{path}/.claude/skills/*/SKILL.md` | Skills specifiques |
| **Commands projet** | `{path}/.claude/commands/*.md` | Commands specifiques |
| **Fichiers locaux** | `{path}/.claude/local/*` | INTERCOM, notes locales |
| **Roo rules** | `{path}/.roo/rules/*.md` | Regles Roo si present |
| **Roo modes** | `{path}/.roomodes` | Modes configures |

### Analyse cross-workspace

Pour chaque paire de workspaces, identifier :

1. **Doublons de regles** : Meme regle dans CLAUDE.md de 2+ workspaces → factoriser dans `~/.claude/CLAUDE.md`
2. **Agents/skills reutilisables** : Agent projet-specifique qui serait utile ailleurs → creer template global
3. **Lessons learned universelles** : Dans MEMORY.md d'un workspace mais applicable partout
4. **Patterns de configuration** : Memes rules dans plusieurs workspaces → factoriser au niveau user
5. **XP non capturee** : Workspace sans CLAUDE.md ou sans rules → y a-t-il de l'XP dans MEMORY.md a propager ?

### Rapport multi-workspace

**Output attendu :**
```markdown
## Scan Multi-Workspace - {MACHINE_NAME}

### Workspaces detectes : N
| Workspace | Chemin | CLAUDE.md | Rules | Agents | Skills | MEMORY.md |
|-----------|--------|-----------|-------|--------|--------|-----------|
| roo-extensions | D:\roo-extensions | 700L | 3 | 12 | 5 | 180L |
| Open-WebUI | D:\Open-WebUI\... | - | - | - | - | 20L |
| qdrant | D:\qdrant | - | - | - | - | 15L |
| ... | ... | ... | ... | ... | ... | ... |

### XP a redistribuer
| Source | Contenu | Destination proposee | Raison |
|--------|---------|---------------------|--------|
| qdrant/MEMORY.md | "Always check collection exists before insert" | ~/.claude/CLAUDE.md | Regle universelle |
| Open-WebUI/MEMORY.md | "Docker compose logs -f for debugging" | ~/.claude/CLAUDE.md | Workflow universel |

### Agents/Skills a globaliser
| Element | Workspace source | Reutilisable? | Action |
|---------|------------------|---------------|--------|
| validate | roo-extensions | Oui (deja global) | ✅ Deja deploye |
| ... | ... | ... | ... |
```

### Execution multi-machines (via RooSync)

Ce skill est concu pour etre execute sur CHAQUE machine du reseau.
Chaque agent envoie son rapport via RooSync au coordinateur qui consolide.

**Workflow multi-machines :**
1. Coordinateur envoie message RooSync `[TASK] Executer redistribute-memory scan complet`
2. Chaque agent execute le skill localement (Phase 1-2-3)
3. Chaque agent envoie le rapport multi-workspace via RooSync
4. Coordinateur consolide les rapports de toutes les machines
5. Coordinateur propose les factorisations cross-machines (Phase 3 consolidee)
6. Apres validation utilisateur, deployer les templates globaux (Phase 4)

---

## Criteres de placement (reference)

### Va dans `~/.claude/CLAUDE.md` (user global)

**Critere cle : est-ce utile dans TOUT workspace, pas seulement celui-ci ?**

Exemples de contenu qui DOIT etre ici :
- Definitions terminologiques (ex: "consolider" = analyser + merger + archiver)
- Preferences de style (langue, format, emojis)
- Git best practices (conflict resolution manuelle, conventional commits, never force push)
- Claude Code tool discipline (Read before Edit, test commands non-bloquants)
- Methodology investigation (code source > docs, annoncer travail avant)
- Knowledge preservation (consolider avant fin de session)
- Safety rules (backup avant destructif, jamais de secrets en git)
- Windows/PowerShell gotchas (BOM, Join-Path 2 args, CRLF)
- Submodule workflow (commit interne d'abord)

**Verification a chaque audit :** Relire le CLAUDE.md project et MEMORY.md pour identifier les lecons
qui sont formulees comme specifiques au projet mais en realite universelles.
Demander : "Est-ce que cette regle serait utile si je travaillais sur un autre projet ?"

**Propagation inter-machines :**
- **Source git :** `.claude/configs/user-global-claude.md` dans le repo **roo-extensions**
- **Deploye vers :** `~/.claude/CLAUDE.md` (local, pas dans git, s'applique a TOUS les workspaces)
- **Workflow :** Modifier le template dans roo-extensions, commit+push, chaque machine pull et copie
- **Commande :** `Copy-Item .claude/configs/user-global-claude.md $env:USERPROFILE\.claude\CLAUDE.md`
- **Verif :** Comparer le deploye vs template : `diff ~/.claude/CLAUDE.md .claude/configs/user-global-claude.md`

### Va dans `{workspace}/CLAUDE.md` (project)
- Architecture du projet
- Roles et responsabilites (multi-agent)
- Canaux de communication (RooSync, INTERCOM)
- Vue d'ensemble du systeme

### Va dans `.claude/rules/*.md` (project rules)
- Regles de test (`testing.md`)
- Regles GitHub CLI (`github-cli.md`)
- Protocoles techniques (scheduler, RooSync)
- Conventions de code

### Va dans `MEMORY.md` (auto-memory, privee)
- Etat courant (commits, issues, progression)
- Lessons learned recentes (non encore stabilisees)
- Info specifique a cette machine
- Contexte de session

### Va dans `.claude/memory/PROJECT_MEMORY.md` (shared)
- Lessons learned stabilisees (validees sur >3 sessions)
- Conventions partagees multi-machines
- Decisions architecturales documentees

### Va dans `.roo/rules/*.md` (Roo rules)
- Instructions pour Roo (pas Claude)
- Restrictions d'outils Roo
- Protocole INTERCOM cote Roo
- Validation et securite cote Roo

---

## Diagnostic rapide (NOUVEAU v2.0)

Avant de lancer le workflow complet, un diagnostic rapide identifie les urgences :

```
1. Compter les lignes de chaque fichier cle :
   - CLAUDE.md (projet) > 500 ? → ALERTE SATURATION
   - MEMORY.md (auto) > 150 ? → ALERTE TRUNCATION
   - PROJECT_MEMORY.md > 300 ? → ALERTE BALLONNEMENT

2. Verifier les doublons evidents :
   - Meme section dans CLAUDE.md ET dans .claude/rules/ ?
   - Meme info dans MEMORY.md ET dans PROJECT_MEMORY.md ?
   - Instructions Roo dans fichiers Claude et vice-versa ?

3. Verifier la fraicheur :
   - "Current State" avec dates > 7 jours ? → PERIME
   - Issues fermees encore listees comme actives ? → STALE
   - Metriques (tests, tools) qui ne correspondent plus ? → DECALE
```

### Actions correctives typiques pour CLAUDE.md sature

Si CLAUDE.md > 500 lignes, extraire dans cet ordre de priorite :

| Section a extraire | Vers | Raison |
|--------------------|------|--------|
| Systeme de scheduler (~300 lignes) | `.claude/rules/scheduler-system.md` | Documentation technique, pas instructions de haut niveau |
| GitHub Projects / GraphQL (~60 lignes) | Deja dans `.claude/rules/github-cli.md` | DOUBLON : retirer de CLAUDE.md |
| Checklist validation technique (~80 lignes) | `.claude/rules/validation-checklist.md` | Regle technique |
| Architecture agents/skills (~150 lignes) | `.claude/rules/agents-architecture.md` | Reference technique, pas instructions |
| Config MCP detaillee (~100 lignes) | `.claude/MCP_SETUP.md` (existe deja) | Consolidation |

### Actions correctives pour MEMORY.md sature

Si MEMORY.md > 150 lignes :
1. Deplacer les lessons learned stables vers PROJECT_MEMORY.md
2. Retirer les etats transitoires perimes (cycles >48h, issues fermees)
3. Condenser les tableaux machine status en une ligne par machine
4. Deplacer les details d'issues vers des fichiers topic (memory/issues.md)

---

## Notes d'utilisation

### Invocation
- "redistribue la memoire" ou "audite les regles" ou "nettoie CLAUDE.md" → scan workspace courant
- "scan global" ou "redistribue tout" → scan complet multi-workspace (Phase 1 etape 4)
- "rapport multi-workspace" → generer le rapport tabulaire pour envoi au coordinateur

### Signalement de friction
Si le scan multi-workspace revele des incoherences recurrentes ou des outils manquants :
```
roosync_send(action: "send", to: "all", subject: "[FRICTION] Description", body: "...", tags: ["friction", "memory"])
```
Les ameliorations des skills sont decidees collectivement (voir `.claude/rules/sddd-conversational-grounding.md`).

### Frequence recommandee
- Apres chaque session longue (>2h)
- Quand CLAUDE.md depasse 500 lignes
- Quand MEMORY.md depasse 150 lignes
- Apres ajout de nouvelles conventions/regles
- **Sur demande du coordinateur** via RooSync (scan multi-machines)
- **Apres deploiement global** (verifier que les templates sont bien deployes)

### Permissions
- Lecture de tous les fichiers memoire/rules (workspace courant ET autres)
- Lecture des fichiers locaux `~/.claude/` (agents, skills, commands, CLAUDE.md globaux)
- Lecture des repertoires locaux des autres workspaces (CLAUDE.md, .claude/, .roo/)
- Ecriture apres validation utilisateur uniquement
- Pas de suppression de fichier (seulement edition de contenu)
