# Règles SDDD - Grounding Technique

## Protocole SDDD (Semantic Documentation Driven Design)

Le SDDD est la méthodologie de développement utilisée dans ce projet. Version actuelle : **v2.7.0**

---

## Triple Grounding

Avant toute tâche significative, effectuer le **triple grounding** :

### 1. Grounding Sémantique

**Objectif :** Comprendre le contexte et la terminologie

**Actions :**
- Rechercher documentation existante (`docs/`, `roo-config/`)
- Identifier patterns et conventions du codebase
- Lire les issues GitHub liées

**Outils :**
```bash
# Recherche par pattern
grep -r "terme" docs/
grep -r "terme" mcps/internal/servers/roo-state-manager/src/
```

### 2. Grounding Conversationnel

**Objectif :** Comprendre l'historique et les décisions

**Actions :**
- Lire INTERCOM (messages récents)
- Consulter git log des fichiers concernés
- Vérifier les commentaires sur les issues GitHub

**Outils :**
```bash
# Historique d'un fichier
git log --oneline -10 -- path/to/file

# Messages récents
cat .claude/local/INTERCOM-{MACHINE}.md | tail -100
```

### 3. Grounding Technique

**Objectif :** Comprendre le code et la faisabilité

**Actions :**
- Lire le code source concerné
- Identifier les dépendances
- Vérifier les tests existants
- Valider la faisabilité technique

**Outils :**
```bash
# Dépendances d'un fichier
grep -r "import.*from" path/to/file

# Tests associés
find . -name "*test*" -path "*/__tests__/*" | grep "filename"
```

---

## Critères Simple vs Complex

### Mode Simple (code-simple)

**Utiliser si :**
- Tâche clairement définie avec un seul objectif
- Modification de 1-3 fichiers maximum
- Pas de décision architecturale requise
- Pattern existant à suivre
- < 50 lignes de code

**Exemples :**
- Corriger un typo
- Ajouter un champ à un JSON existant
- Créer un test unitaire simple
- Renommer une variable

### Mode Complex (code-complex)

**Utiliser si :**
- Tâche avec multiples sous-objectifs
- Modification de 4+ fichiers
- Décision architecturale requise
- Nouveau pattern à établir
- > 50 lignes de code
- Coordination multi-agent nécessaire

**Exemples :**
- Implémenter une nouvelle fonctionnalité MCP
- Refactorer un module
- Résoudre bug affectant plusieurs composants
- Créer nouvelle stratégie de synchronisation

---

## Triggers d'Escalade

### Simple → Complex

Escalader immédiatement si :

1. **> 3 fichiers** à modifier
2. **> 50 lignes** de code
3. **Décision architecturale** non triviale
4. **2 erreurs consécutives** non résolues
5. **Dépendance circulaire** détectée
6. **Conflit** avec pattern existant

**Action :**
```markdown
## [TIMESTAMP] roo → claude-code [INFO]

### Escalade simple → complex

**Raison :** [trigger détecté]
**Tâche :** [description]
**Fichiers concernés :** [liste]

Je passe en mode complex.

---
```

### Complex → Simple

Désescalader si :

1. **Sous-tâche isolée** identifiée
2. **Pattern clair** établi après analyse
3. **< 20 lignes** de code final

---

## Documentation des Tâches

### Avant de Commencer

Documenter dans INTERCOM :
- Tâche assignée (issue #)
- Fichiers à modifier
- Approche prévue

### Après Complétion

Documenter dans INTERCOM :
- Résultat (commit hash)
- Tests passés
- Écarts vs plan initial

---

## Références

- **PROTOCOLE_SDDD.md :** `docs/roosync/PROTOCOLE_SDDD.md`
- **level-criteria.json :** `roo-config/sddd/level-criteria.json`
- **CLAUDE_CODE_GUIDE.md :** `.claude/CLAUDE_CODE_GUIDE.md`

---

*Le grounding n'est pas optionnel. Il évite les erreurs coûteuses.*
