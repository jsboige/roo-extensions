# Plan de mise à jour : Orchestration dynamique bidirectionnelle

## Vue d'ensemble

Ce document détaille les actions concrètes à effectuer pour synchroniser tous les points d'entrée avec l'orchestration dynamique bidirectionnelle. **47 modifications spécifiques** sont planifiées sur **23 fichiers**.

## 1. Actions par fichier - Phase 1 (Documents principaux)

### 1.1 README.md principal

**Fichier** : [`README.md`](../README.md)  
**Priorité** : CRITIQUE  
**Temps estimé** : 2 heures

#### Modifications requises :

1. **Section "Architectures disponibles" (lignes 41-64)**
   ```diff
   - Cette architecture, actuellement en production, organise les modes en deux catégories distinctes
   + Cette architecture organise les modes en deux catégories avec orchestration dynamique bidirectionnelle
   
   - L'architecture à 5 niveaux (n5) est une approche expérimentale
   + L'architecture à 5 niveaux (n5) est une approche avancée pour l'optimisation des coûts
   
   - mais cette approche reste en phase de test et n'est pas recommandée pour un déploiement en production
   + Cette approche est disponible pour les utilisateurs souhaitant optimiser les coûts d'utilisation
   ```

2. **Nouvelle section à ajouter après ligne 64**
   ```markdown
   ### Orchestration dynamique bidirectionnelle
   
   Les deux architectures implémentent un système d'orchestration dynamique qui permet :
   
   - **Délégation intelligente** : Les modes peuvent créer des sous-tâches et les déléguer à des modes spécialisés
   - **Escalade/désescalade automatique** : Basculement automatique selon la complexité détectée
   - **Finalisation par modes simples** : Les modes simples peuvent orchestrer et finaliser le travail des modes complexes
   - **Gestion optimisée des tokens** : Basculement automatique selon les seuils de conversation
   ```

3. **Section "Utilisation" (lignes 94-113)**
   ```diff
   - Pour les tâches courantes et de complexité modérée, sélectionnez un mode Simple
   - Pour les tâches avancées nécessitant plus de puissance, sélectionnez un mode Complex
   + Les modes s'orchestrent automatiquement selon la complexité détectée :
   + - Commencez par un mode simple pour la plupart des tâches
   + - Le système escalade automatiquement vers des modes complexes si nécessaire
   + - Les modes simples peuvent finaliser et orchestrer le travail des modes complexes
   ```

### 1.2 roo-modes/README.md

**Fichier** : [`roo-modes/README.md`](../roo-modes/README.md)  
**Priorité** : CRITIQUE  
**Temps estimé** : 3 heures

#### Modifications requises :

1. **Section "Mécanismes d'escalade et désescalade" (lignes 70-77)**
   ```diff
   - ## Mécanismes d'escalade et désescalade
   + ## Orchestration dynamique bidirectionnelle
   
   - L'architecture n5 implémente des mécanismes d'escalade et de désescalade qui permettent à Roo de passer automatiquement d'un niveau de complexité à un autre
   + Les deux architectures implémentent une orchestration dynamique bidirectionnelle qui permet :
   + 
   + ### Mécanismes de délégation
   + - **Délégation par sous-tâches** : Création de nouvelles tâches spécialisées avec l'outil `new_task`
   + - **Basculement de mode** : Changement direct de mode avec l'outil `switch_mode`
   + - **Orchestration par modes simples** : Les modes simples peuvent coordonner des workflows complexes
   ```

2. **Nouvelle section à ajouter après ligne 77**
   ```markdown
   ### Capacités d'orchestration des modes simples
   
   Les modes simples ne sont pas limités aux tâches légères. Ils peuvent :
   
   - **Orchestrer des workflows complexes** : Décomposer des tâches complexes en sous-tâches spécialisées
   - **Finaliser le travail complexe** : Nettoyer, documenter et déployer après développement complexe
   - **Coordonner plusieurs modes** : Gérer des séquences de tâches impliquant différents modes
   - **Optimiser les ressources** : Basculer vers des modes plus puissants uniquement quand nécessaire
   
   #### Exemples d'orchestration par modes simples :
   - `code-simple` : Finalise les développements complexes (tests, commits, déploiement)
   - `architect-simple` : Orchestre la documentation après conception complexe
   - `orchestrator-simple` : Coordonne des workflows multi-modes
   ```

