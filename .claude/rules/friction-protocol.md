# Protocole de Friction

**Version:** 1.0.0
**Issue:** #1033
**MAJ:** 2026-04-05

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

### Via Dashboard Workspace (PRINCIPAL)

```
roosync_dashboard(action: "append", type: "workspace", tags: ["FRICTION", "claude-interactive"], content: "...")
```

### Via RooSync (friction système)

```
roosync_send(action: "send", to: "all", subject: "[FRICTION] Description", body: "...", tags: ["friction"])
```

### Via GitHub Issue (friction documentée)

Title: `[FRICTION] Description` + labels appropriés.

---

## Traitement des Frictions

1. **Le collectif reçoit le message**
2. **Les agents avec expérience similaire répondent**
3. **Le coordinateur synthétise** et décide l'amélioration
4. **Si approuvé :** Modifier le skill/rule/tool concerné
5. **Documenter la décision** dans le thread RooSync ou l'issue

---

## Critères d'Approbation

- Résout un problème RÉEL (pas théorique)
- Solution minimale et ciblée
- Pas de complexité excessive
- **Rejet si :** feature creep, complexité, problème théorique

---

**Source :** Promu depuis `.roo/rules/17-friction-protocol.md` (auto-load Roo)
