# Protocole de Scepticisme Raisonnable - Anti-Propagation d'Erreurs

**Version:** 1.0.0
**Cree:** 2026-03-04
**Contexte:** Incidents de propagation d'erreurs entre agents (GPU panic po-2026, Session 101 archives, duplicate work)

---

## Principe

**Ne JAMAIS propager une affirmation non verifiee.** Si un agent (Roo, Claude, autre machine) fait une affirmation surprenante, la verifier AVANT de la repeter, d'agir dessus, ou de la transmettre a d'autres.

Le cout d'une verification est de quelques secondes. Le cout d'une erreur propagee est de plusieurs heures sur 6 machines.

---

## Declencheurs de Scepticisme (Smell Test)

**PAUSE et VERIFIE si une affirmation entrante contient :**

| Categorie | Exemples | Verification |
|-----------|----------|-------------|
| **Infrastructure** | "GPU insuffisante", "modele X necessite Y GB", "service Z est down" | Croiser avec tables CLAUDE.md/MEMORY.md (GPU Fleet, Services) |
| **Capacite** | "impossible sur cette machine", "pas assez de RAM/VRAM" | Verifier si la tache est locale ou via API distante |
| **Etat du code** | "tests passent tous", "feature X implementee", "bug Y fixe" | `git log`, `npx vitest run`, lire le code source |
| **Blocage** | "bloque depuis X heures", "impossible de faire Y" | Verifier traces (conversation_browser), tenter soi-meme |
| **Urgence** | "il faut tout arreter", "probleme critique" | Evaluer la severite reelle avant de propager |
| **Configuration** | "MCP X ne marche pas", "config Y incorrecte" | Tester l'outil directement, lire la config |

**Regle du pouce :** Si l'affirmation contredit ce que tu sais, ou si elle te surprend, c'est un declencheur.

---

## Protocole de Verification (3 niveaux)

### Niveau 1 : Verification rapide (10 secondes)
**Quand :** Affirmation sur un fait verifiable en lecture seule.
- Consulter CLAUDE.md, MEMORY.md, ou les tables d'infrastructure
- Exemple : "Qwen 3.5 tourne sur po-2026" → GPU Fleet table → Qwen 3.5 tourne sur ai-01 via vLLM

### Niveau 2 : Verification active (1-2 minutes)
**Quand :** Affirmation sur un etat qui change (tests, git, services).
- `git log --oneline -5` pour verifier les commits revendiques
- `npx vitest run` pour verifier "tests passent"
- Appel MCP pour verifier "outil X ne marche pas"

### Niveau 3 : Verification croisee (5 minutes)
**Quand :** Affirmation structurelle ou architecturale.
- Lire le code source (Read, Grep)
- Croiser avec traces Roo (conversation_browser)
- Comparer avec historique GitHub

---

## Regles Anti-Propagation

### Pour le Coordinateur (myia-ai-01)

1. **JAMAIS repeter une affirmation d'executeur dans un dispatch** sans l'avoir verifiee
2. **JAMAIS proposer un workaround** base sur un probleme non confirme
3. Quand un executeur rapporte un blocage surprenant :
   - Verifier soi-meme OU repondre : "Verifie : [fait connu] ne contredit-il pas ton affirmation ?"
4. **Inclure la source** dans les dispatches : "Confirme par git log abc123" ou "Selon po-2026 (NON VERIFIE)"

### Pour les Executeurs

1. **JAMAIS dire "impossible"** sans avoir tente et documente l'echec concret (output exact)
2. **Inclure les preuves** dans les rapports : commit hash, output de commande, extrait de fichier
3. Quand une directive recue est basee sur une premisse surprenante :
   - Verifier la premisse localement avant d'executer
   - Si la premisse est fausse : rapporter IMMEDIATEMENT au coordinateur

### Pour TOUS les agents

1. **Qualifier les affirmations** :
   - **VERIFIE** : J'ai teste/lu/confirme moi-meme
   - **RAPPORTE PAR [source]** : Un autre agent/doc le dit (pas confirme)
   - **SUPPOSE** : Hypothese non verifiee
2. **Ne pas confondre correlation et causalite** : "test echoue ET GPU a 100%" ≠ "test echoue A CAUSE du GPU"
3. **Preferer "je ne sais pas"** a une hypothese non verifiee presentee comme un fait

---

## Faits de Reference (Infrastructure Connue)

Pour les verifications de Niveau 1, consulter :

| Source | Contenu | Fichier |
|--------|---------|---------|
| GPU Fleet | GPU par machine (ai-01: 3x4090, etc.) | CLAUDE.md section "GPU Fleet" |
| Services | Ports, domaines, endpoints | CLAUDE.md section "Services" |
| Modeles | Endpoints vLLM, modeles disponibles | MEMORY.md, `hosted-models.md` |
| MCP Config | Outils attendus par machine | `.claude/rules/tool-availability.md` |
| Contraintes machine | RAM, OS, limitations | `.claude/rules/machine-specific/myia-web1-constraints.md` |

**Fait critique :**
- Les modeles LLM (Qwen 3.5, GLM-5, ZwZ-8B) tournent sur **ai-01 via API** (vLLM ou z.ai), pas localement sur les executeurs
- La charge compute LLM est sur le provider, PAS sur la machine qui fait la requete
- Les MCPs tournent localement, mais les modeles sont distants

---

## Anti-Patterns Documentes

| Anti-Pattern | Incident | Impact | Correction |
|-------------|----------|--------|------------|
| Accepter "GPU insuffisante" sans verifier | po-2026 #536 Qwen 3.5 | Fausse panique sur 6 machines | Verifier GPU Fleet + architecture API |
| Archiver sans verifier le contenu | Session 101, 8 scripts perdus | Pipeline casse | Checklist consolidation obligatoire |
| Proposer workaround sur fausse premisse | "tester sur po-2023 RTX 3090" | Temps perdu, directives fausses | Verifier la premisse d'abord |
| Declarer machine "silencieuse" sans verifier | web1 3 fois faux | Taches non assignees | Verifier inbox complet (read+unread, 48h) |
| Dupliquer le travail sans verifier claim | #553 po-2026+po-2024 memes fichiers | Double travail, conflits | Claim protocol obligatoire |

---

## Integration

Ce protocole s'applique a :
- `/coordinate` : Verifier les rapports AVANT de dispatcher
- `/executor` : Verifier les premisses des instructions recues
- `roosync-hub` : Croiser rapports avec git/GitHub
- `dispatch-manager` : Verifier capacites avant assignation

---

**Derniere mise a jour :** 2026-03-04
