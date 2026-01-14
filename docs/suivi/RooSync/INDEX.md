# Index RooSync - Documentation Consolidée

**Dernière mise à jour:** 2026-01-14
**Coordinateur:** Claude Code (myia-ai-01)

---

## 📚 Structure (4 fichiers actifs seulement)

### Fichiers ACTIFS

| Fichier | Usage | MAJ |
|---------|-------|-----|
| **INDEX.md** | Ce fichier - Navigation | 2026-01-14 |
| **SUIVI_ACTIF.md** | Suivi quotidien de l'activité | Quotidien |
| **BUGS_TRACKING.md** | Bugs connus et leur statut | Quand bugs |
| **AUDIT_HONNETE.md** | État honnête du projet | 2026-01-14 |

### Documentation Technique (référence)

| Fichier | Usage |
|---------|-------|
| [`../roosync/GUIDE-TECHNIQUE-v2.3.md`](../roosync/GUIDE-TECHNIQUE-v2.3.md) | Guide technique complet |
| [`../roosync/PROTOCOLE_SDDD.md`](../roosync/PROTOCOLE_SDDD.md) | Protocole SDDD v2.5.0 |
| [`../../../CLAUDE.md`](../../../CLAUDE.md) | Guide Claude Code + IDs GitHub |

---

## 🗂️ Archives

Tous les rapports antérieurs à 2026-01-14 sont dans `Archives/`:
- Rapports de gouvernance
- Rapports de tâches individuelles
- Analyses d'architecture
- Rapports de synthèse

---

## 📊 État Système

| Métrique | Valeur |
|----------|--------|
| Version RooSync | v2.3.0 |
| Tâches complétées | 28/77 (36.4%) |
| Bugs critiques | 0 ouverts |
| Machines actives | 5/5 |
| Tests RooSync | 1045/1076 PASS (97.1%) |

---

## 🔍 Recherche

- **Bugs** → `BUGS_TRACKING.md`
- **Quotidien** → `SUIVI_ACTIF.md`
- **Audit** → `AUDIT_HONNETE.md`
- **Archives** → `Archives/`
- **Technique** → [`../roosync/GUIDE-TECHNIQUE-v2.3.md`](../roosync/GUIDE-TECHNIQUE-v2.3.md)

---

## 🚦 Prochaines Étapes

1. **Smoke Test Inter-Machines** (BLOCKER - En attente inventaires)
   - Toutes les machines doivent lancer `roosync_get_machine_inventory`
   - Puis tester `roosync_compare_config` entre 2 machines

2. **Validation E2E Réelle**
   - Tests mockés : 8/10 PASS ✅
   - Tests réels inter-machines : À faire ❌

---

**Règle:** Git log est la source de vérité. Ce fichier contient un index minimal. L'historique complet est dans git log.
