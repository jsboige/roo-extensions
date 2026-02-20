---
name: debrief
description: Analyse et documente la session courante avec triple grounding SDDD. Utilise ce skill à la fin d'une session de travail, quand l'utilisateur tape /debrief, pour capturer les leçons apprises, consolider la mémoire (MEMORY.md) et préparer la transition vers la session suivante. Phrase déclencheur : "/debrief", "débrief", "fin de session", "documente ce qu'on a fait".
---

# Skill: Debrief - Analyse et Documentation de Session

**Version:** 2.0.0
**Cree:** 2026-02-12
**MAJ:** 2026-02-21
**Usage:** `/debrief`
**Methodologie:** SDDD triple grounding (voir `.claude/rules/sddd-conversational-grounding.md`)

---

## Objectif

Analyser le travail effectue dans la session courante, documenter les lecons apprises, et preparer un resume structure pour transition vers une nouvelle session ou vers l'assistant Roo.

---

## Workflow

### Phase 1 : Analyse de la Session (Triple Grounding)

**Actions :**
1. **Grounding conversationnel** : Consulter ce que Roo a fait en parallele
   ```
   conversation_browser(action: "current", workspace: "d:\\roo-extensions")
   ```
   Si une tache Roo est active, lire son squelette :
   ```
   conversation_browser(action: "view", task_id: "{ID}", detail_level: "skeleton", smart_truncation: true)
   ```
2. **Grounding semantique** : Verifier si des taches similaires ont ete faites recemment
   ```
   roosync_search(action: "semantic", search_query: "sujet principal de la session")
   ```
3. Identifier les taches principales accomplies (conversation courante)
4. Lister les problemes rencontres et resolus
5. Extraire les outils/commandes utilises
6. Mesurer les metriques cles (temps, tests, commits, etc.)

**Methode :**
- Croiser le triple grounding : historique conversation + traces Roo + recherche semantique
- Identifier les patterns : problemes → diagnostic → solution
- Extraire les commandes Bash executees
- Noter les outils MCP utilises

### Phase 2 : Extraction des Lecons

**Grounding semantique (deduplication) :**
Avant d'ecrire une lecon, verifier qu'elle n'existe pas deja :
```
codebase_search(query: "description de la lecon", workspace: "d:\\roo-extensions")
```
Si codebase_search retourne un fichier existant avec cette info → ne pas dupliquer.

**Categories de lecons :**
- **Problemes Techniques** : Root causes, solutions, workarounds
- **Processus** : Workflows efficaces, patterns reutilisables
- **Outils** : Decouvertes, configurations, best practices
- **Coordination** : Communication RooSync, INTERCOM, GitHub
- **Performance** : Optimisations, gains de temps
- **Friction** : Problemes avec les outils/skills a signaler au collectif

**Format par lecon :**
```
Categorie: [Technique|Processus|Outils|Coordination|Performance|Friction]
Probleme: [Description courte]
Solution: [Action concrete]
Impact: [Resultat mesurable]
Reutilisable: [Oui/Non]
```

**Si friction detectee** : Envoyer un message au collectif (voir protocole de friction dans `.claude/rules/sddd-conversational-grounding.md`).

### Phase 3 : Documentation Mémoire

**Cibles :**
1. **Mémoire Auto** (`.claude/memory/MEMORY.md`)
   - Patterns confirmés multi-sessions
   - Configurations critiques
   - Procédures récurrentes

2. **Mémoire Projet** (`.claude/memory/PROJECT_MEMORY.md`)
   - Leçons spécifiques au projet roo-extensions
   - Décisions architecturales
   - Incidents majeurs et résolutions

**Règles d'écriture :**
- Fusionner avec contenu existant (éviter duplication)
- Format concis (bullet points)
- Dates et contextes clairs
- Liens vers issues GitHub si applicable

### Phase 4 : Mise à Jour INTERCOM

**Contenu :**
```markdown
## [TIMESTAMP] claude-code → roo [DEBRIEF]

### Session Recap - [DATE]

**Tâches Accomplies :**
- [Liste avec statuts ✅/⏳]

**Problèmes Résolus :**
- [Problème] → [Solution]

**État Système :**
- Git: [statut]
- Build: [statut]
- Tests: [résultats]
- MCPs: [statut]

**Actions Requises pour Roo :**
- [Directives claires pour prochain cycle]

**Monitoring :**
- [Éléments à surveiller]
```

### Phase 5 : Résumé pour Utilisateur

**Format :**
```
# 📊 Debrief Session - [DATE]

## ✅ Accompli
[Liste concise]

## 🎓 Leçons Clés
[3-5 leçons principales]

## 📁 Documentation
[Fichiers mis à jour]

## 🎯 Next Steps
[Actions recommandées]
```

---

## 🛠️ Outils Utilisés

- **Read** : Lire mémoire existante, INTERCOM
- **Edit** : Mettre à jour MEMORY.md, PROJECT_MEMORY.md
- **Grep** : Chercher duplications avant écriture
- **Bash** : Extraire métriques git (commits, files changed)

---

## 📏 Critères de Qualité

**Une bonne leçon doit être :**
- ✅ **Concrète** : Action spécifique, pas vague
- ✅ **Réutilisable** : Applicable à futures sessions
- ✅ **Mesurable** : Impact quantifiable si possible
- ✅ **Contextuelle** : Quand/où appliquer

**Exemples :**

❌ **Mauvais** : "Mieux vérifier les configs"
✅ **Bon** : "Toujours vérifier `transportType: 'stdio'` dans `~/.claude.json` avant debug MCPs"

❌ **Mauvais** : "Communication importante"
✅ **Bon** : "Envoyer rapport RooSync au coordinateur dans les 5min après reconnexion pour éviter escalade"

---

## 🚀 Invocation

```bash
# Depuis la commande
/debrief

# Le skill s'exécute automatiquement via la commande
```

---

## 📝 Notes

- **Durée estimée** : 2-3 minutes
- **Fréquence recommandée** : Fin de chaque session de travail significative
- **Pré-requis** : Avoir accompli au moins 1 tâche substantielle
- **Output** : Résumé markdown + fichiers mémoire mis à jour

---

**Dernière mise à jour :** 2026-02-12
