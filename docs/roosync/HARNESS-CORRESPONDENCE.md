# Correspondances Roo/Claude - Harnais Synchronisés

**Version:** 1.0.0
**Created:** 2026-03-26
**Issue:** #874 (Meta-analysis myia-po-2026)

---

## Vue d'ensemble

Ce document établit les correspondances explicites entre les règles des harnais Roo (`.roo/rules/`) et Claude Code (`.claude/rules/`). Il documente également les règles qui n'ont pas de correspondance (intentionnel ou à combler).

---

## Règles Synchronisées (✅)

Ces règles ont des correspondances directes entre Roo et Claude :

| Règle Claude | Règle Roo | Synchronisation |
|--------------|-----------|-----------------|
| `file-writing.md` | `08-file-writing.md` | ✅ Stratégies d'écriture fichier (limites Qwen vs Edit/Write) |
| `sddd-conversational-grounding.md` | `04-sddd-grounding.md` | ✅ Protocole triple grounding + bookend |
| `no-deletion-without-proof.md` | `23-no-deletion-without-proof.md` | ✅ Règle anti-destruction |
| `pr-mandatory.md` | `20-pr-mandatory.md` | ✅ Workflow PR obligatoire |
| `skepticism-protocol.md` | `21-skepticism-protocol.md` | ✅ Vérification avant propagation |
| `test-success-rates.md` | `13-test-success-rates.md` | ✅ Taux de succès attendus |
| `tool-availability.md` | `05-tool-availability.md` | ✅ STOP & REPAIR si MCP absent |
| `validation.md` | `22-validation.md` | ✅ Checklist validation consolidation |
| `ci-guardrails.md` | `10-ci-guardrails.md` | ✅ Validation CI avant push |
| `github-cli.md` | `19-github-cli.md` | ✅ Utilisation gh CLI |
| `intercom-protocol.md` | `02-dashboard.md` | ✅ Protocole communication dashboard (renamed from 02-intercom.md) |

---

## Règles Claude Sans Correspondance Roo (🔵)

Ces règles existent uniquement pour Claude Code. La plupart sont spécifiques à l'architecture Claude (agents, skills, commands) ou à des contraintes techniques (context window).

### Règle Spécifique Claude

| Règle Claude | Raison de l'absence Roo | Notes |
|--------------|------------------------|-------|
| `agents-architecture.md` | Claude a 18 subagents, Roo en a ~30 | Architectures différentes, pas besoin de correspondance |
| `context-window.md` | Seuil 80% spécifique GLM (z.ai) | Roo utilise seuil 70% (Qwen 3.5) dans `12-machine-constraints.md` |
| `delegation.md` | Protocole délégation Claude (Task tool) | Roo utilise `new_task` avec workflow différent |
| `escalate.md` | Protocole escalade Claude (5 niveaux) | Roo a escalade différente (-simple → -complex) |
| `worktree-cleanup.md` | Script cleanup worktrees | Roo n'a pas d'équivalent (pas de worktrees) |

---

## Règles Roo Sans Correspondance Claude (🟢)

Ces règles existent uniquement pour Roo. Elles sont spécifiques à l'architecture Roo (modes, scheduler, orchestration).

### Règles Spécifiques Roo

| Règle Roo | Raison de l'absence Claude | Notes |
|-----------|---------------------------|-------|
| `01-general.md` | Instructions générales Roo | Claude n'a pas d'équivalent (pas de "general rule") |
| `03-mcp-usage.md` | Utilisation MCPs Roo | Claude utilise MCPs différemment (pas de "use MCP tools") |
| `07-orchestrator-delegation.md` | Délégation orchestrateur Roo | Claude n'a pas d'orchestrateur équivalent |
| `09-github-checklists.md` | Checklists GitHub Roo | Claude utilise `github-cli.md` (plus simple) |
| `11-incident-history.md` | Historique incidents Roo | Partagé via `docs/reference/incident-history.md` |
| `12-machine-constraints.md` | Contraintes machine Roo | Claude utilise `context-window.md` + règles locales |
| `14-tdd-recommended.md` | TDD recommandé Roo | Claude n'a pas de règle équivalente |
| `15-coordinator-responsibilities.md` | Responsabilités coordinateur | Claude n'a pas de coordinateur formel |
| `16-no-tools-warnings.md` | Warning NoTools conversation_browser | Documenté dans `sddd-conversational-grounding.md` Claude |
| `17-friction-protocol.md` | Protocole friction Roo | Claude utilise `sddd-conversational-grounding.md` |
| `18-meta-analysis.md` | Protocole meta-analyse Roo | Claude n'a pas de scheduler équivalent |

---

## Stratégie de Maintien

### Règles Synchronisées

**Quand une règle synchronisée est mise à jour :**

1. **Mettre à jour les deux fichiers** (Roo + Claude)
2. **Vérifier la correspondance** dans ce document
3. **Mettre à jour la date de version** dans les deux fichiers
4. **Referencer l'autre règle** dans les deux fichiers

Exemple :
```markdown
## Référence Croisée
- Roo equivalent: `.roo/rules/08-file-writing.md`
- Claude equivalent: `.claude/rules/file-writing.md`
```

### Règles Non Synchronisées

**Quand une nouvelle règle est créée :**

1. **Décider si elle doit être synchronisée**
   - Règle de pratique courante (SDDD, validation, PR) → synchroniser
   - Règle spécifique architecture → non synchronisée
2. **Documenter la décision** dans ce fichier
3. **Ajouter la référence croisée** si synchronisée

---

## Audit Périodique

**Fréquence:** Chaque cycle meta-analyse (72h)

**Actions :**

1. **Vérifier les numéros de version** des règles synchronisées
2. **Confirmer que les dates de mise à jour** sont cohérentes
3. **Identifier les règles nouvelles** depuis le dernier audit
4. **Mettre à jour ce document** avec les nouvelles correspondances

---

## Actions Issues #874

### ✅ Terminé

1. **Création de ce document** (`HARNESS-CORRESPONDENCE.md`)
2. **Création issue bug #881** pour le problème NoTools

### 🔄 En Cours

1. **Mise à jour `18-meta-analysis.md`** pour documenter explicitement que les sessions Claude ne sont pas indexées

### 📋 À Faire

1. **Renforcer le bookend FIN** dans les workflows
2. **Automatisation validation bookend** (future)

---

## Références

- **Issue #874:** Meta-analysis myia-po-2026
- **Issue #881:** Bug NoTools filtering
- **`.roo/rules/`:** Règles harnais Roo
- **`.claude/rules/`:** Règles harnais Claude
- **`docs/roosync/`:** Documentation RooSync

---

**Dernière mise à jour:** 2026-03-26
**Prochain audit:** 2026-03-29 (cycle meta-analyse)
