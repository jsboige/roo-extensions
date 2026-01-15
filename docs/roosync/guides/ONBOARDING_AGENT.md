# Guide d'Onboarding - Nouvel Agent RooSync

**Version:** 1.0.0
**Date:** 2026-01-15
**Auteur:** Claude Code (myia-web1)

---

## Vue d'Ensemble

Ce guide vous accompagne pas-à-pas pour configurer un nouvel agent (Claude Code ou Roo) sur une machine du système RooSync multi-agent.

**Temps estimé:** 15-30 minutes

---

## Prérequis

### Matériel

- Machine Windows (10/11/Server)
- Accès réseau au dossier partagé RooSync
- VS Code installé

### Logiciels

| Logiciel | Version Minimum | Vérification |
|----------|-----------------|--------------|
| Node.js | v20+ | `node --version` |
| npm | v10+ | `npm --version` |
| Git | v2.40+ | `git --version` |
| PowerShell | 7+ | `$PSVersionTable.PSVersion` |

### Accès

- Token GitHub avec droits `repo`, `project`
- Accès au dossier partagé: `G:/Mon Drive/Synchronisation/RooSync/`

---

## Étape 1: Cloner le Dépôt

```powershell
# Se placer dans le répertoire de développement
cd c:\dev

# Cloner avec les submodules
git clone --recurse-submodules https://github.com/jsboige/roo-extensions.git

# Entrer dans le dépôt
cd roo-extensions
```

**Vérification:**
```powershell
# Doit afficher la branche main
git branch
```

---

## Étape 2: Installer les Dépendances

### 2.1 Dépendances Principales

```powershell
# Dans le répertoire racine
npm install
```

### 2.2 Dépendances du Submodule RooSync

```powershell
# Aller dans le submodule
cd mcps/internal/servers/roo-state-manager

# Installer les dépendances
npm install

# Compiler
npm run build

# Revenir à la racine
cd ../../../..
```

**Vérification:**
```powershell
# Doit afficher les fichiers compilés
ls mcps/internal/servers/roo-state-manager/dist
```

---

## Étape 3: Configurer les MCPs

### 3.1 Exécuter le Script d'Initialisation

```powershell
# Depuis la racine du dépôt
.\.claude\scripts\init-claude-code.ps1
```

Ce script:
- Détecte le nom de la machine
- Crée `.mcp.json` dans le profil utilisateur
- Configure les MCPs github-projects et roo-state-manager

### 3.2 Créer le Fichier .env

```powershell
# Créer le fichier d'environnement
cd mcps/internal/servers/roo-state-manager
Copy-Item .env.example .env

# Éditer pour ajouter votre token GitHub
notepad .env
```

Contenu du `.env`:
```
GITHUB_TOKEN=ghp_votre_token_ici
ROOSYNC_SHARED_PATH=G:/Mon Drive/Synchronisation/RooSync/.shared-state
```

### 3.3 Redémarrer VS Code

**Important:** Fermez complètement VS Code et rouvrez-le pour charger les MCPs.

---

## Étape 4: Valider la Configuration

### 4.1 Tester les MCPs

Dans Claude Code, exécutez:

```
/mcp
```

Vous devez voir:
- `github-projects-mcp` avec 57+ outils
- `roo-state-manager` avec 6-11 outils RooSync

### 4.2 Tester la Messagerie RooSync

```
roosync_read_inbox
```

Doit afficher votre boîte de réception (même vide).

### 4.3 Tester GitHub Projects

```
list_projects owner: jsboige
```

Doit lister les projets GitHub.

---

## Étape 5: S'identifier dans le Système

### 5.1 Vérifier l'Identité Machine

```powershell
# Affiche le nom de la machine
$env:COMPUTERNAME
```

### 5.2 Envoyer un Message de Présentation

Envoyez un message aux autres agents:

```
roosync_send_message {
  "to": "myia-ai-01",
  "subject": "Nouvel agent connecté",
  "body": "Agent [VOTRE_MACHINE] opérationnel et prêt à recevoir des tâches.",
  "priority": "MEDIUM",
  "tags": ["onboarding", "nouveau"]
}
```

### 5.3 Créer une Issue GitHub de Validation

