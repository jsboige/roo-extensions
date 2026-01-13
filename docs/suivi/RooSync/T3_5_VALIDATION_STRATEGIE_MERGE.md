# T3.5 - Validation de la Stratégie de Merge

**Date:** 2026-01-14
**Responsable:** Claude Code (myia-po-2023)
**Statut:** ✅ VALIDÉ

---

## Objectif

Valider et documenter la stratégie de merge utilisée pour les configurations RooSync.

## Analyse du Code

**Fichier:** `mcps/internal/servers/roo-state-manager/src/utils/JsonMerger.ts`

### Stratégies de Merge pour les Tableaux

| Stratégie | Description | Comportement |
|-----------|-------------|--------------|
| `replace` | **Par défaut** | Le tableau source remplace le tableau cible |
| `concat` | Concaténation | Les éléments source sont ajoutés à la fin |
| `union` | Sans doublons | Concat sans éléments dupliqués (via JSON.stringify) |

### Comportement de Merge par Type

| Type | Comportement |
|------|--------------|
| `null/undefined` | L'autre valeur gagne |
| Types différents | La source gagne |
| Tableaux | Selon `arrayStrategy` (défaut: `replace`) |
| Objets | Fusion récursive propriété par propriété |
| Primitifs | La source remplace la cible |

## Validation de la Stratégie `replace`

### Pourquoi `replace` est le défaut ?

1. **Sécurité** - Évite l'accumulation de configurations obsolètes
2. **Prévisibilité** - Le résultat est toujours ce qui est attendu
3. **Compatibilité** - Aligné avec le comportement du script legacy `deploy-settings.ps1`

### Cas d'Usage

```typescript
// Exemple: Fusion de configurations MCP
const source = {
  mcpServers: {
    "roo-state-manager": { enabled: true }
  },
  modes: ["code", "architect"]
};

const target = {
  mcpServers: {
    "old-server": { enabled: false }
  },
  modes: ["code"]
};

// Résultat avec strategy: 'replace' (défaut)
const result = JsonMerger.merge(source, target);
// {
//   mcpServers: {
//     "old-server": { enabled: false },
//     "roo-state-manager": { enabled: true }
//   },
//   modes: ["code", "architect"]  // REPLACED, not merged
// }
```

## Recommandations

### Quand utiliser `replace` (défaut)

- Configuration de modes Roo (liste de modes actifs)
- Configuration de serveurs MCP (liste complète)
- Tout tableau où l'ordre et le contenu exact importent

### Quand utiliser `concat`

- Historique d'événements
- Logs accumulés
- Listes qui doivent grandir

### Quand utiliser `union`

- Tags ou labels
- Permissions uniques
- Collections sans doublons

## Tests Existants

Les tests du JsonMerger couvrent:
- ✅ Merge d'objets simples
- ✅ Merge récursif
- ✅ Stratégie `replace` pour tableaux
- ✅ Stratégie `concat` pour tableaux
- ✅ Stratégie `union` pour tableaux
- ✅ Gestion des null/undefined

## Conclusion

La stratégie de merge `replace` pour les tableaux est **validée** comme comportement par défaut car:

1. Elle est **plus sûre** - évite les effets de bord inattendus
2. Elle est **prévisible** - le résultat correspond aux attentes
3. Elle est **compatible** - alignée avec les pratiques existantes

---

**Critère de validation:** ✅ Stratégie documentée et validée
**Checkpoint:** CP3.5 - Stratégie de merge validée
