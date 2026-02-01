# Règles de Sécurité - Roo Code

## JAMAIS PUBLIER DE SECRETS

Ces règles sont **ABSOLUES** et ne peuvent pas être contournées.

### Fichiers Interdits

**NE JAMAIS lire, modifier ou commit ces fichiers :**

| Pattern | Exemple |
|---------|---------|
| `.env`, `.env.*` | `.env`, `.env.local`, `.env.production` |
| `credentials.*` | `credentials.json`, `credentials.yaml` |
| `secrets.*` | `secrets.json`, `secrets.yaml` |
| `*.pem`, `*.key` | `server.key`, `private.pem` |
| `id_rsa*` | `id_rsa`, `id_rsa.pub` |
| `~/.ssh/*` | Tout le répertoire SSH |
| `*token*`, `*password*` | Fichiers avec ces mots dans le nom |

### Avant Chaque Commit

**Vérifier que le commit NE CONTIENT PAS :**

1. Clés API (ex: `sk-...`, `AKIA...`)
2. Tokens d'authentification
3. Mots de passe
4. Clés privées
5. Secrets d'application

### Commandes de Vérification

```bash
# Vérifier fichiers staged
git diff --cached --name-only | xargs grep -l -E "(password|secret|token|api.?key)" 2>/dev/null

# Vérifier le contenu
git diff --cached | grep -E "(sk-|AKIA|password\s*=|token\s*=)"
```

### Si Secret Commité par Erreur

1. **NE PAS PUSH** si pas encore fait
2. `git reset HEAD~1` pour annuler le commit
3. Supprimer le secret du fichier
4. Refaire le commit proprement
5. **SI DÉJÀ PUSH :** Alerter immédiatement l'utilisateur via INTERCOM

### .gitignore Obligatoire

Ces entrées DOIVENT être dans `.gitignore` :

```gitignore
# Secrets - OBLIGATOIRE
.env
.env.*
*.pem
*.key
credentials.json
secrets.json

# IDE
.vscode/settings.json
.idea/

# Build
node_modules/
dist/
*.log
```

---

## Communication Sécurité

Si tu détectes un risque de sécurité :

```markdown
## [TIMESTAMP] roo → claude-code [ERROR]

### ALERTE SÉCURITÉ

**Risque détecté :** [description]
**Fichier concerné :** [chemin]
**Action requise :** [bloquer/supprimer/alerter]

---
```

---

*Ces règles sont non-négociables. Aucune exception.*
