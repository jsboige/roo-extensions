# Configuration Cross-Workspace - myia-ai-01

**Date:** 2026-03-03
**Issue:** #526
**Statut:** OPÉRATIONNEL

---

## Workspaces RooSync Actifs

### 1. roo-extensions (workspace principal)

**Chemin:** `/d/roo-extensions`

**Configuration:**
- ROOSYNC_MACHINE_ID: `myia-ai-01`
- ROOSYNC_SHARED_PATH: `G:/Mon Drive/Synchronisation/RooSync/.shared-state`
- roo-state-manager: ✅ Configuré dans `.roo/mcp.json`
- INTERCOM: `.claude/local/INTERCOM-myia-ai-01.md`

**MCPs actifs:**
- roo-state-manager (36 outils)
- win-cli (9 outils)
- playwright (22 outils)
- markitdown (1 outil)

### 2. 2025-Epita-Intelligence-Symbolique (workspace secondaire)

**Chemin:** `/d/2025-Epita-Intelligence-Symbolique`

**Configuration:**
- ROOSYNC_MACHINE_ID: `myia-ai-01`
- ROOSYNC_SHARED_PATH: `G:/Mon Drive/Synchronisation/RooSync/.shared-state`
- roo-state-manager: ✅ Configuré dans `.roo/mcp.json`
- INTERCOM: `.claude/local/INTERCOM-myia-ai-01.md`

**Projet:** Cours EPITA Intelligence Symbolique (analyse argumentation, LLM, systèmes multi-agents)

---

## Tests de Validation

### Test Cross-Workspace (2026-03-03)

**Envoi de message:**
```
roosync_send(
  action: "send",
  to: "myia-ai-01:2025-Epita-Intelligence-Symbolique",
  subject: "[TEST] Validation cross-workspace depuis roo-extensions",
  ...
)
```

**Résultat:** ✅ SUCCESS
- ID: msg-20260303T083114-75yx65
- Livré dans: `messages/inbox/msg-20260303T083114-75yx65.json`
- Format validé: `machine:workspace` fonctionne

---

## Limitations Connues

### 1. Lecture Inbox Cross-Workspace

**Problème:**
`roosync_read(mode: "inbox")` lit uniquement l'inbox du workspace ACTUEL.

**Impact:**
- ✅ Envoi cross-workspace: FONCTIONNE
- ❌ Lecture cross-workspace: NON DISPONIBLE

**Workaround:**
Pour lire l'inbox d'un autre workspace, l'agent doit:
1. Se déplacer dans le workspace cible (`cd /d/2025-Epita-Intelligence-Symbolique`)
2. Invoquer `roosync_read` depuis ce contexte
3. Retourner au workspace original

**Solution future (Phase 2):**
Ajouter paramètre `workspace` aux outils RooSync:
```typescript
roosync_read(mode: "inbox", workspace: "2025-Epita-Intelligence-Symbolique")
```

---

## Workspaces Non-Éligibles

### 2025-Epita-Intelligence-Symbolique-4
- **Statut:** Roo présent, Claude absent
- **MCPs:** argumentation_analysis_mcp (spécifique projet)
- **Recommandation:** Ne pas intégrer (usage isolé)

### semantic-fleet
- **Statut:** Roo présent, Claude absent
- **MCPs:** Aucun configuré
- **Recommandation:** Ne pas intégrer (projet dormant)

### Autres workspaces (16 repos)
- **Type:** Git-only (pas de Roo/Claude)
- **Exemples:** Dify, Open-WebUI, qdrant, vllm, etc.
- **Recommandation:** Hors scope RooSync

---

## Usage Cross-Workspace

### Envoyer un Message

```typescript
roosync_send(
  action: "send",
  to: "myia-ai-01:2025-Epita-Intelligence-Symbolique",
  subject: "[TASK] Tâche à déléguer",
  body: "Description de la tâche...",
  priority: "MEDIUM"
)
```

### Lire l'Inbox (workspace actuel uniquement)

```typescript
roosync_read(
  mode: "inbox",
  status: "unread"
)
```

### Délégation Cross-Workspace

**Scenario:** Claude Code dans roo-extensions délègue une tâche au workspace Epita

1. Envoyer message via `roosync_send` vers `myia-ai-01:2025-Epita-Intelligence-Symbolique`
2. L'agent dans le workspace cible lit son INTERCOM local
3. Exécute la tâche
4. Répond via `roosync_send` avec `reply_to: message_id`

---

## Checklist d'Extension à d'Autres Workspaces

Pour ajouter un nouveau workspace au réseau RooSync:

- [ ] Vérifier que le workspace a Roo configuré (`.roo/` existe)
- [ ] Vérifier que le workspace a Claude configuré (`.claude/` existe)
- [ ] Ajouter roo-state-manager dans `.roo/mcp.json`:
  ```json
  "roo-state-manager": {
    "command": "node",
    "args": ["D:\\roo-extensions\\mcps\\internal\\servers\\roo-state-manager\\build\\index.js"],
    "env": {
      "ROOSYNC_MACHINE_ID": "myia-ai-01",
      "ROOSYNC_SHARED_PATH": "G:/Mon Drive/Synchronisation/RooSync/.shared-state"
    }
  }
  ```
- [ ] Créer INTERCOM local: `.claude/local/INTERCOM-myia-ai-01.md`
- [ ] Tester envoi message cross-workspace
- [ ] Documenter dans ce fichier

---

## Références

- **Issue GitHub:** #526
- **Documentation RooSync:** `docs/roosync/GUIDE-TECHNIQUE-v2.3.md`
- **Protocol INTERCOM:** `.claude/INTERCOM_PROTOCOL.md`

**Dernière mise à jour:** 2026-03-03 par myia-ai-01
