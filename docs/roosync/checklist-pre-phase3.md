# ✅ Checklist Pré-Phase 3 RooSync

**Date de création** : 21 octobre 2025  
**Version** : 1.0  
**Agent responsable** : myia-ai-01  

---

## 📋 Préparation Locale (myia-ai-01)

### Infrastructure RooSync v2.0

- [x] **Phase 2 complétée avec succès**
  - ✅ InventoryCollector réparé (CPU/RAM détection OK)
  - ✅ DiffDetector refactorisé (safe property access)
  - ✅ Tests locaux validés

- [x] **Tous commits synchronisés sur GitHub**
  - ✅ 15+ commits pushés
  - ✅ Dernier merge : `f7a3790`
  - ✅ Submodule roo-state-manager à jour

- [x] **Working tree clean**
  - ✅ Repo principal : `nothing to commit, working tree clean`
  - ✅ Submodule roo-state-manager : `nothing to commit, working tree clean`
  - ✅ Branch main synchronisée avec origin/main

- [x] **Documentation à jour**
  - ✅ Rapport InventoryCollector (`docs/roosync/repair-inventory-collector-20251020.md`)
  - ✅ Rapport DiffDetector (`docs/roosync/refactor-diff-detector-safe-access-20251021.md`)
  - ✅ Rapport session globale (`docs/sessions/session-roosync-phase2-20251021.md`)
  - ✅ Checklist pré-Phase 3 (ce document)

- [ ] **Message myia-po-2024 reçu et traité**
  - ⚠️ EN ATTENTE : Message envoyé, lecture non confirmée
  - ⚠️ Actions requises par myia-po-2024 (voir section Agent Distant)

- [ ] **Inventaire myia-po-2024 validé**
  - ⚠️ BLOQUANT : CPU=0, RAM=0 détectés lors dernier test
  - ⚠️ Nécessite correction script `Get-MachineInventory.ps1` sur myia-po-2024

---

## 📋 Préparation Agent Distant (myia-po-2024)

### Communication et Coordination

- [ ] **Message Phase 2 lu et compris**
  - Localisation : `RooSync/inbox/<message-id>.json`
  - Contenu : Rapport Phase 2 + Instructions Phase 3
  - Action : Marquer comme lu via `roosync_mark_message_read`

### Correction Inventaire Machine

- [ ] **Script Get-MachineInventory.ps1 corrigé**
  - **Problème identifié** : Commandes Linux incompatibles
  - **Fichier à corriger** : `scripts/roosync/Get-MachineInventory.ps1`
  - **Corrections requises** :
    ```powershell
    # CPU Detection (Linux)
    # AVANT (défaillant):
    $cpuInfo = lscpu | Select-String "Model name"
    
    # APRÈS (correct):
    $cpuInfo = lscpu | grep -i "model name" | head -1 | cut -d ':' -f 2 | xargs
    
    # OU utiliser alternative robuste:
    $cpuInfo = cat /proc/cpuinfo | grep "model name" | head -1 | cut -d ':' -f 2 | xargs
    ```
    
    ```powershell
    # RAM Detection (Linux)  
    # AVANT (défaillant):
    $ramInfo = free -h | Select-String "Mem:"
    
    # APRÈS (correct):
    $ramTotal = free -m | grep "^Mem:" | awk '{print $2}'
    $ramUsed = free -m | grep "^Mem:" | awk '{print $3}'
    ```

- [ ] **Inventaire re-généré et validé**
  - Commande : `pwsh -c "./scripts/roosync/Get-MachineInventory.ps1"`
  - **Validation critique** :
    - ✅ CPU name contient du texte (ex: "Intel Core i7-9700K")
    - ✅ RAM total > 0 (ex: 16384 MB)
    - ✅ Disques détectés (au moins 1 disque)
    - ✅ Fichier sauvegardé : `roo-config/reports/machine-inventory-myia-po-2024-<date>.json`

### Synchronisation Git

- [ ] **Commits GitHub récupérés**
  - Commits clés à puller :
    - `f7a3790` - Merge Phase 2 RooSync + Post-Phase 3D
    - `ee9d0aa` - DiffDetector refactoring + update submodule
    - `53d01c3` - InventoryCollector repair report
  - Commande : `git pull origin main`

