# 📘 Git Safety & Source Control - Spécification Sécurité Critique

**Version :** 1.0.0  
**Date :** 07 Octobre 2025  
**Architecture :** 2-Niveaux (Simple/Complex)  
**Statut :** 🔴 SPÉCIFICATION CRITIQUE - Protection contre pertes de données  
**Priorité :** MAXIMALE - Application obligatoire tous modes

---

## 🚨 Historique des Incidents

Cette spécification a été créée en réponse à des **incidents critiques réels** ayant causé des pertes de données majeures dans le projet :

### Incidents Documentés

#### Incident #1 : Push Force avec Réécriture d'Historique (25/09/2025)
- **Type** : `git push --force` sans validation
- **Impact** : 5 commits orphelins, risque perte documentation critique
- **Cause** : Rebase interactif + amend + reset sans grounding
- **Référence** : [`docs/fixes/git-recovery-report-20250925.md`](../../docs/fixes/git-recovery-report-20250925.md)

#### Incident #2 : Destruction Fichiers Non-Versionnés (03/08/2025)
- **Type** : `git clean -fdx` sans vérification
- **Impact** : Perte irréversible fichiers de travail + node_modules
- **Cause** : Traitement "untracked content" sans analyse préalable
- **Référence** : [`roo-code-customization/incident-report-condensation-revert.md`](../../roo-code-customization/incident-report-condensation-revert.md)

#### Incident #3 : Contamination Agent Multi-Machines (21/09/2025)
- **Type** : Régression Git catastrophique
- **Impact** : +100 commits effacés par contamination d'agent
- **Cause** : Travail simultané multi-machines sans synchronisation
- **Référence** : [`docs/missions/2025-09-21-rapport-mission-restauration-git-critique-sddd.md`](../../docs/missions/2025-09-21-rapport-mission-restauration-git-critique-sddd.md)

#### Incident #4 : Exposition Secrets dans Historique (25/09/2025)
- **Type** : GitHub Push Protection bloquant push
- **Impact** : Clés API exposées dans commits (OpenAI, Qdrant)
- **Cause** : Commits sans vérification contenu sensible
- **Référence** : [`docs/integration/04-synchronisation-git-version-2.0.0.md`](../../docs/integration/04-synchronisation-git-version-2.0.0.md)

### Cause Racine Commune

> **Manque de prudence systématique et trop grande confiance dans la "situational awareness" des LLMs**

Les agents LLM (Claude 4.6, Gemini, etc.) ont tendance à :
- ❌ Exécuter des commandes destructives sans vérification préalable
- ❌ Assumer que leur compréhension du contexte est complète
- ❌ Privilégier la rapidité d'exécution sur la sécurité
- ❌ Utiliser des raccourcis dangereux (`--force`, `--theirs`, `clean -fdx`)

---

## 🎯 Principes Fondamentaux

### 1. Grounding Maximal Obligatoire

**RÈGLE ABSOLUE** : Aucune opération Git sans grounding complet du contexte

```
Avant TOUTE opération Git :
1. État working tree (git status)
2. Historique récent (git log)
3. État remote (git fetch + comparison)
4. Branches actives (git branch -vv)
```

### 2. Pas de Raccourcis Dangereux

**INTERDICTIONS STRICTES** : Opérations destructives sans validation utilisateur

- ❌ `git push --force` ou `-f`
- ❌ `git push --force-with-lease` (même avec lease)
- ❌ `git reset --hard` sur branche partagée
- ❌ `git clean -fdx` sans analyse préalable
- ❌ `git checkout --theirs` ou `--ours` aveugle
- ❌ Toute commande réécrivant l'historique public

### 3. Vérification Avant Action

**PROTOCOLE** : Chaque action doit être précédée d'une vérification

```
Vérifier → Comprendre → Demander (si doute) → Agir
```

### 4. Sauvegarde Systématique

**OBLIGATION** : Backup avant toute modification potentiellement destructive

```bash
# Avant modification fichier
cp fichier.ext fichier.ext.backup.$(date +%Y%m%d-%H%M%S)

# Avant opération Git destructive
git branch backup-$(date +%Y%m%d-%H%M%S)
```

---

## 📋 Section 1 : Règles Git Fondamentales

### 1.1 Vérification État Dépôt (OBLIGATOIRE)

**AVANT toute opération Git**, exécuter séquence complète :

```bash
# 1. État working tree
git status

# 2. Commits récents (contexte)
git log --oneline -10

# 3. Remotes configurés
git remote -v

# 4. Branches et tracking
git branch -vv

# 5. Stash existants (si applicable)
git stash list
```

**Analyser les résultats** :
- Fichiers modifiés/non suivis → Comprendre pourquoi
- Commits récents → Identifier le travail en cours
- Divergence avec remote → Stratégie de synchronisation
- Branches multiples → Risque de confusion

### 1.2 Opérations ABSOLUMENT INTERDITES

Ces commandes sont **INTERDITES sans autorisation explicite utilisateur** :

#### Catégorie A : Réécriture Historique Public

```bash
❌ git push --force
❌ git push -f
❌ git push --force-with-lease  # Même avec lease !
❌ git reset --hard <commit>     # Sur branche partagée
❌ git rebase <branch>           # Sur historique pushé
❌ git commit --amend            # Sur commit pushé
❌ git filter-branch
❌ git filter-repo
```

**Justification** : Ces commandes réécrivent l'historique, créant conflits et pertes de données pour autres agents/utilisateurs.

#### Catégorie B : Suppression Destructive

```bash
❌ git clean -fdx                # Sans analyse préalable
❌ git clean -fd                 # Idem
❌ git reset --hard              # Sans backup
❌ git checkout -- .             # Sans vérifier contenu
```

**Justification** : Ces commandes suppriment irréversiblement fichiers non-versionnés ou modifications en cours.

#### Catégorie C : Résolution Aveugle Conflits

```bash
❌ git checkout --theirs <file>  # Sans analyser contenu
❌ git checkout --ours <file>    # Sans analyser contenu
❌ git merge -X theirs           # Résolution automatique aveugle
❌ git merge -X ours             # Résolution automatique aveugle
```

**Justification** : Ces commandes écrasent potentiellement du travail légitime sans analyse intelligente.

### 1.3 Protocole Pull OBLIGATOIRE Avant Push

**RÈGLE STRICTE** : Toujours pull avant push, jamais l'inverse

```bash
# 1. Fetch état remote
git fetch origin

# 2. Vérifier divergence
git status

# 3. Si divergence détectée
if [ "diverged" ]; then
    # a. Examiner commits distants
    git log HEAD..origin/main --oneline
    
    # b. DEMANDER validation utilisateur
    # "Il y a X commits sur origin/main. Stratégie : merge ou rebase ?"
    
    # c. Expliquer ce qui sera intégré
    git log HEAD..origin/main --stat
    
    # d. Agir selon validation
    git pull --rebase    # OU git pull --no-rebase
    
    # e. Résoudre conflits intelligemment (voir Section 3)
fi

# 4. Push seulement après synchronisation
git push origin main
```

**En cas d'échec push** :

```bash
# Si push rejeté (remote ahead)
! [rejected] main -> main (non-fast-forward)

# ARRÊTER IMMÉDIATEMENT
# Ne JAMAIS utiliser --force
# Revenir à étape 1 (fetch + analyse)
```

### 1.4 Commits Atomiques et Descriptifs

**RÈGLES** :

