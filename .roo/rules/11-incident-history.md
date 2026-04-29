# Historique des Incidents

**Version:** 2.1.0
**MAJ:** 2026-04-29

## Lecons cles

1. **Verification cross-machine** : Apres TOUTE modif config, verifier sur TOUTES les machines
2. **Stop & Repair** : Outil critique absent → ARRETER. Pas de mode degrade
3. **Config separee** : MCP config Roo ≠ Claude Code. Documenter explicitement
4. **Tests locaux d'abord** : Valider sur une machine AVANT deploiement global

## Incidents recents

| Date | Machine | Probleme | Root cause |
| ---- | ------- | -------- | ---------- |
| 2026-02-21 | web1 | win-cli absent | Pas de verif cross-machine apres modes fix |
| 2026-02-21 | ai-01 | Contexte explose (--coverage) | Output non limite |
| 2026-02-21 | po-2023 | Boucle condensation infinie | Seuil + INTERCOM sature |
| 2026-03-05 | po-2026 | roo-state-manager absent (Claude) | Config MCP separee non documentee |
| 2026-03-06 | ai-01 | 31+ outils roosync absents (Claude) | Config MCP exposee partielle |
| 2026-04-24 | po-2026 | Violation harnais orchestrateur (#1672) | Orchestrateur a execute du code au lieu de deleguer |
| 2026-04-29 | ai-01 (NanoClaw) | Chaine MCP 404 + silencieux (#1839) | sparfenyuk proxy wedge → watchdog escalation insuffisante. Fix : escalation full chain restart |
| 2026-04-29 | 3 machines | Overlap PRs #233/#237/#238 (#1786) | Pas de pre-claim → 3 agents meme tache → 12h travail duplique. Fix : regle #1798 pre-claim discipline |

**Ref complete :** `docs/harness/reference/incident-history.md`

---
**Historique versions completes :** Git history avant 2026-04-08
