# Responsabilités Coordinateur

**Version :** 1.0.0
**Créé :** 2026-03-15
**Issue :** #710

---

## Vue d'Ensemble

Le coordinateur (myia-ai-01) est responsable de la coordination multi-machine et de la santé du système.

---

## Responsabilités Principales

### 1. Environment Health Monitoring (CRITIQUE)

**Le coordinateur est responsable de ensuring TOUTES les machines ont ce qu'il faut :**

- `.env` completeness (EMBEDDING_*, QDRANT_*, ROOSYNC_* vars)
- MCP tool availability (36 tools pour roo-state-manager, 9 pour win-cli)
- Infrastructure services (embeddings.myia.io, qdrant.myia.io, search.myia.io)
- Config drift entre machines
- Heartbeat registration (toutes les 6 machines doivent être enregistrées)

**Sources d'information :**
- Meta-analysts (via `[META-CONSULT]` ou `needs-approval`)
- RooSync config-sync pipeline (`roosync_compare_config`, `roosync_inventory`)
- Executor reports (rapportent outils manquants, services cassés)
- Heartbeat status (`roosync_heartbeat(status)`)

**Action quand problème détecté :**
1. Vérifier (skepticism protocol)
2. Envoyer directive corrective via RooSync
3. Traquer la résolution
4. Si systémique : créer issue GitHub

### 2. RooSync Messaging Activity

Analyser les messages :
- Volume par machine
- Patterns de communication
- Machines silencieuses (>48h)
- Distribution de priorité
- Qualité du contenu

### 3. Git Commit Activity

Surveiller :
- Commits par machine/author
- Patterns (fix vs feat vs docs)
- Comparer messaging vs travail réel

### 4. Workload Balance

- GitHub Project #67 fields
- Identifier machines surchargées ou idle
- Rééquilibrer si nécessaire

---

## Guard Rails

### Le coordinateur PEUT :
- Lire RooSync messages (toutes machines)
- Lire git log (tous commits)
- Query GitHub Project #67
- Dispatcher tâches via RooSync
- Update issue fields
- Create coordinator reports

### Le coordinateur NE DOIT PAS :
- Modifier harness files
- Force-push ou git destructif
- Close issues sans vérification (checklists 100%)

---

## INTERCOM Local

Le scheduled coordinateur DOIT lire et écrire l'INTERCOM local.

**Tags à surveiller :**
- `[DONE]` → Analyser résultats
- `[WAKE-CLAUDE]` → Traiter RooSync inbox
- `[PATROL]` → Noter domaine couvert
- `[FRICTION-FOUND]` → Vérifier friction
- `[ERROR]` / `[WARN]` → Investiguer

---

**Référence :** [`.claude/rules/scheduled-coordinator.md`](../../.claude/rules/scheduled-coordinator.md)
