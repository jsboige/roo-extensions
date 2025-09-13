# Rapport d'Escalade Technique : MCP Playwright

**Date :** 2025-09-09
**Auteur :** Roo Architect
**Statut :** Identification et analyse terminées

## 1. Description du Problème

Le MCP (Model Context Protocol) Playwright présente une instabilité de démarrage intermittente dans l'environnement Windows. Ce problème se manifeste par des échecs de lancement du serveur MCP, empêchant l'utilisation des fonctionnalités d'automatisation de navigateur.

L'erreur la plus fréquemment observée est `ERR_MODULE_NOT_FOUND`, indiquant que Node.js ne parvient pas à localiser le module Playwright nécessaire.

## 2. Analyse de la Cause Racine

L'enquête a révélé que la cause principale du problème réside dans la méthode de lancement actuelle du MCP Playwright, configurée dans `mcp_settings.json`.

**Configuration actuelle :**
```json
"playwright": {
  "command": "powershell",
  "args": [
    "-Command",
    "npx -y @playwright/mcp --browser firefox"
  ],
  ...
}
```

Le problème est directement lié à l'utilisation de `npx` sur Windows. `npx` est conçu pour exécuter des paquets Node.js sans les installer globalement. Cependant, son mécanisme de cache peut se corrompre, conduisant à des échecs où les paquets téléchargés sont incomplets ou inaccessibles.

L'utilisation d'un encapsuleur `powershell -Command` est un indicateur supplémentaire qu'il s'agit d'un contournement pour des problèmes d'exécution.

## 3. Solutions Proposées

### 3.1 Solution de Contournement (Court Terme)

Pour stabiliser l'environnement sans modifier la configuration de fond, une stratégie de "préchauffage" peut être implémentée. Elle consiste à forcer la mise à jour du cache `npx` avant le démarrage effectif du MCP.

**Action :** Exécuter la commande suivante dans les scripts de démarrage de l'environnement :
```powershell
npx -y @playwright/mcp --version
```
Cette commande a un faible coût et garantit que le paquet `@playwright/mcp` est correctement installé dans le cache `npx` avant son utilisation réelle par l'agent.

### 3.2 Solution Recommandée (Long Terme)

La solution la plus robuste et la plus fiable consiste à abandonner `npx` pour le lancement de Playwright et à utiliser une installation locale du paquet, comme recommandé dans la documentation interne.

**Étapes de mise en œuvre :**

1.  **Installer les paquets localement :**
    À la racine du projet `d:/dev/roo-extensions`, exécuter la commande :
    ```bash
    npm install @playwright/mcp playwright
    ```

2.  **Mettre à jour `mcp_settings.json` :**
    Modifier la configuration du serveur Playwright pour pointer directement sur le script exécutable du paquet local.

    **Nouvelle configuration :**
    ```json
    "playwright": {
      "command": "node",
      "args": [
        "D:/dev/roo-extensions/node_modules/@playwright/mcp/lib/cli.js",
        "--browser",
        "firefox"
      ],
      "transportType": "stdio",
      "disabled": false,
      "autoStart": true,
      "description": "MCP for browser automation with Playwright."
    }
    ```

## 4. Conclusion

Le problème d'instabilité du MCP Playwright est bien compris et des solutions claires ont été identifiées.

- À court terme, la **stratégie de préchauffage** peut être mise en place pour réduire la fréquence des pannes.
- À long terme, l'**adoption de l'installation locale** est fortement recommandée pour une stabilité et une fiabilité maximales de l'écosystème.

Cette escalade a pour but de notifier les développeurs et de planifier l'implémentation de la solution à long terme.