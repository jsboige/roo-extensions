# Skill : Redistribution Memoire & Regles

Ce skill audite et redistribue les connaissances, regles et memoires entre les differents niveaux de configuration de Claude Code et Roo Code.

---

## Objectif

Les informations s'accumulent dans des fichiers qui ne sont pas toujours au bon niveau. Ce skill :
1. Inventorie tous les fichiers de memoire/regles/instructions
2. Analyse le contenu pour identifier les mauvais placements
3. Propose des deplacements/consolidations
4. Applique les changements apres validation utilisateur

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
| **Modes** | `{workspace}/.roomodes` (genere) | Modes disponibles | Oui (git) |
| **Mode config** | `roo-config/modes/modes-config.json` | Source des modes | Oui (git) |
| **Settings** | `roo-config/settings/settings.json` | Preferences | Oui (git) |

---

## Workflow en 4 phases

### Phase 1 : Inventaire

Collecter TOUS les fichiers de memoire/regles dans le workspace courant ET les niveaux utilisateur.

**Actions :**

1. **Claude Code - Workspace :**
   ```
   Glob: {workspace}/CLAUDE.md
   Glob: {workspace}/.claude/rules/*.md
   Glob: {workspace}/.claude/memory/*.md
   Glob: {workspace}/.claude/agents/**/*.md
   Glob: {workspace}/.claude/skills/*/SKILL.md
   Glob: {workspace}/.claude/commands/*.md
   ```

2. **Claude Code - User level :**
   ```
   Read: ~/.claude/CLAUDE.md (peut ne pas exister)
   Glob: ~/.claude/projects/*/memory/MEMORY.md
   Glob: ~/.claude/projects/*/memory/*.md
   ```

3. **Roo Code :**
   ```
   Glob: {workspace}/.roo/rules/*.md
   Read: {workspace}/.roomodes
   Read: roo-config/modes/modes-config.json (si existe)
   Read: roo-config/settings/settings.json (si existe)
   ```

4. **Autres workspaces sur cette machine** (optionnel, si demande) :
   ```
   # Detecter les workspaces connus via les projets Claude
   Glob: ~/.claude/projects/*/memory/MEMORY.md
   # Pour chaque projet trouve, lire son CLAUDE.md et ses rules
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

### Phase 2 : Analyse

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

## Extension multi-workspace (optionnel)

Si invoque avec la demande d'analyser d'autres workspaces :

1. **Detecter les projets Claude Code :**
   ```bash
   ls ~/.claude/projects/
   ```

2. **Pour chaque projet trouve :**
   - Extraire le chemin workspace du slug (ex: `d--roo-extensions` → `d:\roo-extensions`)
   - Lire son CLAUDE.md et ses rules
   - Analyser les doublons cross-workspace
   - Identifier les regles qui devraient etre au niveau user (`~/.claude/CLAUDE.md`)

3. **Proposer les factorisations cross-workspace :**
   - Regles communes → `~/.claude/CLAUDE.md` (user level)
   - Regles specifiques → garder au niveau projet

---

## Criteres de placement (reference)

### Va dans `~/.claude/CLAUDE.md` (user global)
- Preferences de style (langue, format, emojis)
- Outils preferes (git workflow, test commands)
- Conventions personnelles applicables a tous les projets
- Configuration LLM provider

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

## Notes d'utilisation

### Invocation
Demander : "redistribue la memoire" ou "audite les regles" ou "nettoie CLAUDE.md"

### Frequence recommandee
- Apres chaque session longue (>2h)
- Quand CLAUDE.md depasse 500 lignes
- Quand MEMORY.md depasse 150 lignes
- Apres ajout de nouvelles conventions/regles

### Permissions
- Lecture de tous les fichiers memoire/rules
- Ecriture apres validation utilisateur uniquement
- Pas de suppression de fichier (seulement edition de contenu)
