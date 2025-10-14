# 🤝 Protocole de Coordination RooSync - Tests Multi-Machines

## 📋 Vue d'Ensemble

Ce document définit le protocole de coordination entre les agents **myia-ai-01** (agent principal) et l'**agent distant** (seconde machine) lors des tests RooSync v2.0.0.

## 🎯 Objectifs du Protocole

1. **Synchronisation temporelle** : Garantir que les deux agents exécutent les tests dans un ordre coordonné
2. **Communication standardisée** : Format unifié pour les rapports et échanges
3. **Gestion des conflits** : Procédures claires pour résoudre les désaccords
4. **Traçabilité complète** : Chaque action doit être documentée et horodatée

## 🔄 Points de Synchronisation Obligatoires

### Phase 1 : Initialisation
**Responsable** : myia-ai-01  
**Actions** :
1. Exécuter `roosync_init`
2. Vérifier la création de l'infrastructure (`sync-dashboard.json`, `sync-roadmap.md`)
3. Confirmer l'accès au répertoire partagé

**Point de Sync** : ✋ **CHECKPOINT-INIT**
- myia-ai-01 rapporte : "Infrastructure initialisée, répertoire partagé accessible"
- Agent distant confirme : "Accès au répertoire partagé vérifié"

### Phase 2 : État Initial
**Responsable** : Les deux agents (parallèle)  
**Actions** :
1. Chaque agent exécute `roosync_get_status`
2. Chaque agent exécute `roosync_compare_config` avec l'autre machine comme cible

**Point de Sync** : ✋ **CHECKPOINT-STATUS**
- Format de rapport :
```json
{
  "agent": "myia-ai-01",
  "timestamp": "2025-10-13T22:00:00Z",
  "machines_detected": 2,
  "status": "synced|diverged",
  "divergences_count": 0
}
```

### Phase 3 : Détection de Divergences
**Responsable** : Les deux agents (parallèle)  
**Actions** :
1. Exécuter `roosync_list_diffs`
2. Pour chaque divergence détectée, exécuter `roosync_get_decision_details`

**Point de Sync** : ✋ **CHECKPOINT-DIFFS**
- Si divergences détectées : passage en mode coordination stricte
- Si aucune divergence : passage à Phase 5 (validation)

### Phase 4 : Résolution de Divergences (si nécessaire)
**Responsable** : Coordination utilisateur + agents  
**Actions** :
1. **Consultation utilisateur** : Présentation des divergences et recommandations
2. **Approbation** : L'agent désigné exécute `roosync_approve_decision`
3. **Application** : L'agent désigné exécute `roosync_apply_decision`
4. **Vérification post-application** : Les deux agents re-vérifient l'état

**Point de Sync** : ✋ **CHECKPOINT-RESOLUTION**
- Rapport de chaque agent confirmant l'application
- Vérification que les deux machines sont maintenant `synced`

### Phase 5 : Validation Finale
**Responsable** : Les deux agents (parallèle)  
**Actions** :
1. Re-exécuter `roosync_get_status`
2. Re-exécuter `roosync_compare_config`
3. Confirmer : status = `synced`, divergences = 0

**Point de Sync** : ✋ **CHECKPOINT-FINAL**
- Rapport final de validation
- Synthèse des tests effectués

## 📝 Format de Communication Standardisé

### Message de Status
```markdown
## Status Report - [Agent ID] - [Timestamp]

### État Actuel
- Machine ID : [ID]
- Status Global : [synced|diverged]
- Machines Détectées : [count]
- Divergences : [count]

### Dernière Action
- Outil : [nom_outil]
- Résultat : [success|failure]
- Détails : [description]

### État de Coordination
- Checkpoint Atteint : [CHECKPOINT-XXX]
- En Attente de : [autre_agent|utilisateur|rien]
```

### Message de Divergence
```markdown
## Divergence Report - [Agent ID] - [Timestamp]

### Divergence Détectée
- Type : [config|files|settings]
- Champ Affecté : [nom_champ]
- Valeur Locale : [valeur]
- Valeur Distante : [valeur]
- Décision ID : [decision_id]

### Recommandation
- Action Suggérée : [merge|override_local|override_remote]
- Justification : [raison]
- Risque : [low|medium|high]
```

### Message de Coordination
```markdown
## Coordination Request - [Agent ID] - [Timestamp]

### Demande
- Type : [approval|execution|verification]
- Cible : [decision_id|autre_agent]
- Action Requise : [description]

### Contexte
- Checkpoint : [CHECKPOINT-XXX]
- État Dépendances : [ready|waiting]
- Timeout : [duration en minutes]
```

## ⚠️ Gestion des Conflits

### Principe Fondamental : Synchronisation Asynchrone
**Aucune priorité d'agent** : Tous les agents sont égaux. Après l'initialisation par myia-ai-01, chaque agent peut agir indépendamment. La coordination se fait à 3 (utilisateur + les deux agents) lors des points de décision.

### Cas 1 : Détection Simultanée d'Actions Conflictuelles
**Approche collaborative à 3** :
1. Chaque agent détecte la divergence indépendamment et crée son rapport
2. Les deux agents partagent leurs observations dans le dashboard
3. **Point de synchronisation à 3** : Utilisateur + agent 1 + agent 2 examinent ensemble
4. L'utilisateur arbitre et désigne quel agent appliquera la décision
5. Validation finale collective des trois parties

