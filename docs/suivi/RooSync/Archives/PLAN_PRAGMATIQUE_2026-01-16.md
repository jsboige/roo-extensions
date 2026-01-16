# Plan Pragmatique RooSync - 2026-01-16

**Objectif:** Faire fonctionner RooSync pour la gestion de configs multi-machine.
**Principe:** Arrêter l'architecture pour l'architecture. Tester et valider.

---

## 1. Ce qui EXISTE et fonctionne

| Outil | Fonction | Statut |
|------|----------|--------|
| `get-machine-inventory` | Collecter config machine | ✅ |
| `collect-config` | Collecter config pour partage | ✅ |
| `compare-config` | Comparer deux configs | ✅ |
| `apply-config` | Appliquer une config | ✅ |
| `get-status` | Statut du système | ⚠️ 1 test échoue |
| `publish-config` | Publier sa config | ✅ |
| `read_inbox` / `send_message` | Messagerie | ✅ |

**Conclusion:** Le cœur fonctionnel EXISTE.

---

## 2. Ce qui MANQUE pour que ça marche vraiment

| Manque | Impact | Effort |
|--------|--------|--------|
| **Test E2E du flux complet** | On ne sait pas si ça marche bout-en-bout | 2h |
| **Documentation usage simple** | Personne ne sait comment s'en servir | 1h |
| **Validation multi-machine réelle** | Jamais testé sur 2 machines réelles | 2h |

**Total:** ~5h pour avoir un système UTILISABLE.

---

## 3. Arrêter de faire (liste noire)

- ❌ Plus de nouveaux outils (heartbeat, etc.)
- ❌ Plus de refactors d'architecture
- ❌ Plus de glossaires, guides, docs théoriques
- ❌ Plus de tâches d'analyse (T3.x, T4.x)

---

## 4. Actions immédiates (Aujourd'hui)

### 4.1 Test E2E du flux complet (P0)

```powershell
# Sur myia-ai-01
# 1. Collecter inventaire
get-machine-inventory

# 2. Collecter config
collect-config

# 3. Comparer avec une autre machine
compare-config --other myia-po-2024

# 4. Appliquer une config si nécessaire
apply-config --source myia-po-2024
```

**Critère de succès:** Le flux complet fonctionne sans erreur.

### 4.2 Corriger le test get-status (P0)

Le test échoue sur `onlineMachines`. Corriger le mock.

### 4.3 Documentation usage simple (P1)

Un README de 30 lignes max, exemple concret:

```markdown
# RooSync - Gestion de configs multi-machine

## Usage basique

# Voir les différences entre machines
compare-config

# Appliquer la config de référence
apply-config

# Voir le statut
get-status
```

---

## 5. Priorité absolue

**Aucun nouveau code** jusqu'à ce que:
1. Le test E2E passe
2. Le flux complet est validé sur 2 machines réelles
3. Un README simple existe

---

**Date:** 2026-01-16
**Statut:** Plan pragmatique - À exécuter
