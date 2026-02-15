# RooSync v2.1 - Résumé Consolidé

**Date de consolidation** : 2026-02-15
**Version résumée** : v2.1 (4 guides, 7406 lignes → ce résumé)
**Status** : ✅ Archivé (remplacé par v2.3)

---

## 📋 Objectif de ce Document

Ce document consolide les **4 guides RooSync v2.1** en un résumé structuré préservant les concepts clés, patterns, et leçons apprises. RooSync v2.1 a été remplacé par **v2.3** (voir [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](../GUIDE-TECHNIQUE-v2.3.md)), mais ce résumé conserve les innovations et patterns introduits dans v2.1.

**Guides sources consolidés :**
1. [`GUIDE-TECHNIQUE-v2.1.md`](GUIDE-TECHNIQUE-v2.1.md) - 1554 lignes - Architecture technique, baseline-driven, RAP
2. [`GUIDE-DEVELOPPEUR-v2.1.md`](GUIDE-DEVELOPPEUR-v2.1.md) - 2748 lignes - Stack technique, services, tests
3. [`GUIDE-OPERATIONNEL-UNIFIE-v2.1.md`](GUIDE-OPERATIONNEL-UNIFIE-v2.1.md) - 2665 lignes - Installation, configuration, opérations
4. [`GUIDE-TECHNIQUE-v2.1-ADDENDUM-2025-12-27.md`](GUIDE-TECHNIQUE-v2.1-ADDENDUM-2025-12-27.md) - 439 lignes - État actuel, plan v2.3

---

## 1. Concepts Clés v2.1

### 1.1 Mission Principale

**RooSync v2.1 = Synchronisation baseline-driven avec validation humaine obligatoire**

Principe fondamental : *Une source de vérité unique, versionnable et distribuée via Git*

**Innovation clé** : Transition d'un système de synchronisation bidirectionnelle (v1) vers un modèle **baseline-first** où la baseline Git devient la source de vérité canonique.

### 1.2 Architecture Baseline-Driven

```
┌─────────────────┐
│  Baseline Git   │  ← Source de vérité unique (Git)
│  (GDrive sync)  │
└────────┬────────┘
         │
    ┌────▼─────┐
    │  Collect │  ← 1. Collecte config locale → ZIP
    └────┬─────┘
         │
    ┌────▼─────┐
    │   Diff   │  ← 2. Compare baseline vs local
    └────┬─────┘
         │
    ┌────▼─────┐
    │ Decision │  ← 3. Génère décisions (approve/reject)
    └────┬─────┘
         │
    ┌────▼─────┐
    │  Apply   │  ← 4. Applique changements approuvés
    └──────────┘
```

**Sources** :
- Architecture : `GUIDE-TECHNIQUE-v2.1.md`, lignes 1-100
- Workflow : `GUIDE-OPERATIONNEL-UNIFIE-v2.1.md`, lignes 500-700

### 1.3 RAP - RooSync Autonomous Protocol

**RAP** = Protocole de synchronisation autonome sans intervention manuelle (vision future)

**3 Piliers RAP** :
1. **Detection automatique** : Scan périodique des changements (baseline vs local)
2. **Decision automatique** : Règles de merge automatiques (baseline wins, local wins, merge intelligent)
3. **Application automatique** : Deployment sans confirmation manuelle

**État v2.1** : Implémentation partielle (detection ✅, decision ⚠️ semi-auto, application ❌ manuelle requise)

**Sources** : `GUIDE-TECHNIQUE-v2.1.md`, section 3 "Protocole RAP"

---

## 2. Architecture Technique

### 2.1 Stack Technologique

| Composant | Technologie | Rôle |
|-----------|-------------|------|
| **Serveur MCP** | TypeScript + Node.js | Cœur RooSync (roo-state-manager) |
| **Scripts Deployment** | PowerShell 5.1/7+ | Exécution locale des déploiements |
| **Baseline Storage** | Google Drive sync | Stockage partagé `.shared-state/` |
| **Messaging** | JSON files (GDrive) | Communication inter-machines |
| **Tests** | Vitest | Suite de tests unitaires |
| **Logger** | Custom TypeScript | Logs rotatifs (local + console) |

**Sources** : `GUIDE-DEVELOPPEUR-v2.1.md`, section 1.1

### 2.2 Services Core (Cycle 7)

**BaselineService** : Gestion baseline Git
- Méthodes : `readBaseline()`, `getBaselineVersion()`, `collectBaseline()`
- Rôle : Interface avec la baseline Git stockée sur GDrive

