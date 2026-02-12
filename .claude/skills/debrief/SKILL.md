# Skill: Debrief - Analyse et Documentation de Session

**Version:** 1.0.0
**Créé:** 2026-02-12
**Usage:** `/debrief`

---

## 🎯 Objectif

Analyser le travail effectué dans la session courante, documenter les leçons apprises, et préparer un résumé structuré pour transition vers une nouvelle session ou vers l'assistant Roo.

---

## 📋 Workflow

### Phase 1 : Analyse de la Session

**Actions :**
1. Identifier les tâches principales accomplies
2. Lister les problèmes rencontrés et résolus
3. Extraire les outils/commandes utilisés
4. Mesurer les métriques clés (temps, tests, commits, etc.)

**Méthode :**
- Parcourir l'historique de conversation (messages User + Assistant récents)
- Identifier les patterns : problèmes → diagnostic → solution
- Extraire les commandes Bash exécutées
- Noter les outils MCP utilisés

### Phase 2 : Extraction des Leçons

**Catégories de leçons :**
- **Problèmes Techniques** : Root causes, solutions, workarounds
- **Processus** : Workflows efficaces, patterns réutilisables
- **Outils** : Découvertes, configurations, best practices
- **Coordination** : Communication RooSync, INTERCOM, GitHub
- **Performance** : Optimisations, gains de temps

**Format par leçon :**
```
Catégorie: [Technique|Processus|Outils|Coordination|Performance]
Problème: [Description courte]
Solution: [Action concrète]
Impact: [Résultat mesurable]
Réutilisable: [Oui/Non]
```

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
