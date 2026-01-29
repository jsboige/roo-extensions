# Leçons Apprises - Janvier 2026

**Période :** 2026-01-15 → 2026-01-29
**Phase :** Nettoyage "Écuries d'Augias" + Coordination Multi-Agent
**Responsable :** Claude Code (myia-ai-01) + Réseau 5 machines

---

## 📋 Vue d'ensemble

Ce document synthétise les leçons apprises durant la phase de nettoyage et stabilisation du système RooSync multi-agent, couvrant :
- Bug #322 (fix définitif)
- Architecture agents & skills Claude Code
- Coordination multi-machine via RooSync
- Dashboard MCP et inventaires v2.3.0

---

## 🎯 Leçons Techniques

### 1. Data Transformation & Format Compatibility

**Contexte :** Bug #322 - `compare_config` retournait 0 diffs au lieu de 17

**Problème :**
- `InventoryCollector` transforme `inventory.mcpServers` → `roo.mcpServers`
- `compare-config.ts` ne supportait que le format `inventory.*`
- Résultat : Fonction cherchait les données au mauvais endroit

**Leçon :**
> **Quand un service intermédiaire transforme des données, tous les consommateurs DOIVENT supporter les multiples formats.**

**Application :**
```typescript
// ❌ AVANT - Format unique
sourceData = (sourceInventory as any).inventory?.mcpServers || {};

// ✅ APRÈS - Support 3 formats
sourceData = (sourceInventory as any).inventory?.mcpServers ||
             (sourceInventory as any).roo?.mcpServers ||
             (sourceInventory as any).mcpServers ||
             {};
```

**Recommandations :**
1. Documenter TOUS les formats possibles d'un objet
2. Ajouter des tests pour chaque format
3. Utiliser des helpers de normalisation quand nécessaire

---

### 2. False Negatives in Comparison Functions

**Contexte :** `compare_config` retournait 0 diffs → semblait correct, mais était un faux négatif

**Leçon :**
> **Un résultat de "0 différences" peut être un bug silencieux si la fonction cherche au mauvais endroit.**

**Détection :**
1. Comparer avec une référence connue (inventaires réels de machines différentes)
2. Valider que la fonction trouve bien les données attendues
3. Ajouter des logs de debug pour tracer les chemins d'accès

**Application :**
- Créer un test avec des inventaires réels dont on connaît les différences
- Exécuter la fonction directement (hors MCP) pour valider
- Comparer résultat attendu vs résultat obtenu

---

### 3. Investigation Méthodique des Bugs "Impossibles"

**Contexte :** Bug fonctionnait en test direct mais pas via MCP

**Approche qui a fonctionné :**
1. **Isoler le problème** : Créer script de test autonome
2. **Valider les données** : Vérifier format et contenu en entrée
3. **Tracer l'exécution** : Ajouter logs de debug pour voir où cherche la fonction
4. **Comparer les contextes** : Test direct vs MCP vs autre contexte

**Leçon :**
> **Face à un bug "impossible", créer un environnement de test minimal pour reproduire le problème hors contexte.**

**Outil :** Scripts `.mjs` autonomes pour tester TypeScript directement

---

### 4. MCP Server Process Lifecycle

**Contexte :** Fix appliqué mais MCP continuait à utiliser l'ancienne version

**Découverte :**
- Le serveur MCP est un processus séparé
- Il ne se recharge PAS automatiquement après rebuild
- Il faut redémarrer VS Code ou le processus MCP

**Leçon :**
> **Après un rebuild du code MCP, toujours redémarrer le serveur pour que les changements prennent effet.**

**Workflow de développement :**
1. Modifier code TypeScript
2. `npm run build`
3. **Redémarrer VS Code** (ou tuer/relancer processus MCP)
4. Tester via MCP

**Alternative pour validation rapide :**
- Exécuter le code TypeScript directement (sans passer par MCP)
- Valider le fix
- Puis tester via MCP après redémarrage

---

## 🤝 Leçons Coordination Multi-Agent

### 5. INTERCOM Phase 0 Critique

**Contexte :** Skill `sync-tour` amélioré avec Phase 0 (INTERCOM local)

**Problème identifié :**
- Sans Phase 0, Claude pouvait faire un git pull pendant que Roo modifiait des fichiers
- Risque de conflits ou perte de travail

**Leçon :**
> **TOUJOURS lire INTERCOM local AVANT toute opération Git ou coordination.**

**Application :**
- Phase 0 ajoutée au `sync-tour` (8 phases au lieu de 7)
- Claude vérifie messages Roo < 24h AVANT git pull
- Détection urgences : merge en cours, modifs locales, questions

