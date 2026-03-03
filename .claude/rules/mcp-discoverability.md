# Règle Tests de Découvrabilité MCP

**Version:** 1.0.0
**Créé:** 2026-03-03
**Issue:** #486 Proposition P4

---

## Objectif

Vérifier que les nouveaux outils MCP sont **découvrables** et **utilisables** par les agents Claude Code et Roo. Cette règle complète le protocole STOP & REPAIR défini dans `tool-availability.md`.

## Quand Tester

- **Ajout d'un nouveau MCP** : Avant déploiement
- **Modification de alwaysAllow** : Après mise à jour
- **Nouvelle fonctionnalité MCP** : Avant de documenter
- **Rapport de bug** : Pour identifier les outils non-découvrables
- **Validation de session** : Au démarrage d'une session (Phase 0 STOP & REPAIR)

## Tests de Découvrabilité

### Test 1: Visibilité (system-reminders)

**Objectif:** Vérifier que l'outil apparaît dans les system-reminders

**Procédure:**
- Vérifier les system-reminders au début de conversation
- Compter le nombre d'outils attendus vs. présents

**Résultat attendu:** L'outil est listé avec le nom exact attendu

### Test 2: Fonctionnalité (appel simple)

**Objectif:** Vérifier que l'outil répond correctement

**Procédure:**
```
# Exemples d'appels simples
# - win-cli: execute_command(shell="powershell", command="echo OK")
# - roo-state-manager: conversation_browser(action: "current")
# - playwright: browser_snapshot()
```

**Résultat attendu:** Retour valide en < 5 secondes

### Test 3: Intégration (workflow)

**Objectif:** Vérifier l'intégration avec le workflow existant

**Procédure:**
- Tester l'outil dans un scénario réaliste
- Vérifier absence de conflit avec autres outils

**Résultat attendu:** L'outil fonctionne sans conflit

## Checklist de Validation

```markdown
## Découvrabilité MCP - [Nom du MCP]

| Test | Statut | Notes |
|------|--------|-------|
| Visibilité (system-reminders) | ⬜ | |
| Fonctionnalité (appel simple) | ⬜ | |
| Intégration (workflow) | ⬜ | |
| Documentation (CLAUDE.md/rules) | ⬜ | |
```

## Intégration Workflow de Validation

Les tests de découvrabilité s'exécutent **AVANT** le build et les tests unitaires:

```
1. Tests découvrabilité MCP → 2. Build TypeScript → 3. Tests unitaires
```

## Rapport de Problèmes

Si un test échoue → appliquer le protocole STOP & REPAIR (`tool-availability.md`)

---

**Références:**
- `tool-availability.md` - STOP & REPAIR
- `validation-checklist.md` - Validation code
- `testing.md` - Commandes de test

---

**Dernière mise à jour:** 2026-03-03
