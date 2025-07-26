# Analyse de l'échec du test E2E : Problème de connexion Qdrant

## Contexte

Le test End-to-End (E2E) pour la recherche sémantique (`tests/e2e/semantic-search.test.ts`) du MCP `roo-state-manager` échouait de manière systématique avec une erreur de connexion à la base de données vectorielle Qdrant. Ce document détaille le processus de débogage, les hypothèses testées, les corrections apportées au code, et la conclusion sur la cause racine du problème.

## Problème Initial

Le test échouait avec l'erreur `TypeError: fetch failed`, dont la cause sous-jacente était `connect ECONNREFUSED <QDRANT_IP>:<QDRANT_PORT>`.

Cela indique un refus de connexion TCP au niveau du système d'exploitation. La connexion au service Qdrant Cloud était impossible depuis l'environnement de test Jest.

## Étapes du Débogage et Corrections

Plusieurs pistes ont été explorées pour identifier et corriger le problème.

### 1. Correction du Code de Test

Le code de test initial a été entièrement réécrit pour corriger plusieurs "anti-patterns":
*   **Utilisation incorrecte du client Qdrant :** Le test instançiait son propre client sans utiliser la configuration globale (notamment la clé API), ce qui a été corrigé pour utiliser une instance partagée.
*   **Logique asynchrone :** `setTimeout` a été remplacé par une fonction `waitForPointInCollection` plus robuste pour attendre l'indexation.
*   **Gestion du cycle de vie :** Le code a été structuré pour gérer correctement la création et la suppression de la collection de test dans Qdrant.

**Résultat :** Malgré un code de test plus propre et correct, l'erreur `ECONNREFUSED` persistait.

### 2. Problème avec `fetch` dans l'environnement Jest

L'hypothèse suivante était une incompatibilité entre l'implémentation de `fetch` native de Node.js (via la bibliothèque `undici`, visible dans la stack trace) et l'environnement d'exécution de Jest.

Deux stratégies ont été tentées pour contourner ce problème :

#### a) Polyfill `globalThis.fetch`

Une tentative a été faite pour "patcher" l'objet global `fetch` en utilisant la bibliothèque `node-fetch`. Cela a été implémenté dans le fichier `tests/setup-env.ts`.

#### b) Initialisation Paresseuse (Lazy Loading)

Pour s'assurer que le polyfill `fetch` était bien en place *avant* l'initialisation du client Qdrant, le service `qdrant.ts` a été refactorisé. Au lieu d'exporter une instance, il exporte maintenant une fonction `getQdrantClient()` qui instancie le client seulement lors du premier appel.

**Résultat :** L'initialisation paresseuse a fonctionné, mais l'erreur `ECONNREFUSED` persistait. La stack trace montrait toujours que `undici` était utilisé, prouvant que ces tentatives de contournement étaient inefficaces.

### 3. Mapping de Module Jest

Une tentative plus agressive a été faite en utilisant le `moduleNameMapper` de Jest pour forcer la redirection de toute tentative d'import du module `undici` vers `node-fetch`.

**Résultat :** Cette approche a bien redirigé le module, mais a provoqué une nouvelle erreur (`TypeError: undici_1.Agent is not a constructor`), car le client Qdrant s'attendait à l'API interne spécifique d'`undici` et a reçu celle, incompatible, de `node-fetch`.

## Diagnostic Final

Après avoir épuisé les solutions au niveau du code et de la configuration des tests, la conclusion est que le problème est **externe au projet lui-même**.

L'erreur `ECONNREFUSED` persistante, malgré un code et une configuration de test corrigés, pointe vers l'une des deux causes suivantes :

1.  **Environnement Réseau restrictif (Cause la plus probable) :** Il existe très probablement un blocage au niveau de l'environnement d'exécution (pare-feu local, logiciel de sécurité, proxy d'entreprise, configuration DNS, etc.) qui empêche le processus Node.js lancé par Jest d'établir des connexions TCP sortantes vers le serveur Qdrant.
2.  **Incompatibilité de bas niveau :** Un bug non-documenté existe dans l'interaction complexe entre `@qdrant/js-client-rest`, `ts-jest`, et la version de Node.js/`undici` utilisée.

## Prochaines Étapes Recommandées

Le problème ne pouvant être résolu au niveau du code de l'application, les prochaines étapes de diagnostic doivent se concentrer sur l'environnement :
*   **Test de connectivité simple :** Exécuter un simple script Node.js (`node test-connection.js`) en dehors de Jest pour voir si une connexion basique à Qdrant peut être établie.
*   **Vérification du Pare-feu/Proxy :** Inspecter les règles de pare-feu et les configurations proxy de la machine pour s'assurer qu'elles n'interfèrent pas avec les connexions sortantes sur le port `6333`.
*   **Mise à jour des dépendances :** Tenter de mettre à jour `jest`, `ts-jest`, et `@qdrant/js-client-rest` vers leurs dernières versions respectives.