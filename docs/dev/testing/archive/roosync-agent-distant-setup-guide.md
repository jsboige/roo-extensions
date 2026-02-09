# 🚀 Guide de Mise en Route - Agent Distant RooSync v2.0.0

## 🎯 Contexte

Vous êtes l'agent IA d'une seconde machine qui va participer aux tests de synchronisation multi-machines RooSync v2.0.0. L'agent **myia-ai-01** a déjà initialisé l'infrastructure et corrigé les outils MCP.

## 📋 Prérequis

### 1. Récupérer les Dernières Modifications

**Dans le dépôt principal** :
```bash
cd d:/roo-extensions  # Ou votre chemin de workspace
git pull origin main
```

**Mettre à jour le sous-module roo-state-manager** :
```bash
git submodule update --init --recursive
cd mcps/internal/servers/roo-state-manager
git pull origin main
cd ../../../..
```

### 2. Configurer Votre Identité Machine

**Éditer** : `mcps/internal/servers/roo-state-manager/.env`

Ajouter/modifier :
```env
ROOSYNC_MACHINE_ID=<votre-identifiant-unique>
# Exemples : myia-ai-02, dev-laptop, prod-server
```

**Autres variables importantes** :
```env
SHARED_STATE_PATH=G:/Mon Drive/Synchronisation/RooSync/.shared-state/
ROOSYNC_CONFLICT_STRATEGY=manual
ROOSYNC_AUTO_SYNC=false
```

### 3. Vérifier l'Accès au Répertoire Partagé

- Confirmer que `G:/Mon Drive/Synchronisation/RooSync/.shared-state/` est accessible
- Vérifier que les fichiers suivants existent :
  - `sync-dashboard.json`
  - `sync-roadmap.md`
  - Répertoire `.rollback/`

## 🧪 Phase de Test

### Étape 1 : Obtenir l'État Initial

Utiliser l'outil MCP `roosync_get_status` :

```json
{
  "action": "get_status"
}
```

**Résultat attendu** :
- Vous devriez voir 2 machines (myia-ai-01 + votre machine)
- Status global : `synced` ou `diverged`
- Décisions en attente : 0 ou plus

### Étape 2 : Comparer Votre Configuration

Utiliser l'outil MCP `roosync_compare_config` :

```json
{
  "targetMachine": "myia-ai-01"
}
```

**Objectif** : Détecter les divergences entre votre configuration locale et celle de myia-ai-01.

### Étape 3 : Lister Toutes les Divergences

Utiliser l'outil MCP `roosync_list_diffs` :

```json
{
  "type": "config"
}
```

### Étape 4 : Workflow de Décision (Coordination avec myia-ai-01)

**SI une divergence est détectée** :

1. **Examiner la décision** avec `roosync_get_decision_details` :
   ```json
   {
     "decisionId": "<ID fourni dans list_diffs>"
   }
   ```

2. **Attendre coordination avec l'utilisateur** avant d'approuver/rejeter

3. **Approuver** (si validé) avec `roosync_approve_decision` :
   ```json
   {
     "decisionId": "<ID>",
     "approver": "<votre-machine-id>"
   }
   ```

4. **Appliquer** (si autorisé) avec `roosync_apply_decision` :
   ```json
   {
     "decisionId": "<ID>"
   }
   ```

### Étape 5 : Validation Finale

Re-exécuter `roosync_get_status` et `roosync_compare_config` pour confirmer :
- Status : `synced`
- Divergences : 0
- Les deux machines sont cohérentes

## 🔄 Scénarios de Test Prévus

### Scénario A : Divergence de Version
- **Objectif** : Tester la détection de versions différentes
- **Action** : Modifier votre `RooSync/.config/sync-config.json` (version)
- **Résultat attendu** : Décision créée, workflow d'approbation

### Scénario B : Divergence de Chemin
- **Objectif** : Tester les différences de configuration système
- **Action** : Modifier `sharedStatePath`
- **Résultat attendu** : Détection et proposition de fusion

### Scénario C : Application et Rollback
- **Objectif** : Valider le mécanisme de sauvegarde/restauration
- **Action** : Appliquer une décision puis la rollback
- **Résultat attendu** : Retour à l'état initial

## ⚠️ Règles de Coordination

1. **Ne jamais approuver/appliquer sans validation de l'utilisateur**
2. **Communiquer chaque observation à l'utilisateur**
3. **Attendre la synchronisation avec myia-ai-01** pour les actions coordonnées
4. **Documenter chaque étape dans votre rapport**

## 📊 Format de Rapport

Après chaque phase, rapporter :

```markdown
## Rapport Agent [Votre Machine ID]

### État Initial
- Machine ID : <votre-id>
- Machines détectées : X
- Divergences : X

### Actions Réalisées
- [ ] roosync_get_status
- [ ] roosync_compare_config
- [ ] roosync_list_diffs
- [ ] roosync_get_decision_details
- [ ] roosync_approve_decision
- [ ] roosync_apply_decision

### Observations
- Observation 1
- Observation 2

### Synchronisation avec myia-ai-01
- État myia-ai-01 : <synced/diverged>
- Différences détectées : <liste>
- Actions coordonnées : <liste>

### Recommandations
- Recommandation 1
- Recommandation 2
```

## 🎯 Objectif Final

Valider que le système RooSync v2.0.0 fonctionne en mode multi-machines avec :
- ✅ Détection de divergences bidirectionnelle
- ✅ Création de décisions cohérentes
- ✅ Workflow d'approbation coordonné
- ✅ Application et rollback fiables
- ✅ Synchronisation finale réussie

## 🆘 Support

En cas de problème :
1. Vérifier l'accès au répertoire partagé
2. Confirmer que votre `.env` est correctement configuré
3. Relancer le serveur MCP roo-state-manager
4. Consulter les logs dans `sync-dashboard.json`

**Bonne chance !** 🚀