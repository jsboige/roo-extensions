# Répertoire des logs de conflits de synchronisation

Ce répertoire contient les logs des conflits détectés lors des opérations de synchronisation Git.

## Structure des fichiers de log

- `sync_conflicts_YYYYMMDD_HHmmss.log` : Logs des conflits de fusion Git
- `stash_pop_conflicts_YYYYMMDD_HHmmss.log` : Logs des conflits lors de la restauration du stash

## Format des logs

Chaque fichier de log contient :
- Horodatage du conflit
- Chemin du dépôt concerné
- Branche impliquée
- Statut Git au moment du conflit
- Détails de l'erreur

Ces logs permettent un diagnostic rapide et une résolution manuelle des conflits de synchronisation.