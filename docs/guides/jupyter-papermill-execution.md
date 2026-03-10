# Exécution de Notebooks Jupyter via Papermill

**Version** : 1.0.0
**Date** : 2026-03-10
**Issue** : #600 - [STUDY] Exécution Jupyter dans Claude Code - Options

---

## 🎯 Vue d'ensemble

Ce guide présente l'**Option 2** (script externe) pour exécuter des notebooks Jupyter dans Claude Code. Cette approche est **légère, paramétrable et ne nécessite pas le MCP jupyter-mcp** (152 outils).

### ✅ Avantages

- **Léger** : Un seul script PowerShell + Python/papermill
- **Paramétrable** : Supporte les paramètres papermill injectés
- **Rapport HTML automatique** : nbconvert intégré
- **Contrôle total** : Gestion des erreurs, codes de sortie, timings
- **CI/CD friendly** : Sortie structurée, codes de sortie propres

### ⚠️ Prérequis

- Python 3.x installé
- `papermill` installé : `python -m pip install papermill`
- `nbconvert` (inclus avec jupyter) pour les rapports HTML

---

## 🚀 Démarrage Rapide

### Installation des prérequis

```powershell
# Installer papermill
python -m pip install papermill

# Vérifier l'installation
python -m pip show papermill
```

### Exécution basique

```powershell
# Exécuter un notebook (sortie auto-générée)
.\scripts\jupyter\run-notebook.ps1 -Notebook "tests/notebook-test.ipynb"

# Spécifier le fichier de sortie
.\scripts\jupyter\run-notebook.ps1 -Notebook "input.ipynb" -Output "output.ipynb"

# Sans rapport HTML
.\scripts\jupyter\run-notebook.ps1 -Notebook "input.ipynb" -NoReport
```

---

## 📖 Paramètres

| Paramètre | Type | Obligatoire | Description |
|-----------|------|-------------|-------------|
| `-Notebook` | String | **Oui** | Chemin vers le notebook `.ipynb` à exécuter |
| `-Output` | String | Non | Chemin de sortie (défaut : `{input}-output.ipynb`) |
| `-Parameters` | Hashtable | Non | Paramètres à injecter dans le notebook |
| `-NoReport` | Switch | Non | Désactive la génération du rapport HTML |

---

## 🔧 Exemples d'Utilisation

### Exemple 1 : Notebook simple

```powershell
# Exécution avec sortie par défaut
.\scripts\jupyter\run-notebook.ps1 -Notebook "tests/test-analysis.ipynb"

# Résultat attendu :
# Exécution du notebook: tests/test-analysis.ipynb
# Sortie: tests/test-analysis-output.ipynb
# ✅ Notebook exécuté avec succès en 3.70 secondes
# ✅ Rapport HTML généré: tests/test-analysis-output.html
```

### Exemple 2 : Avec paramètres

```powershell
# Injecter des paramètres dans le notebook
.\scripts\jupyter\run-notebook.ps1 `
    -Notebook "analysis-template.ipynb" `
    -Parameters @{
        "data_file" = "data/dataset-2026.csv"
        "threshold" = 0.85
        "output_format" = "png"
    }

# Dans le notebook, les paramètres sont accessibles via :
# data = parameters["data_file"]
# threshold = parameters["threshold"]
```

### Exemple 3 : Pipeline de notebooks

```powershell
# Exécuter plusieurs notebooks séquentiellement
$notebooks = @(
    "step1-data-prep.ipynb",
    "step2-analysis.ipynb",
    "step3-report.ipynb"
)

foreach ($nb in $notebooks) {
    Write-Host "=== Exécution: $nb ==="
    .\scripts\jupyter\run-notebook.ps1 -Notebook $nb

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Échec sur $nb, arrêt du pipeline"
        exit $LASTEXITCODE
    }
}

Write-Host "✅ Pipeline terminé avec succès"
```

### Exemple 4 : Intégration CI/CD

