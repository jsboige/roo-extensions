# Condensation Context Window - Claude Code

**Version:** 1.0.0
**Created:** 2026-03-24
**Issue:** #841 (Friction - seuil 80% non documenté)

---

## Règle Critique : Seuil de Condensation 80%

**Pour les modèles GLM (z.ai provider), le seuil de condensation OBLIGATOIRE est 80%.**

### Pourquoi ?

Les modèles GLM annoncent 200k tokens mais la réalité est **~131k tokens** (les 200k incluent les tokens de sortie).

| Seuil | Problème |
|-------|----------|
| **50%** (défaut) | Boucle infinie de condensation (#502) |
| **70%** | Boucle avec harnais lourd (#736, po-2023) |
| **80%** ✅ | Compaction à ~105k réels, marge 26k |
| **90%** | Trop haut, risque saturation |

---

## Configuration

### Claude Code (settings.json)

**Chemin :** `~/.claude/settings.json`

**Pour z.ai (GLM) :**
```json
{
  "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"
}
```

**⚠️ NE JAMAIS utiliser 50%** → Boucle infinie !
**⚠️ 70% insuffisant** avec harnais lourd → Boucle

---

## Modèles GLM - Contexte Réel

| Modèle | Contexte Réel | Seuil 80% |
|--------|---------------|-----------|
| GLM-5 (z.ai) | 131k tokens | ~105k |
| GLM-4.7 (z.ai) | 131k tokens | ~105k |
| GLM-4.7 Flash | 131k tokens | ~105k |
| GLM-4.5 Air (z.ai) | 131k tokens | ~105k |

---

## Documentation Complète

Pour plus de détails (historique des issues, configuration Roo, tests) :
- **Voir :** `.claude/docs/condensation-thresholds.md`

---

**Dernière mise à jour :** 2026-03-24
**Mainteneur :** Coordinateur RooSync (myia-ai-01)
