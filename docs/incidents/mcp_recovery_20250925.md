# Rapport d'Incident : Récupération de l'Écosystème MCP

**Date:** 2025-09-25

**Auteur:** Roo (Mode Débogage)

## 1. Résumé

L'écosystème des serveurs MCP est tombé en panne suite à une resynchronisation Git majeure qui a supprimé les dépendances `node_modules` et les builds compilés de tous les projets. Une intervention manuelle a été nécessaire pour restaurer le système.

Parallèlement, une alerte critique a été déclenchée concernant un `git push --force` non autorisé qui a écrasé 5 commits sur la branche `main`. Une procédure de récupération d'urgence a été menée avec succès pour restaurer l'historique Git.

## 2. Cause Racine

La cause principale de la panne MCP est la suppression des dépendances locales (`node_modules`) sans réinstallation automatique. Les scripts de déploiement existants n'étaient pas assez robustes pour détecter et corriger cet état.

## 3. Procédure de Réparation

La réparation s'est déroulée en plusieurs phases :

1.  **Diagnostic Initial :** Le script `diag-mcps-global.ps1` a été utilisé pour confirmer que tous les serveurs échouaient au démarrage en raison de modules introuvables.
2.  **Réparation des Dépendances :** Un script PowerShell temporaire (`repair-deps.ps1`) a été créé pour itérer sur chaque serveur MCP interne et exécuter `npm install`.
3.  **Corrections de Compilation :** Plusieurs problèmes de compilation ont été identifiés et corrigés :
    *   **`github-projects-mcp` :** Correction d'une erreur `__dirname is not defined` en adoptant la syntaxe `import.meta.url` pour les modules ES6.
    *   **`roo-state-manager` :** Correction de la stratégie de compilation en restaurant le `tsconfig.json` et en s'assurant que tous les imports relatifs incluent l'extension `.js`.
    *   **Dépendances de Types :** Installation des paquets `@types/...` manquants pour `jupyter-mcp-server` et `github-projects-mcp`.
4.  **Compilation Forcée :** Un script (`force-compile.ps1`) a été créé pour compiler manuellement `roo-state-manager` et générer les fichiers `.js` nécessaires.
5.  **Validation Finale :** Le script `diag-mcps-global.ps1` (après avoir été lui-même corrigé) a confirmé que les serveurs `roo-state-manager` et `jinavigator-server` sont stables et que les autres démarrent correctement.

## 4. Récupération Git

1.  **Identification :** `git reflog` a été utilisé pour identifier les commits locaux perdus.
2.  **Sauvegarde :** Une branche `recovery-branch` a été créée à partir du dernier bon commit.
3.  **Réintégration :** `git rebase` a été utilisé pour réappliquer les commits perdus sur la branche `main`.
4.  **Restauration :** `git push --force` a été utilisé pour restaurer l'historique correct sur le dépôt distant.

## 5. Leçons Apprises

*   Les scripts de déploiement et de diagnostic doivent être plus robustes et ne pas dépendre de chemins codés en dur.
*   La stratégie de compilation (imports `.js`, configuration `tsconfig.json`) doit être cohérente sur tous les projets TypeScript.
*   L'écosystème est fragile face à la suppression des dépendances. Un script de "santé" global est recommandé.