```powershell
# Dans un script de build/CI
$ErrorActionPreference = "Stop"

# Exécuter les tests notebooks
$testResult = .\scripts\jupyter\run-notebook.ps1 `
    -Notebook "tests/validation.ipynb" `
    -NoReport

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Tests notebooks validés"
    exit 0
} else {
    Write-Error "❌ Tests notebooks échoués"
    exit 1
}
```

---

## 📊 Performance

Les timings observés sur myia-po-2026 :

| Notebook | Cellules | Durée | Observations |
|----------|---------|-------|--------------|
| test-simple | 5 | 3.7s | Import pandas, calcul simple |
| test-complex | 15 | 6.7s | Graphiques,数据分析 |
| template | 8 | 4.2s | Avec paramètres injectés |

**Note** : Le temps d'exécution dépend de la complexité du notebook et des ressources système.

---

## 🚨 Gestion des Erreurs

### Codes de sortie

| Code | Signification |
|------|---------------|
| `0` | Succès |
| `1` | papermill non installé |
| `>0` | Erreur lors de l'exécution du notebook |

### Erreurs courantes

#### **papermill non installé**
```
❌ papermill n'est pas installé. Installez-le avec: python -m pip install papermill
```
**Solution** : `python -m pip install papermill`

#### **Notebook non trouvé**
```
❌ Erreur lors de l'exécution du notebook (code: 1)
[Errno 2] No such file or directory: 'input.ipynb'
```
**Solution** : Vérifier le chemin vers le notebook

#### **Erreur dans le notebook**
```
❌ Erreur lors de l'exécution du notebook (code: 1)
CellExecutionError: An error occurred while executing the cell
```
**Solution** : Vérifier le notebook dans Jupyter pour identifier la cellule problématique

---

## 🎯 Cas d'Usage

### 1. **Validation de notebooks après création**

```powershell
# Après avoir créé/édité un notebook
.\scripts\jupyter\run-notebook.ps1 -Notebook "docs/notebooks/new-analysis.ipynb"
```

### 2. **Exécution de tests dans des notebooks**

```powershell
# Tests automatiques avec notebooks
.\scripts\jupyter\run-notebook.ps1 `
    -Notebook "tests/unit-tests.ipynb" `
    -NoReport
```

### 3. **Génération de rapports automatisés**

```powershell
# Template de rapport avec paramètres
.\scripts\jupyter\run-notebook.ps1 `
    -Notebook "templates/monthly-report.ipynb" `
    -Parameters @{
        "month" = (Get-Date).Month
        "year" = (Get-Date).Year
        "include_charts" = $true
    }
```

### 4. **Intégration CI/CD**

```powershell
# Dans GitHub Actions, Azure Pipelines, etc.
- name: Execute Jupyter Notebooks
  run: |
    .\scripts\jupyter\run-notebook.ps1 -Notebook "tests/validation.ipynb"
```

---

## 🔗 Comparaison des Options

| Option | Avantages | Inconvénients | Usage recommandé |
|--------|-----------|---------------|------------------|
| **Option 1: jupyter-mcp direct** | Full Jupyter API, interactif | 152 outils, serveur requis | Développement interactif |
| **Option 2: Script papermill** ✅ | Léger, paramétrable, HTML auto | Requiert Python+pip | **Batch, CI/CD, Automation** |
| **Option 3: sk-agent** | Infrastructure existante | Lecture seule | Non adapté pour exécution |
| **Option 4: DotNet.Interactive** | Intégration .NET | Stack différent | Non pertinent |

---

## 📚 Références

- **Script** : `scripts/jupyter/run-notebook.ps1`
- **Papermill** : https://github.com/nteract/papermill
- **nbconvert** : https://nbconvert.readthedocs.io/
- **Issue** : #600 - [STUDY] Exécution Jupyter dans Claude Code

---

**Ce script est la solution recommandée pour l'exécution batch de notebooks Jupyter dans Claude Code.** 🚀
