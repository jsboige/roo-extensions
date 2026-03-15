# Protocole de Friction

**Version :** 1.0.0
**Créé :** 2026-03-15
**Issue :** #710

---

## Principe

**Tout agent rencontrant une friction ou un problème avec les outils/workflows DOIT le signaler au collectif.**

Les skills évoluent par friction RÉELLE, pas par anticipation théorique.

---

## Quand Signaler

Signaler une friction quand :
- Un outil ne fonctionne pas (timeout, réponse vide, erreur inattendue)
- Le bookend SDDD ne retourne rien d'utile
- Un skill/workflow ne suit pas le protocole documenté
- Une doc est introuvable malgré le triple grounding
- La configuration ne correspond pas à la documentation

---

## Comment Signaler

### Via RooSync (friction système)

```
roosync_send(
  action: "send",
  to: "all",
  subject: "[FRICTION] Description courte du problème",
  body: "## Problème\n[Description]\n\n## Contexte\n[Quelle tâche, quel outil, quel résultat]\n\n## Impact\n[Ce qui est bloqué ou dégradé]\n\n## Suggestion\n[Amélioration proposée si applicable]",
  tags: ["friction"]
)
```

### Via INTERCOM (friction locale)

```markdown
## [YYYY-MM-DD HH:MM:SS] agent -> all [FRICTION]

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

### Via GitHub Issue (friction documentée)

Créer une issue avec :
- Title: `[FRICTION] Description`
- Label: `friction` + catégorie appropriée
- Body: Template complet (problème, contexte, impact, suggestion)

---

## Traitement des Frictions

1. **Le collectif reçoit le message** (toutes machines ou agents concernés)
2. **Les agents avec expérience similaire répondent** avec contexte
3. **Le coordinateur synthétise** et décide l'amélioration
4. **Si approuvé :** Modifier le skill/rule/tool concerné (incremental)
5. **Documenter la décision** dans le thread RooSync ou l'issue

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

- **Issue GitHub** avec label `workflow-improvement`
- **MAJ du fichier concerné** (.claude/commands/, skills/, agents/, rules/)
- **Commit** avec référence à l'issue ou au message RooSync

---

## Workflow Complet

```
1. Identification → Repérer problème/friction
2. Consultation collective → Message RooSync [FEEDBACK]
3. Collecte des retours → 24-48h pour avis
4. Décision finale → Coordinateur synthétise
5. Documentation → Issue + MAJ fichiers
```

---

**Références :**
- [`.claude/rules/feedback-process.md`](../../.claude/rules/feedback-process.md)
- [`.claude/rules/sddd-conversational-grounding.md`](../../.claude/rules/sddd-conversational-grounding.md) - Section "Protocole de Friction"
