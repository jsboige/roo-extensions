# Bidirectional Trigger — [WAKE-CLAUDE] / [WAKE-ROO]

**Status :** ⚠️ **DEPRECATED — Voir [`.claude/rules/wake-claude-routing.md`](../../../claude/rules/wake-claude-routing.md) pour le contrat de routing canonique.**

**Version:** 1.0.0
**Issue:** #1955 (Claude→Roo direction), #1954 (Claude side dispatcher fix), #2639 WS3 (po-2023 c.65/c.66 audit)
**MAJ:** 2026-07-16 (PR Option A — redirige vers slim, retire direction Roo post-décommission)

---

## ⛔ Redirection canonique

Le contrat de routage Wake-Claude vit maintenant dans **[`.claude/rules/wake-claude-routing.md`](../../../claude/rules/wake-claude-routing.md)** (slim, auto-chargé). Ce document est conservé comme **trace historique** du mécanisme bidirectionnel (Roo → Claude ET Claude → Roo) qui prévalait avant :

- Le re-travail du wake-listener (#2431) qui a remplacé `dashboard-watcher`/`poll-dashboard.ps1` par `dashboard-listener.ps1` + wrapper durable (`-ExecutionTimeLimit PT0S`, triggers `AtLogOn/AtStartup/Once/15min`).
- La migration Roo Code → Zoo Code (#2379) qui rend la direction Claude → Roo (`[WAKE-ROO]`) **non-applicable** post-décommission Roo (gating user #2381 en cours).

---

## Résumé historique (pré-2026-07)

Mécanisme de réveil croisé entre les deux agents principaux du cluster :

- **`[WAKE-CLAUDE]`** (Roo → Claude) : historiquement détecté par `dashboard-watcher` (poll <1h), spawn `claude -p` immédiat.
- **`[WAKE-ROO]`** (Claude → Roo) : historiquement détecté par le scheduler `orchestrator-simple` au prochain cycle (max 6h). **N/A post-#2379.**

```text
Claude Code --[WAKE-ROO]--> Dashboard --> Roo Scheduler (IMMEDIATE, max 6h)
    ^                                      |
    +--------[WAKE-CLAUDE]------------------+
              (poll-dashboard.ps1, ~1h interval) [DEAD]
```

---

## Quand l'utiliser (historique)

### Claude → Roo (`[WAKE-ROO]`) — **RETIRÉ** post-#2379

~~- PR créée et review Roo demandée~~
~~- Tâche déléguée qui nécessite exécution immédiate (build, test, deploy)~~
~~- Conflit git à résoudre par Roo `-complex`~~
~~- Question architecturale nécessitant input Roo~~

### Roo → Claude (`[WAKE-CLAUDE]`)

- Tâche complexe escaladée de Roo vers Claude (échec `-simple` ou `-complex`)
- Décision stratégique requise (architecture, API design)
- Bug critique à investigation profonde
- Coordination multi-machine nécessitant Claude

**Note** : `escalader depuis Roo` n'a plus cours post-décommission. Reste utile pour les bots alternatifs (Hermes sur po-2026, NanoClaw sur ai-01, voir `bots-directory.md`).

---

## Usage (historique)

### Côté Claude (Claude → Roo) — **RETIRÉ**

```javascript
// NE PLUS UTILISER post-#2379 — Roo decommissionné
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["WAKE-ROO"],
  content: "..."
)
```

### Côté Roo (Roo → Claude) — Remplacé par bots alternatifs

```javascript
// Post-#2379, les bots (Hermes/NanoClaw) peuvent escalader via :
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["WAKE-CLAUDE"],  // routing: myia-po-2026:hermes-agent ou myia-ai-01:nanoclaw
  content: "..."
)
```

---

## Mécanique technique (historique, références mortes)

### Côté Claude Worker (`[WAKE-CLAUDE]`) — REMPLACÉ

- ~~**Script** : `scripts/dashboard-scheduler/poll-dashboard.ps1`~~ → voir [`scripts/dashboard-scheduler/dashboard-listener.ps1`](../../../scripts/dashboard-scheduler/dashboard-listener.ps1) (post-#2431)
- **AllowedTags par défaut** : `ASK,TASK,BLOCKED,ORDER,PING,URGENT,WAKE-CLAUDE`
- **Override env var** : `DASHBOARD_WATCHER_TAGS` (unifié wrapper + script, #1961) — **note** : variable conservée pour rétro-compat, le listener dashboard utilise `Test-ActionableContent` à la place
- **Fréquence poll** : ~1h (historique) → **5 min heartbeat + poll 20s** (post-#2431)
- **Action** : Spawn `claude -p` avec contexte du message

### Côté Roo Scheduler (`[WAKE-ROO]`) — **RETIRÉ**

~~- **Workflow** : `.roo/scheduler-workflow-executor.md`, `.roo/scheduler-workflow-coordinator.md`~~
~~- **Détection** : Step 1 (lecture dashboard), tag `[WAKE-ROO]` recherche en priorité~~
~~- **Fréquence cycle** : Variable (configuré via Task Scheduler, typique 6h)~~
~~- **Action** : Traiter contenu IMMÉDIATEMENT, `[ACK]` dashboard, escalader vers `-complex` si nécessaire~~

---

## Garde-fous (toujours applicables)

### Anti-saturation

- **Claude side** : le listener évite le re-spawn si même message déjà traité (lock file `.claude/locks/dashboard-listener.lastack`)
- **Bots alternatifs** : bots postent `[ACK]` pour signaler le traitement, évitant qu'un autre cycle re-traite le même message

### Anti-loop

- Ne JAMAIS poster `[WAKE-ROO]` en réponse à `[WAKE-CLAUDE]` et inversement, sauf nouvelle demande de fond
- Un `[ACK]` ferme le cycle. Pas de relance automatique.

### Priorité vs autres tags

- `[WAKE-*]` est **TOUJOURS prioritaire** sur `[TASK]`, `[PROPOSAL]`, `[ASK]`, `[INFO]`
- Si plusieurs `[WAKE-*]` simultanés : traiter par ordre chronologique (timestamp)
- Si `[WAKE-CLAUDE]` ET `[WAKE-ROO]` simultanés : chaque agent traite le sien (~~mais `[WAKE-ROO]` est N/A~~)

---

## Test du système (historique)

```powershell
# Poster un test
roosync_dashboard(action: "append", type: "workspace", tags: ["WAKE-CLAUDE"], content: "TEST trigger Claude")

# Vérifier que le listener détecte (post-#2431)
.\scripts\dashboard-scheduler\diagnose-wake-listener.ps1
# Doit afficher : heartbeat frais + last action OK
```

---

## Historique

- **2026-05-03 (#1954)** : Fix initial `WAKE-CLAUDE` absent du `AllowedTags` par défaut. PR #1961.
- **2026-05-03 (#1961)** : Naming env var unifié `DASHBOARD_WATCHER_TAGS` (wrapper + script).
- **2026-05-03 (#1955)** : Symétrique `[WAKE-ROO]` ajouté aux workflows Roo.
- **2026-06-06 (#2431)** : Wake-listener réécrit (`dashboard-listener.ps1` + wrapper durable), `dashboard-watcher`/`poll-dashboard.ps1` deviennent des alternatives legacy.
- **2026-07-15 (#2379)** : Migration Roo → Zoo Code en cours. `[WAKE-ROO]` devient N/A.
- **2026-07-16 (#2639 WS3)** : Audit po-2023 c.65 → décision gardien Option A → ce document redirige vers `.claude/rules/wake-claude-routing.md` (slim canonique), retire direction Roo, fence les références mortes. **Conservé comme trace historique** (no-deletion-without-proof).

---

## References

- **[`.claude/rules/wake-claude-routing.md`](../../../claude/rules/wake-claude-routing.md)** — **CONTRAT CANONIQUE** (slim, auto-chargé)
- [`.claude/rules/intercom-protocol.md`](../../../claude/rules/intercom-protocol.md) — Protocole dashboard côté Claude
- [`scripts/dashboard-scheduler/dashboard-listener.ps1`](../../../scripts/dashboard-scheduler/dashboard-listener.ps1) — Listener post-#2431
- [`docs/harness/reference/bots-directory.md`](bots-directory.md) — Bots alternatifs (Hermes, NanoClaw) qui remplacent `[WAKE-ROO]`
- [`docs/harness/reference/intercom-deprecation.md`](intercom-deprecation.md) — Déprécation INTERCOM local (2026-04-30)
