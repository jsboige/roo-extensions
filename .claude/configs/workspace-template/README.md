# Workspace template — gabarit de workspace (#3111 étape 1, #4873)

Décision user 13/11 (RX152) : « Faire le gabarit et voir au mieux comment RSM peut le déployer ».
Cette étape 1 livre le gabarit et l'amorçage local. L'étape 2 (déploiement par le RSM) vit côté
`jsboige-mcp-servers`.

## Ce qui converge (contenu du gabarit)

- `CLAUDE.md.template` — squelette court ; seuls `{{WORKSPACE}}` et `{{REPO}}` sont remplacés.
- `gitignore.fragment` — `.tmp/`, `scratchpad_*`, `C:Users*`, `.claude/local/`.
- `.claude/rules/` — **deux** règles : claim sur l'issue (ADR 017), PR obligatoire.
- `.claude/plans/README.md` — pointeur vers la convention plans/progress (ADR 015), optionnelle.
- `memory-seed/` — `MEMORY.md` (index vide, 1 ligne par fiche) et
  `user-question-registry.md` (squelette, 5 champs du format user).

## Ce qui reste propre au dépôt

La configuration projet (MCP, provider, modes, scripts métier) n'entre PAS dans le
gabarit : elle vit dans chaque dépôt. Les règles globales de `~/.claude/rules/` ne sont
jamais copiées ici.

## Comment l'appliquer

```powershell
# Prévisualiser (n'écrit rien, pas même un répertoire)
powershell -ExecutionPolicy Bypass -File <roo-extensions>/scripts/workspace/New-WorkspaceFromTemplate.ps1 -Target C:\dev\MonRepo -Workspace MonRepo -DryRun

# Créer (création seule : refuse d'écraser, liste les fichiers sautés, fusionne .gitignore)
powershell -ExecutionPolicy Bypass -File <roo-extensions>/scripts/workspace/New-WorkspaceFromTemplate.ps1 -Target C:\dev\MonRepo -Workspace MonRepo
```

Le script est compatible PowerShell 5.1 et n'écrit jamais hors de `-Target`.
