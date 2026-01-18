# Multi-Machine Deployment Guide

**Version:** 1.0
**Date:** 2026-01-05
**Système:** RooSync v2.3 Multi-Agent Coordination

---

## 🎯 Objectif

Déployer la configuration MCP Claude Code sur les 5 machines du système RooSync pour permettre la coordination multi-agent via GitHub Projects.

---

## 🖥️ Inventaire des machines

| Machine | Rôle | Status MCP | Status Agent |
|---------|------|------------|--------------|
| **myia-ai-01** | Baseline Master / Coordinator | ⏳ En test | ✅ Actif |
| **myia-po-2023** | Agent (flexible) | ❌ À déployer | ⏸️ En attente |
| **myia-po-2024** | Agent (flexible) | ❌ À déployer | ⏸️ En attente |
| **myia-po-2026** | Agent (flexible) | ❌ À déployer | ⏸️ En attente |
| **myia-web1** | Agent (flexible) | ❌ À déployer | ⏸️ En attente |

---

## 📋 Prérequis

### Avant de déployer sur une machine

**✅ myia-ai-01 DOIT être validé en premier :**
- MCP fonctionnel
- Outils GitHub Projects accessibles
- Création d'issue de test réussie

**⚠️ NE PAS démarrer les autres agents avant validation myia-ai-01**

---

## 🚀 Procédure de déploiement

### Étape 1: Pull des derniers changements

```bash
# Sur chaque machine
cd d:\roo-extensions
git pull origin main
```

### Étape 2: Vérifier la configuration

```powershell
# Vérifier que le fichier MCP existe
Test-Path "d:\roo-extensions\.claude\.mcp.json"
# Doit retourner: True

# Vérifier que le contenu est correct
Get-Content "d:\roo-extensions\.claude\.mcp.json"
# Doit contenir la configuration github-projects-mcp
```

### Étape 3: Vérifier le serveur MCP

```powershell
# Vérifier que le serveur est build
Test-Path "d:\roo-extensions\mcps\internal\servers\github-projects-mcp\dist\index.js"
# Doit retourner: True

# Si False, builder le serveur:
cd d:\roo-extensions\mcps\internal\servers\github-projects-mcp
npm install
npm run build
```

### Étape 4: Identifier la machine

```powershell
# Vérifier le nom de la machine
$env:COMPUTERNAME
# Ou
hostname
```

### Étape 5: Redémarrer VS Code

Fermer complètement VS Code et le rouvrir pour que la configuration MCP soit chargée.

### Étape 6: Tester le MCP

Dans une nouvelle conversation Claude Code :

```
/mcp
```

Ou demander :

```
Peux-tu lister les projets GitHub disponibles ?
```

### Étape 7: Créer issue de validation

Créer une issue GitHub avec le titre :

```
[CLAUDE-MACHINE] Bootstrap Complete - NOM_MACHINE
```

**Contenu de l'issue :**

```markdown
## Machine Info

- **Nom:** [myia-po-2023|myia-po-2024|myia-po-2026|myia-web1]
- **Date:** DATE
- **Status:** ✅|❌

## MCP Verification

- [x] Git pull réussi
- [x] Fichier .mcp.json présent
- [x] Serveur MCP buildé
- [x] VS Code redémarré
- [ ] MCP fonctionnel (test avec /mcp)
- [ ] Outils GitHub Projects accessibles

## Test Results

<!-- Ajouter résultats des tests MCP ici -->

## Issues rencontrées

<!-- Documenter任何 problèmes -->
```

---

## 📊 Suivi du déploiement

### Tableau de progression

**À mettre à jour dans [`.claude/MCP_BOOTSTRAP_REPORT.md`](.claude/MCP_BOOTSTRAP_REPORT.md)**

| Machine | Git Pull | .mcp.json | Build MCP | VS Code Restart | MCP Test | GitHub Issue |
|---------|----------|-----------|-----------|----------------|----------|--------------|
| myia-ai-01 | ✅ | ✅ | ✅ | ✅ | ⏳ | #TODO |
| myia-po-2023 | ⏸️ | ⏸️ | ⏸️ | ⏸️ | ⏸️ | - |
| myia-po-2024 | ⏸️ | ⏸️ | ⏸️ | ⏸️ | ⏸️ | - |
| myia-po-2026 | ⏸️ | ⏸️ | ⏸️ | ⏸️ | ⏸️ | - |
| myia-web1 | ⏸️ | ⏸️ | ⏸️ | ⏸️ | ⏸️ | - |

---

## 🔧 Dépannage

### Problème: MCP ne démarre pas

**Symptôme:** Erreur dans VS Code Output > Claude Code

**Solutions:**

