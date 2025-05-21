# Guide de dépannage

Ce guide vous aidera à résoudre les problèmes courants rencontrés lors de l'utilisation des serveurs MCP.

## Problèmes d'installation

### Erreur: Module introuvable

**Symptôme**: Message d'erreur du type `Cannot find module 'xxx'`

**Solution**:
1. Vérifiez que vous avez exécuté `npm install` dans le répertoire principal
2. Exécutez `npm run install-all` pour installer les dépendances de tous les serveurs
3. Vérifiez que le module est bien listé dans le fichier `package.json` correspondant
4. Essayez d'installer manuellement le module: `npm install xxx`

### Erreur: Version de Node.js incompatible

**Symptôme**: Message d'erreur indiquant que la version de Node.js est trop ancienne

**Solution**:
1. Vérifiez votre version de Node.js: `node --version`
2. Installez une version plus récente de Node.js (14.x ou supérieur recommandé)
3. Utilisez nvm pour gérer plusieurs versions de Node.js: `nvm use 14`

## Problèmes de configuration

### Erreur: Fichier de configuration introuvable

**Symptôme**: Message d'erreur du type `Cannot find config file`

**Solution**:
1. Exécutez `npm run setup-config` pour générer les fichiers de configuration
2. Vérifiez que le fichier `config.json` existe dans le répertoire du serveur
3. Copiez manuellement `config.example.json` vers `config.json`

### Erreur: Configuration invalide

**Symptôme**: Message d'erreur indiquant que la configuration est invalide

**Solution**:
1. Vérifiez que le fichier de configuration est un JSON valide
2. Comparez avec `config.example.json` pour vous assurer que tous les champs requis sont présents
3. Vérifiez les valeurs des champs (URLs, ports, clés API, etc.)

## Problèmes de connexion

### Erreur: Impossible de se connecter au serveur MCP

**Symptôme**: Le LLM ne peut pas se connecter au serveur MCP

**Solution**:
1. Vérifiez que le serveur MCP est en cours d'exécution
2. Vérifiez le port utilisé (par défaut 3000)
3. Assurez-vous qu'aucun pare-feu ne bloque la connexion
4. Vérifiez les logs du serveur pour plus d'informations

### Erreur: Timeout de connexion

**Symptôme**: La connexion au serveur MCP expire

**Solution**:
1. Augmentez la valeur du timeout dans la configuration
2. Vérifiez la stabilité de votre connexion réseau
3. Vérifiez si le serveur est surchargé

## Problèmes d'authentification

### Erreur: Clé API invalide

**Symptôme**: Message d'erreur indiquant que la clé API est invalide

**Solution**:
1. Vérifiez que la clé API est correctement configurée dans `config.json`
2. Générez une nouvelle clé API si nécessaire
3. Vérifiez que la clé API a les permissions nécessaires

## Problèmes spécifiques aux serveurs

### API Connectors

#### Erreur: Limite d'API dépassée

**Symptôme**: Message d'erreur indiquant que la limite d'API est dépassée

**Solution**:
1. Attendez que la limite soit réinitialisée
2. Utilisez une clé API différente
3. Augmentez votre quota auprès du fournisseur d'API

### Dev Tools

#### Erreur: Analyse de code échouée

**Symptôme**: L'analyse de code ne produit pas de résultat ou échoue

**Solution**:
1. Vérifiez que le fichier à analyser existe et est accessible
2. Vérifiez que le langage du fichier est supporté
3. Augmentez la limite de mémoire si le fichier est volumineux

### System Utils

#### Erreur: Permissions insuffisantes

**Symptôme**: Message d'erreur indiquant des permissions insuffisantes

**Solution**:
1. Vérifiez les permissions des fichiers et répertoires concernés
2. Exécutez le serveur avec des privilèges plus élevés si nécessaire (avec précaution)
3. Configurez correctement les permissions dans le système d'exploitation

## Collecte d'informations pour le support

Si vous ne parvenez pas à résoudre un problème, collectez les informations suivantes avant de demander de l'aide:

1. Version de Node.js: `node --version`
2. Version du serveur MCP concerné
3. Logs d'erreur complets
4. Configuration (sans les informations sensibles)
5. Étapes pour reproduire le problème

## Contacter le support

Si vous avez besoin d'aide supplémentaire:

1. Ouvrez une issue sur GitHub: [https://github.com/jsboige/jsboige-mcp-servers/issues](https://github.com/jsboige/jsboige-mcp-servers/issues)
2. Incluez toutes les informations collectées ci-dessus
3. Décrivez clairement le problème et les étapes que vous avez déjà essayées