**Ordre des phases :**
```
Phase 0 : INTERCOM Local (CRITIQUE - EN PREMIER)
Phase 1 : Messages RooSync
Phase 2 : Git Sync (après avoir vérifié INTERCOM)
...
```

---

### 6. Validation Utilisateur pour Nouvelles Issues

**Contexte :** Trop d'issues créées automatiquement sans validation

**Problème :**
- Claude créait issues GitHub sans demander
- Feature creep : Propositions théoriques non demandées
- Pollution du backlog

**Leçon :**
> **TOUJOURS demander validation utilisateur AVANT de créer une nouvelle issue GitHub.**

**Application dans CLAUDE.md :**
```markdown
### ⚠️ VALIDATION UTILISATEUR OBLIGATOIRE

**AVANT de créer une nouvelle tâche GitHub (#67 ou #70) :**
1. Présenter la tâche proposée à l'utilisateur
2. Expliquer pourquoi elle est nécessaire
3. Attendre validation explicite
4. Seulement ensuite créer l'issue

**Exception :** Bugs critiques bloquants (informer immédiatement)
```

---

### 7. Communication Hiérarchisée (RooSync > INTERCOM)

**Contexte :** 2 canaux de communication (RooSync inter-machine, INTERCOM locale)

**Hiérarchie établie :**
1. **RooSync** : Coordination inter-machines (priorité haute)
2. **INTERCOM** : Coordination locale Claude ↔ Roo (priorité normale)

**Leçon :**
> **Messages RooSync du coordinateur priment sur INTERCOM locale.**

**Application :**
- Si conflit entre instruction RooSync et INTERCOM : suivre RooSync
- INTERCOM pour détails locaux et tâches non-urgentes
- RooSync pour assignations critiques et coordination globale

---

### 8. Dashboard MCP : Lisibilité Avant Tout

**Contexte :** Dashboard généré avec format markdown cassé

**Problèmes identifiés :**
1. Tableau markdown invalide (lignes mal formatées)
2. Fautes de frappe ("oosync_", "ull")
3. Manque de détails sur les "modified"

**Leçon :**
> **Un dashboard illisible est inutile, même s'il contient les bonnes données.**

**Application :**
- T120 assignée à Roo pour corriger le format
- Ajout colonnes "Avant/Après" pour les modifications
- Validation format markdown avant publication

**Principe :**
- Dashboard = outil de décision pour l'utilisateur
- Doit être présentable et compréhensible en < 30s
- Prioriser la clarté sur l'exhaustivité

---

## 📚 Leçons Méthodologiques

### 9. "Écuries d'Augias" : Nettoyage Systématique

**Contexte :** Système avec 6 mois d'héritage technique

**Approche qui a fonctionné :**
1. **Investigation approfondie** : Comprendre la cause racine (pas juste les symptômes)
2. **Fix minimal ciblé** : Corriger uniquement ce qui est cassé
3. **Tests avant commit** : Valider que le fix fonctionne
4. **Documentation immédiate** : Post-mortem + addendum

**Leçon :**
> **Nettoyage technique = Investigation + Fix Minimal + Tests + Documentation.**

**Anti-pattern à éviter :**
- Refactoring massif "tant qu'on y est"
- Fix sans comprendre la cause racine
- Commit sans tests de validation

---

### 10. Git Submodule Workflow

**Contexte :** `mcps/internal` est un submodule séparé

**Workflow établi :**
1. Modifier code dans `mcps/internal/`
2. **Commit submodule** : `cd mcps/internal && git commit`
3. **Push submodule** : `git push`
4. **Commit main** : `cd ../.. && git commit` (mise à jour référence submodule)
5. **Push main** : `git push`

**Leçon :**
> **Toujours committer et pusher le submodule AVANT de committer le dépôt principal.**

**Erreur courante :**
- Committer main sans pusher submodule
- Résultat : Autres machines ne peuvent pas fetch le submodule

---

### 11. Tests Flaky : Nettoyage Test Data

**Contexte :** Tests `MessageManager.test.ts` échouaient aléatoirement

**Cause :** Test data directory pas nettoyé entre tests

**Fix :** `rm -rf __test-data__` avant run tests

**Leçon :**
> **Tests flaky = Souvent problème de cleanup de test data, pas de logique.**

**Best practice :**
```typescript
beforeEach(async () => {
  await cleanupTestData();
});

afterEach(async () => {
  await cleanupTestData();
});
```

---

## 🔄 Leçons Processus

### 12. Tour de Sync Structuré (8 Phases)

**Contexte :** Skill `sync-tour` créé pour standardiser la coordination

**Bénéfices :**
1. **Reproductibilité** : Même séquence à chaque fois
2. **Exhaustivité** : Aucune étape oubliée
3. **Traçabilité** : Rapport structuré à la fin

