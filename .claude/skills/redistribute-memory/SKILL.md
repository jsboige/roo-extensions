---
name: redistribute-memory
description: Audite et redistribue les connaissances entre 5 niveaux de hiérarchie. Détecte les antipatterns, propose un plan de redistribution, et exécute après validation. Utilisable sur tout workspace. Phrase déclencheur : "/redistribute-memory", "redistribue la mémoire", "audite les règles", "nettoie CLAUDE.md".
triggers:
  keywords:
    - "redistribue mémoire"
    - "redistribue la mémoire"
    - "redistribue la memoire"
    - "audite les règles"
    - "nettoie CLAUDE.md"
    - "redistribute memory"
    - "CLAUDE.md saturé"
    - "audit tiers"
  exact:
    - "redistribute"
  patterns:
    - "(redistribu|audit|nettoye?).{0,15}(memoire|regles|rules|CLAUDE|tiers)"
metadata:
  author: "Roo Extensions Team"
  version: "3.1.0"
  issue: "#2223"
  compatibility:
    surfaces: ["claude-code", "claude.ai"]
    workspaces: ["roo-extensions", "CoursIA", "any"]
    restrictions: "Requiert accès aux fichiers de configuration Claude/Roo. dry-run par défaut."
---

# Skill : Redistribution Mémoire V2 — 5 Tiers

**Version:** 3.1.0 (2026-09-01)
**Issue:** #2223
**Usage:** `/redistribute-memory` ou "redistribue la mémoire", "audite les règles", "nettoie CLAUDE.md"

---

## Les 5 Tiers

| Tier | Fichier | Scope | Chargement | Mutabilité |
|------|---------|-------|------------|------------|
| **T1** Machine Global | `~/.claude/CLAUDE.md` | Toutes sessions, tous workspaces | Auto | Faible (template git) |
| **T2** Workspace Projet | `{workspace}/CLAUDE.md` | Ce workspace | Auto | Moyen (git) |
| **T3** Workspace Rules | `{workspace}/.claude/rules/*.md` | Ce workspace | Auto | **SACRÉ** — validation user obligatoire |
| **T4** Workspace Deferred | `{workspace}/docs/harness/reference/*.md` (ou équivalent) | Ce workspace | Lazy (`Read`) | Élevé (git, docs) |
| **T5** Machine+Workspace Memory | `~/.claude/projects/{slug}/memory/MEMORY.md` + `*.md` | Machine+workspace | Auto-injecté | Élevé (local) |

**Règle absolue :** T3 (rules) = sacré. Jamais de modification sans validation user explicite.

---

## Workflow — 5 Phases

### Phase 0 : Auto-détection

**Objectif :** Identifier la machine, le workspace, et résoudre les chemins des 5 tiers.

**Actions :**

```
1. Machine : hostname ou $env:COMPUTERNAME
2. Workspace : répertoire courant (process.cwd() ou pwd)
3. Slug : encoder le chemin workspace en slug Claude Code
   - Windows : D:\roo-extensions → d--roo-extensions
   - Règle : lettre lecteur minuscule + "--" + chemin avec "-" pour séparateurs
4. Résoudre les chemins :
   T1 = ~/.claude/CLAUDE.md
   T2 = {workspace}/CLAUDE.md
   T3 = {workspace}/.claude/rules/*.md
   T4 = {workspace}/docs/harness/reference/*.md  (ou équivalent projet)
   T5 = ~/.claude/projects/{slug}/memory/MEMORY.md + *.md
5. Vérifier l'existence de chaque tier (Glob/Read)
```

**Output :**
```
## Auto-détection
- Machine: myia-po-2025
- Workspace: D:\roo-extensions
- Slug: d--roo-extensions
- T1: C:\Users\jsboi\.claude\CLAUDE.md (exists, N lignes)
- T2: D:\roo-extensions\CLAUDE.md (exists, N lignes)
- T3: D:\roo-extensions\.claude\rules\ (N fichiers)
- T4: D:\roo-extensions\docs\harness\reference\ (N fichiers)
- T5: C:\Users\jsboi\.claude\projects\d--roo-extensions\memory\ (N fichiers)
```

### Phase 1 : Audit des 5 Tiers

**Objectif :** Collecter volume, contenu, et métriques pour chaque tier.