1. **Un commit = une modification logique cohérente**
   ```bash
   # ✅ BON : Commit atomique
   git add src/feature.ts
   git commit -m "feat(feature): add user authentication"
   
   # ❌ MAUVAIS : Commit fourre-tout
   git add .
   git commit -m "fixes"
   ```

2. **Format Conventional Commits OBLIGATOIRE**
   ```
   <type>(<scope>): <description>
   
   [body optionnel]
   
   [footer optionnel]
   ```
   
   Types valides : `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

3. **Vérifier fichiers ajoutés AVANT commit**
   ```bash
   # Examiner diff staged
   git diff --cached
   
   # Lister fichiers staged
   git diff --cached --name-only
   
   # ❌ INTERDIT : git add . aveugle
   # ✅ OBLIGATOIRE : git add <file1> <file2> explicite
   ```

4. **Pas de commits temporaires/WIP sur branche partagée**
   ```bash
   # ❌ INTERDIT sur main/develop
   git commit -m "WIP"
   git commit -m "temp"
   git commit -m "checkpoint"
   
   # ✅ Utiliser branche feature ou stash
   git stash save "WIP: feature implementation"
   ```

### 1.5 Gestion des Branches

**PROTOCOLE** :

1. **Vérifier branche active avant toute modification**
   ```bash
   git branch --show-current
   
   # Si sur main → Créer feature branch
   git checkout -b feature/new-feature
   ```

2. **Nomenclature branches**
   ```
   feature/<description>   # Nouvelles fonctionnalités
   fix/<description>       # Corrections bugs
   docs/<description>      # Documentation
   refactor/<description>  # Refactoring
   ```

3. **Nettoyage branches obsolètes**
   ```bash
   # Lister branches mergées
   git branch --merged main
   
   # Supprimer UNIQUEMENT après validation utilisateur
   git branch -d feature/merged-feature
   ```

---

## 📋 Section 2 : Résolution de Conflits Intelligente

### 2.1 Détection et Analyse Conflits

**Lors d'un conflit Git**, procédure obligatoire :

```bash
# 1. Identifier fichiers en conflit
git status

# Exemple output :
# both modified:   src/config.ts
# both modified:   package.json

# 2. Pour CHAQUE fichier en conflit
for file in $(git diff --name-only --diff-filter=U); do
    echo "=== Analyse: $file ==="
    
    # a. Voir modifications locales (HEAD)
    git show HEAD:$file > /tmp/local.txt
    
    # b. Voir modifications distantes (origin)
    git show origin/main:$file > /tmp/remote.txt
    
    # c. Comparer les deux
    git diff HEAD origin/main -- $file
    
    # d. ANALYSER : Les deux changements sont-ils compatibles ?
    # e. DÉCIDER : Merge intelligent ou choisir version
done
```

**Questions à se poser** :

1. ✅ Les modifications touchent-elles des lignes différentes ? → Merge automatique possible
2. ✅ Les modifications sont-elles complémentaires ? → Intégrer les deux
3. ❌ Les modifications sont-elles contradictoires ? → Demander validation utilisateur
4. ❌ Une version introduit-elle un bug ? → Analyser historique commits

### 2.2 Stratégies de Résolution

#### Priorité 1 : Merge Intelligent (Préféré)

**Objectif** : Préserver le travail de tous les contributeurs

```bash
# Exemple : Conflit config.json
<<<<<<< HEAD
{
  "apiUrl": "https://api.prod.example.com",
  "timeout": 5000
}
=======
{
  "apiUrl": "https://api.staging.example.com",
  "logLevel": "debug"
}
>>>>>>> origin/main

# ✅ Résolution intelligente : Intégrer les deux
{
  "apiUrl": "https://api.prod.example.com",
  "timeout": 5000,
  "logLevel": "debug"
}
```

**Procédure** :

1. Analyser les deux versions ligne par ligne
2. Identifier les ajouts/modifications non-conflictuels
3. Fusionner intelligemment en préservant les deux intentions
4. Tester le résultat si possible
5. Documenter le merge dans message commit

```bash
git add config.json
git commit -m "merge: Résolution conflit config.json

- Intégration URL production (local) + logLevel (remote)
- Préservation timeout existant
- Résolution manuelle intelligente"
```

#### Priorité 2 : Validation Utilisateur (Si incertitude)

**Quand demander** :

- ❓ Impossible de déterminer quelle version est correcte
- ❓ Modifications contradictoires sur logique métier
- ❓ Risque d'introduire un bug par merge automatique
- ❓ Fichier critique (config, schema, migration)

**Procédure** :

```bash
# 1. Préparer comparaison claire
git diff HEAD origin/main -- problematic-file.ts > /tmp/conflict-analysis.txt

# 2. ask_followup_question avec contexte
```

**Question type** :

```
Conflit détecté sur `src/api/client.ts` :

VERSION LOCALE (HEAD) :
- Changement timeout de 30s à 60s
- Ajout retry logic (3 tentatives)

VERSION DISTANTE (origin/main) :
- Changement timeout de 30s à 45s  
- Ajout logging détaillé

ANALYSE :
Les deux versions augmentent le timeout mais valeurs différentes.
Les fonctionnalités (retry vs logging) sont complémentaires.

PROPOSITION :
Merger avec timeout=60s + retry logic + logging

Validation ?
[1] ✅ Merger comme proposé
[2] Garder timeout=45s (version distante)
[3] Autre stratégie (préciser)
```

#### Priorité 3 : Version Choisie (Dernier recours)

**UNIQUEMENT si** :

- ✅ L'utilisateur valide explicitement
- ✅ Une version est clairement obsolète/incorrecte
- ✅ Le contexte métier justifie le choix

**Procédure** :

```bash
# 1. Sauvegarder version abandonnée
git show origin/main:file.ts > file.ts.remote-backup-$(date +%Y%m%d-%H%M%S)

# 2. Choisir version (après validation)
git checkout --ours file.ts    # Garder locale
# OU
git checkout --theirs file.ts  # Garder distante

# 3. Documenter POURQUOI dans commit
git add file.ts
git commit -m "merge: Résolution conflit file.ts - version [locale|distante] choisie

JUSTIFICATION :
- Version [autre] contenait bug XYZ
- Version choisie validée par tests
- Sauvegarde version abandonnée dans file.ts.remote-backup-*"
```

### 2.3 Cas Spéciaux

#### Conflits Binaires (Images, PDFs, etc.)

```bash
# Fichiers binaires : pas de merge possible
# TOUJOURS demander validation utilisateur

# Voir taille/date des deux versions
git log --all --pretty=format:"%h %ad %s" -- path/to/image.png

# Extraire les deux versions
git show HEAD:path/to/image.png > image-local.png
git show origin/main:path/to/image.png > image-remote.png

# ask_followup_question avec preview si possible
```

#### Conflits package.json / package-lock.json

```bash
# Stratégie spéciale : Regenerate lock files

# 1. Résoudre d'abord package.json intelligemment
# 2. Supprimer lock file en conflit
rm package-lock.json  # ou yarn.lock, pnpm-lock.yaml

# 3. Regénérer
npm install  # ou yarn, pnpm install

# 4. Commit résolution
git add package.json package-lock.json
git commit -m "merge: Résolution conflit dependencies + regenerate lock"
```

---

## 📋 Section 3 : Gestion de Fichiers Sécurisée

### 3.1 Protocole OBLIGATOIRE Avant Création/Modification

**AVANT de créer ou modifier un fichier**, exécuter séquence complète :

```bash
# 1. Recherche exhaustive existence
# a. Recherche exacte
find . -name "filename.ext" -type f

