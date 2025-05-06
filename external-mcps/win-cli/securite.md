# Guide de sécurité pour Win-CLI MCP

Ce guide présente les bonnes pratiques de sécurité à suivre lors de l'utilisation du serveur MCP Win-CLI, qui permet à Roo d'exécuter des commandes sur votre système.

## Risques de sécurité

L'exécution de commandes système via un serveur MCP présente plusieurs risques de sécurité potentiels :

1. **Exécution de commandes dangereuses** : Suppression accidentelle de fichiers, modification de paramètres système critiques, etc.
2. **Injection de commandes** : Exécution de commandes malveillantes via des entrées non validées
3. **Élévation de privilèges** : Exécution de commandes avec des privilèges supérieurs à ceux nécessaires
4. **Fuite d'informations sensibles** : Exposition de données confidentielles via l'historique des commandes ou les journaux
5. **Accès non autorisé** : Utilisation du serveur par des tiers non autorisés

## Bonnes pratiques générales

### Principe du moindre privilège

- Exécutez le serveur MCP Win-CLI avec les privilèges minimaux nécessaires
- Évitez d'exécuter le serveur en tant qu'administrateur, sauf si absolument nécessaire
- Limitez les commandes autorisées au strict nécessaire

### Isolation

- Exécutez le serveur dans un environnement isolé si possible
- Limitez l'accès aux fichiers et répertoires sensibles
- Utilisez des comptes utilisateurs dédiés pour l'exécution du serveur

### Validation des entrées

- Validez toutes les entrées avant de les utiliser dans des commandes
- Méfiez-vous des caractères spéciaux et des séquences d'échappement
- Utilisez des listes blanches plutôt que des listes noires pour filtrer les entrées

## Configuration sécurisée

### Limitation des commandes autorisées

Configurez la liste des commandes autorisées dans le fichier de configuration :

```json
"security": {
  "allowedCommands": [
    "dir", "ls", "type", "cat", "echo",
    "npm", "node", "git"
  ],
  "blockedCommands": [
    "rm", "del", "rmdir", "format", "shutdown",
    "reboot", "reg", "net user", "net localgroup"
  ]
}
```

### Restriction des séparateurs de commande

Limitez les séparateurs de commande autorisés pour réduire les risques d'injection :

```json
"security": {
  "commandSeparators": [";"],
  "allowCommandChaining": true
}
```

Pour une sécurité maximale, vous pouvez désactiver complètement le chaînage de commandes :

```json
"security": {
  "commandSeparators": [],
  "allowCommandChaining": false
}
```

### Sécurisation des connexions SSH

Si vous utilisez des connexions SSH :

- Utilisez des clés SSH plutôt que des mots de passe
- Stockez les clés privées dans un emplacement sécurisé
- Utilisez des phrases de passe pour protéger les clés privées
- Limitez les hôtes auxquels vous pouvez vous connecter

Exemple de configuration SSH sécurisée :

```json
"ssh": {
  "enabled": true,
  "connections": {
    "serveur-prod": {
      "host": "192.168.1.100",
      "port": 22,
      "username": "utilisateur",
      "privateKeyPath": "C:\\Users\\votre-nom\\.ssh\\id_rsa",
      "passphrase": "votre-phrase-de-passe"
    }
  }
}
```

## Sécurisation spécifique pour Roo

### Limitation des opérations dangereuses

Configurez Roo pour qu'il demande confirmation avant d'exécuter des commandes potentiellement dangereuses :

1. Identifiez les commandes à risque (suppression, modification de fichiers système, etc.)
2. Configurez des règles de validation dans vos prompts système
3. Demandez à Roo d'expliquer les commandes qu'il souhaite exécuter

### Séparation des environnements

- Utilisez des environnements distincts pour le développement et la production
- Créez des configurations spécifiques pour chaque environnement
- Limitez les commandes disponibles en fonction de l'environnement

## Personnalisation des séparateurs de commande

Comme mentionné dans la demande initiale, la personnalisation des séparateurs de commande est importante pour l'utilisation avec Roo. Voici comment configurer spécifiquement le séparateur `;` :

1. Modifiez le fichier de configuration pour n'autoriser que le séparateur `;` :

```json
"security": {
  "commandSeparators": [";"],
  "allowCommandChaining": true
}
```

2. Testez la configuration avec une commande simple :

```
echo Première commande ; echo Deuxième commande
```

