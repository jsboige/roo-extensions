# Audit Technique des Tests E2E pour `roo-state-manager`

Ce document retrace le processus de débogage qui a conduit à la résolution des échecs systématiques des tests End-to-End (E2E) du serveur MCP `roo-state-manager`. Il décrit le problème initial, les fausses pistes explorées et le diagnostic final.

## 1. Problématique Initiale : La "Race Condition"

À l'origine, les tests E2E échouaient de manière intermittente avec des erreurs `ECONNREFUSED`. Le diagnostic initial a correctement identifié une "race condition" : les tests tentaient de se connecter au service Qdrant avant que celui-ci ne soit pleinement opérationnel.

Pour y remédier, une solution basée sur le `globalSetup` de Jest a été implémentée. Un script, [`tests/global-setup.ts`](../../../../mcps/internal/servers/roo-state-manager/tests/global-setup.ts:1), a été configuré pour s'exécuter avant toute la suite de tests. Ce script sonde un endpoint de health check (`/readyz`) de Qdrant et met en pause l'exécution jusqu'à obtenir une réponse valide, garantissant ainsi que le service est prêt.

## 2. Fausse Piste : L'Isolation Réseau des Workers Jest

Malgré la mise en place du `globalSetup`, les tests continuaient d'échouer, mais de manière déroutante : le `globalSetup` réussissait, prouvant que Qdrant était accessible depuis le processus principal de Jest, mais les tests individuels (exécutés dans des workers séparés) échouaient toujours avec des erreurs `ECONNREFUSED`.

Cette situation a orienté notre enquête vers une hypothèse d'isolation réseau. Nous avons suspecté que les workers de Jest, étant des processus enfants, n'héritaient pas correctement de la configuration réseau ou de l'accès au `localhost` du conteneur Docker où Qdrant était exécuté. Cette piste semblait plausible car elle expliquait pourquoi le processus parent (`globalSetup`) pouvait voir le service, mais pas les processus enfants (les tests).

Cette hypothèse s'est avérée être une **fausse piste**.

## 3. Diagnostic Final : Le Service Qdrant n'était pas démarré

Après avoir écarté l'isolation réseau, une vérification plus fondamentale a révélé la véritable cause racine, d'une simplicité déconcertante : le service Qdrant n'était tout simplement pas en cours d'exécution dans l'environnement de test.

Le script qui lançait les tests démarrait bien le serveur `roo-state-manager`, mais omettait de lancer sa dépendance principale, le conteneur Docker de Qdrant.

Toutes les erreurs `ECONNREFUSED` provenaient de ce simple fait : le serveur tentait de se connecter à un port (`6333`) où aucun processus n'écoutait. Le succès apparent du `globalSetup` était probablement un artefact d'un démarrage manuel antérieur du service Qdrant lors de tests locaux, ce qui a contribué à la confusion.

## 4. Solution Définitive et Prérequis

La solution n'est pas une modification de code, mais un **prérequis d'environnement**.

**Solution :** S'assurer que le service Qdrant est démarré et accessible avant de lancer la suite de tests E2E.

Concrètement, cela signifie que tout script ou pipeline de CI/CD responsable de l'exécution des tests doit impérativement inclure une étape pour démarrer l'infrastructure nécessaire, notamment Qdrant.