**ConfigSharingService** : Orchestrateur principal (Cycle 7)
- Méthodes : `collectConfig()`, `publishConfig()`, `compareBaseline()`, `applyConfig()`
- Rôle : Coordonne le workflow collect → diff → decision → apply

**ConfigNormalizationService** : Normalisation multi-OS (Cycle 7)
- **Innovation clé** : Normalisation des chemins Windows ↔ Linux + gestion secrets
- Patterns supportés : `${env:VARIABLE}`, `${HOME}`, `${USERPROFILE}`
- Secrets : Détection et masquage automatique (`***SECRET***`)

**ConfigDiffService** : Moteur de diff granulaire
- Algorithme : Deep diff JSON avec path tracking (ex: `mcpServers.roo-state-manager.args[0]`)
- Output : Liste de décisions avec type (`added`, `modified`, `deleted`)

**InventoryService** : Collecte inventaire machines
- Données collectées : OS, RAM, CPU, disques, MCPs, CLIs, règles Roo/Claude
- Format : JSON structuré (`inventories/{machineId}.json`)

**Sources** :
- Services : `GUIDE-DEVELOPPEUR-v2.1.md`, section 2
- Normalisation : `GUIDE-OPERATIONNEL-UNIFIE-v2.1.md`, section 4.4

### 2.3 Outils MCP RooSync (9 outils v2.1)

**État v2.1** : 9 outils RooSync exportés

| Outil | Catégorie | Description |
|-------|-----------|-------------|
| `roosync_collect_config` | Config | Collecte config locale → ZIP |
| `roosync_publish_config` | Config | Publie config locale → baseline |
| `roosync_apply_config` | Config | Applique baseline → local |
| `roosync_compare_config` | Baseline | Compare baseline vs local |
| `roosync_init` | Init | Initialise infrastructure RooSync |
| `roosync_send_message` | Messaging | Envoie message inter-machines |
| `roosync_read_inbox` | Messaging | Lit boîte de réception |
| `roosync_list_diffs` | Diff | Liste différences détectées |
| `roosync_get_status` | Dashboard | État synchronisation global |

**Évolution v2.3** : Consolidation 9→6 outils (voir `ADDENDUM` lignes 200-300)

**Sources** :
- Inventaire : `ADDENDUM`, section "Inventaire Complet"
- Détails : `GUIDE-TECHNIQUE-v2.1.md`, section 2.4

### 2.4 Structure Baseline Complete v2.1

```
.shared-state/baseline/
├── version.json              ← Version baseline (semver)
├── core/
│   ├── mcp_settings.json     ← Config MCP globale
│   ├── tasks.json            ← Tâches Roo
│   └── settings.json         ← Settings VS Code
├── deployments/
│   ├── deploy-roosync.ps1    ← Script deployment RooSync
│   └── deploy-*.ps1          ← Autres scripts
├── docs/
│   └── *.md                  ← Documentation baseline
└── tests/
    └── validation-*.md       ← Rapports de validation
```

**Sources** : `GUIDE-TECHNIQUE-v2.1.md`, section 2.3

---

## 3. Workflow Opérationnel

### 3.1 Cycle de Synchronisation Standard

**Phase 1 : Collecte**
```powershell
# Collecte la configuration locale
roosync_collect_config
# → Génère .shared-state/configs/{machineId}-{timestamp}.zip
```

**Phase 2 : Comparaison**
```powershell
# Compare baseline vs config collectée
roosync_compare_config
# → Génère .shared-state/decisions/{decision-id}.json
```

**Phase 3 : Décision**
```powershell
# Lister les différences
roosync_list_diffs

# Approuver une décision
roosync_decision(action: "approve", decisionId: "...")
```

**Phase 4 : Application**
```powershell
# Appliquer la décision approuvée
roosync_apply_config(decisionId: "...")
# → Applique les changements sur la machine locale
```

**Sources** : `GUIDE-OPERATIONNEL-UNIFIE-v2.1.md`, section 5.1

### 3.2 Stratégies de Merge (Cycle 7)

**Stratégie Manuelle** (par défaut v2.1)
- Toute différence → décision requise
- Validation humaine obligatoire

**Stratégie Baseline Wins** (expérimentale)
- Baseline écrase toujours le local
- Aucune validation requise (DANGEREUX)

**Stratégie Local Wins** (expérimentale)
- Local écrase toujours la baseline
- Utilisé pour publier une nouvelle baseline

**Sources** : `GUIDE-OPERATIONNEL-UNIFIE-v2.1.md`, lignes 800-900

