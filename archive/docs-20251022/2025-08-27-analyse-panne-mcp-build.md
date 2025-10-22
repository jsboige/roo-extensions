# Post-Mortem : Panne des Serveurs MCP suite à une Régression du Build

**Date:** 2025-08-27

## 1. Résumé de l'Incident

Le 27 août 2025, plusieurs serveurs MCP critiques (`quickfiles`, `jinavigator`, `jupyter`, `github-projects`) ont cessé de fonctionner, empêchant leur démarrage par l'extension Roo. L'erreur rapportée était `Error: Cannot find module`, indiquant que les points d'entrée des serveurs (les fichiers JavaScript compilés) étaient introuvables.

L'incident a été entièrement résolu en restaurant les processus de build et en corrigeant un bug de démarrage dans le `jupyter-mcp-server` qui masquait le problème initial.

## 2. Cause Racine

L'enquête a révélé une double cause :

1.  **Absence d'Artefacts de Build :** La cause première était la suppression ou l'absence des répertoires `build/` (ou `dist/`) et `node_modules/` dans les dossiers des serveurs MCP affectés. Sans ces répertoires, les dépendances (comme le compilateur TypeScript `tsc`) et les fichiers JavaScript exécutables étaient manquants, provoquant l'échec du démarrage.
2.  ** mauvaise Gestion du Mode Hors Ligne (Jupyter MCP) :** L'erreur de build était masquée par un second bug dans le `jupyter-mcp-server`. Celui-ci tentait systématiquement de se connecter à un serveur Jupyter externe à son démarrage. En l'absence de ce serveur, le processus plantait brutalement, même quand il aurait dû démarrer en mode "hors ligne" dégradé. Cette erreur empêchait une analyse claire du problème de build initial.

## 3. Chronologie de la Résolution

- **Hypothèse Initiale :** Une recherche sémantique sur `"processus de build et gestion des dépendances"` a rapidement pointé vers une compilation TypeScript (`tsc`) comme étape nécessaire. L'absence des répertoires de build a été confirmée par une inspection des fichiers.
- **Diagnostic sur `quickfiles-server` :**
    - Tentative de build manuel (`npm run build`) révèle l'absence de `tsc`.
    - L'installation des dépendances (`npm install`) puis le build ont permis de corriger localement le problème pour ce serveur.
- **Correction Globale :** Le script PowerShell `scripts/mcp/compile-mcp-servers.ps1` a été identifié comme la solution d'orchestration pour réinstaller les dépendances et recompiler tous les serveurs. L'exécution de ce script a résolu l'erreur `Cannot find module` pour tous les serveurs.
- **Diagnostic du Problème Jupyter :** Les logs ont alors révélé l'erreur `ECONNREFUSED` du serveur Jupyter. L'analyse du code (`index.ts` et `services/jupyter.ts`) a montré que la logique du mode hors ligne était défaillante.
- **Correction du Bug Jupyter :** Deux modifications ont été apportées :
    1.  Dans `services/jupyter.ts`, le test de connexion est maintenant correctement ignoré si le drapeau `skipConnectionCheck` est actif.
    2.  Dans `index.ts`, l'échec de la connexion à Jupyter est maintenant capturé comme un avertissement non bloquant, permettant au serveur de démarrer en mode dégradé au lieu de planter.
- **Validation Finale :** Une nouvelle exécution de `compile-mcp-servers.ps1` a confirmé que tous les serveurs compilent et démarrent correctement, y compris `jupyter-mcp-server` qui affiche désormais un avertissement approprié.

## 4. Impact

- **Utilisateurs :** Perte totale des fonctionnalités offertes par les serveurs MCP affectés.
- **Technique :** L'incident n'a pas causé de perte de données.

## 5. Leçons Apprises et Actions Correctives

1.  **Leçon : La CI doit valider les artefacts de build.** Le processus d'intégration continue aurait dû détecter l'absence des fichiers compilés.
    - **Action :** Mettre à jour la pipeline de CI pour inclure une étape qui vérifie la présence des répertoires `build/` après la compilation de chaque MCP.

2.  **Leçon : Les dépendances externes doivent être gérées avec élégance.** Le `jupyter-mcp-server` ne devrait jamais planter si sa dépendance (le serveur Jupyter) est indisponible au démarrage.
    - **Action :** Le bug a été corrigé. Une revue des autres MCP pourrait être menée pour s'assurer qu'ils gèrent tous correctement leurs dépendances externes.

3.  **Leçon : La documentation sur le démarrage hors ligne est cruciale.** Le fait que le mode hors ligne était documenté a été un indice clé pour diagnostiquer le bug du serveur Jupyter.
    - **Action :** S'assurer que chaque MCP ayant un mode de fonctionnement dégradé le documente clairement dans son `README.md` et son `TROUBLESHOOTING.md`.

## 6. Accessibilité Sémantique

Cette analyse a été rédigée pour être facilement découvrable via des recherches sémantiques telles que :
- *"que faire si un serveur MCP ne trouve pas son module au démarrage ?"*
- *"erreur ECONNREFUSED sur le serveur jupyter"*
- *"comment recompiler les serveurs MCP ?"*