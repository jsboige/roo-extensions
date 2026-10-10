# Tests Git MCP

Ce répertoire contient les tests et outils de débogage pour le serveur MCP Git.

## Fichiers

- `server_corrected.py` : Version corrigée du serveur MCP Git (15.4 KB)
- `server_patch.py` : Patch pour le serveur MCP Git (3.1 KB)

## Utilisation

Ces fichiers ont été déplacés depuis la racine du projet lors du nettoyage du 25/05/2025 pour maintenir une structure de projet propre.

(`test_mcp_git_local.py` a été retiré le 10/10/2026 : script de debug 2025 classé mort — cible non peuplée, zéro assert, aucune invocation CI.)

## Dépendances

```bash
pip install click gitpython mcp pydantic