Format:
```
Titre: [CLAUDE-{MACHINE}] Bootstrap Complete
Labels: claude-code, onboarding
Body:
- Machine: {MACHINE}
- Date: {DATE}
- MCPs: github-projects ✅, roo-state-manager ✅
- Tests: Messagerie ✅, Projects ✅
```

---

## Étape 6: Lire la Documentation

### Documents Essentiels

| Document | Contenu | Priorité |
|----------|---------|----------|
| [CLAUDE.md](../../../CLAUDE.md) | Guide principal agents | **CRITIQUE** |
| [GESTION_MULTI_AGENT.md](../GESTION_MULTI_AGENT.md) | Rôles et protocoles | HIGH |
| [ERROR_CODES_REFERENCE.md](../ERROR_CODES_REFERENCE.md) | Codes d'erreur | MEDIUM |

### Fichiers de Coordination

| Fichier | Usage |
|---------|-------|
| `.claude/local/INTERCOM-{MACHINE}.md` | Communication locale Claude↔Roo |
| `docs/suivi/RooSync/SUIVI_ACTIF.md` | Suivi quotidien |

---

## Checklist de Validation

Cochez chaque élément une fois validé:

### Configuration

- [ ] Dépôt cloné avec submodules
- [ ] Node.js v20+ installé
- [ ] npm dependencies installées
- [ ] Submodule roo-state-manager compilé
- [ ] Script init-claude-code.ps1 exécuté
- [ ] Fichier .env créé avec GITHUB_TOKEN
- [ ] VS Code redémarré

### Tests

- [ ] `/mcp` affiche les MCPs
- [ ] `roosync_read_inbox` fonctionne
- [ ] `list_projects` fonctionne

### Communication

- [ ] Message de présentation envoyé
- [ ] Issue GitHub de validation créée
- [ ] CLAUDE.md lu complètement

---

## Troubleshooting

### Problème: MCP ne se charge pas

**Symptômes:** `/mcp` n'affiche pas les outils

**Solutions:**
1. Vérifier que `.mcp.json` existe dans `~/.mcp.json`
2. Vérifier les chemins dans `.mcp.json`
3. Redémarrer VS Code complètement
4. Vérifier les logs: `~/.claude/logs/`

### Problème: Erreur GITHUB_TOKEN

**Symptômes:** "Bad credentials" ou "401 Unauthorized"

**Solutions:**
1. Vérifier que le token est valide sur GitHub
2. Vérifier les permissions du token (`repo`, `project`)
3. Vérifier le fichier `.env`

### Problème: ROOSYNC_SHARED_PATH inaccessible

**Symptômes:** "Cannot find path" ou "Access denied"

**Solutions:**
1. Vérifier que Google Drive est synchronisé
2. Vérifier le chemin dans `.env`
3. Tester l'accès: `ls "G:/Mon Drive/Synchronisation/RooSync/"`

### Problème: Submodule non compilé

**Symptômes:** "Cannot find module" ou erreurs TypeScript

**Solutions:**
```powershell
cd mcps/internal/servers/roo-state-manager
npm install
npm run build
```

---

## Rôles des Machines

| Machine | Rôle | Responsabilités |
|---------|------|-----------------|
| **myia-ai-01** | Baseline Master | Coordination, baseline, décisions |
| **myia-po-2024** | Coordinateur Tech | Comparaisons, analyse technique |
| **myia-po-2023** | Agent | Tâches assignées, synchronisation |
| **myia-po-2026** | Agent | Tâches assignées, synchronisation |
| **myia-web-01** | Testeur | Tests, validation, documentation |

---

## Contacts et Support

### En cas de problème

1. **Consulter** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. **Envoyer** un message RooSync à myia-ai-01
3. **Créer** une issue GitHub avec label `help-wanted`

### Canaux de communication

- **RooSync:** `roosync_send_message`
- **INTERCOM:** `.claude/local/INTERCOM-{MACHINE}.md`
- **GitHub Issues:** https://github.com/jsboige/roo-extensions/issues

---

## Historique

| Date | Version | Auteur | Description |
|------|---------|--------|-------------|
| 2026-01-15 | 1.0.0 | Claude Code (myia-web1) | Création initiale |

---

**Document créé dans le cadre de T4.11**
**Référence:** T4.10 - Analyse des besoins de documentation multi-agent
