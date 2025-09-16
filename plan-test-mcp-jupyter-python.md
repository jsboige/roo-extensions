# Plan de test spécialisé - MCP Jupyter Python/Papermill

## Vue d'ensemble

### Objectifs du test
1. **Validation fonctionnelle** : Vérifier les 17+ outils MCP
2. **Test de robustesse** : Comparaison avec le serveur Node.js  
3. **Test d'intégration** : Compatibilité avec Roo/VSCode
4. **Test de performance** : Benchmarks Papermill vs Node.js
5. **Test de régression** : Parité fonctionnelle complète

### Stratégie hybride à tester
- **Papermill** : Exécution robuste de notebooks complets
- **jupyter_client** : Gestion interactive des kernels

## Phase 1 : Tests d'installation et configuration

### 1.1 Test environnement Conda
```bash
# Test création environnement
conda create -n mcp-jupyter python=3.12 -y
conda activate mcp-jupyter

# Validation environnement
python --version  # Attendu: 3.12.x
which python      # Attendu: chemin env mcp-jupyter
```

### 1.2 Test installation dépendances
```bash
cd mcps/internal/servers/jupyter-papermill-mcp-server
pip install -e .

# Test imports critiques
python -c "import papermill; print('Papermill OK')"
python -c "import mcp; print('MCP OK')" 
python -c "import jupyter_client; print('Jupyter Client OK')"
python -c "from papermill_mcp.main_fastmcp import mcp; print('FastMCP OK')"
```

### 1.3 Test script de démarrage
```bash
# Test démarrage serveur
python -m papermill_mcp.main_fastmcp &
sleep 5
ps aux | grep papermill_mcp  # Vérifier processus actif
kill %1  # Arrêter serveur test
```

**Critères de succès** :
- ✅ Environnement créé sans erreur
- ✅ Toutes les dépendances importables
- ✅ Serveur démarre et écoute

## Phase 2 : Tests unitaires des outils MCP

### 2.1 Outils Notebook (6 outils)

#### `read_notebook`
```python
# Test cas nominal
result = await tool_read_notebook({"path": "test_notebook.ipynb"})
assert "cells" in result
assert "metadata" in result

# Test fichier inexistant  
try:
    await tool_read_notebook({"path": "inexistant.ipynb"})
    assert False, "Devrait lever une exception"
except Exception as e:
    assert "not found" in str(e)
```

#### `write_notebook`
```python
# Test écriture notebook valide
notebook_content = {
    "cells": [],
    "metadata": {},
    "nbformat": 4,
    "nbformat_minor": 5
}
result = await tool_write_notebook({
    "path": "test_output.ipynb", 
    "content": notebook_content
})
assert result["status"] == "success"
```

#### `create_notebook`
```python
# Test création notebook vide
result = await tool_create_notebook({
    "path": "new_notebook.ipynb",
    "kernel": "python3"
})
assert result["created"] == True
assert os.path.exists("new_notebook.ipynb")
```

#### `add_cell`, `remove_cell`, `update_cell`
```python
# Test manipulation cellules
# Tests détaillés pour chaque opération CRUD
```

### 2.2 Outils Kernel (5 outils)

#### `list_kernels`
```python
# Test liste kernels
result = await tool_list_kernels({})
assert "available" in result
assert "active" in result
assert isinstance(result["available"], list)
```

#### `start_kernel`, `stop_kernel`, `restart_kernel`, `interrupt_kernel`
```python
# Test cycle de vie kernel complet
start_result = await tool_start_kernel({"kernel_name": "python3"})
kernel_id = start_result["kernel_id"]

# Test interruption
interrupt_result = await tool_interrupt_kernel({"kernel_id": kernel_id})
assert interrupt_result["status"] == "interrupted"

# Test redémarrage
restart_result = await tool_restart_kernel({"kernel_id": kernel_id})
assert restart_result["status"] == "restarted"

# Test arrêt
stop_result = await tool_stop_kernel({"kernel_id": kernel_id})
assert stop_result["status"] == "stopped"
```

### 2.3 Outils Exécution (3 outils)

