# Matrice de Traçabilité - Standardisation Environnement UTF-8

**Date**: 2025-10-30
**Projet**: Standardisation UTF-8
**Responsable**: Roo Architect Complex Mode
**Statut**: Validé

## 1. Objectifs de la Standardisation

L'objectif principal est d'éliminer les problèmes d'encodage récurrents en forçant un environnement UTF-8 cohérent à tous les niveaux (Machine, User, Processus).

## 2. Matrice des Exigences et Corrections

| ID Exigence | Description | ID Correction | Composant Affecté | Statut | Validation |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **REQ-ENV-001** | Le système doit utiliser UTF-8 pour toutes les opérations de locale. | **ENV-001** | Variables `LANG`, `LC_ALL` | ✅ Implémenté | `Test-StandardizedEnvironment.ps1` (Test 3) |
| **REQ-ENV-002** | Python doit utiliser UTF-8 pour les E/S standard. | **ENV-002** | Variable `PYTHONIOENCODING` | ✅ Implémenté | `Test-StandardizedEnvironment.ps1` (Test 3) |
| **REQ-ENV-003** | Node.js doit avoir une mémoire suffisante pour les gros traitements. | **ENV-003** | Variable `NODE_OPTIONS` | ✅ Implémenté | `Test-StandardizedEnvironment.ps1` (Test 3) |
| **REQ-ENV-004** | Java doit utiliser UTF-8 par défaut pour les fichiers. | **ENV-004** | Variable `JAVA_TOOL_OPTIONS` | ✅ Implémenté | `Test-StandardizedEnvironment.ps1` (Test 3) |
| **REQ-ENV-005** | La console Windows doit utiliser la page de code 65001 (UTF-8). | **ENV-005** | Registre `HKCU\Console` | ✅ Implémenté | `Test-StandardizedEnvironment.ps1` (Test 3) |
| **REQ-ENV-006** | Git doit gérer correctement les chemins Unicode. | **ENV-006** | Variables `GIT_CONFIG_*` | ✅ Implémenté | `Test-StandardizedEnvironment.ps1` (Test 3) |
| **REQ-ENV-007** | Les variables critiques doivent être persistantes. | **ENV-007** | Registre HKLM/HKCU | ✅ Implémenté | `Test-StandardizedEnvironment.ps1` (Test 2) |
| **REQ-ENV-008** | La hiérarchie Machine > User > Processus doit être respectée. | **ENV-008** | Logique d'application | ✅ Implémenté | `Test-StandardizedEnvironment.ps1` (Test 1) |

## 3. Détail des Corrections (ENV-XXX)

### ENV-001 : Standardisation Locale
- **Description**: Force `fr-FR.UTF-8` pour `LANG` et `LC_ALL`.
- **Impact**: Tous les outils respectant POSIX utiliseront UTF-8.
- **Rollback**: Supprimer les variables `LANG` et `LC_ALL`.

### ENV-002 : Encodage Python
- **Description**: Force `utf-8` pour `PYTHONIOENCODING`.
- **Impact**: Résout les `UnicodeEncodeError` lors de l'impression de caractères spéciaux.
- **Rollback**: Supprimer la variable `PYTHONIOENCODING`.

### ENV-003 : Mémoire Node.js
- **Description**: Définit `--max-old-space-size=4096` dans `NODE_OPTIONS`.
- **Impact**: Prévient les crashs "Out of Memory" sur les gros projets.
- **Rollback**: Supprimer la variable `NODE_OPTIONS`.

### ENV-004 : Encodage Java
- **Description**: Ajoute `-Dfile.encoding=UTF-8` à `JAVA_TOOL_OPTIONS`.
- **Impact**: Les applications Java liront/écriront en UTF-8 par défaut.
- **Rollback**: Supprimer la variable `JAVA_TOOL_OPTIONS`.

### ENV-005 : Page de Code Console
- **Description**: Configure le registre pour utiliser CP 65001 par défaut.
- **Impact**: `cmd.exe` et PowerShell s'ouvriront en mode UTF-8.
- **Rollback**: Restaurer la valeur par défaut du registre (souvent 850 ou 437).

### ENV-006 : Configuration Git
- **Description**: Définit les variables d'environnement Git pour le support Unicode.
- **Impact**: `git status` et `git log` afficheront correctement les accents.
- **Rollback**: Supprimer les variables `GIT_CONFIG_*`.

### ENV-007 : Persistance
- **Description**: Écriture directe dans le registre Windows (HKLM/HKCU).
- **Impact**: Les configurations survivent au redémarrage.
- **Rollback**: Restaurer depuis le backup JSON généré par `Set-StandardizedEnvironment.ps1`.

### ENV-008 : Hiérarchie
- **Description**: Application séquentielle Machine -> User -> Processus.
- **Impact**: Garantit que les politiques système prévalent, suivies des préférences utilisateur.
- **Rollback**: N/A (Logique procédurale).

## 4. Procédures de Validation et Rollback

### Validation
Exécuter le script de test :
```powershell
.\scripts\encoding\Test-StandardizedEnvironment.ps1 -Detailed
```
Critère de succès : Taux de réussite > 95%.

### Rollback
En cas de problème majeur, utiliser le fichier de backup généré lors de l'application :
1. Localiser le dernier backup dans `backups\environment-backups\`.
2. Restaurer manuellement les valeurs ou utiliser un script de restauration (à développer si nécessaire, format JSON standard).