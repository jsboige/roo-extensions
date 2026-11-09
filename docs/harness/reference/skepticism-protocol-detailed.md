# Protocole de Scepticisme Raisonnable — Reference Detaillee

**Source :** `.claude/rules/skepticism-protocol.md` (version slim — **seule autorite**)
**Origine :** `docs/roosync/SKEPTICISM_PROTOCOL.md` v1.0.0 (2026-03-04), consolide le 2026-11-09 (issue #2877, arbitrage `c.6728993741`)
**Contexte :** incidents de propagation d'erreurs entre agents (panique GPU po-2026, Session 101 archives, travail duplique)

> Ce document **elabore** la regle, il ne la remplace pas. En cas d'ecart, la regle fait foi.

---

## Declencheurs de Scepticisme (Smell Test)

**PAUSE et VERIFIE si une affirmation entrante contient :**

| Categorie | Exemples | Verification |
|-----------|----------|-------------|
| **Infrastructure** | "GPU insuffisante", "modele X necessite Y GB", "service Z est down" | Croiser avec les tables CLAUDE.md / MEMORY.md de la machine |
| **Capacite** | "impossible sur cette machine", "pas assez de RAM/VRAM" | Verifier si la tache est locale ou via API distante |
| **Etat du code** | "tests passent tous", "feature X implementee", "bug Y fixe" | `git log`, `npx vitest run`, lire le code source |
| **Blocage** | "bloque depuis X heures", "impossible de faire Y" | Verifier les traces (`conversation_browser`), tenter soi-meme |
| **Urgence** | "il faut tout arreter", "probleme critique" | Evaluer la severite reelle avant de propager |
| **Configuration** | "MCP X ne marche pas", "config Y incorrecte" | Tester l'outil directement, lire la config |

**Regle du pouce :** si l'affirmation contredit ce que tu sais, ou si elle te surprend, c'est un declencheur.

---

## Protocole de Verification (3 niveaux)

### Niveau 1 : Verification rapide (10 secondes)

**Quand :** affirmation sur un fait verifiable en lecture seule.

- Consulter CLAUDE.md, MEMORY.md, ou les tables d'infrastructure de la machine
- Exemple : "Qwen tourne sur po-2026" → la table des modeles heberges dit ai-01 via vLLM

### Niveau 2 : Verification active (1-2 minutes)

**Quand :** affirmation sur un etat qui change (tests, git, services).

- `git log --oneline -5` pour verifier les commits revendiques
- `npx vitest run` pour verifier "tests passent"
- Appel MCP pour verifier "outil X ne marche pas"

### Niveau 3 : Verification croisee (5 minutes)

**Quand :** affirmation structurelle ou architecturale.

- Lire le code source (`Read`, `Grep`)
- Croiser avec les traces Roo (`conversation_browser`)
- Comparer avec l'historique GitHub

---

## Regles Anti-Propagation

### Pour le Coordinateur (myia-ai-01)

1. **JAMAIS repeter une affirmation d'executeur dans un dispatch** sans l'avoir verifiee
2. **JAMAIS proposer un workaround** base sur un probleme non confirme
3. Quand un executeur rapporte un blocage surprenant : verifier soi-meme, OU repondre "Verifie : [fait connu] ne contredit-il pas ton affirmation ?"
4. **Inclure la source** dans les dispatches : "Confirme par `git log abc123`" ou "Selon po-2026 (NON VERIFIE)"

### Pour les Executeurs

1. **JAMAIS dire "impossible"** sans avoir tente et documente l'echec concret (output exact)
2. **Inclure les preuves** dans les rapports : commit hash, output de commande, extrait de fichier
3. Quand une directive recue est basee sur une premisse surprenante : verifier la premisse localement avant d'executer ; si elle est fausse, rapporter IMMEDIATEMENT au coordinateur

### Pour TOUS les agents

1. **Qualifier les affirmations** — VERIFIE / RAPPORTE PAR [source] / SUPPOSE
2. **Ne pas confondre correlation et causalite** : "test echoue ET GPU a 100%" ≠ "test echoue A CAUSE du GPU"
3. **Preferer "je ne sais pas"** a une hypothese non verifiee presentee comme un fait

---

## Sources de Verification (pointeurs vivants)

| Source | Contenu | Fichier |
|--------|---------|---------|
| Outils attendus par machine | inventaire MCP + STOP & REPAIR | `.claude/rules/tool-availability.md` |
| Contraintes machine | RAM, OS, limitations par siège | `docs/harness/machine-specific/myia-web1-constraints.md` |
| Modeles heberges / endpoints | vLLM, z.ai, modeles disponibles par LAN | `docs/harness/reference/INDEX.md` (lignes « modeles » / `hosted-models`) |

> Les anciens pointeurs `CLAUDE.md` section « GPU Fleet » et `.claude/rules/myia-web1-constraints.md` ont ete **retires** faute de cible vivante (la section n'existe plus dans `CLAUDE.md`, et le fichier de contraintes vit sous `docs/harness/machine-specific/`). La liste de modeles (GLM-5.2 / Qwen3.6-35B) de la version 2026-03-04 est perimee et n'est pas recopiee.

---

## Anti-Patterns Documentes

| Anti-Pattern | Incident | Impact | Correction |
|-------------|----------|--------|------------|
| Accepter "GPU insuffisante" sans verifier | po-2026 #536 Qwen | Fausse panique sur plusieurs machines | Verifier la table des modeles heberges + l'architecture API |
| Archiver sans verifier le contenu | Session 101, 8 scripts perdus | Pipeline casse | Checklist de consolidation obligatoire |
| Proposer un workaround sur une fausse premisse | "tester sur po-2023 RTX 3090" | Temps perdu, directives fausses | Verifier la premisse d'abord |
| Declarer une machine "silencieuse" sans verifier | web1, 3 fois faux | Taches non assignees | Verifier l'inbox complete (read + unread, 48 h) |
| Dupliquer le travail sans verifier le claim | #553, po-2026 + po-2024 sur les memes fichiers | Double travail, conflits | Claim obligatoire (ADR 017) |

---

**Derniere mise a jour :** 2026-11-09 (consolidation #2877 — contenu de `docs/roosync/SKEPTICISM_PROTOCOL.md` v1.0.0, archive sous `docs/archive/doc-audit-2026-11-09/`)
