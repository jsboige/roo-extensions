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

### `audit-stale-mcp-disables.py`

Audit **lecture seule** des désactivations MCP fantômes de `~/.claude.json` (#4195, volet 3). L'emplacement `projects[<workspace>].disabledMcpServers` est indexé par le chemin absolu du workspace : après un déménagement (`C:\dev`→`D:\Dev`), la désactivation ne s'applique plus et le MCP est **réactivé silencieusement** (incident po-2024 09/10 : fenêtre OAuth ouverte sans demande, consigne user « svp ne faites pas ça »). Le résidu est invisible de l'intérieur d'une session.

- **STALE-GHOST** — clé `projects[chemin]` dont le chemin n'existe plus ET qui porte des `disabledMcpServers` (exit 2).
- **ACTIVE** — clé de chemin existant portant des désactivations (état légitime, informatif — c'est le contrôle gratuit d'ouverture de session, volet 1 de #4195).

```powershell
# Audit de ~/.claude.json
python scripts/diagnostic/audit-stale-mcp-disables.py

# Sortie machine-readable / fixture synthétique — exit 0 propre / 2 findings / 1 erreur
python scripts/diagnostic/audit-stale-mcp-disables.py --json
python scripts/diagnostic/audit-stale-mcp-disables.py --selftest
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

### `scan-approval-waits.py`

Instrument **côté transcript** des attentes d'approbation malgré bypass (#4214, mandat user 15/10). Apparie chaque `tool_use` Bash/PowerShell avec son `tool_result` dans `~/.claude/projects/**/*.jsonl` : entre les deux il n'y a **aucune génération modèle** (l'appel API suivant n'a lieu qu'après retour du résultat), donc l'écart = attente d'approbation + exécution + overhead client. Complément de `tool-gap.py` côté hub (claudish#474) : le hub voit l'écart mais pas la ligne de prompt ; le transcript porte la commande et sa forme.

- **Formes classifiées :** `composed-cd` (composé commençant par `cd` — forme dominante flotte, médiane 121 s des deux côtés), `composed`, `rm-rf`, `wsl`, `elevated`, `multiline`, `plain`.
- **Réduction de secrets (volet 1b + follow-up c.27) :** tout extrait de commande passe un réducteur avant sortie — `sk-`, `ghp_`/`gho_`/`ghu_`/`ghs_`, `Bearer`, `x-proxy-key`/`x-api-key`, familles d'assignation `*api_key*`/`*token*`/`*secret*`/`*password*` **insensibles à la casse** y compris formes drapeau (`--token=`), et **crédentials d'URL** (`scheme://user:pass@host` → `scheme://[REDACTED]@host`) : le **nom** reste, la **valeur** devient `[REDACTED]`, valeur quotée masquée entière (`"k1 k2"`) — la réduction précède la troncature pour qu'un extrait coupé ne fuie jamais une valeur partielle. Sortie collable sur dashboard/issue/PR par construction. Faux positifs possibles (ex. `--max-tokens=4096` masqué) : coût d'affichage seulement, assumé.
- **Déduplication resume :** mêmes uuids re-appendés = copies, sautées (comptées `rewritten nodes`) — même ground truth que scan-duplicate-tool-use.py.
- **Adjudication `--hook-log` (volet 3b) :** joint chaque finding au journal du hook `log-tool-start.js` (clé `(session_id, tool, commande brute)` + fenêtre) → `pre_exec_s` (approbation + overhead) / `exec_s` (exécution), étiquette `approval|exec`. Contrôle positif requis avant toute conclusion (dispatch c.28 : une commande délibérément soumise à approbation doit montrer `pre_exec_s` > 0).
- **Limite explicite :** l'écart ne départage PAS approbation vs exécution sans `--hook-log` (un `npx vitest run` de 320 s est une exécution) — le corpus headless (volet 2 de #4214) borne le plateau, la jointure tranche.

```powershell
# Fenêtre 24 h, seuil 120 s, top 30 par écart décroissant
python scripts/diagnostic/scan-approval-waits.py --min-wait 120 --since-hours 24 --top 30

# Sortie machine-readable — exit 0 propre / 2 findings
python scripts/diagnostic/scan-approval-waits.py --json

# Validation autonome (fixtures synthétiques)
python scripts/diagnostic/scan-approval-waits.py --selftest
```

## Compteurs mémoire

### `log-commit-charge.ps1` (#2992)

Logger read-only du commit charge Windows (`CommittedBytes` / `CommitLimit`), écrit pour mesurer le **pic de commit pendant le chargement d'un modèle vLLM** — jamais mesuré car rien sur l'hôte ne logge ces compteurs en continu. Une ligne JSON par échantillon (`samples.jsonl`) + un `_summary.json` écrit en sortie **y compris sur Ctrl+C** (bloc `finally`), avec pour chaque échantillon : commit, limite, `FreeVirtualMemory` (KB), pagefile alloué, pools, somme du commit privé des processus, et le solde **non attribué** (commit − processus − pools — page tables, sections, driver-locked).

- **Locale-proof par construction :** lit uniquement des classes CIM aux noms de propriétés anglais sur toute locale (`Win32_PerfFormattedData_PerfOS_Memory`, `Win32_OperatingSystem`, `Win32_PageFileUsage`). L'original archivé (`_archive/cleanup-3323-2026-08-31/`) lisait les compteurs perf par nom anglais via `Get-Counter` → silencieusement vide sur locale FR (défaut connu #2992). `Get-Counter` est ici interdit par les tests.
- **Auto-validation :** chaque échantillon porte les deux sources de l'identité `FreeVirtualMemory ≈ CommitLimit − CommittedBytes` (vérifiée sur machine FR : écart ~0,14 % de la limite) — un échantillon incohérent se voit sans instrument externe.

```powershell
# Runbook #2992 (avant le prochain restart vLLM sur ai-01) :
powershell -ExecutionPolicy Bypass -File scripts\diagnostic\log-commit-charge.ps1 `
    -OutputDir C:\temp\memdiag\peak -IntervalSec 10
# puis, dans un autre terminal : docker start myia_vllm-...
# stop par Ctrl+C une fois le modèle chargé ; poster samples.jsonl sur #2992.
```

Tests Pester : `scripts/testing/unit/log-commit-charge.Tests.ps1` (13 tests — contrat statique toutes plateformes + micro-run live Windows avec l'identité sémantique à 2 % de tolérance).