**Actions :**

Pour chaque tier, collecter :
- Nombre de fichiers
- Lignes totales / taille en KB
- Dernière date de modification
- Sections thématiques (titres markdown)

```
# T1 - Machine Global
Read: ~/.claude/CLAUDE.md

# T2 - Workspace Projet
Read: {workspace}/CLAUDE.md

# T3 - Workspace Rules (LECTURE SEULE)
Glob: {workspace}/.claude/rules/*.md
# Pour chaque fichier : compter lignes, lister sections

# T4 - Workspace Deferred
Glob: {workspace}/docs/**/*.md (ou équivalent)
# Identifier les docs de référence existants

# T5 - Memory
Read: ~/.claude/projects/{slug}/memory/MEMORY.md
Glob: ~/.claude/projects/{slug}/memory/*.md
```

**Métriques collectées :**
```
| Tier | Fichiers | Lignes | Taille | Dernière MAJ |
|------|----------|--------|--------|-------------|
| T1 | 1 | N | N KB | YYYY-MM-DD |
| T2 | 1 | N | N KB | YYYY-MM-DD |
| T3 | N | N | N KB | YYYY-MM-DD |
| T4 | N | N | N KB | YYYY-MM-DD |
| T5 | N | N | N KB | YYYY-MM-DD |
```

**Seuils d'alerte :**
- T2 (CLAUDE.md projet) > 500 lignes → **SATURATION** — candidat extraction vers T3/T4
- T3 (rules) fichier individuel > 150 lignes → **VERBOSE** — candidat condensation
- T5 (MEMORY.md) > **17,1 Ko** → **TRUNCATION RISK** — candidat stabilisation vers T4 ou PROJECT_MEMORY
  - ⚠️ **Mesurer en OCTETS, jamais en lignes.** Les deux nombres ci-dessus (**24,4 Ko** de
    read-limit, **17,1 Ko** de cible) ne sont pas choisis : ils sont **énoncés par le hook
    système `PostToolUse:Edit`** lui-même, verbatim (capté par po-2025 le 2026-08-13) :
    > *this write left the memory index at MEMORY.md at 24.9KB, over its 24.4KB read limit.
    > The write succeeded, but everything past the limit is **silently dropped each time the
    > index is loaded** — entries at the end are already invisible to readers. Rewrite it to
    > under 17.1KB now: keep one line per entry, move detail into topic files, and merge or
    > drop stale entries.*
  - **L'écriture RÉUSSIT** — il n'y a ni erreur ni troncature visible. Seule la *lecture* perd
    la fin de l'index, à chaque chargement. C'est pourquoi un seuil qui ne se déclenche pas
    ne se remarque jamais. Re-mesure ai-01 le 2026-09-01 : **160 lignes pour 24 994 o**, soit
    40 lignes SOUS un seuil de 200 et déjà **au-dessus** de la read-limit.
  - Un seuil en lignes ne se déclenche sur **aucun** des 14 index d'ai-01, et il **décorrèle à
    mesure que le skill réussit** : compacter une entrée en pointeur + accroche densifie les lignes,
    donc fait BAISSER leur compte à octets constants. La métrique de succès s'éloigne de la
    contrainte à chaque compaction — c'est l'explication du « total plat » observé sur 3 rounds.
- Doublons entre tiers → **REDONDANCE**

### Phase 2 : Détection d'Antipatterns

**Objectif :** Identifier les problèmes de placement et de structure.

#### Antipattern 1 : Connaissance machine dupliquée dans le workspace

**Détection :** Comparer T1 et T2. Chercher les sections identiques ou quasi-identiques.

```
Pour chaque section de T2 :
  Si la même information existe dans T1 → FLAG (duplication T1↔T2)
  Question : "Est-ce que cette info serait utile dans UN AUTRE workspace ?"
  Si oui → doit être dans T1, pas T2
```

**Exemples typiques :**
- Git workflow dans CLAUDE.md projet alors que déjà dans `~/.claude/CLAUDE.md`
- Tool discipline (Read before Edit, test commands) dupliqué
- PowerShell/Windows gotchas dupliqué

#### Antipattern 2 : Connaissance workspace remontée à tort dans T1

**Détection :** Comparer T1 et T2. Chercher les infos spécifiques au projet dans T1.

