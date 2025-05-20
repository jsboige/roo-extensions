# Tests d'Encodage

Ce document sert à tester et documenter les problèmes d'encodage dans le projet Roo Extensions. L'encodage correct des caractères est essentiel pour garantir la compatibilité entre les différents composants du projet et éviter les problèmes d'affichage.

## Caractères de Test

### Caractères accentués français
- Minuscules : é è ê ë à â ä ô ö ù û ü ç
- Majuscules : É È Ê Ë À Â Ä Ô Ö Ù Û Ü Ç
- Ligatures : œ æ Œ Æ

### Autres caractères spéciaux
- Symboles : € £ ¥ © ® ™ ° § ¶
- Guillemets : « » " " ' '
- Tirets et espaces : – — …

## Phrases de test

Voici quelques phrases avec des caractères accentués pour tester l'encodage :

1. Les paramètres de configuration sont stockés dans le dossier.
2. L'exécution des tests nécessite une configuration spécifique.
3. Les modes personnalisés permettent d'étendre les fonctionnalités.
4. Voici un texte avec des caractères spéciaux : 100€, 50£, 25°C.
5. « Les guillemets français » et "les guillemets anglais" sont différents.

## Problèmes d'encodage courants

### Problèmes identifiés
- Caractères accentués mal affichés dans les fichiers JSON
- Problèmes avec les emojis dans les fichiers de configuration
- Caractères spéciaux corrompus lors de la conversion entre formats

### Solutions implémentées
- Utilisation systématique de l'encodage UTF-8 sans BOM
- Scripts de correction d'encodage dans `roo-config/encoding-scripts/`
- Tests automatisés pour détecter les problèmes d'encodage

## Comment tester l'encodage

Pour vérifier si l'encodage est correct dans vos fichiers :

1. Exécutez le script de diagnostic d'encodage :
   ```powershell
   cd ../roo-config/diagnostic-scripts
   .\diagnostic-rapide-encodage.ps1
   ```

2. Si des problèmes sont détectés, utilisez le script de correction approprié :
   ```powershell
   cd ../roo-config/encoding-scripts
   .\fix-encoding.ps1
   ```

3. Vérifiez que ce fichier s'affiche correctement avec tous ses caractères spéciaux.

## Références

- [Documentation sur l'encodage](../roo-config/encoding-scripts/README.md)
- [Scripts de diagnostic d'encodage](../roo-config/diagnostic-scripts/README.md)