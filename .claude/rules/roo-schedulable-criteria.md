# Règle `roo-schedulable` - Critères d'Application

**Version:** 1.0.0
**Créé:** 2026-03-08
**Issue:** #605 - Cascade de délégation vers agents les moins capables

---

## Principe

Le label `roo-schedulable** indique qu'une issue peut être exécutée par le scheduler Roo automatique. **À appliquer avec discernement** pour éviter que des tâches stratégiques soient exécutées par les agents les moins capables.

---

## ✅ QUAND appliquer `roo-schedulable`

**Tâches subalternes** qui ne nécessitent pas de réflexion architecturale :

| Type | Exemples | Agent cible |
|------|----------|-------------|
| **Tests** | Validation end-to-end, tests unitaires | code-simple |
| **Validation** | Audit configs, vérification builds | code-simple |
| **Documentation** | MAJ README, guides techniques, rapports | code-simple |
| **Cleanup** | Suppression code deprecated, tri issues | code-simple |
| **Investigation simple** | Lecture + rapport, recherche fichiers | ask-simple |
| **Build/Deploy** | Scripts existants, déploiement config | code-simple |

**Critère :** La tâche peut être accomplie par **lecture, recherche, et actions mécaniques** sans créativité architecturale.

---

## ❌ QUAND NE PAS appliquer `roo-schedulable`

**Tâches stratégiques** qui nécessitent Claude Code (opus/sonnet) :

| Type | Raison | Agent cible |
|------|--------|-------------|
| **Feature implementation** | Création nouvelle fonctionnalité | Claude Code (sonnet/opus) |
| **Architecture** | Conception système, refactoring majeur | Claude Code (opus) |
| **MCP tools** | Création/modification outils MCP | Claude Code (sonnet) |
| **Harness changes** | Modification skills/commands/rules/modes | Claude Code (opus) |
| **Bug fix complexe** | Requiert investigation profonde | Claude Code (sonnet) |
| **Schémas complexes** | Zod avec `refine()`, validation conditionnelle | Claude Code (sonnet) |

**Critère :** La tâche nécessite **créativité, jugement architectural, ou compréhension système**.

---

## 🏷️ Labels alternatifs

| Label | Usage | Agent |
|-------|-------|-------|
| `claude-only` | Réservé Claude Code (opus/sonnet) | Claude |
| `roo-schedulable` | Exécutable par scheduler Roo | Roo |
| (aucun) | Tâche interactive, décision requise | Human |

---

## 🔍 Decision Tree

```
La tâche nécessite-t-elle de créer du code ?
├─ OUI → Est-ce une nouvelle feature ou architecture ?
│  ├─ OUI → ❌ PAS roo-schedulable (use claude-only)
│  └─ NON → Est-ce un fix simple (< 50 lignes, 1 fichier) ?
│     ├─ OUI → ⚠️ Peut être roo-schedulable
│     └─ NON → ❌ PAS roo-schedulable
└─ NON → Est-ce lecture/rapport/validation uniquement ?
   └─ OUI → ✅ roo-schedulable OK
```

---

## ✅ Checklist avant d'appliquer `roo-schedulable`

- [ ] La tâche ne crée PAS de nouvelle fonctionnalité
- [ ] La tâche ne modifie PAS l'architecture existante
- [ ] La tâche ne crée PAS d'outil MCP ou de skill
- [ ] La tâche peut être accomplie par lecture + actions mécaniques
- [ ] Le résultat est prévisible et ne nécessite pas de jugement

**Si TOUTES cochées → ✅ Appliquer `roo-schedulable`**

---

## 📚 Références

- Issue #605: Cascade de délégation
- `.claude/rules/delegation.md`: Règles de délégation sub-agents
- `.claude/rules/scheduler-system.md`: Architecture scheduler Roo
- `.claude/ESCALATION_MECHANISM.md`: Mécanisme d'escalade 3 couches

---

**Dernière mise à jour:** 2026-03-08
