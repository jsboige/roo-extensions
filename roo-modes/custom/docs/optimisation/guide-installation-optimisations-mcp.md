# Guide d'installation des optimisations MCP pour les modes personnalisés

Ce guide explique comment installer et utiliser les optimisations MCP pour les modes personnalisés de Roo.

## Introduction

Les optimisations MCP permettent d'améliorer significativement les performances et l'efficacité des modes personnalisés en utilisant les serveurs MCP (Model Context Protocol) de manière optimale. Ces optimisations incluent des exemples concrets d'utilisation des MCPs pour différentes opérations, comme la manipulation de fichiers, la navigation web, les recherches, et les commandes système.

## Prérequis

- PowerShell 5.1 ou supérieur
- Accès aux fichiers de configuration des modes personnalisés
- Droits d'écriture sur les fichiers de configuration

## Installation automatique

Un script PowerShell est fourni pour automatiser l'installation des optimisations MCP dans les modes personnalisés existants.

### Étapes d'installation

1. Ouvrez PowerShell en tant qu'administrateur
2. Naviguez vers le répertoire contenant le script d'installation
   ```powershell
   cd chemin\vers\roo-modes\custom\scripts
   ```
3. Exécutez le script d'installation
   ```powershell
   .\update-mcp-optimizations.ps1
   ```
4. Vérifiez les résultats de l'installation
   - Le script affichera le nombre de fichiers mis à jour
   - En cas d'erreur, consultez les messages d'erreur pour plus d'informations

## Installation manuelle

Si vous préférez installer les optimisations manuellement, vous pouvez suivre ces étapes :

1. Ouvrez le fichier de configuration du mode personnalisé que vous souhaitez mettre à jour
2. Localisez la section `/* UTILISATION OPTIMISÉE DES MCPs */`
3. Remplacez cette section par la version optimisée correspondant au niveau du mode
   - Pour les modes micro et mini : utilisez la section du fichier `roo-modes/custom/docs/optimisation/utilisation-optimisee-mcps.md`
   - Pour les modes medium et large : utilisez la section du fichier `roo-modes/custom/docs/optimisation/utilisation-optimisee-mcps.md`
   - Pour les modes oracle : utilisez la section du fichier `roo-modes/custom/docs/optimisation/utilisation-optimisee-mcps.md`
4. Enregistrez le fichier

## Vérification de l'installation

Pour vérifier que les optimisations ont été correctement installées :

1. Ouvrez le fichier de configuration mis à jour
2. Vérifiez que la section `/* UTILISATION OPTIMISÉE DES MCPs */` contient les exemples concrets d'utilisation des MCPs
3. Vérifiez que les exemples sont adaptés au niveau du mode (micro, mini, medium, large, oracle)

## Utilisation des optimisations

Une fois les optimisations installées, les modes personnalisés utiliseront automatiquement les MCPs de manière optimale. Vous pouvez consulter le guide d'utilisation des MCPs pour plus d'informations sur les différentes fonctionnalités disponibles.

### Documentation supplémentaire

- [Guide d'utilisation des MCPs](../../../../docs/guide-utilisation-mcps.md) - Guide complet sur l'utilisation des MCPs
- [Exemples d'utilisation optimisée](./utilisation-optimisee-mcps.md) - Exemples d'utilisation optimisée des MCPs pour différents niveaux de modes

## Résolution des problèmes

### Problème : Le script d'installation échoue

**Solution** : Vérifiez que vous avez les droits d'administrateur et que les chemins vers les fichiers de configuration sont corrects. Vous pouvez également essayer d'installer les optimisations manuellement.

### Problème : Les optimisations ne sont pas appliquées correctement

**Solution** : Vérifiez que la section `/* UTILISATION OPTIMISÉE DES MCPs */` a été correctement remplacée dans le fichier de configuration. Si nécessaire, copiez manuellement la section depuis les fichiers d'exemple.

### Problème : Les exemples ne sont pas adaptés au niveau du mode

**Solution** : Assurez-vous d'utiliser les exemples correspondant au niveau du mode (micro, mini, medium, large, oracle). Vous pouvez trouver ces exemples dans le fichier `roo-modes/custom/docs/optimisation/utilisation-optimisee-mcps.md`.

## Support

Si vous rencontrez des problèmes lors de l'installation ou de l'utilisation des optimisations MCP, vous pouvez contacter l'équipe de support ou consulter la documentation en ligne.