- [ ] **Submodule roo-state-manager mis à jour**
  - Commande : `git submodule update --remote --merge`
  - Validation : Vérifier présence commits récents dans submodule

### Build et Validation MCP

- [ ] **Build MCP roo-state-manager à jour**
  - Localisation : `mcps/internal/servers/roo-state-manager`
  - Commandes :
    ```bash
    cd mcps/internal/servers/roo-state-manager
    npm install
    npm run build
    ```
  - Validation : Dossier `build/` créé et contient fichiers .js

- [ ] **Tests MCP fonctionnels**
  - Test inventaire : Appeler tool `detect_roo_storage`
  - Test comparaison : Vérifier tool `roosync_compare_config` disponible
  - Validation : Aucune erreur dans logs MCP

---

## 📋 Coordination Collaborative

### Communication Inter-Agents

- [ ] **Utilisateur informé de l'état actuel**
  - Rapport session Phase 2 partagé
  - Blocages identifiés communiqués (inventaire myia-po-2024)
  - Timeline Phase 3 estimée (2-3h si inventaire OK)

- [ ] **Planning Phase 3 validé par utilisateur**
  - Objectif : Tests collaboratifs comparaison configurations
  - Participants : myia-ai-01 (local) + myia-po-2024 (distant) + utilisateur (superviseur)
  - Durée estimée : 2-3 heures

- [ ] **Rôles et responsabilités clarifiés**
  - **myia-ai-01** : 
    - Orchestration tests Phase 3
    - Appel `roosync_compare_config` avec inventaires réels
    - Génération décisions (Phase 4)
  - **myia-po-2024** :
    - Fournir inventaire machine valide
    - Confirmer réception messages RooSync
    - Appliquer décisions approuvées (Phase 5)
  - **Utilisateur** :
    - Valider décisions générées avant application
    - Superviser synchronisation collaborative
    - Résoudre conflits si nécessaires

---

## 🎯 Critères de Démarrage Phase 3

### Pré-requis Techniques (OBLIGATOIRES)

- [ ] **Inventaires complets (2 machines)**
  - ✅ myia-ai-01 : Inventaire valide (CPU/RAM > 0)
  - ⚠️ myia-po-2024 : Inventaire à valider (CPU/RAM > 0)

- [ ] **Tool roosync_compare_config opérationnel**
  - Validation : Appel test avec inventaires factices
  - Résultat attendu : JSON avec sections `hardware`, `software`, `rooConfig`

- [ ] **Décisions générées et analysées**
  - Format : JSON avec `decisionId`, `type`, `priority`, `impact`
  - Catégories attendues :
    - Différences MCPs (ajout/suppression/version)
    - Différences modes (configuration)
    - Différences settings (paths, options)

- [ ] **Accord utilisateur pour approbations**
  - Processus validé : Génération → Analyse → Approbation → Application
  - Responsabilité claire : Utilisateur approuve, agents exécutent
  - Sécurité : Rollback possible via `roosync_rollback_decision`

### Pré-requis Communication

- [ ] **Message RooSync envoyé à myia-po-2024**
  - ✅ Message créé (Phase 2 rapport + instructions)
  - ⚠️ Lecture non confirmée (EN ATTENTE)

- [ ] **Canal communication bidirectionnel actif**
  - Test : myia-po-2024 peut répondre via `roosync_send_message`
  - Test : myia-ai-01 peut lire inbox via `roosync_read_inbox`

---

## 📊 État Actuel des Critères

| Critère | Machine | Statut | Blocage |
|---------|---------|--------|---------|
| Inventaire valide | myia-ai-01 | ✅ **OK** | - |
| Inventaire valide | myia-po-2024 | ⚠️ **BLOQUÉ** | CPU=0, RAM=0 |
| Commits synchronisés | myia-ai-01 | ✅ **OK** | - |
| Commits synchronisés | myia-po-2024 | ⚠️ **INCONNU** | Pull requis |
| Build MCP à jour | myia-ai-01 | ✅ **OK** | - |
| Build MCP à jour | myia-po-2024 | ⚠️ **INCONNU** | Rebuild requis |
| Message lu | myia-po-2024 | ⚠️ **INCONNU** | Lecture non confirmée |

