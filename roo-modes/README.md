# Modes Roo

Ce répertoire contient l'ensemble des modes personnalisés pour Roo, organisés selon différentes architectures et optimisations pour divers modèles de langage.

## Qu'est-ce qu'un mode Roo ?

Un mode Roo est une configuration spécifique qui définit le comportement, les capacités et les limitations d'un agent Roo. Chaque mode est conçu pour un type de tâche particulier (code, debug, architect, ask, orchestrator, etc.) et peut être optimisé pour différents modèles de langage et niveaux de complexité.

## Architecture à 5 niveaux (n5)

L'architecture à 5 niveaux (n5) est une approche innovante qui organise les modes Roo en cinq niveaux de complexité, permettant d'optimiser les coûts d'utilisation tout en maintenant la qualité des résultats :

1. **MICRO** : Pour les tâches très simples (Claude 3 Haiku / Qwen3-0.6B)
2. **MINI** : Pour les tâches simples (Claude 3.5 Sonnet / Qwen3-4B)
3. **MEDIUM** : Pour les tâches standard (Claude 3.5 Sonnet / Qwen3-14B)
4. **LARGE** : Pour les tâches complexes (Claude 3.7 Sonnet / Qwen3-32B)
5. **ORACLE** : Pour les tâches très complexes (Claude 3.7 Opus / Qwen3-235B-A22B)

Pour plus de détails sur cette architecture, consultez le [README de l'architecture n5](n5/README.md).

## Structure du répertoire

### Répertoires principaux

- **[n5/](n5/)** : Implémentation de l'architecture à 5 niveaux de complexité
  - `configs/` : Configurations des modes pour chaque niveau
  - `docs/` : Documentation et guides
  - `tests/` : Tests pour les mécanismes d'escalade et désescalade
  - `test-results/` : Résultats des tests d'escalade et désescalade

- **[custom/](custom/)** : Modes personnalisés spécifiques
  - `examples/` : Exemples de modes personnalisés

- **[optimized/](optimized/)** : Modes optimisés pour différents modèles
  - `docs/` : Documentation sur l'optimisation des modes

- **[configs/](configs/)** : Fichiers de configuration généraux pour les modes
  - `standard-modes.json.original` : Configuration originale des modes standards
  - `vscode-custom-modes.json` : Configuration pour VSCode

- **[docs/](docs/)** : Documentation sur les modes
  - `criteres-decision/` : Critères de décision pour la sélection des modes
  - `implementation/` : Guides d'implémentation et de déploiement

- **[tests/](tests/)** : Tests pour les modes personnalisés
  - `test-escalade.js` : Tests pour le mécanisme d'escalade
  - `test-desescalade.js` : Tests pour le mécanisme de désescalade

### Fichiers importants

- **[docs/implementation/guide-installation-modes-personnalises.md](docs/implementation/guide-installation-modes-personnalises.md)** : Guide détaillé pour l'installation et la configuration des modes personnalisés
- **[docs/guide-verrouillage-famille-modes.md](docs/guide-verrouillage-famille-modes.md)** : Guide sur le verrouillage des familles de modes
- **[docs/guide-import-export.md](docs/guide-import-export.md)** : Guide pour l'import et l'export des configurations de modes
- **[docs/directives-modes-custom.md](docs/directives-modes-custom.md)** : Directives pour la création de modes personnalisés

## Mécanismes d'escalade et désescalade

L'architecture n5 implémente des mécanismes d'escalade et de désescalade qui permettent à Roo de passer automatiquement d'un niveau de complexité à un autre en fonction de la difficulté de la tâche :

- **Escalade** : Passage à un niveau supérieur lorsque la tâche est trop complexe pour le niveau actuel
- **Désescalade** : Passage à un niveau inférieur lorsque la tâche peut être résolue efficacement avec un modèle moins puissant

Ces mécanismes sont testés et validés par des scripts de test spécifiques disponibles dans le répertoire `n5/tests/`.

## Types de modes disponibles

L'architecture n5 propose plusieurs types de modes, chacun optimisé pour un type de tâche spécifique :

| Type | Description |
|------|-------------|
| **Code** | Modes pour le développement de code, du simple bug à la conception de systèmes complexes |
| **Debug** | Modes pour le débogage, de l'erreur simple aux problèmes systémiques |
| **Architect** | Modes pour la conception d'architecture, des suggestions rapides à la conception distribuée |
| **Ask** | Modes pour répondre aux questions, des réponses courtes aux synthèses complexes |
| **Orchestrator** | Modes pour l'orchestration de tâches, de la délégation simple à l'orchestration complexe |

## Installation et utilisation

### Installation des modes

Pour installer des modes personnalisés, vous pouvez utiliser les scripts de déploiement disponibles dans le répertoire `roo-config/deployment-scripts/` :

```powershell
# Déploiement simple des modes
cd ../roo-config/deployment-scripts
./simple-deploy.ps1

# Déploiement avec options avancées
./deploy-modes-simple-complex.ps1
```

### Utilisation des modes

Une fois installés, les modes personnalisés apparaissent dans l'interface de Roo et peuvent être sélectionnés comme n'importe quel autre mode. Vous pouvez également utiliser l'Orchestrateur pour router automatiquement les tâches vers le mode le plus approprié.

## Création de modes personnalisés

Pour créer vos propres modes personnalisés, suivez les étapes décrites dans le [guide d'installation des modes personnalisés](docs/implementation/guide-installation-modes-personnalises.md).

## Tests et validation

Les modes personnalisés sont testés et validés à l'aide de scripts de test spécifiques :

- Tests d'escalade : `tests/test-escalade.js`
- Tests de désescalade : `tests/test-desescalade.js`

Ces tests vérifient que les mécanismes d'escalade et de désescalade fonctionnent correctement et que les modes répondent aux critères de qualité définis.

## Ressources supplémentaires

- [Guide complet des modes Roo](../docs/guide-complet-modes-roo.md)
- [Rapport de synthèse des modes Roo](../docs/rapport-synthese-modes-roo.md)
- [Guide d'escalade et désescalade](../docs/guides/guide-escalade-desescalade.md)
- [Documentation de la configuration Roo](../roo-config/README.md)
