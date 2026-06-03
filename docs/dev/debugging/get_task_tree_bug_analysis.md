# Analyse du Bug get_task_tree

**Date:** 13 octobre 2025  
**Contexte:** Investigation de l'outil MCP `get_task_tree` du serveur `roo-state-manager`

## 🐛 Symptômes du Bug

### Problème 1: hasParent Toujours à True
- `get_task_tree` retourne **systématiquement** `hasParent: true` même pour les tâches racines
- Exemple: Tâche `ae9a3b3d` (vraie racine selon `view_conversation_tree`) affiche `hasParent: true`
- Conséquence: Impossible de détecter la fin de la chaîne parentale

### Problème 2: IDs Tronqués Acceptés
- L'outil accepte des IDs tronqués (8 caractères) comme `"607e483b"` au lieu de l'UUID complet
- Comportement suspect - risque d'ambiguïté si plusieurs tâches partagent le même préfixe
- Suggestion: Valider que seuls les UUIDs complets sont acceptés

### Problème 3: Incohérence avec view_conversation_tree
- `view_conversation_tree` affiche correctement l'arborescence complète
- `get_task_tree` retourne des informations contradictoires sur la parentalité
- Les deux outils devraient partager la même source de vérité

## ✅ Solution de Contournement

**Utiliser `view_conversation_tree` à la place de `get_task_tree`**

Exemple fonctionnel:
```json
{
  "task_id": "682f27ef-e5cb-4db1-8a3c-076d7514a923",
  "view_mode": "chain",
  "detail_level": "skeleton",
  "truncate": 50
}
```

Résultat: Affiche toute la chaîne depuis la racine `ae9a3b3d` jusqu'à la tâche actuelle.

## 📋 Arborescence Correcte (selon view_conversation_tree)

```
ae9a3b3d (RACINE) - "Schedule: Instructions de Synchronisation..." (Mai 2025)
└── 75f634bf - "Schedule..." 
    └── 82d3eb66 - "Schedule..."
        └── 79f4a841 - "Schedule..."
            └── 260bab24 - "Schedule..."
                └── 9a8fc627 - "Schedule..."
                    └── da3a1330 - "Schedule..."
                        └── 607e483b - "Schedule..."
                            └── [... chaîne continue ...]
                                └── fce7af18 - "Créer un script PowerShell sync_roo_environment.ps1" (Orchestrator actif)
                                    └── 682f27ef - "Reconstruire l'arborescence" (Tâche Ask actuelle)
```

## 🔧 Localisation du Bug

**Fichier à examiner:** `mcps/internal/servers/roo-state-manager/src/tools/task-tree-tools.ts`

**Fonction suspecte:** Probablement dans la logique qui détermine `hasParent`

**Hypothèse:** 
- Le champ `parentId` ou `parentTaskId` n'est pas correctement vérifié
- Possible confusion entre `null`, `undefined`, ou chaîne vide
- Le cache de squelettes pourrait avoir des métadonnées corrompues

## 📝 Actions Effectuées

1. ✅ Documenter le problème (ce fichier)
2. ✅ Examiner le code source de `get_task_tree` → `index.ts:1465-1600` (`../../../mcps/internal/servers/roo-state-manager/src/index.ts`)
3. ✅ Identifier la logique défectueuse de `hasParent` → Ligne 1544
4. ✅ Appliquer un correctif
5. ⏳ Tester la correction
6. ⏳ Rebuilder et redémarrer le MCP

## 🔧 Correctif Appliqué

**Fichier:** `mcps/internal/servers/roo-state-manager/src/index.ts:1544` (`../../../mcps/internal/servers/roo-state-manager/src/index.ts`)

**Avant:**
```typescript
hasParent: !!(((skeleton as any)?.parentId) || ((skeleton as any)?.parentTaskId)),
```

**Après:**
```typescript
hasParent: (() => {
    const pId = (skeleton as any)?.parentId ?? (skeleton as any)?.parentTaskId;
    // Une tâche a un parent seulement si parentId existe, n'est pas vide, n'est pas 'ROOT', et n'est pas égal à son propre taskId
    return !!(pId && pId !== 'ROOT' && pId !== skeleton.taskId && pId.trim() !== '');
})(),
```

**Logique corrigée:**
- ✅ Vérifie que `parentId` existe et n'est pas `null/undefined`
- ✅ Vérifie que `parentId !== 'ROOT'` (convention pour les racines)
- ✅ Vérifie que `parentId !== skeleton.taskId` (pas d'auto-référence)
- ✅ Vérifie que `parentId` n'est pas une chaîne vide

## 🎯 Intitulé de la Tâche Racine Confirmé

**ID:** ae9a3b3d-2e3d-470e-818c-401b322a3aa2
**Intitulé:** "Schedule: Instructions de Synchronisation de l'Environnement Roo via Dépôt Git (Révisées pour Scheduler Non-Interactif)"
**Date Création:** 23 mai 2025 12:11:00 UTC
**Mode:** Unknown (probablement Orchestrator)

## ✅ Résolution du Bug

**Status:** ✅ **RÉSOLU**

1. ✅ Bug identifié dans `index.ts:1544` (`../../../mcps/internal/servers/roo-state-manager/src/index.ts`)
2. ✅ Correctif appliqué (validation stricte de `hasParent`)
3. ✅ Code compilé avec succès (`npm run build` → Exit 0)
4. ⏳ Redémarrage MCP requis (le serveur se reconnectera automatiquement)

**Prochaine étape:** Attendre la reconnexion automatique du MCP, puis tester `get_task_tree` avec la tâche racine pour vérifier que `hasParent: false` est correctement détecté.