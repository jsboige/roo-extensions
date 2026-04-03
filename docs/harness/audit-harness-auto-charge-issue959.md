# Audit Harnais Auto-Chargé - Issue #959

**Date:** 2026-04-03
**Machine:** myia-po-2026
**Agent:** Claude Code (task-worker)

---

## Exécutif

L'issue #959 demande un audit du harnais auto-chargé (`.claude/rules/` et `.roo/rules/`) pour identifier les règles qui pourraient être déplacées en documentation on-demand (`.claude/docs/`).

**État actuel:**
- **Claude:** 10 règles auto-chargées, ~50 000 caractères
- **Roo:** 22 règles auto-chargées, ~92 000 caractères
- **Total:** ~142 000 caractères (~35-50K tokens estimés)

**Observation critique:** Plusieurs fichiers mentionnés dans l'issue comme étant auto-chargés (`delegation.md`, `github-cli.md`, `sddd-conversational-grounding.md`, `test-success-rates.md`) sont **déjà** dans `.claude/docs/` (on-demand). L'issue a été créée sur la base d'informations obsolètes.

---

## Audit Claude - 10 Règles Auto-Chargées

| Règle | Lignes | Caractères | Toujours nécessaire ? | Candidat on-demand ? | Classification |
|-------|--------|------------|----------------------|---------------------|----------------|
| `agents-architecture.md` | 94 | ~3 600 | **OUI** - Référence agents déplacés | NON | **AUTO-LOAD** (référence) |
| `ci-guardrails.md` | 119 | ~3 900 | **OUI** - Incidents récurrents | NON | **AUTO-LOAD** (critique) |
| `context-window.md` | 63 | ~1 500 | **OUI** - Configuration GLM | NON | **AUTO-LOAD** (config) |
| `file-writing.md` | 62 | ~2 500 | **OUI** - Modifie comportement Edit/Write | NON | **AUTO-LOAD** (comportement) |
| `intercom-protocol.md` | 308 | ~9 500 | **PARTIEL** - Peut être réduit | OUI | **RÉDUIRE** |
| `no-deletion-without-proof.md` | 97 | ~3 500 | **OUI** - Anti-destruction | NON | **AUTO-LOAD** (critique) |
| `pr-mandatory.md` | 169 | ~6 500 | **OUI** - Workflow critique | NON | **AUTO-LOAD** (critique) |
| `skepticism-protocol.md` | 146 | ~6 400 | **OUI** - Anti-propagation erreurs | NON | **AUTO-LOAD** (critique) |
| `tool-availability.md` | 248 | ~9 600 | **OUI** - STOP & REPAIR | NON | **AUTO-LOAD** (critique) |
| `validation.md` | 95 | ~3 000 | **OUI** - Checklist consolidation | NON | **AUTO-LOAD** (critique) |

**Total Claude:** 50 000 caractères

---

## Analyse Détaillée - Claude

### 1. agents-architecture.md (94 lignes, ~3 600 car.)

**Contenu:** Liste des subagents, skills, commands disponibles.

**Raison AUTO-LOAD:** Référence essentielle pour savoir quels agents existent. Sans cela, un agent ne sait pas qu'il peut déléguer à `code-fixer`, `test-runner`, etc.

**Recommandation:** **GARDER en auto-load** mais pourrait être réduite aux tables essentielles.

---

### 2. ci-guardrails.md (119 lignes, ~3 900 car.)

**Contenu:** Règles de validation avant push submodule + incidents historiques.

**Raison AUTO-LOAD:** Incidents #626, #827 montrent que sans cette règle, les agents poussent du code cassé. Critique.

**Recommandation:** **GARDER en auto-load**. Section incidents pourrait être déplacée vers docs on-demand (gain ~500 car).

---

### 3. context-window.md (63 lignes, ~1 500 car.)

**Contenu:** Seuil de condensation 80% pour GLM (z.ai).

