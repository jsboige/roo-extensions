# Commande: /debrief

**Version:** 1.0.0
**Créé:** 2026-02-12

---

## Description

Analyse la session de travail courante, documente les leçons apprées, et prépare un résumé structuré pour transition.

**Utilise le skill :** `.claude/skills/debrief/SKILL.md`

---

## Usage

```bash
/debrief
```

---

## Quand Utiliser

- ✅ **Fin de session Claude Code** avant de lancer `/executor`
- ✅ **Après résolution d'un problème complexe** (>1h de travail)
- ✅ **Après complétion de tâches assignées** par coordinateur
- ✅ **Périodiquement** (ex: avant chaque tour de sync majeur)

---

## Ce que Fait la Commande

### 1. Analyse de Session
- Identifie tâches accomplies
- Liste problèmes résolus
- Extrait métriques (tests, commits, temps)

### 2. Documentation Leçons
- Met à jour `~/.claude/projects/<hash>/memory/MEMORY.md` (patterns généraux, par machine)
- Met à jour `.claude/memory/PROJECT_MEMORY.md` (leçons projet)
- Évite duplication avec contenu existant

### 3. Mise à Jour INTERCOM
- Ajoute résumé session pour Roo
- Liste actions requises
- Indique éléments à monitorer

### 4. Résumé Utilisateur
- Récap concis des accomplissements
- 3-5 leçons clés
- Fichiers mis à jour
- Next steps recommandés

---

## Output Attendu

```
# 📊 Debrief Session - 2026-02-12

## ✅ Accompli
- MCPs RooSync réparés (transportType: "stdio")
- 10 messages RooSync rattrapés
- Tâches #458, #459, #460 complétées
- Build 0 erreurs, 3252 tests passed

## 🎓 Leçons Clés
1. Toujours vérifier transportType dans config MCP globale
2. Triage messages urgents avant non-urgents (gain temps)
3. Redémarrer VS Code immédiatement après deploy scheduler
4. Todo list essentielle pour tâches multi-étapes (>3 actions)
5. Envoyer rapport coordinateur dans 5min après reconnexion

## 📁 Documentation
- `~/.claude/projects/<hash>/memory/MEMORY.md` (ajout section MCP Setup)
- `.claude/memory/PROJECT_MEMORY.md` (leçon coordinator escalation)
- `.claude/local/INTERCOM-myia-po-2023.md` (résumé session)

## 🎯 Next Steps
- Monitoring scheduler cycles 18:00 et 21:00 (validation #459)
- Lire 5 messages RooSync restants (non urgents)
- Disponible pour nouvelles tâches coordinateur
```

---

## Workflow Interne

La commande exécute le workflow suivant (défini dans le skill) :

1. **Phase 1** : Analyse session (historique conversation)
2. **Phase 2** : Extraction leçons (patterns réutilisables)
3. **Phase 3** : Documentation mémoire (MEMORY.md + PROJECT_MEMORY.md)
4. **Phase 4** : Mise à jour INTERCOM (résumé pour Roo)
5. **Phase 5** : Résumé utilisateur (output final)

---

## Exemples d'Usage

### Cas 1 : Fin de Session Normale

```bash
# Après avoir complété des tâches
/debrief
# → Analyse session, documente leçons, prépare transition
```

### Cas 2 : Après Incident Résolu

```bash
# Après 6h de diagnostic MCPs
/debrief
# → Focus sur root cause, solution, prevention future
```

### Cas 3 : Avant Executor

```bash
# Avant de lancer /executor
/debrief
# → Récap accomplissements, next steps pour Roo
```

---

## Notes Importantes

- ⏱️ **Durée** : 2-3 minutes d'exécution
- 📝 **Automatique** : Pas d'input utilisateur requis
- 🎯 **Focus** : Leçons réutilisables, pas juste résumé
- 🔄 **Idempotent** : Peut être relancé sans duplication

---

## Commandes Complémentaires

- `/sync-tour` - Tour de synchronisation complet (avant debrief)
- `/executor` - Session exécution Roo (après debrief)
- `/coordinate` - Session coordination (myia-ai-01 uniquement)

---

**Skill associé :** `.claude/skills/debrief/SKILL.md`
**Dernière mise à jour :** 2026-02-12