#### `execute_cell` (via jupyter_client)
```python
# Test exécution cellule simple
result = await tool_execute_cell({
    "kernel_id": kernel_id,
    "code": "print('Hello World')"
})
assert "Hello World" in result["output"]

# Test exécution avec erreur
result = await tool_execute_cell({
    "kernel_id": kernel_id, 
    "code": "1/0"  # Division par zéro
})
assert "ZeroDivisionError" in result["error"]
```

#### `execute_notebook` (via Papermill) 
```python
# Test exécution notebook complet
result = await tool_execute_notebook({
    "path": "test_notebook.ipynb",
    "kernel_id": kernel_id
})
assert result["status"] == "completed"
assert "execution_time" in result
```

#### `execute_notebook_cell` (hybride)
```python
# Test exécution cellule spécifique dans notebook
result = await tool_execute_notebook_cell({
    "path": "test_notebook.ipynb",
    "cell_index": 0,
    "kernel_id": kernel_id  
})
assert result["executed"] == True
```

**Critères de succès** :
- ✅ 17+ outils passent tous leurs tests
- ✅ Gestion d'erreurs robuste
- ✅ Formats de retour conformes

## Phase 3 : Tests d'intégration

### 3.1 Test stratégie hybride

#### Test Papermill vs jupyter_client
```python
import time

# Test performance Papermill (notebooks complets)
start = time.time()
papermill_result = await execute_notebook_papermill("heavy_notebook.ipynb")
papermill_time = time.time() - start

# Test performance jupyter_client (cellules)  
start = time.time()
jupyter_result = await execute_cells_jupyter_client("heavy_notebook.ipynb")
jupyter_time = time.time() - start

# Comparaison
print(f"Papermill: {papermill_time}s")
print(f"Jupyter Client: {jupyter_time}s")
assert papermill_result["robustness"] > jupyter_result["robustness"]
```

#### Test gestion d'erreurs avancée
```python
# Test notebook avec erreurs (Papermill devrait être plus robuste)
problematic_notebook = create_notebook_with_errors()

papermill_result = await execute_with_papermill(problematic_notebook)
jupyter_result = await execute_with_jupyter_client(problematic_notebook)

assert papermill_result["error_recovery"] > jupyter_result["error_recovery"]
```

### 3.2 Test intégration Roo/VSCode

#### Test communication MCP
```python
# Simulation client MCP (Roo)
from mcp import Client

client = Client("http://localhost:3000")
tools = await client.list_tools()

assert len(tools) >= 17
assert "read_notebook" in [tool["name"] for tool in tools]
```

#### Test workflow complet
```python
# Simulation workflow utilisateur Roo
# 1. Créer notebook
create_result = await client.call_tool("create_notebook", {
    "path": "user_notebook.ipynb"
})

# 2. Ajouter cellule
add_result = await client.call_tool("add_cell", {
    "path": "user_notebook.ipynb",
    "cell_type": "code", 
    "source": "import numpy as np"
})

# 3. Exécuter
execute_result = await client.call_tool("execute_notebook", {
    "path": "user_notebook.ipynb"
})

assert all(r["status"] == "success" for r in [create_result, add_result, execute_result])
```

## Phase 4 : Tests de performance et robustesse

### 4.1 Benchmarks comparatifs

#### Test charge (notebooks multiples)
```python
# Test 10 notebooks simultanés
import asyncio

notebooks = [f"test_notebook_{i}.ipynb" for i in range(10)]
tasks = [execute_notebook(nb) for nb in notebooks]

start = time.time()
results = await asyncio.gather(*tasks, return_exceptions=True)
total_time = time.time() - start

success_count = sum(1 for r in results if not isinstance(r, Exception))
print(f"Succès: {success_count}/10 en {total_time}s")
assert success_count >= 8  # 80% de succès minimum
```

#### Test mémoire et ressources
```python
import psutil
import gc

# Baseline mémoire
gc.collect()
mem_before = psutil.virtual_memory().used

# Exécution intensive
for i in range(100):
    await execute_notebook(f"memory_test_{i}.ipynb")
    if i % 10 == 0:
        gc.collect()  # Nettoyage périodique

mem_after = psutil.virtual_memory().used
memory_increase = mem_after - mem_before

# Vérifier pas de fuite mémoire majeure
assert memory_increase < 500 * 1024 * 1024  # < 500MB
```

