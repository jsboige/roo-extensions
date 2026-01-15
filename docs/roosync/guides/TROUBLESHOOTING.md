# RooSync Troubleshooting Guide

**Version:** 1.0.0
**Date:** 2026-01-15
**Auteur:** Claude Code (myia-web1)

---

## Table des Matières

1. [Erreurs MCP](#1-erreurs-mcp)
2. [Erreurs RooSync](#2-erreurs-roosync)
3. [Erreurs Git/Submodule](#3-erreurs-gitsubmodule)
4. [Erreurs de Synchronisation](#4-erreurs-de-synchronisation)
5. [Erreurs de Tests](#5-erreurs-de-tests)
6. [Codes d'Erreur Référence](#6-codes-derreur-référence)

---

## 1. Erreurs MCP

### 1.1 MCP ne se charge pas au démarrage

**Symptômes:**
- `/mcp` n'affiche pas les outils
- "No MCP servers configured"

**Causes possibles:**
1. Fichier `.mcp.json` manquant ou mal placé
2. Chemins incorrects dans la configuration
3. VS Code pas redémarré après configuration

**Solutions:**

```powershell
# Vérifier que .mcp.json existe
Test-Path ~/.mcp.json

# Si absent, exécuter le script d'init
.\.claude\scripts\init-claude-code.ps1

# Redémarrer VS Code COMPLÈTEMENT
```

### 1.2 Erreur "Cannot find module"

**Symptômes:**
- "Error: Cannot find module '/path/to/dist/index.js'"

**Cause:** Le submodule n'est pas compilé.

**Solution:**
```powershell
cd mcps/internal/servers/roo-state-manager
npm install
npm run build
```

### 1.3 Erreur "Bad credentials" (GitHub)

**Symptômes:**
- "HttpError: Bad credentials"
- "401 Unauthorized"

**Causes:**
1. Token GitHub invalide ou expiré
2. Token sans les bonnes permissions

**Solutions:**
1. Créer un nouveau token sur GitHub avec permissions `repo`, `project`, `read:org`
2. Mettre à jour le fichier `.env`:
```
GITHUB_TOKEN=ghp_nouveau_token
```
3. Redémarrer VS Code

### 1.4 Trop de logs stdout (crash Claude Code)

**Symptômes:**
- Claude Code crash au démarrage
- Logs massifs dans la console

**Cause:** Le MCP roo-state-manager envoie trop de logs.

**Solution:** Utiliser le wrapper intelligent:
```json
{
  "roo-state-manager": {
    "command": "node",
    "args": ["mcp-wrapper.cjs"],
    "cwd": "path/to/roo-state-manager"
  }
}
```

---

## 2. Erreurs RooSync

### 2.1 ROOSYNC_SHARED_PATH non accessible

**Symptômes:**
- "Cannot find path 'G:/Mon Drive/...'"
- "ROOSYNC_SHARED_PATH not defined"

**Causes:**
1. Google Drive non synchronisé
2. Variable d'environnement non définie
3. Chemin incorrect

**Solutions:**

```powershell
# Vérifier l'accès au dossier
Test-Path "G:/Mon Drive/Synchronisation/RooSync/.shared-state"

# Si Google Drive n'est pas monté, le synchroniser

# Vérifier le .env
cat mcps/internal/servers/roo-state-manager/.env
# Doit contenir: ROOSYNC_SHARED_PATH=G:/Mon Drive/...
```

### 2.2 Conflit d'identité machine

**Symptômes:**
- "Identity conflict detected"
- Deux machines avec le même ID

**Exemple:** `myia-web-01` vs `myia-web1`

**Solution:**
1. Identifier la machine correcte: `$env:COMPUTERNAME`
2. Supprimer le fichier de présence en conflit dans `.shared-state/machines/`
3. Redémarrer le MCP

### 2.3 Message non envoyé

**Symptômes:**
- "Message send failed"
- "Invalid recipient"

**Causes:**
1. Destinataire inexistant
2. Dossier messages non accessible
3. Format de message invalide

**Solutions:**
```powershell
# Vérifier que le destinataire existe
ls "G:/Mon Drive/Synchronisation/RooSync/.shared-state/machines/"

# Vérifier le format du message
# to, subject, body sont obligatoires
```

### 2.4 Inbox vide alors que des messages existent

**Symptômes:**
- `roosync_read_inbox` retourne vide
- Mais des fichiers existent dans `inbox/`

**Cause:** Problème de parsing JSON (souvent BOM UTF-8).

**Solution:**
Les fichiers JSON doivent être encodés en UTF-8 sans BOM:
```powershell
# Ré-enregistrer sans BOM
$content = Get-Content file.json -Raw
[System.IO.File]::WriteAllText("file.json", $content, [System.Text.UTF8Encoding]::new($false))
```

---

## 3. Erreurs Git/Submodule

### 3.1 Submodule non initialisé

**Symptômes:**
- Dossier `mcps/internal/servers/roo-state-manager` vide
- "fatal: no submodule mapping found"

**Solution:**
```powershell
git submodule update --init --recursive
```

### 3.2 Submodule désynchronisé

**Symptômes:**
- "HEAD detached"
- Modifications non trackées dans le submodule

**Solution:**
```powershell
# Dans le submodule
cd mcps/internal/servers/roo-state-manager
git checkout main
git pull origin main

# Dans le repo principal
cd ../../../..
git add mcps/internal/servers/roo-state-manager
git commit -m "chore: Update submodule"
```

### 3.3 Conflit lors du push

**Symptômes:**
- "rejected - fetch first"
- "Updates were rejected"

**Solution:**
```powershell
git pull --rebase
git push
```

### 3.4 Conflit de merge submodule

**Symptômes:**
- "CONFLICT (submodule)"
- Merge en échec

**Solution:**
```powershell
# Accepter la version remote
git checkout --theirs mcps/internal/servers/roo-state-manager
git add mcps/internal/servers/roo-state-manager
git rebase --continue
```

---

## 4. Erreurs de Synchronisation

### 4.1 Baseline non trouvée

**Symptômes:**
- "BASELINE_NOT_FOUND"
- Comparaison impossible

**Solutions:**
1. Vérifier que le fichier baseline existe dans `.shared-state/baselines/`
2. Créer une nouvelle baseline si nécessaire

### 4.2 Décision non trouvée

**Symptômes:**
- "DECISION_NOT_FOUND"
- Application de décision échoue

**Cause:** La décision a été supprimée ou archivée.

**Solution:** Créer une nouvelle décision via le Baseline Master.

### 4.3 Application de configuration échouée

**Symptômes:**
- "APPLICATION_FAILED"
- Configuration partiellement appliquée

**Solutions:**
1. Vérifier les permissions fichiers
2. Tester en mode `dryRun: true` d'abord
3. Effectuer un rollback si nécessaire

---

## 5. Erreurs de Tests

### 5.1 Tests en échec - ROOSYNC_SHARED_PATH

**Symptômes:**
```
FAIL src/services/__tests__/roosync-config.test.ts
  ● Cannot access shared state path
```

**Cause:** Variable d'environnement non définie pour les tests.

**Solution:** Ces tests nécessitent l'environnement RooSync complet. Ils sont marqués comme "skip" sur les machines sans accès.

### 5.2 Tests en échec - Imports

**Symptômes:**
```
Error: Cannot find module '../../types/errors.js'
```

**Cause:** Chemins d'import incorrects après refactoring.

**Solution:**
- Fichiers dans `src/tools/` → `../types/errors.js`
- Fichiers dans `src/tools/subfolder/` → `../../types/errors.js`

### 5.3 Tests timeout

**Symptômes:**
- "Timeout - Async callback was not invoked within 5000ms"

**Solutions:**
1. Augmenter le timeout dans le test
2. Vérifier les mocks de services externes
3. Vérifier les connexions réseau

---

## 6. Codes d'Erreur Référence

### Classification Script vs Système

| Type | Exemples | Action |
|------|----------|--------|
| **SCRIPT** | `PARSE_FAILED`, `INVALID_ARGUMENT` | Bug dans le code, corriger |
| **SYSTEM** | `FILE_NOT_FOUND`, `PERMISSION_DENIED` | Problème environnement |

### Codes Fréquents

| Code | Service | Cause | Solution |
|------|---------|-------|----------|
| `CONFIG_NOT_FOUND` | ConfigService | Fichier config manquant | Créer le fichier |
| `BASELINE_NOT_FOUND` | BaselineLoader | Baseline manquante | Créer baseline |
| `MESSAGE_NOT_FOUND` | MessageManager | Message supprimé | Vérifier inbox |
| `IDENTITY_CONFLICT` | IdentityManager | Conflit ID machine | Corriger identité |
| `EXECUTION_FAILED` | PowerShellExecutor | Script PS échoué | Vérifier script |
| `TIMEOUT` | Generic | Délai dépassé | Augmenter timeout |

**Référence complète:** [ERROR_CODES_REFERENCE.md](../ERROR_CODES_REFERENCE.md)

---

## Procédure de Debug Générale

### 1. Collecter les Informations

```powershell
# Version Node
node --version

# Statut git
git status

# Logs MCP
cat ~/.claude/logs/mcp-*.log | tail -100
```

### 2. Identifier le Type d'Erreur

- **MCP:** Problème de chargement ou configuration
- **RooSync:** Problème de synchronisation ou messagerie
- **Git:** Problème de versioning ou submodule
- **Tests:** Problème de code ou environnement

### 3. Appliquer la Solution

Suivre les sections correspondantes ci-dessus.

### 4. Valider la Correction

```powershell
# Pour MCP
# Redémarrer VS Code, tester /mcp

# Pour RooSync
roosync_get_status

# Pour Git
git status

# Pour Tests
npm test
```

### 5. Documenter si Nouveau Problème

Ajouter le problème et sa solution à ce document via PR.

---

## Contacts Support

| Problème | Contact | Canal |
|----------|---------|-------|
| MCP/Config | myia-ai-01 | RooSync |
| Technique | myia-po-2024 | RooSync |
| Tests | myia-web-01 | RooSync |
| Urgent | Tous | GitHub Issue + RooSync URGENT |

---

## Historique

| Date | Version | Auteur | Description |
|------|---------|--------|-------------|
| 2026-01-15 | 1.0.0 | Claude Code (myia-web1) | Création initiale |

---

**Document créé dans le cadre de T4.11**
**Référence:** T4.10 - Analyse des besoins de documentation multi-agent