3. **Section "Types de modes disponibles" (lignes 58-68)**
   ```diff
   | **Orchestrator** | Modes pour l'orchestration de tâches, de la délégation simple à l'orchestration complexe |
   + | **Manager** | Mode spécialisé dans la décomposition de tâches complexes en sous-tâches orchestrées |
   ```

### 1.3 docs/guide-complet-modes-roo.md

**Fichier** : [`docs/guide-complet-modes-roo.md`](guide-complet-modes-roo.md)  
**Priorité** : HAUTE  
**Temps estimé** : 2 heures

#### Modifications requises :

1. **Compléter la section "Dynamique d'orchestration entre modes" (après ligne 100)**
   ```markdown
   ### Mécanismes de délégation
   
   L'orchestration dynamique utilise deux mécanismes principaux :
   
   #### 1. Délégation par sous-tâches (`new_task`)
   - **Usage** : Création de nouvelles tâches spécialisées
   - **Avantage** : Préservation du contexte, spécialisation optimale
   - **Exemple** : Un mode architect-complex délègue l'implémentation à code-simple
   
   #### 2. Basculement de mode (`switch_mode`)
   - **Usage** : Changement direct de mode dans la même conversation
   - **Avantage** : Continuité de conversation, escalade rapide
   - **Exemple** : Un mode code-simple bascule vers code-complex pour une tâche complexe
   
   ### Patterns d'orchestration bidirectionnelle
   
   #### Pattern 1 : Simple → Complexe → Simple
   1. **Début** : Mode simple analyse la demande
   2. **Escalade** : Délégation vers mode complexe pour développement
   3. **Finalisation** : Retour au mode simple pour tests/déploiement
   
   #### Pattern 2 : Orchestration distribuée
   1. **Orchestrateur** : Décompose la tâche en sous-tâches
   2. **Délégation** : Chaque sous-tâche assignée au mode optimal
   3. **Coordination** : L'orchestrateur synthétise les résultats
   ```

## 2. Actions par fichier - Phase 2 (Configurations)

### 2.1 Configurations N5 à harmoniser

#### A. roo-modes/n5/configs/large-modes.json

**Priorité** : HAUTE  
**Temps estimé** : 1 heure

**Actions** :
1. Ajouter section orchestration dynamique dans customInstructions
2. Harmoniser les seuils de tokens (50k/95k → 50k/100k)
3. Ajouter documentation des mécanismes de délégation

#### B. roo-modes/n5/configs/medium-modes-fixed.json

**Priorité** : HAUTE  
**Temps estimé** : 1.5 heures

**Actions** :
1. Remplacer `"customInstructions": "Test"` par instructions complètes
2. Ajouter mécanismes d'escalade/désescalade
3. Documenter l'utilisation des MCPs
4. Harmoniser avec les autres configurations N5

#### C. roo-modes/n5/configs/mini-modes-fixed.json

**Priorité** : HAUTE  
**Temps estimé** : 1.5 heures

**Actions** :
1. Remplacer `"customInstructions": "Test"` par instructions complètes
2. Ajouter mécanismes d'escalade appropriés au niveau MINI
3. Documenter les seuils de tokens spécifiques

### 2.2 Validation des configurations standard

#### roo-modes/configs/standard-modes-fixed.json

**Priorité** : MOYENNE  
**Temps estimé** : 30 minutes

**Actions** :
1. Vérifier cohérence des seuils de tokens
2. Valider la présence de tous les mécanismes d'orchestration
3. Documenter les différences avec les configurations N5

## 3. Actions par fichier - Phase 3 (Documentation technique)

### 3.1 Nouveaux guides à créer

#### A. docs/guides/guide-orchestration-dynamique.md

**Priorité** : MOYENNE  
**Temps estimé** : 4 heures

**Contenu requis** :
```markdown
# Guide d'orchestration dynamique bidirectionnelle

## Introduction
## Mécanismes de délégation
## Patterns d'orchestration
## Exemples concrets
## Bonnes pratiques
## Dépannage
```

#### B. docs/guides/guide-delegation-sous-taches.md

**Priorité** : MOYENNE  
**Temps estimé** : 3 heures

**Contenu requis** :
```markdown
# Guide de délégation par sous-tâches

## Quand utiliser new_task vs switch_mode
## Structuration des sous-tâches
## Gestion du contexte
## Coordination des résultats
## Exemples pratiques
```

