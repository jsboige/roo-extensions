# Gabarit de workspace (Epic #3111, candidat #7 — étape 1, #4873)

Décision user RX152 (13/11) : « Faire le gabarit et voir au mieux comment RSM peut le
déployer. » Ce répertoire est ce gabarit : **ce qui converge entre les dépôts** de la
flotte, et rien d'autre. Ce qui est propre à un dépôt reste dans le dépôt. L'étape 2
(déploiement par le RSM) vivra côté `jsboige-mcp-servers`.

## Contenu — ce qui converge

| Fichier du gabarit | Devient, dans le dépôt cible |
|--------------------|------------------------------|
| `CLAUDE.md.template` | `CLAUDE.md` — marqueurs `{{WORKSPACE}}` et `{{REPO}}` remplacés |
| `gitignore.fragment` | fusion dans `.gitignore` — ajout des seules lignes absentes |
| `.claude/rules/claim-discipline.md` | `.claude/rules/claim-discipline.md` (verbatim) |
| `.claude/rules/pr-mandatory.md` | `.claude/rules/pr-mandatory.md` (verbatim) |
| `.claude/plans/README.md` | `.claude/plans/README.md` (verbatim) |
| `memory-seed/MEMORY.md` | graine de l'index de la mémoire machine |
| `memory-seed/user-question-registry.md` | graine du registre des questions user |

`README.md` (ce fichier) est la documentation du gabarit : il ne part jamais dans la cible.
Les marqueurs `{{WORKSPACE}}` et `{{REPO}}` sont les **seuls** à remplacer ; ils peuvent
apparaître dans n'importe quel fichier copié.

## Ce qui reste propre au dépôt

Tout le reste : la description métier (section Vue d'ensemble du `CLAUDE.md`), les MCP et
configs spécifiques, les submodules, les scripts propres, et toute règle additionnelle
au-delà des deux du gabarit. **Les règles globales (`~/.claude/CLAUDE.md`,
`~/.claude/rules/*.md`) ne sont jamais recopiées** — le gabarit n'en porte que des
pointeurs.

## Comment l'appliquer

Depuis un checkout roo-extensions (Windows PowerShell 5.1 ou PowerShell 7+) :

```powershell
powershell -ExecutionPolicy Bypass -File scripts/workspace/New-WorkspaceFromTemplate.ps1 -Target <chemin du nouveau dépôt> -Workspace <nom> -DryRun
powershell -ExecutionPolicy Bypass -File scripts/workspace/New-WorkspaceFromTemplate.ps1 -Target <chemin> -Workspace <nom>
```

- **Création seule** : un fichier existant n'est jamais écrasé — il est listé comme
  sauté ; un second run est idempotent.
- `-DryRun` n'écrit rien, pas même un répertoire, et imprime la liste de ce qui serait créé.
- Le script **n'écrit jamais hors de `-Target`** et refuse la racine d'un lecteur comme
  toute cible qui contiendrait le gabarit lui-même.
- `{{REPO}}` est dérivé du nom du répertoire cible (dernier segment de `-Target`).

### La graine mémoire (`memory-seed/`)

Elle est copiée telle quelle dans la cible. À la première session du workspace sur une
machine, initialiser la mémoire machine (`~/.claude/projects/<hash>/memory/`) depuis ces
deux fichiers, puis la graine peut être retirée du dépôt. Ce geste manuel est provisoire :
l'étape 2 (déploiement RSM) l'automatisera.

Garde : `scripts/testing/unit/new-workspace-from-template.Tests.ps1` (job CI `unit-pester`).
