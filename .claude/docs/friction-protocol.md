# Protocole de Friction - Claude Code

**Version :** 1.0.0
**Créé :** 2026-03-15
**Issue :** #712 (basé sur .roo/rules/17-friction-protocol.md)

---

## Principe

**Tout agent Claude Code rencontrant une friction ou un problème avec les outils/workflows DOIT le signaler au collectif.**

Les skills évoluent par friction RÉELLE, pas par anticipation théorique.

---

## Quand Signaler

Signaler une friction quand :
- Un outil MCP ne fonctionne pas (timeout, réponse vide, erreur inattendue)
- Le bookend SDDD (`codebase_search`) ne retourne rien d'utile
- Un skill/command ne suit pas le protocole documenté
- Une doc est introuvable malgré le triple grounding
- La configuration ne correspond pas à la documentation
- Un pattern d'erreur se répète > 2 fois dans la même session

---

## Comment Signaler

### Via RooSync (friction système — à diffuser à toutes les machines)

```
roosync_send(
  action: "send",
  to: "all",
  subject: "[FRICTION] Description courte du problème",
  body: "## Problème\n[Description]\n\n## Contexte\n[Quelle tâche, quel outil, quel résultat]\n\n## Impact\n[Ce qui est bloqué ou dégradé]\n\n## Suggestion\n[Amélioration proposée si applicable]",
  tags: ["friction"]
)
```

### Via INTERCOM (friction locale — pour Roo sur la même machine)

```markdown
## [YYYY-MM-DD HH:MM:SS] claude-code -> roo [FRICTION-FOUND]

### Problème
[Description]

### Contexte
- Tâche : ...
- Outil : ...
- Résultat attendu : ...
- Résultat obtenu : ...

### Impact
[Ce qui est bloqué]

### Suggestion
[Proposition d'amélioration]

---
```

### Via GitHub Issue (friction à corriger — nécessite approbation)

Créer une issue avec :
- Title: `[FRICTION] Description`
- Label: `friction` + catégorie + `needs-approval`
- Body: Template complet (problème, contexte, impact, suggestion)

**Note :** Les issues HARNESS nécessitent aussi le label `harness-change`.

---

## Traitement des Frictions

1. **Le collectif reçoit le message** (toutes machines ou agents concernés)
2. **Les agents avec expérience similaire répondent** avec leur contexte
3. **Le coordinateur (myia-ai-01) synthétise** et décide l'amélioration
4. **Si approuvé :** Modifier le skill/rule/tool concerné (incrémental)
5. **Documenter la décision** dans le thread RooSync ou l'issue GitHub

---

## Critères d'Approbation

Une amélioration est approuvée si :
- Résout un problème RÉEL (pas théorique)
- Solution minimale et ciblée
- Pas de complexité excessive
- Consensus ou majorité des agents
- **Rejet si :** feature creep, complexité, problème théorique

---

## Documentation

- **Issue GitHub** avec label `workflow-improvement` ou `friction`
- **MAJ du fichier concerné** (`.claude/commands/`, `skills/`, `agents/`, `rules/`)
- **Commit** avec référence à l'issue ou au message RooSync

---

## Workflow Complet

```
1. Identification → Repérer problème/friction
2. Signalement → RooSync [FRICTION] to:all + INTERCOM [FRICTION-FOUND]
3. Consultation collective → 24-48h pour avis
4. Décision finale → Coordinateur synthétise
5. Documentation → Issue + MAJ fichiers + Commit
```

---

## Références

- [`.claude/docs/feedback-process.md`](feedback-process.md) — Processus d'amélioration continue
- [`.claude/rules/sddd-conversational-grounding.md`](../rules/sddd-conversational-grounding.md) — Section "Protocole de Friction"
- [`.claude/commands/executor.md`](../commands/executor.md) — Section "Protocole de friction (OBLIGATOIRE)"
- Équivalent Roo : `.roo/rules/17-friction-protocol.md`
