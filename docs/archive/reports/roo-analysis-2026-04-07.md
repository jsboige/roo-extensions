# Cross-Analysis Harnais .claude/rules/ vs .roo/rules/

**Machine :** myia-po-2026
**Date :** 2026-04-07
**Mission :** Comparer les deux harnais (Claude et Roo) pour identifier frictions et incohérences

---

## 1. Mapping Conceptuel

| Fichier .claude/rules/ | Fichier .roo/rules/ | Correspondance |
|------------------------|---------------------|----------------|
| `agents-architecture.md` | `01-general.md` | Partiel - Roo a plus de contexte |
| `ci-guardrails.md` | `10-ci-guardrails.md` | ✅ OUI - Même contenu |
| `context-window.md` | `06-context-window.md` | ✅ OUI - Même contenu |
| `conversation-browser-guide.md` | `04-sddd-grounding.md` + `16-no-tools-warnings.md` | ✅ OUI - Roo divise en 2 fichiers |
| `file-writing.md` | `08-file-writing.md` | ✅ OUI - Même contenu |
| `friction-protocol.md` | `17-friction-protocol.md` | ✅ OUI - Même contenu |
| `intercom-protocol.md` | `02-intercom.md` | ✅ OUI - Même contenu |
| `issue-closure.md` | `24-issue-closure.md` | ✅ OUI - Même contenu |
| `no-deletion-without-proof.md` | `23-no-deletion-without-proof.md` | ✅ OUI - Même contenu |
| `pr-mandatory.md` | `20-pr-mandatory.md` | ✅ OUI - Même contenu |
| `sddd-grounding.md` | `04-sddd-grounding.md` | ✅ OUI - Même contenu |
| `skepticism-protocol.md` | `21-skepticism-protocol.md` | ✅ OUI - Même contenu |
| `tool-availability.md` | `05-tool-availability.md` | ✅ OUI - Même contenu |
| `validation.md` | `22-validation.md` | ✅ OUI - Même contenu |

