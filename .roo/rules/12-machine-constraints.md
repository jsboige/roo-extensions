# Contraintes Spécifiques par Machine

**Version :** 1.0.0
**Créé :** 2026-03-15
**Issue :** #710

---

## Vue d'Ensemble

Chaque machine du système RooSync a des contraintes spécifiques (RAM, OS, rôle). Ce document les référence pour éviter les erreurs d'assignation.

---

## Machines Exécutantes

### myia-po-2023 / myia-po-2024 / myia-po-2025 / myia-po-2026

**RAM :** 16GB
**OS :** Windows 10/11
**Rôle :** Agent exécutant flexible

**Capacités :**
- Investigation + implémentation code
- Features substantielles
- Tests unitaires complets
- Build TypeScript

### myia-web1

**RAM :** 16GB (vérifié 2026-03-05)
**OS :** Windows Server 2019
**Rôle :** Agent exécutant (pas coordinateur)

**Contraintes CRITIQUES :**

1. **Configuration RooSync SINGULIÈRE**
   - Compte Google différent (jsboige@gmail.com)
   - Path : `C:\Drive\.shortcut-targets-by-id\1jEQqHabwXrIukTEI1vE05gWsJNYNNFVB\.shared-state`
   - **NE PAS utiliser :** `G:/Mon Drive/...` (n'existe pas sur cette machine)

2. **Tests TOUJOURS avec --maxWorkers=1**
   ```bash
   npx vitest run --maxWorkers=1
   ```

3. **Seuil de condensation : 80% minimum** (pas 50%)

**Documentation complète :** [`.claude/rules/myia-web1-constraints.md`](../../.claude/rules/myia-web1-constraints.md)

---

## Coordinateur

### myia-ai-01

**RAM :** 32GB+
**OS :** Windows 11
**Rôle :** Coordinateur principal

**Responsabilités :**
- Dispatch des tâches
- Coordination RooSync
- GitHub Project #67 management
- Environment health monitoring

---

## Références Cross-Machines

| Machine | GPU | RAM | Provider |
|---------|-----|-----|----------|
| myia-ai-01 | 3x RTX 4090 | 32GB | Anthropic |
| myia-po-2023 | A5000 | 16GB | z.ai |
| myia-po-2024 | A4000 | 16GB | z.ai |
| myia-po-2025 | RTX 3060 | 16GB | z.ai |
| myia-po-2026 | RTX 3060 | 16GB | z.ai |
| myia-web1 | None | 16GB | z.ai |

**Note :** La charge LLM est sur le provider (z.ai ou Anthropic), PAS local.

---

**Dernière mise à jour :** 2026-03-15