```
Pour chaque section de T1 :
  Contient-elle des chemins, noms de repo, ou concepts spécifiques à un projet ?
  Si oui → FLAG (T1 contamination)
  Action : Déplacer vers T2 du workspace concerné
```

#### Antipattern 3 : Procédures longues dans T2 au lieu de T4

**Détection :** Sections de T2 qui sont des procédures détaillées ou de la documentation technique.

```
Pour chaque section de T2 :
  Longueur > 30 lignes ET nature = procédure/documentation technique ?
  Si oui → FLAG (deferred candidate)
  Action : Extraire vers T4 (docs/), laisser un résumé 3-5 lignes dans T2
```

**Exemples :**
- Configuration MCP détaillée → `docs/harness/reference/mcp-setup.md`
- Procédure de build complète → `docs/harness/reference/build-procedure.md`
- Architecture détaillée → `docs/harness/reference/architecture.md`

#### Antipattern 4 : Rules redondantes (T3)

**Détection :** Comparer les paires de fichiers dans T3.

```
Pour chaque paire de fichiers T3 :
  Chevauchement de contenu > 30% ?
  Si oui → FLAG (rules redondantes)
  ATTENTION : signaler UNIQUEMENT, ne jamais modifier sans validation user explicite
```

#### Antipattern 5 : MEMORY.md topic files orphelins

**Détection :** Vérifier que chaque fichier topic dans T5 est référencé.

```
Pour chaque fichier dans T5 (sauf MEMORY.md) :
  Rechercher son nom dans MEMORY.md (index)
  S'il n'est pas référencé → FLAG (topic orphelin)
  Action : Intégrer dans l'index MEMORY.md ou merger son contenu
           ⚠️ DEUX modes d'échec — voir sous le bloc
```

**Les deux modes d'échec de l'indexation** — les distinguer AVANT d'indexer, car ils ne se
réparent pas au même endroit :

- **(a) L'index est PLEIN** (MEMORY.md proche de ~24,4 Ko). Indexer y **droppe silencieusement**.
  Compacter ou stabiliser d'abord. Le réflexe à proscrire est de rabattre le contenu dans un
  topic voisin faute de place : le placement est alors décidé par le cap, **pas par le critère**,
  et le fait devient introuvable pour qui ne sait pas déjà où regarder.
- **(b) Le taux d'indexation est très bas** (< 20 %). L'index n'est pas *en retard*, il est
  **dépassé structurellement** : le producteur écrit plus vite que toute indexation possible
  (cas mesuré : 563 topics pour 18 référencés, un fichier par cycle). Réparer l'aval se rejoue
  indéfiniment — **c'est le producteur qu'il faut corriger**, en cessant d'écrire un topic par
  cycle (le rapport de cycle va au dashboard, qui existe déjà).

AP5 ne distingue pas ces deux causes ; les traiter à l'identique fait perdre le cas (b).

#### Antipattern 6 : Contenu obsolète

**Détection :** Chercher les marqueurs d'obsolescence.

```
Pour chaque tier :
  - "Current State" avec date > 14 jours → STALE
  - Références à des issues fermées (gh issue view N --json state) → STALE
  - Métriques qui ne correspondent plus à la réalité → STALE
  - Sections "TODO" ou "FIXME" anciennes → STALE
```

**Output Phase 2 :**
```
## Antipatterns détectés

| # | Antipattern | Tier | Contenu | Action proposée |
|---|------------|------|---------|----------------|
| 1 | T1↔T2 duplication | T2 | Git workflow (lignes X-Y) | Retirer de T2, déjà dans T1 |
| 2 | Deferred candidate | T2 | Procédure MCP (lignes X-Y, 80L) | Extraire vers docs/ |
| 3 | Topic orphelin | T5 | memory/docker.md | Ajouter au index MEMORY.md |
| ... | ... | ... | ... | ... |
```

### Phase 3 : Plan de Redistribution (dry-run)

**Objectif :** Produire un plan concret. **AUCUNE exécution sans validation user.**

