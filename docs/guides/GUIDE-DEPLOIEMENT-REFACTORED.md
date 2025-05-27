# Guide de Déploiement - Configuration Refactorisée

## Vue d'ensemble

Cette refonte résout les problèmes critiques identifiés dans les modes simple/complexe et introduit des fonctionnalités avancées pour une meilleure robustesse et flexibilité.

## Problèmes Résolus

### ✅ 1. Accès Terminal Restauré
- **Problème** : Accès terminal restreint dans les modes simple/complexe
- **Solution** : Accès complet restauré avec stratégies de fallback
- **Implémentation** : Groupe "command" ajouté à tous les modes

### ✅ 2. Stratégies de Fallback MCP Robustes
- **Problème** : Dépendance critique aux MCPs sans alternatives
- **Solution** : Fallback automatique MCP → Terminal → Erreur explicite
- **Implémentation** : Instructions de fallback dans tous les modes

### ✅ 3. Logique d'Escalade/Désescalade Intelligente
- **Problème** : Pas de mécanisme d'évaluation de complexité
- **Solution** : Évaluation systématique avec critères objectifs
- **Implémentation** : Mécanismes d'escalade dans 11/12 modes

### ✅ 4. Création de Sous-tâches Inter-familles
- **Problème** : Limitation aux sous-tâches de même famille
- **Solution** : Création selon la complexité réelle de la tâche
- **Implémentation** : Règles flexibles dans tous les modes

## Nouvelles Fonctionnalités

### 🆕 Validateur de Familles
```json
{
  "slug": "mode-family-validator",
  "familyDefinitions": {
    "simple": ["code-simple", "debug-simple", "architect-simple", "ask-simple", "orchestrator-simple"],
    "complex": ["code-complex", "debug-complex", "architect-complex", "ask-complex", "orchestrator-complex", "manager"]
  }
}
```

### 🆕 Transitions Inter-familles
- Tous les modes peuvent créer des sous-tâches dans les deux familles
- Évaluation automatique de la complexité
- Escalade/désescalade basée sur des critères objectifs

### 🆕 Stratégies de Fallback Multicouches
1. **Priorité 1** : MCPs (win-cli, quickfiles, jinavigator, searxng)
2. **Priorité 2** : Outils standards (execute_command, read_file, etc.)
3. **Priorité 3** : Signalement d'erreur explicite

## Architecture Technique

### Structure des Modes
```
Famille SIMPLE (5 modes)
├── code-simple      → Modifications mineures (<50 lignes)
├── debug-simple     → Erreurs de syntaxe, bugs évidents
├── architect-simple → Documentation simple, diagrammes basiques
├── ask-simple       → Questions factuelles, concepts de base
└── orchestrator-simple → Coordination de tâches simples

Famille COMPLEX (6 modes)
├── code-complex     → Refactoring majeur, architecture
├── debug-complex    → Debugging système, performance
├── architect-complex → Architecture système complexe
├── ask-complex      → Recherches approfondies, expertise
├── orchestrator-complex → Workflows complexes, dépendances
└── manager          → Gestion de ressources, coordination
```

### Critères d'Escalade/Désescalade

#### SIMPLE → COMPLEX
- \> 50 lignes de code
- Multiples fichiers
- Refactoring nécessaire
- Optimisations complexes
- Analyse architecturale

#### COMPLEX → SIMPLE
- < 50 lignes de code
- Fonctionnalités isolées
- Patterns standards
- Pas d'optimisations
- Pas d'analyse approfondie

## Instructions de Déploiement

### 1. Sauvegarde
```powershell
# Sauvegarder la configuration actuelle
Copy-Item ".roomodes" ".roomodes.backup"
Copy-Item "roo-modes/configs/standard-modes.json" "roo-modes/configs/standard-modes.json.backup"
```

### 2. Déploiement
```powershell
# Copier la nouvelle configuration
Copy-Item "roo-modes/configs/refactored-modes.json" ".roomodes"
```

### 3. Validation
```powershell
# Exécuter le script de validation
powershell -ExecutionPolicy Bypass -File "roo-modes/validation-refactored-modes.ps1"
```

### 4. Test des MCPs
```powershell
# Tester les MCPs critiques
# win-cli, quickfiles, jinavigator, searxng, jupyter, filesystem
# Seul gitglobal peut être en erreur selon les besoins
```

## Validation des Résultats

### ✅ Métriques de Validation
- **Structure JSON** : Valide (12 modes)
- **Familles** : 5 modes SIMPLE + 6 modes COMPLEX
- **Accès terminal** : Restauré pour tous les modes
- **Stratégies de fallback** : Implémentées
- **Logique d'escalade** : 11/12 modes
- **Groupes d'outils** : read(11), edit(9), command(11), browser(11), mcp(11)
- **Modèles** : claude-sonnet-4(6), claude-3.5-sonnet(5)

### 🧪 Tests de Fonctionnement
1. **Test MCP win-cli** : ✅ Opérationnel
2. **Test MCP quickfiles** : ✅ Opérationnel  
3. **Test MCP jinavigator** : ✅ Opérationnel
4. **Test MCP searxng** : ✅ Opérationnel
5. **Test MCP gitglobal** : ✅ Opérationnel (inattendu mais fonctionnel)
6. **Test fallback** : ✅ Démontré avec restrictions win-cli

## Utilisation Optimisée

### Recommandations d'Usage

#### Pour les Tâches Simples
- Commencer par les modes **SIMPLE**
- Laisser l'escalade automatique se déclencher si nécessaire
- Utiliser les MCPs en priorité pour de meilleures performances

#### Pour les Tâches Complexes
- Utiliser directement les modes **COMPLEX**
- Évaluer régulièrement si une désescalade est possible
- Créer des sous-tâches au niveau de complexité minimal

#### Gestion des Tokens
- Modes SIMPLE : Conversations plus courtes, moins de tokens
- Modes COMPLEX : Gestion avancée avec création de sous-tâches
- Escalade par approfondissement après 50k tokens

## Support et Maintenance

### Fichiers Clés
- **Configuration** : `roo-modes/configs/refactored-modes.json`
- **Validation** : `roo-modes/validation-refactored-modes.ps1`
- **Documentation** : `roo-modes/GUIDE-DEPLOIEMENT-REFACTORED.md`
- **Rapport** : `roo-modes/validation-report-*.md`

### Monitoring
- Surveiller les performances des MCPs
- Vérifier les transitions inter-familles
- Analyser l'efficacité des stratégies de fallback

## Conclusion

🎉 **La refonte des modes simple/complexe est maintenant complète et opérationnelle.**

Cette nouvelle architecture offre :
- **Robustesse** : Stratégies de fallback multicouches
- **Flexibilité** : Transitions inter-familles intelligentes
- **Performance** : Utilisation optimisée des MCPs
- **Évolutivité** : Architecture extensible pour de futures améliorations

La configuration a été validée avec succès et tous les problèmes identifiés ont été résolus.