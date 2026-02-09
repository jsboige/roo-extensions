# Scheduler Issues & Fixes - Session 2026-02-09

**Date:** 2026-02-09 16:20 UTC
**Machine:** myia-po-2024

---

## ❌ Problèmes Identifiés lors de la Première Exécution

### Tâche Scheduler : `019c42f8-62bf-76ec-a39c-88594224da23`
**Timestamp:** 15:15 UTC
**Mode:** `orchestrator-simple`
**Résultat:** ❌ PARTIELLEMENT ÉCHOUÉ

---

## 🔴 Problème 1 : MCP win-cli Manquant

### Symptôme
```
Error accessing MCP resource:
No connection found for server: win-cli
```

### Cause Racine
Le MCP `win-cli` est **désactivé** dans `mcp_settings.json` :
```json
"win-cli": {
  "disabled": true,
  ...
}
```

### Impact
- Roo ne peut pas exécuter `git status`
- Roo ne peut pas écrire dans `.claude/local/INTERCOM-myia-po-2024.md`
- Le rapport IDLE n'a pas été écrit dans INTERCOM

### Solution

**Option A : Activer win-cli (Recommandé pour scheduler)**
```json
"win-cli": {
  "disabled": false,
  "command": "cmd",
  "args": ["/c", "npx", "-y", "@simonb97/server-win-cli"],
  ...
}
```

**Option B : Modifier le workflow scheduler**
- Utiliser les outils natifs Roo (readFile, writeFile) au lieu de win-cli
- Retirer la vérification `git status` (non critique pour scheduler IDLE)
- Simplifier le rapport INTERCOM

---

## 🔴 Problème 2 : orchestrator-simple Essaie d'Exécuter Directement

### Symptôme
```
Je n'ai pas accès à l'outil `execute_command` en mode orchestrator-simple
```

### Cause Racine
Le mode `orchestrator-simple` a les `groups: ["read", "mcp"]` dans `.roomodes` :
- ✅ Peut lire des fichiers
- ✅ Peut utiliser MCPs
- ❌ **NE PEUT PAS** exécuter des commandes (pas de "command" group)
- ❌ **NE PEUT PAS** écrire des fichiers (pas de "edit" group)

Mais les instructions du scheduler lui disent :
```
**Etape 2 : Verifier l'etat du workspace**
- `git status` : changements non commites ?
```

### Impact
- `orchestrator-simple` essaie d'exécuter `git status` directement → Erreur
- `orchestrator-simple` essaie d'écrire dans INTERCOM directement → Erreur
- Il devrait **déléguer** à `code-simple` ou `debug-simple` via `new_task`

### Solution

**Option A : Corriger les instructions scheduler (Recommandé)**

Modifier `.roo/schedules.json` > `taskInstructions` :

```markdown
**Etape 2 : Verifier l'etat du workspace**
- Lire `.claude/local/INTERCOM-myia-po-2024.md` pour l'état récent
- SI des modifications TypeScript sont mentionnées : déléguer validation à code-simple

**Etape 4 : Rapporter le resultat**
- Déléguer l'écriture du rapport à code-simple via new_task :
  - Tâche : "Écrire message IDLE dans .claude/local/INTERCOM-myia-po-2024.md"
  - Format fourni dans le prompt
```

**Option B : Changer le mode scheduler**

Utiliser `code-simple` au lieu de `orchestrator-simple` :
```json
{
  "mode": "code-simple",
  ...
}
```

Avantages :
- ✅ `code-simple` a accès à "edit" group → peut écrire dans INTERCOM
- ✅ `code-simple` a accès à "command" group → peut exécuter git status
- ❌ Moins adapté pour orchestration multi-étapes

---

## 🔴 Problème 3 : Rapport INTERCOM Non Écrit

### Symptôme
Aucun message `[IDLE]` de Roo dans `.claude/local/INTERCOM-myia-po-2024.md` après exécution.

### Cause
Combinaison des problèmes 1 et 2 :
- win-cli manquant → pas d'accès write_file via MCP
- orchestrator-simple sans "edit" → pas d'accès writeFile natif

### Impact
- Claude Code ne sait pas que le scheduler a tourné
- Pas de traçabilité des exécutions planifiées
- Pas de détection si Roo a un problème

### Solution
Résoudre Problème 1 OU Problème 2 (voir solutions ci-dessus).

---

## ✅ Solutions Recommandées (Par Ordre de Priorité)

### Solution 1 : Simplifier le Workflow Scheduler (FACILE)

**Modifier `.roo/schedules.json` :**

```json
{
  "taskInstructions": "Tu es lance par le planificateur automatique. Suis ce workflow strictement.

### WORKFLOW EN 3 ETAPES SIMPLIFIEES

**Etape 1 : Lire l'INTERCOM**
- Ouvre `.claude/local/INTERCOM-myia-po-2024.md`
- Lis les 5 derniers messages
- Cherche les messages de type [SCHEDULED] ou [TASK] de Claude Code
- Si message [URGENT] : traiter en priorite absolue

**Etape 2 : Executer les taches**
- Si message [SCHEDULED] ou [TASK] : deleguer aux modes -simple via new_task
- Si tache complexe detectee : escalader vers orchestrator-complex
- Si rien a faire : passer a l'etape 3 directement

**Etape 3 : Rapporter le resultat**
- Deleguer à code-simple via new_task :
  Tâche : \"Ajouter message IDLE dans .claude/local/INTERCOM-myia-po-2024.md\"
  Format : Voir exemple ci-dessous

### Format du message IDLE (pour code-simple)

```
## [DATE] roo → claude-code [IDLE]
Aucune tache planifiee. Workspace propre. En attente.
```

### REGLES DE SECURITE (inchangées)
..."
}
```

**Avantages :**
- ✅ Pas besoin d'activer win-cli
- ✅ Pas besoin de changer le mode
- ✅ orchestrator-simple délègue correctement
- ✅ Minimal changes

### Solution 2 : Activer win-cli + Corriger Instructions (RECOMMANDÉ SI MCPs REQUIS)

1. **Activer win-cli** dans `mcp_settings.json`
2. **Modifier taskInstructions** pour déléguer l'écriture INTERCOM à code-simple

### Solution 3 : Changer Mode à code-simple (ALTERNATIVE)

```json
{
  "mode": "code-simple",
  "taskInstructions": "(simplifié - code-simple peut tout faire directement)"
}
```

---

## 📋 Checklist de Validation Post-Fix

Après application d'une solution :

- [ ] Modifier `.roo/schedules.json` avec la solution choisie
- [ ] Tester avec `timeInterval: "5"` minutes
- [ ] Vérifier qu'une nouvelle tâche se crée
- [ ] Vérifier que le message IDLE/DONE apparaît dans INTERCOM
- [ ] Vérifier qu'aucune erreur MCP n'apparaît dans ui_messages.json
- [ ] Restaurer `timeInterval: "180"` (3h)
- [ ] Mettre à jour ce document avec le résultat

---

## 🔄 Actions Immédiates Requises

1. **myia-po-2024 :** Appliquer Solution 1 (simplifier workflow)
2. **Tester** avec interval 5 minutes
3. **Documenter** le résultat
4. **Mettre à jour** message RooSync pour informer les autres machines
5. **Déployer** la correction sur les 4 autres machines avant activation

---

**Note :** Le scheduler fonctionne (la tâche s'est bien déclenchée), mais le workflow a besoin d'être adapté aux capacités réelles du mode `orchestrator-simple`.
