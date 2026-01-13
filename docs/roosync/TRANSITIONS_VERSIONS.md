# Guide des Transitions de Version RooSync

**Date** : 2026-01-10
**Auteur** : myia-po-2023 (Claude Code)
**Tache** : T2.18 - Clarifier les transitions de version

---

## Resume Executif

Ce document clarifie les transitions entre les versions RooSync v2.1, v2.2 et v2.3. Il explique les differences entre chaque version, les types de changements, et les impacts pour les utilisateurs, developpeurs et operateurs.

---

## Vue d'Ensemble des Versions

### Tableau Comparatif

| Version | Date | Type | API | Architecture | Documentation |
|---------|------|------|-----|--------------|---------------|
| **v2.1** | 2025-12-27 | Architecture Baseline-Driven | 17 outils | BaselineService | Complete |
| **v2.2** | 2025-12-27 | Publication de configuration | 17 outils (inchangee) | BaselineService (inchangee) | Partielle |
| **v2.3** | 2025-12-27 | Consolidation majeure | 12 outils (-29%) | NonNominativeBaselineService | Complete |

### Diagramme de Transition

```
v2.1 (Architecture)
    |
    | Publication de configuration WP4
    v
v2.2 (Configuration)
    |
    | Consolidation majeure de l'API
    v
v2.3 (Consolidation)
```

---

## Version 2.1 : Architecture Baseline-Driven

### Description

La version v2.1 introduit l'architecture **baseline-driven** qui utilise une baseline unique (`sync-config.ref.json`) comme source de verite.

### Caracteristiques

- **Service Principal** : `BaselineService`
- **Approche** : Nominative (basee sur `machineId`)
- **Outils MCP** : 17 outils exportes
- **Workflow** : Compare -> Validate -> Apply

### Documentation

- [Guide Technique v2.1](GUIDE-TECHNIQUE-v2.1.md)
- [Guide Operationnel v2.1](GUIDE-OPERATIONNEL-UNIFIE-v2.1.md)
- [Guide Developpeur v2.1](GUIDE-DEVELOPPEUR-v2.1.md)

---

## Version 2.2 : Publication de Configuration

### Point Important

**v2.2 n'est PAS une nouvelle version de l'API RooSync.**

C'est une **publication de configuration** basee sur l'architecture v2.1.

### Description

La version v2.2 represente la publication d'une configuration validee depuis myia-po-2023 avec des corrections Work Package 4 (WP4).

### Caracteristiques

