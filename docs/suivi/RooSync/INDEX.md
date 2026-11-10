# Index RooSync - Documentation Consolidée

**Dernière mise à jour:** 2026-01-26
**Coordinateur:** Claude Code (myia-ai-01)

---

## Structure des Fichiers

### Fichiers ACTIFS (suivi quotidien)

| Fichier | Usage | MAJ |
|---------|-------|-----|
| **INDEX.md** | Ce fichier - Navigation | 2026-01-18 |
| **DASHBOARD.md** | Dashboard hiérarchique (GDrive) | Automatique via roosync_update_dashboard |
| **BUGS_TRACKING.md** | Bugs connus et leur statut | Quand bugs |

### Documentation Technique

| Fichier | Usage |
|---------|-------|
| [`../roosync/GUIDE-TECHNIQUE-v2.3.md`](../../roosync/GUIDE-TECHNIQUE-v2.3.md) | Guide technique complet |
| [`PROTOCOLE_SDDD.md (archivé)`](../../archive/doc-audit-2026-11-09/PROTOCOLE_SDDD.md) | Protocole SDDD v2.7 — superseded par `.claude/rules/sddd-grounding.md` |
| [`../roosync/QUICKSTART.md`](../../roosync/QUICKSTART.md) | Guide rapide (30 lignes) |
| [`../roosync/ERROR_CODES_REFERENCE.md (archivé)`](../../archive/doc-audit-2026-11-09/ERROR_CODES_REFERENCE.md) | Codes erreur T2.8 (janvier, #2877 vague 5) |
| [`../../../CLAUDE.md`](../../../CLAUDE.md) | Guide Claude Code + IDs GitHub |

### Guides Opérationnels

| Fichier | Usage |
|---------|-------|
| [`../roosync/guides/ONBOARDING_AGENT.md`](../../roosync/guides/ONBOARDING_AGENT.md) | Guide nouvel agent |
| [`../roosync/guides/TROUBLESHOOTING.md`](../../roosync/guides/TROUBLESHOOTING.md) | FAQ et problèmes |
| [`../roosync/guides/CHECKLISTS.md (archivé)`](../../archive/doc-audit-2026-11-09/guides/CHECKLISTS.md) | Listes vérification (janvier, #2877 vague 5) |
| [`../roosync/guides/GLOSSAIRE.md`](../../roosync/guides/GLOSSAIRE.md) | Termes RooSync |

---

## État Système

| Métrique | Valeur |
|----------|--------|
| Version RooSync | v2.3.0 |
| Project #67 | ~91/100 (~91%) Done |
| Project #70 | ~14/20 (~70%) Done |
| CI mcps/internal | ✅ 7/7 jobs PASS |
| Machines actives | 5/5 |

---

## Recherche Rapide

- **Bugs** → `BUGS_TRACKING.md`
- **Dashboard** → `$ROOSYNC_SHARED_PATH/DASHBOARD.md` (nouveau format hiérarchique)
- **Guide rapide** → [`QUICKSTART.md`](../../roosync/QUICKSTART.md)
- **Archives** → `Archives/` (80+ rapports)
- **Technique** → [`GUIDE-TECHNIQUE-v2.3.md`](../../roosync/GUIDE-TECHNIQUE-v2.3.md)
- **Consolidation Post-Harmonisation** → `Archives/CONSOLIDATION_POST_HARMONISATION_2026-01-20.md`

---

## Prochaines Étapes

1. **T106** - Consolider documentation GPU (Roo, myia-ai-01)
2. **#369** - CI mcps/internal fixé ✅
3. **P1** - Migration gh CLI validée (myia-po-2026)

---

**Règle:** Git log est la source de vérité. Ce fichier est un index de navigation minimal.