**Fichiers uniques à .roo/rules/ :**
- `01-general.md` - Guide général Roo Code (pas d'équivalent Claude)
- `03-mcp-usage.md` - Règles d'utilisation MCPs (spécifique Roo)
- `07-orchestrator-delegation.md` - Règles pour orchestrateurs (spécifique Roo)
- `09-github-checklists.md` - Checklists GitHub (spécifique Roo)
- `11-incident-history.md` - Historique des incidents (spécifique Roo)
- `12-machine-constraints.md` - Contraintes machines (spécifique Roo)
- `13-test-success-rates.md` - Taux de succès tests (spécifique Roo)
- `14-tdd-recommended.md` - TDD recommandé (spécifique Roo)
- `15-coordinator-responsibilities.md` - Responsabilités coordinateur (spécifique Roo)
- `18-meta-analysis.md` - Protocole meta-analyse (spécifique Roo)
- `19-github-cli.md` - Règles GitHub CLI (spécifique Roo)

---

## 2. Incohérences de Contenu

### 2.1 Seuils de Condensation

**🔴 CRITICAL - Incohérence détectée :**

| Fichier | Seuil indiqué |
|---------|---------------|
| `.claude/rules/context-window.md` | 75% (standard déployé) |
| `.roo/rules/06-context-window.md` | 75% (standard unifié) |
| `.roo/rules/12-machine-constraints.md` | **80% minimum** (machine constraints) |
| `.roo/rules/18-meta-analysis.md` | **80%** (contraintes contexte Roo) |

**Analyse :**
- Les fichiers `context-window.md` (Claude et Roo) indiquent **75%** comme seuil standard
- Les fichiers `machine-constraints.md` et `meta-analysis.md` (Roo uniquement) indiquent **80%**
- **myia-po-2026** est une machine exécutante (16GB RAM) - devrait suivre le standard 75%
- **myia-web1** (Windows Server 2019) est la seule machine avec contrainte 80%

**Impact :** Risque de confusion pour les agents Roo sur myia-po-2026.

### 2.2 Versioning et Dates

| Fichier | .claude/rules/ | .roo/rules/ | Écart |
|---------|----------------|-------------|-------|
| `context-window.md` | 2026-04-07 | 2026-04-07 | ✅ Sync |
| `friction-protocol.md` | 2026-04-07 | 2026-04-07 | ✅ Sync |
| `issue-closure.md` | 2026-04-06 | 2026-04-07 | ⚠️ 1 jour |
| `tool-availability.md` | 2026-04-05 | 2026-03-22 | 🔴 16 jours |
| `sddd-grounding.md` | 2026-04-05 | 2026-02-23 | 🔴 43 jours |
| `pr-mandatory.md` | 2026-04-05 | 2026-03-23 | 🔴 15 jours |
| `conversation-browser-guide.md` | 2026-04-05 | N/A | - |
| `validation.md` | 2026-04-05 | 2026-03-29 | 🔴 9 jours |
| `skepticism-protocol.md` | 2026-04-05 | 2026-03-04 | 🔴 34 jours |
| `no-deletion-without-proof.md` | 2026-04-05 | 2026-03-29 | 🔴 9 jours |
| `intercom-protocol.md` | 2026-04-05 | 2026-03-05 | 🔴 33 jours |
| `file-writing.md` | 2026-04-05 | 2026-03-10 | 🔴 28 jours |
| `ci-guardrails.md` | 2026-04-05 | 2026-03-23 | 🔴 15 jours |
| `agents-architecture.md` | 2026-04-05 | N/A | - |

**🔴 CRITICAL - Désynchronisation majeure :**
- `tool-availability.md` : 16 jours d'écart (version Claude 2.0.0 vs Roo 1.6.0)
- `sddd-grounding.md` : 43 jours d'écart (version Claude 1.0.0 vs Roo 2.1.0)
- `skepticism-protocol.md` : 34 jours d'écart (version Claude 3.0.0 vs Roo 2.0.0)

---

## 3. Écart de Couverture

### 3.1 Statistiques

| Métrique | .claude/rules/ | .roo/rules/ | Écart |
|----------|----------------|-------------|-------|
| Nombre de fichiers | 14 | 24 | +10 fichiers Roo |
| Taille totale | 26 082 bytes | 108 053 bytes | **+314%** |
| Taille moyenne | 1 863 bytes | 4 502 bytes | **+142%** |

### 3.2 Règles Exclusives à Roo

| Fichier | Contenu | Utilité |
|---------|---------|---------|
| `01-general.md` | Guide général Roo Code, hiérarchie agents | Essentiel pour Roo |
| `03-mcp-usage.md` | Règles d'utilisation MCPs, win-cli obligatoire | Critique pour Roo |
| `07-orchestrator-delegation.md` | Règles orchestrateurs (new_task uniquement) | Critique pour orchestrators |
| `09-github-checklists.md` | Checklists GitHub (validation avant fermeture) | Important |
| `11-incident-history.md` | Historique incidents MCP récents | Important |
| `12-machine-constraints.md` | Contraintes machines (RAM, OS, rôle) | Important |
| `13-test-success-rates.md` | Taux de succès tests par machine | Important |
| `14-tdd-recommended.md` | TDD recommandé | Optionnel |
| `15-coordinator-responsibilities.md` | Responsabilités coordinateur | Important |
| `18-meta-analysis.md` | Protocole meta-analyse 3x2 scheduler | Critique |
| `19-github-cli.md` | Règles GitHub CLI (migration MCP→gh) | Important |

### 3.3 Règles Exclusives à Claude

| Fichier | Contenu | Utilité |
|---------|---------|---------|
| `agents-architecture.md` | Architecture subagents (github-tracker, etc.) | Spécifique Claude |
| `conversation-browser-guide.md` | Guide détaillé conversation_browser | Spécifique Claude |
| `intercom-protocol.md` | Règles communication locale + dashboard | Spécifique Claude |

**Note :** Ces fichiers Claude ont des équivalents Roo mais sont divisés ou combinés différemment.

---

## 4. Références Croisées

### 4.1 Références .claude dans .roo/rules/

**27 références trouvées** dans les fichiers Roo :

| Fichier | Nombre de références |
|---------|---------------------|
| `01-general.md` | 3 |
| `02-intercom.md` | 3 |
| `03-mcp-usage.md` | 2 |
| `04-sddd-grounding.md` | 1 |
| `05-tool-availability.md` | 1 |
| `06-context-window.md` | 2 |
| `07-orchestrator-delegation.md` | 1 |
| `08-file-writing.md` | 4 |
| `10-ci-guardrails.md` | 1 |
| `11-incident-history.md` | 1 |
| `16-no-tools-warnings.md` | 1 |
| `17-friction-protocol.md` | 2 |
| `18-meta-analysis.md` | 8 |
| `20-pr-mandatory.md` | 3 |
| `21-skepticism-protocol.md` | 3 |
| `23-no-deletion-without-proof.md` | 1 |

**Références clés :**
- `06-context-window.md:49` : `**Source :** `.claude/rules/context-window.md` (auto-load Claude)`
- `10-ci-guardrails.md:112` : `**Reference complete :** `.claude/rules/ci-guardrails.md``
- `11-incident-history.md:43` : `Documentation complète : [`.claude/rules/tool-availability.md`](../../.claude/rules/tool-availability.md)`
- `16-no-tools-warnings.md:92` : `**Référence :** [`.claude/rules/sddd-grounding.md`](../../.claude/rules/sddd-grounding.md)`
- `17-friction-protocol.md:104` : `[`.claude/rules/sddd-conversational-grounding.md`](../../.claude/rules/sddd-conversational-grounding.md)`
- `21-skepticism-protocol.md:146` : `**Reference complete :** `.claude/rules/skepticism-protocol.md``

### 4.2 Références .roo dans .claude/rules/

**3 références trouvées** dans les fichiers Claude :

| Fichier | Référence |
|---------|-----------|
| `friction-protocol.md:67` | `**Source :** Promu depuis `.roo/rules/17-friction-protocol.md` (auto-load Roo)` |
| `pr-mandatory.md:53` | `-.claude/rules/, .roo/rules/ (harnais)` |
| `tool-availability.md:26` | `**Config separee :** Claude Code = `C:\Users\{user}\.claude.json`. Roo = `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`` |

**🔴 CRITICAL - Asymétrie des références :**
- Roo référence Claude **27 fois**
- Claude référence Roo **3 fois**
- **Ratio 9:1** - Claude est largement dépendant de Roo, mais pas l'inverse

---

## 5. Désynchronisation Temporelle

### 5.1 Fichiers modifiés récemment (Claude)

| Fichier | Date | Statut |
|---------|------|--------|
| `context-window.md` | 2026-04-07 20:11 | ✅ Très récent |
| `friction-protocol.md` | 2026-04-07 03:16 | ✅ Très récent |
| `issue-closure.md` | 2026-04-06 23:46 | ✅ Récent |
| `tool-availability.md` | 2026-04-05 15:16 | ⚠️ 2 jours |
| `sddd-grounding.md` | 2026-04-05 15:16 | ⚠️ 2 jours |
| `pr-mandatory.md` | 2026-04-05 15:16 | ⚠️ 2 jours |
| `conversation-browser-guide.md` | 2026-04-05 15:16 | ⚠️ 2 jours |

### 5.2 Fichiers modifiés récemment (Roo)

| Fichier | Date | Statut |
|---------|------|--------|
| `17-friction-protocol.md` | 2026-04-07 22:50 | ✅ Très récent |
| `06-context-window.md` | 2026-04-07 22:50 | ✅ Très récent |
| `24-issue-closure.md` | 2026-04-07 21:14 | ✅ Très récent |
| `16-no-tools-warnings.md` | 2026-04-07 21:14 | ✅ Très récent |
| `14-tdd-recommended.md` | 2026-04-07 21:14 | ✅ Très récent |
| `13-test-success-rates.md` | 2026-04-07 21:14 | ✅ Très récent |
| `04-sddd-grounding.md` | 2026-04-07 21:14 | ✅ Très récent |

### 5.3 Désynchronisations critiques

| Fichier | Claude | Roo | Écart | Sévérité |
|---------|--------|-----|-------|----------|
| `tool-availability.md` | 2026-04-05 | 2026-03-22 | 14 jours | 🔴 CRITICAL |
| `sddd-grounding.md` | 2026-04-05 | 2026-02-23 | 41 jours | 🔴 CRITICAL |
| `skepticism-protocol.md` | 2026-04-05 | 2026-03-04 | 32 jours | 🔴 CRITICAL |
| `intercom-protocol.md` | 2026-04-05 | 2026-03-05 | 31 jours | 🔴 CRITICAL |
| `file-writing.md` | 2026-04-05 | 2026-03-10 | 26 jours | 🔴 CRITICAL |
| `ci-guardrails.md` | 2026-04-05 | 2026-03-23 | 13 jours | 🟠 HIGH |
| `pr-mandatory.md` | 2026-04-05 | 2026-03-23 | 13 jours | 🟠 HIGH |

---

## 6. Frictions Identifiées

### 6.1 Frictions CRITICAL

| ID | Problème | Impact | Machine(s) concernée(s) |
|----|----------|--------|------------------------|
| **F-001** | Seuil condensation 75% vs 80% | Agents Roo peuvent utiliser mauvais seuil | myia-po-2023/2024/2025/2026 |
| **F-002** | Désynchronisation tool-availability.md (14 jours) | Protocole STOP & REPAIR obsolète | TOUTES |
| **F-003** | Désynchronisation sddd-grounding.md (41 jours) | Grounding conversationnel obsolète | TOUTES |
| **F-004** | Désynchronisation skepticism-protocol.md (32 jours) | Protocole scepticisme obsolète | TOUTES |
| **F-005** | Asymétrie références (27 vs 3) | Claude dépend de Roo, pas l'inverse | TOUTES |

### 6.2 Frictions HIGH

| ID | Problème | Impact | Machine(s) concernée(s) |
|----|----------|--------|------------------------|
| **F-006** | Désynchronisation file-writing.md (26 jours) | Règles écriture fichiers obsolètes | TOUTES |
| **F-007** | Désynchronisation ci-guardrails.md (13 jours) | Validation CI obsolète | TOUTES |
| **F-008** | Désynchronisation pr-mandatory.md (13 jours) | Règles PR obsolètes | TOUTES |
| **F-009** | Fichier conversation-browser-guide.md unique à Claude | Roo n'a pas de guide dédié | TOUTES |
| **F-010** | Fichier intercom-protocol.md unique à Claude | Roo n'a pas de guide dédié | TOUTES |

### 6.3 Frictions MEDIUM

| ID | Problème | Impact | Machine(s) concernée(s) |
|----|----------|--------|------------------------|
| **F-011** | Taille Roo +314% vs Claude | Complexité accrue, risque confusion | TOUTES |
| **F-012** | Fichiers Roo non synchronisés (01-general, 03-mcp-usage, etc.) | Couverture inégale | TOUTES |
| **F-013** | Versioning incohérent (Claude 3.0.0 vs Roo 2.0.0) | Confusion sur les versions | TOUTES |

### 6.4 Frictions LOW

| ID | Problème | Impact | Machine(s) concernée(s) |
|----|----------|--------|------------------------|
| **F-014** | Noms de fichiers différents (01-general vs agents-architecture) | Recherche moins intuitive | TOUTES |
| **F-015** | Contenu divisé différemment (conversation-browser en 2 fichiers chez Roo) | Fragmentation | TOUTES |

---

## 7. Recommandations

### 7.1 Actions harnès-change (nécessitent approbation utilisateur)

| ID | Action | Fichier(s) concerné(s) | Sévérité |
|----|--------|------------------------|----------|
| **HC-001** | Uniformiser seuil condensation à 75% dans tous les fichiers | `12-machine-constraints.md`, `18-meta-analysis.md` | 🔴 CRITICAL |
| **HC-002** | Mettre à jour `05-tool-availability.md` avec version Claude 2.0.0 | `05-tool-availability.md` | 🔴 CRITICAL |
| **HC-003** | Mettre à jour `04-sddd-grounding.md` avec version Claude 1.0.0 | `04-sddd-grounding.md` | 🔴 CRITICAL |
| **HC-004** | Mettre à jour `21-skepticism-protocol.md` avec version Claude 3.0.0 | `21-skepticism-protocol.md` | 🔴 CRITICAL |
| **HC-005** | Mettre à jour `08-file-writing.md` avec version Claude 2.0.0 | `08-file-writing.md` | 🔴 CRITICAL |
| **HC-006** | Mettre à jour `10-ci-guardrails.md` avec version Claude 3.0.0 | `10-ci-guardrails.md` | 🟠 HIGH |
| **HC-007** | Mettre à jour `20-pr-mandatory.md` avec version Claude 2.0.0 | `20-pr-mandatory.md` | 🟠 HIGH |

### 7.2 Actions needs-approval (propositions d'amélioration)

| ID | Action | Fichier(s) concerné(s) | Sévérité |
|----|--------|------------------------|----------|
| **NA-001** | Créer fichier `conversation-browser-guide.md` pour Roo | Nouveau fichier | 🟠 HIGH |
| **NA-002** | Créer fichier `intercom-protocol.md` pour Roo | Nouveau fichier | 🟠 HIGH |
| **NA-003** | Standardiser les noms de fichiers (01-XX.md vs XX-XX.md) | Tous les fichiers | 🟡 MEDIUM |
| **NA-004** | Ajouter références croisées .roo dans .claude/rules/ | Tous les fichiers Claude | 🟡 MEDIUM |
| **NA-005** | Créer un fichier de mapping conceptuel | Nouveau fichier | 🟡 MEDIUM |
| **NA-006** | Mettre en place un processus de sync automatique | Tous les fichiers | 🟡 MEDIUM |

### 7.3 Actions INFO (documentation)

| ID | Action | Fichier(s) concerné(s) | Sévérité |
|----|--------|------------------------|----------|
| **I-001** | Documenter les écarts de taille (26KB vs 108KB) | Nouveau fichier | 🟢 LOW |
| **I-002** | Créer un tableau de suivi des versions | Nouveau fichier | 🟢 LOW |
| **I-003** | Ajouter un checksum de sync dans chaque fichier | Tous les fichiers | 🟢 LOW |

---

## 8. Synthèse

### 8.1 État des lieux

- **Claude** : 14 fichiers, 26KB, versioning récent (2026-04-05/06/07)
- **Roo** : 24 fichiers, 108KB, versioning hétérogène (2026-02-23 à 2026-04-07)
- **Couverture** : Roo a +10 fichiers spécifiques, Claude a 2 fichiers uniques
- **Références** : Asymétrie 27:1 (Roo→Claude vs Claude→Roo)

### 8.2 Problèmes majeurs

1. **Désynchronisation versioning** : 6 fichiers avec écart >13 jours
2. **Seuil condensation** : 75% vs 80% selon le fichier
3. **Asymétrie références** : Claude dépend fortement de Roo, pas l'inverse
4. **Taille disproportionnée** : Roo est 314% plus volumineux

### 8.3 Priorités d'action

1. **CRITICAL** : Uniformiser seuil condensation (HC-001)
2. **CRITICAL** : Mettre à jour tool-availability.md (HC-002)
3. **CRITICAL** : Mettre à jour sddd-grounding.md (HC-003)
4. **HIGH** : Créer guides conversation-browser et intercom pour Roo (NA-001, NA-002)
5. **MEDIUM** : Standardiser noms de fichiers (NA-003)

---

**Fin de l'analyse cross-harnais.**
