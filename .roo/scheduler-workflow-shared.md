# Scheduler Workflow — Preamble Partagé

> **Lu par TOUS les orchestrateurs scheduler** (coordinator, executor, meta-analyst).
> Ce fichier contient les règles communes. Les workflows spécifiques gardent uniquement leur logique propre.

---

## ⚠️ RÈGLE #1 - AUTONOMIE ABSOLUE (ZÉRO QUESTION)

**Tu es 100% AUTONOME. Tu n'as AUCUN droit de poser une question à l'utilisateur.**

### ❌ INTERDIT (bloque le scheduler IMMEDIATEMENT)

```
"Pourriez-vous copier le contenu du fichier ?"       # Demande de contenu
"Veux-tu que je continue ?"                           # Demande de confirmation
"Dois-je procéder à l'exécution ?"                    # Demande de permission
"Voulez-vous que je fasse X ?"                        # Demande de validation
"Confirmez-vous que..."                               # Demande de confirmation
"Que préférez-vous ?"                                 # Demande de choix
```

**Pourquoi ?** Le scheduler tourne SANS utilisateur. Toute question bloque indéfiniment.

### ✅ TOUJOURS FAIRE (agir directement)

- Besoin de lire un fichier → **déléguer via `new_task`** à ask-simple ou code-simple
- Besoin de décider → **décider soi-même** selon le workflow
- Besoin de confirmer → **agir directement** sans demander
- Outil échoue → **déléguer à un autre mode** qui a l'outil, JAMAIS demander à l'utilisateur

### RÈGLE #2 : Propagation aux sous-tâches

**TOUTES les sous-tâches créées via `new_task` doivent commencer par :**
```
REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question,
JAMAIS demander confirmation. Agis directement.

IMPORTANT - Contraintes GitHub CLI en mode -simple:
- JAMAIS utiliser `gh api graphql` (quoting JSON instable en -simple via win-cli)
- Utiliser UNIQUEMENT: gh issue list, gh issue view, gh pr list, gh pr view
- Si GraphQL absolument necessaire ? escalader vers -complex ou reporter IMPOSSIBLE
```

**Il n'y a AUCUNE exception à cette règle.**

---

## 🛑 CIRCUIT BREAKER - Anti-Boucle d'Échecs (Issue #737)

**Si un outil échoue 2 fois de suite avec la même erreur → ABANDONNER cette action.**

| Échecs consécutifs | Action |
|--------------------|--------|
| 1 | Réessayer UNE FOIS avec syntaxe simplifiée |
| 2 | **STOP** — Abandonner cette sous-tâche, passer à la suivante |
| 3+ | **INTERDIT** — Ne JAMAIS réessayer plus de 2 fois |

### Cas spécifiques

