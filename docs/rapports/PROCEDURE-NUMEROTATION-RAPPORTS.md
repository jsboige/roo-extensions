# 📋 PROCÉDURE DE NUMÉROTATION CHRONOLOGIQUE DES RAPPORTS

**Date de création :** 28 novembre 2025  
**Auteur :** myia-po-2023 (Lead Coordinateur)  
**Version :** 1.0

---

## 🎯 OBJECTIF

Cette procédure standardise la numérotation chronologique des rapports dans `docs/rapports/` pour assurer :
- Meilleure traçabilité chronologique
- Identification rapide des rapports par date
- Organisation professionnelle de la documentation
- Référencement cohérent dans les futurs rapports

---

## 📝 FORMAT ADOPTÉ

### Structure du nom de fichier
```
YYYY-MM-DD_NNN-CATEGORIE-TITRE.md
```

### Composants expliqués
- **`YYYY-MM-DD`** : Date exacte de création du rapport (ISO 8601)
- **`NNN`** : Numéro séquentiel par jour (001, 002, 003...)
- **`CATEGORIE`** : Type de rapport en MAJUSCULES
- **`TITRE`** : Titre descriptif avec tirets
- **`.md`** : Extension Markdown obligatoire

### Exemples valides
```
2025-11-29_001_MCP-nouveau-fix-critique.md
2025-11-29_002_ROOSYNC-synchronisation-avancee.md
2025-11-30_001_VALIDATION-tests-integration.md
2025-12-01_001_MISSION-deploiement-production.md
```

---

## 🏷️ CATÉGORIES AUTORISÉES

| Catégorie | Usage | Exemples |
|-----------|--------|----------|
| **MCP** | Rapports sur serveurs MCP, fixes, intégrations | fix-critique, integration, configuration |
| **ROOSYNC** | Rapports sur système RooSync, synchronisation | suivi, orchestration, corrections |
| **VALIDATION** | Tests, validations, vérifications | tests-integration, validation-systeme |
| **MISSION** | Rapports de missions, opérations spéciales | deploiement, rescue, analyse |
| **CONFIG** | Configurations, paramètres, settings | mise-a-jour, parametrage |
| **SYNTHESE** | Synthèses, résumés, bilans | global, mensuel, projet |
| **DEPLOIEMENT** | Déploiements, installations | production, staging, environnement |
| **GIT** | Opérations Git, versions, branches | sync, merge, stash, branches |
| **ETAT** | États des systèmes, diagnostics | etat-mcps, diagnostic-système |
| **ORCHESTRATION** | Orchestration, coordination | dynamique, multi-agents |
| **CACHE** | Cache, performance, optimisation | rebuild, optimisation |
| **WEB** | Applications web, interfaces | performance, analyse |
| **README** | Documentation, guides | complet, agents, procedure |

---

## 🔄 PROCÉDURE D'AJOUT DE RAPPORT

### 1. Vérification préliminaire
```bash
# Lister les rapports du jour
ls docs/rapports/2025-11-29_*.md

# Compter le nombre de rapports existants pour ce jour
ls docs/rapports/2025-11-29_*.md | wc -l
```

### 2. Détermination du numéro séquentiel
- Si aucun rapport pour la date : utiliser `001`
- Si N rapports existent : utiliser `N+1` (formaté sur 3 chiffres)

### 3. Création du rapport
```bash
# Exemple pour le 3ème rapport du 29 novembre 2025
touch "docs/rapports/2025-11-29_003_MCP-nouveau-fix.md"
```

### 4. Mise à jour de l'index
Ajouter le nouveau rapport dans `docs/rapports/INDEX-RAPPORTS.md` :
- Mettre à jour le compteur total
- Ajouter à la section chronologique appropriée
- Ajouter aux références rapides par catégorie

---

## 📊 GESTION DE L'INDEX

### Mise à jour automatique
L'index `INDEX-RAPPORTS.md` doit être mis à jour avec chaque nouveau rapport :

1. **Incrémenter le compteur total**
2. **Ajouter à la section chronologique** (date appropriée)
3. **Ajouter aux références par catégorie**
4. **Mettre à jour la date de dernière modification**

### Structure de l'index
```markdown
## 📅 RAPPORTS PAR ORDRE CHRONOLOGIQUE
### 2025-11-29 (X rapports)
N. **[lien](fichier.md)**
   - Description courte
   - Taille : X.XX KB (XXX lignes)

## 📋 RÉFÉRENCES RAPIDES PAR CATÉGORIE
### 🚀 MISSION (X rapports)
- [lien](fichier.md)
```

---

## 🔍 VÉRIFICATION ET MAINTENANCE

### Vérification mensuelle
```bash
# Vérifier l'ordre chronologique
ls -la docs/rapports/*.md | sort

# Vérifier les doublons de numéros
ls docs/rapports/2025-11-*.md | grep -E "00[1-9]"
```

### Maintenance trimestrielle
1. **Vérifier l'intégrité des liens** dans l'index
2. **Valider le format** de tous les noms de fichiers
3. **Nettoyer les références obsolètes**
4. **Archiver les rapports très anciens** si nécessaire

---

## ⚠️ POINTS DE VIGILANCE

### À éviter
- **Noms de fichiers trop longs** (> 100 caractères)
- **Caractères spéciaux** (accents, espaces, symboles)
- **Numéros séquentiels incorrects** (doublons, trous)
- **Catégories non standardisées**

### Bonnes pratiques
- **Toujours vérifier** le numéro séquentiel avant création
- **Mettre à jour l'index** immédiatement après création
- **Utiliser des titres descriptifs** mais concis
- **Vérifier les références croisées** dans les rapports existants

---

## 🛠️ SCRIPTS D'AUTOMATISATION (OPTIONNEL)

### Script de vérification (PowerShell)
```powershell
# verify-report-naming.ps1
Get-ChildItem "docs/rapports/*.md" | ForEach-Object {
    if ($_.Name -notmatch '^\d{4}-\d{2}-\d{2}_\d{3}-[A-Z]+-.*\.md$') {
        Write-Warning "Format invalide: $($_.Name)"
    }
}
```

### Script de génération de numéro (Bash)
```bash
# get-next-number.sh
DATE=$1
COUNT=$(ls docs/rapports/${DATE}_*.md 2>/dev/null | wc -l)
printf "%03d" $((COUNT + 1))
```

---

## 📞 SUPPORT ET CONTACT

**Pour toute question sur cette procédure :**
- **Coordinateur principal :** myia-po-2023
- **Dépôt de référence :** `docs/rapports/`
- **Index principal :** `docs/rapports/INDEX-RAPPORTS.md`

---

*Document créé le 28 novembre 2025*
*Dernière mise à jour : 28 novembre 2025*
*Version : 1.0*