# Action : Initialize-Workspace

## Rôle

L'action `Initialize-Workspace` est une commande fondamentale du `sync-manager`. Son rôle principal est de préparer et de valider l'environnement de synchronisation partagé, garantissant ainsi que tous les participants au processus RUSH-SYNC partent d'une base commune, saine et connue.

Cette action est cruciale pour la stabilité et la fiabilité du système. En établissant un "état zéro" contrôlé, elle prévient les erreurs de configuration initiales et facilite grandement la résolution de problèmes futurs, puisqu'un point de référence stable est toujours disponible.

## Fonctionnement

L'action `Initialize-Workspace` effectue les opérations suivantes :

1.  **Vérification du dossier partagé** : Elle lit la variable `$config.sharedStatePath` pour identifier l'emplacement du dossier de synchronisation partagé.
2.  **Création du dossier** : Si le dossier spécifié n'existe pas, l'action le crée. Cela garantit que le chemin est toujours disponible pour les opérations de synchronisation.
3.  **Initialisation des artefacts** : L'action s'assure que les fichiers suivants existent dans le dossier partagé. S'ils sont manquants, elle les crée :
    *   **`sync-config.ref.json`** : Une copie de la configuration locale (`config/sync-config.json`). Ce fichier sert de "source de vérité" pour la configuration du système, permettant de détecter toute déviation sur les autres machines.
    *   **`sync-roadmap.md`** : Un fichier Markdown destiné à suivre les décisions de synchronisation manuelles et les actions en attente.
    *   **`sync-dashboard.json`** : Un fichier JSON qui maintient un état en temps réel de l'environnement de synchronisation, incluant des informations comme la date de la dernière synchronisation réussie et l'état général du système.
    *   **`sync-report.md`** : Un fichier Markdown destiné à recevoir les rapports générés par les futures actions de synchronisation.

## Production

Lorsque vous exécutez l'action `Initialize-Workspace`, les fichiers suivants sont créés dans le répertoire défini par `$config.sharedStatePath`, uniquement s'ils n'existent pas déjà :

*   `sync-config.ref.json`
*   `sync-roadmap.md`
*   `sync-dashboard.json`
*   `sync-report.md`

Toute exécution ultérieure de cette commande vérifiera simplement la présence de ces fichiers sans les modifier, garantissant la pérennité de l'environnement initialisé.