# Scripts de Diagnostic

Ce dossier contient des outils pour effectuer des diagnostics techniques sur l'environnement et la configuration de l'application Roo.

## Contexte de la Refactorisation

Auparavant, ce dossier contenait un mélange de scripts de diagnostic technique et de validation fonctionnelle. Pour clarifier les responsabilités, les scripts ont été réorganisés :

-   Les outils de **diagnostic technique** (vérification de l'environnement, des chemins, des dépendances, etc.) ont été consolidés dans `run-diagnostic.ps1`.
-   Les scripts de **validation métier** (ex: "est-ce que la configuration des Modes est logique ?", "est-ce que le déploiement a réussi fonctionnellement ?") ont été déplacés dans le nouveau répertoire `../validation`.

## Script Principal

### `run-diagnostic.ps1`

C'est le point d'entrée unique pour le diagnostic technique. Il exécute une série de vérifications pour s'assurer que l'environnement est sain et que les configurations sont structurellement correctes.

#### Fonctionnalités

*   **Vérifications Multiples :** Exécute une suite de tests, incluant la vérification des chemins d'accès, la validité de l'encodage des fichiers de configuration, et la structure des fichiers JSON.
*   **Rapports Clairs :** Génère un rapport indiquant les succès et les échecs, aidant l'utilisateur à identifier rapidement les problèmes.
*   **Extensibilité :** Conçu pour pouvoir ajouter facilement de nouvelles routines de diagnostic.

#### Utilisation

Pour lancer une analyse complète de l'environnement :

```powershell
.\run-diagnostic.ps1
```

Pour cibler le diagnostic sur un aspect spécifique (si le script le supporte via des paramètres) :
```powershell
.\run-diagnostic.ps1 -Check "Encoding"
```

## Scanners de sessions Claude Code

### `scan-duplicate-tool-use.py`

Détecte la signature du bug harness #3276 (même `tool_use` émis puis exécuté deux fois — fork en deux nœuds transcript distincts) qui produit des effets de bord dupliqués (ex. 2 issues GitHub créées pour 1 seule intendue : CoursIA #13089/#13090, récidive #13108/#13109).

*   **EMIT_FORK :** le même id de bloc `tool_use` émis sur ≥ 2 nœuds à uuids DISTINCTS (le fork transcript ; lien parent-enfant rapporté quand présent).
*   **EXEC_DOUBLE :** ≥ 2 `tool_result` à uuids distincts pour un même id `tool_use`, avec contenu DIFFÉRENT — vraie double exécution.
*   **EXEC_COPY** (`--strict` uniquement) : ≥ 2 `tool_result` à uuids distincts au contenu identique — artefact de copie probable.

Ground truth structurel (vérifié sur transcripts réels, 2026-08-26 — ne pas régresser vers ces faux positifs) :

*   *Un nœud par content block* : une réponse assistant API est décomposée en un nœud par bloc (thinking → text → tool_use…), tous partageant le même `message.id`. « Deux nœuds même `message.id` » est la **norme**, pas la signature du bug.
*   *Ré-écriture au resume/fork* : reprendre une session ré-appende verbatim des plages antérieures — mêmes nœuds, **mêmes uuids**. Le scanner déduplique par uuid (comptés dans `rewritten nodes`) : ces copies ne sont PAS des ré-exécutions.

Le correctif racine est côté runtime Claude Code — ce scanner est l'instrumentation de détection, pas le fix. Tant que #3276 est ouverte, toute lane publiant des issues depuis un harnais Claude Code doit post-verify chaque `gh issue create` (re-lister le titre ~15 s après, supprimer la copie byte-identique vierge).

```powershell
# Scan complet des sessions locales (~/.claude/projects)
python scripts/diagnostic/scan-duplicate-tool-use.py

# Une session précise (ex. vérifier un transcript suspect)
python scripts/diagnostic/scan-duplicate-tool-use.py --file "<chemin>/session.jsonl"

# Sortie machine-readable (CI, scheduler) — exit 0 propre / 2 findings
python scripts/diagnostic/scan-duplicate-tool-use.py --json

# Validation autonome (fixture synthétique signature #3276)
python scripts/diagnostic/scan-duplicate-tool-use.py --selftest
```

### `../transcript/Find-DuplicateToolUse.ps1` (PR #3498)

Variante PowerShell du même détecteur, ajoutée post-#3278. Mêmes signatures (`EMIT_FORK` / `EXEC_DOUBLE` / `EXEC_COPY`) sur un transcript unique, avec sortie `Object` / `Json` / `Summary` — utile quand le harnais cible est Windows natif (`powershell`) et que le Python n'est pas disponible. Tests Pester dans `scripts/testing/unit/Find-DuplicateToolUse.Tests.ps1` (12/12 verts).

```powershell
# Walk tous les transcripts sous ~/.claude/projects
Get-ChildItem ~/.claude/projects/*/*.jsonl | ForEach-Object {
    powershell -ExecutionPolicy Bypass -File scripts/transcript/Find-DuplicateToolUse.ps1 `
        -Path $_.FullName -OutputFormat Summary
}
```

Les deux outils sont **complémentaires**, pas redondants : le scanner Python fait le balayage de masse (exit codes CI-friendly), le script PowerShell est l'analyseur forensic d'un transcript précis (sortie structurée pour triage).