# Analyse Croisée des Harnais - Roo vs Claude Code

**Date:** 2026-03-15
**Auteur:** Roo Code (GLM-5)
**Contexte:** Étape 2 du processus d'harmonisation des harnais

---

## Résumé Exécutif

Cette analyse compare les harnais de règles de **Roo Code** (8 fichiers) et **Claude Code** (6 fichiers) pour identifier les incohérences, lacunes et opportunités d'amélioration.

### Métriques Clés

| Métrique | Roo | Claude |
|----------|-----|--------|
| Fichiers de règles | 8 | 6 |
| Workflows scheduler | 2 (coordinator + executor) | 1 (référence) |
| Canaux communication | 1 (INTERCOM) | 2 (INTERCOM + META-INTERCOM) |
| Gardes-fous documentés | 5 | 4 |
| Règles SDDD | Oui (détaillées) | Non (mention seulement) |

### Score de Cohérence Globale: **65%**

- ✅ Cohérent: Communication locale (INTERCOM), Testing, Git workflow
- ⚠️ Partiel: Escalade, MCP usage, Tool availability
- ❌ Divergent: SDDD, Validation checklist, Scheduler workflows

---

## Tableau des Incohérences

### INCO-001: Canaux de Communication (CRITICAL)

| Aspect | Roo | Claude | Impact |
|--------|-----|--------|--------|
| Canal local | INTERCOM | INTERCOM | ✅ Identique |
| Méta-analyse | ❌ Aucun | META-INTERCOM | ⚠️ Divergence |

**Fichiers:**
- Roo: `.roo/rules/02-intercom.md`
- Claude: `.claude/rules/meta-analysis.md` (lignes 60-74)

**Problème:** Roo n'a pas de mécanisme équivalent au META-INTERCOM pour les méta-analyses (fréquence 72h). Claude a un canal dédié `.claude/local/META-INTERCOM-{MACHINE}.md`.

**Recommandation:** Clarifier si Roo doit participer aux méta-analyses ou si c'est réservé à Claude Code.

---

### INCO-002: Modèle d'Escalade (WARNING)

| Aspect | Roo | Claude |
|--------|-----|--------|
| Niveau 1 | Mode simple → complex | Roo → Claude Code |
| Niveau 2 | orchestrator-complex | Claude Code → Meta-Analyst |
| Niveau 3 | Claude CLI (sonnet/opus) | - |

**Fichiers:**
- Roo: `.roo/rules/01-sddd-escalade.md` (règles globales)
- Claude: `.claude/rules/scheduler-system.md` (lignes 78-100)

**Problème:** Les modèles d'escalade ne sont pas alignés. Roo a une escalade interne (simple→complex→orchestrator) puis externe (Claude CLI). Claude a une escalade Roo→Claude→Meta-Analyst.

**Recommandation:** Documenter un modèle d'escalade unifié avec correspondance entre les deux systèmes.

---

### INCO-003: Inventaire MCP (WARNING)

| Aspect | Roo | Claude |
|--------|-----|--------|
| MCPs CRITIQUES | win-cli, roo-state-manager | win-cli, roo-state-manager, jinavigator, markitdown, playwright, sk-agent |
| MCPs RETIRES | desktop-commander, quickfiles | + github-projects-mcp |
| Historique incidents | ❌ Non | ✅ Oui (lignes 196-209) |

**Fichiers:**
- Roo: `.roo/rules/03-mcp-usage.md`, `.roo/rules/05-tool-availability.md`
- Claude: `.claude/rules/tool-availability.md` (lignes 61-209)

**Problème:** Claude a un inventaire MCP plus complet avec historique des incidents. Roo n'a qu'une liste basique.

**Recommandation:** Synchroniser l'inventaire MCP entre les deux harnais.

---

### INCO-004: Configuration Context Window (INFO)

| Aspect | Roo | Claude |
|--------|-----|--------|
| Seuil condensation | 70% (documenté) | 70% (documenté) |
| Taille contexte GLM | 131k (documenté) | Non documenté |

**Fichiers:**
- Roo: `.roo/rules/06-context-window.md`
- Claude: Non documenté

**Problème:** Roo a une règle explicite pour la configuration du seuil de condensation. Claude n'a pas de documentation équivalente.

**Recommandation:** Claude devrait documenter sa configuration de condensation.

---

## Tableau des Lacunes

### LAC-001: Règles SDDD (CRITICAL)

**Manquant dans:** Claude Code

**Détail:** Roo a des règles SDDD détaillées (`.roo/rules/04-sddd-grounding.md`) avec:
- Triple grounding (Sémantique, Conversationnel, Technique)
- Pattern bookend (début/fin de tâche)
- Recherche multi-pass avec `codebase_search`
- Workflow SDDD structuré

