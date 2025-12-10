# Plan de Ventilation Intelligente - 125 Échecs de Tests

**Date :** 2025-11-30  
**Auteur :** myia-po-2023 (Lead/Coordinateur)  
**Contexte :** Distribution des 125 corrections nécessaires après synchronisation des agents

## 1. État des Agents Disponibles

### 1.1. Agents Actifs Identifiés
D'après l'analyse RooSync et les messages récents :

| Agent | Statut | Spécialisation | Dernière activité | Charge actuelle |
|--------|--------|----------------|------------------|-----------------|
| **myia-po-2024** | ✅ Disponible | Infrastructure & Configuration | 29/11/2025 | Moyenne |
| **myia-po-2026** | ✅ Disponible | Parsing & Traitement données | 29/11/2025 | Élevée |
| **myia-ai-01** | ✅ Disponible | IA & Recherche Sémantique | 27/11/2025 | Moyenne |
| **myia-web1** | ✅ Disponible | Intégration & Tests | 29/11/2025 | Faible |

### 1.2. Analyse des Compétences
- **myia-po-2024** : Expert en infrastructure, mocks Vitest, configuration RooSync
- **myia-po-2026** : Spécialiste du parsing XML, hiérarchies, traitement données
- **myia-ai-01** : Expert en Qdrant, recherche sémantique, indexation vectorielle
- **myia-web1** : Spécialiste en intégration end-to-end, tests d'validation

## 2. Répartition des 125 Échecs par Spécialité

### 2.1. Catégorisation des Échecs

| Catégorie | Nombre d'échecs | Agent principal | Complexité |
|----------|----------------|----------------|-------------|
| **Mocking Vitest** | 31 | myia-po-2024 | Élevée |
| **Parsing XML** | 22 | myia-po-2026 | Critique |
| **Recherche Sémantique** | 9 | myia-ai-01 | Critique |
| **Reconstruction Hiérarchique** | 7 | myia-po-2026 | Moyenne |
| **Configuration RooSync** | 6 | myia-po-2024 | Moyenne |
| **Indexation Vectorielle** | 1 | myia-ai-01 | Faible |
| **Divers/Autres** | 49 | myia-web1 | Variable |

### 2.2. Répartition Optimale

#### myia-po-2024 (Infrastructure) - 37 corrections (30%)
**Priorité 1 - Mocking Vitest (31 échecs)**
- Corriger les mocks dans `MessageManager.test.ts` (2)
- Corriger les mocks dans `BaselineService.test.ts` (9)
- Corriger les mocks dans `timestamp-parsing.test.ts` (4)
- Corriger les mocks dans les autres fichiers (16)

**Priorité 2 - Configuration RooSync (6 échecs)**
- Réparer `roosync-config.test.ts` (6)

#### myia-po-2026 (Parsing) - 29 corrections (23%)
**Priorité 1 - Parsing XML (22 échecs)**
- Réparer `xml-parsing.test.ts` (services) (13)
- Réparer `xml-parsing.test.ts` (utils) (9)

**Priorité 2 - Reconstruction Hiérarchique (7 échecs)**
- Réparer `controlled-hierarchy-reconstruction-fix.test.ts` (4)
- Réparer `hierarchy-pipeline.test.ts` (2)
- Réparer `hierarchy-reconstruction-engine.test.ts` (1)

#### myia-ai-01 (IA/Sémantique) - 10 corrections (8%)
**Priorité 1 - Recherche Sémantique (9 échecs)**
- Réparer `search-by-content.test.ts` (9)

**Priorité 2 - Indexation Vectorielle (1 échec)**
- Réparer `task-indexer-vector-validation.test.ts` (1)

#### myia-web1 (Intégration) - 49 corrections (39%)
**Priorité 1 - Validation et Tests**
- Créer des tests d'intégration pour les corrections
- Valider les corrections end-to-end
- Documenter les patterns de correction

**Priorité 2 - Support**
- Aider les autres agents en cas de blocage
- Optimiser les performances des tests
- Créer des rapports de progression

## 3. Plan d'Action Détaillé

### 3.1. Phase 1 : Corrections Critiques (Jour 1-2)

#### myia-po-2024 - Infrastructure
```
MISSION CRITIQUE - Mocking Vitest
Objectif : Corriger 31 erreurs de mocks Vitest
Fichiers prioritaires :
1. tests/unit/services/BaselineService.test.ts (9 échecs)
2. tests/unit/utils/timestamp-parsing.test.ts (4 échecs)
3. src/services/__tests__/MessageManager.test.ts (2 échecs)

Action requise :
- Réviser tous les vi.mock() pour inclure les exports manquants
- Ajouter "promises" dans les mocks fs
- Valider avec npm run test:unit:services
```

#### myia-po-2026 - Parsing
```
MISSION CRITIQUE - Parsing XML
Objectif : Corriger 22 erreurs de parsing XML
Fichiers prioritaires :
1. tests/unit/services/xml-parsing.test.ts (13 échecs)
2. tests/unit/utils/xml-parsing.test.ts (9 échecs)

Action requise :
- Analyser les patterns d'échec : expected [] to have a length of X but got +0
- Corriger le parser XML pour extraire correctement les balises
- Valider avec npm run test:unit:services
```

