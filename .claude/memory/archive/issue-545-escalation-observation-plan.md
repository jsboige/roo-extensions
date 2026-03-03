# Issue #545 - Plan d'Observation de l'Escalade Roo

**Date:** 2026-03-03
**Issue:** [MATURITY] Scheduler Roo - Graduation vers modes complex avec travail réel

---

## Objectif

Prouver que Roo peut compléter des tâches `-complex` avec des résultats concrets (commits, issues commentées, code modifié).

---

## Phase 1 : Tâches Assignées (3 tâches INTERCOM)

### Tâche A : Analyse patterns d'utilisation MCP
**Tag:** `[COMPLEX]`
**Complexité:** Moyenne (requiert coordination entre plusieurs outils MCP)
**Déclencheur d'escalade attendu:** `roosync_search` + `view_task_details` + synthèse
**Seuil d'échec -simple:** 2 échecs consécutifs

### Tâche B : Analyse workflows scheduler
**Tag:** `[COMPLEX]`
**Complexité:** Moyenne (comparaison structurelle de 2 fichiers)
**Déclencheur d'escalade attendu:** Analyse comparative + synthèse
**Seuil d'échec -simple:** 2 échecs consécutifs

### Tâche C : Documentation critères d'escalade
**Tag:** `[COMPLEX]`
**Complexité:** Moyenne (extraction JSON + organisation multi-sources)
**Déclencheur d'escalade attendu:** Parsing structuré + création doc
**Seuil d'échec -simple:** 2 échecs consécutifs

---

## Phase 2 : Observation de l'Escalade

### Métriques à Collecter

| Métrique | Méthode de collecte | Valeur cible |
|----------|---------------------|--------------|
| Nombre d'escalades -simple → -complex | Lecture traces Roo | ≥ 1 |
| Taux de succès après escalade | Résultats dans INTERCOM | > 80% |
| Temps d'exécution -simple vs -complex | Timestamps traces | -complex 2-3x plus lent |
| Qualité des résultats | Analyse humaine | -complex objectivement meilleur |

### Indicateurs de Réussite

- **Scénario A (Escalade réussie):**
  1. code-simple échoue sur une tâche
  2. orchestrator-simple détecte l'échec
  3. Escalade vers code-complex ou orchestrator-complex
  4. Tâche réussit en mode -complex

- **Scénario B (3 tâches réussies):**
  1. Au moins 3 tâches [COMPLEX] assignées
  2. Chacune produit un résultat visible (INTERCOM, fichier, rapport)
  3. 3/3 produisent des résultats exploitables

- **Scénario C (Gain de qualité):**
  1. Même tâche en -simple vs -complex
  2. -complex est objectivement meilleur sur 2/3 critères (complétude, précision, pertinence)

---

## Phase 3 : Démarrage Direct en -Complex

Pour les tâches de complexité connue, le workflow reconnaît le tag `[COMPLEX]` et démarre directement en mode -complex.

**Modification workflow executor:**
```
Si [TASK] avec tag [COMPLEX] ET date < 24h :
  Escalader vers orchestrator-complex (démarrage direct)
```

---

## Procédure d'Observation

### Avant le prochain scheduler tick (180 min)

1. **Vérifier les tâches INTERCOM** :
   ```bash
   tail -50 .claude/local/INTERCOM-myia-po-2023.md
   ```
   - Confirmer que les 3 tâches [COMPLEX] sont présentes

2. **Préparer la collecte de traces** :
   - Identifier le chemin des traces Roo
   - `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks`

### Pendant le scheduler tick

3. **Observer la délégation** :
   - orchestrator-simple lit l'INTERCOM
   - Détecte les tags [COMPLEX]
   - Soit délègue en -simple (échec attendu), soit escalade directement

4. **Surveiller les traces** :
   - Ouvrir `ui_messages.json` de la tâche scheduler
   - Chercher les patterns d'escalade :
     ```
     "escalating to code-complex"
     "delegating to orchestrator-complex"
     "[COMPLEX] tag detected"
     ```

### Après le scheduler tick

5. **Analyser les résultats** :
   - Lire l'INTERCOM pour les résultats des 3 tâches
   - Vérifier les traces pour confirmer l'escalade
   - Calculer les métriques (temps, succès, qualité)

6. **Documenter dans GitHub issue** :
   - Poster un commentaire avec les résultats
   - Mettre à jour la checklist de validation

---

## Critères de Validation de l'Issue

| Phase | Critère | Machine | Status |
|-------|---------|---------|--------|
| Phase 1 | 3 tâches INTERCOM assignées | ai-01 | ✅ DONE |
| Phase 1 | Tâches exécutées par Roo | 3 machines | ⏳ PENDING |
| Phase 2 | Au moins 1 escalade observée | - | ⏳ PENDING |
| Phase 2 | Métriques collectées | - | ⏳ PENDING |
| Phase 3 | Démarrage direct [COMPLEX] implémenté | - | ⏳ PENDING |
| Scénario A | Escalade réussie observée | - | ⏳ PENDING |
| Scénario B | 3/3 tâches réussies | - | ⏳ PENDING |
| Scénario C | Gain qualité mesuré | - | ⏳ PENDING |

---

## Notes Techniques

### Point d'insertion du tag [COMPLEX]

Le tag `[COMPLEX]` est reconnu à l'**Etape 1** du workflow executor :

```
Si [TASK] avec tag [COMPLEX] ET date < 24h :
  Escalader vers orchestrator-complex (démarrage direct en mode complex)
```

### Chaines d'escalade possibles

1. **orchestrator-simple** → détecte [COMPLEX] → **orchestrator-complex**
2. **orchestrator-simple** → délègue **code-simple** → échec → **code-complex**
3. **orchestrator-simple** → délègue **debug-simple** → échec → **debug-complex**
4. **orchestrator-complex** → délègue directement **code-complex**

### Fichiers de traces à surveiller

- `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\{TASK_ID}\ui_messages.json`
- `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\{TASK_ID}\api_conversation_history.json`

---

**Document créé par:** Claude Code (myia-po-2023)
**Pour:** Issue #545 - Scheduler Roo Graduation