3. Vérifiez que d'autres séparateurs comme `&&` ou `||` sont bien bloqués :

```
echo Test && echo Ceci ne devrait pas s'exécuter
```

## Audit et surveillance

### Journalisation

Activez la journalisation détaillée pour suivre toutes les commandes exécutées :

```json
"logging": {
  "level": "debug",
  "file": "win-cli-server.log"
}
```

### Historique des commandes

Conservez un historique des commandes pour pouvoir auditer les actions effectuées :

```json
"history": {
  "enabled": true,
  "maxEntries": 1000
}
```

### Revue régulière

- Examinez régulièrement les journaux et l'historique des commandes
- Recherchez des modèles d'utilisation suspects
- Mettez à jour la configuration de sécurité en fonction des résultats

## Gestion des incidents

### Détection

- Surveillez les comportements anormaux (commandes inhabituelles, volume élevé de commandes, etc.)
- Mettez en place des alertes pour les commandes sensibles

### Réponse

En cas de détection d'une utilisation suspecte :

1. Arrêtez immédiatement le serveur MCP Win-CLI
2. Analysez les journaux pour déterminer l'étendue de l'incident
3. Vérifiez l'intégrité du système
4. Renforcez la configuration de sécurité avant de redémarrer le serveur

## Liste de contrôle de sécurité

Utilisez cette liste pour vérifier régulièrement la sécurité de votre configuration :

- [ ] Les commandes autorisées sont limitées au strict nécessaire
- [ ] Les séparateurs de commande sont restreints (idéalement uniquement `;`)
- [ ] Le chaînage de commandes est correctement configuré
- [ ] Les connexions SSH utilisent des clés plutôt que des mots de passe
- [ ] La journalisation est activée et les journaux sont régulièrement examinés
- [ ] L'historique des commandes est activé et régulièrement examiné
- [ ] Le serveur s'exécute avec les privilèges minimaux nécessaires
- [ ] Les mises à jour de sécurité sont appliquées régulièrement

## Sécurité dans les modes personnalisés Roo

Lorsque vous utilisez le serveur MCP Win-CLI avec des modes personnalisés Roo, des considérations de sécurité supplémentaires s'appliquent.

### Contrôle d'accès par mode

Configurez les autorisations d'accès au MCP Win-CLI en fonction du mode Roo :

1. **Modes simples** : Limitez l'accès aux commandes de base et aux ressources directes uniquement
2. **Modes complexes** : Accordez un accès plus étendu, mais toujours avec des restrictions appropriées

Exemple de configuration dans le fichier `.roomodes` :

```json
{
  "slug": "code-simple",
  "name": "💻 Code Simple",
  "model": "anthropic/claude-3.5-sonnet",
  "roleDefinition": "You are Roo Code (version simple)...",
  "groups": ["read", "edit", "mcp"],
  "customInstructions": "Utilisez le MCP win-cli uniquement pour des commandes simples et non destructives..."
}
```

### Isolation des environnements

Pour les modes personnalisés qui utilisent le MCP Win-CLI :

1. **Créez des configurations spécifiques** pour chaque mode
2. **Utilisez des répertoires de travail dédiés** pour chaque type de mode
3. **Définissez des listes de commandes autorisées** spécifiques à chaque mode

### Bonnes pratiques pour les modes personnalisés

1. **Mode Code Simple** :
   - Limitez l'accès aux commandes de base (dir, ls, echo)
   - Désactivez les commandes de modification du système
   - Utilisez principalement les ressources directes

2. **Mode Debug Simple** :
   - Autorisez les commandes de diagnostic (Get-Process, netstat)
   - Limitez l'accès aux fichiers système
   - Désactivez les commandes de modification

3. **Mode Architect** :
   - Privilégiez l'accès en lecture seule
   - Limitez l'exécution de commandes aux outils de documentation
   - Utilisez des répertoires de travail isolés

4. **Mode Orchestrator** :
   - Configurez des permissions granulaires selon les sous-tâches
   - Utilisez un système de validation avant exécution
   - Implémentez des quotas d'utilisation

## Ressources supplémentaires

- [Documentation officielle de Win-CLI MCP](https://github.com/simonb97/server-win-cli)
- [Bonnes pratiques de sécurité pour PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/security/security-features)
- [Sécurité des commandes Windows](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/windows-commands-security)
- [Guide de sécurité pour les modes personnalisés Roo](../custom-modes/docs/securite.md)