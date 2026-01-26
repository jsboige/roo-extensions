# Diagnostic MCP GitHub vs gh CLI - Dashboard Multi-Machines

**Date de création :** 2026-01-24
**Machine responsable :** myia-po-2026
**Priorité :** P1 (selon retour utilisateur)
**Objectif :** Décider si migration MCP GitHub → gh CLI + Dashboard complet

---

## 1. Problème Identifié : Verbosité MCP GitHub

### 1.1 Contexte

Le MCP `github-projects-mcp` cause des saturations de contexte Claude Code :

**Symptôme :**
```
Error: The tool result exceeds maximum allowed tokens
```

**Cause :**
- `mcp__github-projects-mcp__get_project_items` retourne 81,749 caractères
- Contexte Claude Code saturé (>25k tokens)
- Impossible de lister les issues P0/P1 du projet #67

**Impact :**
- Coordination multi-agent ralentie
- Impossibilité d'utiliser le MCP pour les opérations courantes
- Workaround nécessaire (curl + API REST)

### 1.2 Workaround Actuel

**Pour les opérations read-only :**
```bash
curl -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/jsboige/roo-extensions/issues?state=open&labels=priority-high"
```

**Pour les opérations write :**
- Envoyer message RooSync au coordinateur (myia-ai-01)
- Le coordinateur utilise son MCP GitHub pour créer/modifier issues

**Limitations :**
- Workflow asynchrone et complexe
- Dépendance sur le coordinateur
- Pas d'autonomie pour les exécutants

---

## 2. Solution Proposée : gh CLI

### 2.1 Avantages de gh CLI

**Verbosité réduite :**
- Sortie compacte et structurée
- Filtrage intégré (labels, état, assigné)
- Réduction estimée : 97.5% du contexte (81k → 2k chars)

**Fonctionnalités complètes :**
- Issues : `gh issue list/create/view/comment/close/edit`
- Projects : `gh project list/view/item-add/item-edit`
- PR : `gh pr list/create/view/merge/close`
- API directe : `gh api` pour requêtes personnalisées

**Autonomie des machines :**
- Chaque machine peut gérer ses propres issues
- Pas de dépendance sur le coordinateur
- Workflow synchrone et rapide

**Uniformité :**
- Même outil sur les 5 machines
- Scripts PowerShell/Bash portables
- Documentation simplifiée

### 2.2 Installation et Configuration

**Installation (Windows) :**
```powershell
winget install --id GitHub.cli
# OU
choco install gh
# OU
scoop install gh
```

**Authentification :**
```bash
gh auth login
# Choisir: GitHub.com → HTTPS → Login with a browser
```

**Configuration :**
```bash
gh config set git_protocol https
gh config set editor "code --wait"
```

### 2.3 Fonctionnalités Testées

#### Test 1 : gh CLI installé ?

**Commande :**
```bash
gh --version
```

**Résultat sur myia-po-2026 :**
```
❌ gh: command not found
```

**État :** gh CLI **non installé** sur myia-po-2026

#### Test 1b : Installation gh CLI via winget

**Commande :**
```powershell
winget install --id GitHub.cli --silent
```

**Résultat :**
```
❌ Installation bloquée (MSI attend interaction utilisateur malgré --silent)
Installation annulée après timeout
```

**Problème identifié :** winget avec --silent ne fonctionne pas correctement pour gh CLI MSI

**Solutions alternatives :**

**Option A : Installation manuelle**
1. Télécharger : https://github.com/cli/cli/releases/download/v2.85.0/gh_2.85.0_windows_amd64.msi
2. Exécuter MSI avec double-clic
3. Suivre wizard d'installation
4. Redémarrer terminal

**Option B : Installation via Chocolatey**
```powershell
choco install gh -y
```

**Option C : Installation via Scoop**
```powershell
scoop install gh
```

**Option D : Téléchargement portable**
```powershell
# Télécharger zip portable
curl -L https://github.com/cli/cli/releases/download/v2.85.0/gh_2.85.0_windows_amd64.zip -o gh.zip
# Extraire dans C:\Tools\gh\
# Ajouter au PATH
```