#### myia-ai-01 - IA/Sémantique
```
MISSION CRITIQUE - Recherche Sémantique
Objectif : Corriger 9 erreurs de recherche sémantique
Fichier prioritaire :
1. tests/unit/tools/search/search-by-content.test.ts (9 échecs)

Action requise :
- Corriger les noms d'index Qdrant
- Réparer les erreurs de gestion d'erreurs
- Valider avec npm run test:unit:tools
```

### 3.2. Phase 2 : Stabilisation (Jour 3-4)

#### myia-po-2024 - Configuration RooSync
```
MISSION STABILISATION - Configuration RooSync
Objectif : Corriger 6 erreurs de configuration
Fichier prioritaire :
1. tests/unit/config/roosync-config.test.ts (6 échecs)

Action requise :
- Corriger les valeurs de configuration par défaut
- Valider la levée d'erreurs
- Tester avec npm run test:unit:config
```

#### myia-po-2026 - Reconstruction Hiérarchique
```
MISSION STABILISATION - Reconstruction Hiérarchique
Objectif : Corriger 7 erreurs de reconstruction
Fichiers prioritaires :
1. tests/unit/utils/controlled-hierarchy-reconstruction-fix.test.ts (4)
2. tests/unit/hierarchy-pipeline.test.ts (2)
3. tests/unit/services/hierarchy-reconstruction-engine.test.ts (1)

Action requise :
- Corriger l'extraction des instructions new_task
- Réparer les incohérences de profondeur
- Valider avec npm run test:hierarchy
```

#### myia-ai-01 - Indexation Vectorielle
```
MISSION STABILISATION - Indexation Vectorielle
Objectif : Corriger 1 erreur d'indexation
Fichier prioritaire :
1. tests/unit/services/task-indexer-vector-validation.test.ts (1)

Action requise :
- Corriger l'upsert batch dans Qdrant
- Valider avec npm run test:vector
```

### 3.3. Phase 3 : Intégration et Validation (Jour 5-7)

#### myia-web1 - Intégration
```
MISSION INTÉGRATION - Validation End-to-End
Objectif : Valider toutes les corrections et créer des tests robustes

Actions requises :
1. Créer des tests d'intégration pour les workflows critiques
2. Valider les corrections de chaque agent
3. Créer des tests de régression
4. Optimiser les performances des tests
5. Documenter les patterns de correction
```

## 4. Coordination et Communication

### 4.1. Protocole de Communication
1. **Rapport quotidien** : Chaque agent envoie un rapport de progression
2. **Points de blocage** : Signalés immédiatement via RooSync
3. **Validation croisée** : myia-web1 valide les corrections des autres
4. **Synchronisation** : Mise à jour des corrections après chaque phase

### 4.2. Points de Contrôle
- **Jour 2** : Validation des corrections critiques
- **Jour 4** : Validation des corrections de stabilisation
- **Jour 7** : Validation finale et rapport complet

## 5. Mesures de Succès

### 5.1. Objectifs Quantitatifs
- **Réduire les échecs de 125 à < 20** (84% de réduction)
- **Atteindre 95% de tests passés** (vs 74.3% actuel)
- **Temps moyen d'exécution < 10s** (vs 12.96s actuel)

### 5.2. Objectifs Qualitatifs
- **Zéro erreur de mocking Vitest**
- **Parsing XML 100% fonctionnel**
- **Recherche sémantique stable**
- **Configuration RooSync robuste**

## 6. Plan de Contingence

### 6.1. Si un Agent est Bloqué
1. **Redistribution automatique** : Répartir les corrections entre les autres agents
2. **Support croisé** : Les agents disponibles aident l'agent bloqué
3. **Escalade** : myia-po-2023 intervient pour déblocage

### 6.2. Si les Corrections sont Plus Complexes
1. **Extension des délais** : +2 jours pour les corrections complexes
2. **Division supplémentaire** : Sous-tâches plus granulaires
3. **Expertise externe** : Faire appel à des spécialistes si nécessaire

## 7. Prochaines Étapes

### 7.1. Immédiat (Aujourd'hui)
1. Envoyer les missions détaillées à chaque agent via RooSync
2. Créer les canaux de communication dédiés
3. Initialiser le suivi de progression

### 7.2. Court Terme (Cette semaine)
1. Suivi quotidien des corrections
2. Validation intermédiaire après chaque phase
3. Ajustements du plan si nécessaire

### 7.3. Moyen Terme (Semaine prochaine)
1. Tests complets de validation
2. Rapport final de corrections
3. Plan de stabilisation à long terme

---

**Conclusion :** Avec cette ventilation intelligente et une coordination efficace, les 125 échecs devraient être réduits à moins de 20 dans la semaine, permettant d'atteindre un taux de réussite de 95% des tests.