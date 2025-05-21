# Sécurité du MCP Win-CLI

<!-- START_SECTION: introduction -->
## Introduction

Ce guide présente les bonnes pratiques de sécurité à suivre lors de l'utilisation du serveur MCP Win-CLI, qui permet à Roo d'exécuter des commandes sur votre système. La sécurité est un aspect crucial lors de l'utilisation d'un outil qui peut exécuter des commandes système, et ce document vous aidera à configurer et utiliser le MCP Win-CLI de manière sécurisée.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: security_risks -->
## Risques de sécurité

L'exécution de commandes système via un serveur MCP présente plusieurs risques de sécurité potentiels:

1. **Exécution de commandes dangereuses**: Suppression accidentelle de fichiers, modification de paramètres système critiques, etc.
2. **Injection de commandes**: Exécution de commandes malveillantes via des entrées non validées
3. **Élévation de privilèges**: Exécution de commandes avec des privilèges supérieurs à ceux nécessaires
4. **Fuite d'informations sensibles**: Exposition de données confidentielles via l'historique des commandes ou les journaux
5. **Accès non autorisé**: Utilisation du serveur par des tiers non autorisés

Il est essentiel de comprendre ces risques et de mettre en place des mesures pour les atténuer.
<!-- END_SECTION: security_risks -->

<!-- START_SECTION: general_best_practices -->
## Bonnes pratiques générales

### Principe du moindre privilège

- Exécutez le serveur MCP Win-CLI avec les privilèges minimaux nécessaires
- Évitez d'exécuter le serveur en tant qu'administrateur, sauf si absolument nécessaire
- Limitez les commandes autorisées au strict nécessaire
- Utilisez un compte utilisateur dédié avec des permissions limitées

### Isolation

- Exécutez le serveur dans un environnement isolé si possible
- Limitez l'accès aux fichiers et répertoires sensibles
- Utilisez des comptes utilisateurs dédiés pour l'exécution du serveur
- Considérez l'utilisation de conteneurs ou de machines virtuelles pour une isolation maximale

### Validation des entrées

- Validez toutes les entrées avant de les utiliser dans des commandes
- Méfiez-vous des caractères spéciaux et des séquences d'échappement
- Utilisez des listes blanches plutôt que des listes noires pour filtrer les entrées
- Échappez correctement les caractères spéciaux dans les commandes
<!-- END_SECTION: general_best_practices -->

<!-- START_SECTION: secure_configuration -->
## Configuration sécurisée

### Limitation des commandes autorisées

Configurez la liste des commandes autorisées dans le fichier de configuration:

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

Cette configuration:
- Autorise uniquement les commandes spécifiées dans `allowedCommands`
- Bloque explicitement les commandes dangereuses listées dans `blockedCommands`
- Réduit considérablement le risque d'exécution de commandes destructives

### Restriction des séparateurs de commande

Limitez les séparateurs de commande autorisés pour réduire les risques d'injection:

```json
"security": {
  "commandSeparators": [";"],
  "allowCommandChaining": true
}
```

Pour une sécurité maximale, vous pouvez désactiver complètement le chaînage de commandes:

```json
"security": {
  "commandSeparators": [],
  "allowCommandChaining": false
}
```

### Sécurisation des connexions SSH

Si vous utilisez des connexions SSH:

- Utilisez des clés SSH plutôt que des mots de passe
- Stockez les clés privées dans un emplacement sécurisé
- Utilisez des phrases de passe pour protéger les clés privées
- Limitez les hôtes auxquels vous pouvez vous connecter

Exemple de configuration SSH sécurisée:

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

### Configuration des journaux

Configurez la journalisation pour équilibrer la sécurité et la capacité d'audit:

```json
"logging": {
  "level": "info",
  "file": "win-cli-server.log",
  "rotation": {
    "maxSize": "10m",
    "maxFiles": 5
  },
  "sanitize": true
}
```

L'option `sanitize` (si disponible) permet de masquer les informations sensibles dans les journaux.
<!-- END_SECTION: secure_configuration -->

<!-- START_SECTION: command_separators -->
## Personnalisation des séparateurs de commande

La personnalisation des séparateurs de commande est importante pour l'utilisation avec Roo. Voici comment configurer spécifiquement le séparateur `;`:

1. Modifiez le fichier de configuration pour n'autoriser que le séparateur `;`:

```json
"security": {
  "commandSeparators": [";"],
  "allowCommandChaining": true
}
```

2. Testez la configuration avec une commande simple:

```
echo Première commande ; echo Deuxième commande
```

3. Vérifiez que d'autres séparateurs comme `&&` ou `||` sont bien bloqués:

```
echo Test && echo Ceci ne devrait pas s'exécuter
```

### Implications de sécurité des différents séparateurs

| Séparateur | Description | Risque de sécurité |
|------------|-------------|-------------------|
| `;` | Exécute les commandes séquentiellement | Modéré - Permet l'exécution de plusieurs commandes |
| `&&` | Exécute la commande suivante si la précédente réussit | Modéré - Permet l'exécution conditionnelle |
| `\|\|` | Exécute la commande suivante si la précédente échoue | Modéré - Permet l'exécution conditionnelle |
| `\|` | Redirige la sortie vers la commande suivante | Élevé - Permet des chaînes de commandes complexes |
| `&` | Exécute la commande en arrière-plan | Élevé - Permet l'exécution en arrière-plan |