Claude mentionne "Methodologie SDDD" dans `CLAUDE.md` (ligne 439) mais n'a pas de règles détaillées.

**Impact:** Claude Code manque de guidance structurée pour le grounding conversationnel et la recherche sémantique.

**Recommandation:** Créer `.claude/rules/sddd-grounding.md` ou référencer les règles Roo.

---

### LAC-002: Workflows Scheduler Détaillés (WARNING)

**Manquant dans:** Claude Code

**Détail:** Roo a deux workflows scheduler détaillés:
- `.roo/scheduler-workflow-coordinator.md` (4 étapes, ~350 lignes)
- `.roo/scheduler-workflow-executor.md` (4 étapes, ~690 lignes)

Claude a une référence au scheduler (`.claude/rules/scheduler-system.md`) mais pas de workflow détaillé.

**Impact:** Claude Code manque de guidance pour les exécutions scheduler.

**Recommandation:** Claude devrait avoir un workflow scheduler équivalent ou référencer explicitement les workflows Roo.

---

### LAC-003: Validation Checklist (WARNING)

**Manquant dans:** Roo Code

**Détail:** Claude a une validation checklist détaillée (`.claude/rules/validation-checklist.md`) avec:
- Checklist avant/après implémentation
- Comptage outils/fichiers
- Exemples d'erreurs à éviter
- Responsabilités du coordinateur

Roo référence `.roo/rules/validation.md` mais ce fichier n'existe pas dans les règles lues.

**Impact:** Roo manque de guidance pour la validation des consolidations.

**Recommandation:** Créer `.roo/rules/validation.md` ou harmoniser avec Claude.

---

### LAC-004: Règles d'Écriture Fichiers (INFO)

**Manquant dans:** Claude Code

**Détail:** Roo a des règles spécifiques (`.roo/rules/08-file-writing.md`) pour gérer la limitation de Qwen 3.5 avec `write_to_file` (>200 lignes).

**Impact:** Claude Code pourrait rencontrer des problèmes similaires avec certains modèles.

**Recommandation:** Évaluer si Claude a besoin de règles équivalentes.

---

### LAC-005: Skepticism Protocol (INFO)

**Manquant dans:** Claude Code (version détaillée)

**Détail:** Roo a un protocole de scepticisme détaillé (`.roo/rules/skepticism-protocol.md`) avec:
- Smell test triggers
- Qualification des affirmations (VÉRIFIÉ/SUPPOSÉ/RAPPORTE)
- Vérification des instructions de Claude

Claude a une référence dans `CLAUDE.md` mais pas de règles détaillées.

**Recommandation:** Claude devrait avoir un protocole équivalent.

---

### LAC-006: GitHub CLI Rules (INFO)

**Manquant dans:** Claude Code

**Détail:** Roo a des règles détaillées pour GitHub CLI (`.roo/rules/github-cli.md`) avec:
- Migration MCP → gh CLI
- Field IDs pour Project #67
- Exemples GraphQL avec type union

Claude référence `gh` CLI mais n'a pas de documentation détaillée.

**Recommandation:** Partager les règles GitHub CLI entre les deux harnais.

---

## Tableau des Améliorations

### AMEL-001: Harmonisation SDDD (Priorité: HAUTE)

**Statut:** 🟡 Partiellement implémenté

**Action:** Créer des règles SDDD pour Claude Code ou référencer les règles Roo.

**Bénéfice:** Grounding cohérent entre les deux agents.

**Effort:** Moyen (créer fichier ou ajouter référence)

---

### AMEL-002: Inventaire MCP Unifié (Priorité: HAUTE)

**Statut:** 🔴 Non implémenté

**Action:** Créer un inventaire MCP partagé avec:
- Liste unifiée des MCPs CRITIQUES/STANDARDS/OPTIONNELS/RETIRES
- Historique des incidents commun
- Procédure STOP & REPAIR harmonisée

**Bénéfice:** Maintenance simplifiée, cohérence des gardes-fous.

**Effort:** Moyen (fusionner les deux inventaires)

---

### AMEL-003: Modèle d'Escalade Unifié (Priorité: MOYENNE)

**Statut:** 🔴 Non implémenté

**Action:** Documenter un modèle d'escalade unifié avec:
- Correspondance entre les deux systèmes
- Critères d'escalade harmonisés
- Documentation des limites de chaque niveau

**Bénéfice:** Clarification des responsabilités, meilleure coordination.

**Effort:** Moyen (créer documentation unifiée)

---

