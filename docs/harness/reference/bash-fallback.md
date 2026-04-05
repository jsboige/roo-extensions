# Règle Bash-Fallback - Mitigation Issue #488

**Version:** 1.0.0
**Créé:** 2026-02-18
**Issue:** #488 - Claude Code Bash tool silently fails

---

## Problème

L'outil `Bash` peut échouer silencieusement avec "Exit code 1" sans message d'erreur exploitable. Ce problème a été introduit par une mise à jour récente de Claude Code.

**Référence:** https://github.com/search?q=repo%3Aanthropics%2Fclaude-code%20bash&type=issues

---

## Mitigation

### Priorité 1: Éviter Bash

**Toujours privilégier les outils natifs Claude Code:**

| Action | ❌ Bash | ✅ Outil Natif |
|--------|---------|----------------|
| Lire fichier | `cat file.txt` | `Read` |
| Lister fichiers | `ls` / `find` | `Glob` |
| Chercher contenu | `grep` | `Grep` |
| Modifier fichier | `sed` / `echo >>` | `Edit` / `Write` |
| Créer fichier | `echo > file` | `Write` |

### Priorité 2: MCP win-cli (si disponible)

Si Bash est indispensable et échoue:

```
Bash (essayé) → Exit code 1 → MCP win-cli (fallback)
```

**Outils MCP win-cli:**
- `execute_command` - Exécuter commande shell
- `read_file` / `write_file` - Opérations fichiers
- `list_directory` - Lister répertoire

### Priorité 3: Dégradation Gracieuse

Si shell complètement indisponible:

1. **Documenter** les actions bloquées dans INTERCOM
2. **Continuer** avec tâches alternatives:
   - Lecture et analyse de code
   - Documentation
   - Investigation via Read/Grep/Glob
   - Recherche sémantique via MCP
3. **Signaler** au coordinateur via RooSync
4. **Demander** à l'utilisateur d'exécuter les commandes manuellement

---

## Workflow Dégradé

```
┌─────────────────────────────────────────────────────────┐
│  PHASE 1: Détection Bash cassé                          │
│  - Tenter 1 commande simple (ex: pwd)                   │
│  - Si Exit code 1 sans output → Bash cassé confirmé     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  PHASE 2: Mode Dégradé                                  │
│  - Annoncer dans INTERCOM                               │
│  - Continuer tâches sans bash                           │
│  - Lister actions bloquées                              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  PHASE 3: Rapport                                       │
│  - Envoyer message RooSync au coordinateur              │
│  - Documenter dans issue #488 si nouveau cas            │
└─────────────────────────────────────────────────────────┘
```

---

## Tâches Réalisables Sans Bash

Quand bash est cassé, se concentrer sur:

| Type | Outils | Exemples |
|------|--------|----------|
| **Lecture code** | Read, Grep, Glob | Investigation bugs |
| **Analyse** | codebase_search, roosync_search | Recherche sémantique |
| **Documentation** | Read, Write, Edit | MAJ CLAUDE.md, guides |
| **Communication** | roosync_send, roosync_read | Coordination |
| **Navigation** | conversation_browser, task_export | Historique |

---

## Tâches Bloquées Sans Bash

| Type | Alternative |
|------|-------------|
| Git operations | Demander à utilisateur |
| Build TypeScript | Demander à utilisateur |
| Tests | Demander à utilisateur |
| npm install | Demander à utilisateur |
| Commandes shell | MCP win-cli ou utilisateur |

---

## Règle pour Skills/Agents

**Les skills et agents DOIVENT:**

1. **Déclarer** leur dépendance bash dans le frontmatter:
   ```yaml
   tools: Read, Grep, Glob, Bash  # Bash requis pour validation
   ```

2. **Prévoir** un mode dégradé si bash échoue:
   ```markdown
   ## Mode Dégradé
   Si bash indisponible:
   - Analyser le code source
   - Proposer corrections
   - Demander validation manuelle
   ```

3. **Documenter** les actions bloquées dans le rapport final

---

**Dernière mise à jour:** 2026-02-18