# b. Recherche pattern similaire
find . -name "*filename*" -type f

# c. Recherche par extension dans répertoire attendu
find ./expected/path -name "*.ext" -type f

# d. Recherche dans historique Git
git log --all --full-history -- '**/filename.ext'

# e. Recherche dans tous les commits (même supprimés)
git rev-list --all | xargs git grep -l "filename.ext"
```

**Si fichier EXISTE** :

```bash
# 2. Examiner contenu
head -20 filename.ext
tail -20 filename.ext

# 3. Vérifier métadonnées
ls -lh filename.ext  # Taille, date modification
file filename.ext    # Type de fichier
git log -- filename.ext  # Historique Git

# 4. ANALYSER
# - Est-ce le bon fichier ?
# - Est-ce une version production ou debug/temp ?
# - Y a-t-il d'autres versions (filename-v2, filename.old) ?

# 5. Si modification : BACKUP OBLIGATOIRE
cp filename.ext filename.ext.backup.$(date +%Y%m%d-%H%M%S)

# 6. Modifier avec précaution
```

**Si fichier N'EXISTE PAS** :

```bash
# 2. Vérifier versions alternatives
find . -name "filename*" -o -name "*filename*"

# 3. Vérifier si supprimé intentionnellement
git log --all --full-history --diff-filter=D -- '**/filename.ext'

# 4. Si fichier a été supprimé
# DEMANDER validation utilisateur avant recréation
# "Ce fichier a été supprimé dans commit XYZ. Raison : [message].
#  Voulez-vous vraiment le recréer ?"

# 5. Créer seulement après validation
```

### 3.2 Détection Versions Multiples

**RÈGLE** : Si plusieurs versions d'un fichier, TOUJOURS investiguer

```bash
# Scénario : Trouvé plusieurs versions
$ find . -name "*config*"
./config.json
./config.backup.json
./config.old.json
./config-v2.json
./config.temp.json

# PROTOCOLE OBLIGATOIRE
for file in config*.json; do
    echo "=== $file ==="
    
    # Taille
    ls -lh "$file"
    
    # Contenu (début)
    head -10 "$file"
    
    # Dernière modification
    git log -1 --format="%ai %an" -- "$file" 2>/dev/null || echo "Non versionné"
    
    echo ""
done

# ANALYSER
# 1. Quelle est la version de production ?
# 2. Pourquoi plusieurs versions existent ?
# 3. Lesquelles sont obsolètes ?

# ask_followup_question si doute
```

**Question type** :

```
Plusieurs versions trouvées pour config.json :

1. config.json (2.5 KB, modifié il y a 2h, dans Git)
2. config.backup.json (2.3 KB, modifié il y a 1 jour, dans Git)
3. config.temp.json (150 bytes, modifié il y a 5min, PAS dans Git)

ANALYSE :
- config.temp.json est très petit, probablement fichier debug
- config.json et config.backup.json similaires taille

Quelle version dois-je utiliser pour modifications ?
[1] config.json (version actuelle)
[2] config.backup.json (backup récent)
[3] Analyser différences entre les deux d'abord
```

### 3.3 Fichiers Temporaires vs Production

**Signes d'alerte** (fichier possiblement temporaire) :

```
❗ Nom contient : .tmp, .temp, .test, .debug, .backup, .old, -old, -new
❗ Taille anormalement petite (< 100 bytes pour fichier code)
❗ Date modification très récente (< 1h) sans explication
❗ Contenu vide ou placeholders
❗ Non versionné Git (mais dans .gitignore)
❗ Extension inhabituelle (.bak, .swp, .swo, ~)
```

**PROTOCOLE si signes détectés** :

```bash
# 1. NE PAS utiliser automatiquement ce fichier

# 2. Chercher version production
# a. Historique Git
git log --all -- '**/filename.ext' | head -20

# b. Fichiers similaires versionnés
git ls-files | grep -i filename

# c. Recherche dans commits récents
git log --oneline --all -20 --name-only | grep -i filename

# 3. ask_followup_question OBLIGATOIRE
```

**Exemple question** :

```
⚠️ ALERTE : Fichier suspect détecté

Fichier : src/api/client.temp.ts
- Taille : 45 bytes
- Contenu : "// TODO: implement"
- Modifié : il y a 15 minutes
- Git : Non versionné

RECHERCHE version production :
- Trouvé : src/api/client.ts (3.2 KB, dans Git)
- Historique : 15 commits, dernière modif il y a 3 jours

SUSPICION : client.temp.ts est fichier de test/debug vide

Dois-je utiliser src/api/client.ts (production) ?
```

### 3.4 Vérification Avant Suppression

**AVANT toute suppression**, vérification obligatoire :

```bash
# 1. Lister ce qui sera supprimé
git clean -n -d  # Dry-run, montre sans exécuter

# 2. Examiner chaque fichier/dossier
for item in $(git clean -n -d | awk '{print $3}'); do
    echo "=== $item ==="
    
    if [ -f "$item" ]; then
        # Fichier
        file "$item"
        head -5 "$item"
        wc -l "$item"
    else
        # Dossier
        ls -lh "$item" | head -10
        du -sh "$item"
    fi
    
    echo ""
done

# 3. ask_followup_question OBLIGATOIRE si :
# - Fichiers > 1 KB
# - Dossiers contenant code (pas node_modules)
# - Noms ne contenant pas "temp", "cache", "build"

# 4. Seulement après validation
git clean -fdx  # OU suppression manuelle sélective
```

---

## 📋 Section 4 : Coordination Multi-Agents

### 4.1 Vérifications Avant Toute Modification

**AVANT de modifier fichiers**, vérifier activité récente :

```bash
# 1. Activité générale dernières 24h
git log --since="1 day ago" --oneline --all

# 2. Travail d'autres agents/utilisateurs
git log --since="6 hours ago" --all --author-date-order

# 3. Pour chaque fichier à modifier
for file in files_to_modify.txt; do
    # Dernière modification
    git log -1 --format="%ai %an %s" -- "$file"
    
    # Modifications récentes (7 jours)
    git log --since="7 days ago" --oneline -- "$file"
done

# 4. Si activité récente détectée
# PULL OBLIGATOIRE avant modification
git fetch origin
git pull --rebase origin main
```

**Si conflit lors du pull** : Voir Section 2 (Résolution Conflits)

### 4.2 Communication via Messages de Commit

**RÈGLES commits en environnement multi-agents** :

```bash
# 1. Inclure identifiant agent/mode
git commit -m "feat(api): add caching layer

Agent: Code Mode (Claude-4.6)
Context: Performance optimization task
Files: src/api/cache.ts, src/api/client.ts
Related: #123"

# 2. Si travail long (> 1h), commits intermédiaires fréquents
# Pas de gros commit unique après plusieurs heures

# 3. Si feature partagée, mentionner dans commit
git commit -m "feat(auth): add JWT validation (part 1/3)

⚠️ SHARED FEATURE: Auth system
Next steps: Token refresh, user permissions
Coordinating with: Architect mode"

# 4. Utiliser conventional commits pour filtrage
git log --oneline --grep="^feat" --since="1 day ago"
```

### 4.3 Détection et Résolution Collisions

**Scénario** : Push échoue car remote plus récent

```bash
$ git push origin main
To https://github.com/user/repo.git
 ! [rejected] main -> main (non-fast-forward)
error: failed to push some refs

# ⚠️ ARRÊTER IMMÉDIATEMENT
# NE JAMAIS utiliser --force