**Format du plan :**
```
## Plan de Redistribution — {MACHINE} / {WORKSPACE}

### Résumé
- N antipatterns détectés
- N actions proposées
- Volume estimé : ±N lignes par tier

### Actions proposées

#### ACTION-1 : [Déplacer|Dédupliquer|Déférer|Indexer|Nettoyer]
- **Source :** Tier X, fichier, lignes A-B
- **Destination :** Tier Y, fichier
- **Contenu :** [résumé 1 ligne]
- **Raison :** [pourquoi]
- **Impact :** [ce qui change]
- **Risque :** [faible|moyen|élevé]
- **Requiert validation T3 :** [oui|non]

#### ACTION-2 : ...

### Total par tier
| Tier | Avant | Après | Delta |
|------|-------|-------|-------|
| T1 | N lignes | N lignes | ±N |
| T2 | N lignes | N lignes | ±N |
| T3 | N fichiers | N fichiers | ±N |
| T4 | N fichiers | N fichiers | ±N |
| T5 | N fichiers | N fichiers | ±N |

### Validation requise
- [ ] ACTION-1 : [description]
- [ ] ACTION-2 : [description]
- ...
- [ ] Confirmer les modifications T3 (si applicable)
```

**Règles du plan :**
1. **T3 (rules) :** Toute action touchant T3 requiert une validation user explicite par action. Pas de batch approval.
2. **T5 (MEMORY.md) :** Jamais de suppression de leçons. Seulement déplacement (vers PROJECT_MEMORY.md ou T4) ou stabilisation.
3. **T4 (docs) :** Création libre. Le contenu déplacé de T2 est préservé intégralement.
4. **Token savings :** Mentionné si naturel (déduplication, déport docs). Jamais agressif.

### Phase 4 : Exécution (après validation)

**Objectif :** Appliquer les actions validées.

**Pour chaque action validée :**

```
1. Read le fichier source (vérifier que le contenu est toujours là)
2. Read le fichier destination (si existe, pour append/merge)
3. Exécuter la transformation :
   - DÉPLACER : Write destination + Edit source (retirer section)
   - DÉDUPLIQUER : Edit source (retirer doublon)
   - DÉFÉRER : Write destination dans T4 + Edit T2 (remplacer par résumé 3-5 lignes + lien Read)
   - INDEXER : Edit MEMORY.md (ajouter référence au topic file)
     ⚠️ **ÉCHOUE si l'index est plein** (cf. AP5) : vérifier la taille de MEMORY.md AVANT.
       Si l'ajout ferait dépasser ~24,4 Ko → compacter/stabiliser d'abord. Ne JAMAIS rabattre
       le contenu dans un topic voisin faute de place : le fait devient introuvable pour qui
       ne sait pas déjà où regarder, et l'index chargé à chaque session n'apprend pas qu'il existe.
       La sortie du hook prescrit exactement la discipline de ce skill — *« keep one line per
       entry, move detail into topic files »* : compacter en pointeur + accroche, détail déporté.
   - NETTOYER : Edit fichier (retirer contenu obsolète)
4. Vérifier la cohérence (re-Read si nécessaire)
```

**Output :**
```
## Changements appliqués

| Action | Fichier | Détail |
|--------|---------|--------|
| ACTION-1 | T2/CLAUDE.md | -80 lignes (section MCP extraite) |
| ACTION-1 | T4/docs/.../mcp-setup.md | +85 lignes (nouveau fichier) |
| ACTION-2 | T5/MEMORY.md | +2 lignes (index mis à jour) |
| ... | ... | ... |

### Vérification non-régression
- T2 : N lignes (avant: M, delta: -K)
- T4 : N+1 fichiers (avant: N)
- T5 : N fichiers (inchangé)
- T3 : NON MODIFIÉ (sacré)
- Agents scheduled : peuvent toujours accéder l'info via Read ciblé
```

### Phase 5 : Rapport

**Objectif :** Documenter le résultat.

```
## Rapport Redistribution — {MACHINE} / {WORKSPACE}
**Date :** YYYY-MM-DD
**Mode :** [dry-run | exec]

### Avant
| Tier | Lignes | Fichiers |
|------|--------|----------|
| T1 | N | 1 |
| T2 | N | 1 |
| T3 | N | N |
| T4 | N | N |
| T5 | N | N |

### Après
| Tier | Lignes | Fichiers | Delta |
|------|--------|----------|-------|
| T1 | N | 1 | ±0 |
| T2 | N-M | 1 | -M |
| T3 | N | N | 0 (sacré) |
| T4 | N+K | N+1 | +K |
| T5 | N | N | ±0 |

### Antipatterns
- N/6 résolus
- N restants (raison)

### Prochaines actions recommandées
- [Action spécifique pour prochaine session]
```