- **Type** : Publication de configuration (pas de changement d'API)
- **Source** : myia-po-2023
- **Corrections** : WP4 (registry et permissions)
- **Baseline** : `.shared-state/configs/baseline-v2.2.0`

### Pourquoi v2.2 ?

La numerotation v2.2 a ete utilisee pour identifier la version de la configuration publiee, pas pour marquer une evolution de l'API.

### Pas de Migration Requise

Comme v2.2 utilise la meme architecture que v2.1, aucune migration n'est requise pour passer de v2.1 a v2.2.

### Documentation

- [Changelog v2.2](CHANGELOG-v2.2.md)
- Documentation v2.1 reste valide

---

## Version 2.3 : Consolidation Majeure

### Description

La version v2.3 est une **consolidation majeure** de l'API RooSync qui reduit le nombre d'outils et introduit une nouvelle architecture.

### Caracteristiques

- **Service Principal** : `NonNominativeBaselineService`
- **Approche** : Non-nominative (basee sur des profils)
- **Outils MCP** : 12 outils exportes (-29%)
- **Tests** : +220% de couverture (5 -> 16 tests)

### Breaking Changes

v2.3 introduit des **breaking changes** :

| Ancien Outil | Nouvel Outil | Changement |
|--------------|--------------|------------|
| `debug-dashboard` | `roosync_debug_reset` | Parametre `target` requis |
| `reset-service` | `roosync_debug_reset` | Parametre `target` requis |
| `read-dashboard` | `roosync_get_status` | Parametre `includeDetails` optionnel |
| `version-baseline` | `roosync_manage_baseline` | Parametre `action` requis |
| `restore-baseline` | `roosync_manage_baseline` | Parametre `action` requis |

### Migration Requise

Pour migrer de v2.1/v2.2 vers v2.3, suivez le [Plan de Migration](PLAN_MIGRATION_V2.1_V2.3.md).

### Documentation

- [Changelog v2.3](CHANGELOG-v2.3.md)
- [Guide Technique v2.3](GUIDE-TECHNIQUE-v2.3.md)
- [Plan de Migration v2.1 -> v2.3](PLAN_MIGRATION_V2.1_V2.3.md)

---

## Transition v2.1 -> v2.2

### Type de Transition

**Publication de configuration** - Aucun changement d'API.

### Impact

| Categorie | Impact |
|-----------|--------|
| Utilisateurs | Aucun |
| Developpeurs | Aucun |
| Operateurs | Minimal - nouvelle baseline disponible |

### Actions Requises

Aucune action requise. La configuration v2.2 peut etre appliquee avec les outils v2.1 existants.

### Verification

```bash
# Verifier que la baseline v2.2 est disponible
roosync_get_status

# Comparer avec la baseline v2.2
roosync_compare_config { "source": "local_machine", "target": "baseline_reference" }
```

---

## Transition v2.2 -> v2.3

### Type de Transition

**Consolidation majeure** - Breaking changes de l'API.

### Impact

| Categorie | Impact |
|-----------|--------|
| Utilisateurs | Moyen - nouveaux noms d'outils |
| Developpeurs | Eleve - migration de code requise |
| Operateurs | Moyen - mise a jour des scripts |

### Actions Requises

1. **Identifier les outils utilises** qui sont affectes par les breaking changes
2. **Mettre a jour le code** pour utiliser les nouveaux outils
3. **Tester** la migration sur un environnement de test
4. **Deployer** sur l'environnement de production

### Exemples de Migration

#### Avant (v2.2/v2.1)

```typescript
// Debug dashboard
await use_mcp_tool('roo-state-manager', 'debug_dashboard', {});

// Version baseline
await use_mcp_tool('roo-state-manager', 'roosync_version_baseline', {
  version: "2.3.0"
});
```

#### Apres (v2.3)

```typescript
// Debug dashboard -> roosync_debug_reset
await use_mcp_tool('roo-state-manager', 'roosync_debug_reset', {
  target: 'dashboard'
});

// Version baseline -> roosync_manage_baseline
await use_mcp_tool('roo-state-manager', 'roosync_manage_baseline', {
  action: 'version',
  version: "2.3.0"
});
```

### Rollback

En cas de probleme, il est possible de revenir a v2.2/v2.1 :

```bash
# Restaurer le backup
Copy-Item 'roo-config/backups/sync-config.ref.backup.v2.1-*.json' 'roo-config/sync-config.ref.json'

# Restaurer le code
git checkout HEAD~1 -- mcps/internal/servers/roo-state-manager/src/tools/roosync/
```

---

## Transition v2.1 -> v2.3 (Directe)

### Type de Transition

**Consolidation majeure** - Breaking changes de l'API.

### Recommandation

Il est possible de passer directement de v2.1 a v2.3 sans passer par v2.2, car v2.2 est une publication de configuration et non une evolution de l'API.

### Actions Requises

Identiques a la transition v2.2 -> v2.3.

### Documentation

- [Plan de Migration v2.1 -> v2.3](PLAN_MIGRATION_V2.1_V2.3.md)
- [Changelog v2.3](CHANGELOG-v2.3.md)

---

## Quelle Version Utiliser ?

### Recommandation

| Situation | Version Recommandee |
|-----------|---------------------|
| Nouvelle installation | **v2.3** |
| Installation existante stable | Rester sur votre version actuelle |
| Besoin des nouveaux outils consolides | **v2.3** |
| Scripts legacy a maintenir | **v2.1** (avec plan de migration) |

### Criteres de Decision

1. **Stabilite** : v2.1 et v2.3 sont Production Ready
2. **Performance** : v2.3 offre de meilleures performances
3. **Maintenance** : v2.3 est plus facile a maintenir (moins d'outils)
4. **Compatibilite** : v2.3 a des breaking changes

---

## FAQ

### Q: v2.2 est-elle stable ?

R: Oui, mais elle utilise l'architecture v2.1. Il n'y a pas de difference fonctionnelle entre v2.1 et v2.2.

### Q: Dois-je migrer vers v2.3 ?

R: Si vous utilisez des scripts ou du code qui appellent les outils MCP, vous devrez migrer vers v2.3 pour beneficier des ameliorations. Sinon, vous pouvez rester sur v2.1/v2.2.

### Q: Les donnees sont-elles compatibles entre versions ?

R: Oui, les donnees (baselines, messages, configurations) sont compatibles entre toutes les versions.

### Q: Puis-je revenir en arriere apres migration vers v2.3 ?

R: Oui, il est possible de faire un rollback vers v2.1/v2.2 si necessaire.

---

## Ressources

### Documentation

- [README RooSync](README.md)
- [Guide Technique v2.1](GUIDE-TECHNIQUE-v2.1.md)
- [Guide Technique v2.3](GUIDE-TECHNIQUE-v2.3.md)
- [Changelog v2.2](CHANGELOG-v2.2.md)
- [Changelog v2.3](CHANGELOG-v2.3.md)
- [Plan de Migration v2.1 -> v2.3](PLAN_MIGRATION_V2.1_V2.3.md)

### Support

Pour toute question sur les transitions de version :
1. Consulter ce guide
2. Verifier les changelogs
3. Creer une issue GitHub si necessaire

---

**Version du document** : 1.0
**Derniere mise a jour** : 2026-01-10
**Auteur** : myia-po-2023 (Claude Code)
**Checkpoint** : CP2.14 - Documentation consolidee
