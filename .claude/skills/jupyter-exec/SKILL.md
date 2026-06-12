---
name: jupyter-exec
description: Exécute un notebook Jupyter en CLI via papermill (sans serveur Jupyter ni MCP lourd) et génère un rapport HTML. Utilise ce skill quand un agent doit lancer un notebook .ipynb paramétrable, valider un notebook généré programmatiquement, ou produire un rapport reproductible en CI. Phrase déclencheur : "exécute le notebook", "lance le notebook", "papermill", "run notebook".
triggers:
  keywords:
    - "exécute le notebook"
    - "lance le notebook"
    - "run notebook"
    - "papermill"
    - "exécuter un ipynb"
    - "rapport notebook"
  exact:
    - "papermill"
    - "run-notebook"
    - "ipynb"
  patterns:
    - "(exécute|lance|run).{0,12}notebook"
    - "(notebook|ipynb).{0,12}(exécut|run|papermill)"
  priority: medium
metadata:
  author: "Roo Extensions Team"
  version: "1.0.0"
  compatibility:
    surfaces: ["claude-code", "claude.ai"]
    restrictions: "Requiert Python + papermill installés sur la machine (po-2023 : papermill 2.6.0 / Python 3.13.3 vérifié 2026-06-12)"
---

# Skill : Jupyter Exec (papermill CLI)

Exécuter un notebook Jupyter **sans serveur Jupyter ni MCP lourd**, via le script validé
[`scripts/jupyter/run-notebook.ps1`](../../../scripts/jupyter/run-notebook.ps1) qui enveloppe
`python -m papermill` + un rapport HTML `nbconvert`.

Issue source : **#600** ([STUDY] Exécution Jupyter dans Claude Code — Option 2 retenue).

---

## Quand utiliser

- Un agent a **généré** un notebook (`.ipynb`) et veut l'**exécuter** pour vérifier qu'il tourne.
- Exécution **paramétrable** d'un notebook (injection de variables via papermill `-p`).
- Produire un **rapport HTML reproductible** (CI/CD, pas d'interaction humaine).

## Quand NE PAS utiliser

| Besoin | Outil correct |
|--------|---------------|
| **Éditer** des cellules d'un notebook | Outil natif Claude Code `NotebookEdit` (pas ce skill) |
| Serveur Jupyter interactif, kernels persistants, 30+ outils MCP | `jupyter-papermill-mcp-server` (`mcps/internal/servers/jupyter-papermill-mcp-server/`) — désactivé pour Roo (#827, 152 outils) mais disponible si l'interactif est requis |
| Simple exécution Python sans format notebook | `Bash` / `PowerShell` direct |

> Ce skill **ne duplique pas** le MCP server : il documente le chemin **léger CLI** (Option 2 de #600),
> complémentaire au MCP server (Option 1, interactif).

---

## Invocation validée

```powershell
# Exécution simple (notebook embarquant déjà sa metadata kernelspec)
pwsh -File scripts/jupyter/run-notebook.ps1 -Notebook chemin/vers/notebook.ipynb

# Notebook SANS kernelspec (généré via nbformat.v4.new_notebook()) → -Kernel OBLIGATOIRE
pwsh -File scripts/jupyter/run-notebook.ps1 -Notebook chemin/vers/notebook.ipynb -Kernel python3

# Avec paramètres injectés + sortie explicite
pwsh -File scripts/jupyter/run-notebook.ps1 -Notebook in.ipynb -Output out.ipynb -Parameters @{ alpha = 0.5; label = "run1" }

# Sans rapport HTML
pwsh -File scripts/jupyter/run-notebook.ps1 -Notebook in.ipynb -NoReport
```

Le script écrit `<nom>-output.ipynb` + `<nom>-output.html` à côté du notebook (sauf `-Output`/`-NoReport`),
et retourne le chemin de sortie. Code retour ≠ 0 = échec d'exécution (propagé depuis papermill).

---

## Piège kernel (cause #1 d'échec)

Un notebook créé programmatiquement (`nbformat.v4.new_notebook()`) **n'embarque aucune metadata
kernelspec** → papermill échoue avec :

```
ValueError: No kernel name found in notebook and no override provided.
```

**Remède :** passer `-Kernel <nom>`. Lister les kernels disponibles :

```powershell
jupyter kernelspec list
```

Sur po-2023 (vérifié 2026-06-12) : `python3`, `.net-csharp`, `.net-fsharp`, `.net-powershell`,
`gametheory-wsl`, `lean4-wsl`, `mcp-jupyter-py310`. Le défaut sûr pour du Python générique = `python3`.

---

## Pré-requis

- Python 3 + `papermill` (le script vérifie `pip show papermill` et sort en erreur sinon :
  `python -m pip install papermill`).
- `nbconvert` pour le rapport HTML (déjà tiré par papermill en général).

---

## Documentation afférente

- Guide complet : [`docs/guides/jupyter-papermill-execution.md`](../../../docs/guides/jupyter-papermill-execution.md)
- Guide MCP interactif : [`docs/guides/guide-utilisation-mcp-jupyter.md`](../../../docs/guides/guide-utilisation-mcp-jupyter.md)
- Étude des options : Issue #600