### 4.2 Tests de robustesse

#### Test kernels défaillants
```python
# Test avec kernel qui crash
faulty_code = """
import os
os._exit(1)  # Force crash kernel
"""

result = await execute_cell(kernel_id, faulty_code)
assert result["status"] == "kernel_died"

# Vérifier récupération automatique
recovery_result = await execute_cell(kernel_id, "print('recovered')")
assert recovery_result["status"] == "success"
```

#### Test notebooks corrompus
```python
# Test avec notebooks JSON malformés
corrupted_notebook = "corrupted.ipynb"
with open(corrupted_notebook, 'w') as f:
    f.write('{"invalid": json}')  # JSON invalide

result = await read_notebook(corrupted_notebook)
assert "error" in result
assert "malformed" in result["error"]
```

## Phase 5 : Tests de régression vs Node.js

### 5.1 Comparaison fonctionnelle

#### Parité des outils
```python
# Liste outils Node.js vs Python
nodejs_tools = get_nodejs_tools()
python_tools = get_python_tools()

# Vérifier parité (Python devrait avoir >=)
assert len(python_tools) >= len(nodejs_tools)
assert all(tool in python_tools for tool in nodejs_tools)
```

#### Test comportements identiques
```python
# Test même notebook sur les deux serveurs
test_notebook = "regression_test.ipynb"

# Résultat Node.js (référence)
nodejs_result = await execute_on_nodejs(test_notebook)

# Résultat Python
python_result = await execute_on_python(test_notebook)

# Comparaison résultats
compare_results(nodejs_result, python_result)
assert python_result["accuracy"] >= 0.95  # 95% de fidélité
```

### 5.2 Tests de migration

#### Test import configuration Node.js
```python
# Test lecture config Node.js existante
nodejs_config = load_nodejs_config("jupyter_config.json")
python_config = convert_to_python_config(nodejs_config)

# Vérifier conversion
assert python_config["jupyter_server"]["url"] == nodejs_config["baseUrl"]
assert python_config["jupyter_server"]["token"] == nodejs_config["token"]
```

## Plan d'exécution et critères de succès

### Séquencement des phases
1. **Phase 1** (Installation) : 15-25 minutes
2. **Phase 2** (Tests unitaires) : 45-60 minutes  
3. **Phase 3** (Intégration) : 30-45 minutes
4. **Phase 4** (Performance) : 30-45 minutes
5. **Phase 5** (Régression) : 20-30 minutes

**Durée totale estimée** : 2h30 - 3h15

### Critères de validation globaux

#### ✅ Critères de succès minimum
- Installation sans erreur
- 17+ outils fonctionnels (100%)
- Intégration Roo opérationnelle  
- Performance ≥ serveur Node.js
- Aucune régression fonctionnelle

#### ✅ Critères de succès optimal
- Amélioration robustesse vs Node.js
- Performance supérieure pour notebooks
- Gestion d'erreurs plus fine
- Documentation complète
- Tests automatisés intégrés

### Actions post-test
1. **Rapport de validation** détaillé
2. **Documentation utilisateur** mise à jour
3. **Scripts de déploiement** finalisés
4. **Intégration CI/CD** (optionnel)
5. **Formation équipe** (optionnel)

## Outils et frameworks de test

### Outils recommandés
- **pytest** : Tests unitaires Python
- **pytest-asyncio** : Tests asynchrones
- **pytest-benchmark** : Benchmarks performance
- **httpx** : Tests clients MCP
- **nbformat** : Validation notebooks

### Structure de test suggérée
```
tests/
├── unit/
│   ├── test_notebooks.py
│   ├── test_kernels.py  
│   └── test_execution.py
├── integration/
│   ├── test_hybrid_strategy.py
│   └── test_mcp_client.py
├── performance/
│   ├── test_benchmarks.py
│   └── test_memory.py
├── regression/
│   └── test_nodejs_parity.py
└── fixtures/
    ├── sample_notebooks/
    └── test_data/
```

Cette stratégie de test garantit une validation complète et rigoureuse du serveur Python/Papermill avant sa mise en production.