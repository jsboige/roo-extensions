# Analyse du Harnais - myia-po-2026

**Date d'analyse :** 2026-03-22
**Machine :** myia-po-2026
**Analyse :** `.roo/rules/` et `.claude/rules/`

---

## Vue d'ensemble

Cette analyse examine les règles et configurations des harnais Roo et Claude Code pour identifier les frictions, incohérences, et opportunités d'amélioration.

---

## Harnais Roo - `.roo/rules/`

### Règles Présentes (21 fichiers)

| Fichier | Description | Statut |
|---------|-------------|--------|
| 01-general.md | Règles générales | ✅ Actif |
| 02-intercom.md | Protocole de communication locale | ✅ Actif |
| 03-mcp-usage.md | Utilisation des MCPs | ✅ Actif |
| 04-sddd-grounding.md | Grounding conversationnel | ✅ Actif |
| 05-tool-availability.md | Vérification des outils | ✅ Actif |
| 06-context-window.md | Configuration contexte/condensation | ✅ Actif |
| 07-orchestrator-delegation.md | Delegation orchestrator | ✅ Actif |
| 08-file-writing.md | Règle d'écriture de fichiers | ✅ Actif |
| 09-github-checklists.md | Checklists GitHub | ✅ Actif |
| 10-ci-guardrails.md | Garde-fous CI | ✅ Actif |
| 11-incident-history.md | Historique des incidents | ✅ Actif |
| 12-machine-constraints.md | Contraintes par machine | ✅ Actif |
| 13-test-success-rates.md | Taux de succès tests | ✅ Actif |
| 14-tdd-recommended.md | TDD recommandé | ✅ Actif |
| 15-coordinator-responsibilities.md | Responsabilités coordinateur | ✅ Actif |
| 16-no-tools-warnings.md | Warnings NoTools | ✅ Actif |
| 17-friction-protocol.md | Protocole de friction | ✅ Actif |
| 18-meta-analysis.md | Protocole meta-analyse | ✅ Actif |
| 19-github-cli.md | Règles GitHub CLI | ✅ Actif |
| 20-skepticism-protocol.md | Scepticisme raisonnable | ✅ Actif |
| 21-validation.md | Règles de validation | ✅ Actif |

### Observations

- **Couverture complète** : Toutes les règles essentielles sont présentes
- **Documentation à jour** : Les règles incluent des références aux issues GitHub
- **Versioning** : Les règles ont des numéros de version et dates de mise à jour

---

## Harnais Claude - `.claude/rules/`

### Règles Présentes (10 fichiers)

| Fichier | Description | Correspondance Roo |
|---------|-------------|-------------------|
| agents-architecture.md | Architecture des agents | ❌ Unique à Claude |
| ci-guardrails.md | Garde-fous CI | ✅ Similaire à 10-ci-guardrails.md |
| delegation.md | Delegation | ✅ Similaire à 07-orchestrator-delegation.md |
| github-cli.md | Règles GitHub CLI | ✅ Similaire à 19-github-cli.md |
| intercom-protocol.md | Protocole INTERCOM | ✅ Similaire à 02-intercom.md |
| sddd-conversational-grounding.md | Grounding | ✅ Similaire à 04-sddd-grounding.md |
| skepticism-protocol.md | Scepticisme | ✅ Similaire à 20-skepticism-protocol.md |
| test-success-rates.md | Taux de succès tests | ✅ Similaire à 13-test-success-rates.md |
| tool-availability.md | Disponibilité outils | ✅ Similaire à 05-tool-availability.md |
| validation.md | Validation | ✅ Similaire à 21-validation.md |

### Observations

- **Moins de règles** : 10 fichiers vs 21 pour Roo
- **Absence de règles spécifiques** :
  - Pas de règle sur le contexte/condensation (06-context-window.md)
  - Pas de règle sur les fichiers volumineux (08-file-writing.md)
  - Pas de règle sur l'historique des incidents (11-incident-history.md)
  - Pas de règle sur les contraintes machines (12-machine-constraints.md)
  - Pas de règle TDD (14-tdd-recommended.md)
  - Pas de règle sur les responsabilités coordinateur (15-coordinator-responsibilities.md)
  - Pas de règle sur les warnings NoTools (16-no-tools-warnings.md)
  - Pas de règle sur le protocole friction (17-friction-protocol.md)
  - Pas de règle sur le meta-analyse (18-meta-analysis.md)

---

## Frictions et Incohérences Identifiées

### 1. Déséquilibre des Règles

**Problème :** Le harnais Claude a significativement moins de règles que le harnais Roo.

**Impact :**
- Moins de guidance pour les agents Claude Code
- Risque d'incohérences dans les pratiques
- Documentation moins complète

**Recommandation :**
- Syncroniser les règles entre les deux harnais
- Documenter les différences intentionnelles

### 2. Absence de Règle Contexte/Condensation

**Problème :** `.claude/rules/` n'a pas d'équivalent à `06-context-window.md`.

**Impact :**
- Risque de saturation du contexte avec Claude Code
- Pas de guidance sur le seuil de condensation (80% recommandé)

**Recommandation :**
- Créer `context-window.md` pour Claude Code
- Documenter le seuil de 80% et la taille réelle GLM (131k tokens)

### 3. Worktrees et Submodules

**Problème :** Les worktrees Claude ne contiennent pas les submodules.

**Impact :**
- Blocage des tâches nécessitant `mcps/internal/servers/roo-state-manager`
- Temps perdu en diagnostic au lieu d'exécution

**Recommandation :**
- Ajouter une règle sur l'initialisation des submodules
- Ajouter une vérification pre-flight dans le workflow worker

### 4. Erreurs new_task

**Problème :** Des erreurs `Roo tried to use new_task without value for required parameter` ont été observées.

**Impact :**
- Échec de delegation
- Perte de temps en retry

**Recommandation :**
- Documenter ce bug dans l'historique des incidents
- Ajouter une vérification dans les rules de delegation

---

## Recommandations d'Amélioration

### Priorité Haute

1. **Créer `context-window.md` pour Claude Code**
   - Documenter le seuil de condensation 80%
   - Expliquer la taille réelle GLM (131k tokens)
   - Références aux issues #502, #555, #736, #737

2. **Initialisation des submodules**
   - Ajouter une règle dans `.claude/rules/`
   - Workflow pre-flight pour vérifier les submodules
   - Documentation des worktrees

3. **Syncronisation des règles**
   - Identifier les règles Roo sans équivalent Claude
   - Décider si elles doivent être syncronisées ou documentées comme spécifiques

### Priorité Moyenne

4. **Documentation des erreurs new_task**
   - Ajouter dans `incident-history.md`
   - Proposer des corrections

5. **Règle de friction**
   - Documenter les frictions découvertes
   - Protocole de signalement

---

## Conclusion

L'analyse du harnais révèle un déséquilibre entre les règles Roo (21 fichiers) et Claude (10 fichiers). Les principales frictions identifiées sont :

1. **Absence de règle contexte/condensation** pour Claude Code
2. **Worktrees sans submodules** bloquant l'exécution
3. **Erreurs de delegation new_task** à documenter

**Date de la prochaine analyse :** 2026-03-25 (72h)
