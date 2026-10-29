# Stratégie de Test Alternative pour les MCP Servers en Node.js

> ⚠️ **[Exemple périmé — sweep #2639 WS3, 29/10/2026]** La stratégie (script Node.js isolé pour
> tester un serveur MCP ESM) reste valable, mais son cas d'usage démonstrateur `quickfiles-server`
> a été supprimé du code (2026-09, #3423). Appliquer la démarche aux serveurs existants
> (`mcps/internal/servers/` : roo-state-manager, sk-agent, jinavigator-server, …).

## 🎯 Contexte et Problématique

Lors du développement de MCP Servers en Node.js, notamment ceux utilisant des modules ES (ESM), la mise en place de frameworks de test traditionnels comme Jest peut s'avérer complexe. Les problèmes de configuration liés à la transpilation (Babel), à la résolution des modules (`"type": "module"` dans `package.json`) et aux imports dynamiques peuvent ralentir considérablement le cycle de développement.

Face à ces défis, une approche de test plus pragmatique et directe a été adoptée.

## 💡 Approche : Un Script de Test Node.js Isolé

Plutôt que de dépendre d'un test runner lourd, notre stratégie repose sur l'utilisation d'un simple script de test Node.js (`*.mjs` ou `*.js` avec la configuration ESM appropriée).

### Pourquoi cette approche ?

1.  **Simplicité :** Élimine la complexité de configuration de Jest/Babel pour ESM. Le script s'exécute directement avec Node.js, reflétant l'environnement de production du MCP.
2.  **Rapidité :** L'exécution est quasi instantanée car elle ne nécessite ni transplilation à la volée ni chargement d'un framework lourd.
3.  **Isolation Fiable :** En s'appuyant sur des bibliothèques comme `mock-fs`, nous pouvons simuler un système de fichiers en mémoire. Cela garantit que les tests sont parfaitement isolés, non destructifs pour le système de fichiers réel, et entièrement reproductibles.
4.  **Contrôle Total :** Le développeur a un contrôle total sur le flux d'exécution des tests, ce qui facilite le débogage.

### Comment ça fonctionne ?

La stratégie s'articule autour des points suivants :

1.  **Le Script de Test :** Un fichier (par exemple, `simple-test.mjs`) est créé à la racine du projet du MCP.
2.  **L'isolation du Système de Fichiers :** La bibliothèque `mock-fs` est utilisée pour créer un système de fichiers virtuel en mémoire avant l'exécution des tests. On y définit les fichiers et répertoires nécessaires aux scénarios de test.
3.  **Importation de la Classe Serveur :** Le script importe directement la classe du serveur MCP (ex: `QuickFilesServer`).
4.  **Instanciation et Appel Direct :** La classe est instanciée, et ses méthodes publiques (les `handlers` des outils) sont appelées directement, en leur passant des objets `request` simulés.
5.  **Assertions :** Les résultats sont validés à l'aide du module `assert` natif de Node.js.
6.  **Nettoyage :** Après les tests, `mock-fs.restore()` est appelé pour restaurer le système de fichiers réel.

### ✅ Cas d'Usage Concret : Le Test de `quickfiles-server`

La stratégie a été mise en œuvre avec succès pour tester le MCP `quickfiles-server`. Le script `simple-test.mjs` a permis de valider en profondeur toutes les fonctionnalités de manipulation de fichiers (`writeFile`, `createDirectory`, `deleteFiles`, `listDirectoryContents`, etc.) dans un environnement contrôlé et sans les frictions habituelles liées à la configuration de Jest avec ESM.

Cet exemple sert de modèle de référence pour le test des futurs MCP Servers développés en Node.js.