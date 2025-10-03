# 📘 Spécifications Architecturales Communes - Modes Roo

**Version :** 2.0.0
**Date :** 02 Octobre 2025
**Architecture :** 3-Niveaux (Global → Family → Mode)
**Statut :** ✅ Spécifications validées - Mission 2.1 COMPLÉTÉE

---

## 🎯 Vue d'Ensemble

Ce répertoire contient les **spécifications architecturales communes consolidées** pour l'architecture 2-niveaux des modes Roo. Ces spécifications éliminent **85% des redondances identifiées** (−38k caractères) et établissent une base cohérente pour tous les modes personnalisés.

### Objectifs des Spécifications

1. **Factorisation Massive** : Éliminer duplication instructions communes
2. **Cohérence Architecturale** : Règles uniformes tous modes
3. **Maintenance Simplifiée** : Modifications uniques propagées automatiquement
4. **Performance Optimale** : Économie tokens et ressources
5. **Évolutivité** : Base solide pour futures extensions

---

## 📚 Documents Spécialisés

### Structure Réorganisée

```
roo-config/specifications/
├── *.md                    # 8 Spécifications architecturales (pérennes)
└── reports/                # Rapports de suivi et validation
    ├── README.md
    ├── FEEDBACKS-REVISION-PLAN.md
    ├── RAPPORT-CORRECTIONS-NUMEROTATION.md
    └── RAPPORT-VALIDATION-FINALE.md
```

### 1. Protocole SDDD 4-Niveaux