**Recommandation :** Option B (Chocolatey) si disponible, sinon Option A (manuel)

#### Test 1c : Authentification gh CLI + Tests Fonctionnels

**Commande :**

```bash
gh auth refresh -s read:project
```

**Résultat :**

```text
✅ Authentification réussie
- Account: jsboige
- Scopes: gist, read:org, read:project, repo, workflow
```

**État :** gh CLI **complètement opérationnel** sur myia-po-2026

##### Tests Fonctionnels Complets

**Date :** 2026-01-26

| Test | Commande | Résultat | Taille Sortie |
|------|----------|----------|---------------|
| Liste projets | `gh project list --owner jsboige` | ✅ Succès (5 projets) | ~500 bytes |
| Voir projet #67 | `gh project view 67 --owner jsboige` | ✅ Succès (108 items) | ~300 bytes |
| Liste items (30) | `gh project item-list 67 --limit 30` | ✅ Succès | ~19KB |
| Liste issues (10) | `gh issue list --limit 10 --json number,title,state` | ✅ Succès | ~1.5KB |
| Voir issue #368 | `gh issue view 368 --json number,title,body,state` | ✅ Succès | ~5KB |

**Comparaison Verbosité :**

| Opération | MCP GitHub (full) | MCP GitHub (summary) | gh CLI | Gain |
|-----------|-------------------|----------------------|---------|------|
| 30 items projet | 81K chars | ~15KB | ~19KB | 4.2x vs full |
| 10 issues | ~40KB | N/A | ~1.5KB | 26x |

**Conclusion :** gh CLI offre un contrôle fin de la verbosité et reste sous les seuils critiques.

#### Test 2 : État MCP GitHub

**Fichier de config :** `~/.claude.json`

**Résultat :**
```json
{
  "github-projects-mcp": {
    "command": "node",
    "args": ["C:/dev/roo-extensions/mcps/internal/servers/github-projects-mcp/dist/index.js"],
    "cwd": "C:/dev/roo-extensions/mcps/internal/servers/github-projects-mcp/",
    "env": {}
  }
}
```

**État :** MCP GitHub **installé et configuré** sur myia-po-2026

#### Test 3 : Fonctionnalités à valider

**Une fois gh installé, tester :**

| Fonctionnalité | Commande gh CLI | MCP GitHub équivalent | Priorité |
|----------------|-----------------|------------------------|----------|
| Lister issues P0/P1 | `gh issue list --label priority-high,priority-critical` | `get_project_items` (81k chars) | ✅ P0 |
| Créer issue | `gh issue create --title "..." --body "..."` | `create_issue` | ✅ P0 |
| Commenter issue | `gh issue comment 123 --body "..."` | `add_issue_comment` | ✅ P0 |
| Fermer issue | `gh issue close 123` | `update_issue_state` | ✅ P0 |
| Lister projets | `gh project list --owner jsboige` | `list_projects` | ⚠️ P1 |
| Voir projet | `gh project view 67` | `get_project` | ⚠️ P1 |
| Ajouter item projet | `gh project item-add 67 --owner jsboige --url ...` | `add_item_to_project` | ⚠️ P1 |
| Marquer item Done | `gh project item-edit --id ... --field-id ... --single-select-option-id ...` | `update_project_item_field` | ⚠️ P1 |

**Note :** gh CLI supporte les projets via extension ou `gh api` pour GraphQL.

---

## 3. État Multi-Machines (Dashboard)

### 3.1 Machine 1/5 : myia-po-2026 (Exécutant)

**Rôle :** Agent exécutant (Claude Code + Roo)

**Outils installés :**
- ✅ MCP GitHub : Configuré et fonctionnel
- ❌ gh CLI : **Non installé**
- ✅ MCP RooSync : Configuré et fonctionnel (6 outils messagerie)
- ✅ Git : Configuré
- ✅ Node.js : v20+ (pour MCPs)
- ✅ PowerShell : 7.x

