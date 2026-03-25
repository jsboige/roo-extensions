# Protocole d'Escalade Claude Code

**Version:** 1.0.0
**Créé:** 2026-03-25
**Issue:** #842

---

## Principe

Quand Claude Code est bloqué ou face à un problème qu'il ne peut résoudre avec ses capacités actuelles, il doit **escalader** vers des méthodes plus sophistiquées. Contrairement à Roo qui a des niveaux 4-5 (Claude CLI, API directe), **Claude Code EST déjà le niveau maximum** (Opus 4.6). L'escalade pour Claude Code signifie donc : déléguer à des sous-agents, utiliser des outils spécialisés, ou demander à l'utilisateur.

---

## Chaîne d'Escalade Claude Code (5 Niveaux)

| Niveau | Action | Quand l'utiliser | Outils/Agents |
|--------|--------|------------------|---------------|
| **1** | **Outils directs** | Défaut - toute tâche commence ici | Read, Grep, Bash, Edit, Write |
| **2** | **Sub-agent spécialisé** | Tâche complexe ou multi-fichier | code-fixer, test-investigator, Explore |
| **3** | **sk-agent délibération** | Décision architecturale, trade-offs | deep-think, code-review, run_conversation |
| **4** | **Recherche SDDD multi-pass** | Information introuvable par méthodes simples | codebase_search + conversation_browser + roosync_search |
| **5** | **Escalade utilisateur** | Blocage, décision non-technique, approbation | Batch de questions via AskUserQuestion |

---

## Critères de Passage Niveau → Niveau

### Niveau 1 → Niveau 2 (Sub-agent)
**Escalader si :**
- La tâche nécessite plus de 3 fichiers interconnectés
- L'investigation dépasse 10 fichiers sans conclusion
- Pattern de recherche complexe (ex: "trouver toutes les utilisations de X dans le codebase")

**Ne PAS escalader si :**
- Tâche simple sur 1-2 fichiers connus
- Modification localisée avec contexte clair

### Niveau 2 → Niveau 3 (sk-agent délibération)
**Escalder si :**
- Décision architecturale requise (choix entre approches)
- Trade-offs non triviaux (performance vs maintenabilité)
- Analyse de code critique (PR review, refactoring majeur)

**Ne PAS escalader si :**
- Implémentation guidée avec spécifications claires
- Tâche purement mécanique (formatting, renommage)

### Niveau 3 → Niveau 4 (SDDD multi-pass)
**Escalder si :**
- Information introuvable après 2+ passes codebase_search
- Nécessité de comprendre le contexte historique (traces Roo, sessions passées)
- Validation d'hypothèse contre la base de connaissances projet

**Ne PAS escalader si :**
- Information trouvée dans les 2 premières passes
- Tâche ne nécessitant pas de contexte historique

### Niveau 4 → Niveau 5 (Utilisateur)
**Escalder si :**
- **2 échecs consécutifs** avec des approches différentes
- **Blocage structurel** (nécessité de décision utilisateur)
- **Question de préférence** (esthétique, nommage, priorisation)
- **Approbation requise** (création issue GitHub, destruction de code)

**Ne PAS escalader si :**
- Première tentative échoue (toujours réessayer avec approche différente)
- Question technique (continuer à investiguer)

---

## Procédure par Niveau

### Niveau 1 : Outils Directs
**C'est le mode par défaut.** Utiliser les outils MCP natifs :
- `Read` - Lire un fichier spécifique
- `Grep` - Rechercher du texte dans le codebase
- `Glob` - Trouver des fichiers par pattern
- `Bash` - Exécuter des commandes shell
- `Edit`/`Write` - Modifier/créer des fichiers

**Règle :** Toujours commencer ici. Ne pas sauter directement aux sous-agents pour une tâche simple.

### Niveau 2 : Sub-Agent Spécialisé
**Déléguer à un agent avec expertise spécifique :**

```typescript
// Exemples d'agents disponibles
Agent("code-fixer") // Investigation + correction de bugs
Agent("test-investigator") // Analyse tests échoués
Agent("Explore") // Exploration codebase rapide
Agent("code-explorer") // Investigation approfondie
```

**Quand déléguer :**
- La tâche est autonome (entrées claires, sorties attendues)
- Peut être parallélisée avec d'autres tâches
- Requiert une recherche approfondie

**Voir aussi :** `.claude/rules/delegation.md` pour les règles de délégation.

### Niveau 3 : sk-Agent Délibération
**Utiliser sk-agent pour des capacités de raisonnement étendues :**

```
sk-agent call_agent avec options:
- "deep-think" : Décisions architecturales complexes
- "code-review" : Analyse critique de PR/diff
- "run_conversation" : Multi-agent délibération
```

