# Guide de Sécurité : Configuration MCP - Éviter les Erreurs Critiques

## ⚠️ ATTENTION CRITIQUE ⚠️

**NE JAMAIS MODIFIER LE FICHIER MCP_SETTINGS.JSON SANS SAUVEGARDE COMPLÈTE**

## Incident du 28/05/2025 - 02:05 AM

### Contexte de l'erreur
- **Fichier affecté** : `C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
- **Cause** : Modification mineure (`"enabled": true` → `"disabled": false`) qui a cassé la moitié des serveurs MCP
- **Impact** : Perte de connectivité pour plusieurs serveurs MCP critiques (git, filesystem, searxng)

### Erreurs observées
```
MCP error -32000: Connection closed
```

### Leçons apprises

#### 1. Sensibilité extrême de la configuration MCP
- Une modification d'un seul champ peut casser l'ensemble du système
- La cohérence des propriétés est critique
- Certains serveurs utilisent `"disabled": false`, d'autres peuvent avoir des variations

#### 2. Configuration de référence fonctionnelle
```json
{
  "mcpServers": {
    "git": {
      "command": "cmd",
      "args": ["/c", "python", "-m", "mcp_server_git"],
      "env": {
        "MCP_TRANSPORT_TYPE": "stdio",
        "MCP_LOG_LEVEL": "info",
        "GIT_SIGN_COMMITS": "false",
        "GIT_DEFAULT_PATH": "D:\\roo-extensions"
      },
      "cwd": "d:/roo-extensions/mcps/forked/modelcontextprotocol-servers/src/git/src/",
      "disabled": false,
      "autoApprove": [],
      "alwaysAllow": ["git_status", "git_add", "git_commit", ...],
      "transportType": "stdio"
    }
  }
}
```

## Procédures de Sécurité

### Avant toute modification MCP

1. **SAUVEGARDE OBLIGATOIRE**
   ```powershell
   Copy-Item "C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json" "C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
   ```

2. **VALIDATION JSON**
   - Utiliser un validateur JSON avant toute sauvegarde
   - Vérifier la cohérence des propriétés

3. **TEST PROGRESSIF**
   - Redémarrer VSCode après modification
   - Vérifier la connectivité de chaque serveur MCP
   - Rollback immédiat si problème

### Propriétés critiques à ne jamais modifier sans expertise

- `"command"` et `"args"` : Définissent comment lancer le serveur
- `"transportType"` : Toujours `"stdio"` pour nos serveurs
- `"disabled"` : Utiliser `false` pour activer, `true` pour désactiver
- `"cwd"` : Répertoire de travail critique pour certains serveurs
- `"env"` : Variables d'environnement essentielles

### Serveurs MCP critiques à ne jamais casser

1. **filesystem** : Accès aux fichiers
2. **git** : Opérations Git
3. **github** : Intégration GitHub
4. **quickfiles** : Opérations de fichiers multiples
5. **win-cli** : Commandes système
6. **searxng** : Recherche web

## Configuration de référence par OS

### Windows (D:\roo-extensions)
- Chemins avec `D:\\roo-extensions` (double backslash)
- Commandes via `cmd /c`
- Serveurs internes : `D:\\roo-extensions\\mcps\\internal\\servers\\`

### Autres OS (C:\dev\roo-extensions)
- Chemins avec `/` ou `\\` selon le contexte
- Serveurs internes : chemins adaptés

## Commandes de diagnostic MCP

```powershell
# Vérifier la syntaxe JSON
Get-Content "C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json" | ConvertFrom-Json

# Sauvegarder avant modification
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item "C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json" "mcp_settings.backup.$timestamp.json"
```

## Restauration d'urgence

En cas de corruption :

1. **Arrêter VSCode complètement**
2. **Restaurer depuis sauvegarde**
3. **Redémarrer VSCode**
4. **Vérifier la connectivité MCP**

## Points de vigilance spécifiques

### Serveur win-cli
- Utilise `npm start -- --debug` comme commande
- Répertoire de travail : `d:\\roo-extensions\\mcps\\external\\win-cli\\server`
- **NE PAS** utiliser `npx -y @simonb97/server-win-cli` (version externe)

### Serveurs internes
- Tous dans `D:\\roo-extensions\\mcps\\internal\\servers\\`
- Utilisent `node` avec le chemin complet vers `build/index.js` ou `dist/index.js`

### Configuration des tokens et secrets
- Les tokens GitHub doivent être configurés via des variables d'environnement
- URL SearXNG : `https://search.myia.io/`
- **IMPORTANT** : Ne jamais inclure de tokens dans les fichiers de configuration versionnés
- Utiliser des fichiers `.env` (ignorés par Git) pour stocker les tokens sensibles

## Conclusion

**La configuration MCP est extrêmement fragile. Toute modification doit être traitée comme une opération critique avec sauvegarde préalable et validation complète.**

---
*Document créé suite à l'incident du 28/05/2025 - Ne pas reproduire cette erreur*