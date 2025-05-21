# Exemples d'utilisation avancée des MCPs quickfiles et jinavigator

Ce répertoire contient des exemples d'utilisation avancée combinant les MCPs (Model Context Protocol) quickfiles et jinavigator pour réaliser des tâches complexes.

## Prérequis

- Node.js (v14 ou supérieur)
- Les serveurs MCP quickfiles et jinavigator correctement installés et configurés

## Structure des exemples

1. **web-to-markdown-saver.js** - Convertit plusieurs pages web en Markdown et les enregistre dans des fichiers
2. **web-data-analyzer.js** - Extrait des informations de plusieurs sites web et les analyse
3. **content-enricher.js** - Lit plusieurs fichiers et enrichit leur contenu avec des informations web
4. **complete-workflow.js** - Démontre un workflow complet (collecte, traitement, stockage)

## Comment exécuter les exemples

Chaque exemple peut être exécuté directement avec Node.js :

```bash
node examples/web-to-markdown-saver.js
node examples/web-data-analyzer.js
node examples/content-enricher.js
node examples/complete-workflow.js
```

## Description détaillée des exemples

### 1. web-to-markdown-saver.js

Ce script utilise le MCP jinavigator pour convertir plusieurs pages web en Markdown, puis le MCP quickfiles pour enregistrer les résultats dans des fichiers.

**Fonctionnalités :**
- Connexion aux deux serveurs MCP
- Conversion de plusieurs URLs en Markdown en une seule requête
- Écriture des fichiers Markdown générés

### 2. web-data-analyzer.js

Ce script utilise le MCP jinavigator pour extraire des informations de plusieurs sites web, puis le MCP quickfiles pour analyser ces informations (compter les occurrences de motifs spécifiques).

**Fonctionnalités :**
- Extraction de contenu web
- Stockage temporaire des données
- Analyse des données (recherche de motifs)
- Génération d'un rapport d'analyse

### 3. content-enricher.js

Ce script utilise le MCP quickfiles pour lire plusieurs fichiers locaux, puis le MCP jinavigator pour enrichir leur contenu avec des informations provenant du web.

**Fonctionnalités :**
- Lecture de fichiers locaux
- Extraction d'informations web pertinentes
- Combinaison des contenus locaux et web
- Génération de fichiers enrichis

### 4. complete-workflow.js

Ce script démontre un workflow complet utilisant les deux MCPs pour collecter des informations, les traiter et les stocker de manière structurée.

**Fonctionnalités :**
- Collecte d'informations à partir de plusieurs sources web
- Extraction de sections spécifiques
- Analyse de mots-clés
- Génération de résumés
- Stockage structuré des données brutes et traitées
- Génération de rapports de synthèse et comparatifs

## Avantages de l'utilisation combinée des MCPs

1. **Modularité** : Chaque MCP se concentre sur sa spécialité (manipulation de fichiers pour quickfiles, traitement web pour jinavigator)
2. **Efficacité** : Les opérations en lot permettent de traiter plusieurs fichiers ou URLs en une seule requête
3. **Flexibilité** : Les MCPs peuvent être combinés de différentes manières pour répondre à des besoins spécifiques
4. **Extensibilité** : De nouveaux MCPs peuvent être ajoutés pour étendre les fonctionnalités
5. **Séparation des préoccupations** : Chaque MCP gère un aspect spécifique du traitement

## Comparaison avec des solutions traditionnelles

| Aspect | Approche MCP | Approche traditionnelle |
|--------|-------------|------------------------|
| **Modularité** | Haute (MCPs spécialisés) | Variable (souvent monolithique) |
| **Maintenance** | Simplifiée (mise à jour indépendante) | Complexe (dépendances étroites) |
| **Extensibilité** | Facile (ajout de nouveaux MCPs) | Difficile (modifications profondes) |
| **Réutilisabilité** | Élevée (MCPs utilisables dans différents contextes) | Faible (code souvent spécifique) |
| **Performances** | Optimisées (opérations en lot) | Variables (souvent séquentielles) |

## Conclusion

Ces exemples démontrent comment l'utilisation combinée des MCPs quickfiles et jinavigator permet de réaliser des tâches complexes de manière modulaire, efficace et flexible. Cette approche offre des avantages significatifs par rapport aux solutions traditionnelles, notamment en termes de modularité, de maintenance et d'extensibilité.