Poster ce rapport sur le dashboard workspace :
```
roosync_dashboard(action: "append", type: "workspace", tags: ["DONE", "claude-interactive"], content: "Rapport redistribution V2...")
```

---

## Mode dry-run (défaut)

**Par défaut, le skill s'exécute en mode dry-run :** Phases 0-3 + Phase 5 (rapport dry-run). Phase 4 n'est exécutée QUE si l'utilisateur valide explicitement.

**Invocation :**
- "redistribue la mémoire" → dry-run (Phases 0-3 + rapport)
- "redistribue et applique" ou "exécute la redistribution" → dry-run + Phase 4 après validation
- L'utilisateur peut valider des actions individuelles : "applique ACTION-1 et ACTION-3"

---

## Critères de placement — Reference rapide

### T1 — `~/.claude/CLAUDE.md` (Machine Global)
**Critère : utile dans TOUT workspace.**

- Terminologie (définitions utilisateur)
- Git best practices (commits, conflits, submodules, force push)
- Tool discipline (Read before Edit, test commands)
- Methodology investigation (code > docs)
- Safety (backup, no secrets)
- OS gotchas (PowerShell BOM, CRLF)
- Knowledge preservation (consolidation, memory hierarchy)

### T2 — `{workspace}/CLAUDE.md` (Workspace Projet)
**Critère : spécifique au projet, haut niveau.**

- Architecture du projet
- Canaux de communication
- Vue d'ensemble du système
- Raccourcis vers docs (résumés 3-5 lignes + "Voir docs/... pour détails")

### T3 — `{workspace}/.claude/rules/*.md` (Workspace Rules) — SACRÉ
**Critère : règles techniques auto-chargées.**

- Protocoles techniques
- Conventions de code
- Checklist validation
- Restriction d'accès / sécurité

### T4 — `{workspace}/docs/harness/reference/` (Workspace Deferred)
**Critère : documentation détaillée, procédures, références.**

- Procédures de build/deploy
- Documentation MCP détaillée
- Architecture détaillée
- Guides opérationnels
- Post-mortems

### T5 — `~/.claude/projects/{slug}/memory/` (Machine+Workspace Memory)
**Critère : état transitoire, lessons learned récentes.**

- État courant (commits, issues, progression)
- Lessons learned récentes (non stabilisées)
- Info spécifique machine
- Index des topic files

---

## Multi-workspace

Le skill est conçu pour fonctionner sur **tout workspace** sans modification :

1. **Auto-détection** (Phase 0) résout les chemins dynamiquement
2. **T4 adaptatif** : Si `{workspace}/docs/harness/reference/` n'existe pas, cherche `{workspace}/docs/` ou propose de créer la structure
3. **T3 sacré** : Ne suppose jamais l'existence de rules
4. **T5 discovery** : Encode le chemin workspace en slug pour trouver le bon répertoire memory

### Exécution sur CoursIA

```
Phase 0 :
  Workspace: D:\CoursIA
  Slug: d--CoursIA
  T4 adaptatif: D:\CoursIA\docs/ (pas de docs/harness/reference/)
  T3: D:\CoursIA\.claude\rules\ (si existe)
```

Le skill s'adapte automatiquement à la structure du workspace cible.

---

## Antipatterns — Catalogue complet

| # | Nom | Détection | Action |
|---|-----|-----------|--------|
| AP1 | T1↔T2 duplication | Comparaison sections T1 vs T2 | Retirer de T2 si déjà dans T1 |
| AP2 | T1 contamination | Info projet-spécifique dans T1 | Déplacer vers T2 du workspace |
| AP3 | Deferred candidate | Section >30L de type procédure dans T2 | Extraire vers T4 + résumé dans T2 |
| AP4 | Rules redondantes | Chevauchement >30% entre 2 fichiers T3 | Signaler (ne jamais modifier sans user) |
| AP5 | Topic orphelin | Fichier T5 non référencé dans MEMORY.md | Ajouter au index |
| AP6 | Contenu obsolète | Dates >14j, issues fermées, métriques décalées | Nettoyer (après vérification) |