**Leçon :**
> **Standardiser les opérations répétitives complexes dans des skills/scripts.**

**Application :**
- Skill `sync-tour` utilisé quotidiennement
- Chaque phase a un objectif clair
- Rapport final structuré

---

### 13. Machines Silencieuses : Escalade Progressive

**Contexte :** myia-po-2023 et myia-po-2026 sans rapport depuis 48h+

**Escalade définie :**
1. **< 48h** : Normal (attendre)
2. **> 48h** : Message priorité HIGH (relance)
3. **> 72h** : Message priorité URGENT (escalade)
4. **> 96h** : Signaler utilisateur + réassigner tâches critiques

**Leçon :**
> **Définir des seuils clairs pour l'escalade des machines silencieuses.**

**Application :**
- Phase 7 du sync-tour vérifie dernière activité
- Messages automatiques selon seuils
- Réassignation tâches critiques après 96h

---

### 14. CONS Tasks : Consolidation Progressive

**Contexte :** 7 tâches CONS pour réduire 57+ outils RooSync

**Approche validée :**
1. **Analyse** : Identifier redondances (CONS-2 par myia-po-2024)
2. **Validation** : Coordinateur approuve avant implémentation
3. **Implémentation** : Créer nouveaux outils SANS supprimer anciens
4. **Dépréciation** : Warning logs sur anciens outils
5. **Migration** : 1 sprint de transition
6. **Suppression** : Après validation complète

**Leçon :**
> **Consolidation API = Migration progressive avec période de transition, PAS refactoring brutal.**

**Anti-pattern :**
- Supprimer anciens outils immédiatement
- Refactoring sans phase de transition
- Pas de dépréciation warnings

---

## 🎯 Métriques d'Impact

### Avant la phase (15/01)
- Tests : ~1285/1286 pass (99.9%)
- Project #67 : ~50/77 Done (65%)
- Bug #322 : ⚠️ Non résolu définitivement
- Dashboard : ❌ Format invalide
- Coordination : 🟡 Ad-hoc (pas de skill)

### Après la phase (29/01)
- Tests : 1493/1506 pass (98.9%)
- Project #67 : 97/108 Done (90%)
- Bug #322 : ✅ Résolu définitivement
- Dashboard : ✅ Fonctionnel (5/5 inventaires)
- Coordination : ✅ Standardisée (skill sync-tour 8 phases)

**Amélioration :**
- +25% tasks Done (#67)
- +208 tests ajoutés
- Bug critique résolu
- Processus coordination standardisé

---

## 🔮 Recommandations Futures

### Court Terme (Février 2026)

1. **Dashboard MCP** : Finaliser T120 (format, détails)
2. **CONS Tasks** : Compléter 7 tâches consolidation
3. **Inventaire enrichi** : T123 (Windows/PowerShell/Roo/Claude infos)
4. **Machines silencieuses** : T122 (investiguer po-2023, po-2026)

### Moyen Terme (Mars 2026)

1. **Tests E2E** : Augmenter couverture scenarios réels
2. **Documentation formats** : Créer `DATA_FORMATS.md`
3. **Monitoring** : Métriques sur taux succès operations
4. **Split RooSync** : Séparer roo-state-manager du MCP

### Long Terme (Q2 2026)

1. **Harmonisation configs** : Arbitrages basés sur dashboard
2. **Déploiement unitaire** : MCPs, permissions, profils indépendants
3. **Auto-healing** : Détection et correction automatique divergences
4. **Audit trail** : Traçabilité complète des modifications

---

## ✅ Conclusion

Cette phase de nettoyage "Écuries d'Augias" a permis :
1. ✅ Résolution définitive bug critique #322
2. ✅ Standardisation coordination multi-agent (skill sync-tour)
3. ✅ Dashboard MCP fonctionnel avec 5/5 inventaires
4. ✅ Documentation consolidée et à jour
5. ✅ Processus de consolidation API établi

**Leçon principale :**
> **La coordination multi-agent nécessite des processus standardisés, une communication hiérarchisée, et une validation utilisateur systématique.**

---

**Rédigé par :** Claude Code (myia-ai-01)
**Date :** 2026-01-29T13:00:00Z
**Hash Git :** b39af4b0
**Références :**
- [BUG_322_POST_MORTEM.md](./BUG_322_POST_MORTEM.md)
- [BUG_322_POST_MORTEM_ADDENDUM.md](./BUG_322_POST_MORTEM_ADDENDUM.md)
- [GUIDE-TECHNIQUE-v2.3.md](./GUIDE-TECHNIQUE-v2.3.md)
- [SUIVI_ACTIF.md](../suivi/RooSync/SUIVI_ACTIF.md)
