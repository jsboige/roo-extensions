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
roosync_messages(action: "send", to: "all", subject: "[FRICTION] Description", body: "...", tags: ["friction"])
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
- **Consensus ou majorite des agents** (propositions d'amelioration)
- **Rejet si :** feature creep, complexite, probleme theorique

## Proposition d'Amelioration (heritage `FEEDBACK_PROCESS.md`)

**Principe :** evolution prudente et collective, pour eviter le feature creep.

1. **Identification** (n'importe quel agent)
   - reperer un probleme/friction dans le workflow actuel
   - documenter l'experience concrete
   - proposer une amelioration specifique et minimaliste
2. **Consultation collective** (via RooSync)
   - message `to: "all"` avec sujet `[FEEDBACK] Amelioration proposee: <titre>`
   - contexte, proposition concrete, risques de feature creep
   - demander un avis critique (24-48 h)
3. **Collecte des retours**
   - focus : "Est-ce vraiment necessaire ?" et "Risques ?"
   - les agents servent de garde-fou contre le feature creep
4. **Decision finale** (coordinateur `myia-ai-01`)
   - synthetiser, decider : APPROUVER / REJETER / MODIFIER
   - si approuve : creer l'issue GitHub avec le label `workflow-improvement`
   - documenter la decision dans le thread RooSync
   - mettre a jour le fichier concerne (`.claude/commands/`, `skills/`, `agents/`)

---

**Source :** Promu depuis `.roo/rules/17-friction-protocol.md` (auto-load Roo)
**Consolidation :** section « Proposition d'Amelioration » issue de `feedback-process.md` / `FEEDBACK_PROCESS.md` (twins byte-identiques), archives le 2026-11-09 sous `docs/archive/doc-audit-2026-11-09/` (issue #2877).