**Raison AUTO-LOAD:** Configuration critique qui impacte directement le comportement de Claude Code. Sans cela, boucle de condensation (#502, #736).

**Recommandation:** **GARDER en auto-load**.

---

### 4. file-writing.md (62 lignes, ~2 500 car.)

**Contenu:** Quand utiliser Edit vs Write, append-only INTERCOM.

**Raison AUTO-LOAD:** Modifie le comportement par défaut des outils. Sans cette règle, les agents risquent d'écraser des fichiers.

**Recommandation:** **GARDER en auto-load**.

---

### 5. intercom-protocol.md (308 lignes, ~9 500 car.) ⚠️ **CANDIDAT RÉDUCTION**

**Contenu:** Protocole dashboard RooSync + fallback fichier local + exemples.

**Problème:** Très verbose (308 lignes). Les sections exemples (~100 lignes) sont rarement nécessaires.

**Raison AUTO-LOAD (partielle):** Le protocole dashboard est critique pour la coordination.

**Recommandation:** **RÉDUIRE** en auto-load (garder l'essentiel), déplacer exemples vers docs on-demand.
- **Garder en auto-load:** Protocole dashboard, tags, hiérarchie (~150 lignes)
- **Déplacer vers docs:** Exemples détaillés, fallback fichier (~150 lignes)
- **Gain estimé:** ~4 500 caractères

---

### 6. no-deletion-without-proof.md (97 lignes, ~3 500 car.)

**Contenu:** Règle anti-destruction + preuves requises + répertoires protégés.

**Raison AUTO-LOAD:** Incidents Session 101, #815, #821 montrent que sans cette règle, du code fonctionnel est détruit. Critique.

**Recommandation:** **GARDER en auto-load**.

---

### 7. pr-mandatory.md (169 lignes, ~6 500 car.)

**Contenu:** Workflow PR obligatoire + cleanup worktree + audit PRs CLOSED.

**Raison AUTO-LOAD:** Incidents multiples (push directs, worktrees orphelins) montrent que cette règle est critique.

**Recommandation:** **GARDER en auto-load**. Section audit PRs CLOSED pourrait être déplacée vers docs (gain ~500 car).

---

### 8. skepticism-protocol.md (146 lignes, ~6 400 car.)

**Contenu:** Protocole de vérification avant de propager des affirmations + anti-patterns documentés.

**Raison AUTO-LOAD:** Incidents (GPU panic po-2026, duplication #553) montrent que sans cette règle, des erreurs se propagent sur 6 machines.

**Recommandation:** **GARDER en auto-load**.

---

### 9. tool-availability.md (248 lignes, ~9 600 car.)

**Contenu:** Inventaire MCPs attendus + protocole STOP & REPAIR + configuration Claude vs Roo.

**Raison AUTO-LOAD:** Règle la plus critique. Sans elle, un agent peut travailler pendant des heures avec un MCP absent (incident win-cli web1).

**Recommandation:** **GARDER en auto-load**. Section historique incidents pourrait être réduite (gain ~1 000 car).

---

### 10. validation.md (95 lignes, ~3 000 car.)

**Contenu:** Checklist validation consolidation (comptage avant/après).

**Raison AUTO-LOAD:** Incidents de consolidation montrent que sans cette checklist, les agents créent des incohérences dans les exports.

**Recommandation:** **GARDER en auto-load**.

---

## Audit Roo - 22 Règles Auto-Chargées

| Règle | Lignes | Caractères | Toujours nécessaire ? | Candidat on-demand ? | Classification |
|-------|--------|------------|----------------------|---------------------|----------------|
| `01-general.md` | ~130 | ~4 700 | **OUI** | NON | **AUTO-LOAD** |
| `02-intercom.md` | ~180 | ~6 600 | **OUI** | NON | **AUTO-LOAD** |
| `03-mcp-usage.md` | ~80 | ~2 900 | **OUI** | NON | **AUTO-LOAD** |
| `04-sddd-grounding.md` | ~200 | ~7 000 | **OUI** | NON | **AUTO-LOAD** |
| `05-tool-availability.md` | ~230 | ~8 200 | **OUI** | NON | **AUTO-LOAD** |
| `07-orchestrator-delegation.md` | ~90 | ~3 300 | **OUI** | NON | **AUTO-LOAD** |
| `08-file-writing.md` | ~80 | ~3 000 | **OUI** | NON | **AUTO-LOAD** |
| `09-github-checklists.md` | ~40 | ~1 300 | **OUI** | NON | **AUTO-LOAD** |
| `10-ci-guardrails.md` | ~90 | ~3 300 | **OUI** | NON | **AUTO-LOAD** |
| `11-incident-history.md` | ~45 | ~1 600 | **NON** | **OUI** | **ON-DEMAND** |
| `12-machine-constraints.md` | ~60 | ~2 000 | **OUI** | NON | **AUTO-LOAD** |
| `13-test-success-rates.md` | ~75 | ~2 600 | **OUI** | NON | **AUTO-LOAD** |
| `14-tdd-recommended.md` | ~40 | ~1 300 | **NON** | **OUI** | **ON-DEMAND** |
| `15-coordinator-responsibilities.md` | ~75 | ~2 500 | **OUI** | NON | **AUTO-LOAD** |
| `16-no-tools-warnings.md` | ~95 | ~3 200 | **OUI** | NON | **AUTO-LOAD** |
| `17-friction-protocol.md` | ~85 | ~3 000 | **OUI** | NON | **AUTO-LOAD** |
| `18-meta-analysis.md` | ~300 | ~10 800 | **NON** | **OUI** | **ON-DEMAND** |
| `19-github-cli.md` | ~190 | ~6 600 | **NON** | **OUI** | **ON-DEMAND** |
| `20-pr-mandatory.md` | ~190 | ~6 700 | **OUI** | NON | **AUTO-LOAD** |
| `21-skepticism-protocol.md` | ~185 | ~6 400 | **OUI** | NON | **AUTO-LOAD** |
| `22-validation.md` | ~85 | ~2 900 | **OUI** | NON | **AUTO-LOAD** |
| `23-no-deletion-without-proof.md` | ~60 | ~2 000 | **OUI** | NON | **AUTO-LOAD** |

**Total Roo:** 92 000 caractères

---

## Analyse Détaillée - Roo

### Candidats On-Demand (Roo)

#### 1. 11-incident-history.md (~45 lignes, ~1 600 car.)

**Contenu:** Liste des incidents historiques.

**Raison ON-DEMAND:** Historique statique, pas nécessaire à chaque conversation. Consulté uniquement lors d'investigations.

**Recommandation:** **DÉPLACER vers `.roo/docs/reference/incident-history.md`**

---

#### 2. 14-tdd-recommended.md (~40 lignes, ~1 300 car.)

**Contenu:** Recommandations TDD (Test Driven Development).

**Raison ON-DEMAND:** Méthodologie optionnelle, pas critique pour les opérations quotidiennes.

**Recommandation:** **DÉPLACER vers `.roo/docs/testing/tdd-recommended.md`**

---

#### 3. 18-meta-analysis.md (~300 lignes, ~10 800 car.) ⭐ **GROS GAIN**

**Contenu:** Protocol d'analyse méta (72h), triple grounding LLM.

**Raison ON-DEMAND:** Utilisé uniquement lors des méta-analyses trimestrielles. Pas nécessaire à chaque conversation.

**Recommandation:** **DÉPLACER vers `.roo/docs/reference/meta-analysis.md`**

---

#### 4. 19-github-cli.md (~190 lignes, ~6 600 car.)

**Contenu:** Guide complet d'utilisation de `gh` CLI.

**Raison ON-DEMAND:** Documentation de référence, pas une règle opérationnelle. Les agents savent déjà utiliser `gh` pour les opérations de base.

**Recommandation:** **DÉPLACER vers `.roo/docs/reference/github-cli.md`**

---

## Plan de Migration Proposé

### Phase 1: Réduction intercom-protocol.md (Claude)

**Action:** Réduire `intercom-protocol.md` de 308 → ~150 lignes

**Éléments à déplacer vers `.claude/docs/intercom-protocol-examples.md`:**
- Exemples détaillés de messages
- Section fallback fichier local complet
- Cas d'utilisation avancés

**Éléments à GARDER en auto-load:**
- Protocole dashboard (principe)
- Hiérarchie des canaux
- Tags et types de messages
- Règles d'engagement (synthèse)

**Gain estimé:** ~4 500 caractères (~1 100 tokens)

---

### Phase 2: Déplacement règles Roo vers on-demand

**Fichiers à déplacer:**

| Fichier | Vers | Gain |
|---------|------|------|
| `.roo/rules/11-incident-history.md` | `.roo/docs/reference/incident-history.md` | ~1 600 car |
| `.roo/rules/14-tdd-recommended.md` | `.roo/docs/testing/tdd-recommended.md` | ~1 300 car |
| `.roo/rules/18-meta-analysis.md` | `.roo/docs/reference/meta-analysis.md` | ~10 800 car |
| `.roo/rules/19-github-cli.md` | `.roo/docs/reference/github-cli.md` | ~6 600 car |

**Total gain Roo:** ~20 300 caractères (~5 000 tokens)

---

### Phase 3: Réduction sections verbose (optionnel)

**Sections candidates à déplacer vers docs:**

| Fichier | Section à déplacer | Vers | Gain |
|---------|-------------------|------|------|
| `ci-guardrails.md` | Incidents historiques | `.claude/docs/reference/incident-history.md` | ~500 car |
| `tool-availability.md` | Historique incidents | `.claude/docs/reference/incident-history.md` | ~1 000 car |
| `pr-mandatory.md` | Audit PRs CLOSED | `.claude/docs/reference/pr-audit.md` | ~500 car |

**Total gain optionnel:** ~2 000 caractères (~500 tokens)

---

## Estimation Gain Total

| Phase | Description | Gain (caractères) | Gain (tokens) |
|-------|-------------|-------------------|---------------|
| **Phase 1** | Réduction intercom-protocol.md | ~4 500 | ~1 100 |
| **Phase 2** | Déplacement 4 règles Roo | ~20 300 | ~5 000 |
| **Phase 3** | Réduction sections verbose (optionnel) | ~2 000 | ~500 |
| **TOTAL** | | **~26 800** | **~6 600 tokens** |

**Réduction du harnais:** ~18% (de 142 000 → ~115 000 caractères)

---

## Risques et Atténuations

### Risque 1: Perte d'information critique

**Atténuation:**
- Conserver des liens dans les règles réduites: "Pour plus de détails, voir `.claude/docs/intercom-protocol-examples.md`"
- Les fichiers déplacés restent accessibles via le système de fichiers

### Risque 2: Agents ne consultent pas les docs on-demand

**Atténuation:**
- Ajouter dans `.roo/rules/01-general.md` une section "Quand consulter les docs on-demand"
- Former les agents à vérifier les docs lors de tâches spécifiques (meta-analysis, investigation incidents)

### Risque 3: Rupture de synchronisation Claude/Roo

**Atténuation:**
- Maintenir la synchronisation des règles jumelles (tool-availability, skepticism-protocol, etc.)
- Documenter clairement les règles qui ont des équivalents dans l'autre harnais

---

## Recommandations Finales

### 1. Exécuter Phase 1 (Priorité Haute)

**Action:** Réduire `intercom-protocol.md` immédiatement.

**Justification:**
- Gain significatif (~1 100 tokens)
- Aucun risque (les exemples sont rarement utilisés)
- Améliore la lisibilité de la règle

### 2. Exécuter Phase 2 (Priorité Moyenne)

**Action:** Déplacer les 4 règles Roo identifiées vers on-demand.

**Justification:**
- Gain important (~5 000 tokens)
- Les fichiers déplacés sont clairement de la documentation, pas des règles opérationnelles
- `meta-analysis.md` en particulier est très verbose et rarement utilisé

### 3. Phase 3 (Priorité Basse)

**Action:** Réduire les sections verbose uniquement si les phases 1-2 sont insuffisantes.

**Justification:**
- Gain modeste (~500 tokens)
- Risque plus élevé de perte d'information contextuelle
- Les sections d'incidents aident à comprendre le POURQUOI des règles

---

## Conclusion

L'audit révèle que:

1. **L'issue #959 est basée sur des informations obsolètes** - plusieurs fichiers mentionnés sont déjà en on-demand
2. **Le harnais actuel est raisonnablement optimisé** - la plupart des règles auto-chargées sont critiques
3. **Un gain de ~6 600 tokens est possible** via les 3 phases proposées
4. **La plus grosse opportunité est `meta-analysis.md` (Roo)** - 10 800 caractères rarement utilisés

**Recommandation globale:** Procéder avec les phases 1 et 2. Le gain de ~6 100 tokens (18% du harnais) est significatif sans compromettre la sécurité des opérations.

---

## Méta-Information

**Agent:** Claude Code (task-worker) sur myia-po-2026
**Date:** 2026-04-03
**Durée:** ~15 minutes
**Méthode:** Lecture systématique de toutes les règles + analyse critère par critère
**Prochaine action:** Attendre approbation utilisateur avant exécution
