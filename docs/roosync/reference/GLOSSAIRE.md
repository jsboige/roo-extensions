# Glossaire RooSync

**Version:** 1.0.0
**Date:** 2026-01-15
**Auteur:** Claude Code (myia-po-2023)

---

## Table des Matieres

1. [Termes Generaux](#1-termes-generaux)
2. [Architecture](#2-architecture)
3. [Synchronisation](#3-synchronisation)
4. [Erreurs](#4-erreurs)
5. [Outils MCP](#5-outils-mcp)
6. [Machines](#6-machines)

---

## 1. Termes Generaux

### Agent
Programme autonome (Claude Code ou Roo) executant des taches sur une machine du systeme RooSync.

### Baseline
Configuration de reference utilisee pour comparer et synchroniser les machines. Version actuelle: Non-Nominatif v3.0.

### Checkpoint (CP)
Point de validation intermediaire dans le projet. Exemple: CP4.4 = Documentation multi-agent operationnelle.

### INTERCOM
Fichier local `.claude/local/INTERCOM-{MACHINE}.md` pour la communication entre Claude Code et Roo sur la meme machine.

### MCP (Model Context Protocol)
Protocole permettant aux agents d'acceder a des outils externes. RooSync utilise `roo-state-manager` et `github-projects-mcp`.

### RooSync
Systeme de synchronisation multi-agent pour coordonner les configurations entre 5 machines.

### SDDD (Synchronization-Driven Development Documentation)
Methodologie de developpement documentee utilisee pour le projet RooSync.

---

## 2. Architecture

### Baseline Master
Machine responsable de la baseline de reference. Actuellement: **myia-ai-01**.

### Coordinateur Technique
Machine responsable des comparaisons et analyses. Actuellement: **myia-po-2024**.

### Non-Nominatif v3.0
Modele de baseline recommande ou les configurations ne sont pas liees a des machines specifiques.

### Shared State
Repertoire partage (`G:/Mon Drive/Synchronisation/RooSync/.shared-state/`) contenant les configurations, messages et baselines.

### Submodule
Depot Git imbrique. Le MCP RooSync est dans `mcps/internal/servers/roo-state-manager`.

---

## 3. Synchronisation

### Compare
Operation comparant la configuration d'une machine avec la baseline.

### Consensus
Mecanisme de resolution des conflits entre machines. Pattern: timestamp-based (premier arrive, premier servi).

### Heartbeat
Signal periodique indiquant qu'une machine est active. Gap identifie dans T3.14.

### Inventaire
Collecte des informations de configuration d'une machine via `Get-MachineInventory.ps1`.

### Rollback
Restauration d'une configuration precedente apres un echec.

### TTL (Time To Live)
Duree de validite du cache. Valeurs actuelles:
- CacheManager: 2 heures
- RooSyncService: 5 minutes (augmente de 30s)

---

## 4. Erreurs

### ErrorCategory
Classification des erreurs: SCRIPT (bug code) vs SYSTEM (environnement).

### StateManagerError
Classe d'erreur de base pour toutes les erreurs RooSync typees.

### Codes d'Erreur
14 classes, 89 codes documentes dans [ERROR_CODES_REFERENCE.md](ERROR_CODES_REFERENCE.md).

| Classe | Prefixe | Exemple |
|--------|---------|---------|
| ConfigServiceError | CONFIG_ | CONFIG_NOT_FOUND |
| BaselineLoaderError | BASELINE_ | BASELINE_NOT_FOUND |
| MessageManagerError | MESSAGE_ | MESSAGE_NOT_FOUND |

---

## 5. Outils MCP

### github-projects-mcp
MCP pour interagir avec GitHub Projects. 57 outils disponibles.

### roo-state-manager
MCP principal RooSync avec 6 outils de messagerie apres filtrage par wrapper.

### Outils RooSync

| Outil | Description |
|-------|-------------|
| `roosync_send_message` | Envoyer un message inter-machine |
| `roosync_read_inbox` | Lire la boite de reception |
| `roosync_reply_message` | Repondre a un message |
| `roosync_get_message` | Obtenir un message complet |
| `roosync_mark_message_read` | Marquer comme lu |
| `roosync_archive_message` | Archiver un message |
| `roosync_get_status` | Etat de synchronisation |
| `roosync_compare_config` | Comparer configurations |
| `roosync_list_diffs` | Lister les differences |

---

## 6. Machines

### myia-ai-01
Machine principale. Role: Baseline Master, Coordinateur.

### myia-po-2023
Machine secondaire. Role: Agent flexible.

### myia-po-2024
Machine secondaire. Role: Coordinateur Technique.

### myia-po-2026
Machine secondaire. Role: Agent flexible. **Actuellement HS** (reboot manuel requis).

### myia-web-01
Machine de test. Role: Testeur, validation.

---

## Acronymes

| Acronyme | Signification |
|----------|---------------|
| BOM | Byte Order Mark (UTF-8) |
| CP | Checkpoint |
| E2E | End-to-End (tests) |
| HS | Hors Service |
| LRU | Least Recently Used (cache) |
| MCP | Model Context Protocol |
| SDDD | Synchronization-Driven Development Documentation |
| SHA256 | Secure Hash Algorithm 256-bit |
| TTL | Time To Live |

---

## Historique

| Date | Version | Auteur | Description |
|------|---------|--------|-------------|
| 2026-01-15 | 1.0.0 | Claude Code (myia-po-2023) | Creation initiale |

---

**Document cree dans le cadre de T4.12 (ameliorations P2)**
**Reference:** T4.10 - Analyse des besoins de documentation multi-agent