Pour une sécurité optimale, n'autorisez que le séparateur `;` ou désactivez complètement le chaînage de commandes.
<!-- END_SECTION: command_separators -->

<!-- START_SECTION: roo_security -->
## Sécurisation spécifique pour Roo

### Limitation des opérations dangereuses

Configurez Roo pour qu'il demande confirmation avant d'exécuter des commandes potentiellement dangereuses:

1. Identifiez les commandes à risque (suppression, modification de fichiers système, etc.)
2. Configurez des règles de validation dans vos prompts système
3. Demandez à Roo d'expliquer les commandes qu'il souhaite exécuter

### Séparation des environnements

- Utilisez des environnements distincts pour le développement et la production
- Créez des configurations spécifiques pour chaque environnement
- Limitez les commandes disponibles en fonction de l'environnement

### Configuration de l'approbation automatique

Dans la configuration MCP de Roo, évitez d'ajouter `execute_command` à la liste `autoApprove`:

```json
{
  "mcpServers": {
    "win-cli": {
      "autoApprove": [],  // Ne pas inclure "execute_command" ici
      "alwaysAllow": [
        "execute_command",
        "get_command_history",
        "ssh_execute",
        "ssh_disconnect",
        "create_ssh_connection",
        "read_ssh_connections",
        "update_ssh_connection",
        "delete_ssh_connection",
        "get_current_directory"
      ],
      "command": "cmd",
      "args": ["/c", "npx", "-y", "@simonb97/server-win-cli"],
      "transportType": "stdio",
      "disabled": false
    }
  }
}
```

Cela garantit que Roo demandera toujours confirmation avant d'exécuter des commandes système.
<!-- END_SECTION: roo_security -->

<!-- START_SECTION: audit_monitoring -->
## Audit et surveillance

### Journalisation

Activez la journalisation détaillée pour suivre toutes les commandes exécutées:

```json
"logging": {
  "level": "debug",
  "file": "win-cli-server.log"
}
```

### Historique des commandes

Conservez un historique des commandes pour pouvoir auditer les actions effectuées:

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

### Outils d'audit

Utilisez des outils d'audit pour analyser les journaux et détecter les activités suspectes:

1. **PowerShell Script Analyzer** pour vérifier les scripts PowerShell
2. **Windows Event Log** pour surveiller les activités système
3. **Outils d'analyse de journaux** pour détecter les modèles suspects
<!-- END_SECTION: audit_monitoring -->

<!-- START_SECTION: incident_management -->
## Gestion des incidents

### Détection

- Surveillez les comportements anormaux (commandes inhabituelles, volume élevé de commandes, etc.)
- Mettez en place des alertes pour les commandes sensibles
- Utilisez des outils de détection d'intrusion si possible

### Réponse

En cas de détection d'une utilisation suspecte:

1. Arrêtez immédiatement le serveur MCP Win-CLI
2. Analysez les journaux pour déterminer l'étendue de l'incident
3. Vérifiez l'intégrité du système
4. Renforcez la configuration de sécurité avant de redémarrer le serveur

### Plan de récupération

Préparez un plan de récupération en cas d'incident:

1. Sauvegardez régulièrement les configurations et les données importantes
2. Documentez les procédures de restauration
3. Testez régulièrement le plan de récupération
<!-- END_SECTION: incident_management -->

<!-- START_SECTION: security_checklist -->
## Liste de contrôle de sécurité

Utilisez cette liste pour vérifier régulièrement la sécurité de votre configuration:

- [ ] Les commandes autorisées sont limitées au strict nécessaire
- [ ] Les séparateurs de commande sont restreints (idéalement uniquement `;`)
- [ ] Le chaînage de commandes est correctement configuré
- [ ] Les connexions SSH utilisent des clés plutôt que des mots de passe
- [ ] La journalisation est activée et les journaux sont régulièrement examinés
- [ ] L'historique des commandes est activé et régulièrement examiné
- [ ] Le serveur s'exécute avec les privilèges minimaux nécessaires
- [ ] Les mises à jour de sécurité sont appliquées régulièrement
- [ ] Les fichiers de configuration sont protégés contre les accès non autorisés
- [ ] Les informations d'identification sensibles sont stockées de manière sécurisée
<!-- END_SECTION: security_checklist -->

<!-- START_SECTION: updates_maintenance -->
## Mises à jour et maintenance

### Mises à jour régulières

- Maintenez le MCP Win-CLI à jour pour bénéficier des dernières corrections de sécurité
- Vérifiez régulièrement les nouvelles versions:
  ```bash
  npm outdated -g @simonb97/server-win-cli
  ```
- Mettez à jour le package lorsqu'une nouvelle version est disponible:
  ```bash
  npm update -g @simonb97/server-win-cli
  ```

### Maintenance de la configuration

- Revoyez régulièrement votre configuration de sécurité
- Ajustez les listes de commandes autorisées et bloquées en fonction de vos besoins
- Mettez à jour les connexions SSH et supprimez celles qui ne sont plus nécessaires
<!-- END_SECTION: updates_maintenance -->

<!-- START_SECTION: resources -->
## Ressources supplémentaires

- [Documentation officielle de Win-CLI MCP](https://github.com/simonb97/server-win-cli)
- [Bonnes pratiques de sécurité pour PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/security/security-features)
- [Sécurité des commandes Windows](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/windows-commands-security)
- [Guide de sécurité SSH](https://www.ssh.com/academy/ssh/security)
- [OWASP Command Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html)
<!-- END_SECTION: resources -->