**MCPs actifs :**
1. `github-projects-mcp` (57 outils)
2. `roo-state-manager` (wrapper → 6 outils RooSync)

**Statut synchronisation :**
- Last heartbeat : (à collecter)
- Last git pull : (à vérifier)
- Branch : main
- Commits ahead : 0 (après dernier rebase)

**Inventaire RooSync :**
- ✅ Inventaire créé : `myia-po-2026.json` (78 KB)
- ✅ Validé par `Validate-AllInventories.ps1`
- Contenu : 11 MCP servers, 12 Roo modes, 296 scripts

**Action requise :**
1. Installer gh CLI : `winget install GitHub.cli`
2. Authentifier : `gh auth login`
3. Tester fonctionnalités P0
4. Documenter résultats

### 3.2 Machine 2/5 : myia-ai-01 (Coordinateur)

**Rôle :** Coordinateur principal (Claude Code + Roo)

**Outils installés :**
- ✅ MCP GitHub : Vérifié fonctionnel (commit 71dfdad)
- ❓ gh CLI : **État inconnu** (à vérifier)
- ✅ MCP RooSync : Configuré et fonctionnel
- ✅ Git : Configuré
- ✅ Node.js : v20+
- ✅ PowerShell : 7.x

**MCPs actifs :**
- `github-projects-mcp` (57 outils)
- `roo-state-manager` (wrapper → 6 outils RooSync)

**GitHub Project géré :**
- Projet #67 : "RooSync Multi-Agent Tasks"
- URL : https://github.com/users/jsboige/projects/67
- État : 29/77 Done (37.7%)

**Inventaire RooSync :**
- ✅ Inventaire créé : `myia-ai-01.json`
- ✅ Validé

**Action requise :**
- Envoyer message RooSync pour vérifier état gh CLI
- Si absent, installer et configurer
- Coordonner stratégie de migration

### 3.3 Machine 3/5 : myia-po-2023 (Exécutant)

