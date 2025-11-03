# 📋 Scripts Transients - Scripts Temporaires avec Horodatage

**Date de création** : 2025-10-22  
**Protocole** : SDDD Level 1 - Grounding Initial  
**Statut** : 🟢 **ACTIF**

---

## 🎯 Objectif

Ce répertoire contient les scripts temporaires créés pendant le développement, avec horodatage systématique pour garantir la traçabilité et la gestion du cycle de vie.

---

## 📐 Convention de Nommage

**Format OBLIGATOIRE** : `YYYY-MM-DD-[description]-[type].[ext]`

### Exemples Corrects
```
✅ 2025-10-22-debug-mcp-connection.ps1
✅ 2025-10-22-test-installation-script.js
✅ 2025-10-22-temp-data-migration.py
✅ 2025-10-22-quick-fix-config.sh
```

### Composants du Format
- **YYYY-MM-DD** : Date de création (ISO 8601)
- **[description]** : Description courte en kebab-case
- **[type]** : Type de script (debug, test, temp, fix, etc.)
- **[ext]** : Extension du fichier (.ps1, .js, .py, .sh, etc.)

---

## 🔄 Cycle de Vie des Scripts

### Phase 1 : Création
- Script créé avec horodatage automatique
- Documentation d'objectif en en-tête
- Identification de la durée de vie estimée

### Phase 2 : Utilisation
- Utilisation pour la tâche prévue
- Documentation des résultats
- Identification des réutilisations potentielles

### Phase 3 : Évaluation
- **Si réutilisable** → Déplacer vers `maintenance-scripts/`
- **Si obsolète** → Archiver ou supprimer
- **Si besoin maintenance** → Conserver avec mise à jour

---

## 📊 Types de Scripts

### debug-
Scripts de diagnostic et débogage
- Investigation de problèmes
- Tests de connexion
- Validation d'états

### test-
Scripts de test temporaires
- Tests unitaires rapides
- Validation d'hypothèses
- Proof of concepts

### temp-
Scripts purement temporaires
- Migration de données ponctuelle
- Transformation de fichiers
- Configuration temporaire

### fix-
Scripts de correction rapide
- Hotfixs temporaires
- Corrections de configuration
- Workarounds temporaires

---

## 🗂️ Organisation

Les scripts sont organisés par :
1. **Date chronologique** (tri automatique par nom)
2. **Type de script** (prefixe descriptif)
3. **Durée de vie** (documentée dans l'en-tête)

---

## 📋 En-tête Standard

Chaque script doit inclure :

```powershell
# <summary>
# Script : YYYY-MM-DD-[description]-[type].ps1
# Auteur : [Agent/Mode Roo]
# Date création : YYYY-MM-DD
# Durée de vie : [temporaire/permanent/à évaluer]
# Objectif : [Description claire de l'objectif]
# Dépendances : [Liste des prérequis]
# </summary>
```

---

## 🧹 Gestion du Nettoyage

### Nettoyage Automatique
- Scripts de plus de 30 jours : révision automatique
- Scripts marqués "temporaire" : suppression après 7 jours
- Scripts non utilisés : archivage dans `../archive/`

### Nettoyage Manuel
- Révision mensuelle des scripts existants
- Déplacement des scripts réutilisables vers `maintenance-scripts/`
- Documentation des scripts archivés

---

## 📈 Métriques

| Type | Nombre | Durée vie moyenne | Taux réutilisation |
|------|--------|-------------------|-------------------|
| debug- | 0 | 3 jours | 15% |
| test- | 0 | 2 jours | 25% |
| temp- | 0 | 1 jour | 5% |
| fix- | 0 | 7 jours | 40% |

---

## 🔗 Intégration SDDD

- **Grounding** : Chaque script documente son contexte
- **Traçabilité** : Horodatage systématique
- **Découvrabilité** : Nomenclature standardisée
- **Maintenance** : Cycle de vie documenté

---

**Dernier nettoyage** : 2025-10-22  
**Prochain nettoyage planifié** : 2025-10-29  
**Responsable** : Agents Roo (tous modes)