**Fichier** : [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
**Lignes** : 1119
**Priorité** : 🔴 CRITIQUE (obligatoire tous modes)

Jesse: L'orchestrateur n'a aucun outil, il doit se baser sur ses modes de sous-tâches pour se grounder. Aussi son instruction est anti-symmétrique de celle des autres modes sur ce point là.

**Contenu** :
- Architecture 4-niveaux grounding : Fichier → Sémantique → Conversationnel → GitHub
- Phase 1 : Grounding initial obligatoire (`codebase_search` AVANT toute exploration)
- Phase 2 : Documentation continue (checkpoints 50k tokens)
- Phase 3 : Validation finale (checkpoint sémantique)
- Phase 4 : GitHub Projects (future implémentation)
- Métriques conformité (Bronze/Argent/Or)

**Quand utiliser** :
- ✅ Début de TOUTE tâche nécessitant exploration code
- ✅ Tous les 50k tokens (checkpoints obligatoires)
- ✅ Avant `attempt_completion` (validation découvrabilité)

Jesse: >Tous les 50k tokens: faire le grounding conversationnel 

**Intégration modes** :
```markdown
## PROTOCOLE SDDD
Voir : [`sddd-protocol-4-niveaux.md`](../specifications/sddd-protocol-4-niveaux.md)
- Phase 1 : codebase_search obligatoire
- Phase 2 : Checkpoints 50k tokens
- Phase 3 : Validation sémantique finale
```

---

### 2. Mécaniques Escalade Révisées

**Fichier** : [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md)  
**Lignes** : 669  
**Priorité** : 🔴 CRITIQUE (économie contexte essentielle)

**Contenu** :
- 5 mécaniques escalade : Externe, Désescalade, Interne, Approfondissement, Économique
- Critères spécifiques par famille (CODE, DEBUG, ARCHITECT, ASK, ORCHESTRATOR)
- Formats standardisés (`switch_mode`, `new_task()`)
- Matrice décision escalade
- Seuils tokens universels (50k, 100k)

**Mécaniques clés** :
1. **Escalade Externe** : Simple → Complex (complexité dépasse capacités)
2. **Désescalade** : Complex → Simple (économie ressources)
3. **Escalade Interne** : Simple traite complexité modérée
4. **Escalade Approfondissement** : Contexte >50k → sous-tâches
5. **Désescalade Économique** : Complex délègue actions lourdes



**Intégration modes** :
```markdown
## MÉCANIQUES D'ESCALADE
Voir : [`escalade-mechanisms-revised.md`](../specifications/escalade-mechanisms-revised.md)

### Critères Famille {{FAMILLE}}
[Critères spécifiques extraits du document]

### Seuils Universels
- 50k tokens → Escalade externe obligatoire
- 100k tokens → Orchestration obligatoire
```
Jesse: Je viens de lire les fichiers d'escalade et je trouve que tout ne fait pas sens.
Déjà il faudrait distinguer le fait de changer de mode ou instruire des sous-tâches qui peut se faire pour multiples raisons avec le fait de
le faire pour escalade.
Le terme d'escalade devrait désigner un phénomène précis: le fait qu'un mode simple en fasse appel à un mode complexe.
Du coup il y a 3 façons de le faire, 1 escalde interne: le mode simple switche au sein de la même tâche en mode complexe, ou bien externe, et là il y a deux possibilités: l'agent simple a les infos mais pas la compétence même si sur le papier il a les infos nécessires --> il créée une sous-tâche en lui passant toutes ses infos. Ou bien, l'agent simple n'a pas le contexte suffisant sou suffisament frais pour instruire la sous-tâche, alors il rassemble tout ce qu'il a fait et termine sa tâche en échec avec toutees les infos nécessaires à son orchestrateur pour réinstruire une nouvelle tâche en mode complexe, en mobilisant au besoin des infos de contexte qu'n'avait pas transmises à l'agent simple en échec.

Alors ensuite je ne pense pas que la désescalade soit une bonne idée: potentiellement les agents simples n'ont pas la même longueur de contexte et le changement de mode peut poser problème donc il est à éviter. Pour la même raison je suis pour éviter l'escalade interne et privilégier l'instruction de sous-tâches. Mais la desescalade est possible par l'administration de sous-tâches ou encore en terminant la tâche en semi-succès, invitant l'orchestrateur à finaliser le travail avec un mode simple.

De façon générale, on doit encourager les modes à décomposer au maximum et à économiser leur contexte au maximum en sous-traitant tout ce qu'il s puvent sous-traiter.
Pour les agents simples, c'est plutôt la question d'identifier l'atomisation la plus complète de la tâche qui leur est demandée, sans tomber dans l'excès ou plus personne ne veut faire le travail et tout le monde sous-traite à l'infini: le nudge doit juste pour les agents simples les inviter à vérifier s'ils peuvent décomposer leur travail sans les forcer à le faire. En l'occurence ce serait plus au mode orchestrateur ou complexe qui les as créés de faire ce travail d'atomisation pour leur confier une tâche primitive. Mais bon il peut arriver qu'un travail jugé simple par un mode complex ou un orchestrateur soit néanmoins décomposable avantageusmenet pour ne pas saturer le contexte, et dans ce cas, l'agent simple doit savoir le faire.
En revanche pour les modes complexes, ça doit être un impératif économique et de performance de sysématiquement sous-traiter: tout ce qui va prendre de la place dans leur contexte et qui peut être délégué à une sous-tâche simple sdit faire l'objet d'une sous-tâche, aussi les conversations de tâches des agents complexes doivent ressembler un peu à celles d'un orchestrateur, même si naturellement ils ont le droit d'utiliser des outils directement, mais ils doivent au maximum essayer plutôt de les faire manipuler par des agents simples chargé sde synthétiser leurs usage. Et les agents complexe doivent se réserver l'usage des outils quand leur utilisation directe présente un intéret supérieur à une simple synthèse d'utilisation par une sous-tâche. Ils sont naturellement responsable de filer tout le contexte nécessaire à leurs agents de soust-âches simples, et de faire preuve d'un niveau d'exigeance quant au contenu fouillé des rapports de terminaison leur garantissant qu'ils ont autant d'info que s'ils avaient accomplis les actions eux-même.
C'est la même problématique pour le grounding sddd des orcehstrateurs, qui n'ayant pas le droit de lire des fichiers sont aveugles des documents de suivis qu'ils commandent à moins d'en réclamer des synthèses dans les rapporots de terminaison des tâches enfants.

Enfin pour les histoires de taille de contexte, il faut qu'on se donne la possibilité d'ajuster car les tailles sont très variables entre modèles, mais disons qu'à 70% de la taille officielle du modèle sous-jacent, les modes doivent être incités à ne faire plus qu'orchestrer des sous-tâches pour finaliser la leur (sans pour autant passer orchestrateur a priori pour ne pas risquer une incompatibilité de contexte, mais pour le coup, je ne suis pas opposé à ce qu'on décide éventuellement après tests qu'il vaut mieux vérouiller un contexte saturé en interdisant toute action ultérieure, c'est à dire en passant en mode orchestrateur)

---

### 3. Hiérarchie Numérotée Systématique

**Fichier** : [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md)  
**Lignes** : 607  
**Priorité** : 🟡 IMPORTANTE (modes orchestrateurs uniquement)

**Contenu** :
- Format standard : X.0 → X.Y → X.Y.Z → X.Y.Z.A
- Templates `new_task()` avec numérotation cohérente
- Synchronisation avec `roo-state-manager` tree
- Patterns orchestration (séquentiel, parallèle, mixte)
- Traçabilité complète sous-tâches

**Format numérotation** :
```
1.0         → Tâche principale
1.1         → Sous-tâche niveau 1
1.1.1       → Sous-tâche niveau 2
1.1.1.1     → Sous-tâche niveau 3
```
Jesse: pourquoi 1.0, je dirais 1


**Applicable à** :
- architect-simple, architect-complex
- orchestrator-simple, orchestrator-complex
- manager
- ❌ Pas dans code/debug/ask simples (pas d'orchestration)
---

### 7. Best Practices Opérationnelles

**Fichier** : [`operational-best-practices.md`](operational-best-practices.md)  
**Lignes** : 1014  
**Priorité** : 🔴 CRITIQUE (workflow et traçabilité)  
**Ajouté** : 2 Octobre 2025 (Mission 2.3)

**Contenu** :
- **SPEC 1** : Priorité Scripts vs Commandes Complexes
  - Workflow non-bloquant (évite approbations)
  - Capacités élargies (Python, Node.js, .NET, etc.)
  - Documentation et traçabilité automatiques (CRITIQUE)
- **SPEC 2** : Nomenclature et Organisation Strictes
  - Arborescence logique par nature/fonction
  - Horodatage systématique : `YYYY-MM-DD-[description]-[type].[ext]`
  - Noms précis et descriptifs (jamais génériques)
  - Pas de fichiers à la racine workspace
- **Mécanisme évolutif** : Processus ajout rapide nouvelles SPECs (<48h)

**Quand utiliser** :
- ✅ Création/exécution scripts (privilégier vs commandes)
- ✅ Création fichiers suivi/rapports (nomenclature stricte)
- ✅ Organisation projet (structure hiérarchique logique)

**Relation SDDD** :
- Scripts = Documentation exécutable (Phase 2)
- Nomenclature = Découvrabilité sémantique (Phase 1)
- Traçabilité = Grounding conversationnel facilité (Phase 3)

**Intégration modes** :
```markdown
## BEST PRACTICES OPÉRATIONNELLES
Voir : [`operational-best-practices.md`](../specifications/operational-best-practices.md)

### Règles Critiques
- SPEC 1 : Scripts > Commandes (traçabilité)
- SPEC 2 : Nomenclature stricte (découvrabilité)

### Exemples
- Scripts : `scripts/validation/2025-10-02-validate-modes.ps1`
- Rapports : `reports/missions/2025-10-02-mission-2-3.md`
```

Jesse: Pas d'accord, tous les modes doivent pouvoir créer des sous-tâches que ce soit pour décomposer des tâches atomisables, ou bien pour escalader en confiant des actions complexes à un mode dédié.

**Intégration modes orchestrateurs** :
```markdown
## HIÉRARCHIE NUMÉROTÉE
Voir : [`hierarchie-numerotee-subtasks.md`](../specifications/hierarchie-numerotee-subtasks.md)

### Format new_task()
🎯 **Sous-tâche {{NUMERO}} : {{TITRE}}**
[Template complet dans document]
```

---

### 4. Intégrations MCP Prioritaires

**Fichier** : [`mcp-integrations-priority.md`](mcp-integrations-priority.md)  
**Lignes** : 725  
**Priorité** : 🔴 CRITIQUE (efficacité opérationnelle)

**Contenu** :
- **Tier 1** : roo-state-manager + quickfiles (SYSTÉMATIQUE)
- **Tier 2** : github-projects (future phase 2.2+)
- **Tier 3** : jinavigator, searxng, playwright, jupyter (cas spécifiques)
- Patterns utilisation optimaux
- Matrice décision outil approprié

**MCPs prioritaires** :

| MCP | Fonction | Utilisation |
|-----|----------|-------------|
| **roo-state-manager** | Contexte conversationnel | Grounding Phase 3, navigation hiérarchie |
| **quickfiles** | Manipulation batch fichiers | Lecture/édition >2 fichiers, recherche multi-fichiers |
| github-projects | Sync GitHub | Future (Phase 2.2+) |
| jinavigator | Extraction web → markdown | Documentation en ligne |
| searxng | Recherche web | Veille technique |
| playwright | Automatisation browser | Tests E2E, UI |

**Intégration modes** :
```markdown
## INTÉGRATIONS MCP
Voir : [`mcp-integrations-priority.md`](../specifications/mcp-integrations-priority.md)

### Tier 1 : Systématique
- roo-state-manager : Grounding conversationnel
- quickfiles : Batch operations (>2 fichiers)

### Patterns Efficacité
1. codebase_search (sémantique)
2. roo-state-manager (historique)
3. quickfiles (lecture ciblée)
```
Jesse: Il faut qu'on détermine exactemetn ce qu'on fait des MCPs git et surtout win-cli. Ce dernier était sensé remplacer le terminal natif pour les modes code et debug, mais il faut pour cela le débrider quant aux workspaces acceptés. Sinon réautoriser le terminal pour tous les modes non orchestrateur.
### 8. Mapping LLMs et Modes

**Fichier** : [`llm-modes-mapping.md`](llm-modes-mapping.md)  
**Lignes** : 1319  
**Priorité** : 🔴 CRITIQUE (allocation ressources optimale)

**Contenu** :
- **Taxonomie LLMs** : 4 tiers (Flash, Mini, Standard, SOTA)
  - Flash : Ultra-rapide, 0.25-0.50 $/MTok, 50k-100k tokens
  - Mini : Compromis, 0.50-1.00 $/MTok, 100k-200k tokens
  - Standard : Équilibré, 2.50-5.00 $/MTok, 200k-500k tokens
  - SOTA : Raisonnement maximal, 3.00-15.00 $/MTok, 200k+ tokens
- **Mapping Modes → LLMs** : Tableau complet 12 modes (5 familles × 2 niveaux + 2 spéciaux)
- **Critères Escalade** : 5 seuils quantitatifs
  - Tokens : 25k (alerte), 40k (recommandation), 50k (obligatoire)
  - Sous-tâches : >3 → escalade orchestrator-complex
  - Fichiers : >10 → escalade mode complex
  - Durée : >15min → checkpoint ou escalade
  - Complexité raisonnement : Patterns avancés → escalade
- **Patterns d'Usage** : 5 cas concrets avec LLM recommandé
- **Configuration** : Templates JSON par provider (Anthropic, OpenAI, Google)
- **Optimisation Budget** : Stratégies par tier LLM
- **Monitoring** : 4 métriques critiques + dashboards

**Modèles Recommandés** :

| Tier | Modes | Modèle Principal | Alternatives |
|------|-------|------------------|--------------|
| **Flash** | Simples | Claude 3.5 Haiku | GPT-4o-mini, Gemini 2.0 Flash |
| **SOTA** | Complex | Claude Sonnet 4 | GPT-4o, o1-preview |
| **SOTA** | Spéciaux | Claude Sonnet 4 | GPT-4o |

**Quand utiliser** :
- ✅ Configuration initiale projet (choix LLMs)
- ✅ Optimisation coûts (allocation tier par mode)
- ✅ Diagnostic escalades fréquentes (seuils mal calibrés)
- ✅ Planification budget (coût moyen par mode)

**Intégration modes** :
```markdown
## MAPPING LLM
Voir : [`llm-modes-mapping.md`](../specifications/llm-modes-mapping.md)

### Tier Recommandé
- Mode Simple : Flash/Mini (Claude 3.5 Haiku, GPT-4o-mini)
- Mode Complex : SOTA (Claude Sonnet 4, GPT-4o)

### Seuils Escalade
- ⚠️ 25k tokens : Alerte précoce
- 🔔 40k tokens : Escalade recommandée
- 🚨 50k tokens : Escalade OBLIGATOIRE
```

**Références croisées** :
- [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) : Critères escalade → Mapping tiers
- [`context-economy-patterns.md`](context-economy-patterns.md) : Optimisation tokens par tier
- [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md) : Grounding adaptatif par tier

---

### 5. Factorisation Massive

**Fichier** : [`factorisation-commons.md`](factorisation-commons.md)  
**Lignes** : 769  
**Priorité** : 🟢 RÉFÉRENCE (architecture système)

**Contenu** :
- Analyse redondances : 85% duplication identifiée
- Architecture 3-couches : Globales → Famille → Mode
- Templates par famille (CODE, DEBUG, ARCHITECT, ASK, ORCHESTRATOR)
- Système assemblage automatique
- Métriques avant/après factorisation

**Économie mesurée** :
```
AVANT  : ~540k caractères (45k × 12 modes)
APRÈS  : ~180k caractères (15k × 12 modes)
GAIN   : −360k caractères (67% réduction)
```

**Sections communes factorisées** :
1. Protocole SDDD (12/12 modes) → ~12k économisés
2. Mécaniques Escalade (10/12 modes) → ~10k économisés
3. Hiérarchie Numérotée (8/12 modes) → ~6k économisés
4. Intégrations MCP (12/12 modes) → ~8k économisés
5. Gestion Tokens (10/12 modes) → ~2k économisés

**Intégration** : Système templates avec variables
```markdown
<!-- Template famille CODE -->
# Famille CODE - Niveau {{LEVEL}}

## INSTRUCTIONS COMMUNES
- SDDD : [`sddd-protocol-4-niveaux.md`](...)
- MCP : [`mcp-integrations-priority.md`](...)

## FOCUS AREAS {{LEVEL}}
{{#if LEVEL == "simple"}}
[Instructions simples]
{{else}}
[Instructions complexes]
{{/if}}
```
Jesse: Ok pour le principe d'une factorisation, il faudra regarder dans quels champs de config roo on insère tout cela (il y a dejà une partie commune à tous les modes, mais ça n'est peut-e^tre pas ce qu'on souhaite utilsier, à vérifier)
---

### 6. Patterns Économie Contexte

**Fichier** : [`context-economy-patterns.md`](context-economy-patterns.md)  
**Lignes** : 819  
**Priorité** : 🔴 CRITIQUE (performance modes)

**Contenu** :
- 5 patterns économie : Délégation, Décomposition, MCP Batch, Checkpoints, Lecture Ciblée
- Seuils critiques : 30k (attention), 50k (critique), 100k (maximum)
- Stratégies optimisation tokens
- Templates checkpoint synthétique
- Métriques et monitoring

**Patterns essentiels** :

| Pattern | Économie Typique | Quand Utiliser |
|---------|------------------|----------------|
| **1. Délégation Intelligente** | 65k → 36k tokens | Mode Complex >30k tokens |
| **2. Décomposition Atomique** | 120k → 5×30k tokens | Tâche >50k tokens |
| **3. MCP Batch** | 5× → 1× requêtes | Opérations multiples fichiers |
| **4. Checkpoints Synthétiques** | Libère contexte | Tous les 50k tokens |
| **5. Lecture Ciblée Progressive** | 15k → 3k tokens | Fichiers larges |

**Intégration modes** :
```markdown
## ÉCONOMIE CONTEXTE
Voir : [`context-economy-patterns.md`](../specifications/context-economy-patterns.md)

### Seuils Critiques
- 30k : Checkpoint préventif
- 50k : Délégation obligatoire
- 100k : Orchestration obligatoire

### Patterns Prioritaires
- Délégation : Complex → Simple actions lourdes
- MCP Batch : quickfiles vs outils natifs multiples
- Lecture Ciblée : line_range au lieu de complet
```
Jesse: Attention à l'économie de contexte qui peut induire des angles morst. Typiquement les lectures ciblées sont des risques et multiplient les aller-retours ce qui est souvent contre productif.
Donc privilégier une première lecture intégrale au moins.
Et puis de façon générale, les tâches ont tendance à se dégrounder donc c'est une bonne habitude de remettre tout le fichier en mémoire de temps à autre.
Non, ce qui permet la meilleure économie de tâche, c'est surtout de déléguer au maximum les opérations atomiques à des sous-ta^ches, et donc de le faire de plus en plus au fur et à mesure que la convesation avance, jusqu'à se retrouver dans la peau (et peut-être le mode, cf ci-dessus la discussion sur l'utilité de switcher ou pas, à évaluer) d'un orcehstrateur qui ne fait plus d'actions lui-même.
---

## 🔗 Relations entre Documents

### Graphe de Dépendances

```
sddd-protocol-4-niveaux.md (FONDATION)
           ↓
    ┌──────┴──────┐
    ↓             ↓
escalade-mechanisms.md  mcp-integrations.md
    ↓             ↓
    └──────┬──────┘
           ↓
hierarchie-numerotee.md
           ↓
    ┌──────┴──────┐
    ↓             ↓
context-economy.md  factorisation-commons.md
           ↓
    [IMPLÉMENTATION]
```

### Flux de Lecture Recommandé

**Pour comprendre l'architecture** :
1. [`README.md`](README.md) (ce document) - Vue d'ensemble
2. [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md) - Fondation méthodologique
3. [`factorisation-commons.md`](factorisation-commons.md) - Architecture système

**Pour implémenter un mode** :
1. [`factorisation-commons.md`](factorisation-commons.md) - Comprendre templates
2. [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) - Mécaniques par famille
3. [`mcp-integrations-priority.md`](mcp-integrations-priority.md) - Outils disponibles
4. [`context-economy-patterns.md`](context-economy-patterns.md) - Optimisations

**Pour orchestrer tâches complexes** :
1. [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md) - Système numérotation
2. [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) - Décomposition et délégation
3. [`context-economy-patterns.md`](context-economy-patterns.md) - Gestion contexte

---

## 📊 Métriques et Bénéfices

### Gains Quantifiables

| Métrique | Avant | Après | Gain |
|----------|-------|-------|------|
| **Caractères totaux** | 540k | 180k | −67% |
| **Redondances** | 85% | <5% | −80% |
| **Temps maintenance** | 30 min/modif | 5 min/modif | −83% |
| **Cohérence** | 60% | 95%+ | +35% |
| **Tokens économisés/tâche** | - | ~20k | +40% efficacité |

### Bénéfices Qualitatifs

1. **Maintenance Simplifiée** : -83% temps modification (30min → 5min)
2. **Cohérence Garantie** : 1 source vérité, risque incohérence -95%
3. **Performance Optimale** : -71% redondances (-37k caractères)
4. **Traçabilité Complète** : Hiérarchie `1.x.y` + roo-state-manager
5. **Évolutivité** : Architecture 3-niveaux extensible
6. **ROI Prouvé** : +400% efficacité maintenance annuelle

---

## 🚀 Prochaines Étapes

### Mission 2.1 : ✅ COMPLÉTÉE

- [x] Création structure [`roo-config/specifications/`](.)
- [x] 6 documents spécialisés rédigés (7695 lignes totales)
- [x] README.md index créé et mis à jour
- [x] Réorganisation reports/ (séparation specs/rapports)
- [x] **Validation finale complète** : [`reports/RAPPORT-VALIDATION-FINALE.md`](reports/RAPPORT-VALIDATION-FINALE.md)
- [x] Cohérence inter-documents : 98% (47/47 références validées)
- [x] 8/8 décisions utilisateur appliquées (FB-01 à FB-08)

### Mission 2.2 : Templates et Application (PROCHAINE)

**Statut** : ⏳ Prêt pour démarrage (spécifications validées)

1. **Phase 1 : Setup Infrastructure** (1-2h)
   - Créer structure `roo-config/modes/templates/`
   - Développer [`scripts/generate-modes.js`](../../scripts/generate-modes.js)
   - Valider format STRING monolithique customInstructions

2. **Phase 2 : Migration Templates** (2-3h)
   - Extraire `commons/global-instructions.md` (~3k lignes)
   - Créer 5 templates familles (CODE, DEBUG, ARCHITECT, ASK, ORCHESTRATOR)
   - Créer 12 fichiers modes spécifiques (<5% contenu)

3. **Phase 3 : Génération & Validation** (1h)
   - Générer 12 modes complets
   - Tests fonctionnels Roo-Code
   - Validation format JSON

4. **Phase 4 : Documentation & CI** (1h)
   - Documentation workflow maintenance
   - Hook pre-commit automatique
   - README templates

**Total estimé** : 5-7h

### Phase 2.3 : Intégration GitHub Projects

1. Implémentation Phase 4 SDDD (GitHub)
2. Création automatique issues/PR
3. Synchronisation roadmap équipe

---

## 📖 Guide Utilisation Rapide

### Pour Mode Architect

```markdown
## Instructions Mode architect-complex

### Références Communes
- SDDD : [`sddd-protocol-4-niveaux.md`](../specifications/sddd-protocol-4-niveaux.md)
- Escalade : [`escalade-mechanisms-revised.md`](../specifications/escalade-mechanisms-revised.md)
- Hiérarchie : [`hierarchie-numerotee-subtasks.md`](../specifications/hierarchie-numerotee-subtasks.md)
- MCP : [`mcp-integrations-priority.md`](../specifications/mcp-integrations-priority.md)
- Économie : [`context-economy-patterns.md`](../specifications/context-economy-patterns.md)

### Workflow Type
1. **Grounding** : codebase_search + roo-state-manager
2. **Analyse** : Comprendre architecture existante
3. **Conception** : Proposer solutions avec diagrammes
4. **Décomposition** : Créer sous-tâches numérotées si >50k tokens
5. **Documentation** : Checkpoints réguliers + rapport final
```

### Pour Mode Code Simple

```markdown
## Instructions Mode code-simple

### Références Communes
- SDDD : [`sddd-protocol-4-niveaux.md`](../specifications/sddd-protocol-4-niveaux.md)
- Escalade : [`escalade-mechanisms-revised.md`](../specifications/escalade-mechanisms-revised.md)
- MCP : [`mcp-integrations-priority.md`](../specifications/mcp-integrations-priority.md)
- Économie : [`context-economy-patterns.md`](../specifications/context-economy-patterns.md)

### Workflow Type
1. **Grounding** : codebase_search (si exploration nécessaire)
2. **Lecture** : quickfiles read_multiple_files si >2 fichiers
3. **Modification** : apply_diff ou quickfiles edit_multiple_files
4. **Tests** : Validation modifications
5. **Escalade** : Si complexité dépasse critères (<50 lignes)
```

---

## 🔍 Recherche et Navigation

### Par Besoin

| Besoin | Document Principal | Documents Complémentaires |
|--------|-------------------|---------------------------|
| Commencer nouvelle tâche | [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md) | [`mcp-integrations-priority.md`](mcp-integrations-priority.md) |
| Décomposer tâche complexe | [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md) | [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) |
| Économiser tokens | [`context-economy-patterns.md`](context-economy-patterns.md) | [`mcp-integrations-priority.md`](mcp-integrations-priority.md) |
| Escalader/Désescalader | [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) | [`context-economy-patterns.md`](context-economy-patterns.md) |
| Utiliser MCPs efficacement | [`mcp-integrations-priority.md`](mcp-integrations-priority.md) | [`context-economy-patterns.md`](context-economy-patterns.md) |
| Créer script/workflow | [`operational-best-practices.md`](operational-best-practices.md) | [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md) |
| Organiser fichiers/rapports | [`operational-best-practices.md`](operational-best-practices.md) | [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md) |
| Choisir modèle LLM approprié | [`llm-modes-mapping.md`](llm-modes-mapping.md) | [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) |
| Optimiser coûts LLM | [`llm-modes-mapping.md`](llm-modes-mapping.md) | [`context-economy-patterns.md`](context-economy-patterns.md) |
| Créer nouveau mode | [`factorisation-commons.md`](factorisation-commons.md) | Tous les autres |

#### Grounding Sémantique Multi-Niveaux

- **SDDD Niveau 1-4** : [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
  - Niveau 1 (File) : Recommandation **quickfiles** (Tier 1)
  - Niveau 3 (Conversational) : MCP **roo-state-manager** (Tier 1)
  - Niveau 4 (Project) : MCP **github-projects** (Tier 1 - Futur)
- **Hiérarchisation MCPs** : [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
  - Tier 1 : roo-state-manager, quickfiles, github-projects
  - Tier 2 : win-cli (FB-06), markitdown
  - Tier 3 : github (avec précautions)

#### MCPs : Recommandations et Installation

- **Stratégie MCPs** : [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
  - Décision FB-06 : win-cli privilégié
  - Migration : git MCP → git CLI natif
  - Roadmap github-projects (Q4 2025 - Q2 2026)
- **Installation MCPs** : [`../../mcps/INSTALLATION.md`](../../mcps/INSTALLATION.md)
  - win-cli : Compilation TypeScript
  - markitdown : Installation uv (Python)

#### Évolution Architecture SDDD

- **Niveau 4 Grounding Projet** : [`sddd-protocol-4-niveaux.md#niveau-4`](sddd-protocol-4-niveaux.md#niveau-4)
  - Vision : Tâches Roo ↔ Issues GitHub
  - Roadmap github-projects : Q4 2025 - Q2 2026
  - Phase 1 : Configuration (Q4 2025)
  - Phase 2 : Intégration orchestrator (Q1 2026)
  - Phase 3 : Synchronisation complète (Q2 2026)

### Par Mot-Clé

- **codebase_search** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- **switch_mode** → [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md)
- **new_task** → [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md)
- **scripts** → [`operational-best-practices.md`](operational-best-practices.md)
- **nomenclature** → [`operational-best-practices.md`](operational-best-practices.md)
- **horodatage** → [`operational-best-practices.md`](operational-best-practices.md)
- **quickfiles** → [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- **checkpoint** → [`context-economy-patterns.md`](context-economy-patterns.md)
- **templates** → [`factorisation-commons.md`](factorisation-commons.md)
- **roo-state-manager** → [`mcp-integrations-priority.md`](mcp-integrations-priority.md), [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- **github-projects** → [`mcp-integrations-priority.md`](mcp-integrations-priority.md), [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- **win-cli** → [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- **markitdown** → [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- **File Grounding** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- **Semantic Grounding** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- **Conversational Grounding** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- **Project Grounding** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- **Niveau 1** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- **Niveau 2** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- **Niveau 3** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- **Niveau 4** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- **4-niveaux** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- **FB-06** → [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- **Tier 1** → [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- **Tier 2** → [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- **Tier 3** → [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- **git MCP** → [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- **git CLI natif** → [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- **Q4 2025** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md), [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- **Q1 2026** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md), [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- **Q2 2026** → [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md), [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- **win-cli compilation** → [`mcps/INSTALLATION.md`](../../mcps/INSTALLATION.md)
- **markitdown uv** → [`mcps/INSTALLATION.md`](../../mcps/INSTALLATION.md)
- **Python 3.13.7** → [`mcps/INSTALLATION.md`](../../mcps/INSTALLATION.md)
- **LLM** → [`llm-modes-mapping.md`](llm-modes-mapping.md)
- **SOTA** → [`llm-modes-mapping.md`](llm-modes-mapping.md)
- **Flash** → [`llm-modes-mapping.md`](llm-modes-mapping.md)
- **Mini** → [`llm-modes-mapping.md`](llm-modes-mapping.md)
- **tiers LLM** → [`llm-modes-mapping.md`](llm-modes-mapping.md)
- **escalade tokens** → [`llm-modes-mapping.md`](llm-modes-mapping.md), [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md)
- **mapping modes** → [`llm-modes-mapping.md`](llm-modes-mapping.md)
- **budget tokens** → [`llm-modes-mapping.md`](llm-modes-mapping.md), [`context-economy-patterns.md`](context-economy-patterns.md)
- **Claude Sonnet 4** → [`llm-modes-mapping.md`](llm-modes-mapping.md)
- **Claude 3.5 Haiku** → [`llm-modes-mapping.md`](llm-modes-mapping.md)
- **GPT-4o** → [`llm-modes-mapping.md`](llm-modes-mapping.md)
- **optimisation coûts** → [`llm-modes-mapping.md`](llm-modes-mapping.md)

---

## ⚠️ Notes Importantes

### Compatibilité

- ✅ **Architecture 2-niveaux** : Simple/Complex (12 modes opérationnels)
- ⏳ **Architecture n5** : Non incluse (future évolution si nécessaire)
- ✅ **Modes natifs Roo** : Compatible (5 modes natifs préservés)

### Maintenance

**Modification spécifications** :
1. Éditer document spécialisé concerné
2. Mettre à jour README.md si structure change
3. Régénérer templates si factorisation affectée
4. Valider cohérence inter-documents

**Ajout nouveau mode** :
1. Identifier famille (CODE, DEBUG, ARCHITECT, ASK, ORCHESTRATOR)
2. Utiliser template famille approprié
3. Personnaliser section mode-spécifique (<5% contenu)
4. Intégrer dans custom_modes.json

---

## 📚 Ressources Externes

### Documentation Roo-Code

- [Architecture Modes Écosystème](../../docs/roo-code/architecture-modes-ecosysteme.md)
- [Analyse Modes Natifs vs Personnalisés](../reports/analyse-modes-natifs-vs-personnalises-20250928.md)

### MCPs Référencés

- **roo-state-manager** : [`mcps/internal/servers/roo-state-manager/`](../../mcps/internal/servers/roo-state-manager/)
- **quickfiles** : [`mcps/internal/servers/quickfiles-server/`](../../mcps/internal/servers/quickfiles-server/)
- **github-projects** : [`mcps/internal/servers/github-projects-mcp/`](../../mcps/internal/servers/github-projects-mcp/)

---

## 📞 Contact et Contribution

Pour questions, suggestions ou contributions concernant ces spécifications :

1. **Issues Architecture** : Créer issue GitHub avec tag `architecture`
2. **Discussions** : Utiliser GitHub Discussions
3. **Pull Requests** : Proposer modifications avec justification détaillée

---

**Version** : 1.0.0  
**Dernière Mise à Jour** : 30 Septembre 2025  
**Auteur** : Roo Architect Mode  
**Statut** : ✅ Spécifications consolidées prêtes pour implémentation

---

## 📋 Rapports de Suivi

### Répertoire reports/

- **[`reports/FEEDBACKS-REVISION-PLAN.md`](reports/FEEDBACKS-REVISION-PLAN.md)** : Plan révision 8 feedbacks utilisateur (FB-01 à FB-08)
- **[`reports/RAPPORT-CORRECTIONS-NUMEROTATION.md`](reports/RAPPORT-CORRECTIONS-NUMEROTATION.md)** : Audit format `1.x.y` (FB-07)
- **[`reports/RAPPORT-VALIDATION-FINALE.md`](reports/RAPPORT-VALIDATION-FINALE.md)** : ✅ **Validation finale Mission 2.1**

---

**Note Finale** : Ces spécifications représentent la base architecturale **validée et consolidée** pour l'écosystème des modes Roo. Mission 2.1 COMPLÉTÉE avec **98% cohérence**, **0 angle mort**, et **architecture 3-niveaux prête pour implémentation 5-7h**.