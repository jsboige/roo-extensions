# Ajustements Workflow Scheduler Roo - Propositions

**Date:** 2026-02-20
**Basé sur:** Audit scheduler myia-po-2026
**Tâche:** #487 - Maturation Roo + Préparation scheduler Claude Code

---

## Résumé

Suite à l'audit du scheduler Roo sur myia-po-2026, 3 obstacles majeurs ont été identifiés empêchant le calcul des métriques et la traçabilité des exécutions. Ce document propose des ajustements concrets pour résoudre ces problèmes.

---

## Obstacle 1: INTERCOM Non Mis à Jour

### Problème

Le scheduler ne semble pas écrire les messages DONE/MAINTENANCE/IDLE dans l'INTERCOM local, rendant impossible la traçabilité des exécutions.

### Cause Probable

1. **Délégation échoue:** L'étape 3 du workflow demande de déléguer l'écriture à `code-simple`, mais cette délégation échoue
2. **MCP win-cli désactivé:** Le workflow peut dépendre de win-cli pour l'écriture, mais ce MCP est désactivé
3. **Permissions insuffisantes:** Le mode `orchestrator-simple` n'a pas les permissions nécessaires pour écrire

### Proposition d'Ajustement A1: Simplifier l'Écriture INTERCOM

**Objectif:** Garantir que le scheduler écrit toujours dans l'INTERCOM

**Modification du workflow ([`.roo/scheduler-workflow-executor.md`](.roo/scheduler-workflow-executor.md:1)):**

```markdown
### Etape 3 : Rapporter dans INTERCOM

**MÉTHODE SIMPLIFIÉE (sans délégation):**

1. Lire le fichier INTERCOM complet avec `read_file`
2. Préparer le nouveau message (format ci-dessous)
3. Ajouter le message A LA FIN du contenu existant
4. Réécrire le fichier complet avec `write_to_file`

**Format du message:**

```markdown
## [{DATE}] roo -> claude-code [{DONE|MAINTENANCE|IDLE}]
### Bilan scheduler executeur

