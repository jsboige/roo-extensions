# Tests de l'équipe agentique

Ce répertoire contient les tests effectués pour valider la configuration de l'équipe agentique.

## Structure des tests

Les tests sont organisés par catégorie :

- **[Escalade](./escalade/)** : Tests du mécanisme d'escalade (code-simple vers code-complex)
- **[Désescalade](./desescalade/)** : Tests du mécanisme de désescalade (code-complex vers code-simple)
- **[MCP](./mcp/)** : Tests des MCPs et commandes PowerShell
- **[Orchestrateur](./orchestrateur/)** : Tests de l'orchestrateur complexe

## Rapports de tests

### Test d'escalade

Le [rapport de test d'escalade](./escalade/rapport-test-escalade.md) documente le test du mécanisme d'escalade du mode code-simple vers code-complex. Le test a confirmé que le mode code-simple détecte correctement les tâches complexes et demande une escalade vers le mode code-complex avec le format approprié.

**Fichiers associés :**
- [rapport-test-escalade.md](./escalade/rapport-test-escalade.md)
- [test-escalade-code.js](./escalade/test-escalade-code.js)

### Test de désescalade

Le [rapport de test de désescalade](./desescalade/rapport-test-desescalade.md) documente le test du mécanisme de désescalade du mode code-complex vers code-simple. Le test a confirmé que le mode code-complex détecte correctement les tâches simples et suggère une désescalade vers code-simple avec le format attendu.

**Fichiers associés :**
- [rapport-test-desescalade.md](./desescalade/rapport-test-desescalade.md)
- [test-desescalade-code.js](./desescalade/test-desescalade-code.js)

### Test des MCPs et commandes PowerShell

Le [rapport de test des MCPs](./mcp/rapport-test-mcp.md) documente les tests effectués pour vérifier l'implémentation correcte des fonctionnalités suivantes :
1. Utilisation des MCPs (Model Context Protocol)
2. Utilisation des commandes PowerShell avec la syntaxe appropriée

**Fichiers associés :**
- [rapport-test-mcp.md](./mcp/rapport-test-mcp.md)
- [test-mcp.js](./mcp/test-mcp.js)
- [test-mcp-powershell.ps1](./mcp/test-mcp-powershell.ps1)

### Test de l'orchestrateur complexe

Le [rapport de test de l'orchestrateur](./orchestrateur/rapport-test-orchestrateur.md) documente le comportement de l'orchestrateur complexe dans le cadre des tests réalisés pour évaluer ses capacités à gérer des tâches complexes nécessitant l'intervention de plusieurs modes spécialisés.

**Fichiers associés :**
- [rapport-test-orchestrateur.md](./orchestrateur/rapport-test-orchestrateur.md)
- [scenario-test-orchestrateur-complex.md](./orchestrateur/scenario-test-orchestrateur-complex.md)

## Rapport de synthèse global

Le [rapport de synthèse global](../rapport-synthese-global.md) présente une synthèse de tous les tests effectués, confirme que toutes les spécifications sont respectées, identifie d'éventuelles améliorations futures, et présente une vision d'ensemble de l'équipe agentique.

## Documentation de déploiement

La documentation de déploiement est disponible dans le répertoire [custom-modes/docs/implementation](../custom-modes/docs/implementation/) :

- [deploiement.md](../custom-modes/docs/implementation/deploiement.md) : Guide de déploiement standard
- [deploiement-autres-machines.md](../custom-modes/docs/implementation/deploiement-autres-machines.md) : Guide de déploiement pour d'autres machines, notamment celles avec des modèles locaux
- [script-deploy-local-endpoints.md](../custom-modes/docs/implementation/script-deploy-local-endpoints.md) : Script de déploiement pour les endpoints locaux

## Exécution des tests

Pour reproduire les tests, suivez les instructions spécifiques à chaque test dans les rapports correspondants.

### Exemple : Test des MCPs et commandes PowerShell

1. Exécutez le script PowerShell pour créer la structure de test :
   ```powershell
   .\tests\mcp\test-mcp-powershell.ps1
   ```

2. Vérifiez que la structure de répertoires et les fichiers ont été créés correctement :
   ```powershell
   Get-ChildItem -Path .\test-mcp-structure -Recurse
   ```

3. Exécutez le script JavaScript pour tester les MCPs :
   ```powershell
   node .\tests\mcp\test-mcp.js
   ```

4. Vérifiez les résultats dans la console.