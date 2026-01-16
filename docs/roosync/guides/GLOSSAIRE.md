# RooSync Glossaire

**Version:** 1.0.0
**Date:** 2026-01-16
**Auteur:** Claude Code (myia-web1)

---

## Table des Matières

1. [Termes RooSync](#1-termes-roosync)
2. [Termes MCP](#2-termes-mcp)
3. [Termes Git/Submodule](#3-termes-gitsubmodule)
4. [Termes Multi-Agent](#4-termes-multi-agent)
5. [Codes et Identifiants](#5-codes-et-identifiants)
6. [Acronymes](#6-acronymes)

---

## 1. Termes RooSync

### Baseline
Configuration de référence utilisée pour comparer et synchroniser les machines. Contient les paramètres Roo, MCPs, et settings considérés comme "standard".

**Types:**
- **Baseline Non-Nominative (v3.0):** Baseline unique partagée, indépendante des machines. Architecture recommandée depuis T3.9.
- **Baseline Nominative (v2.1):** Baseline par machine. Conservée pour backward-compat uniquement.

### Baseline Master
Machine responsable de la gestion des baselines et des décisions de synchronisation. Actuellement: **myia-ai-01**.

**Responsabilités:**
- Créer et valider les baselines
- Approuver les décisions de synchronisation
- Coordonner les mises à jour globales

### Checkpoint (CP)
Point de validation formel dans la roadmap. Marque la complétion d'un ensemble de tâches.

**Format:** `CP{phase}.{numéro}` (ex: CP4.4)

### Décision
Enregistrement formel d'une action de synchronisation validée par le Baseline Master.

**Contenu:**
- Action à effectuer
- Machines concernées
- Justification
- Statut d'approbation

### Diff (Différence)
Écart détecté entre la configuration d'une machine et la baseline de référence.

**Types:**
- **CONFIG:** Différence de configuration Roo
- **FILES:** Fichiers manquants ou modifiés
- **SETTINGS:** Paramètres différents

### Inventaire
Collecte complète de la configuration d'une machine via `Get-MachineInventory.ps1`.

**Contenu:**
- Hardware (CPU, RAM, disques)
- Software (Node, PowerShell, etc.)
- Configuration Roo et MCPs
- Métadonnées système

### Machine ID
Identifiant unique d'une machine dans le système RooSync.

**Format:** Hostname en minuscules (ex: `myia-ai-01`, `myia-web1`)

### Message RooSync
Communication asynchrone entre machines via le système de messagerie.

**Propriétés:**
- `to`: Destinataire
- `subject`: Sujet
- `body`: Contenu (Markdown supporté)
- `priority`: LOW, MEDIUM, HIGH, URGENT
- `tags`: Catégorisation

### Shared State
Dossier partagé contenant l'état synchronisé du système.

**Chemin:** `G:/Mon Drive/Synchronisation/RooSync/.shared-state/`

**Structure:**
```
.shared-state/
├── machines/       # Fichiers de présence
├── baselines/      # Baselines de référence
├── messages/       # Inbox/Sent par machine
└── decisions/      # Décisions approuvées
```

### Synchronisation
Processus d'alignement de la configuration d'une machine avec la baseline.

**Workflow:**
1. Compare (détection des diffs)
2. Validate (approbation)
3. Apply (application des changements)

---

## 2. Termes MCP

### MCP (Model Context Protocol)
Protocole permettant aux modèles d'IA d'interagir avec des outils externes.

### github-projects-mcp
Serveur MCP pour interagir avec GitHub Projects V2.

**Outils principaux:**
- `list_projects` - Lister les projets
- `get_project_items` - Obtenir les items
- `update_project_item_field` - Mettre à jour un champ

### roo-state-manager
Serveur MCP principal de RooSync.

**Outils RooSync:**
- `roosync_get_status` - État du système
- `roosync_compare_config` - Comparer configurations
- `roosync_send_message` - Envoyer message
- `roosync_read_inbox` - Lire boîte de réception

### Wrapper MCP
Script intermédiaire (`mcp-wrapper.cjs`) qui filtre les outils exposés par le MCP pour éviter les surcharges.

---

## 3. Termes Git/Submodule

### Submodule
Dépôt Git imbriqué dans un autre dépôt. Le MCP roo-state-manager est un submodule.

**Chemin:** `mcps/internal/servers/roo-state-manager`

### Workflow Submodule
Procédure pour committer dans un submodule:

```bash
# 1. Dans le submodule
cd mcps/internal/servers/roo-state-manager
git add . && git commit -m "message" && git push

# 2. Dans le repo principal
cd /c/dev/roo-extensions
git add mcps/internal/servers/roo-state-manager
git commit -m "chore: Update submodule" && git push
```

### Detached HEAD
État Git où HEAD pointe sur un commit spécifique plutôt qu'une branche. Fréquent dans les submodules.

---

## 4. Termes Multi-Agent

### Agent
Instance Claude Code ou Roo Code travaillant sur une machine.

**Types:**
- **Claude Code:** Coordination, documentation, reporting
- **Roo Code:** Tâches techniques (scripts, tests, build)

### Coordination Bicéphale
Architecture où Claude Code et Roo Code collaborent sur la même machine avec des responsabilités distinctes.

### INTERCOM
Fichier de communication locale entre Claude Code et Roo Code sur une même machine.

**Chemin:** `.claude/local/INTERCOM-{MACHINE}.md`

**Format message:**
```markdown
## [DATE] agent-source → agent-dest [TYPE]
Contenu du message
```

### Priorité Message

| Niveau | Délai Réponse | Usage |
|--------|---------------|-------|
| LOW | 24h | Information non urgente |
| MEDIUM | 8h | Coordination normale |
| HIGH | 2h | Important |
| URGENT | 30min | Critique |

### Thread
Fil de conversation RooSync regroupant les messages liés.

---

## 5. Codes et Identifiants

### Codes d'Erreur

**Format:** `{CATEGORY}_{ACTION}` (ex: `CONFIG_NOT_FOUND`)

**Catégories principales:**
- `CONFIG_*` - Erreurs de configuration
- `BASELINE_*` - Erreurs de baseline
- `MESSAGE_*` - Erreurs de messagerie
- `SYNC_*` - Erreurs de synchronisation

**Classification:**
- **SCRIPT:** Bug dans le code (à corriger)
- **SYSTEM:** Problème environnement (configuration)

### IDs GitHub Project

| Élément | ID |
|---------|-----|
| Projet #67 | `PVT_kwHOADA1Xc4BLw3w` |
| Field Status | `PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY` |
| Option Todo | `f75ad846` |
| Option In Progress | `47fc9ee4` |
| Option Done | `98236657` |

### Machines

| Machine | Rôle |
|---------|------|
| myia-ai-01 | Baseline Master |
| myia-po-2023 | Agent flexible |
| myia-po-2024 | Coordinateur Tech |
| myia-po-2026 | Agent flexible |
| myia-web-01 (myia-web1) | Testeur |

---

## 6. Acronymes

| Acronyme | Signification |
|----------|---------------|
| **BOM** | Byte Order Mark (encodage UTF-8) |
| **CP** | Checkpoint |
| **E2E** | End-to-End (tests) |
| **MCP** | Model Context Protocol |
| **PR** | Pull Request |
| **SDDD** | Semantic-Driven Document Design |
| **TTL** | Time To Live (cache) |

---

## Voir Aussi

- [ONBOARDING_AGENT.md](ONBOARDING_AGENT.md) - Guide nouvel agent
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Résolution problèmes
- [CHECKLISTS.md](CHECKLISTS.md) - Listes de vérification
- [ERROR_CODES_REFERENCE.md](../ERROR_CODES_REFERENCE.md) - Codes d'erreur détaillés

---

## Historique

| Date | Version | Auteur | Description |
|------|---------|--------|-------------|
| 2026-01-16 | 1.0.0 | Claude Code (myia-web1) | Création initiale |

---

**Document créé suite à la recommandation T4.12**
**Objectif:** Unifier les termes utilisés dans le système RooSync

