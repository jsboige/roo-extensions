# Détection deny-sans-repli — sonde handshake au démarrage

**Version :** 1.0.0 · **Issue :** #4340 (STOP&REPAIR, mandat user 2026-10-24) · **MAJ :** 2026-10-24

---

## Incident fondateur (po-2027/CoursIA, 24/10)

User verbatim : « La complaisance vis à vis d'un environnement défectueux est mortelle et a déjà détruit de nombreux notebooks [...] Pas d'excuse, pas de workaround, et escalade globale d'un incident gravissime. Il faudra encore renforcer le harnais en ce sens. »

Le MCP `jupyter-papermill` n'a jamais été provisionné sur po-2027 (`~/.claude.json` sans entrée, `.mcp.json` local absent) alors que `NotebookEdit` est deny : **le repli canonique désigné par la règle n'existait pas, et rien ne l'a détecté pendant des semaines**. La lane a normalisé un fallback interdit (bytesplice JSON du `.ipynb` par script) au lieu d'escalader. Mesures et réparation : dashboard global 2026-10-24 13:11Z + REPLY 16:00Z (repair vérifié en session, 23 outils).

La règle (`.claude/rules/harnais-tightening.md` §2) était saine — son **prérequis de provisioning n'était pas vérifié**. Ce document outille cette vérification.

## Les quatre leçons câblées dans le harnais

1. **Détection deny-sans-repli au démarrage.** Outil deny + règle désignant un repli canonique unique → le démarrage vérifie par **handshake** que le repli répond. Échec = signal visible permanent, pas une découverte par incident des semaines plus tard.
2. **La sonde ne lit pas les drapeaux — seul le handshake décide.** Mesuré po-2025 (13:47Z) : `disabled: true` dans une entrée `.mcp.json` est **inert sur un siège Claude Code** (drapeau VS Code/Roo) — le serveur charge quand même. Seul l'emplacement 3 (`projects[<ws>].disabledMcpServers` de `~/.claude.json`) désactive effectivement un serveur sur le siège. Une sonde qui se fie au drapeau conclut l'inverse de la réalité.
3. **Câblage normalisé vers UNE forme** (voir recette ci-dessous) — cinq variantes recensées sur la flotte : pip-editable + module / module avec `disabled:true` / inline `-c` / conda-global / module-nu-inerte.
4. **Périmètre : chaque workspace décide** (arbitrage user 24/10) — CoursIA est centré Jupyter, pas de déploiement aveugle flotte-wide. Le deny actif sur le siège EST le signal d'opt-in de la vérification.

## La sonde : `scripts/diagnostic/check-deny-fallback.py`

```bash
python scripts/diagnostic/check-deny-fallback.py --workspace <chemin>   # sonde un siège
python scripts/diagnostic/check-deny-fallback.py --json                 # machine-readable
python scripts/diagnostic/check-deny-fallback.py --selftest             # fixtures + handshake réel
```

La carte des replis (`DENY_FALLBACK_MAP` dans le script) démarre à une entrée : `NotebookEdit` → `jupyter-papermill`. Une future règle désignant un autre repli canonique unique s'y ajoute par édition.

