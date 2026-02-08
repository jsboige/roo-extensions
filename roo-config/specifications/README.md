# Specifications Architecturales - Modes Roo

**Version :** 3.0.0
**Date :** Fevrier 2026
**Statut :** Specifications de reference consolidees

---

## Vue d'Ensemble

Ce repertoire contient les specifications architecturales pour les modes Roo, organisees en 3 themes. Ces specifications definissent les regles de fonctionnement des modes (escalade, economie de contexte, securite), le mapping avec les LLMs, et les integrations MCP.

---

## Theme A : Modes, Escalade & Factorisation

Specifications liees a l'architecture des modes, aux mecanismes de transition, et a la factorisation des instructions communes.

| Document | Lignes | Description | Priorite |
|----------|--------|-------------|----------|
| [llm-modes-mapping.md](llm-modes-mapping.md) | ~1319 | Mapping LLMs/modes : taxonomie 4 tiers (Flash/Mini/Standard/SOTA), criteres escalade quantitatifs, budget tokens, monitoring | CRITIQUE |
| [escalade-mechanisms-revised.md](escalade-mechanisms-revised.md) | ~669 | Mecaniques d'escalade v3.0 : definition stricte (Simple->Complex), 3 formes (interne/branchement/terminaison), anti-patterns | CRITIQUE |
| [factorisation-commons.md](factorisation-commons.md) | ~769 | Factorisation massive : architecture 3 niveaux (Global/Family/Mode), -71% redondance, systeme templates | HAUTE |
| [hierarchie-numerotee-subtasks.md](hierarchie-numerotee-subtasks.md) | ~607 | Hierarchie numerotee : tracabilite sous-taches, universalite new_task(), patterns orchestration | HAUTE |

**Relations :** Les criteres d'escalade (`escalade-mechanisms`) declenchent des transitions vers des LLMs plus puissants definis dans `llm-modes-mapping`. La factorisation definit la structure des instructions, la hierarchie numerotee organise les sous-taches.

---

## Theme B : SDDD, Economie de Contexte & Operations

Specifications liees au protocole SDDD, a l'optimisation du contexte, et aux bonnes pratiques operationnelles.

| Document | Lignes | Description | Priorite |
|----------|--------|-------------|----------|
| [sddd-protocol-4-niveaux.md](sddd-protocol-4-niveaux.md) | ~1119 | Protocole SDDD : grounding 4 niveaux (Fichier/Semantique/Conversationnel/GitHub), checkpoints 50k tokens, metriques conformite | CRITIQUE |
| [context-economy-patterns.md](context-economy-patterns.md) | ~819 | Patterns economie de contexte : 5 patterns (delegation, decomposition, MCP batch, checkpoints, lecture ciblee), seuils 30k/50k/100k | HAUTE |
| [operational-best-practices.md](operational-best-practices.md) | ~1014 | Best practices : priorite scripts vs commandes, nomenclature stricte, horodatage, tracabilite | MOYENNE |

**Relations :** Le SDDD definit le cadre methodologique. L'economie de contexte optimise l'utilisation des tokens. Les best practices fournissent les regles operationnelles quotidiennes.

---

## Theme C : Integration MCP & Securite

Specifications liees aux integrations MCP et a la securite multi-agent.

| Document | Lignes | Description | Priorite |
|----------|--------|-------------|----------|
| [mcp-integrations-priority.md](mcp-integrations-priority.md) | ~725 | Priorites MCP : Tier 1 (roo-state-manager, quickfiles), Tier 2 (win-cli, markitdown), patterns utilisation | HAUTE |
| [git-safety-source-control.md](git-safety-source-control.md) | ~800 | Securite git : commits atomiques, protection branches, resolution conflits, hooks | CRITIQUE |
| [multi-agent-system-safety.md](multi-agent-system-safety.md) | ~1400 | Securite multi-agent : isolation, permissions, coordination inter-machines, garde-fous | CRITIQUE |

---

## Autres fichiers

| Document | Description |
|----------|-------------|
| [level-criteria.json](level-criteria.json) | Criteres de selection simple/complex pour SDDD (decision tree, metriques GLM, seuils d'escalade) |

---

## Flux de lecture recommande

**Pour comprendre l'architecture :**
1. Ce README (vue d'ensemble)
2. `sddd-protocol-4-niveaux.md` (fondation methodologique)
3. `factorisation-commons.md` (architecture templates)

**Pour implementer un mode :**
1. `factorisation-commons.md` (templates)
2. `escalade-mechanisms-revised.md` (mecaniques par famille)
3. `mcp-integrations-priority.md` (outils disponibles)

**Pour choisir les modeles LLM :**
1. `llm-modes-mapping.md` (taxonomie et mapping)
2. `level-criteria.json` (criteres decision simple/complex)

---

## Historique

- **v3.0.0** (Fevrier 2026) : Reorganisation en 3 themes, ajout level-criteria.json, nettoyage rapports obsoletes
- **v2.0.0** (Octobre 2025) : 8 specifications consolidees post-Mission 2.1, ajout git-safety et multi-agent-safety
- **v1.0.0** (Septembre 2025) : Specifications initiales