**502 Retry Death Spiral (Issue #1783) :**
- Si l'API retourne des erreurs 502 persistantes (3+ erreurs 502 consécutives) → **ABANDONNER la tâche immédiatement**
- **NE PAS** réessayer indéfiniment — le retry automatique de Roo Code n'a pas de circuit breaker natif
- **Action :** `attempt_completion(result: "ECHEC: API 502 persistant (death spiral détecté). Tâche abandonnée après N erreurs 502.")`
- Signaler sur le dashboard : `roosync_dashboard(action: "append", type: "workspace", tags: ["CRITICAL", "roo-scheduler"], content: "502 death spiral détecté — tâche abandonnée")`
- **Seuil :** Après 5 erreurs 502 consécutives → STOP définitif, ne pas reprendre cette tâche ce cycle

**MCP critique HS en mode `-simple` (#1181) :**
- Si win-cli MCP échoue 2 fois → **NE PAS utiliser `ask_followup_question`**
- **Action :** `attempt_completion(result: "ECHEC: MCP win-cli non disponible après 2 tentatives. Rapporté sur dashboard.")`
- Signaler sur le dashboard : `roosync_dashboard(action: "append", type: "workspace", tags: ["CRITICAL", "roo-scheduler"], content: "...")`
- **JAMAIS** `ask_followup_question` en mode scheduler — l'utilisateur n'est pas là

**`gh api graphql` en mode `-simple` via win-cli (Issue #1288) :**
- **INTERDIT EN -SIMPLE** : Quoting JSON instable via win-cli. JAMAIS réessayer (même avec quoting différent).
- **1 échec graphql** → **STOP immédiatement, escalader vers `-complex`** qui a le terminal natif
- **Commandes autorisées UNIQUEMENT** : `gh issue list`, `gh issue view`, `gh pr list`, `gh pr view`
- **Si GraphQL nécessaire** : Escalader ou signaler "GraphQL IMPOSSIBLE en -simple"
- ⚠️ **Anti-boucle critique** : Ne JAMAIS reessayer la meme commande graphql >1 fois. La 2e tentative = STOP.

**Condensation qui échoue :**
- Si erreur (token limit, API error) → **NE PAS réessayer**
- Terminer avec `attempt_completion` immédiatement
- Écrire `[WARN] Condensation failed` dans le rapport dashboard

---

## 🚨 RÈGLE OBLIGATOIRE - LIMITATION D'OUTPUT (Issue #707)

**TOUJOURS limiter l'output des commandes shell** (GLM : 131k tokens réels).

```bash
# GIT LOG — TOUJOURS avec head -30 ou équivalent
execute_command(shell="gitbash", command="git log --oneline -30")

# GIT DIFF — TOUJOURS limiter
execute_command(shell="gitbash", command="git diff --stat | head -30")

# VITEST — TOUJOURS tronquer
execute_command(shell="powershell", command="...npx vitest run 2>&1 | Select-Object -Last 30")

# AUTRES COMMANDES À OUTPUT LONG — TOUJOURS limiter
execute_command(shell="powershell", command="... | Select-Object -Last 30")
execute_command(shell="gitbash", command="... | tail -30")
```

**⛔ INTERDIT :**
- `git log` sans `-N` ou `| head -N` ou `--since`
- `git diff` complet sans filtre
- `--coverage` dans les tests (output 600KB = saturation contexte)
- `npx vitest run` sans `2>&1 | Select-Object -Last 30`

---

## REGLES WIN-CLI (CRITIQUE)

Les modes `-simple` n'ont PAS accès au terminal natif. **Toujours inclure ces instructions dans les prompts `new_task`** :

```
# Build/Tests :
execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npm run build")
execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npx vitest run 2>&1 | Select-Object -Last 30")

# Git :
execute_command(shell="gitbash", command="git pull --no-rebase origin main")
execute_command(shell="gitbash", command="git status")

# GitHub CLI :
execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --state open --limit 10 --json number,title,labels")
```

**ATTENTION** : Ne PAS piper vers des commandes PowerShell complexes. Privilégier des commandes simples ou plusieurs appels séparés.

---

## RAPPORT DASHBOARD (OBLIGATOIRE en fin de cycle)

> **CRITIQUE** : Le rapport est la seule trace du passage du scheduler. **Ne JAMAIS quitter sans avoir écrit le rapport.**

### Format

```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["{DONE|MAINTENANCE|IDLE|META-ANALYSIS}", "{roo-scheduler|roo-meta}"],
  content: "### [{MACHINE}] Bilan scheduler {role}\n\nGit: {OK/erreur} | Build: {OK/FAIL} | Tests: {X}p/{Y}f\nTâches: {N} ({source}) | Erreurs: {aucune ou 1 ligne}"
)
```

### Tags d'identification auteur (OBLIGATOIRES)

| Tag | Source |
|-----|--------|
| `roo-scheduler` | Roo orchestrateur coordinator/executor |
| `roo-meta` | Roo meta-analyste |
| `claude-scheduled` | Claude Worker schtask |
| `claude-interactive` | Claude Code interactif |

### Fallback si dashboard MCP échoue

1. `roosync_dashboard(action: "append", ...)` — retenter une fois
2. Si toujours échec : écrire dans `.claude/local/INTERCOM-{MACHINE}.md` via `apply_diff`
3. **NE JAMAIS** utiliser `write_to_file` (écrase le contenu)

---

## TERMINER LE CYCLE (OBLIGATOIRE)

> **CRITIQUE :** L'orchestrateur DOIT appeler `attempt_completion` pour marquer la tâche comme terminée. Sans cela, le scheduler considère la tâche "en cours" et SAUTE les prochains ticks (`taskInteraction: "skip"`).

```
attempt_completion(result: "Cycle {role} terminé. Bilan posté dans dashboard workspace.")
```

**Si oublié**, la fréquence du scheduler passe de {6h/8h/72h} à ~24h+ car chaque tick suivant est sauté.

---

## VEILLE ACTIVE — Patrouille Proactive avec Auto-Réparation (Mandate #1886)

**Contraintes OBLIGATOIRES :**

1. **Max 1 patrol/hour** — Si moins d'1h depuis la dernière patrol, PASSER cette étape
2. **Auto-réparation LIMITÉE** — Seulement pour les cas explicitement autorisés (voir ci-dessous)
3. **Rapport obligatoire** — Poster `[PATROL]` si OK, `[FRICTION-FOUND]` si problème détecté
4. **Création d'issue automatique** — SEULEMENT pour échecs critiques (tests, build)

**Domaines de patrol avec auto-réparation :**

| # | Domaine | Méthode | Auto-fix autorisé ? |
|---|---------|---------|---------------------|
| 1 | Santé build + tests | `npm run build` + `npx vitest run` | **NON** → créer issue GitHub automatiquement |
| 2 | Fichiers non-commités | `git status` + dates fichiers | **NON** → rapport dashboard uniquement |
| 3 | Imports morts | Comparer exports/imports dans src/ | **NON** → rapport dashboard uniquement |
| 4 | Sync schedules.json | Vérifier âge fichier vs sources | **OUI** → régénérer si décalé |

**Règles d'auto-réparation :**

- **schedules.json** : SEUL auto-fix autorisé (règle simple : régénérer depuis sources)
- **Tests/Build échoués** : Créer issue GitHub avec label `needs-approval` + `patrol` (pas de fix automatique)
- **Autres problèmes** : Rapport dashboard uniquement (`[FRICTION-FOUND]`)

**Ce que la patrol N'EST PAS :**
- PAS un nettoyage (parasite cleanup = Etape 2b-idle du executor)
- PAS une consolidation (consolidation = tâche séparée)
- PAS un fix généralisé (auto-fix LIMITÉ à schedules.json)

---

## SÉCURITÉ COMMUNE

1. Ne JAMAIS commit sans validation
2. Ne JAMAIS push directement
3. **Ne JAMAIS faire `git checkout` dans le submodule `mcps/internal/`** — corrompt le pointer submodule
4. **RooSync** : Dashboard workspace (`roosync_dashboard(type: "workspace")`) pour communication. Fichiers INTERCOM locaux = DEPRECATED.
5. Après 2 échecs sur même tâche : arrêter et rapporter
6. **JAMAIS `write_to_file` pour fichiers >200 lignes** : Utiliser `apply_diff` ou `replace_in_file`
7. **JAMAIS `--coverage`** dans les tests (output trop volumineux)
8. **Ignorer les [TASK] de plus de 24h** (coordinator/executor uniquement)
