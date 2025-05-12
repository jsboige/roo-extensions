# Système de verrouillage de famille pour les modes Roo

## Présentation

Le système de verrouillage de famille est une solution technique conçue pour empêcher le basculement inapproprié des modes simples/complexes vers les modes standard. Ce système garantit que les modes restent dans leur "famille" respective, préservant ainsi leur bon fonctionnement et leur cohérence.

## Problème résolu

Ce système résout un problème critique identifié dans l'architecture des modes Roo : les modes simples/complexes basculent fréquemment vers des modes standard, ce qui rompt leur bon fonctionnement. Ce basculement inapproprié se produit car les configurations actuelles ne contiennent pas de mécanisme explicite pour maintenir un mode dans sa famille.

## Installation rapide

Pour installer le système de verrouillage de famille, exécutez le script de déploiement :

```powershell
# Dans PowerShell
.\roo-modes\scripts\deploy-family-lock.ps1
```

Ce script :
1. Vérifie les prérequis
2. Crée une sauvegarde de la configuration actuelle
3. Installe le système de verrouillage de famille
4. Exécute les tests pour vérifier le bon fonctionnement du système
5. Affiche les instructions post-installation

## Structure du système

Le système de verrouillage de famille est composé de plusieurs composants :

### 1. Configuration des modes

Le fichier `standard-modes.json` a été modifié pour inclure :
- Un validateur de famille (`mode-family-validator`)
- Des métadonnées de famille pour chaque mode (`family` et `allowedFamilyTransitions`)

### 2. Scripts de validation et d'interception

Trois scripts principaux ont été créés :
- **validate-mode-transitions.js** : Valide les transitions entre modes
- **mode-transition-interceptor.js** : Intercepte les demandes de transition de mode
- **update-mode-instructions.js** : Met à jour les instructions personnalisées des modes

### 3. Instructions personnalisées

Les instructions personnalisées des modes ont été enrichies avec :
- Une section d'identité de mode et de famille
- Des mécanismes d'escalade/désescalade renforcés
- Des restrictions explicites sur les transitions de mode

## Utilisation

Le système de verrouillage de famille est automatiquement activé lors de l'utilisation de l'outil `switch_mode`. Il n'y a pas d'action spécifique à effectuer pour l'utiliser.

### Exemple d'escalade (mode simple vers mode simple)

```xml
<switch_mode>
<mode_slug>debug-simple</mode_slug>
<reason>Cette tâche nécessite des capacités de débogage</reason>
</switch_mode>
```

### Exemple de désescalade (mode complex vers mode complex)

```xml
<switch_mode>
<mode_slug>code-complex</mode_slug>
<reason>Cette tâche nécessite des capacités de développement</reason>
</switch_mode>
```

## Maintenance

### Journaux

Les journaux de transition se trouvent dans le répertoire `logs` et peuvent être consultés pour diagnostiquer les problèmes.

### Mise à jour du système

Pour mettre à jour le système :

1. Modifier les fichiers de configuration si nécessaire
2. Exécuter le script `update-mode-instructions.js` pour mettre à jour les instructions personnalisées
3. Redémarrer les services Roo si nécessaire

## Dépannage

### Problèmes courants

1. **Transition refusée** : Vérifier que le mode cible appartient à la même famille que le mode actuel
2. **Mode non trouvé** : Vérifier que le mode existe dans la configuration
3. **Instructions personnalisées non mises à jour** : Exécuter à nouveau le script `update-mode-instructions.js`

### Restauration d'une sauvegarde

En cas de problème, vous pouvez restaurer une sauvegarde de la configuration :

```powershell
# Dans PowerShell
Copy-Item -Path ".\roo-modes\backups\modes_backup_YYYYMMDD_HHMMSS.json" -Destination ".\roo-modes\configs\standard-modes.json"
```

## Documentation complète

Pour une documentation complète du système de verrouillage de famille, consultez le fichier `guide-verrouillage-famille-modes.md`.

## Scripts disponibles

- **install-family-lock.js** : Script d'installation du système
- **validate-mode-transitions.js** : Script de validation des transitions
- **mode-transition-interceptor.js** : Script d'interception des transitions
- **update-mode-instructions.js** : Script de mise à jour des instructions
- **test-family-lock.js** : Script de test du système
- **deploy-family-lock.ps1** : Script de déploiement du système

## Contribution

Pour contribuer au développement du système de verrouillage de famille, veuillez suivre ces étapes :

1. Créer une branche pour vos modifications
2. Effectuer vos modifications
3. Exécuter les tests pour vérifier que le système fonctionne correctement
4. Soumettre une demande de fusion

## Licence

Ce système est distribué sous la même licence que le projet Roo.