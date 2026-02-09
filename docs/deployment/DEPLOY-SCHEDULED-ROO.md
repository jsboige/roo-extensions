# Deploiement Modes Simple/Complex + Scheduler Roo

Guide pour deployer les 10 modes Roo (5 familles x 2 niveaux) et configurer le scheduler sur chaque machine.

## Prerequis

- Roo Code installe dans VS Code
- Git configure avec acces au repo `jsboige/roo-extensions`
- Variable d'environnement `ROOSYNC_SHARED_PATH` configuree dans `.env`
- MCP roo-state-manager configure dans VS Code (`.roo/mcp.json`)

## Etape 1 : Synchroniser le depot

```powershell
cd d:\roo-extensions
git pull origin main
git submodule update --init --recursive
```

## Etape 2 : Build MCP

```powershell
cd mcps/internal/servers/roo-state-manager
npm run build
```

Verifier que le build passe sans erreur TypeScript.

## Etape 3 : Recharger VS Code

**OBLIGATOIRE** apres le build MCP : `Ctrl+Shift+P` -> `Reload Window`

Les outils MCP sont charges au demarrage de VS Code uniquement.

## Etape 4 : Deployer modes + rules via RooSync

Depuis Roo ou Claude Code, utiliser l'outil MCP `roosync_config` :

```
roosync_config action=apply machineId='myia-ai-01' targets=['roomodes','rules']
```

Ceci va :
1. Telecharger `.roomodes` depuis GDrive (publie par myia-ai-01)
2. L'appliquer a la racine du workspace (`.roomodes`)
3. Telecharger les rules globales
4. Les deployer dans `~/.roo/rules/` (dossier home de l'utilisateur)

**Note :** Le `machineId` doit pointer vers la machine source qui a publie la configuration (typiquement `myia-ai-01`).

### Alternative manuelle (si RooSync non disponible)

```powershell
# Copier .roomodes
copy roo-config\modes\generated\simple-complex.roomodes .roomodes

# Deployer rules globales
$rulesDir = Join-Path $env:USERPROFILE ".roo\rules"
if (-not (Test-Path $rulesDir)) { New-Item -ItemType Directory -Path $rulesDir -Force }
Copy-Item roo-config\rules-global\*.md $rulesDir\
```

## Etape 5 : Configurer model-configs.json (PAR MACHINE)

Le fichier `roo-config/model-configs.json` contient les mappings modes -> modeles LLM. Chaque machine peut avoir des profils differents selon ses capacites.

**L'utilisateur adapte ce fichier manuellement** en fonction des modeles disponibles sur la machine (GLM-4.5-Air, GLM-4.7, Claude, Gemini, etc.).

## Etape 6 : Validation

### 6.1 Verifier les modes

Ouvrir le selecteur de mode dans Roo Code. Vous devez voir 10 modes :
- `code-simple` / `code-complex`
- `debug-simple` / `debug-complex`
- `architect-simple` / `architect-complex`
- `ask-simple` / `ask-complex`
- `orchestrator-simple` / `orchestrator-complex`

### 6.2 Test d'escalade

1. Lancer une tache en `code-simple`
2. Donner une tache complexe (refactoring multi-fichiers)
3. Verifier que le mode detecte la complexite et suggere l'escalade vers `code-complex`

### 6.3 Verifier les rules

```powershell
ls ~/.roo/rules/
```

Doit contenir 4 fichiers :
- `00-securite.md`
- `01-sddd-escalade.md`
- `02-terminal-environnement.md`
- `03-vigilance-pratiques.md`

### 6.4 Verifier le champ instructions personnalisees

Le champ "Instructions personnalisees pour tous les modes" dans les settings Roo Code doit etre **VIDE**. Tout le contenu est maintenant dans `~/.roo/rules/`.

## Troubleshooting

| Probleme | Solution |
|----------|----------|
| Modes non visibles | Recharger VS Code (`Ctrl+Shift+P` -> Reload Window) |
| `.roomodes` non deploye | Verifier que `roosync_config action=apply` a fonctionne. Fallback : copie manuelle |
| Erreur build MCP | Verifier Node.js >= 18, `npm install` d'abord |
| Emojis corrompus dans les noms de modes | Le fichier doit etre en UTF-8 sans BOM |
| Rules non chargees | Verifier que les fichiers sont dans `~/.roo/rules/` (pas `~/.roo/rules-global/`) |
| Escalade ne fonctionne pas | Verifier `customInstructions` dans `.roomodes` - doit contenir les criteres d'escalade |

## Architecture en 3 couches

```
Couche 1 : Rules globales (~/.roo/rules/*.md)
   Securite, submodules, terminal, escalade SDDD
   Chargees par TOUS les modes sur TOUTES les machines

Couche 2 : Rules projet (.roo/rules/*.md)
   Specifique au workspace roo-extensions
   Environnement partage Claude Code + Roo, liste des modes valides

Couche 3 : Instructions par mode (.roomodes customInstructions)
   Criteres d'escalade/desescalade specifiques a chaque mode
   GENERIQUES - pas de references workspace
```

## Publication initiale (coordinateur uniquement)

Pour publier la configuration depuis myia-ai-01 :

```
roosync_config action=publish targets=['roomodes','rules'] version='1.0.0' description='Deploy modes simple/complex + rules globales'
```
