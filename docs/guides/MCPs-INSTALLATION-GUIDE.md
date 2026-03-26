# 📋 Guide Complet - Installation et Configuration des MCPs

**Date de création** : 2025-10-22
**Dernière mise à jour** : 2025-10-28
**Version** : 2.0.0
**Auteur** : Roo Architect Complex
**Statut** : 🟢 **VALIDÉ AVEC LEÇONS APPRISES**
**Catégorie** : GUIDE

---

## 🚨 AVERTISSEMENT CRITIQUE - MISSION 2025-10-28

### Leçons Apprises de la Mission de Correction d'Urgence
Suite à la mission de correction MCPs du 28 octobre 2025, **des problèmes critiques ont été identifiés** dans le processus d'installation :

1. **COMPILATION OBLIGATOIRE** : Les MCPs TypeScript nécessitent une compilation réelle (`npm run build`)
2. **VALIDATION RÉELLE** : Les placeholders ne sont PAS des fichiers fonctionnels
3. **DÉPENDANCES SYSTÈME** : Vérification obligatoire des prérequis (pytest, etc.)
4. **SÉCURITÉ** : Toujours utiliser des variables d'environnement pour les tokens

### Procédure Corrigée
- Suivre impérativement la **Section 8 - Procédure de Compilation Validée**
- Valider chaque étape avec les scripts de la **Section 9**
- Ne jamais considérer l'installation terminée sans validation réelle

---

## 🎯 Objectif

Ce guide fournit des instructions complètes pour l'installation, la configuration et la validation des 14 serveurs MCP (6 internes, 8 externes) de l'écosystème roo-extensions.

---

## 📊 Vue d'ensemble des MCPs

### Architecture des MCPs (État Réel - 2025-10-28)
```
mcps/
├── internal/                    # 6 MCPs internes (Tier 1-2)
│   ├── servers/
│   │   ├── roo-state-manager/   # ✅ Configuré, ❌ Non compilé
│   │   ├── quickfiles-server/   # ✅ Configuré, ❌ Non compilé
│   │   ├── jinavigator-server/  # ✅ Configuré, ❌ Non compilé
│   │   ├── jupyter-mcp-server/  # ✅ Configuré, ❌ Non compilé
│   │   ├── github-projects-mcp/ # ✅ Configuré, ❌ Non compilé
│   │   └── jupyter-papermill-mcp-server/ # ✅ Configuré, ✅ Python
│   └── INSTALLATION.md          # Guide installation interne
├── external/                    # 8 MCPs externes (Tier 3)
│   ├── searxng/                # ✅ Opérationnel
│   ├── github/                 # ✅ Opérationnel
│   ├── markitdown/             # ❌ Module non installé
│   ├── playwright/             # ❌ Package non trouvé
│   ├── filesystem/             # ✅ Désactivé
│   ├── win-cli/                # ✅ Désactivé
│   ├── git/                    # ✅ Configuré
│   └── docker/                 # ✅ Configuré
└── INSTALLATION.md              # Guide d'installation global
```

### État Actuel des MCPs (28 octobre 2025)
| MCP | Type | Statut Configuration | Statut Fonctionnel | Action Requise |
|-----|-------|-------------------|-------------------|----------------|
| **MCPs Internes** | | | | |
| roo-state-manager | TypeScript | ✅ | ❌ | Compilation |
| quickfiles-server | TypeScript | ✅ | ❌ | Compilation |
| jinavigator-server | TypeScript | ✅ | ❌ | Compilation |
| jupyter-mcp-server | TypeScript | ✅ | ❌ | Compilation |
| github-projects-mcp | TypeScript | ✅ | ❌ | Compilation |
| jupyter-papermill-mcp-server | Python | ✅ | ⚠️ | Validation |
| **MCPs Externes** | | | | |
| searxng | npm global | ✅ | ✅ | Aucune |
| github | npm global | ✅ | ✅ | Aucune |
| markitdown | Python | ✅ | ❌ | Installation module |
| playwright | npm global | ✅ | ❌ | Installation package |
| filesystem | npm global | ✅ | ❌ | Activation |
| win-cli | npm global | ✅ | ❌ | Activation |
| git | npm global | ✅ | ⚠️ | Validation |
| docker | npm global | ✅ | ⚠️ | Validation |

