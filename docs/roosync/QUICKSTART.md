# RooSync - Guide Rapide (30 lignes)

## Qu'est-ce que c'est ?
Synchronisation de configs entre machines Windows via MCP.

## Commandes essentielles

```bash
# 1. Voir les différences entre ma machine et une autre
roosync_compare_config

# 2. Collecter ma config locale
roosync_get_machine_inventory

# 3. Voir le statut global
roosync_get_status

# 4. Envoyer un message à une autre machine
roosync_send_message --to myia-ai-01 --subject "Test" --body "Hello"

# 5. Lire mes messages
roosync_read_inbox
```

## Fichiers importants
- `G:/Mon Drive/Synchronisation/RooSync/.shared-state/` - État partagé
- `sync-config.ref.json` - Config de référence

## En cas de problème
1. Vérifier que le MCP roo-state-manager est chargé
2. Lancer `roosync_get_status` pour voir l'état
3. Vérifier les logs dans `.shared-state/logs/`

C'est tout. Le reste est de l'overengineering.
