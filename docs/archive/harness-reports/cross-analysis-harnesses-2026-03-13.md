# Analyse Croisée des Harnais META-ANALYST (Roo vs Claude)

**Date:** 2026-03-13
**Auteur:** Roo Code (GLM-5, mode code-complex)
**Contexte:** META-ANALYST - Analyse de cohérence des harnais d'agents

---

## 1. Tableau des Incohérences

| ID | Sujet | Harnais Roo | Harnais Claude | Sévérité |
|----|-------|-------------|----------------|----------|
| **INC-001** | Seuil condensation context | 70% (règle 06-context-window.md) | Non documenté dans les fichiers lus | **MOYENNE** |
| **INC-002** | INTERCOM écriture | Règle stricte: TOUJOURS ajouter à la fin (apply_diff ou Add-Content) | META-INTERCOM mentionné mais pas de règle d'écriture explicite | **BASSE** |
| **INC-003** | Escalade niveau 4 | Claude CLI via `claude -p` (règle globale) | Escalade vers modes plus puissants (architect-complex) | **MOYENNE** |
| **INC-004** | Commandes test | `npx vitest run` (testing.md) | `npx vitest run` + `--maxWorkers=1` (testing.md) | **BASSE** |
| **INC-005** | STOP & REPAIR actions | READ-ONLY en scheduler, INTERCOM [CRITICAL], attendre prochain tick | Actions correctives documentées mais pas de distinction scheduler | **MOYENNE** |
| **INC-006** | Outils retirés | desktop-commander, quickfiles explicitement listés comme RETIRES | Non mentionnés (pas d'historique de retrait) | **BASSE** |
| **INC-007** | MCP shell | win-cli OBLIGATOIRE (seul shell actif) | MCPs multiples listés, pas de shell obligatoire unique | **HAUTE** |
| **INC-008** | Communication inter-machine | RooSync tools (roosync_send, roosync_read) + INTERCOM local | RooSync tools + META-INTERCOM pour meta-analysis | **BASSE** |
| **INC-009** | SDDD grounding | conversation_browser avec `list` OBLIGATOIRE en premier | Non documenté dans les fichiers Claude lus | **MOYENNE** |
| **INC-010** | Validation checklist | Checklist AVANT/PENDANT/APRÈS avec décompte outils | Checklist similaire mais sans décompte explicite | **BASSE** |

---

## 2. Tableau des Lacunes

| ID | Sujet | Manquant dans | Impact | Référence croisée |
|----|-------|---------------|--------|-------------------|
| **GAP-001** | Règle condensation context (70%) | Claude | Risque boucle infinie ou saturation | Roo: `.roo/rules/06-context-window.md` |
| **GAP-002** | Protocole SDDD avec `list` obligatoire | Claude | Perte d'IDs, appels impossibles | Roo: `.roo/rules/04-sddd-grounding.md` |
| **GAP-003** | Règle écriture INTERCOM (append fin) | Claude | Risque d'écrasement/inversion chronologique | Roo: `.roo/rules/02-intercom.md` |
| **GAP-004** | Distinction scheduler READ-ONLY | Claude | Actions interdites en mode scheduler | Roo: `.roo/rules/05-tool-availability.md` |
| **GAP-005** | Historique outils retirés | Claude | Références à des outils obsolètes | Roo: `.roo/rules/03-mcp-usage.md` |
| **GAP-006** | Escalade Claude CLI (niveau 4) | Claude | Pas de mécanisme de dernier recours | Roo: `~/.roo/rules/01-sddd-escalade.md` |
| **GAP-007** | Règle write_to_file >200 lignes | Claude | Échecs silencieux sur gros fichiers | Roo: `.roo/rules/08-file-writing.md` |
| **GAP-008** | Checklists GitHub (cocher au fur et à mesure) | Claude | Issues fermées avec tableaux incomplets | Roo: `.roo/rules/09-github-checklists.md` |
| **GAP-009** | CI guardrails (vitest.config.ci.ts) | Claude | Push de code qui échoue en CI | Roo: `.roo/rules/10-ci-guardrails.md` |
| **GAP-010** | Skepticism protocol (vérification avant propagation) | Claude | Propagation d'erreurs sur 6 machines | Roo: `.roo/rules/skepticism-protocol.md` |
| **GAP-011** | META-INTERCOM protocol | Roo (pas le canal, RooSync seulement) | Communication meta-analysis fragmentée | Claude: `.claude/rules/meta-analysis.md` |
| **GAP-012** | Architecture 3-tier (Meta-Analyst/Coordinator/Executor) | Roo | Pas de vue d'ensemble du système | Claude: `.claude/rules/meta-analysis.md` |

---

## 3. Analyse des Garde-Fous (Guard Rails)

### 3.1 Consistance des contraintes de sécurité

| Garde-fou | Roo | Claude | Statut |
|-----------|-----|--------|--------|
| **Pas de secrets dans commits** | ✅ Règle 00-securite.md | ⚠️ Non documenté dans fichiers lus | **À synchroniser** |
| **STOP & REPAIR** | ✅ Règle 05-tool-availability.md | ✅ tool-availability.md | **Consistant** |
| **Opérations destructives** | ✅ Règle 03-vigilance-pratiques.md | ⚠️ Non documenté | **À synchroniser** |
| **Submodule Git** | ✅ Règle 03-vigilance-pratiques.md | ⚠️ Non documenté | **À synchroniser** |
| **Validation avant push CI** | ✅ Règle 10-ci-guardrails.md | ⚠️ Non documenté | **À synchroniser** |

### 3.2 Procédures d'escalade

| Niveau | Roo | Claude |
|--------|-----|--------|
| 1 | Modes -simple (Qwen 3.5 local) | Modes simples |
| 2 | Modes -complex (GLM-5 cloud) | Modes complexes |
| 3 | new_task vers mode supérieur | Escalade mode architect-complex |
| 4 | **Claude CLI** (`claude -p --model sonnet/opus`) | Non documenté |

---

## 4. Recommandations Priorisées

### REC-001: Synchroniser la règle de condensation context (70%)
**Priorité:** 🔴 HAUTE
**Type:** `harness-change`
**Cible:** Claude harness

**Problème:** Le seuil de condensation à 70% est critique pour éviter les boucles infinies (#502) et la saturation (#555). Cette règle n'est pas documentée dans le harnais Claude.

**Action proposée:**
```markdown
# Ajouter à .claude/rules/context-condensation.md

## Seuil de condensation OBLIGATOIRE

- **Seuil:** 70% (ni 50%, ni 80%+)
- **Raison:** Éviter boucle infinie (#502) et saturation (#555)
- **Configuration:** Settings → Context Management → Auto-condensation → Threshold = 70%
```

---

### REC-002: Documenter le protocole SDDD avec `list` obligatoire
**Priorité:** 🟠 MOYENNE
**Type:** `harness-change`
**Cible:** Claude harness

**Problème:** L'accès à `conversation_browser` sans `list` préalable échoue (pas d'IDs). Cette règle critique n'est pas dans le harnais Claude.

**Action proposée:**
```markdown
# Ajouter à .claude/rules/sddd-grounding.md

## Règle CRITIQUE: `list` comme point d'entrée

**Sans IDs, tu es aveugle.** TOUJOURS commencer par `list` avant d'utiliser `tree`, `view` ou `summarize`.

<!-- Exemple d'appel obligatoire -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>conversation_browser</tool_name>
<arguments>{"action": "list", "workspace": "d:\\roo-extensions", "limit": 20}</arguments>
</use_mcp_tool>
```

---

### REC-003: Ajouter la règle d'écriture INTERCOM (append à la fin)
**Priorité:** 🟠 MOYENNE
**Type:** `harness-change`
**Cible:** Claude harness (META-INTERCOM)

**Problème:** L'ordre chronologique de l'INTERCOM est essentiel. L'insertion au début casse la lecture des messages récents.

**Action proposée:**
```markdown
# Ajouter à .claude/rules/intercom-protocol.md

## REGLE CRITIQUE : Ordre d'Ecriture

**TOUJOURS ajouter les nouveaux messages A LA FIN du fichier.**

**METHODE PREFEREE (apply_diff):**
1. Lire les 20 dernières lignes
2. Utiliser apply_diff pour ajouter APRÈS le dernier `---`

**INTERDIT:**
- NE JAMAIS insérer un message au début
- NE JAMAIS supprimer ou modifier les messages existants
- NE JAMAIS écrire UNIQUEMENT le nouveau message (écrasement)
```

---

### REC-004: Synchroniser les garde-fous de sécurité
**Priorité:** 🟠 MOYENNE
**Type:** `harness-change`
**Cible:** Claude harness

**Problème:** Plusieurs règles de sécurité critiques de Roo ne sont pas documentées dans Claude.

**Actions proposées:**
1. Ajouter règle "Pas de secrets dans commits"
2. Ajouter règle "Opérations destructives" (git reset, git restore avec validation)
3. Ajouter règle "Submodule Git" (detached HEAD normal, pas de checkout/pull)
4. Ajouter règle "CI guardrails" (valider build+tests avant push submodule)

---

### REC-005: Documenter l'escalade Claude CLI (niveau 4)
**Priorité:** 🟢 BASSE
**Type:** `needs-approval`
**Cible:** Claude harness (optionnel)

**Problème:** Roo a un mécanisme d'escalade de dernier recours vers Claude CLI (Anthropic). Claude n'a pas d'équivalent documenté.

**Question:** Est-ce que Claude Code doit aussi avoir un mécanisme d'escalade vers un modèle plus puissant (ex: opus via API directe), ou est-ce que Claude est déjà le "dernier recours" du système?

**Si approuvé:**
```markdown
# Ajouter à .claude/rules/escalation.md

## Escalade Niveau 5 : Anthropic API Direct

Si après 2 tentatives le problème persiste:
1. Préparer un prompt détaillé
2. Utiliser l'API Anthropic directe (si configurée)
3. Documenter l'escalade dans le rapport
```

---

## 5. Synthèse

### Statistiques

| Métrique | Valeur |
|----------|--------|
| Incohérences identifiées | 10 |
| Lacunes identifiées | 12 |
| Sévérité HAUTE | 1 |
| Sévérité MOYENNE | 5 |
| Sévérité BASSE | 4 |
| Recommandations | 5 |

### Répartition par harnais

| Harnais | Lacunes | Actions requises |
|---------|---------|------------------|
| **Claude** | 10 | Synchroniser règles critiques |
| **Roo** | 2 | Ajouter META-INTERCOM, architecture 3-tier |
| **Les deux** | - | Consistance garde-fous |

### Actions immédiates

1. **REC-001** (HAUTE): Ajouter règle condensation 70% → Claude
2. **REC-002** (MOYENNE): Ajouter protocole SDDD `list` → Claude
3. **REC-003** (MOYENNE): Ajouter règle écriture INTERCOM → Claude
4. **REC-004** (MOYENNE): Synchroniser garde-fous sécurité → Claude
5. **REC-005** (BASSE): Documenter escalade niveau 4 → À approuver

---

## 6. Annexes

### A. Fichiers analysés

**Harnais Roo (8 fichiers):**
- `.roo/rules/01-general.md`
- `.roo/rules/02-intercom.md`
- `.roo/rules/03-mcp-usage.md`
- `.roo/rules/04-sddd-grounding.md`
- `.roo/rules/05-tool-availability.md`
- `.roo/scheduler-workflow-coordinator.md`
- `.roo/scheduler-workflow-executor.md`
- `.roomodes`

**Harnais Claude (6 fichiers):**
- `CLAUDE.md`
- `.claude/rules/meta-analysis.md`
- `.claude/rules/testing.md`
- `.claude/rules/scheduler-system.md`
- `.claude/rules/tool-availability.md`
- `.claude/rules/validation-checklist.md`

### B. Références issues

- #502: Boucle infinie condensation (seuil trop bas)
- #555: Saturation contexte GLM-5 (seuil trop haut)
- #368: Migration gh CLI (MCP github-projects déprécié)
- #563: Orchestrator modes sans outils directs

---

*Rapport généré par Roo Code (GLM-5) - 2026-03-13*
