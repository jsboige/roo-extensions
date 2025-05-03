# Documentation des commits et procédure de push

Ce document décrit les commits effectués pour le projet de modes personnalisés Roo, ainsi que les recommandations pour les futurs commits et la procédure de push vers le dépôt distant.

## Commits effectués

### Phase initiale

1. **Création de la structure de base**
   ```
   mkdir -p custom-modes/docs/structure-technique custom-modes/docs/architecture custom-modes/docs/criteres-decision custom-modes/docs/optimisation custom-modes/docs/implementation custom-modes/templates custom-modes/examples
   ```

2. **Copie des documents existants**
   ```
   copy optimized-agents\docs\criteres-decision.md custom-modes\docs\criteres-decision\criteres-decision.md
   copy optimized-agents\docs\notes-pour-reprise.md custom-modes\docs\implementation\notes-pour-reprise.md
   ```

### Phase de développement

3. **Création du fichier `.roomodes`**
   - Définition des modes personnalisés avec leurs configurations spécifiques
   - Implémentation des mécanismes d'escalade et de rétrogradation
   - Ajout des instructions pour la gestion des tokens, l'utilisation des MCPs et les commandes PowerShell

### Phase de déploiement

4. **Synchronisation avec le fichier global**
   ```
   Copy-Item -Path ".roomodes" -Destination "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json" -Force
   ```

5. **Création de la documentation de déploiement**
   - Création du fichier `custom-modes/docs/implementation/deploiement.md`
   - Documentation du processus d'installation et de synchronisation

6. **Création du script de déploiement**
   - Création du fichier `custom-modes/scripts/deploy.ps1`
   - Automatisation du processus de déploiement

7. **Documentation des commits**
   - Création du fichier `custom-modes/docs/implementation/commits.md`
   - Documentation des commits effectués et de la procédure de push

## Recommandations pour les futurs commits

### Convention de nommage

Pour maintenir une historique de commits claire et cohérente, suivez ces conventions de nommage:

1. **Format général**: `type(scope): description concise`
   - **type**: Le type de changement (feat, fix, docs, style, refactor, test, chore)
   - **scope**: Le module ou la fonctionnalité concernée (optional)
   - **description**: Une description concise du changement

2. **Types de commits**:
   - `feat`: Nouvelle fonctionnalité
   - `fix`: Correction de bug
   - `docs`: Modification de la documentation
   - `style`: Changements qui n'affectent pas le sens du code (espaces, formatage, etc.)
   - `refactor`: Changement de code qui ne corrige pas un bug et n'ajoute pas de fonctionnalité
   - `test`: Ajout ou modification de tests
   - `chore`: Changements aux outils de build, aux dépendances, etc.

3. **Exemples**:
   - `feat(modes): ajouter le mode orchestrator-complex`
   - `fix(escalade): corriger le mécanisme d'escalade interne`
   - `docs(deploiement): mettre à jour la documentation de déploiement`
   - `refactor(instructions): améliorer la lisibilité des instructions`

### Bonnes pratiques

1. **Commits atomiques**: Chaque commit doit représenter un changement logique unique et cohérent.

2. **Messages descriptifs**: Le message de commit doit expliquer clairement ce qui a été changé et pourquoi.

3. **Référence aux issues**: Si le commit est lié à une issue, incluez le numéro de l'issue dans le message.

4. **Vérification avant commit**: Assurez-vous que le code fonctionne correctement avant de le committer.

## Procédure de push vers le dépôt distant

### Configuration initiale

Si vous n'avez pas encore configuré le dépôt distant:

1. **Initialiser le dépôt local** (si ce n'est pas déjà fait):
   ```powershell
   git init
   ```

2. **Ajouter le dépôt distant**:
   ```powershell
   git remote add origin <url-du-depot>
   ```

### Procédure de push

1. **Vérifier l'état du dépôt**:
   ```powershell
   git status
   ```

2. **Ajouter les fichiers modifiés**:
   ```powershell
   git add .
   ```
   Ou pour ajouter des fichiers spécifiques:
   ```powershell
   git add <fichier1> <fichier2> ...
   ```

3. **Créer un commit**:
   ```powershell
   git commit -m "type(scope): description concise"
   ```

4. **Récupérer les dernières modifications du dépôt distant**:
   ```powershell
   git pull origin main
   ```
   Résoudre les conflits si nécessaire.

5. **Pousser les modifications vers le dépôt distant**:
   ```powershell
   git push origin main
   ```

### Gestion des branches

Pour les développements plus complexes, utilisez des branches:

1. **Créer une nouvelle branche**:
   ```powershell
   git checkout -b feature/nom-de-la-fonctionnalite
   ```

2. **Pousser la branche vers le dépôt distant**:
   ```powershell
   git push origin feature/nom-de-la-fonctionnalite
   ```

3. **Créer une pull request** sur la plateforme de gestion de code (GitHub, GitLab, etc.).

## Vérification finale avant push

Avant de pousser vos modifications, assurez-vous que:

1. **Tous les fichiers nécessaires sont inclus**:
   - Fichier `.roomodes`
   - Documentation de déploiement
   - Script de déploiement
   - Documentation des commits

2. **Les fichiers sont correctement formatés**:
   - Le fichier `.roomodes` est un JSON valide
   - Les fichiers Markdown sont bien structurés
   - Le script PowerShell est fonctionnel

3. **Les modifications ont été testées**:
   - Le script de déploiement fonctionne correctement
   - Les modes personnalisés sont correctement configurés
   - La documentation est claire et précise

4. **Les informations sensibles sont exclues**:
   - Pas de tokens d'accès ou de mots de passe
   - Pas d'informations personnelles
   - Pas de chemins absolus spécifiques à votre machine