**Conclusion** : **2 blocages critiques** empêchent démarrage Phase 3
1. Inventaire myia-po-2024 invalide (CPU=0, RAM=0)
2. Communication myia-po-2024 non confirmée (lecture message)

---

## 🚀 Actions Immédiates Requises

### Pour myia-po-2024 (URGENT)

1. **Lire message RooSync Phase 2**
   - Tool : `roosync_read_inbox`
   - Marquer comme lu : `roosync_mark_message_read`

2. **Corriger script Get-MachineInventory.ps1**
   - Appliquer corrections Linux (voir section Correction Inventaire)
   - Tester commandes individuellement avant intégration

3. **Re-générer inventaire machine**
   - Exécuter script corrigé
   - Valider CPU name et RAM > 0

4. **Synchroniser Git et Build MCP**
   - `git pull origin main`
   - `git submodule update --remote --merge`
   - `cd mcps/internal/servers/roo-state-manager && npm run build`

5. **Confirmer prêt pour Phase 3**
   - Répondre via `roosync_send_message` avec statut

### Pour myia-ai-01 (EN ATTENTE)

1. **Attendre confirmation myia-po-2024**
   - Polling inbox toutes les heures
   - Vérifier message "ready for Phase 3"

2. **Valider inventaire myia-po-2024**
   - Tool : `roosync_get_status` avec `machineFilter: "myia-po-2024"`
   - Confirmer CPU/RAM > 0

3. **Préparer appel roosync_compare_config**
   - Arguments : `source: "myia-ai-01"`, `target: "myia-po-2024"`
   - Mode dry-run d'abord pour validation

### Pour Utilisateur

1. **Superviser progression myia-po-2024**
   - Vérifier corrections appliquées
   - Valider inventaire re-généré

2. **Autoriser démarrage Phase 3**
   - Confirmer pré-requis remplis
   - Donner go explicite pour comparaison configs

---

## 📞 Support et Ressources

### Documentation Technique
- [InventoryCollector Repair](repair-inventory-collector-20251020.md)
- [DiffDetector Refactoring](refactor-diff-detector-safe-access-20251021.md)
- [Session Phase 2 Report](../sessions/session-roosync-phase2-20251021.md)

### Scripts Utilitaires
- **Inventaire machine** : `scripts/roosync/Get-MachineInventory.ps1`
- **Force MCP reconnect** : `scripts/roosync/force-mcp-reconnect.ps1`
- **Git commit phase** : `scripts/git/git-commit-phase.ps1`

### MCP Tools RooSync
- `detect_roo_storage` : Détecte emplacements stockage Roo
- `roosync_get_status` : État synchronisation actuel
- `roosync_compare_config` : Compare configurations 2 machines
- `roosync_send_message` : Envoie message inter-agents
- `roosync_read_inbox` : Lit inbox messages RooSync

### Contacts GitHub
- **Repository** : `jsboige/roo-extensions`
- **Branch principale** : `main`
- **Dernier commit** : `f7a3790`

---

## 🔄 Processus de Validation

Avant de cocher un item :
1. ✅ **Exécuter** l'action requise
2. ✅ **Vérifier** le résultat attendu
3. ✅ **Documenter** toute anomalie rencontrée
4. ✅ **Confirmer** avec autre agent si nécessaire

Format de confirmation :
```
[x] Item validé - <Date> - <Agent> - Notes: <détails si pertinent>
```

Exemple :
```
[x] Inventaire re-généré et validé - 21/10/2025 - myia-po-2024 - Notes: CPU=Intel i7, RAM=16GB
```

---

## 📝 Notes de Mise à Jour

| Date | Agent | Modification | Raison |
|------|-------|--------------|--------|
| 21/10/2025 | myia-ai-01 | Création initiale | Clôture Phase 2, préparation Phase 3 |

---

*Checklist maintenue par myia-ai-01 - Dernière mise à jour : 21 octobre 2025*