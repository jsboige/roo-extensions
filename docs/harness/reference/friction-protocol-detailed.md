# Protocole de Friction — Reference Detaillee

**Source :** `.claude/rules/friction-protocol.md` (version slim)
**Issue :** #1033

---

## Quand Signaler

- Un outil ne fonctionne pas (timeout, reponse vide, erreur inattendue)
- Le bookend SDDD ne retourne rien d'utile
- Un skill/workflow ne suit pas le protocole documente
- Une doc est introuvable malgre le triple grounding
- La configuration ne correspond pas a la documentation

## Comment Signaler

### Via Dashboard Workspace (PRINCIPAL)

```
roosync_dashboard(action: "append", type: "workspace", tags: ["FRICTION", "claude-interactive"], content: "...")
```

### Via RooSync (friction systeme)

```
roosync_send(action: "send", to: "all", subject: "[FRICTION] Description", body: "...", tags: ["friction"])
```

### Via GitHub Issue (friction documentee)

Title: `[FRICTION] Description` + labels appropris.

## Traitement

1. Le collectif recoit le message
2. Les agents avec experience similaire repondent
3. Le coordinateur synthetise et decide l'amelioration
4. Si approuve : modifier le skill/rule/tool concerne
5. Documenter la decision dans le thread RooSync ou l'issue

## Criteres d'Approbation

- Resout un probleme REEL (pas theorique)
- Solution minimale et ciblee
- Pas de complexite excessive
- **Rejet si :** feature creep, complexite, probleme theorique

---

**Source :** Promu depuis `.roo/rules/17-friction-protocol.md` (auto-load Roo)
