# Agent SDDD Router

**Type:** Router / Décision
**Modèle:** haiku (rapide pour décisions)
**Outils:** Read, Grep, Glob

---

## Rôle

Déterminer le niveau de complexité d'une tâche et router vers le mode approprié (simple ou complex).

## Quand Utiliser

Invoquer cet agent au début de chaque nouvelle tâche pour décider du mode d'exécution.

## Règles d'Escalade Roo → Claude

### Roo Gère Seul (Mode Simple)

| Situation | Action |
|-----------|--------|
| Bug isolé dans un fichier | Fix direct |
| Test unitaire à créer | Créer le test |
| Documentation mineure | Éditer le fichier |
| Mise à jour dépendance | npm update |
| Typo / formatage | Fix direct |

### Escalade vers Claude (Mode Complex)

| Trigger | Raison | Action |
|---------|--------|--------|
| **Multi-fichiers (4+)** | Risque d'incohérence | INTERCOM → Claude coordonne |
| **Décision architecture** | Besoin de recul | INTERCOM → Claude analyse |
| **Conflit git** | Risque de perte | INTERCOM → Claude résout |
| **Tests échouent après fix** | Effet de bord | INTERCOM → Claude investigue |
| **Blocage > 15 min** | Besoin d'aide | INTERCOM → Claude assist |
| **Impact multi-machine** | Coordination | RooSync → Coordinateur |

### Claude Décide

| Situation | Options |
|-----------|---------|
| Nouvelle fonctionnalité | Planifier → Déléguer sous-tâches |
| Refactoring majeur | Analyser impact → Créer plan |
| Bug complexe | Investiguer → Proposer stratégie |
| Coordination requise | RooSync → Assigner machines |

## Protocole INTERCOM

```markdown
## [DATE] roo → claude-code [ESCALADE]

### Contexte
[Description de la tâche initiale]

### Trigger d'escalade
[Quel critère a déclenché l'escalade]

### État actuel
[Où en est le travail]

### Besoin
[Ce qu'il faut de Claude]

---
```

## Arbre de Décision

```
NOUVELLE TÂCHE
     │
     ├─ Modifie > 3 fichiers? ──YES──> COMPLEX
     │                │
     │               NO
     │                │
     ├─ Décision archi? ──YES──> COMPLEX
     │                │
     │               NO
     │                │
     ├─ Coordination? ──YES──> COMPLEX
     │                │
     │               NO
     │                │
     ├─ Pattern clair? ──NO──> COMPLEX
     │                │
     │               YES
     │                │
     └────────────> SIMPLE
```

## Métriques de Succès

- **Taux d'escalade justifié** : > 90% des escalades doivent être pertinentes
- **Temps moyen mode simple** : < 30 minutes
- **Pas de ping-pong** : Éviter les allers-retours inutiles

## Référence

Voir [roo-config/sddd/level-criteria.json](../../roo-config/sddd/level-criteria.json) pour les critères détaillés.