### 3.3 Système de Messagerie

**Architecture Fichiers**
```
.shared-state/messages/
├── {machineId}/inbox.json         ← Boîte de réception
└── sent/{messageId}.json          ← Messages envoyés
```

**Format Message** :
```json
{
  "id": "msg-timestamp-hash",
  "from": "myia-ai-01",
  "to": "myia-po-2024",
  "subject": "[URGENT] Titre",
  "body": "Contenu markdown",
  "priority": "HIGH|MEDIUM|LOW",
  "tags": ["coordination", "sync"],
  "timestamp": "2025-12-27T10:00:00Z",
  "read": false
}
```

**Outils** :
- `roosync_send_message` : Envoyer
- `roosync_read_inbox` : Lire boîte
- `roosync_reply_message` : Répondre

**Sources** : `GUIDE-TECHNIQUE-v2.1.md`, section 3

---

## 4. Tests et Validation

### 4.1 Stratégie de Test (Cycle 5)

**Règles d'Or Mocking FS** :
1. **TOUJOURS mocker fs** dans les tests unitaires (éviter I/O réel)
2. **Utiliser memfs** pour filesystem en mémoire
3. **Mocker sync_roo_environment_v2.1.ps1** (ne jamais exécuter réellement)

**Exemple Mock** :
```typescript
jest.mock('fs');
jest.mock('path');

const mockFs = {
  readFileSync: jest.fn(),
  writeFileSync: jest.fn(),
  existsSync: jest.fn(() => true)
};
```

**Sources** : `GUIDE-DEVELOPPEUR-v2.1.md`, section 3

### 4.2 Tests Existants v2.1

**5 fichiers de tests** (état v2.1) :
1. `BaselineService.test.ts` - Gestion baseline
2. `ConfigNormalizationService.test.ts` - Normalisation secrets
3. `ConfigDiffService.test.ts` - Diff granulaire
4. `InventoryService.test.ts` - Collecte inventaire
5. `MessageManager.test.ts` - Messagerie

**Couverture** : ~70% des services core (v2.1)

**Sources** : `ADDENDUM`, section "État Actuel des Tests"

### 4.3 Validation Baseline Complete

**3 Niveaux de Validation** :
1. **Structurelle** : Vérifier présence `version.json`, `core/`, `deployments/`
2. **Intégrité** : Vérifier format JSON valide, pas de fichiers corrompus
3. **Fonctionnelle** : Tester `deploy-roosync.ps1` sur machine test

**Sources** : `GUIDE-TECHNIQUE-v2.1.md`, section 4.4

---

## 5. Logger et Monitoring

### 5.1 Architecture Logger

**Custom Logger TypeScript** (pas Winston/Pino) :
- Niveaux : DEBUG, INFO, WARN, ERROR
- Output : Console + fichier `logs/roo-state-manager-{date}.log`
- Rotation : Automatique (cleanup logs >30 jours au démarrage)

**Usage** :
```typescript
import { logger } from './services/logger';

logger.info('Message', { context: 'BaselineService' });
logger.error('Erreur', { error: err.message });
```

**Sources** : `GUIDE-DEVELOPPEUR-v2.1.md`, section 4

### 5.2 Monitoring Déploiement

**Dashboard PowerShell** :
```powershell
# Surveiller logs temps réel
Get-Content logs/*.log -Wait -Tail 50

# Dashboard déploiement
.\scripts\monitor-deployment.ps1
```

**Métriques surveillées** :
- Temps d'exécution deploy
- Erreurs PowerShell
- Diff count (nombre de différences détectées)

**Sources** : `GUIDE-OPERATIONNEL-UNIFIE-v2.1.md`, section 5.3

---

## 6. Leçons Apprises et Patterns

### 6.1 Pattern Baseline-Driven

**Avant (v1.0)** : Synchronisation bidirectionnelle
- Problème : Conflits complexes, pas de source de vérité unique
- Résolution manuelle fréquente

**Après (v2.1)** : Baseline-first
- Solution : Baseline Git = source de vérité
- Workflow : collect → diff → approve → apply
- Avantage : Historique versionné, rollback facile

**Impact** : Réduction 80% des conflits de merge

**Sources** : `GUIDE-TECHNIQUE-v2.1.md`, section 1.1

### 6.2 Pattern Normalisation Multi-OS

**Problème** : Chemins absolus Windows ↔ Linux incompatibles
- `C:\Users\...` vs `/home/...`