1. **Vérifier le chemin du serveur:**
   ```powershell
   Test-Path "d:\roo-extensions\mcps\internal\servers\github-projects-mcp\dist\index.js"
   ```

2. **Rebuilder le serveur:**
   ```powershell
   cd d:\roo-extensions\mcps\internal\servers\github-projects-mcp
   npm install
   npm run build
   ```

3. **Vérifier le format JSON:**
   ```powershell
   Get-Content "d:\roo-extensions\.claude\.mcp.json" | ConvertFrom-Json
   ```

### Problème: Tokens GitHub non reconnus

**Symptôme:** Erreur 401 Unauthorized depuis GitHub API

**Solutions:**

1. **Vérifier que le .env existe:**
   ```powershell
   Test-Path "d:\roo-extensions\mcps\internal\servers\github-projects-mcp\.env"
   ```

2. **Vérifier le contenu du .env** (sans révéler les tokens):
   ```powershell
   Get-Content "d:\roo-extensions\mcps\internal\servers\github-projects-mcp\.env" | Select-String "GITHUB_"
   ```

3. **Le cwd doit pointer vers le répertoire du serveur:**
   Vérifier dans `.mcp.json` que `"cwd"` est correctement configuré.

### Problème: Outils MCP non disponibles

**Symptôme:** La commande `/mcp` ne montre pas github-projects-mcp

**Solutions:**

1. **Vérifier que VS Code a bien redémarré** (fermer complètement, pas juste reload)

2. **Vérifier les logs VS Code:**
   - Ouvrir View > Output
   - Sélectionner "Claude Code" dans le dropdown
   - Chercher les erreurs liées à "MCP" ou "github-projects"

3. **Recréer la configuration:**
   ```bash
   # Supprimer et re-pull
   rm d:\roo-extensions\.claude\.mcp.json
   git pull origin main
   ```

---

## 📚 Documentation de référence

| Document | Description | Lien |
|----------|-------------|------|
| **Bootstrap Report** | Status myia-ai-01 | [`.claude/MCP_BOOTSTRAP_REPORT.md`](.claude/MCP_BOOTSTRAP_REPORT.md) |
| **Setup Guide** | Instructions détaillées | [`.claude/MCP_SETUP.md`](.claude/MCP_SETUP.md) |
| **MCP Analysis** | Capacités et portabilité | [`.claude/MCP_ANALYSIS.md`](.claude/MCP_ANALYSIS.md) |
| **Documentation Map** | Index complet | [`.claude/INDEX.md`](.claude/INDEX.md) |
| **Agent Guide** | Guide pour agents Claude Code | [`.claude/CLAUDE_CODE_GUIDE.md`](.claude/CLAUDE_CODE_GUIDE.md) |
| **Workspace Context** | Contexte auto-chargé | [`CLAUDE.md`](CLAUDE.md) |

---

## ✅ Critères de succès

Une machine est considérée "déployée avec succès" quand :

- [ ] Git pull réussi sans conflits
- [ ] Fichier `.mcp.json` présent et valide
- [ ] Serveur MCP buildé (dist/index.js présent)
- [ ] VS Code redémarré
- [ ] Commande `/mcp` montre github-projects-mcp
- [ ] Peut lister les projets GitHub
- [ ] Peut créer une issue GitHub
- [ ] Issue de validation créée sur GitHub

---

## 🤝 Coordination multi-machine

### Une fois toutes les machines déployées

**1. Créer un Project GitHub:**
   - Nom: "RooSync Multi-Agent Coordination"
   - Colonnes: Backlog, In Progress, Done, Blocked
   - Tags: claude-code, documentation, technical, coordination

**2. Distribuer les tâches:**
   - Chaque agent choisit ses tâches
   - Self-assignement via issues GitHub
   - Communication via commentaires

**3. Rapports quotidiens:**
   - Chaque agent poste: `[CLAUDE-MACHINE] Daily Report - DATE`
   - Status des tâches en cours
   - Blockers rencontrés
   - Besoin d'aide

**4. Équilibrage de charge:**
   - myia-ai-01 coordonne et rééquilibre si besoin
   - Les agents demandent de l'aide quand surchargés
   - Personne n'est "assigné" rigidement à des catégories de tâches

---

## 📞 Support

**Pour toute question ou problème:**

1. **Vérifier la documentation** dans [`.claude/INDEX.md`](.claude/INDEX.md)
2. **Créer une issue GitHub** avec tags `claude-code` et `help-wanted`
3. **Commenter dans l'issue de la machine** pour demander de l'aide

**Ne pas hésiter à demander de l'aide** - le système est conçu pour la collaboration !

---

**Version:** 1.0
**Dernière mise à jour:** 2026-01-05
**Mainteneur:** Claude Code agent sur myia-ai-01
