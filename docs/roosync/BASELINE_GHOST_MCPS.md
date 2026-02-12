# MCPs Fantômes dans la Baseline

**Issue:** #460
**Date:** 2026-02-12
**Baseline actuelle:** myia-ai-01

---

## Contexte

Le dashboard RooSync compare les configurations MCP des 6 machines par rapport à une baseline (myia-ai-01). Le dashboard affiche des "diffs" pour des MCPs qui ont été **intentionnellement retirés** de toutes les machines, ce qui crée de la confusion.

**Problème :** La baseline myia-ai-01 contient encore des références à des MCPs obsolètes qui n'existent plus.

---

## MCPs Fantômes Identifiés

| MCP | Raison du Retrait | Issue/Commit | Remplacement |
|-----|-------------------|--------------|--------------|
| `filesystem` | Remplacé par outils natifs Claude Code | - | Read, Write, Edit, Glob, Bash |
| `github` | Remplacé par `gh` CLI natif | #368 | `gh` CLI (GitHub CLI natif) |
| `github-projects-mcp` | Remplacé par `gh` CLI natif | #368 | `gh` CLI (GitHub CLI natif) |
| `quickfiles` | Remplacé par outils natifs Claude Code | - | Read, Write, Edit |

**Total :** 4 MCPs fantômes dans la baseline.

---

## Impact Actuel

### Dashboard DASHBOARD.md

Le dashboard mentionne ces MCPs dans les sections de diffs :

**Exemple - myia-po-2023 (11 diffs) :**
```markdown
| `filesystem` | added | À évaluer (absent baseline) | `` | `` |
| `github` | added | À évaluer (absent baseline) | `` | `` |
| `github-projects-mcp` | added | À évaluer (absent baseline) | `` | `` |
| `quickfiles` | added | À évaluer (absent baseline) | `` | `` |
```

**Interprétation incorrecte :** Ces diffs suggèrent que myia-po-2023 a des MCPs supplémentaires "à évaluer", alors qu'en réalité, c'est la baseline qui est obsolète.

### Compteur de diffs gonflé

| Machine | Diffs Affichés | Diffs Réels (sans fantômes) |
|---------|----------------|------------------------------|
| myia-po-2023 | 11 | 7 (-4 fantômes) |
| myia-po-2024 | 5 | 5 (pas de fantômes) |
| myia-po-2025 | 10 | 10 (pas de fantômes) |
| myia-po-2026 | 4 | 4 (pas de fantômes) |
| myia-web1 | 8 | 8 (pas de fantômes) |

**myia-po-2024** (ma machine) n'affiche pas ces MCPs fantômes car je n'ai jamais eu ces MCPs installés. Les autres machines les ont probablement dans leur historique d'inventaire.

---

## Solution : Mise à Jour de la Baseline

### Étape 1 : Collecter l'inventaire actuel de myia-ai-01

**Option A - Via MCP (Claude Code avec MCPs chargés) :**

```
Utilise l'outil roosync_inventory avec les paramètres suivants :
- action: "collect"
- machineId: "myia-ai-01"
- forceRefresh: true
```

**Option B - Via script PowerShell :**

```powershell
# Sur myia-ai-01
cd c:/dev/roo-extensions
powershell scripts/roosync/collect-inventory.ps1 -MachineId "myia-ai-01"
```

**Résultat attendu :** Fichier d'inventaire mis à jour dans :
```
G:/Mon Drive/Synchronisation/RooSync/.shared-state/inventories/myia-ai-01-inventory.json
```

### Étape 2 : Republier comme baseline

**Option A - Via MCP :**

```
Utilise l'outil roosync_baseline avec les paramètres suivants :
- action: "set"
- machineId: "myia-ai-01"
```

**Option B - Via script PowerShell :**

```powershell
# Sur myia-ai-01
cd c:/dev/roo-extensions
powershell scripts/roosync/set-baseline.ps1 -MachineId "myia-ai-01"
```

**Résultat attendu :** La baseline est mise à jour sans les 4 MCPs fantômes.

### Étape 3 : Refresh le dashboard

```
Utilise l'outil roosync_refresh_dashboard()
```

Ou :

```powershell
powershell scripts/roosync/generate-mcp-dashboard.ps1
```

**Résultat attendu :** Le dashboard ne mentionne plus les MCPs fantômes dans les diffs.

---

## Validation

Après mise à jour de la baseline, vérifier :

### Fichier baseline

Lire le fichier d'inventaire baseline :
```
G:/Mon Drive/Synchronisation/RooSync/.shared-state/inventories/myia-ai-01-inventory.json
```

Vérifier que les sections `mcpServers` ne contiennent PAS :
- `filesystem`
- `github`
- `github-projects-mcp`
- `quickfiles`

### Dashboard

Le dashboard doit afficher :

**myia-po-2023 :**
- Avant : 11 diffs
- Après : 7 diffs (ou moins)

**Diffs restants attendus :**
- Modifications de configuration (enabled, autoStart, description)
- MCPs légitimement différents (ex: win-cli enabled sur une machine, pas sur l'autre)

**Aucun diff du type :**
```markdown
| `filesystem` | added | À évaluer (absent baseline) | `` | `` |
```

---

## MCPs Actuellement Déployés (Référence)

Pour référence, voici les MCPs déployés sur toutes les machines après harmonisation :

### MCPs Communs (6/6 machines)

| MCP | Description | Usage |
|-----|-------------|-------|
| `roo-state-manager` | Gestion état RooSync + tâches Roo | Outils roosync_* |
| `jinavigator` | Conversion web → markdown | Web scraping |
| `markitdown` | Conversion fichiers → markdown | PDF, DOCX, etc. |
| `playwright` | Automatisation web | Tests E2E, scraping |
| `searxng` | Recherche web privée | Alternative à Google |
| `win-cli` | Commandes Windows CLI | PowerShell, cmd |

### MCPs Spécifiques

| MCP | Machines | Description |
|-----|----------|-------------|
| `jupyter` | Toutes sauf myia-web1 | Notebooks Jupyter |
| `sk-agent` | myia-ai-01 (en test) | Proxy LLM Semantic Kernel |

### MCPs Retirés (Fantômes)

| MCP | Remplacement |
|-----|--------------|
| `filesystem` | Read, Write, Edit, Glob, Bash (natifs) |
| `github` | `gh` CLI (natif) |
| `github-projects-mcp` | `gh` CLI (natif) |
| `quickfiles` | Read, Write, Edit (natifs) |

---

## Prochaines Actions

1. **Collecter inventaire myia-ai-01** : Via roosync_inventory ou script
2. **Republier baseline** : Via roosync_baseline ou script
3. **Refresh dashboard** : Vérifier que les fantômes ont disparu
4. **Mettre à jour #460** : Documenter la correction

---

## Prévention Future

Pour éviter que la baseline ne devienne obsolète à l'avenir :

### Recommandations

1. **Automatiser la baseline** :
   - Collecter l'inventaire myia-ai-01 toutes les semaines
   - Republier automatiquement comme baseline si changements détectés

2. **Documenter les retraits** :
   - Quand un MCP est retiré, documenter dans `docs/mcps/REMOVED_MCPS.md`
   - Inclure la raison, la date, et le remplacement

3. **Validation dashboard** :
   - Ajouter une section "MCPs Retirés" dans le dashboard
   - Alerter si un MCP retiré apparaît dans les diffs

---

**Document complet - Prêt pour exécution**
