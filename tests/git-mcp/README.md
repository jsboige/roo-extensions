# Tests Git MCP

Ce répertoire contient les tests et outils de débogage pour le serveur MCP Git.

## Fichiers

- `test_mcp_git_local.py` : Script de test principal pour reproduire et diagnostiquer les erreurs du serveur MCP Git
- `server_corrected.py` : Version corrigée du serveur MCP Git (15.4 KB)
- `server_patch.py` : Patch pour le serveur MCP Git (3.1 KB)

## Utilisation

Ces fichiers ont été déplacés depuis la racine du projet lors du nettoyage du 25/05/2025 pour maintenir une structure de projet propre.

Le script principal `test_mcp_git_local.py` simule les appels MCP pour identifier les problèmes avec le serveur Git.

## Dépendances

```bash
pip install click gitpython mcp pydantic