# 1. Fetch et analyser ce qui a été pushé
git fetch origin
git log HEAD..origin/main --oneline

# Exemple output :
# a1b2c3d (mode-X) feat: add feature Y
# d4e5f6g (mode-Z) fix: correct bug in module W

# 2. Examiner en détail
git log HEAD..origin/main --stat

# 3. ANALYSER
# - Qui a pushé ? (agent, utilisateur)
# - Quels fichiers modifiés ?
# - Y a-t-il overlap avec notre travail ?

# 4. ask_followup_question OBLIGATOIRE
```

**Question type** :

```
⚠️ COLLISION DÉTECTÉE : Push rejeté (remote ahead)

Commits distants (origin/main) :
1. a1b2c3d (il y a 15min, Architect mode) "feat: restructure API"
   - Fichiers : src/api/routes.ts, src/api/middleware.ts
   
2. d4e5f6g (il y a 5min, Debug mode) "fix: correct timeout handling"
   - Fichiers : src/api/client.ts

Notre travail local :
- Modifications : src/api/client.ts, src/api/cache.ts
- Commits : 3 commits feat(cache)

ANALYSE :
- CONFLIT POTENTIEL : src/api/client.ts modifié des deux côtés
- Pas de conflit : cache.ts (nouveau fichier)

Stratégie recommandée :
[1] Pull --rebase (conseillé si commits atomiques)
[2] Pull --merge (conseillé si feature complexe)
[3] Examiner diff détaillé d'abord
[4] Créer branche feature et demander review
```

### 4.4 Synchronisation Cross-Machine

**Si travail sur plusieurs machines** :

```bash
# PROTOCOLE STRICT

# Machine A - Fin session
# 1. Commit travail en cours
git add .
git commit -m "wip: feature X progress checkpoint

⚠️ WORK IN PROGRESS
Machine: laptop-A
Next session: laptop-B
Status: Tests passing, documentation pending"

# 2. Push
git push origin feature/feature-x

# Machine B - Début session
# 1. TOUJOURS fetch+pull d'abord
git fetch origin
git checkout feature/feature-x
git pull origin feature/feature-x

# 2. Vérifier état
git log -3
git status

# 3. Continuer travail

# Machine B - Fin session
# 1. Commit + push
git add .
git commit -m "wip: feature X continued

Machine: laptop-B
Completed: Documentation
Next: Integration tests"

git push origin feature/feature-x
```

---

## 📋 Section 5 : Protocole SDDD pour Git

### 5.1 Grounding Systématique (4 Niveaux)

**AVANT toute opération Git**, grounding complet obligatoire :

#### Niveau 1 : File Grounding

```bash
# 1. Lister fichiers du dépôt
git ls-files | head -50

# 2. Structure projet
tree -L 2  # Linux/Mac
# OU
Get-ChildItem -Recurse -Depth 2  # PowerShell

# 3. Fichiers modifiés récemment
git diff --name-only HEAD~5..HEAD

# OBJECTIF : Comprendre organisation code
```

#### Niveau 2 : Semantic Grounding

```bash
# Rechercher documentation Git projet
codebase_search "git workflow conventions"
codebase_search "commit message format"
codebase_search "branch strategy"
codebase_search "git safety guidelines"

# OBJECTIF : Découvrir conventions projet
```

#### Niveau 3 : Conversational Grounding

```bash
# Consulter historique tâches Git via roo-state-manager
use_mcp_tool roo-state-manager roosync_search \
  --action "semantic" \
  --search_query "git operations conflicts" \
  --max_results 10

# Vérifier notes précédentes conflits
use_mcp_tool roo-state-manager conversation_browser \
  --action "view" \
  --task_id <current_task> \
  --view_mode chain

# OBJECTIF : Apprendre des expériences passées
```

#### Niveau 4 : Project Grounding

```bash
# 1. Consulter docs projet
cat CONTRIBUTING.md 2>/dev/null
cat docs/git-workflow.md 2>/dev/null
cat .github/pull_request_template.md 2>/dev/null

# 2. Vérifier issues/PR tracking
# (Si MCP GitHub disponible)
use_mcp_tool github list_issues \
  --repo owner/repo \
  --state open \
  --labels "git,workflow"

# OBJECTIF : Aligner avec process projet
```

### 5.2 Checkpoint Grounding (50k tokens)

**RÈGLE** : Tous les 50k tokens, checkpoint conversationnel obligatoire

```bash
# Utiliser roo-state-manager pour grounding
use_mcp_tool roo-state-manager conversation_browser \
  --action "view" \
  --task_id <current_task> \
  --detail_level summary

# Vérifier :
# - Opérations Git effectuées depuis début tâche
# - Conflits rencontrés et résolutions
# - Fichiers modifiés
# - Branches créées/mergées

# Si dérive détectée :
# - Revenir état cohérent (stash, branch)
# - Demander clarification utilisateur
```

### 5.3 Interdictions Raccourcis Dangereux

**❌ INTERDIT, même si "ça irait plus vite"** :

```bash
# 1. Sauter vérification état dépôt
❌ git push  # Sans git status + fetch avant

# 2. Utiliser --force sans comprendre
❌ git push --force  # Jamais acceptable

# 3. Résoudre conflits sans analyser
❌ git checkout --theirs .  # Écrase travail local
❌ git merge -X theirs  # Résolution aveugle

# 4. Créer fichier sans vérifier existence
❌ touch file.ts  # Sans find + git log avant

# 5. Assumer que notre version est bonne
❌ git reset --hard origin/main  # Sans sauvegarder local

# 6. Supprimer sans vérifier
❌ git clean -fdx  # Sans git clean -n + validation

# 7. Amend commit pushé
❌ git commit --amend  # Si déjà sur origin
```

**✅ OBLIGATIONS (toujours, sans exception)** :

```bash
# 1. Vérifier PUIS agir
✅ git status && git fetch && git log HEAD..origin/main
✅ THEN decide action

# 2. Comprendre PUIS modifier
✅ git diff file.ts  # Voir changements
✅ git log -- file.ts  # Comprendre historique
✅ THEN modify

# 3. Demander PUIS décider (si doute)
✅ ask_followup_question with context
✅ AWAIT validation
✅ THEN execute

# 4. Backup PUIS écraser (si nécessaire)
✅ cp file.ts file.ts.backup.$(date +%Y%m%d-%H%M%S)
✅ git branch backup-$(date +%Y%m%d-%H%M%S)
✅ THEN modify/reset

# 5. Pull PUIS push (toujours)
✅ git fetch origin
✅ git pull --rebase origin main
✅ THEN git push origin main
```

---

## 📋 Section 6 : Checklists de Sécurité

### 6.1 Checklist Avant Commit

```
[ ] git status vérifié
[ ] Fichiers ajoutés listés individuellement (pas git add .)
[ ] git diff --cached reviewed (examiner tous changements)
[ ] Pas de fichiers temporaires inclus (.tmp, .test, .debug)
[ ] Pas de fichiers sensibles (secrets, .env, credentials)
[ ] Message commit descriptif (conventional commits)
[ ] Backup créé si modification fichier existant critique
[ ] Tests passés (si applicable)
```

**Script de vérification** :

```bash
#!/bin/bash
# pre-commit-check.sh

echo "🔍 Vérification pré-commit..."

# 1. Fichiers sensibles
if git diff --cached --name-only | grep -E '\.env$|secret|credential|password'; then
    echo "❌ ERREUR : Fichiers sensibles détectés"
    exit 1
fi

