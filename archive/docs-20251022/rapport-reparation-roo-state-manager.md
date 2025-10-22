# Rapport de Réparation du MCP `roo-state-manager`

## Problème Constaté

Le MCP `roo-state-manager` ne redémarrait pas automatiquement après une reconstruction (`npm run build`). Cela entraînait l'exécution d'une version obsolète du code, rendant le débogage et le déploiement de correctifs impossibles.

## Diagnostic et Cause Racine

Une analyse approfondie du `McpHub` (voir `docs/mcp/analyse_mcp_lifecycle.md`) a révélé que le mécanisme de redémarrage automatique est conditionné par la présence de la directive `watchPaths` dans la configuration du serveur (`mcp_settings.json`).

**La cause racine était l'absence de cette directive `watchPaths` pour le serveur `roo-state-manager`.** Sans elle, le `McpHub` n'avait aucune instruction pour surveiller les changements sur les fichiers compilés et ne pouvait donc pas déclencher le redémarrage.

Un problème secondaire a également été identifié : l'outil interne `rebuild_and_restart_mcp` exigeait une propriété `cwd` (working directory) au premier niveau de la configuration, alors qu'elle était imbriquée dans un objet `options`.

## Résolution

Deux actions correctives ont été menées sur le fichier `mcp_settings.json` :

1.  **Ajout de `watchPaths` :** Une directive `watchPaths` a été ajoutée à la configuration du `roo-state-manager`, pointant directement vers le fichier de sortie de la compilation :
    ```json
    "watchPaths": ["D:/roo-extensions/mcps/internal/servers/roo-state-manager/build/src/index.js"]
    ```

2.  **Correction de `cwd` :** La propriété `cwd` a été déplacée de l'objet `options` au niveau racine de la configuration du serveur pour assurer la compatibilité avec les outils de build internes.

## Validation

La correction a été validée en suivant ces étapes :
1.  Mise à jour de la configuration via les outils du MCP.
2.  Rechargement de la configuration par le `McpHub`.
3.  Exécution manuelle de la commande de build (`npm run build`) dans le répertoire du MCP.
4.  Confirmation que le serveur a bien redémarré automatiquement en exécutant avec succès son `minimal_test_tool`.

Le MCP `roo-state-manager` est maintenant pleinement opérationnel et le cycle de développement (build -> redémarrage -> test) est restauré.

---

## Recommandations pour les Développeurs de MCPs

Pour garantir un cycle de développement fluide et un redémarrage fiable des MCPs, il est impératif de suivre les bonnes pratiques suivantes :

1.  **Toujours configurer `watchPaths` :** Pour tout MCP de type `stdio` qui nécessite une compilation, ajoutez systématiquement une directive `watchPaths` dans `mcp_settings.json`. Elle doit pointer vers le principal fichier de sortie du build.
    ```json
    "watchPaths": ["<chemin-vers-votre-mcp>/build/index.js"]
    ```
    Ceci active le mécanisme de redémarrage ciblé, qui est plus rapide et plus fiable que le redémarrage global.

2.  **Configurer `cwd` à la racine :** Assurez-vous que la propriété `cwd` (Current Working Directory) est définie au premier niveau de la configuration de votre MCP, et non dans un sous-objet `options`.

### Amélioration de l'Outil `rebuild_and_restart_mcp`

L'outil a été mis à jour pour être plus intelligent et plus sûr :
*   **Avertissement :** Il affiche désormais un message d'avertissement clair si vous tentez de recompiler un MCP sans `watchPaths` configuré.
*   **Redémarrage Ciblé :** S'il détecte un `watchPaths`, il déclenche le redémarrage en "touchant" directement le fichier surveillé, garantissant ainsi le rechargement. En l'absence de `watchPaths`, il se rabat sur la méthode de redémarrage globale.