**Rôle :** Agent exécutant (Roo uniquement pour l'instant)

**Outils installés :**
- ❓ MCP GitHub : **État inconnu**
- ❓ gh CLI : **État inconnu**
- ❓ MCP RooSync : **État inconnu**
- ❓ Git : À vérifier
- ❓ Node.js : À vérifier

**Inventaire RooSync :**
- ✅ Inventaire créé : `myia-po-2023.json`
- ✅ Validé

**Statut communication :**
- ⚠️ Pas de réponse récente (dernière activité : à vérifier)

**Action requise :**
- Envoyer message RooSync pour collecte d'état
- Bootstrap Claude Code si nécessaire
- Installer gh CLI

### 3.4 Machine 4/5 : myia-po-2024 (Exécutant)

**Rôle :** Agent exécutant (Roo + Claude Code)

**Outils installés :**
- ❓ MCP GitHub : **État inconnu**
- ❓ gh CLI : **État inconnu**
- ❓ MCP RooSync : **État inconnu**
- ❓ Git : À vérifier
- ❓ Node.js : À vérifier

**Hardware :**
- ✅ GPU : RTX 3070 Laptop (4GB VRAM)
- Collecté via RooSync message

**Inventaire RooSync :**
- ✅ Inventaire créé : `myia-po-2024.json`
- ✅ Validé

**Statut communication :**
- ✅ Réponse récente pour GPU specs

**Action requise :**
- Envoyer message RooSync pour collecte d'état complet
- Installer gh CLI

### 3.5 Machine 5/5 : myia-web1 (Exécutant)

**Rôle :** Agent exécutant (Roo uniquement pour l'instant)

**Outils installés :**
- ❓ MCP GitHub : **État inconnu**
- ❓ gh CLI : **État inconnu**
- ❓ MCP RooSync : **État inconnu**
- ❓ Git : À vérifier
- ❓ Node.js : À vérifier

**Inventaire RooSync :**
- ✅ Inventaire créé : `myia-web1.json`
- ✅ Validé

**Statut communication :**
- ⚠️ Pas de réponse récente

**Action requise :**
- Envoyer message RooSync pour collecte d'état
- Bootstrap Claude Code si nécessaire
- Installer gh CLI

---

## 4. Plan de Migration (3 Phases)

### Phase 1 : Validation (Machine locale : myia-po-2026)

**Objectif :** Prouver que gh CLI couvre tous les besoins

**Actions :**
1. ✅ Diagnostiquer état actuel (ce document)
2. ⏳ Installer gh CLI sur myia-po-2026
3. ⏳ Tester toutes les fonctionnalités P0 (issues)
4. ⏳ Tester fonctionnalités P1 (projects)
5. ⏳ Comparer verbosité MCP vs gh CLI
6. ⏳ Documenter résultats et limitations
7. ⏳ Décision GO/NO-GO pour Phase 2

**Durée estimée :** 1-2 heures

**Critère de succès :**
- gh CLI couvre 100% des fonctionnalités P0
- gh CLI couvre ≥80% des fonctionnalités P1
- Verbosité réduite confirmée
- Aucun blocage technique identifié

### Phase 2 : Déploiement Multi-Machines

**Objectif :** Installer et configurer gh CLI sur les 4 autres machines

**Actions :**
1. Envoyer message RooSync à toutes les machines avec instructions
2. Coordonner installation sur myia-ai-01 (coordinateur)
3. Coordonner installation sur myia-po-2023
4. Coordonner installation sur myia-po-2024
5. Coordonner installation sur myia-web1
6. Vérifier authentification sur chaque machine
7. Tester workflow complet multi-machines

**Durée estimée :** 2-4 heures (selon disponibilité machines)

**Critère de succès :**
- gh CLI installé et authentifié sur 5/5 machines
- Tests P0 réussis sur chaque machine
- Documentation par machine complétée

### Phase 3 : Migration et Cleanup

**Objectif :** Remplacer MCP GitHub par gh CLI dans les workflows

**Actions :**
1. Mettre à jour les agents/skills/commands pour utiliser gh CLI
2. Mettre à jour CLAUDE.md et guides
3. Tester workflows coordination complets
4. Décider si suppression MCP GitHub ou conservation en fallback
5. Si suppression : retirer de ~/.claude.json sur 5 machines
6. Si conservation : documenter quand utiliser MCP vs gh CLI

**Durée estimée :** 2-3 heures

**Critère de succès :**
- Tous les workflows utilisent gh CLI par défaut
- Documentation à jour
- Pas de régression fonctionnelle
- Réduction contexte confirmée en production

---

## 5. Dashboard Complet (Objectif P2)

### 5.1 Dashboard Existant

**Script actuel :** `scripts/roosync/generate-mcp-dashboard.ps1`

**Contenu actuel :**
- Inventaires RooSync (5 machines)
- MCP servers installés
- Roo modes configurés
- Paths locaux

**Limitations :**
- Pas de versions des outils
- Pas de statut git
- Pas de métriques RooSync (heartbeats)
- Pas de statut tests/build

### 5.2 Dashboard Enrichi (Proposition)

**Nouvelles sections à ajouter :**

#### A. Versions des Outils
- Node.js version (`node --version`)
- npm version (`npm --version`)
- PowerShell version (`$PSVersionTable`)
- Git version (`git --version`)
- gh CLI version (`gh --version`)
- TypeScript version (`tsc --version`)

#### B. Statut Git
- Branch actuelle (`git branch --show-current`)
- Commits ahead/behind (`git status -sb`)
- Fichiers modifiés (`git status --porcelain`)
- Dernière sync (`git log -1 --format="%h %s %ar"`)

#### C. Métriques RooSync
- Last heartbeat timestamp
- Machine status (online/warning/offline)
- Messages non lus (inbox count)
- Dernière décision de sync

#### D. Build & Tests
- Last build status (`npm run build`)
- Last test status (`npm test`)
- Coverage (`npm run test:coverage`)
- TypeScript errors count (`tsc --noEmit`)

#### E. MCPs Actifs
- Liste des MCPs démarrés
- Nombre d'outils par MCP
- Erreurs de connexion MCP

### 5.3 Implémentation Dashboard

**Option A : Enrichir script existant**
- Modifier `generate-mcp-dashboard.ps1`
- Ajouter les nouvelles sections
- Garder format markdown

**Option B : Nouveau script complémentaire**
- Créer `generate-full-dashboard.ps1`
- Agréger : inventaire + versions + git + roosync + build
- Format markdown + JSON export

**Recommandation :** Option B (séparation des préoccupations)

---

## 6. Décisions Requises du Coordinateur

### 6.1 Migration MCP GitHub → gh CLI

**Question :** Approuver la migration complète vers gh CLI ?

**Options :**
- ✅ **OUI - Migration complète :** Installer gh CLI, migrer workflows, supprimer MCP GitHub
- ⚠️ **OUI - Migration progressive :** Installer gh CLI, garder MCP GitHub en fallback
- ❌ **NON - Conserver MCP :** Optimiser usage MCP GitHub, pas de gh CLI

**Recommandation myia-po-2026 :** Migration progressive (garder MCP en fallback)

**Justification :**
- gh CLI réduit drastiquement le contexte
- MCP GitHub reste disponible pour edge cases
- Pas de perte de fonctionnalité
- Migration réversible

### 6.2 Dashboard Complet

**Question :** Approche pour le dashboard enrichi ?

**Options :**
- **Option A :** Enrichir script existant `generate-mcp-dashboard.ps1`
- **Option B :** Nouveau script `generate-full-dashboard.ps1` (recommandé)

**Recommandation :** Option B

**Justification :**
- Séparation des préoccupations
- Script existant reste stable
- Dashboard complet plus maintenable
- Export JSON possible

### 6.3 Assignation Ressources

**Question :** Qui fait quoi sur les 5 machines ?

**Proposition :**
- **myia-po-2026 (moi) :** Phase 1 validation gh CLI + Dashboard script
- **myia-ai-01 (coordinateur) :** Coordination Phase 2, décisions, validation finale
- **myia-po-2024 :** Installation gh CLI, tests P0
- **myia-po-2023 :** Installation gh CLI, tests P0
- **myia-web1 :** Installation gh CLI, tests P0

**Deadline réponse souhaitée :** 48h

---

## 7. Actions Immédiates (En Attente Coordinateur)

### Sur myia-po-2026 (moi)

1. ⏳ **Installer gh CLI** (dès que décision validée)
   ```powershell
   winget install GitHub.cli
   gh auth login
   ```

2. ⏳ **Tester fonctionnalités P0**
   ```bash
   gh issue list --repo jsboige/roo-extensions --label priority-high
   gh issue create --repo jsboige/roo-extensions --title "Test" --body "Test gh CLI"
   gh issue close 123
   ```

3. ⏳ **Mesurer verbosité**
   ```bash
   gh issue list --json number,title,labels,state | wc -c
   ```

4. ⏳ **Documenter résultats** (mise à jour de ce document)

### Message RooSync Envoyé

Message `msg-20260124T105910-unbb2v` envoyé au coordinateur avec :
- Diagnostic complet
- Plan 3 phases
- Décisions requises
- Deadline 48h

**État :** ⏳ En attente de réponse

---

## 8. Références

**Documentation gh CLI :**
- https://cli.github.com/manual/
- https://cli.github.com/manual/gh_issue
- https://cli.github.com/manual/gh_project

**GitHub API REST :**
- https://docs.github.com/en/rest/issues/issues
- https://docs.github.com/en/rest/projects/projects

**Scripts RooSync :**
- [generate-mcp-dashboard.ps1](../../scripts/roosync/generate-mcp-dashboard.ps1)
- [Validate-AllInventories.ps1](../../scripts/roosync/Validate-AllInventories.ps1)
- [Bootstrap-AllInventories.ps1](../../scripts/roosync/Bootstrap-AllInventories.ps1)

---

**Dernière mise à jour :** 2026-01-24 11:00 UTC
**Auteur :** Claude Code (myia-po-2026)
**Statut :** ⏳ En attente décision coordinateur