# 2. Fichiers temporaires
if git diff --cached --name-only | grep -E '\.tmp$|\.temp$|\.test$|\.debug$'; then
    echo "⚠️ ATTENTION : Fichiers temporaires détectés"
    git diff --cached --name-only | grep -E '\.tmp$|\.temp$|\.test$|\.debug$'
    read -p "Continuer ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 3. Taille diff
lines_changed=$(git diff --cached --numstat | awk '{s+=$1+$2} END {print s}')
if [ "$lines_changed" -gt 500 ]; then
    echo "⚠️ ATTENTION : Gros commit ($lines_changed lignes)"
    read -p "Continuer ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ Vérifications passées"
```

### 6.2 Checklist Avant Push

```
[ ] git fetch effectué
[ ] git status vérifié (clean working tree)
[ ] Pas de divergence avec origin (ou divergence comprise)
[ ] Pull/rebase effectué si nécessaire
[ ] Conflits résolus intelligemment (pas --theirs/--ours aveugle)
[ ] Tests passés (npm test, pytest, etc.)
[ ] Build réussi (si applicable)
[ ] Pas de --force utilisé
[ ] Message dernier commit vérifié (pas de WIP sur main)
[ ] Branche correcte (feature branch OU main si autorisé)
```

**Script de vérification** :

```bash
#!/bin/bash
# pre-push-check.sh

echo "🔍 Vérification pré-push..."

# 1. Fetch origin
git fetch origin

# 2. Vérifier divergence
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u} 2>/dev/null)
BASE=$(git merge-base @ @{u} 2>/dev/null)

if [ "$LOCAL" != "$REMOTE" ] && [ "$LOCAL" = "$BASE" ]; then
    echo "❌ ERREUR : Remote ahead. Pull requis."
    git log HEAD..@{u} --oneline
    exit 1
elif [ "$LOCAL" != "$REMOTE" ] && [ "$REMOTE" = "$BASE" ]; then
    echo "✅ Local ahead. Push autorisé."
elif [ "$LOCAL" != "$REMOTE" ]; then
    echo "❌ ERREUR : Divergence détectée."
    git log --left-right --oneline HEAD...@{u}
    exit 1
fi

# 3. Vérifier branche
current_branch=$(git branch --show-current)
if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
    echo "⚠️ ATTENTION : Push sur branche principale"
    read -p "Confirmer push sur $current_branch ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ Vérifications passées"
```

### 6.3 Checklist Avant Modification Fichier

```
[ ] Fichier recherché (find, git log --all)
[ ] Existence vérifiée
[ ] Contenu examiné (pas fichier temp/debug)
[ ] Versions alternatives recherchées (file-v2, file.old)
[ ] Historique Git consulté (git log -- file)
[ ] Backup créé si modification
[ ] Utilisateur consulté si doute
[ ] Tests impactés identifiés
```

**Script de vérification** :

```bash
#!/bin/bash
# pre-file-modification.sh
# Usage: ./pre-file-modification.sh path/to/file.ts

FILE=$1

echo "🔍 Vérification pré-modification: $FILE"

# 1. Fichier existe ?
if [ ! -f "$FILE" ]; then
    echo "❌ ERREUR : Fichier n'existe pas"
    
    # Rechercher alternatives
    echo "Recherche alternatives..."
    find . -name "$(basename $FILE)*" -o -name "*$(basename $FILE)"
    
    # Historique Git
    echo "Historique Git..."
    git log --all --full-history --diff-filter=D -- "**/$FILE"
    
    exit 1
fi

# 2. Vérifier taille
size=$(wc -c < "$FILE")
if [ "$size" -lt 100 ]; then
    echo "⚠️ ATTENTION : Fichier très petit ($size bytes)"
    echo "Contenu:"
    cat "$FILE"
    read -p "Continuer ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 3. Chercher versions alternatives
basename=$(basename "$FILE" | sed 's/\.[^.]*$//')
dirname=$(dirname "$FILE")
alternatives=$(find "$dirname" -name "${basename}*" -o -name "*${basename}*")

if [ $(echo "$alternatives" | wc -l) -gt 1 ]; then
    echo "⚠️ ATTENTION : Versions multiples trouvées:"
    echo "$alternatives"
    read -p "Continuer avec $FILE ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 4. Créer backup
backup="${FILE}.backup.$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$backup"
echo "✅ Backup créé: $backup"

echo "✅ Vérifications passées"
```

---

## 📋 Section 7 : Escalade et Cas d'Exception

### 7.1 Quand Demander Validation Utilisateur

**ask_followup_question OBLIGATOIRE dans ces cas** :

#### Cas 1 : Conflit Git Non-Mergeable

```
Déclencher si :
- Conflit sur fichier critique (config, schema, migration)
- Modifications contradictoires logique métier
- Impossible déterminer version correcte
- Risque régression fonctionnelle

Template question :
"Conflit sur [fichier] :
LOCAL : [description changements]
REMOTE : [description changements]
ANALYSE : [explication]
PROPOSITION : [stratégie recommandée]
Options : [choix multiples]"
```

#### Cas 2 : Divergence avec Origin

```
Déclencher si :
- origin/main a commits que nous n'avons pas
- Modifications touchent mêmes fichiers
- Rebase vs merge impacte stratégie projet

Template question :
"Divergence détectée :
REMOTE COMMITS : [liste avec auteurs/dates]
LOCAL COMMITS : [liste]
OVERLAP : [fichiers communs]
STRATÉGIE : [rebase/merge/branch]
Validation ?"
```

#### Cas 3 : Versions Multiples Fichier

```
Déclencher si :
- 2+ versions même fichier (file.ts, file-v2.ts, file.old.ts)
- Incertitude sur version production
- Tailles similaires mais contenus différents

Template question :
"Versions multiples :
1. [fichier 1] : [taille, date, contenu aperçu]
2. [fichier 2] : [taille, date, contenu aperçu]
ANALYSE : [différences]
Laquelle utiliser ?"
```

#### Cas 4 : Fichier Suspect (Temp/Debug)

```
Déclencher si :
- Nom contient .tmp, .temp, .test, .debug
- Taille < 100 bytes
- Non versionné Git
- Contenu vide/placeholder

Template question :
"⚠️ Fichier suspect détecté :
[fichier] : [caractéristiques alertes]
VERSION PROD trouvée : [alternative]
Utiliser [alternative] ?"
```

#### Cas 5 : Opération Potentiellement Destructive

```
Déclencher si :
- git clean requis sur fichiers > 1KB
- git reset --hard envisagé
- Suppression fichier versionné
- Modification fichier critique système

Template question :
"⚠️ Opération destructive :
COMMANDE : [commande Git]
IMPACT : [fichiers affectés]
RÉVERSIBILITÉ : [oui/non + méthode]
BACKUP : [existant oui/non]
Confirmer ?"
```

#### Cas 6 : Doute sur Stratégie

```
Déclencher si :
- Incertitude meilleure approche
- Plusieurs solutions possibles
- Risque choix impactant projet

Template question :
"Stratégie à valider :
CONTEXTE : [situation]
OPTIONS :
1. [option 1] : [pros/cons]
2. [option 2] : [pros/cons]
RECOMMANDATION : [choix préféré + justification]
Validation ?"
```

### 7.2 Mode Escalation

**Procédure si situation complexe** :

```bash
# 1. ARRÊTER immédiatement opération en cours

# 2. DOCUMENTER état actuel
git status > /tmp/git-state.txt
git log --oneline -20 >> /tmp/git-state.txt
git branch -vv >> /tmp/git-state.txt
git remote -v >> /tmp/git-state.txt