**Taux de réussite global** : **30%** (3/10 MCPs fonctionnels)

### Classification par Priorité (État Réel)

#### 🔴 Tier 1 - Critiques (Priorité Maximale - ÉCHEC COMPLET)
Ces MCPs sont essentiels au fonctionnement de base des agents Roo :

1. **roo-state-manager** - ❌ **NON FONCTIONNEL** (placeholder)
2. **quickfiles-server** - ❌ **NON FONCTIONNEL** (placeholder)
3. **jinavigator-server** - ❌ **NON FONCTIONNEL** (placeholder)
4. **searxng** - ✅ **OPÉRATIONNEL** (seul MCP Tier 1 fonctionnel)

#### 🟠 Tier 2 - Importants (Priorité Haute - ÉCHEC PARTIEL)
MCPs internes additionnels pour fonctionnalités avancées :

5. **jupyter-mcp-server** - ❌ **NON FONCTIONNEL** (placeholder)
6. **github-projects-mcp** - ❌ **NON FONCTIONNEL** (placeholder) - ⚠️ **DÉPRÉCIÉ** (#368) - Remplacé par `gh` CLI
7. **jupyter-papermill-mcp-server** - ⚠️ **PARTIEL** (Python configuré)

#### 🟡 Tier 3 - Externes (Priorité Variable - SUCCÈS PARTIEL)
MCPs externes pour intégrations spécialisées :

8. **github** - ✅ **OPÉRATIONNEL**
9. **markitdown** - ❌ **NON FONCTIONNEL** (module non installé)
10. **playwright** - ❌ **NON FONCTIONNEL** (package non trouvé)
11. **filesystem** - ❌ **DÉSACTIVÉ**
12. **win-cli** - ❌ **DÉSACTIVÉ**
13. **git** - ⚠️ **CONFIGURÉ** (validation requise)
14. **docker** - ⚠️ **CONFIGURÉ** (validation requise)

**Taux de réussite par Tier** :
- **Tier 1** : 25% (1/4)
- **Tier 2** : 0% (0/3)
- **Tier 3** : 33% (2/6)

---

## 🔧 Prérequis d'Installation

### Prérequis Système (VALIDÉS - 2025-10-28)
```powershell
# Vérifier PowerShell 7.2+
$PSVersionTable.PSVersion
# Attendu : 7.2.0+

# Vérifier Node.js 18+ (CRITIQUE pour MCPs TypeScript)
node --version
# Attendu : v20.12.2+

npm --version
# Attendu : 10.5.0+

# Vérifier Python 3.9+ (pour MCPs Python)
python --version
# Attendu : 3.10.0+

pip --version
# Attendu : 25.2+

# Vérifier Rust (NON REQUIS - correction diagnostic)
# rustc --version
# cargo --version
# Note : quickfiles-server utilise TypeScript, PAS Rust
```

### Prérequis Spécifiques (IDENTIFIÉS COMME CRITIQUES)
```powershell
# pytest (REQUIS pour jupyter-mcp-server)
conda activate mcp-jupyter-py310
pip install pytest

# Variables d'environnement (OBLIGATOIRES)
$env:GITHUB_TOKEN = "votre_token_github_personnel_ici"

# Conda (REQUIS pour jupyter-papermill-mcp-server)
conda --version
# Attendu : 24.7.1+
```

### Prérequis Réseau
- **Accès internet** stable pour MCPs externes
- **Proxy configuré** si nécessaire (variables HTTP_PROXY/HTTPS_PROXY)
- **Firewall** autorisant les connexions sortantes
- **DNS** fonctionnel pour résolution noms de domaine

### Prérequis de Sécurité
- **Permissions d'exécution** pour les scripts
- **Accès lecture/écriture** aux répertoires MCPs
- **API keys** pour MCPs externes (configuration .env)
- **Certificats SSL** valides pour connexions HTTPS

---

## 📋 Procédure d'Installation Complète

### Étape 1 : Préparation de l'Environnement

#### 1.1 Validation des Prérequis
```powershell
# Script de validation des prérequis
.\scripts\validation\validate-mcp-prerequisites.ps1

# Résultat attendu : Tous les tests passent ✅
```

#### 1.2 Configuration des Variables d'Environnement
```powershell
# Ajouter au fichier .env
# MCP Configuration
MCP_SERVERS_ROOT="${ROO_EXTENSIONS_PATH}/mcps"
MCP_INTERNAL_PATH="${MCP_SERVERS_ROOT}/internal"
MCP_EXTERNAL_PATH="${MCP_SERVERS_ROOT}/external"
MCP_LOG_LEVEL="info"
MCP_TIMEOUT=300000

# Configuration spécifique aux MCPs
ROO_STATE_MANAGER_DB="${ROO_EXTENSIONS_PATH}/data/conversations.db"
QUICKFILES_MAX_FILES=100
JINAVIGATOR_USER_AGENT="Roo-Agent/1.0"
SEARXNG_ENDPOINT="http://localhost:8080"
```

#### 1.3 Création des Répertoires
```powershell
# Créer la structure des répertoires
New-Item -ItemType Directory -Force -Path "${MCP_SERVERS_ROOT}/internal/servers"
New-Item -ItemType Directory -Force -Path "${MCP_SERVERS_ROOT}/external"
New-Item -ItemType Directory -Force -Path "${ROO_EXTENSIONS_PATH}/data"
New-Item -ItemType Directory -Force -Path "${ROO_EXTENSIONS_PATH}/logs"
```

### Étape 2 : Installation des MCPs Internes

#### ⚠️ AVERTISSEMENT CRITIQUE - COMPILATION OBLIGATOIRE
**NE PAS SAUTER LES ÉTAPES DE COMPILATION** - Les placeholders ne sont PAS fonctionnels !

#### 2.1 roo-state-manager (Tier 1) - PROCÉDURE CORRIGÉE
```powershell
# Navigation vers le répertoire
cd "C:/dev/roo-extensions/mcps/internal/servers/roo-state-manager"

# Installation des dépendances (OBLIGATOIRE)
npm install

# Construction du serveur (OBLIGATOIRE - ne crée PAS de placeholder)
npm run build

# Vérification du fichier compilé (VALIDATION REQUISE)
Test-Path "build/index.js"
# Doit retourner : True

# Configuration de la base de données
npm run migrate

# Test de fonctionnement
npm test
```

#### 2.2 quickfiles-server (Tier 1) - PROCÉDURE CORRIGÉE
```powershell
# Navigation vers le répertoire
cd "C:/dev/roo-extensions/mcps/internal/servers/quickfiles-server"

# Installation des dépendances (OBLIGATOIRE)
npm install

# Construction du serveur (OBLIGATOIRE - TypeScript/Node.js, PAS Rust)
npm run build

# Vérification du fichier compilé (VALIDATION REQUISE)
Test-Path "build/index.js"
# Doit retourner : True

# Test des fonctionnalités
npm test
```

#### 2.3 jinavigator-server (Tier 1) - PROCÉDURE CORRIGÉE
```powershell
# Navigation vers le répertoire
cd "C:/dev/roo-extensions/mcps/internal/servers/jinavigator-server"

# Installation des dépendances (OBLIGATOIRE)
npm install

# Construction du serveur (OBLIGATOIRE)
npm run build

# Vérification du fichier compilé (VALIDATION REQUISE)
Test-Path "dist/index.js"
# Doit retourner : True

# Configuration du navigateur (Puppeteer)
npm run install-browser

# Tests de navigation
npm test
```

#### 2.4 jupyter-mcp-server (Tier 2) - PROCÉDURE CORRIGÉE
```powershell
# Navigation vers le répertoire
cd "C:/dev/roo-extensions/mcps/internal/servers/jupyter-mcp-server"

# Installation des dépendances (OBLIGATOIRE)
npm install

# Installation pytest (CRITIQUE - dépendance manquante identifiée)
conda activate mcp-jupyter-py310
pip install pytest

# Construction du serveur (OBLIGATOIRE)
npm run build

# Vérification du fichier compilé (VALIDATION REQUISE)
Test-Path "dist/index.js"
# Doit retourner : True

# Test de fonctionnement
npm test
```

#### 2.5 github-projects-mcp (Tier 2) - ⚠️ **DÉPRÉCIÉ** - PROCÉDURE CORRIGÉE

> **NOTE #368** : Ce MCP est **DÉPRÉCIÉ** et remplacé par `gh` CLI (GitHub CLI). Utilisez `gh issue`, `gh pr`, et `gh api graphql` à la place.
```powershell
# Navigation vers le répertoire
cd "C:/dev/roo-extensions/mcps/internal/servers/github-projects-mcp"

# Installation des dépendances (OBLIGATOIRE)
npm install

# Construction du serveur (OBLIGATOIRE)
npm run build

# Vérification du fichier compilé (VALIDATION REQUISE)
Test-Path "dist/index.js"
# Doit retourner : True

# Test de fonctionnement
npm test
```

#### 2.6 jupyter-papermill-mcp-server (Tier 2) - PROCÉDURE CORRIGÉE
```powershell
# Navigation vers le répertoire
cd "C:/dev/roo-extensions/mcps/internal/servers/jupyter-papermill-mcp-server"

# Installation des dépendances Python (OBLIGATOIRE)
conda activate mcp-jupyter-py310
pip install -r requirements.txt

# Vérification du fichier de configuration (VALIDATION REQUISE)
Test-Path "pyproject.toml"
# Doit retourner : True

# Test de fonctionnement
python -m pytest
```

**Configuration requise** :
```json
{
  "database": {
    "path": "${ROO_STATE_MANAGER_DB}",
    "backup": true,
    "backup_interval": 3600
  },
  "server": {
    "port": 3001,
    "host": "localhost"
  },
  "logging": {
    "level": "info",
    "file": "${ROO_EXTENSIONS_PATH}/logs/roo-state-manager.log"
  }
}
```

#### 2.2 quickfiles (Tier 1)
```powershell
cd "${MCP_INTERNAL_PATH}/servers/quickfiles"

# Installation dépendances Rust
cargo build --release

# Test des fonctionnalités
cargo test

# Installation binaire
copy target/release/quickfiles.exe "${ROO_EXTENSIONS_PATH}/bin/"
```

**Configuration requise** :
```toml
[server]
port = 3002
host = "localhost"
max_concurrent_requests = 10

[limits]
max_file_size = "100MB"
max_directory_depth = 10
max_files_per_operation = 50

[cache]
enabled = true
max_size = "1GB"
ttl = 3600
```

#### 2.3 jinavigator (Tier 1)
```powershell
cd "${MCP_INTERNAL_PATH}/servers/jinavigator"

# Installation dépendances
npm install
npm run build

# Configuration du navigateur (Puppeteer)
npm run install-browser

# Tests de navigation
npm test
```

**Configuration requise** :
```json
{
  "browser": {
    "headless": true,
    "timeout": 30000,
    "viewport": {
      "width": 1920,
      "height": 1080
    }
  },
  "server": {
    "port": 3003,
    "host": "localhost"
  },
  "caching": {
    "enabled": true,
    "cache_dir": "${ROO_EXTENSIONS_PATH}/cache/jinavigator",
    "ttl": 7200
  }
}
```

#### 2.4 searxng (Tier 1)
```powershell
cd "${MCP_INTERNAL_PATH}/servers/searxng"

# Installation Docker (recommandé)
docker build -t roo-searxng .

# Ou installation manuelle
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt

# Démarrage du serveur
docker run -p 8080:8080 roo-searxng
# ou
python app.py
```

**Configuration requise** :
```yaml
server:
  port: 8080
  bind_address: "127.0.0.1"
  secret_key: "${SEARXNG_SECRET_KEY}"

search:
  safe_search: 0
  autocomplete: "google"
  default_timezone: "Europe/Paris"

engines:
  - name: google
    enabled: true
  - name: duckduckgo
    enabled: true
  - name: wikipedia
    enabled: true
```

#### 2.6 sk-agent (Tier 1) - PROCÉDURE CORRIGÉE

```powershell
# Navigation vers le répertoire
cd "C:/dev/roo-extensions/mcps/internal/servers/sk-agent"

# Création de l'environnement virtuel Python (OBLIGATOIRE)
python -m venv venv

# Installation des dépendances (OBLIGATOIRE - requirements.txt)
.\venv\Scripts\python.exe -m pip install -r requirements.txt

# Vérification de l'installation (VALIDATION REQUISE)
.\venv\Scripts\python.exe -c "import semantic_kernel, mcp; print('OK')"
# Doit retourner : OK

# Test du wrapper batch
.\run-sk-agent.bat
# Doit démarrer sans erreur (attend sur stdin)
```

**Notes importantes :**

- Le venv est **OBLIGATOIRE** - sans lui, semantic_kernel n'est pas trouvé et le MCP timeout
- Le wrapper batch `run-sk-agent.bat` vérifie maintenant les dépendances et échoue gracieusement si elles manquent
- Temps de chargement attendu : ~7 secondes avec venv, timeout sans venv
- Si les dépendances manquent, le wrapper affiche : `ERROR: sk-agent dependencies not installed!`

#### 2.7 Installation MCPs Internes Restants
Procédure similaire pour les MCPs internes restants selon leur technologie (Node.js, Rust, Python, etc.).

### Étape 3 : Installation des MCPs Externes

#### 3.1 MCPs Externes - PROCÉDURE CORRIGÉE

##### 3.1.1 searxng (✅ OPÉRATIONNEL)
```powershell
# Installation via npx (déjà fonctionnel)
npx -y mcp-searxng

# Test de fonctionnement
# Devrait retourner des outils de recherche
```

##### 3.1.2 github (✅ OPÉRATIONNEL)
```powershell
# Installation via npx (déjà fonctionnel)
npx -y @modelcontextprotocol/server-github

# Configuration du token (OBLIGATOIRE)
$env:GITHUB_TOKEN = "votre_token_github_personnel_ici"

# Test de fonctionnement
# Devrait retourner les outils GitHub
```

##### 3.1.3 markitdown (❌ CORRECTION REQUISE)
```powershell
# Installation du module manquant (CRITIQUE)
C:\Users\jsboi\AppData\Local\Programs\Python\Python310\python.exe -m pip install markitdown-mcp

# Test de fonctionnement
python -m markitdown_mcp --help
# Devrait afficher l'aide du MCP
```

##### 3.1.4 playwright (❌ CORRECTION REQUISE)
```powershell
# Installation du package (CRITIQUE)
npm install -g @playwright/mcp

# Test de fonctionnement
npx @playwright/mcp --help
# Devrait afficher l'aide du MCP
```

##### 3.1.5 filesystem (✅ DÉSACTIVÉ - Activation optionnelle)
```powershell
# Installation
npm install -g @modelcontextprotocol/server-filesystem

# Activation dans mcp_settings.json (si nécessaire)
# "filesystem": {
#   "command": "npx",
#   "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/directory"],
#   "env": {}
# }
```

##### 3.1.6 win-cli (✅ DÉSACTIVÉ - Activation optionnelle)
```powershell
# Installation
npm install -g @modelcontextprotocol/server-win-cli

# Activation dans mcp_settings.json (si nécessaire)
# "win-cli": {
#   "command": "npx",
#   "args": ["-y", "@modelcontextprotocol/server-win-cli"],
#   "env": {}
# }
```

#### 3.2 Configuration API Keys (SÉCURITÉ RENFORCÉE)
```powershell
# Variables d'environnement (MÉTHODE SÉCURISÉE)
$env:GITHUB_TOKEN = "votre_token_github_personnel_ici"
$env:OPENAI_API_KEY = "votre_cle_openai_si_requise"
$env:ANTHROPIC_API_KEY = "votre_cle_anthropic_si_requise"

# JAMAIS de tokens en clair dans les fichiers de configuration
# TOUJOURS utiliser ${env:NOM_VARIABLE} dans mcp_settings.json
```

### Étape 4 : Validation de l'Installation (CRITIQUE)

#### 4.1 Tests de Connectivité - PROCÉDURE VALIDÉE
```powershell
# Script de validation complet (UTILISER OBLIGATOIREMENT)
cd "C:/dev/roo-extensions/sddd-tracking/scripts-transient"
.\check-all-mcps-compilation-2025-10-23.ps1

# Test individuel
.\check-mcps-compilation-2025-10-23.ps1 -McpName "roo-state-manager"
```

#### 4.2 Tests Fonctionnels - VALIDATION RÉELLE
```powershell
# Test de compilation réelle (NON des placeholders)
cd "C:/dev/roo-extensions/mcps/internal/servers/roo-state-manager"
Test-Path "build/index.js"  # Doit retourner True
Get-Content "build/index.js" | Select-Object -First 5  # Ne doit PAS être un placeholder

cd "C:/dev/roo-extensions/mcps/internal/servers/quickfiles-server"
Test-Path "build/index.js"  # Doit retourner True
Get-Content "build/index.js" | Select-Object -First 5  # Ne doit PAS être un placeholder

# Validation pour tous les MCPs internes
$mcps = @("quickfiles-server", "jinavigator-server", "jupyter-mcp-server", "github-projects-mcp", "roo-state-manager")
foreach ($mcp in $mcps) {
    $buildPath = "C:/dev/roo-extensions/mcps/internal/servers/$mcp/build/index.js"
    $distPath = "C:/dev/roo-extensions/mcps/internal/servers/$mcp/dist/index.js"
    
    if (Test-Path $buildPath) {
        $content = Get-Content $buildPath | Select-Object -First 3
        if ($content -match "placeholder") {
            Write-Host "❌ $mcp : PLACEHOLDER DÉTECTÉ - COMPILATION REQUISE" -ForegroundColor Red
        } else {
            Write-Host "✅ $mcp : COMPILATION RÉELLE VALIDÉE" -ForegroundColor Green
        }
    } elseif (Test-Path $distPath) {
        $content = Get-Content $distPath | Select-Object -First 3
        if ($content -match "placeholder") {
            Write-Host "❌ $mcp : PLACEHOLDER DÉTECTÉ - COMPILATION REQUISE" -ForegroundColor Red
        } else {
            Write-Host "✅ $mcp : COMPILATION RÉELLE VALIDÉE" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ $mcp : FICHIER COMPILÉ INTROUVABLE" -ForegroundColor Red
    }
}
```

#### 4.3 Tests de Charge (après compilation réussie)
```powershell
# Test de charge simultanée
.\scripts\testing\stress-test-mcps.ps1 -Concurrency 10 -Duration 300
```

---

## ⚠️ Dépannage et Problèmes Courants

### Problème 1 : Échec de Démarrage MCP
**Symptôme** : Le MCP ne démarre pas ou se termine immédiatement
**Causes possibles** :
- Port déjà utilisé
- Dépendances manquantes
- Permissions insuffisantes
- Configuration incorrecte

**Solutions** :
```powershell
# Vérifier les ports utilisés
netstat -an | findstr ":300"

# Vérifier les logs
Get-Content "${ROO_EXTENSIONS_PATH}/logs/[mcp-name].log" -Tail 50

# Redémarrer avec debug
$env:DEBUG="*"
npm start
```

### Problème 2 : Timeout de Connexion
**Symptôme** : Les agents ne peuvent pas se connecter aux MCPs
**Causes possibles** :
- Firewall bloquant les connexions
- MCP non démarré
- Configuration réseau incorrecte

**Solutions** :
```powershell
# Vérifier si le MCP écoute
Test-NetConnection -ComputerName localhost -Port 3001

# Vérifier le firewall
Get-NetFirewallRule -DisplayName "*Roo*"

# Tester avec curl
curl http://localhost:3001/health
```

### Problème 3 : Performance Dégradée
**Symptôme** : Réponses lentes ou timeouts
**Causes possibles** :
- Ressources système insuffisantes
- Configuration sous-optimale
- Charge excessive

**Solutions** :
```powershell
# Monitorer les ressources
Get-Process | Where-Object {$_.ProcessName -like "*mcp*"}

# Optimiser la configuration
# Augmenter les timeouts, réduire la concurrence, etc.
```

---

## 📈 Monitoring et Maintenance

### Scripts de Monitoring
```powershell
# Surveillance continue
.\scripts\monitoring\monitor-mcps.ps1

# Rapport d'état quotidien
.\scripts\monitoring\daily-mcp-report.ps1

# Alertes automatiques
.\scripts\monitoring\mcp-alerts.ps1
```

### Maintenance Planifiée
```powershell
# Nettoyage des logs
.\scripts\maintenance\cleanup-logs.ps1 -Days 7

# Mise à jour des dépendances
.\scripts\maintenance\update-mcp-dependencies.ps1

# Sauvegarde des configurations
.\scripts\maintenance\backup-mcp-config.ps1
```

---

## 📊 Métriques et KPIs

### Métriques de Performance
- **Temps de réponse moyen** : < 500ms
- **Taux de réussite** : > 99%
- **Disponibilité** : > 99.5%
- **Utilisation ressources** : < 80% CPU, < 4GB RAM

### Métriques d'Utilisation
- **Requêtes/jour** par MCP
- **Pic de charge** simultané
- **Erreurs par type**
- **Temps de récupération**

---

## 🚀 Prochaines Étapes

### Après Installation
1. **Configurer le monitoring** automatique
2. **Documenter les spécificités** de votre environnement
3. **Créer les scripts de backup** personnalisés
4. **Planifier les mises à jour** régulières

### Optimisations Futures
1. **Configuration avancée** selon usage
2. **Intégration avec système monitoring** existant
3. **Automatisation complète** du déploiement
4. **Scaling horizontal** si nécessaire

---

## 📞 Support et Ressources

### Documentation Technique
- [Architecture MCPs détaillée](../mcps/README.md)
- [Configuration avancée](../roo-config/specifications/mcp-configuration.md)
- [Scripts de maintenance](../scripts/maintenance/)
- [Protocole SDDD](../roo-config/specifications/sddd-protocol-4-niveaux.md)

### Support Technique
- **Roo Debug Complex** : Problèmes techniques et dépannage
- **Roo Code Complex** : Installation et configuration
- **Roo Architect Complex** : Architecture et optimisation

---

**Dernière mise à jour** : 2025-10-22  
**Prochaine révision** : Selon évolution des MCPs  
**Validé par** : Roo Architect Complex

---

## 📋 HISTORIQUE DES VERSIONS

### v2.0.0 - 2025-10-28 (MISE À JOUR CRITIQUE)
- **Ajout** : Leçons apprises de la mission de correction d'urgence
- **Correction** : Procédures de compilation validées
- **Ajout** : Scripts de validation anti-placeholder
- **Correction** : Dépendances manquantes identifiées (pytest, markitdown-mcp, @playwright/mcp)
- **Mise à jour** : État réel des MCPs (30% de succès global)

### v1.0.0 - 2025-10-22 (Version initiale)
- **Création** : Guide d'installation complet
- **Documentation** : Procédures pour 14 MCPs
- **Architecture** : Classification par priorité

---

**Dernière mise à jour** : 2025-10-28  
**Prochaine révision** : Après compilation complète des MCPs  
**Validé par** : Roo Architect Complex  
**Statut critique** : 🚨 **COMPILATION REQUISE - GUIDE MIS À JOUR**