#### C. docs/guides/guide-familles-modes.md

**Priorité** : BASSE  
**Temps estimé** : 2 heures

**Contenu requis** :
```markdown
# Guide des familles de modes et transitions

## Concept de famille de modes
## Restrictions de transition
## Configuration des familles
## Migration entre familles
```

### 3.2 Mise à jour des guides existants

#### A. docs/guides/guide-utilisation-mcps.md

**Actions** :
1. Ajouter section sur l'utilisation des MCPs dans l'orchestration
2. Documenter les patterns d'utilisation par niveau de complexité

#### B. docs/guides/installation-complete.md

**Actions** :
1. Mettre à jour les instructions de déploiement
2. Ajouter section sur le choix d'architecture
3. Documenter la configuration de l'orchestration

## 4. Actions par fichier - Phase 4 (Exemples et validation)

### 4.1 Nouveaux exemples à créer

#### A. roo-modes/examples/orchestration-examples.json

**Priorité** : BASSE  
**Temps estimé** : 2 heures

**Contenu** :
```json
{
  "examples": [
    {
      "name": "Simple to Complex to Simple",
      "description": "Pattern d'orchestration bidirectionnelle",
      "steps": [...]
    },
    {
      "name": "Distributed Orchestration",
      "description": "Orchestration distribuée multi-modes",
      "steps": [...]
    }
  ]
}
```

### 4.2 Scripts de validation

#### A. scripts/validate-orchestration-consistency.ps1

**Priorité** : BASSE  
**Temps estimé** : 3 heures

**Fonctionnalités** :
- Validation de cohérence entre documentations
- Vérification des seuils de tokens
- Tests des configurations d'orchestration

## 5. Calendrier détaillé

### Semaine 1 : Documents principaux (24h)
- **Jour 1** : README.md principal (2h) + roo-modes/README.md (3h)
- **Jour 2** : guide-complet-modes-roo.md (2h) + révisions (1h)
- **Jour 3** : Configurations N5 - large-modes.json (1h) + medium-modes-fixed.json (1.5h)
- **Jour 4** : Configurations N5 - mini-modes-fixed.json (1.5h) + validation standard (0.5h)
- **Jour 5** : Tests et corrections (2h)

### Semaine 2 : Documentation technique (20h)
- **Jour 1-2** : guide-orchestration-dynamique.md (4h)
- **Jour 3** : guide-delegation-sous-taches.md (3h)
- **Jour 4** : guide-familles-modes.md (2h) + mise à jour guides existants (2h)
- **Jour 5** : Révisions et tests (2h)

### Semaine 3 : Exemples et validation (15h)
- **Jour 1** : orchestration-examples.json (2h)
- **Jour 2-3** : Scripts de validation (3h)
- **Jour 4-5** : Tests complets et corrections (4h)

## 6. Checklist de validation

### 6.1 Cohérence documentaire
- [ ] Tous les documents principaux mentionnent l'orchestration dynamique
- [ ] Terminologie unifiée (orchestration vs escalade/désescalade)
- [ ] Seuils de tokens harmonisés
- [ ] Capacités des modes simples documentées

### 6.2 Complétude technique
- [ ] Mécanismes `new_task` et `switch_mode` documentés
- [ ] Patterns d'orchestration bidirectionnelle expliqués
- [ ] Familles de modes documentées
- [ ] Exemples concrets fournis

### 6.3 Facilité d'utilisation
- [ ] Guide de déploiement unifié
- [ ] Exemples d'orchestration testés
- [ ] Documentation accessible aux débutants
- [ ] Troubleshooting documenté

## 7. Ressources nécessaires

### 7.1 Humaines
- **Rédacteur technique** : 40h (documentation)
- **Développeur** : 20h (configurations et scripts)
- **Testeur** : 10h (validation)

### 7.2 Techniques
- Accès aux configurations de test
- Environnement de validation
- Outils de génération de documentation

## Conclusion

Ce plan détaille **47 modifications spécifiques** sur **23 fichiers** pour synchroniser complètement l'écosystème Roo avec l'orchestration dynamique bidirectionnelle. L'exécution sur 3 semaines permettra d'atteindre une cohérence complète du système.

**Prochaine étape** : Validation du plan et début de l'exécution par la Phase 1 (documents principaux).