# 3. SAUVEGARDER état
git stash save "Emergency stash before escalation $(date +%Y%m%d-%H%M%S)"
git branch escalation-backup-$(date +%Y%m%d-%H%M%S)

# 4. PRÉPARER contexte pour utilisateur
cat > /tmp/escalation-context.md << EOF
# Escalation Requise

## Situation
[Décrire problème rencontré]

## État Actuel
\`\`\`
$(cat /tmp/git-state.txt)
\`\`\`

## Problème
[Explication détaillée]

## Solutions Envisagées
1. **Option A** : [description]
   - Pros : [avantages]
   - Cons : [inconvénients]
   - Risques : [risques]

2. **Option B** : [description]
   - Pros : [avantages]
   - Cons : [inconvénients]
   - Risques : [risques]

## Recommandation
[Choix préféré + justification]

## Sauvegardes Créées
- Stash : Emergency stash before escalation [timestamp]
- Branch : escalation-backup-[timestamp]
EOF

# 5. ask_followup_question avec contexte complet
```

### 7.3 Récupération d'Urgence

**Si opération destructive exécutée par erreur** :

```bash
# 1. NE PAS PANIQUER
# 2. NE PAS exécuter d'autres commandes Git

# 3. Vérifier reflog (historique complet)
git reflog | head -50

# 4. Identifier commit avant erreur
# Chercher entrée reflog avant opération destructive

# 5. Créer branche sauvegarde immédiatement
git branch emergency-recovery-$(date +%Y%m%d-%H%M%S) <commit-hash-avant-erreur>

# 6. Si fichiers supprimés non commités
# Vérifier fsck pour objets orphelins
git fsck --lost-found

# 7. INFORMER utilisateur IMMÉDIATEMENT
# ask_followup_question en mode urgence
```

**Template notification urgence** :

```
🚨 INCIDENT CRITIQUE : Opération destructive exécutée

COMMANDE : [commande exécutée]
IMPACT : [fichiers/commits affectés]

RÉCUPÉRATION EFFECTUÉE :
✅ Reflog consulté
✅ Branche recovery créée : emergency-recovery-[timestamp]
✅ Objects orphelins identifiés (si applicable)

PROCHAINES ÉTAPES :
[Options de récupération]

BESOIN VALIDATION URGENTE
```

---

## 📋 Section 8 : Exemples Pratiques

### 8.1 Exemple : Push Sécurisé Complet

```bash
#!/bin/bash
# Exemple workflow push sécurisé

# 1. Vérifier état local
echo "1️⃣ Vérification état local..."
git status

# Clean working tree requis
if ! git diff-index --quiet HEAD --; then
    echo "❌ Working tree not clean. Commit or stash changes first."
    exit 1
fi

# 2. Vérifier commits à push
echo "2️⃣ Commits à push..."
git log --oneline origin/main..HEAD

# Demander confirmation si >5 commits
commit_count=$(git rev-list --count origin/main..HEAD)
if [ "$commit_count" -gt 5 ]; then
    echo "⚠️ $commit_count commits à push"
    read -p "Continuer ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 3. Fetch et analyser remote
echo "3️⃣ Fetch origin..."
git fetch origin

# 4. Vérifier divergence
echo "4️⃣ Vérification divergence..."
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u})
BASE=$(git merge-base @ @{u})

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "✅ Déjà à jour"
    exit 0
elif [ "$LOCAL" = "$BASE" ]; then
    echo "❌ Remote ahead. Pull requis."
    
    # Montrer commits distants
    echo "Commits sur origin/main:"
    git log HEAD..origin/main --oneline
    
    # ask_followup_question
    echo "QUESTION UTILISATEUR :"
    echo "Il y a $(git rev-list --count HEAD..origin/main) commits sur origin/main."
    echo "Options:"
    echo "1. Pull --rebase (recommandé si commits atomiques)"
    echo "2. Pull --merge (recommandé si feature complexe)"
    echo "3. Examiner diff détaillé"
    
    read -p "Choix (1/2/3) : " choice
    
    case $choice in
        1)
            echo "Exécution: git pull --rebase origin main"
            git pull --rebase origin main
            ;;
        2)
            echo "Exécution: git pull --merge origin main"
            git pull --merge origin main
            ;;
        3)
            echo "Diff détaillé:"
            git log HEAD..origin/main --stat
            exit 0
            ;;
        *)
            echo "Choix invalide"
            exit 1
            ;;
    esac
    
    # Vérifier si conflits
    if ! git diff-index --quiet HEAD --; then
        echo "⚠️ Conflits détectés. Résolution requise."
        git status
        exit 1
    fi
    
elif [ "$REMOTE" = "$BASE" ]; then
    echo "✅ Local ahead. Push autorisé."
else
    echo "❌ Divergence détectée"
    echo "Local et remote ont divergé:"
    git log --left-right --oneline HEAD...@{u}
    exit 1
fi

# 5. Push
echo "5️⃣ Push vers origin/main..."
git push origin main

# 6. Vérifier succès
if [ $? -eq 0 ]; then
    echo "✅ Push réussi"
else
    echo "❌ Push échoué"
    exit 1
fi
```

### 8.2 Exemple : Résolution Conflit Intelligente

```bash
#!/bin/bash
# Exemple résolution conflit

# Scénario : Conflit lors de pull rebase
git pull --rebase origin main

# Output :
# Auto-merging src/config.ts
# CONFLICT (content): Merge conflict in src/config.ts
# error: could not apply a1b2c3d... feat: update timeout

echo "1️⃣ Conflit détecté. Analyse..."

# 1. Identifier fichiers en conflit
conflicted_files=$(git diff --name-only --diff-filter=U)
echo "Fichiers en conflit:"
echo "$conflicted_files"

# 2. Pour chaque fichier
for file in $conflicted_files; do
    echo ""
    echo "=== Analyse: $file ==="
    
    # Extraire versions
    git show HEAD:"$file" > /tmp/local_version.txt 2>/dev/null
    git show origin/main:"$file" > /tmp/remote_version.txt 2>/dev/null
    
    # Comparer
    echo "--- Différences ---"
    diff -u /tmp/local_version.txt /tmp/remote_version.txt | head -50
    
    # Analyser type conflit
    if grep -q "<<<<<<< HEAD" "$file"; then
        echo "Marqueurs conflit détectés. Résolution manuelle requise."
        
        # Afficher contexte conflit
        echo "--- Contexte conflit ---"
        grep -B5 -A5 "<<<<<<< HEAD" "$file"
        
        echo ""
        echo "ANALYSE REQUISE :"
        echo "1. Les modifications sont-elles sur lignes différentes ?"
        echo "2. Les modifications sont-elles complémentaires ?"
        echo "3. Y a-t-il contradiction logique ?"
        
        # ask_followup_question
        echo ""
        echo "QUESTION UTILISATEUR :"
        echo "Fichier: $file"
        echo "Stratégie de résolution :"
        echo "1. Merger intelligemment (intégrer les deux)"
        echo "2. Garder version locale (HEAD)"
        echo "3. Garder version distante (origin/main)"
        echo "4. Examiner en détail avec diff tool"
        
        read -p "Choix (1/2/3/4) : " choice
        
        case $choice in
            1)
                echo "Résolution manuelle requise."
                echo "Ouvrir $file dans éditeur pour merger."
                ${EDITOR:-nano} "$file"
                
                # Vérifier résolution
                if grep -q "<<<<<<< HEAD" "$file"; then
                    echo "❌ Marqueurs conflit toujours présents"
                    exit 1
                fi
                
                git add "$file"
                echo "✅ Conflit résolu : $file"
                ;;
            2)
                # Sauvegarder version distante
                cp "$file" "${file}.remote-backup-$(date +%Y%m%d-%H%M%S)"
                
                git checkout --ours "$file"
                git add "$file"
                echo "✅ Version locale gardée : $file"
                echo "Backup distant : ${file}.remote-backup-*"
                ;;
            3)
                # Sauvegarder version locale
                cp "$file" "${file}.local-backup-$(date +%Y%m%d-%H%M%S)"
                
                git checkout --theirs "$file"
                git add "$file"
                echo "✅ Version distante gardée : $file"
                echo "Backup local : ${file}.local-backup-*"
                ;;
            4)
                echo "Diff détaillé :"
                git diff "$file"
                exit 0
                ;;
            *)
                echo "Choix invalide"
                exit 1
                ;;
        esac
    fi
done

# 3. Continuer rebase
echo ""
echo "2️⃣ Tous conflits résolus. Continuer rebase..."
git rebase --continue

# 4. Vérifier succès
if [ $? -eq 0 ]; then
    echo "✅ Rebase réussi"
    
    # Commit message documenter résolution
    echo "Message commit suggéré :"
    echo "merge: Résolution conflits après rebase"
    echo ""
    echo "Fichiers résolus :"
    for file in $conflicted_files; do
        echo "- $file"
    done
else
    echo "❌ Rebase échoué"
    exit 1
fi
```

