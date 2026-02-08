# Changelog des Modes N5

Ce document recense les modifications apportées aux configurations des modes N5.

## 15/05/2025 - Harmonisation des modes simple/complex avec les modes N5

### Modifications apportées

#### Intégration des directives de structuration dans les modes simple et complex

Les fichiers suivants ont été modifiés:
- `roo-modes/configs/standard-modes.json`
- `roo-modes/n5/deploy-n5-micro-mini-modes.ps1` (renommé fonctionnellement pour inclure les modes simple/complex)

#### Principales fonctionnalités ajoutées aux modes simple/complex:

1. **Titrage numéroté arborescent**
   - Système de numérotation hiérarchique pour structurer les tâches
   - Format standardisé: `[Niveau.Sous-niveau.Sous-sous-niveau]`
   - Limitation de profondeur adaptée au niveau de complexité (3 niveaux max pour SIMPLE, 4 niveaux max pour COMPLEX)

2. **Utilisation de l'éventail des complexités**
   - Évaluation systématique du niveau de complexité approprié pour chaque tâche
   - Critères d'escalade/désescalade spécifiques à chaque type de mode
   - Mécanismes de transition entre niveaux de complexité

3. **Gestion des fichiers volumineux**
   - Utilisation d'extraits ciblés via le MCP quickfiles pour les fichiers > 1000 lignes
   - Stratégies d'analyse efficace avec search_files et expressions régulières
   - Division des fichiers volumineux en sections gérables

4. **Mécanismes d'escalade et désescalade formalisés**
   - Critères spécifiques pour évaluer la nécessité d'escalade/désescalade
   - Formats standardisés pour signaler les transitions

5. **Gestion des tokens**
   - Seuils d'avertissement et critiques spécifiques à chaque niveau
   - Procédures d'escalade automatique en cas de dépassement des seuils

6. **Priorité aux MCPs**
   - Utilisation prioritaire des MCPs pour toutes les opérations disponibles
   - Préférence pour les opérations groupées via MCP
   - Exemples d'opérations à privilégier pour chaque type de mode

7. **Pratiques de nettoyage et versionnement**
   - Commits atomiques avec messages descriptifs standardisés
   - Nettoyage systématique du code après chaque implémentation
   - Vérification de la cohérence du code après chaque modification

8. **Verrouillage de famille**
   - Restrictions de transition entre modes
   - Limitation aux modes de la même famille (simple ou complex)

### Déploiement

Le script de déploiement a été mis à jour pour inclure les modes simple et complex:
- `roo-modes/n5/deploy-n5-micro-mini-modes.ps1`

#### Utilisation du script:

```powershell
# Déploiement global (pour toutes les instances de VS Code)
.\deploy-n5-micro-mini-modes.ps1 -DeploymentType global

# Déploiement local (uniquement pour le projet courant)
.\deploy-n5-micro-mini-modes.ps1 -DeploymentType local

# Forcer le remplacement des fichiers existants
.\deploy-n5-micro-mini-modes.ps1 -Force
```

## 15/05/2025 - Intégration des directives de structuration dans les modes micro et mini

### Modifications apportées

#### Ajout de directives de structuration dans les modes micro et mini

Les fichiers suivants ont été modifiés:
- `roo-modes/n5/configs/micro-modes.json`
- `roo-modes/n5/configs/mini-modes.json`

#### Principales fonctionnalités ajoutées:

1. **Titrage numéroté arborescent**
   - Système de numérotation hiérarchique pour structurer les tâches
   - Format standardisé: `[Niveau.Sous-niveau.Sous-sous-niveau]`
   - Limitation de profondeur adaptée au niveau de complexité (2 niveaux max pour MICRO, 3 niveaux max pour MINI)

2. **Utilisation de l'éventail des complexités**
   - Évaluation systématique du niveau de complexité approprié pour chaque tâche
   - Critères d'escalade spécifiques à chaque type de mode
   - Escalade progressive: MICRO → MINI → MEDIUM → LARGE → ORACLE

3. **Gestion des fichiers volumineux**
   - Utilisation d'extraits ciblés via le MCP quickfiles pour les fichiers > 1000 lignes
   - Stratégies d'analyse efficace avec search_files et expressions régulières
   - Division des fichiers volumineux en sections gérables

4. **Mécanisme d'escalade formalisé**
   - Critères spécifiques pour évaluer la nécessité d'escalade
   - Formats standardisés pour l'escalade:
     - Escalade par branchement (PRIORITÉ HAUTE)
     - Escalade par changement de mode (PRIORITÉ MOYENNE)
     - Escalade par terminaison (PRIORITÉ BASSE)

5. **Gestion des tokens**
   - Seuils d'avertissement et critiques spécifiques à chaque niveau
   - Procédures d'escalade automatique en cas de dépassement des seuils

6. **Priorité aux MCPs**
   - Utilisation prioritaire des MCPs pour toutes les opérations disponibles
   - Préférence pour les opérations groupées via MCP
   - Exemples d'opérations à privilégier pour chaque type de mode

7. **Pratiques de nettoyage et versionnement**
   - Commits atomiques avec messages descriptifs standardisés
   - Nettoyage systématique du code après chaque implémentation
   - Vérification de la cohérence du code après chaque modification

8. **Verrouillage de famille**
   - Restrictions de transition entre modes
   - Limitation aux modes de la même famille (n5)

### Déploiement

Un script de déploiement a été créé pour faciliter l'installation des modes micro et mini:
- `roo-modes/n5/deploy-n5-micro-mini-modes.ps1`

#### Utilisation du script:

```powershell
# Déploiement global (pour toutes les instances de VS Code)
.\deploy-n5-micro-mini-modes.ps1 -DeploymentType global

# Déploiement local (uniquement pour le projet courant)
.\deploy-n5-micro-mini-modes.ps1 -DeploymentType local

# Forcer le remplacement des fichiers existants
.\deploy-n5-micro-mini-modes.ps1 -Force
```

### Prochaines étapes

- Adaptation des directives de structuration pour les modes medium et large
- Harmonisation des mécanismes d'escalade entre tous les niveaux
- Optimisation des seuils de tokens pour chaque niveau de complexité
- Renommage du script de déploiement pour refléter l'inclusion de tous les modes