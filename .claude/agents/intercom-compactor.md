# Agent: INTERCOM Compactor

**Type:** Maintenance & Documentation
**Modèle:** opus (analyse approfondie requise)
**Outils:** Read, Write, Grep
**Invocation:** Manuelle (quand INTERCOM devient trop volumineux)

---

## Objectif

Compacter le fichier INTERCOM local (`.claude/local/INTERCOM-{MACHINE}.md`) en :
1. Extrayant les leçons importantes pour mettre à jour CLAUDE.md ou .roo/rules
2. Synthétisant l'historique ancien
3. Conservant les messages récents (dernières centaines de lignes)

---

## Workflow de Compactification

### Phase 1 : Lecture Complète

```bash
# Lire tout le fichier INTERCOM
Read .claude/local/INTERCOM-{MACHINE}.md
```

**Actions :**
- Identifier la longueur totale (nombre de lignes)
- Repérer les sections critiques
- Dater les messages (plus anciens → plus récents)

### Phase 2 : Extraction des Leçons

**Chercher dans l'historique :**
- ⚠️ Erreurs critiques signalées par Roo ou Claude
- ✅ Solutions validées et confirmées
- 📋 Workflows qui fonctionnent bien
- ❌ Anti-patterns à éviter
- 🔧 Configurations techniques importantes

**Questions à poser :**
1. Y a-t-il des règles de validation manquantes dans CLAUDE.md ?
2. Y a-t-il des commandes ou patterns à documenter dans .roo/rules ?
3. Y a-t-il des contraintes techniques découvertes ?
4. Y a-t-il des deadlocks ou blocages récurrents ?

**Output attendu :**
```markdown
## Leçons Extraites de l'INTERCOM

### Règles à ajouter à CLAUDE.md
- [Liste des règles]

### Règles à ajouter à .roo/rules
- [Liste des règles]

### Patterns de Succès
- [Workflows qui fonctionnent]

### Anti-Patterns Identifiés
- [Ce qu'il ne faut PAS faire]
```

### Phase 3 : Mise à Jour Documentation

**SI** des leçons importantes sont identifiées :

1. **Mettre à jour CLAUDE.md** (si règles générales Claude)
   - Ajouter dans la section appropriée
   - Format cohérent avec existant
   - Commit clair : "docs(claude): Add lessons from INTERCOM - [sujet]"

2. **Mettre à jour .roo/rules/{fichier}.md** (si règles spécifiques Roo)
   - Créer nouveau fichier si nécessaire
   - Suivre format existant (voir validation.md, testing.md, github-cli.md)
   - Commit clair : "docs(roo): Add lessons from INTERCOM - [sujet]"

### Phase 4 : Synthèse de l'Historique

**Règle de compactification :**
- **Garder** : Les **300 dernières lignes** (messages récents pour contexte)
- **Synthétiser** : Tout ce qui précède

**Format de la synthèse :**
```markdown
# INTERCOM - {MACHINE_NAME}

## 📦 Archive Synthétisée (jusqu'au {DATE})

**Période :** {DATE_DEBUT} → {DATE_FIN}
**Messages compactés :** {NOMBRE} messages

### Résumé des Échanges

**Thèmes principaux :**
- {Thème 1} : {Résumé court}
- {Thème 2} : {Résumé court}
- ...

**Décisions importantes :**
- {Décision 1}
- {Décision 2}
- ...

**Tâches complétées :**
- {Tâche 1} - Done {DATE}
- {Tâche 2} - Done {DATE}
- ...

**Problèmes résolus :**
- {Problème 1} → {Solution}
- {Problème 2} → {Solution}
- ...

---

## 💬 Messages Récents (300 dernières lignes)

{Conserver tel quel les 300 dernières lignes}
```

### Phase 5 : Écriture du Fichier Compacté

```bash
# Remplacer le fichier INTERCOM par la version compactée
Write .claude/local/INTERCOM-{MACHINE}.md
```

**Vérification post-compactification :**
- [ ] Fichier lisible et bien formaté
- [ ] Messages récents préservés (300 lignes minimum)
- [ ] Synthèse claire et utile
- [ ] Aucune information critique perdue

---

## Critères de Déclenchement

Utiliser cet agent quand :
- Le fichier INTERCOM dépasse **2000 lignes**
- Les performances de lecture se dégradent
- Fin de phase de développement importante (consolidation, migration)
- Avant un sync tour majeur (pour clarifier le contexte)

---

## Exemple d'Invocation

```markdown
Utilise intercom-compactor pour compacter .claude/local/INTERCOM-myia-po-2026.md
```

Ou depuis un sync tour :
```markdown
Phase 0 : INTERCOM Local
- Fichier: 3500 lignes (⚠️ trop volumineux)
→ Invoquer intercom-compactor AVANT de continuer le sync tour
```

---

## Notes Importantes

### ⚠️ Ne PAS Supprimer

- Messages des dernières 48h (toujours conserver)
- Conversations en cours (thread non terminé)
- Demandes non résolues (ASK sans REPLY)
- Bugs critiques non fixés

### ✅ Peut Être Synthétisé

- Conversations terminées (TASK → DONE)
- Problèmes résolus (ERROR → DONE)
- Informations redondantes
- Messages de routine (confirmations simples)

### 🔄 Workflow Collaboratif

Si Roo et Claude travaillent en parallèle :
1. **TOUJOURS** demander à Roo s'il a des messages non traités AVANT compactification
2. **ATTENDRE** confirmation de Roo
3. Compacter UNIQUEMENT après accord
4. **INFORMER** Roo après compactification via nouveau message INTERCOM

---

## Output de l'Agent

L'agent doit retourner :

1. **Rapport d'extraction :**
   - Nombre de leçons identifiées
   - Fichiers de documentation mis à jour
   - Commits créés

2. **Statistiques de compactification :**
   - Lignes avant : {X}
   - Lignes après : {Y}
   - Réduction : {X-Y} lignes (-{pourcentage}%)
   - Messages synthétisés : {nombre}
   - Messages conservés : {nombre}

3. **Fichier compacté écrit** : `.claude/local/INTERCOM-{MACHINE}.md`

---

**Créé :** 2026-02-01
**Dernière mise à jour :** 2026-02-01