**Modèles disponibles sk-agent :**
- Qwen 3.5 (délibération)
- GLM-5 (puissance maximale)
- DeepSeek (raisonnement)

**Note :** sk-agent est un proxy vers des modèles LLM avec outils et mémoire, pas un remplacement de Claude Code.

### Niveau 4 : Recherche SDDD Multi-Pass
**Protocole SDDD (Semantic Documentation Driven Development) :**

1. **Pass 1 - Recherche sémantique large** (codebase_search sans directory_prefix)
   - But : identifier le répertoire/module pertinent
2. **Pass 2 - Zoom avec directory_prefix** (vocabulaire du code)
   - But : cibler le module avec noms de fonctions/types
3. **Pass 3 - Grep de confirmation** (vérité technique)
   - But : confirmer et compléter avec recherche exacte
4. **Pass 4 - Conversationnel** (conversation_browser)
   - But : analyser traces Roo et sessions Claude passées

**Référence :** `.claude/rules/sddd-conversational-grounding.md`

### Niveau 5 : Escalade Utilisateur
**Quand 2+ approches ont échoué ou une décision utilisateur est requise :**

Utiliser l'outil `AskUserQuestion` avec un **batch de questions** :
- Accumuler toutes les questions en une seule fois
- Présenter avec contexte, options identifiées, recommendations
- Ne pas poser une question à la fois (éviter les allers-retours)

**Exemple :**
```typescript
AskUserQuestion({
  questions: [{
    question: "Approche pour le refactoring du module auth ?",
    header: "Architecture",
    options: [
      { label: "Rewrite complet", description: "Plus propre mais plus risqué" },
      { label: "Refactor incrémental", description: "Plus sûr mais plus long" }
    ]
  }]
})
```

---

## Référence Croisée avec Roo

**Document Roo équivalent :** `docs/roosync/ESCALATION_MECHANISM.md`

Le mécanisme Roo a 3 types d'escalade (descendante, sur place, sortante) avec niveaux 4-5 (Claude CLI, API directe). Claude Code **n'a pas ces niveaux** car il EST déjà le niveau maximum (Opus 4.6).

**Correspondance :**
- Roo niveau 1-3 (modes -simple/-complex) ≈ Claude Code niveau 1 (outils directs)
- Roo niveau 4 (Claude CLI) ≈ Claude Code niveau 2-3 (sub-agents, sk-agent)
- Roo niveau 5 (API directe) ≈ Claude Code niveau 5 (escalade utilisateur)

**Ce que Claude Code n'est PAS :**
- Un subordonné de Roo ou Claude CLI
- Capable d'escalader vers "un modèle plus puissant" (Opus 4.6 est déjà le max)
- Un outil de commande passive (c'est un assistant interactif)

---

## Critères d'Escalade (✅/❌)

### ✅ Escalader si :

1. **Échecs répétés** : 2+ tentatives avec approches différentes ont échoué
2. **Problème hors portée** : La tâche nécessite des capacités non disponibles (ex: système externe)
3. **Blocage structurel** : Un problème architectural nécessite une refonte complète
4. **Urgence critique** : Le problème bloque toute progression sur le projet

### ❌ NE PAS escalader si :

1. **Premier échec** : Toujours réessayer avec une approche différente
2. **Manque d'information** : Chercher d'abord dans la documentation/code
3. **Problème simple** : La tâche peut être résolue avec plus de temps/patience
4. **Question utilisateur** : Demander à l'utilisateur est plus approprié

---

## Format de Rapport d'Escalade

Quand vous escaladez (sous-agent ou utilisateur), documentez toujours :

```markdown
## Escalade Niveau X - [Tâche]

**Problème:** [Description]
**Tentatives:**
1. [Approche 1] - Résultat: [échec/partiel]
2. [Approche 2] - Résultat: [échec/partiel]

**Raison escalade:** [Pourquoi le niveau actuel est insuffisant]

**Action:** [Sub-agent / Question utilisateur / SDDD multi-pass]
**Résultat:** [Success/Echec]
```

---

## Références

- Issue #842 : Création de ce document
- Roo equivalent : `docs/roosync/ESCALATION_MECHANISM.md` (mécanisme Roo 3 couches)
- `.claude/rules/delegation.md` : Règles de délégation aux sub-agents
- `.claude/rules/sddd-conversational-grounding.md` : Protocole SDDD multi-pass
- `.claude/rules/skepticism-protocol.md` : Scepticisme raisonnable (vérifier avant de propager)

---

**Dernière mise à jour :** 2026-03-25
**Mainteneur :** Coordinateur RooSync (myia-ai-01)