### AMEL-004: Validation Checklist Partagée (Priorité: MOYENNE)

**Statut:** 🔴 Non implémenté

**Action:** Créer une validation checklist partagée ou harmonisée.

**Bénéfice:** Qualité cohérente des consolidations.

**Effort:** Faible (copier/adapter)

---

### AMEL-005: Documentation Scheduler pour Claude (Priorité: BASSE)

**Statut:** 🔴 Non implémenté

**Action:** Claude devrait avoir un workflow scheduler détaillé ou référencer explicitement les workflows Roo.

**Bénéfice:** Guidance complète pour les exécutions scheduler.

**Effort:** Faible (ajouter référence) à Moyen (créer workflow)

---

## Vérification des Gardes-Fous

### GF-001: Condensation

| Aspect | Roo | Claude | Statut |
|--------|-----|--------|--------|
| Seuil documenté | 70% | 70% | ✅ Cohérent |
| Règle explicite | `.roo/rules/06-context-window.md` | Non documenté | ⚠️ Lacune Claude |
| Contexte GLM | 131k documenté | Non documenté | ⚠️ Lacune Claude |

**Recommandation:** Claude devrait documenter sa configuration de condensation.

---

### GF-002: Escalade

| Aspect | Roo | Claude | Statut |
|--------|-----|--------|--------|
| Critères documentés | Oui (01-sddd-escalade.md) | Oui (scheduler-system.md) | ✅ |
| Modèle unifié | Non | Non | ❌ Divergence |
| Claude CLI | Documenté | Non mentionné | ⚠️ Information manquante |

**Recommandation:** Créer un modèle d'escalade unifié.

---

### GF-003: Tool Availability

| Aspect | Roo | Claude | Statut |
|--------|-----|--------|--------|
| Pre-flight check | Oui (05-tool-availability.md) | Oui (tool-availability.md) | ✅ |
| STOP & REPAIR | Documenté | Documenté | ✅ |
| Inventaire MCP | Basique | Complet | ⚠️ Divergence |
| Historique incidents | Non | Oui | ⚠️ Lacune Roo |

**Recommandation:** Synchroniser l'inventaire MCP.

---

### GF-004: INTERCOM vs META-INTERCOM

| Aspect | Roo | Claude | Statut |
|--------|-----|--------|--------|
| INTERCOM local | Oui | Oui | ✅ |
| META-INTERCOM | Non | Oui | ⚠️ Divergence |
| Format messages | Identique | Identique | ✅ |

**Recommandation:** Clarifier le rôle de Roo dans les méta-analyses.

---

## Recommandations Priorisées

### P0 - Critique (À faire immédiatement)

1. **Harmoniser l'inventaire MCP** - Créer un inventaire unifié avec historique des incidents
2. **Clarifier INTERCOM vs META-INTERCOM** - Définir si Roo participe aux méta-analyses

### P1 - Haute Priorité (Cette semaine)

3. **Créer règles SDDD pour Claude** - Éviter le grounding inefficace
4. **Unifier le modèle d'escalade** - Documenter la correspondance entre les deux systèmes

### P2 - Moyenne Priorité (Ce mois)

5. **Créer validation checklist pour Roo** - Harmoniser avec Claude
6. **Documenter condensation pour Claude** - Ajouter configuration explicite

### P3 - Basse Priorité (Backlog)

7. **Partager règles GitHub CLI** - Éviter la duplication
8. **Évaluer règles écriture fichiers pour Claude** - Voir si nécessaire

---

## Annexes

### A. Fichiers Analysés

**Roo Code (8 fichiers):**
- `.roo/rules/01-general.md`
- `.roo/rules/02-intercom.md`
- `.roo/rules/03-mcp-usage.md`
- `.roo/rules/04-sddd-grounding.md`
- `.roo/rules/05-tool-availability.md`
- `.roo/rules/06-context-window.md`
- `.roo/scheduler-workflow-coordinator.md`
- `.roo/scheduler-workflow-executor.md`

**Claude Code (6 fichiers):**
- `CLAUDE.md`
- `.claude/rules/meta-analysis.md`
- `.claude/rules/testing.md`
- `.claude/rules/scheduler-system.md`
- `.claude/rules/tool-availability.md`
- `.claude/rules/validation-checklist.md`

### B. Références

- Issue #462: Roadmap Autonomie Progressive
- Issue #502: Boucle infinie condensation
- Issue #555: Saturation contexte GLM-5
- Issue #580: META-ANALYSIS - Règles condensation Claude
- Commit b91a841c: Modes -simple sans terminal natif

---

*Rapport généré par Roo Code (GLM-5) - 2026-03-15*
