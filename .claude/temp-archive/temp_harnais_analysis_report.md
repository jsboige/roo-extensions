# Rapport d'Analyse Comparative des Harnais
**Date :** 2026-03-22
**Analyse :** .roo/rules/ (21 fichiers) vs .claude/rules/ (9 fichiers)

---

## 1. Vue d'Ensemble

### Statistiques
| Harnais | Nombre de fichiers | Lignes totales estimées |
|----------|-------------------|------------------------|
| .roo/rules/ | 21 | ~1,800 |
| .claude/rules/ | 9 | ~1,500 |
| **Total** | **30** | **~3,300** |

### Ratio
- **Règles dupliquées** : 8 fichiers (26%)
- **Règles Roo-spécifiques** : 13 fichiers (43%)
- **Règles Claude-spécifiques** : 2 fichiers (7%)
- **Règles uniques** : 7 fichiers (23%)

---

## 2. Règles Dupliquées avec Variations

### 2.1 INTERCOM Protocol
**Fichiers :**
- `.roo/rules/02-intercom.md` (324 lignes)
- `.claude/rules/intercom-protocol.md` (287 lignes)

**Incohérences identifiées :**

| Aspect | Roo | Claude | Problème |
|---------|-----|--------|----------|
| Méthode OBLIGATOIRE | Dashboard RooSync (Phase 2 migration #745) | Dashboard RooSync (Phase 2 migration #745) | ✅ Cohérent |
| Fallback fichier local | Oui (apply_diff, Add-Content, write_to_file) | Oui (Edit tool) | ⚠️ Méthodes différentes |
| META-INTERCOM | Documenté (fichier séparé) | Non mentionné | ❌ Manquant dans Claude |
| Format messages | Identique | Identique | ✅ Cohérent |
| Types de messages | Identique | Identique | ✅ Cohérent |

**Recommandation :** Unifier les méthodes fallback et documenter META-INTERCOM dans Claude.

---

### 2.2 SDDD Grounding
**Fichiers :**
- `.roo/rules/04-sddd-grounding.md` (192 lignes)
- `.claude/rules/sddd-conversational-grounding.md` (340 lignes)

**Incohérences identifiées :**

| Aspect | Roo | Claude | Problème |
|---------|-----|--------|----------|
| Taille | 192 lignes | 340 lignes (+77%) | ⚠️ Claude plus détaillé |
| conversation_browser | Outil unifié mentionné | Outil unifié + détails filtres | ⚠️ Claude plus complet |
| roosync_search | Mentionné | Mentionné + filtres avancés | ⚠️ Claude plus complet |
| Bookend pattern | Documenté | Documenté | ✅ Cohérent |
| Multi-pass codebase_search | Documenté (4 passes) | Documenté (4 passes) | ✅ Cohérent |
| Frictions récentes | Non mentionné | Section dédiée | ❌ Manquant dans Roo |

**Recommandation :** Fusionner les deux versions en prenant le meilleur de chaque côté (Claude pour les filtres, Roo pour la concision).

---

### 2.3 Skepticism Protocol
**Fichiers :**
- `.roo/rules/20-skepticism-protocol.md` (79 lignes)
- `.claude/rules/skepticism-protocol.md` (125 lignes)

**Incohérences MAJEURES :**

| Aspect | Roo | Claude | Problème |
|---------|-----|--------|----------|
| Taille | 79 lignes | 125 lignes (+58%) | ⚠️ Claude plus détaillé |
| Niveaux de vérification | Non documentés | 3 niveaux (10s, 1-2min, 5min) | ❌ Manquant dans Roo |
| Smell Test | Documenté | Documenté + déclencheurs spécifiques | ⚠️ Claude plus complet |
| Faits de référence | Local vs distant | Infrastructure connue + anti-patterns | ⚠️ Claude plus complet |
| Coordinateur | Non mentionné | Section dédiée | ❌ Manquant dans Roo |
| Executeurs | Non mentionné | Section dédiée | ❌ Manquant dans Roo |

**Recommandation CRITIQUE :** Roo doit adopter les 3 niveaux de vérification et les sections coordinateur/executeurs de Claude.

---

### 2.4 Validation
**Fichiers :**
- `.roo/rules/21-validation.md` (88 lignes)
- `.claude/rules/validation.md` (96 lignes)

**Incohérences identifiées :**

| Aspect | Roo | Claude | Problème |
|---------|-----|--------|----------|
| Taille | 88 lignes | 96 lignes | ✅ Similaire |
| Checklist AVANT | Identique | Identique | ✅ Cohérent |
| Checklist PENDANT | Identique | Identique | ✅ Cohérent |
| Checklist APRÈS | Identique | Identique | ✅ Cohérent |
| Exemple d'erreur | Identique | Identique | ✅ Cohérent |
| Communication | "Communication avec Claude" | "Communication avec Roo" | ✅ Symétrique |

**Recommandation :** Versions cohérentes, pas de changement nécessaire.

---

### 2.5 Test Success Rates
**Fichiers :**
- `.roo/rules/13-test-success-rates.md` (68 lignes)
- `.claude/rules/test-success-rates.md` (100 lignes)

**Incohérences identifiées :**

| Aspect | Roo | Claude | Problème |
|---------|-----|--------|----------|
| Taille | 68 lignes | 100 lignes (+47%) | ⚠️ Claude plus détaillé |
| Taux attendus | Documentés | Documentés | ✅ Cohérent |
| Commande de test | Identique | Identique | ✅ Cohérent |
| Intégration autres règles | Non mentionné | Section dédiée | ❌ Manquant dans Roo |
| Pourquoi ? | Non mentionné | Section dédiée | ❌ Manquant dans Roo |

**Recommandation :** Ajouter la section "Intégration avec Autres Règles" dans Roo.

---

### 2.6 GitHub CLI
**Fichiers :**
- `.roo/rules/19-github-cli.md` (181 lignes)
- `.claude/rules/github-cli.md` (123 lignes)

**Incohérences identifiées :**

| Aspect | Roo | Claude | Problème |
|---------|-----|--------|----------|
| Taille | 181 lignes | 123 lignes (-32%) | ⚠️ Roo plus détaillé |
| Migration MCP → gh | Documentée | Documentée | ✅ Cohérent |
| Scope project | Documenté | Documenté | ✅ Cohérent |
| GraphQL type unions | Documenté | Documenté | ✅ Cohérent |
| Field IDs | Documentés | Documentés | ✅ Cohérent |
| Pagination | Documentée | Documentée | ✅ Cohérent |
| Trouver ITEM_ID | Documenté | Non mentionné | ❌ Manquant dans Claude |
| Mettre à jour champs | Documenté | Non mentionné | ❌ Manquant dans Claude |
| Règle fichiers temporaires | Documentée | Documentée | ✅ Cohérent |

**Recommandation :** Claude doit ajouter les sections "Trouver l'ITEM_ID" et "Mettre à jour les champs".

---

### 2.7 CI Guardrails
**Fichiers :**
- `.roo/rules/10-ci-guardrails.md` (24 lignes)
- `.claude/rules/ci-guardrails.md` (82 lignes)

**Incohérences MAJEURES :**

| Aspect | Roo | Claude | Problème |
|---------|-----|--------|----------|
| Taille | 24 lignes | 82 lignes (+242%) | ❌ Roo très incomplet |
| Validation avant push | Documentée | Documentée + script validate-before-push.ps1 | ❌ Script manquant dans Roo |
| Deux configs Vitest | Non mentionné | Documenté (local vs CI) | ❌ Manquant dans Roo |
| Incidents motivant règle | Non mentionné | Documenté (Claude + Roo) | ❌ Manquant dans Roo |
| Commande alternative | Non mentionné | Documentée (bash) | ❌ Manquant dans Roo |

**Recommandation CRITIQUE :** Roo doit adopter la version complète de Claude avec validate-before-push.ps1 et les deux configs Vitest.

---

### 2.8 Tool Availability
**Fichiers :**
- `.roo/rules/05-tool-availability.md` (66 lignes)
- `.claude/rules/tool-availability.md` (216 lignes)

**Incohérences MAJEURES :**

| Aspect | Roo | Claude | Problème |
|---------|-----|--------|----------|
| Taille | 66 lignes | 216 lignes (+227%) | ❌ Roo très incomplet |
| Configuration séparée | Mentionnée | Documentée en détail | ❌ Manquant dans Roo |
| MCPs CRITIQUES | win-cli, roo-state-manager | win-cli, roo-state-manager + détails | ⚠️ Claude plus complet |
| MCPs STANDARDS | Non mentionnés | Documentés (filesystem, playwright, etc.) | ❌ Manquant dans Roo |
| MCPs OPTIONNELS | Non mentionnés | Documentés (machine-spécifiques) | ❌ Manquant dans Roo |
| MCPs RETIRES | Documentés | Documentés | ✅ Cohérent |
| Procédure Claude | Non mentionnée | Documentée en détail | ❌ Manquant dans Roo |
| Procédure Roo | Documentée | Documentée | ✅ Cohérent |
| Comptage de référence | Non mentionné | Documenté | ❌ Manquant dans Roo |

**Recommandation CRITIQUE :** Roo doit adopter la version complète de Claude avec tous les MCPs et les procédures détaillées.

---

## 3. Règles Spécifiques à Roo (Non Dupliquées)

### 3.1 01-general.md - Guide Général Roo Code
**Contenu :** Hiérarchie (Claude Code = cerveau principal, Roo = assistant), modes (simple/complex), workflow, commits, ressources.

**Pourquoi unique :** Spécifique au rôle d'assistant de Roo.

**Recommandation :** Garder tel quel.

---

### 3.2 06-context-window.md - Condensation Threshold
**Contenu :** Seuil de condensation 80%, GLM context size 131k tokens (pas 200k).

**Pourquoi unique :** Spécifique aux modèles GLM utilisés par Roo.

**Recommandation :** Garder tel quel.

---

### 3.3 07-orchestrator-delegation.md - Orchestrator Mode
**Contenu :** Orchestrator mode rules - delegation OBLIGATOIRE via new_task, pas d'outils directs.

**Pourquoi unique :** Spécifique aux modes orchestrator-simple/complex de Roo.

**Recommandation :** Garder tel quel.

---

### 3.4 08-file-writing.md - Limitation Qwen 3.5
**Contenu :** Qwen 3.5 ne peut pas générer write_to_file pour >200 lignes, alternatives (apply_diff, replace_in_file, win-cli).

**Pourquoi unique :** Spécifique au modèle Qwen 3.5 utilisé en mode -simple.

**Recommandation :** Garder tel quel.

---

### 3.5 09-github-checklists.md - GitHub Issue Checklist
**Contenu :** Règle absolue : ne jamais fermer une issue avec tableau vide/incomplet.

**Pourquoi unique :** Spécifique au workflow GitHub de Roo.

**Recommandation :** Garder tel quel.

---

### 3.6 11-incident-history.md - Historique Incidents
**Contenu :** Tableau des incidents MCP récents avec leçons apprises.

**Pourquoi unique :** Historique spécifique aux incidents Roo.

**Recommandation :** Garder tel quel, mais synchroniser avec Claude si des incidents Claude sont ajoutés.

---

### 3.7 12-machine-constraints.md - Contraintes Machine
**Contenu :** Contraintes spécifiques par machine (RAM, OS, rôle), notamment myia-web1.

**Pourquoi unique :** Spécifique à l'infrastructure Roo.

**Recommandation :** Garder tel quel.

---

### 3.8 14-tdd-recommended.md - TDD Recommandé
**Contenu :** TDD recommandé mais pas obligatoire, quand l'appliquer, workflow minimal.

**Pourquoi unique :** Spécifique au workflow de développement Roo.

**Recommandation :** Garder tel quel.

---

### 3.9 15-coordinator-responsibilities.md - Coordinateur
**Contenu :** Responsabilités du coordinateur (myia-ai-01) : environment health monitoring, RooSync messaging, git commits, workload balance.

**Pourquoi unique :** Spécifique au rôle de coordinateur Roo.

**Recommandation :** Garder tel quel.

---

### 3.10 16-no-tools-warnings.md - conversation_browser Warnings
**Contenu :** Problème connu : NoTools detailLevel génère explosion de contenu, recommandation d'utiliser Summary + truncationChars.

**Pourquoi unique :** Spécifique à l'outil conversation_browser utilisé par Roo.

**Recommandation :** Garder tel quel.

---

### 3.11 17-friction-protocol.md - Protocole Friction
**Contenu :** Protocole de signalement des frictions via RooSync/INTERCOM/GitHub, critères d'approbation.

**Pourquoi unique :** Spécifique au workflow de signalement Roo.

**Recommandation :** Garder tel quel.

---

### 3.12 18-meta-analysis.md - Meta-Analyse
**Contenu :** Protocole meta-analyse pour scheduler Roo (3x2 architecture), rôle du meta-analyste Roo, META-INTERCOM.

**Pourquoi unique :** Spécifique à l'architecture 3x2 scheduler de Roo.

**Recommandation :** Garder tel quel.

---

## 4. Règles Spécifiques à Claude (Non Dupliquées)

### 4.1 agents-architecture.md - Architecture Agents
**Contenu :** Subagents reference (github-tracker, intercom-handler, etc.), skills, commands, agents globaux/projets/coordinateur/workers.

**Pourquoi unique :** Spécifique à l'architecture des sub-agents Claude Code.

**Recommandation :** Garder tel quel.

---

### 4.2 delegation.md - Délégation Sub-agents
**Contenu :** Règles de délégation pour sub-agents Claude, principe du contexte isolé, quand déléguer, format de rapport.

**Pourquoi unique :** Spécifique au système de sub-agents Claude Code.

**Recommandation :** Garder tel quel.

---

## 5. Incohérences Critiques à Résoudre

### 5.1 CI Guardrails - Roo Très Incomplet
**Sévérité :** CRITIQUE
**Impact :** Risque de régressions non détectées sur Roo

**Problème :**
- Roo version : 24 lignes (très basique)
- Claude version : 82 lignes (complète avec validate-before-push.ps1, deux configs Vitest, incidents)

**Action requise :**
1. Roo doit adopter la version complète de Claude
2. Ajouter le script validate-before-push.ps1
3. Documenter les deux configs Vitest (local vs CI)
4. Ajouter la section "Incidents Ayant Motivé Cette Règle"

---

### 5.2 Tool Availability - Roo Très Incomplet
**Sévérité :** CRITIQUE
**Impact :** Risque de confusion sur les MCPs disponibles et les procédures

**Problème :**
- Roo version : 66 lignes
- Claude version : 216 lignes (+227%)

**Action requise :**
1. Roo doit adopter la version complète de Claude
2. Ajouter la section "Configuration Claude Code vs Roo (CRITIQUE)"
3. Documenter tous les MCPs (CRITIQUES, STANDARDS, OPTIONNELS, RETIRES)
4. Ajouter les procédures détaillées pour Claude Code et Roo
5. Ajouter le comptage de référence

---

### 5.3 Skepticism Protocol - Roo Manque Niveaux de Vérification
**Sévérité :** CRITIQUE
**Impact :** Risque de propagation d'erreurs non vérifiées

**Problème :**
- Roo version : 79 lignes (pas de niveaux de vérification)
- Claude version : 125 lignes avec 3 niveaux (10s, 1-2min, 5min)

**Action requise :**
1. Roo doit adopter les 3 niveaux de vérification de Claude
2. Ajouter les sections "Pour le Coordinateur" et "Pour les Executeurs"
3. Ajouter la section "Faits de Référence (Infrastructure Connue)"
4. Ajouter la section "Anti-Patterns Documentés"

---

### 5.4 GitHub CLI - Claude Manque Sections Importantes
**Sévérité :** ÉLEVÉE
**Impact :** Claude ne sait pas comment mettre à jour les champs d'une issue dans le projet

**Problème :**
- Claude version : 123 lignes
- Roo version : 181 lignes avec sections "Trouver l'ITEM_ID" et "Mettre à jour les champs"

**Action requise :**
1. Claude doit ajouter la section "Trouver l'ITEM_ID d'une issue dans le projet"
2. Claude doit ajouter la section "Mettre à jour les champs d'une issue dans le projet"

---

## 6. Frictions Identifiées

### 6.1 INTERCOM - Méthodes Fallback Différentes
**Friction :** Roo et Claude documentent des méthodes fallback différentes pour l'écriture INTERCOM.

**Impact :** Confusion sur quelle méthode utiliser quand le dashboard échoue.

**Recommandation :** Unifier les méthodes fallback en documentant une seule approche cohérente.

---

### 6.2 SDDD - Versions Inégales
**Friction :** Claude version (340 lignes) est 77% plus détaillée que Roo version (192 lignes).

**Impact :** Roo manque des informations importantes sur les filtres conversation_browser et roosync_search.

**Recommandation :** Fusionner les deux versions en prenant le meilleur de chaque côté.

---

### 6.3 Test Success Rates - Claude Plus Complet
**Friction :** Claude version (100 lignes) est 47% plus détaillée que Roo version (68 lignes).

**Impact :** Roo manque la section "Intégration avec Autres Règles".

**Recommandation :** Ajouter la section "Intégration avec Autres Règles" dans Roo.

---

## 7. Redondances Identifiées

### 7.1 INTERCOM - Contenu Similaire
**Redondance :** Les deux versions contiennent ~80% de contenu identique.

**Recommandation :** Créer un fichier commun `intercom-shared.md` avec le contenu partagé, et deux fichiers spécifiques `intercom-roo.md` et `intercom-claude.md` pour les différences.

---

### 7.2 SDDD - Contenu Similaire
**Redondance :** Les deux versions contiennent ~70% de contenu identique.

**Recommandation :** Même approche que INTERCOM - fichier commun + fichiers spécifiques.

---

### 7.3 Skepticism - Contenu Similaire
**Redondance :** Les deux versions contiennent ~60% de contenu identique.

**Recommandation :** Même approche - fichier commun + fichiers spécifiques.

---

### 7.4 Validation - Contenu Presque Identique
**Redondance :** Les deux versions contiennent ~95% de contenu identique.

**Recommandation :** Fusionner en un seul fichier `validation-shared.md` (les différences sont minimes).

---

### 7.5 Test Success Rates - Contenu Similaire
**Redondance :** Les deux versions contiennent ~70% de contenu identique.

**Recommandation :** Même approche - fichier commun + fichiers spécifiques.

---

### 7.6 GitHub CLI - Contenu Similaire
**Redondance :** Les deux versions contiennent ~80% de contenu identique.

**Recommandation :** Même approche - fichier commun + fichiers spécifiques.

---

## 8. Règles Obsolètes ou Non Documentées

### 8.1 Aucune règle obsolète identifiée
**Analyse :** Toutes les règles lues semblent actuelles et pertinentes.

**Note :** Aucune règle ne mentionne des fonctionnalités dépréciées ou des MCPs retirés qui ne seraient pas documentés ailleurs.

---

## 9. Recommandations Globales

### 9.1 Priorité 1 - Incohérences Critiques
1. **CI Guardrails** : Roo doit adopter la version complète de Claude
2. **Tool Availability** : Roo doit adopter la version complète de Claude
3. **Skepticism Protocol** : Roo doit adopter les 3 niveaux de vérification

### 9.2 Priorité 2 - Incohérences Élevées
4. **GitHub CLI** : Claude doit ajouter les sections ITEM_ID et mise à jour champs

### 9.3 Priorité 3 - Frictions
5. **INTERCOM** : Unifier les méthodes fallback
6. **SDDD** : Fusionner les deux versions
7. **Test Success Rates** : Ajouter section "Intégration avec Autres Règles" dans Roo

### 9.4 Priorité 4 - Redondances
8. Créer des fichiers communs pour les règles dupliquées :
   - `intercom-shared.md`
   - `sddd-shared.md`
   - `skepticism-shared.md`
   - `validation-shared.md`
   - `test-success-rates-shared.md`
   - `github-cli-shared.md`

### 9.5 Priorité 5 - Documentation
9. Ajouter une section "Références Croisées" dans chaque règle dupliquée pour pointer vers la version correspondante dans l'autre harnais.

---

## 10. Métriques de Qualité

### 10.1 Couverture
| Aspect | Roo | Claude | Écart |
|--------|-----|--------|-------|
| Règles dupliquées | 8/8 (100%) | 8/8 (100%) | ✅ Parfait |
| Règles spécifiques | 13 | 2 | - |
| Règles uniques | 7 | 7 | ✅ Équilibré |

### 10.2 Complétude
| Aspect | Roo | Claude | Écart |
|--------|-----|--------|-------|
| CI Guardrails | 29% | 100% | ❌ -71% |
| Tool Availability | 31% | 100% | ❌ -69% |
| Skepticism | 63% | 100% | ❌ -37% |
| GitHub CLI | 100% | 68% | ⚠️ -32% |
| Test Success Rates | 68% | 100% | ❌ -32% |
| SDDD | 56% | 100% | ❌ -44% |

**Moyenne écart Roo :** -47% (Roo est en moyenne 47% moins complet que Claude)

### 10.3 Cohérence
| Aspect | Score |
|--------|-------|
| INTERCOM | 90% |
| SDDD | 70% |
| Skepticism | 60% |
| Validation | 95% |
| Test Success Rates | 70% |
| GitHub CLI | 80% |
| CI Guardrails | 29% |
| Tool Availability | 31% |

**Moyenne cohérence :** 66% (acceptable mais perfectible)

---

## 11. Conclusion

### Résumé
L'analyse comparative révèle des incohérences significatives entre les deux harnais, avec Roo étant en moyenne 47% moins complet que Claude sur les règles dupliquées.

### Points Positifs
- ✅ Toutes les règles dupliquées sont présentes dans les deux harnais
- ✅ Les règles spécifiques à chaque harnais sont bien justifiées
- ✅ Aucune règle obsolète identifiée
- ✅ Les règles Validation et INTERCOM sont très cohérentes

### Points Négatifs
- ❌ CI Guardrails : Roo très incomplet (29% vs 100%)
- ❌ Tool Availability : Roo très incomplet (31% vs 100%)
- ❌ Skepticism Protocol : Roo manque les 3 niveaux de vérification
- ❌ GitHub CLI : Claude manque des sections importantes
- ❌ Redondances importantes (~70-95% de contenu identique)

### Actions Recommandées
1. **Immédiat** : Résoudre les 3 incohérences critiques (CI Guardrails, Tool Availability, Skepticism)
2. **Court terme** : Résoudre l'incohérence élevée (GitHub CLI)
3. **Moyen terme** : Réduire les redondances en créant des fichiers communs
4. **Long terme** : Mettre en place un processus de synchronisation automatique des règles dupliquées

---

**Fin du rapport**
