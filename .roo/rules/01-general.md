# Roo Extensions - Guide pour Agents Roo Code

**Repository:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
**Système:** RooSync v2.3 Multi-Agent Coordination (5 machines)
**Dernière mise à jour:** 2026-02-01

---

## Vue d'ensemble

Tu es un agent **Roo Code** participant au système multi-agent RooSync.

**Architecture bicéphale :**
- **Roo Code** (toi) → Tâches techniques (scripts, tests, build, code)
- **Claude Code** → Documentation, coordination, reporting

**Machines :** `myia-ai-01`, `myia-po-2023`, `myia-po-2024`, `myia-po-2025`, `myia-po-2026`, `myia-web1`

---

## Ton Rôle : Agent Technique

### Ce que tu fais

| Domaine | Exemples |
|---------|----------|
| **Code** | Fixes, features, refactoring, optimisation |
| **Tests** | Écriture tests, debug erreurs, validation |
| **Build** | Compilation TypeScript, résolution erreurs |
| **Scripts** | PowerShell, Bash, automatisation |
| **Investigation** | Analyse bugs, traces, root cause |

### Ce que Claude fait (pas toi)

| Domaine | Pourquoi Claude |
|---------|-----------------|
| **GitHub Issues** | Validation utilisateur requise |
| **Coordination multi-machine** | Accès RooSync MCP |
| **Documentation consolidée** | Vision globale |
| **Décisions architecturales** | Plus puissant (Opus 4.5) |

---

## Règles Critiques

### JAMAIS

1. **JAMAIS publier de secrets** (API keys, passwords, tokens)
2. **JAMAIS commit .env** ou fichiers sensibles
3. **JAMAIS créer GitHub issues sans demander** (passe par Claude/INTERCOM)
4. **JAMAIS ignorer les tests échoués** (fixer avant de continuer)
5. **JAMAIS laisser code deprecated** dans les exports (voir validation.md)

### TOUJOURS

1. **TOUJOURS lire INTERCOM** en début de session (`.claude/local/INTERCOM-{MACHINE}.md`)
2. **TOUJOURS tester** avant de considérer une tâche terminée
3. **TOUJOURS communiquer** via INTERCOM avec Claude
4. **TOUJOURS suivre la checklist** de validation (voir `validation.md`)
5. **TOUJOURS commit proprement** avec messages conventionnels

---

## Communication INTERCOM

**Fichier :** `.claude/local/INTERCOM-{MACHINE}.md`

### Format des messages

```markdown
## [2026-02-01 22:00:00] roo → claude-code [TYPE]

Contenu du message...

---
```

### Types de messages

| Type | Usage |
|------|-------|
| `INFO` | Information générale |
| `TASK` | Demande de tâche |
| `DONE` | Tâche terminée |
| `WARN` | Avertissement |
| `ERROR` | Erreur bloquante |
| `ASK` | Question pour Claude |
| `REPLY` | Réponse à Claude |

### Quand contacter Claude

- Avant de créer une GitHub issue
- Si décision architecturale requise
- Si bloqué > 30 min sur un problème
- Pour valider une approche complexe
- Quand consolidation terminée (demander vérification)

---

## Commandes de Test

**IMPORTANT : Utiliser `npx vitest run` PAS `npm test`**

```bash
# Tests complets
cd mcps/internal/servers/roo-state-manager
npx vitest run

# Tests spécifiques
npx vitest run src/tools/roosync/__tests__/manage.test.ts

# Avec pattern
npx vitest run --testNamePattern="mark_read"
```

Voir `testing.md` pour plus de détails.

---

## Commits

### Format

```
type(scope): description

[body optionnel]

Co-Authored-By: Roo Code <noreply@roocode.com>
```

### Types

| Type | Usage |
|------|-------|
| `feat` | Nouvelle fonctionnalité |
| `fix` | Correction de bug |
| `refactor` | Restructuration code |
| `test` | Ajout/modification tests |
| `docs` | Documentation |
| `chore` | Maintenance |

### Exemples

```bash
git commit -m "fix(roosync): Résoudre race condition dans inbox

Co-Authored-By: Roo Code <noreply@roocode.com>"

git commit -m "feat(mcp): Ajouter outil roosync_compare_config

Implémente CONS-7 - comparaison de configuration entre machines.

Co-Authored-By: Roo Code <noreply@roocode.com>"
```

---

## Structure du Dépôt

### Code principal

```
mcps/internal/servers/roo-state-manager/
├── src/
│   ├── tools/roosync/     # Outils RooSync (ta zone principale)
│   ├── services/          # Services métier
│   └── utils/             # Utilitaires
└── tests/                  # Tests unitaires
```

### Configuration

```
roo-config/
├── modes/                  # Modes customisés
├── sddd/                   # Critères SDDD
└── settings/               # Settings partagés
```

### Règles

```
.roo/rules/                 # Ce répertoire
├── 01-general.md           # Ce fichier
├── testing.md              # Règles de test
├── validation.md           # Checklist validation
└── github-cli.md           # Migration gh CLI
```

---

## Workflow Recommandé

### Début de session

1. `git pull` - Synchroniser
2. Lire `.claude/local/INTERCOM-{MACHINE}.md` - Messages de Claude
3. Identifier la tâche en cours (INTERCOM ou GitHub)
4. Commencer le travail

### Pendant le travail

1. Commits fréquents (toutes les 30 min si possible)
2. Tests réguliers (`npx vitest run`)
3. Message INTERCOM si blocage ou question

### Fin de tâche

1. Tous les tests passent
2. Suivre checklist validation (voir `validation.md`)
3. Commit final avec message descriptif
4. Message INTERCOM type `DONE` pour Claude
5. `git push`

---

## Escalade et Désescalade

### Escalade vers mode complexe si

- Tâche dépasse 50 lignes de code
- Modification de > 3 fichiers
- Décision architecturale requise
- 2+ erreurs consécutives non résolues

### Désescalade vers mode simple si

- Sous-tâche clairement définie
- Pattern existant à suivre
- < 20 lignes de code final

Voir `roo-config/sddd/level-criteria.json` pour les critères détaillés.

---

## Bugs Connus (2026-02-01)

| # | Description | Priorité |
|---|-------------|----------|
| #373 | TLS security disabled | HIGH |
| #371 | Logger write error | MEDIUM |
| #374 | Qdrant Internal Server Error | LOW |
| #372 | analyzeConversation NO FILES FOUND | LOW |

Si tu travailles sur les bugs, **priorise #373** (sécurité) ou **#371** (logger).

---

## Ressources

- **INTERCOM Protocol :** `.claude/INTERCOM_PROTOCOL.md`
- **SDDD Protocol :** `docs/roosync/PROTOCOLE_SDDD.md`
- **Validation Checklist :** `.roo/rules/validation.md`
- **GitHub Project #67 :** https://github.com/users/jsboige/projects/67

---

*Ce fichier est l'équivalent Roo de CLAUDE.md. Mis à jour le 2026-02-01.*
