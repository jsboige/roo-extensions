Cette section détaille le sort recommandé pour chaque script ou groupe de scripts identifié en dehors du répertoire `scripts` central.

| Chemin du Fichier | Analyse et Rôle | Décision | Destination / Justification |
|---|---|---|---|
| **À la racine** | | | |
| `deploy-mcp-environment.ps1` | Point d'entrée pour l'installation de l'environnement MCP. | **DÉPLACER** | `scripts/mcp/deploy-environment.ps1` |
| `diag_mcps.ps1` | Script de diagnostic global pour les MCPs. | **DÉPLACER** | `scripts/diagnostic/diag-mcps-global.ps1` |
| `install_all_deps.ps1` | Script d'installation des dépendances globales. | **DÉPLACER** | `scripts/install/install-dependencies.ps1` |
| **`demo-roo-code/`** | | | |
| `*.ps1`, `*.js` | Tous les scripts dans ce répertoire sont liés à des démos spécifiques. | **CONSERVER** | Ces scripts sont spécifiques au contexte des démos et ne sont pas des outils génériques. |
| **`docs/guides/.../scripts/`** | | | |
| `*.ps1` | Copie statique des outils d'encodage pour un guide. | **SUPPRIMER** | Redondance complète avec `scripts/encoding`. Le guide doit pointer vers l'outillage central. |
| **`mcps/`** | | | |
| `mcps/monitoring/*.ps1` | Script de monitoring des serveurs MCP. | **DÉPLACER** | `scripts/monitoring/monitor-mcp-servers.ps1` |
| `mcps/utils/*.ps1` | Utilitaires pour convertir des configurations MCP. | **DÉPLACER** | `scripts/mcp/utils/` |
| `mcps/*.ps1` | Scripts de gestion de haut niveau pour les MCPs. | **DÉPLACER** | `scripts/mcp/` (Ex: `gestion-mcp.ps1`) |
| `mcps/**/jest.config.js` | Fichiers de configuration pour les tests Jest. | **CONSERVER** | Spécifique à la structure des tests de chaque serveur MCP. |
| `mcps/**/dist/**/*.js` | Code JavaScript transpilé. | **IGNORER** | Fichiers générés par un processus de build. Ne doit pas être versionné ou déplacé manuellement. |
| `mcps/internal/scripts/**/*.js`| Scripts d'aide pour les MCPs (starters, config). | **CONSERVER** | Ces scripts sont étroitement liés à l'écosystème Node.js des MCPs et ne sont pas des outils PowerShell génériques. |
| `mcps/internal-backup/...` | Copie complète de `mcps/internal`, incluant de nombreux scripts de démarrage. | **SUPPRIMER** | Redondance complète et anti-pratique (sauvegarde versionnée). Le répertoire entier doit être supprimé. |
| `mcps/scripts/*.ps1` | Scripts de démarrage pour les serveurs Jupyter. | **DÉPLACER** | Logique de démarrage de serveur MCP, à centraliser dans `scripts/mcp/`. |
| `mcps/internal/.../run_notebook.ps1` | Utilitaire pour exécuter un notebook Jupyter via `nbconvert`. | **CONSERVER (dans sous-module)** | Script spécifique au serveur MCP Jupyter. Doit être commité dans le dépôt du sous-module `mcps/internal`. |
| **`roo-code-customization/`** | | | |
| `deploy-fix.ps1` | Script de déploiement pour un correctif spécifique. | **ARCHIVER** | Semble être un script à usage unique. À déplacer vers `scripts/archive/`. |
| `scripts/audit-roo-tasks.ps1` | Outil d'audit des tâches Roo. | **DÉPLACER** | `scripts/audit/audit-roo-tasks.ps1` |
| **`roo-config/`**| | | |
| `daily-monitoring.ps1` | Script de monitoring journalier (plus récent que celui dans `scripts/`). | **DÉPLACER** | `scripts/monitoring/daily-monitoring.ps1` (et supprimer l'ancienne version). |
| `maintenance-routine.ps1` | Routine de maintenance générale. | **DÉPLACER** | `scripts/maintenance/` |
| `mcp-diagnostic-repair.ps1` | Diagnostic et réparation des MCPs. | **DÉPLACER** | `scripts/diagnostic/` (et fusionner/remplacer la version existante). |
| `scheduler/**/*.ps1` | Ensemble de scripts formant un planificateur de tâches. | **CONSERVER** | Logique applicative complexe et spécifique, pas de l'outillage générique. À garder groupé. |
| `scripts/encoding/*.ps1` | Copie des outils d'encodage. | **SUPPRIMER** | Redondance complète avec `scripts/encoding`. Le répertoire entier doit être supprimé. |
| **`roo-modes/`** | | | |
| `custom/scripts/*.ps1`| Scripts de déploiement pour des modes custom. | **CONSERVER** | Lié à la structure spécifique des modes "custom". Pas un outil générique. |
| `n5/scripts/*.ps1`| Scripts de déploiement pour la famille de modes "n5". | **CONSERVER** | Logique de déploiement trop spécifique à l'architecture "n5". |
| `scripts/*.ps1`| Scripts de déploiement génériques pour les modes. | **SUPPRIMER** | Redondance avec `scripts/deployment`. La logique doit être centralisée là-bas. |
| **`tests/`** | | | |
| `*.ps1` | Scripts de test PowerShell. | **CONSERVER** | Ces scripts sont faits pour lancer des tests et doivent rester co-localisés avec le code de test. |
| **`scripts/` (Analyse interne)** | | | |
| `scripts/deployment/*.ps1` | Scripts de déploiement des modes. Prolifération de versions. | **FUSIONNER** | **Analyse approfondie :** La lecture de `deploy-modes.ps1`, `deploy-modes-simple.ps1`, `deploy-modes-enhanced.ps1` et `deploy-profile-modes.ps1` révèle une duplication massive de la logique de copie et de gestion des chemins, mais encapsulant trois fonctionnalités métier distinctes :
1.  **Déploiement simple :** Copie directe d'un fichier de configuration.
2.  **Enrichissement :** Corrige l'encodage et ajoute dynamiquement des propriétés (`family`, `model`) au JSON avant déploiement.
3.  **Génération par profil :** Crée dynamiquement un fichier de configuration en appliquant un "profil de modèle" sur un template de modes.

**Plan d'action :** Consolider toute la logique dans un script `deploy-modes.ps1` unique et hautement paramétrable. Ce script intelligent gérerait les trois cas d'usage via des paramètres exclusifs (`-EnrichSimpleComplex`, `-ProfileName`). Cela permettra de supprimer une quinzaine de scripts redondants, de centraliser la logique et de clarifier le processus de déploiement. |
| `scripts/diagnostic/*.ps1` | Scripts de diagnostic pour l'encodage et les modes. | **FUSIONNER et SPÉCIALISER** | **Analyse approfondie :** L'analyse complète du répertoire, incluant `mcp-diagnostic-repair.ps1` et `verify-deployed-modes.ps1`, affine la stratégie. Il existe deux types de diagnostics : techniques (encodage, JSON) et métier (règles internes à une configuration).
- **Redondance :** `verify-deployed-modes.ps1` est entièrement redondant avec `check-deployed-encoding.ps1`. Les fonctions de diagnostic technique (BOM, validité JSON) sont dupliquées dans presque tous les scripts.
- **Spécialisation :** `check-deployed-encoding.ps1` et `mcp-diagnostic-repair.ps1` contiennent des logiques de validation métier précieuses (v-layouts, chemins des serveurs MCP).

**Plan d'action :**
1.  **Créer `run-diagnostic.ps1` :** Fusionner les capacités de diagnostic *technique* de tous les scripts (`encoding-diagnostic.ps1`, `diagnostic-rapide-encodage.ps1`, `mcp-diagnostic-repair.ps1`) en un seul outil puissant capable de scanner en masse ou de réparer un fichier unique.
2.  **Créer un répertoire `scripts/validation/` :** Pour héberger les diagnostics *métier*.
3.  **Déplacer et renommer** `check-deployed-encoding.ps1` en `scripts/validation/validate-deployed-modes.ps1`.
4.  **Déplacer, renommer et simplifier** `mcp-diagnostic-repair.ps1` en `scripts/validation/validate-mcp-config.ps1`, en ne conservant que sa logique de vérification des chemins MCP.
5.  **Supprimer** `verify-deployed-modes.ps1` et les scripts originaux après fusion. |
| `scripts/encoding/*.ps1` | Cœur des outils de correction d'encodage. Très nombreuses versions. | **RATIONALISER et FUSIONNER** | **Analyse approfondie :** L'analyse révèle deux familles de scripts distinctes :
1.  **Configuration de l'environnement :** Ces scripts modifient l'environnement local (PowerShell, Git, VSCode) pour prévenir les problèmes. Le script `setup-encoding-workflow.ps1` est l'outil le plus complet, rendant `fix-encoding.ps1` (qui ne configure que PowerShell) et les utilitaires `backup/restore-profile.ps1` largement redondants.
2.  **Correction de fichiers :** Ces scripts (`-regex`, `-advanced`, `-ascii`, etc.) modifient des fichiers de données existants. Ils utilisent différentes stratégies (remplacement de motifs, translitération ASCII).

**Plan d'action :**
1.  **Créer `scripts/setup/` :** Déplacer `setup-encoding-workflow.ps1` vers ce nouveau répertoire et en faire l'unique point d'entrée pour la configuration de l'environnement. Intégrer la logique de sauvegarde/restauration de profil comme une fonctionnalité interne. Supprimer les scripts `fix-encoding.ps1`, `backup-profile.ps1`, et `restore-profile.ps1`.
2.  **Créer `fix-file-encoding.ps1` :** Un script unique qui restera dans `scripts/encoding/` et remplacera toutes les autres variantes. Il offrira différentes stratégies via un paramètre `-Strategy` (`RestoreUtf8`, `ConvertToAscii`).
3.  **Supprimer** toutes les autres variantes de `fix-encoding-*.ps1` ainsi que les scripts de validation redondants (`validate-deployment-*.ps1`). |
| `scripts/maintenance/*.ps1` | Scripts de maintenance, nettoyage et migration. Beaucoup sont à usage unique. | **ARCHIVER / FUSIONNER** | Archiver les scripts de migration (`organize-repo`, `consolidate-configurations`). Fusionner `daily-monitoring` et `maintenance-routine`. |
| `scripts/demo-scripts/*.ps1`| Scripts pour la préparation des environnements de démonstration. | **CONSERVER** | Logique spécifique aux démos, non redondante. À garder groupé. |