### Cas 2 : Travail en Parallèle (Normal)
**Approche** : Les agents travaillent de façon asynchrone et se synchronisent via le dashboard partagé. Aucun timeout strict, chacun avance à son rythme et rapporte ses progrès.

**Procédure** :
1. Si timeout atteint, l'agent en attente signale le problème
2. Vérification de l'état de l'autre agent via `roosync_get_status`
3. Si l'autre agent est "stuck", escalade vers l'utilisateur
4. Possibilité de rollback si nécessaire

### Cas 3 : Échec d'Application de Décision
**Procédure** :
1. L'agent qui a échoué exécute immédiatement `roosync_rollback_decision`
2. Rapport détaillé de l'échec avec logs
3. Les deux agents reviennent au checkpoint précédent
4. Consultation utilisateur obligatoire avant de réessayer

## ✅ Checklist de Validation par Phase

### Phase 1 - Initialisation
- [ ] Infrastructure créée par myia-ai-01
- [ ] Répertoire partagé accessible par les deux agents
- [ ] Fichiers de base présents (dashboard, roadmap)
- [ ] Checkpoint INIT atteint

### Phase 2 - État Initial
- [ ] Les deux agents ont exécuté `roosync_get_status`
- [ ] Les deux agents ont exécuté `roosync_compare_config`
- [ ] Rapports de status échangés et validés
- [ ] Checkpoint STATUS atteint

### Phase 3 - Détection
- [ ] `roosync_list_diffs` exécuté par les deux agents
- [ ] Liste des divergences identique des deux côtés
- [ ] Décisions créées et synchronisées
- [ ] Checkpoint DIFFS atteint

### Phase 4 - Résolution
- [ ] Utilisateur consulté et approbation obtenue
- [ ] Décision approuvée par l'agent désigné
- [ ] Décision appliquée avec succès
- [ ] Vérification post-application OK
- [ ] Checkpoint RESOLUTION atteint

### Phase 5 - Validation
- [ ] Status `synced` confirmé par les deux agents
- [ ] Aucune divergence résiduelle
- [ ] Rapports finaux générés
- [ ] Checkpoint FINAL atteint

## 🚨 Procédure d'Escalade

### Niveau 1 : Avertissement
**Déclencheurs** :
- Timeout approché (80% du temps alloué)
- Divergence inattendue mineure
- Performance dégradée

**Action** : Signaler à l'utilisateur, continuer avec prudence

### Niveau 2 : Intervention Requise
**Déclencheurs** :
- Timeout dépassé
- Échec d'application de décision
- Divergence critique
- Corruption de données suspectée

**Action** : Arrêt immédiat, rapport détaillé, attente instruction utilisateur

### Niveau 3 : Urgence
**Déclencheurs** :
- Perte d'accès au répertoire partagé
- Corruption confirmée
- Incohérence majeure entre agents

**Action** : Rollback automatique si possible, alerte immédiate, arrêt complet des tests

## 📊 Métriques de Coordination

### Indicateurs de Performance
- **Latence de Synchronisation** : Temps entre deux checkpoints
- **Taux de Succès** : % de décisions appliquées sans échec
- **Divergences Détectées** : Nombre total par phase
- **Rollbacks Nécessaires** : Nombre et raisons

### Format de Rapport Métrique
```json
{
  "test_session": "2025-10-13-roosync-phase1",
  "duration_minutes": 45,
  "checkpoints_reached": ["INIT", "STATUS", "DIFFS", "RESOLUTION", "FINAL"],
  "sync_latency_avg_seconds": 12,
  "decisions_total": 3,
  "decisions_success": 3,
  "decisions_rollback": 0,
  "divergences_detected": 3,
  "divergences_resolved": 3
}
```

## 🎓 Bonnes Pratiques

1. **Communication Proactive** : Signaler chaque action avant de l'exécuter
2. **Vérification Systématique** : Ne jamais assumer, toujours vérifier
3. **Documentation Continue** : Logger toutes les actions avec timestamp
4. **Patience** : Attendre la confirmation avant de passer à l'étape suivante
5. **Transparence** : Partager tous les détails, même les erreurs mineures

## 🔐 Sécurité et Intégrité

### Validation des Décisions
Avant d'appliquer toute décision :
1. Vérifier que le `decision_id` est valide et récent
2. Confirmer que la décision a été approuvée
3. S'assurer qu'aucun autre agent n'applique la même décision simultanément
4. Créer un backup automatique

### Protection contre les Conditions de Course
- Utilisation de verrous (locks) dans le dashboard partagé
- Timeout pour libération automatique des verrous
- Détection de verrous orphelins

## 📞 Contacts et Support

En cas de problème non résolu par le protocole :
1. Consulter les logs dans `sync-dashboard.json`
2. Vérifier l'état des deux agents
3. Contacter l'utilisateur avec un rapport complet
4. Si nécessaire, arrêter les tests et attendre assistance

---

**Version** : 1.0.0  
**Date** : 2025-10-13  
**Auteur** : myia-ai-01  
**Status** : Production - Tests Phase 1