| Statut | Signification | Exit |
|---|---|---|
| `INERT` | outil non deny sur ce siège — le workspace décide | 0 |
| `OK` | deny + repli configuré + handshake (initialize → tools/list) + ≥1 outil | 0 |
| `DENY-WITHOUT-FALLBACK` | deny + aucune config du serveur (l'incident po-2027) | 2 |
| `FALLBACK-DISABLED-SEAT` | deny + config mais `disabledMcpServers` du siège — ne se chargera pas en session | 2 |
| `FALLBACK-DEAF` | deny + config mais handshake muet/erreur/0 outil | 2 |
| `UNRESOLVED` | settings illisible (instrument) | 1 |

**Résolution du serveur** (ordre canonique) : `.mcp.json` du workspace → `projects[<ws>].mcpServers` (local) → `mcpServers` top-level (user) de `~/.claude.json`. **Deny lu** comme union des scopes settings (user `~/.claude/settings.json`, projet `.claude/settings.json`, `.claude/settings.local.json`) — deny dans n'importe quel scope = deny.

**Timeout par défaut 30 s, délibéré** sur le `CONNECT_TIMEOUT` de l'hôte Claude Code : un serveur plus lent que le cutoff de l'hôte est un repli **effectivement absent**, pas un repli lent (`--timeout` pour sonder plus long).

**Le handshake est réel** : spawn du process configuré, `initialize` → `notifications/initialized` → `tools/list`, stdin maintenu ouvert (un EOF déclenche le watchdog stdin de certains serveurs), stderr drainé vers fichier. Validé 24/10 contre le vrai serveur papermill du CoursIA po-2024 : 25 outils, exit 0 — et contre le siège roo-extensions po-204 (deny actif, MCP absent) : `DENY-WITHOUT-FALLBACK`, exit 2.

### Conduite sur finding

- La capacité touchée (édition notebook) est **BLOQUÉE** — jamais de workaround : pas de bytesplice JSON du `.ipynb`, pas de `NotebookEdit`, quelle que soit la pression.
- Ouvrir/entretenir une **entrée registre** + relayer `[WARN]`/`[ASK]` sur le dashboard workspace.
- Le provisioning du repli est une **décision par workspace** (point 4) — pas un geste flotte-wide automatique.

## Intégration au démarrage

| Siège | Mécanisme | Posture |
|---|---|---|
| Lane executor (`/executor`) | `scripts/claude/executor-preflight.ps1` invoque la sonde chaque pré-vol | `[DENY-FALLBACK]` **WARN non bloquant** (posture #3169) : le cycle continue, le signal reste visible à chaque pré-vol ; relay dashboard + registre instruit par le skill/command executor |
| Session interactive | règle `harnais-tightening.md` §2 (déployée globale) : lancer la sonde en début de session sur siège deny | finding = capacité bloquée + registre |

Le WARN-never-block du pré-vol est un choix : la posture bloquante s'applique à la **capacité** (édition notebook), pas au cycle — un lane non-Jupyter (roo-extensions) ne doit pas mourir à chaque pré-vol pour un repli qu'elle n'utilise pas ; le standing WARN rend l'écart impossible à rater sans tuer la cadence.

## Câblage canonique `jupyter-papermill` (UNE forme)

`.mcp.json` **local au workspace** (gitignoré — racine `.gitignore` ligne `.mcp.json`) + install editable du serveur dans le venv du workspace + entrée stdio **sans drapeau** :

```json
{
  "mcpServers": {
    "jupyter-papermill": {
      "type": "stdio",
      "command": "<venv-du-workspace>\\Scripts\\python.exe",
      "args": ["-m", "papermill_mcp.main"]
    }
  }
}
```

Install editable : `python -m pip install -e <roo-extensions>/mcps/internal/servers/jupyter-papermill-mcp-server`.

Vérification (la seule qui compte) :

```bash
python <roo-extensions>/scripts/diagnostic/check-deny-fallback.py --workspace <ws>
# attendu : [OK] NotebookEdit deny -> jupyter-papermill: handshake OK — N outil(s)
```

## Tests

| Suite | Ce qu'elle garde | Job CI |
|---|---|---|
| `--selftest` (dans le script) | 7 scénarios avec handshake réel contre un fake serveur MCP : ok / drapeau-ignoré / sans-config / deny-forme-spec / disabled-seat / inert / serveur-mort | via wrapper |
| `scripts/testing/python/test_check_deny_fallback.py` | selftest passe + surface CLI | statique (`unittest discover`) |
| `scripts/testing/unit/executor-preflight-deny-fallback.Tests.ps1` | câblage pré-vol : invocation `--workspace`, contrat exit 2, WARN jamais bloquant, relay skill+command | unit-pester |

---

**Principe condensé** : *« Le repli désigné par une règle se vérifie par handshake au démarrage — un drapeau ne prouve rien, une réponse initialize oui. Deny sans repli = capacité bloquée, jamais de workaround. »*