### 8.3 Exemple : Création Fichier Sécurisée

```bash
#!/bin/bash
# Exemple création fichier sécurisée

NEW_FILE="src/features/auth/login.ts"

echo "1️⃣ Vérification existence fichier..."

# 1. Recherche exhaustive
echo "Recherche exacte..."
exact_match=$(find . -name "login.ts" -type f)

if [ -n "$exact_match" ]; then
    echo "⚠️ Fichier login.ts déjà existe :"
    echo "$exact_match"
    
    # Examiner chaque match
    for file in $exact_match; do
        echo ""
        echo "=== $file ==="
        ls -lh "$file"
        echo "Contenu (début) :"
        head -20 "$file"
        echo "Historique Git :"
        git log --oneline -5 -- "$file" 2>/dev/null || echo "Non versionné"
    done
    
    # ask_followup_question
    echo ""
    echo "QUESTION UTILISATEUR :"
    echo "Fichier(s) login.ts trouvé(s). Action :"
    echo "1. Utiliser fichier existant (pas de création)"
    echo "2. Créer nouveau fichier avec nom différent"
    echo "3. Écraser fichier existant (BACKUP créé)"
    
    read -p "Choix (1/2/3) : " choice
    
    case $choice in
        1)
            echo "✅ Utilisation fichier existant"
            exit 0
            ;;
        2)
            read -p "Nouveau nom de fichier : " new_name
            NEW_FILE="src/features/auth/$new_name"
            ;;
        3)
            # Backup
            for file in $exact_match; do
                backup="${file}.backup-$(date +%Y%m%d-%H%M%S)"
                cp "$file" "$backup"
                echo "✅ Backup créé : $backup"
            done
            ;;
        *)
            echo "Choix invalide"
            exit 1
            ;;
    esac
fi

# 2. Recherche pattern similaire
echo ""
echo "2️⃣ Recherche patterns similaires..."
similar=$(find . -name "*login*" -type f)

if [ -n "$similar" ]; then
    echo "Fichiers similaires trouvés :"
    echo "$similar"
    
    # Demander confirmation
    read -p "Continuer création de $NEW_FILE ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# 3. Vérifier historique Git
echo ""
echo "3️⃣ Vérification historique Git..."
git_history=$(git log --all --full-history -- '**/login.ts' 2>/dev/null)

if [ -n "$git_history" ]; then
    echo "⚠️ login.ts a existé dans l'historique :"
    git log --all --oneline --full-history -- '**/login.ts'
    
    # Vérifier si supprimé
    deleted=$(git log --all --diff-filter=D --oneline -- '**/login.ts')
    if [ -n "$deleted" ]; then
        echo ""
        echo "Fichier a été SUPPRIMÉ dans :"
        echo "$deleted"
        
        # Voir raison suppression
        echo "Message commit suppression :"
        git log --all --diff-filter=D -1 --format="%B" -- '**/login.ts'
        
        # ask_followup_question
        echo ""
        echo "QUESTION UTILISATEUR :"
        echo "login.ts a été supprimé intentionnellement."
        echo "Voulez-vous vraiment le recréer ?"
        read -p "Confirmer (y/N) : " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
fi

# 4. Créer répertoire si nécessaire
echo ""
echo "4️⃣ Création répertoire si nécessaire..."
mkdir -p "$(dirname "$NEW_FILE")"

# 5. Créer fichier
echo ""
echo "5️⃣ Création fichier : $NEW_FILE"

cat > "$NEW_FILE" << 'EOF'
/**
 * Login feature implementation
 * Created: $(date +%Y-%m-%d)
 */

export class LoginService {
  async login(username: string, password: string): Promise<void> {
    // TODO: Implement login logic
    throw new Error('Not implemented');
  }
}
EOF

echo "✅ Fichier créé : $NEW_FILE"

# 6. Vérifier résultat
echo ""
echo "6️⃣ Vérification..."
ls -lh "$NEW_FILE"
echo "Contenu :"
cat "$NEW_FILE"

# 7. Git add
echo ""
read -p "Ajouter à Git ? (y/N) " -n 1 -r
echo
if [[
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git add "$NEW_FILE"
    echo "✅ Ajouté à Git : $NEW_FILE"
fi
```

---

## 📋 Section 9 : Intégration Architecture Roo

### 9.1 Lien avec Protocole SDDD

Cette spécification est un **complément critique** au [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md).

**Synergie avec SDDD** :

```
SDDD Niveau 1 (File Grounding)
    ↓
Git Safety : Vérifier état dépôt (git status, git ls-files)
    ↓
SDDD Niveau 2 (Semantic Grounding)
    ↓
Git Safety : Rechercher conventions Git (codebase_search "git workflow")
    ↓
SDDD Niveau 3 (Conversational Grounding)
    ↓
Git Safety : Consulter historique opérations Git (roo-state-manager)
    ↓
SDDD Niveau 4 (Project Grounding)
    ↓
Git Safety : Vérifier CONTRIBUTING.md, .github/workflows
```

**Application conjointe** :

1. **Avant toute opération Git** : Grounding SDDD complet
2. **Pendant opération Git** : Règles sécurité cette spec
3. **Après opération Git** : Documentation SDDD (checkpoint si besoin)

### 9.2 Intégration Global Instructions

**Ajouts recommandés** pour global-instructions (ou templates modes) :

```markdown
## 🚨 Git Safety & Source Control

**RÈGLES CRITIQUES** : Application obligatoire tous modes

### Avant TOUTE Opération Git

1. **Grounding Maximal** : Vérifier état complet
   ```bash
   git status && git fetch origin && git log --oneline -10
   ```

2. **Pas de Raccourcis Dangereux** : Interdictions strictes
   - ❌ `git push --force` ou `--force-with-lease`
   - ❌ `git reset --hard` sans backup
   - ❌ `git clean -fdx` sans analyse
   - ❌ `git checkout --theirs/--ours` aveugle

3. **Pull Avant Push** : TOUJOURS synchroniser
   ```bash
   git fetch origin → Analyser divergence → Pull/rebase → Push
   ```

4. **Résolution Conflits Intelligente** :
   - ✅ Merger manuellement si compatible
   - ✅ ask_followup_question si incertitude
   - ❌ Jamais --theirs/--ours sans validation

5. **Vérification Fichiers** :
   - Rechercher existence (find, git log --all)
   - Examiner contenu avant modification
   - Backup si modification fichier existant
   - ask_followup_question si versions multiples

**Référence complète** : [`roo-config/specifications/git-safety-source-control.md`](../specifications/git-safety-source-control.md)
```