**Solution** : Variables d'environnement
- `${HOME}`, `${USERPROFILE}`, `${env:VAR}`
- Remplacement automatique à l'application

**Pattern** :
```json
// Baseline (normalisé)
"path": "${HOME}/.config/roo"

// Windows (appliqué)
"path": "C:\\Users\\Myia\\.config\\roo"

// Linux (appliqué)
"path": "/home/myia/.config/roo"
```

**Sources** : `GUIDE-OPERATIONNEL-UNIFIE-v2.1.md`, section 4.4

### 6.3 Pattern Secrets Management

**Problème** : Secrets (API keys, tokens) dans config
- Risque : Fuite de secrets dans baseline Git

**Solution v2.1** : Détection + masquage automatique
- Patterns détectés : `apiKey`, `token`, `password`, `secret`
- Remplacement : `***SECRET***`
- Avertissement utilisateur

**Limitation** : Pas de vault intégré (v2.1), juste masquage

**Sources** : `GUIDE-DEVELOPPEUR-v2.1.md`, section 2.1

### 6.4 Pattern Decision Workflow

**Innovation** : Système de décisions avec états
- États : `pending` → `approved` → `applied` ou `rejected`
- Traçabilité : Chaque décision a un ID unique + timestamp

**Avantage** : Audit trail complet de toutes les modifications

**Sources** : `GUIDE-OPERATIONNEL-UNIFIE-v2.1.md`, section 5.1

---

## 7. Évolution v2.1 → v2.3

### 7.1 Différences Majeures

**Consolidation d'outils** :
- v2.1 : 9 outils RooSync
- v2.3 : 6 outils (fusion `collect`+`publish`+`apply` → `roosync_config`)

**Nouveaux outils v2.3** :
- `conversation_browser` : Navigation conversations Roo/Claude
- `roosync_heartbeat` : Monitoring machines actives

**Améliorations** :
- Wrapper MCP v4 (pass-through, 39 outils exposés)
- Meilleur support submodules Git
- Escalade CLI (simple → complex)

**Sources** : `ADDENDUM`, section "Plan de Consolidation v2.3"

### 7.2 Ce Qui Reste Valide

**Concepts toujours d'actualité en v2.3** :
- ✅ Architecture baseline-driven
- ✅ Workflow collect → diff → approve → apply
- ✅ Normalisation multi-OS
- ✅ Système de messagerie JSON
- ✅ Logger custom avec rotation
- ✅ Stratégie de tests (mocking FS)

**Ce qui a changé** :
- ❌ Nombre d'outils (9→6)
- ❌ Noms d'outils (préfixes consolidés)
- ❌ Structure wrapper MCP (v4)

---

## 8. Références

### 8.1 Documents Sources (7406 lignes total)

| Document | Lignes | Contenu Principal |
|----------|--------|-------------------|
| `GUIDE-TECHNIQUE-v2.1.md` | 1554 | Architecture, RAP, messagerie |
| `GUIDE-DEVELOPPEUR-v2.1.md` | 2748 | Services, tests, logger |
| `GUIDE-OPERATIONNEL-UNIFIE-v2.1.md` | 2665 | Installation, config, opérations |
| `ADDENDUM-2025-12-27.md` | 439 | État actuel, plan v2.3 |

### 8.2 Documents Actifs v2.3

Pour la documentation actuelle, consulter :
- [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](../GUIDE-TECHNIQUE-v2.3.md) - Guide technique v2.3
- [`CLAUDE.md`](../../../CLAUDE.md) - Configuration projet multi-agent
- [`docs/INDEX.md`](../../INDEX.md) - Table des matières complète

### 8.3 Code Source

- MCP RooSync : `mcps/internal/servers/roo-state-manager/`
- Tests : `mcps/internal/servers/roo-state-manager/tests/`
- Scripts : `mcps/internal/servers/roo-state-manager/scripts/`

---

## 9. Métriques de Consolidation

**Avant** : 4 guides séparés, 7406 lignes
**Après** : 1 résumé consolidé, ~500 lignes
**Ratio de compression** : ~14:1

**Contenu préservé** :
- ✅ Tous les concepts clés
- ✅ Tous les patterns importants
- ✅ Toutes les leçons apprises
- ✅ Traçabilité complète (références aux sources)

**Contenu supprimé** :
- ❌ Duplication entre guides
- ❌ Détails d'implémentation obsolètes
- ❌ Exemples de code redondants

---

**Consolidé par** : Claude Code (myia-po-2024)
**Date** : 2026-02-15
**Issue** : #470 Phase 2 - Consolidation archives