- Git pull : OK/erreur
- Git status : propre/dirty
- Build : OK/FAIL
- Tests : {X} pass / {Y} fail
- Taches executees : {N} (source: INTERCOM/GitHub #{num})
- Erreurs : {liste ou "aucune"}
- Escalades : {aucune ou vers {mode}}

---
```

**NOTE:** Si l'écriture échoue, essayer de déléguer à `code-simple` en dernier recours.
```

**Avantages:**
- ✅ Garantit l'écriture dans l'INTERCOM
- ✅ Évite les problèmes de délégation
- ✅ Compatible avec les permissions d'`orchestrator-simple`
- ✅ Fallback vers délégation si nécessaire

**Inconvénients:**
- ⚠️ `orchestrator-simple` doit avoir les permissions d'écriture (vérifier dans `.roomodes`)

### Proposition d'Ajustement A2: Vérifier les Permissions Mode

**Objectif:** S'assurer que `orchestrator-simple` peut écrire dans l'INTERCOM

**Action:** Vérifier la configuration du mode dans [`.roomodes`](.roomodes:1)

```yaml
orchestrator-simple:
  groups:
    - read      # ✅ Lecture de fichiers
    - mcp       # ✅ Utilisation MCPs
    - edit      # ❌ NÉCESSAIRE pour write_to_file
    - command   # ❌ NÉCESSAIRE pour execute_command
```

**Si `edit` est manquant:**

Ajouter `edit` aux groups d'`orchestrator-simple`:

```yaml
orchestrator-simple:
  groups:
    - read
    - mcp
    - edit      # AJOUTER
```

**Avantages:**
- ✅ Permet l'écriture directe sans délégation
- ✅ Simplifie le workflow
- ✅ Réduit le nombre de délégations

**Inconvénients:**
- ⚠️ Augmente les permissions du mode (risque de sécurité?)

### Proposition d'Ajustement A3: Activer win-cli (Alternative)

**Objectif:** Utiliser win-cli pour l'écriture INTERCOM

**Action:** Activer win-cli dans [`mcp_settings.json`](.roo/mcp_settings.json:1)

```json
"win-cli": {
  "disabled": false,
  "command": "cmd",
  "args": ["/c", "npx", "-y", "@simonb97/server-win-cli"],
  "env": {}
}
```

**Avantages:**
- ✅ Compatible avec le workflow actuel
- ✅ Pas besoin de modifier les permissions mode
- ✅ Utilise un MCP existant

**Inconvénients:**
- ⚠️ Dépendance supplémentaire (win-cli)
- ⚠️ Complexité accrue

---

## Obstacle 2: Indexation Sémantique Incomplète

### Problème

La recherche sémantique trouve des tâches mais l'index ne contient pas les données complètes, rendant impossible l'accès aux traces historiques via `get_raw_conversation`.

### Cause Probable

1. **Indexation partielle:** L'indexation sémantique (Qdrant) stocke des embeddings mais pas le contenu complet
2. **Cache SQLite incomplet:** Le cache contient les métadonnées mais pas les conversations complètes
3. **Tâches archivées:** Les tâches scheduler anciennes peuvent être archivées et non indexées

### Proposition d'Ajustement B1: Reconstruire l'Index Sémantique

**Objectif:** S'assurer que l'index contient les données complètes

**Action:** Exécuter la commande de reconstruction

```bash
# Via MCP roo-state-manager
roosync_indexing(action: "rebuild", force_rebuild: true)

# Via CLI (alternative)
cd mcps/internal/servers/roo-state-manager
npm run rebuild-index
```

**Avantages:**
- ✅ Index complet et à jour
- ✅ Accès aux traces historiques
- ✅ Permet le calcul des métriques

**Inconvénients:**
- ⚠️ Peut prendre du temps (selon nombre de tâches)
- ⚠️ Consomme des ressources

### Proposition d'Ajustement B2: Implémenter un Système de Métriques Dédie

**Objectif:** Stocker les métriques scheduler dans un fichier dédié, indépendant de l'index sémantique

**Structure proposée:**

```markdown
# Scheduler Metrics - myia-po-2026

## Configuration

- Machine: myia-po-2026
- Mode: orchestrator-simple
- Intervalle: 180 minutes
- Dernière mise à jour: 2026-02-20T10:43:00Z

## Exécutions

| Date | Task ID | Mode | Résultat | Durée | Escalades | Outils MCP | Tâches exécutées |
|------|----------|------|----------|--------|------------|-------------|-------------------|
| 2026-02-20T10:17:00 | 019c7a8d... | orchestrator-simple | SUCCESS | 15m | 0 | gh, git | Build+Tests |
| 2026-02-20T07:17:00 | 019c6b41... | orchestrator-simple | SUCCESS | 12m | 1 | gh, git | GitHub #487 |
| 2026-02-20T04:17:00 | 019c6dd5... | orchestrator-simple | FAIL | 5m | 0 | git | Build échoue |

## Statistiques Globales

- **Taux de succès:** 66.7% (2/3)
- **Taux d'escalade:** 33.3% (1/3)
- **Durée moyenne:** 10.7m
- **Outils MCP les plus utilisés:** git (100%), gh (66.7%)
- **Types de tâches:** Build+Tests (66.7%), GitHub (33.3%)

## Tendance

- **Succès:** ↗ Amélioration (50% → 66.7%)
- **Escalades:** ↘ Diminution (50% → 33.3%)
- **Durée:** → Stable (10-15m)
```

**Implémentation:**

1. Créer le fichier `outputs/scheduler-metrics-{MACHINE}.md`
2. Mettre à jour après chaque exécution scheduler
3. Utiliser un script pour calculer les statistiques automatiquement

**Avantages:**
- ✅ Métriques facilement accessibles
- ✅ Indépendant de l'index sémantique
- ✅ Historique des exécutions
- ✅ Facilite l'audit et l'optimisation

**Inconvénients:**
- ⚠️ Nécessite une mise à jour manuelle ou automatique du fichier
- ⚠️ Duplication des données (métriques dans fichier + traces dans index)

### Proposition d'Ajustement B3: Taguer les Tâches Scheduler

**Objectif:** Faciliter la recherche et le filtrage des tâches scheduler

**Action:** Ajouter un tag spécifique aux tâches scheduler

**Implémentation dans le workflow:**

```markdown
### Etape 3 : Rapporter dans INTERCOM

**Ajouter un tag au message:**

```markdown
## [{DATE}] roo -> claude-code [{DONE|MAINTENANCE|IDLE}] [SCHEDULER-EXECUTION]
### Bilan scheduler executeur

...
```

**Avantages:**
- ✅ Facile à filtrer dans l'INTERCOM
- ✅ Facile à rechercher via `roosync_search`
- ✅ Permet d'identifier rapidement les exécutions scheduler

**Inconvénients:**
- ⚠️ Nécessite une modification du workflow

---

## Obstacle 3: Logs VSCode Non Verbeux

### Problème

Les logs VSCode ne contiennent pas d'informations détaillées sur les tâches scheduler, rendant difficile le diagnostic des problèmes.

### Cause Probable

1. **Niveau de logging trop bas:** Le scheduler n'est pas configuré pour logger les événements de création/complétion de tâches
2. **Logging désactivé:** Le logging peut être désactivé pour les performances
3. **Logs non implémentés:** Le scheduler peut ne pas logger ces événements

### Proposition d'Ajustement C1: Activer le Logging Verbeux Scheduler

**Objectif:** Tracer les exécutions scheduler dans les logs VSCode

**Action:** Modifier la configuration du scheduler dans [`.roo/schedules.json`](.roo/schedules.json:1)

```json
{
  "schedules": [
    {
      "id": "1770852600244",
      "name": "Claude-Code Assistant",
      "mode": "orchestrator-simple",
      "taskInstructions": "...",
      "scheduleType": "time",
      "timeInterval": "180",
      "timeUnit": "minute",
      "logging": {
        "enabled": true,
        "level": "verbose",
        "logTaskCreation": true,
        "logTaskCompletion": true,
        "logTaskFailure": true,
        "logEscalation": true,
        "logMCPUsage": true
      },
      ...
    }
  ]
}
```

**Format des logs proposé:**

```
[2026-02-20T10:17:00.764Z] [SCHEDULER] Task created: 019c7a8d-844c-744c-a2b0-17916de6faf8
[2026-02-20T10:17:00.764Z] [SCHEDULER] Mode: orchestrator-simple
[2026-02-20T10:17:00.764Z] [SCHEDULER] Workflow started
[2026-02-20T10:17:05.123Z] [SCHEDULER] Step 1: Git pull + INTERCOM read - SUCCESS
[2026-02-20T10:17:10.456Z] [SCHEDULER] Step 2: Execute tasks - SUCCESS (Build+Tests)
[2026-02-20T10:17:15.789Z] [SCHEDULER] Step 3: Report to INTERCOM - SUCCESS
[2026-02-20T10:17:15.789Z] [SCHEDULER] Task completed: 019c7a8d-844c-744c-a2b0-17916de6faf8 (15m)
```

**Avantages:**
- ✅ Tracer les exécutions scheduler
- ✅ Faciliter le diagnostic des problèmes
- ✅ Permet de calculer les métriques à partir des logs

**Inconvénients:**
- ⚠️ Augmente la taille des logs
- ⚠️ Peut impacter les performances (si très verbeux)

### Proposition d'Ajustement C2: Implémenter un Fichier de Log Scheduler Dédie

**Objectif:** Stocker les logs scheduler dans un fichier dédié, séparé des logs VSCode

**Structure proposée:**

```markdown
# Scheduler Log - myia-po-2026

## 2026-02-20

### 10:17:00 - Exécution #1

**Task ID:** 019c7a8d-844c-744c-a2b0-17916de6faf8
**Mode:** orchestrator-simple
**Durée:** 15m

**Étapes:**
1. Git pull + INTERCOM read - SUCCESS (5s)
2. Execute tasks - SUCCESS (10m)
   - Build: OK (8m)
   - Tests: 1661/1661 pass (2m)
3. Report to INTERCOM - SUCCESS (5s)

**Résultat:** SUCCESS
**Escalades:** 0
**Outils MCP:** git, gh
**Erreurs:** Aucune

---

### 07:17:00 - Exécution #2

**Task ID:** 019c6b41-e68f-74ec-a363-a44c1538f6a3
**Mode:** orchestrator-simple
**Durée:** 12m

**Étapes:**
1. Git pull + INTERCOM read - SUCCESS (5s)
2. Execute tasks - SUCCESS (7m)
   - GitHub #487: Claimed and executed
3. Report to INTERCOM - SUCCESS (5s)

**Résultat:** SUCCESS
**Escalades:** 1 (orchestrator-simple → orchestrator-complex)
**Outils MCP:** git, gh
**Erreurs:** Aucune

---

## Statistiques

- **Exécutions totales:** 2
- **Taux de succès:** 100%
- **Taux d'escalade:** 50%
- **Durée moyenne:** 13.5m
```

**Implémentation:**

1. Créer le fichier `outputs/scheduler-log-{MACHINE}.md`
2. Mettre à jour après chaque exécution scheduler
3. Utiliser un script pour formater les logs automatiquement

**Avantages:**
- ✅ Logs dédiés au scheduler
- ✅ Facile à lire et analyser
- ✅ Indépendant des logs VSCode
- ✅ Permet de calculer les métriques

**Inconvénients:**
- ⚠️ Nécessite une mise à jour manuelle ou automatique du fichier
- ⚠️ Duplication des logs (dans fichier + logs VSCode)

---

## Recommandations Prioritaires

### Priorité 1: Résoudre l'Écriture INTERCOM (A1 ou A2)

**Action immédiate:**

1. Vérifier les permissions d'`orchestrator-simple` dans [`.roomodes`](.roomodes:1)
2. Si `edit` est manquant, l'ajouter
3. Modifier le workflow pour utiliser l'écriture directe (A1)
4. Tester manuellement l'étape 3 du workflow

**Critères de succès:**
- ✅ Le scheduler écrit dans l'INTERCOM après chaque exécution
- ✅ Les messages DONE/MAINTENANCE/IDLE sont visibles
- ✅ Le format des messages est correct

### Priorité 2: Activer le Logging Verbeux (C1)

**Action immédiate:**

1. Modifier la configuration du scheduler dans [`.roo/schedules.json`](.roo/schedules.json:1)
2. Ajouter la section `logging` avec les options verbeuses
3. Redémarrer VS Code pour appliquer les changements
4. Attendre la prochaine exécution scheduler (ou forcer une exécution)

**Critères de succès:**
- ✅ Les logs VSCode contiennent les événements scheduler
- ✅ Les logs sont lisibles et structurés
- ✅ Les métriques peuvent être extraites des logs

### Priorité 3: Implémenter le Système de Métriques (B2)

**Action court terme (1-2 semaines):**

1. Créer le fichier `outputs/scheduler-metrics-{MACHINE}.md`
2. Implémenter un script pour mettre à jour les métriques automatiquement
3. Intégrer la mise à jour des métriques dans le workflow scheduler
4. Valider que les métriques sont correctes

**Critères de succès:**
- ✅ Le fichier de métriques existe et est à jour
- ✅ Les métriques sont calculées correctement
- ✅ Les statistiques globales sont cohérentes

---

## Plan d'Implémentation

### Semaine 1: Résolution des Obstacles Immédiats

- [ ] **Jour 1-2:** Vérifier et corriger les permissions mode (A2)
- [ ] **Jour 3-4:** Modifier le workflow pour l'écriture directe (A1)
- [ ] **Jour 5:** Tester l'écriture INTERCOM manuellement

### Semaine 2: Logging et Métriques

- [ ] **Jour 1-2:** Activer le logging verbeux (C1)
- [ ] **Jour 3-4:** Créer le fichier de métriques (B2)
- [ ] **Jour 5:** Intégrer la mise à jour des métriques dans le workflow

### Semaine 3: Validation et Déploiement

- [ ] **Jour 1-2:** Valider que les métriques sont collectées correctement
- [ ] **Jour 3-4:** Audit des 6 machines avec le nouveau système
- [ ] **Jour 5:** Documenter les résultats et les ajustements

---

## Conclusion

### Résumé

Trois ajustements majeurs sont proposés pour résoudre les obstacles identifiés lors de l'audit:

1. **Résoudre l'écriture INTERCOM** (A1 ou A2) - Priorité 1
2. **Activer le logging verbeux** (C1) - Priorité 2
3. **Implémenter le système de métriques** (B2) - Priorité 3

### Bénéfices Attendus

- ✅ Traçabilité complète des exécutions scheduler
- ✅ Métriques facilement accessibles et calculables
- ✅ Diagnostic facilité des problèmes
- ✅ Optimisation possible du scheduler

### Prochaines Étapes

1. Implémenter les ajustements prioritaires (A1/A2, C1, B2)
2. Valider que les métriques sont collectées correctement
3. Audit des 6 machines avec le nouveau système
4. Préparer le design du scheduler Claude Code (Phase 3)

---

**Document généré par:** Roo Code (mode code-complex)
**Date:** 2026-02-20
**Tâche:** #487 - Maturation Roo + Préparation scheduler Claude Code