### 9.3 Instructions Mode-Specific

#### Pour Modes manipulant Git (Code, Orchestrator)

**Ajout dans instructions mode** :

```markdown
### Git Operations - Safety Protocol

**BEFORE any Git operation, you MUST**:

1. Execute grounding sequence:
   - `git status` (verify working tree)
   - `git fetch origin` (check remote state)
   - `git log HEAD..origin/main` (analyze divergence)

2. Apply safety rules from [`git-safety-source-control.md`](../../roo-config/specifications/git-safety-source-control.md):
   - NO `--force` without explicit user validation
   - NO destructive operations without backup
   - NO blind conflict resolution (--theirs/--ours)

3. If doubt or complex situation:
   - Use `ask_followup_question` with detailed context
   - Propose multiple options with pros/cons
   - Wait for user validation before executing

**Remember**: Data loss prevention is PRIORITY #1. When in doubt, ask.
```

### 9.4 Formation et Rappels

**Au début de chaque tâche impliquant Git** :

```markdown
🚨 **Git Safety Reminder**

Cette tâche implique des opérations Git. Protocole de sécurité :

1. ✅ Vérifier état dépôt AVANT toute action
2. ✅ Pull AVANT push (toujours)
3. ✅ Résoudre conflits intelligemment (pas --theirs/--ours aveugle)
4. ✅ Vérifier fichiers AVANT création/modification
5. ✅ ask_followup_question si doute

❌ Opérations INTERDITES sans validation :
- git push --force
- git reset --hard (branche partagée)
- git clean -fdx (sans analyse)
- git checkout --theirs/--ours (aveugle)

📋 Checklists disponibles : Section 6 de [`git-safety-source-control.md`](../../roo-config/specifications/git-safety-source-control.md)
```

### 9.5 Validation Pré-Completion

**Avant `attempt_completion` de tâche Git** :

```markdown
### Git Safety Pre-Completion Checklist

Avant de finaliser cette tâche, vérifier :

[ ] Tous les commits sont descriptifs (conventional commits)
[ ] Pas de commits temporaires (WIP, temp) sur branche partagée
[ ] Pas de fichiers sensibles committé (.env, secrets)
[ ] Working tree clean (`git status`)
[ ] Push réussi (si applicable)
[ ] Pas d'utilisation --force
[ ] Conflits résolus intelligemment (documentation dans commits)
[ ] Backups créés pour modifications critiques
[ ] Documentation mise à jour (si changements workflow Git)

Si UN seul item non validé → Ne PAS attempt_completion
```

---

## 📋 Section 10 : Métriques et Amélioration Continue

### 10.1 Indicateurs de Sécurité

**Métriques à tracker** (via roo-state-manager) :

```json
{
  "git_safety_metrics": {
    "operations_safe": {
      "pull_before_push": 0,
      "conflicts_resolved_intelligently": 0,
      "files_verified_before_modification": 0,
      "backups_created": 0
    },
    "incidents_prevented": {
      "force_push_blocked": 0,
      "destructive_command_avoided": 0,
      "blind_conflict_resolution_prevented": 0,
      "multiple_versions_detected": 0
    },
    "escalations": {
      "user_validation_requested": 0,
      "complex_conflicts": 0,
      "file_existence_doubts": 0
    }
  }
}
```

### 10.2 Patterns d'Incidents

**Analyser périodiquement** :

```bash
# Via roo-state-manager
use_mcp_tool roo-state-manager roosync_search \
  --action "semantic" \
  --search_query "git conflict error problem" \
  --max_results 50

# Identifier patterns :
# - Quels types de conflits récurrents ?
# - Quelles opérations causent incidents ?
# - Quels fichiers souvent en conflit ?
```

**Action** : Mettre à jour cette spec avec nouveaux patterns identifiés

### 10.3 Révision Spécification

**Cette spécification doit être révisée** :

- ✅ Après chaque incident Git majeur
- ✅ Tous les 6 mois (minimum)
- ✅ Quand nouveaux patterns identifiés
- ✅ Lors d'ajout nouveaux outils Git (MCP, scripts)

**Process révision** :

1. Analyser incidents depuis dernière révision
2. Identifier lacunes dans spec actuelle
3. Proposer ajouts/modifications
4. Valider avec équipe/utilisateurs
5. Mettre à jour spec + version

---

## 📋 Conclusion

### Résumé Exécutif

Cette spécification **Git Safety & Source Control** établit des règles strictes pour prévenir les pertes de données causées par des opérations Git imprudentes.

**Principes fondamentaux** :

1. 🔍 **Grounding Maximal** : Vérifier AVANT d'agir
2. 🚫 **Pas de Raccourcis** : Interdictions strictes (--force, --theirs/--ours)
3. ✅ **Pull Avant Push** : Toujours synchroniser
4. 🧠 **Résolution Intelligente** : Analyser, pas automatiser aveuglément
5. 💾 **Backup Systématique** : Sauvegarder avant toute modification

**Couverture incidents** :

- ✅ Push force avec réécriture historique
- ✅ Destruction fichiers non-versionnés (git clean)
- ✅ Contamination multi-agents
- ✅ Exposition secrets dans historique
- ✅ Conflits résolus aveuglément
- ✅ Versions multiples fichiers non détectées

**Application** :

- **Tous les modes** manipulant Git (Code, Orchestrator, etc.)
- **Intégration** avec protocole SDDD existant
- **Checklists** utilisables immédiatement
- **Escalation** claire vers utilisateur

### Prochaines Étapes

1. ✅ Spécification créée : [`git-safety-source-control.md`](git-safety-source-control.md)
2. ⏳ Intégrer recommandations dans global-instructions.md
3. ⏳ Créer checklists pratiques extractibles
4. ⏳ Former agents sur protocoles sécurité
5. ⏳ Monitorer application + métriques

### Références

- **Incidents documentés** :
  - [`docs/fixes/git-recovery-report-20250925.md`](../../docs/fixes/git-recovery-report-20250925.md)
  - [`roo-code-customization/incident-report-condensation-revert.md`](../../roo-code-customization/incident-report-condensation-revert.md)
  - [`docs/missions/2025-09-21-rapport-mission-restauration-git-critique-sddd.md`](../../docs/missions/2025-09-21-rapport-mission-restauration-git-critique-sddd.md)

- **Spécifications liées** :
  - [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
  - [`operational-best-practices.md`](operational-best-practices.md)
  - [`mcp-integrations-priority.md`](mcp-integrations-priority.md)

- **Scripts sécurité Git** :
  - [`scripts/git-safe-operations.ps1`](../../scripts/git-safe-operations.ps1)

---

**Version** : 1.0.0  
**Dernière mise à jour** : 07 Octobre 2025  
**Statut** : ✅ Spécification validée - Application obligatoire

**Mainteneur** : Architecture Team  
**Contact** : Voir [`roo-config/specifications/README.md`](README.md)

---

*Cette spécification sauvera des données. Appliquez-la systématiquement.* 🛡️