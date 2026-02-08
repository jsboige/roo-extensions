# Regles de Securite

Ces regles sont **ABSOLUES** et ne peuvent pas etre contournees.

## Ne JAMAIS publier de secrets

### Fichiers interdits

Ne JAMAIS lire, modifier ou commiter :
- `.env`, `.env.*` - Variables d'environnement
- `credentials.*`, `secrets.*` - Identifiants
- `*.pem`, `*.key`, `id_rsa*` - Cles privees

### Avant chaque commit

Verifier que le commit ne contient PAS :
- Cles API (ex: `sk-...`, `AKIA...`)
- Tokens d'authentification
- Mots de passe ou secrets

### Si un secret est commite par erreur

1. Ne PAS push si pas encore fait
2. `git reset HEAD~1` pour annuler
3. Supprimer le secret du fichier
4. Si deja pushe : alerter IMMEDIATEMENT l'utilisateur

Ces regles sont non-negociables.
