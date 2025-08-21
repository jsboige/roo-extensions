# Action : Compare-Config

**Module :** `Actions.psm1`

## Objectif

L'action `Compare-Config` est un mécanisme de détection de dérive de configuration. Elle compare la configuration locale d'une machine (`config/sync-config.json`) à une configuration de référence stockée dans un emplacement partagé.

L'objectif principal est d'identifier les changements de configuration et de les soumettre à une validation humaine asynchrone via la feuille de route (`sync-roadmap.md`).

## Fonctionnement

1.  **Lecture de la Configuration :** L'action utilise `Resolve-AppConfiguration` pour charger la configuration et déterminer le `sharedStatePath`.
2.  **Vérification de la Référence :** Elle vérifie l'existence d'un fichier `sync-config.ref.json` dans le `sharedStatePath`.
    *   **Si la référence n'existe pas :** La configuration locale actuelle (`config/sync-config.json`) est copiée pour devenir la première référence. Aucune comparaison n'a lieu.
    *   **Si la référence existe :** La comparaison est effectuée.
3.  **Comparaison :** La configuration locale est comparée à la configuration de référence.
4.  **Génération du Rapport :**
    *   **Si des différences sont détectées :** Un bloc de décision est ajouté à `sync-roadmap.md`. Ce bloc contient le `diff` des changements, la machine et l'heure de détection, et une case à cocher pour permettre à un opérateur d'approuver la mise à jour de la référence.
    *   **Si aucune différence n'est détectée :** L'action se termine sans rien écrire.

## Usage

```powershell
./sync-manager.ps1 -Action Compare-Config
```

## Intégration dans le Flux de Travail

Cette action est la première étape vers une gestion de configuration décentralisée et validée. Elle permet de :

-   Détecter les modifications de configuration sur n'importe quelle machine du parc.
-   Centraliser les demandes de changement dans un document unique (`sync-roadmap.md`).
-   Valider humainement chaque changement avant qu'il ne devienne la nouvelle norme pour l'ensemble du parc.