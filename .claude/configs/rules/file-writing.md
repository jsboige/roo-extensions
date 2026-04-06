# File Writing (Global)

| Situation | Outil | Note |
|-----------|-------|------|
| Modifier existant | `Edit` | `Read` d'abord. Prefere. |
| Creer nouveau | `Write` | `Read` d'abord si existe deja. |
| Ajouter contenu | `Edit` (remplacer dernier bloc) | Jamais `Write` (ecrase tout). |

- **Edit necessite Read prealable** — echoue sinon
- **Edit old_string doit etre unique** — ajouter du contexte si ambigu
- **Encodage** : UTF-8 no-BOM. PowerShell : `[System.IO.File]::WriteAllText()` avec `UTF8Encoding($false)`
