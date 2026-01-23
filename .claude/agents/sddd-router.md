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

## Politique de Rationnement Claude Code (Abonnement Max)

### Principe

L'abonnement Claude Max est partagé entre les 5 machines. Un rationnement strict est nécessaire pour éviter les dépassements.

### Politique par Modèle

| Modèle | Usage Recommandé | Limite | Cas d'Usage |
|--------|------------------|--------|-------------|
| **Haiku** | Scheduling fréquent | Illimité | Résumés, notifications, décisions simples, résultats tests |
| **Sonnet** | Usage manuel principal | Quotidien | Coordination, documentation, investigation, code |
| **Opus** | Escalade critique uniquement | **Max 1/jour/machine** | Bugs critiques, décisions architecturales majeures |

### Règles d'Escalade Modèle

**De Sonnet vers Opus :**

| Trigger | Exemples |
|---------|----------|
| Bug bloquant production | Déploiement échoué, service down |
| Décision architecture majeure | Choix technologique critique, refactoring massif |
| Problème multi-machine non résolu | Coordination complexe bloquée |
| Deadline critique | Release imminente avec blocage |

**Jamais utiliser Opus pour :**
- Documentation simple
- Tests unitaires
- Bugs mineurs
- Tâches routinières

### Workflow de Demande Opus

1. **Tentative Sonnet** - Toujours essayer avec Sonnet d'abord
2. **Documentation du besoin** - Pourquoi Sonnet ne suffit pas ?
3. **Validation utilisateur** - Demander approbation explicite
4. **Usage ciblé** - Limiter aux actions critiques uniquement

### Exemple d'Escalade Justifiée

```markdown
## [DATE] claude-code (Sonnet) → user [ESCALADE OPUS]

### Contexte
Bug critique : roosync_apply_config corrompt les fichiers sur 3 machines

### Tentatives Sonnet
- Investigation : 2h, root cause non trouvée
- Fix tenté : Échec, problème persiste
- Impact : Bloque tous les sync (production)

### Besoin Opus
- Analyse approfondie multi-fichiers (20+ fichiers)
- Débogage complexe avec traces asynchrones
- Proposition architecture alternative

### Justification
- Bloquant pour toutes les machines
- Deadline : Sync requis avant demain
- Complexité dépasse capacités Sonnet

---

**Demande autorisation Opus pour cette session.**
```

### Tracking Usage

Documenter chaque usage Opus dans INTERCOM :

```markdown
## [DATE] claude-code [OPUS USAGE]

### Tâche
[Description]

### Durée session Opus
[X minutes]

### Résultat
[Résolu / Partiel / Échec]

### ROI
[Le résultat justifie-t-il l'usage Opus ?]

---
```

### Métriques Cibles

- **Usage Opus** : < 5 sessions/semaine pour l'équipe complète (5 machines)
- **Taux de résolution Opus** : > 90% (si on utilise Opus, ça doit régler le problème)
- **Réduction coût** : Viser 70% des tâches en Haiku/Sonnet

## Référence

Voir [roo-config/sddd/level-criteria.json](../../roo-config/sddd/level-criteria.json) pour les critères détaillés.
