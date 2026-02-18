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

### Roo Code (si present)

| Niveau | Fichier | Portee | Versionne |
|--------|---------|--------|-----------|
| **Rules** | `{workspace}/.roo/rules/*.md` | Toutes les conversations Roo | Oui (git) |
| **Modes** | `{workspace}/.roomodes` | Modes disponibles | Oui (git) |

---

## Workflow en 4 phases

### Phase 1 : Inventaire

Collecter TOUS les fichiers de memoire/regles dans le workspace courant et les niveaux utilisateur.

**Actions :**

1. **Claude Code - Workspace courant :**
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
   Read: ~/.claude/CLAUDE.md
   Glob: ~/.claude/agents/**/*.md
   Glob: ~/.claude/skills/*/SKILL.md
   Glob: ~/.claude/commands/*.md
   Glob: ~/.claude/projects/*/memory/MEMORY.md
   ```

3. **Roo Code - Workspace courant (si .roo/ existe) :**
   ```
   Glob: {workspace}/.roo/rules/*.md
   ```

4. **Decouverte des autres workspaces :**
   ```bash
   ls ~/.claude/projects/
   # Decoder chaque slug en chemin workspace
   # d--mon-projet → D:\mon-projet
   ```

**Output :** Tableau avec fichier, taille, lignes pour chaque fichier decouvert.

### Phase 2 : Analyse

Pour chaque fichier, identifier :

**2a. Doublons et contradictions :**
- Meme information dans CLAUDE.md ET une rule
- Meme regle dans `.claude/rules/` ET `.roo/rules/`
- Information dans MEMORY.md qui devrait etre dans CLAUDE.md (ou vice-versa)

**2b. Mauvais placements :**

| Contenu | Devrait etre dans | Pas dans |
|---------|-------------------|----------|
| Preferences utilisateur permanentes | `~/.claude/CLAUDE.md` (user) | CLAUDE.md project |
| Regles techniques du projet | `.claude/rules/*.md` | CLAUDE.md (trop gros) |
| Etat transitoire (issues, commits) | `MEMORY.md` (auto-memory) | CLAUDE.md |
| Architecture/conventions stables | `CLAUDE.md` project | MEMORY.md |
| Lessons learned recentes | `MEMORY.md` | CLAUDE.md (sauf si stable) |
| Conventions partagees multi-machines | `.claude/memory/PROJECT_MEMORY.md` | MEMORY.md local |
| Info specifique machine | `MEMORY.md` local | PROJECT_MEMORY.md partage |

**2c. Taille et complexite :**
- CLAUDE.md > 500 lignes = candidat a l'extraction de rules
- MEMORY.md > 150 lignes = tronque dans le system prompt, risque perte
- Rules > 150 lignes = trop verbeux, condenser

**2d. Information perimee :**
- Etat qui ne correspond plus a la realite (commits, issues fermees)
- Sections "Current State" avec dates > 7 jours
- Lessons learned qui sont maintenant dans les rules

**2e. Contenu universel mal place :**
Pour chaque regle/lecon, poser la question :
**"Est-ce que cette regle serait utile dans un AUTRE workspace ?"**
Si oui → elle doit aller dans `~/.claude/CLAUDE.md` (user global).

### Phase 3 : Proposition

Generer un plan de redistribution concret avec :
- Deplacements proposes (source → destination + raison)
- Nouveaux fichiers a creer
- Contenu perime a retirer
- Validation utilisateur requise

**IMPORTANT : NE RIEN APPLIQUER SANS VALIDATION UTILISATEUR EXPLICITE.**

### Phase 4 : Application

Apres validation :
1. Creer les nouveaux fichiers rules (Write)
2. Retirer le contenu deplace des fichiers source (Edit)
3. Mettre a jour les references croisees
4. Nettoyer le contenu perime
5. Verifier la coherence finale

---

## Diagnostic rapide

Avant le workflow complet, un diagnostic rapide :

```
1. Compter les lignes de chaque fichier cle :
   - CLAUDE.md (projet) > 500 ? → ALERTE SATURATION
   - MEMORY.md (auto) > 150 ? → ALERTE TRUNCATION

2. Verifier les doublons evidents

3. Verifier la fraicheur (dates > 7 jours = PERIME)
```

---

## Criteres de placement (reference)

| Destination | Contenu type |
|-------------|-------------|
| `~/.claude/CLAUDE.md` (user global) | Preferences permanentes cross-projets, git workflow, tool discipline, OS gotchas |
| `{workspace}/CLAUDE.md` (project) | Architecture, roles, canaux de communication, vue d'ensemble |
| `.claude/rules/*.md` (project rules) | Regles techniques : tests, CLI, protocoles, conventions |
| `MEMORY.md` (auto-memory) | Etat courant, lessons recentes, info machine-specifique |
| `.claude/memory/PROJECT_MEMORY.md` (shared) | Lessons stabilisees, conventions multi-machines, decisions archi |
| `.roo/rules/*.md` (Roo rules) | Instructions Roo uniquement, restrictions outils, protocole INTERCOM |

---

## Notes d'utilisation

### Frequence recommandee
- Quand CLAUDE.md depasse 500 lignes
- Quand MEMORY.md depasse 150 lignes
- Apres ajout de nouvelles conventions/regles
- Sur demande du coordinateur (scan multi-machines)

### Permissions
- Lecture de tous les fichiers memoire/rules
- Ecriture apres validation utilisateur uniquement
- Pas de suppression de fichier (seulement edition de contenu)
