# Solution pour les modes simple/complex dans VS Code

## Problème identifié

Lors du déploiement des modes simple/complex dans VS Code, nous avons identifié plusieurs problèmes :

1. **Perte de la propriété `familyDefinitions`** : Cette propriété essentielle du validateur de famille de modes est perdue lors du déploiement, ce qui empêche la visibilité et le bon fonctionnement des modes simple/complex dans VS Code.

2. **Problèmes d'encodage** : Les emojis et les caractères accentués sont mal encodés, ce qui affecte l'affichage des noms des modes et des instructions personnalisées.

3. **Altération de la structure JSON** : L'utilisation de `ConvertFrom-Json` et `ConvertTo-Json` dans les scripts de déploiement altère la structure du JSON, causant la perte de certaines propriétés.

## Cause racine

La cause racine de ces problèmes est l'utilisation des cmdlets PowerShell `ConvertFrom-Json` et `ConvertTo-Json` dans le script de déploiement. Ces cmdlets :

- Ne préservent pas toujours la structure complète du JSON, notamment pour les propriétés imbriquées comme `familyDefinitions`
- Ne gèrent pas correctement l'encodage UTF-8 pour les caractères spéciaux comme les emojis et les caractères accentués
- Peuvent modifier la structure des données lors de la conversion entre JSON et objets PowerShell

## Solution

La solution consiste à éviter l'utilisation de `ConvertFrom-Json` et `ConvertTo-Json` et à traiter le fichier JSON comme du texte brut, en préservant son encodage UTF-8.

### Nouveau script de déploiement

Un nouveau script de déploiement (`deploy-modes-solution.ps1`) a été créé avec les améliorations suivantes :

1. **Préservation de la structure complète** : Le script lit et écrit le contenu JSON directement comme du texte, sans le convertir en objets PowerShell, ce qui préserve toutes les propriétés, y compris `familyDefinitions`.

2. **Encodage UTF-8 correct** : Le script utilise explicitement l'encodage UTF-8 sans BOM pour la lecture et l'écriture du fichier, ce qui préserve les emojis et les caractères accentués.

3. **Vérification de l'intégrité** : Le script vérifie que le fichier déployé contient bien la propriété `familyDefinitions` et que le JSON est valide.

### Script de diagnostic

Un script de diagnostic (`check-deployed-encoding.ps1`) a également été créé pour vérifier :

1. La présence de la propriété `familyDefinitions` dans le fichier déployé
2. L'encodage correct des emojis et des caractères accentués
3. La validité du JSON

## Étapes pour résoudre le problème

1. **Déployer les modes avec le nouveau script** :

   ```powershell
   # Déploiement global (pour toutes les instances de VS Code)
   .\roo-config\deployment-scripts\deploy-modes-solution.ps1 -DeploymentType global

   # OU déploiement local (pour le projet courant uniquement)
   .\roo-config\deployment-scripts\deploy-modes-solution.ps1 -DeploymentType local
   ```

2. **Vérifier le déploiement** :

   ```powershell
   .\roo-config\diagnostic-scripts\check-deployed-encoding.ps1
   ```

3. **Redémarrer VS Code** pour que les changements prennent effet.

4. **Vérifier que les modes sont correctement affichés** dans la palette de commandes (Ctrl+Shift+P) en tapant "Roo: Switch Mode".

## Prévention des problèmes futurs

Pour éviter que ces problèmes ne se reproduisent à l'avenir, voici quelques recommandations :

1. **Éviter l'utilisation de `ConvertFrom-Json` et `ConvertTo-Json`** pour les fichiers JSON contenant des structures complexes ou des caractères spéciaux.

2. **Utiliser systématiquement l'encodage UTF-8 sans BOM** pour les fichiers JSON, qui est le standard recommandé pour JSON.

3. **Vérifier l'intégrité des fichiers déployés** après chaque déploiement, en particulier la présence des propriétés essentielles comme `familyDefinitions`.

4. **Maintenir des sauvegardes** des fichiers de configuration avant toute modification.

## Détails techniques

### Propriété `familyDefinitions`

La propriété `familyDefinitions` est essentielle car elle définit les familles de modes et les modes qui appartiennent à chaque famille. Sans cette propriété, VS Code ne peut pas déterminer quels modes appartiennent aux familles "simple" et "complex", ce qui empêche leur affichage correct dans la palette de commandes.

Structure de la propriété `familyDefinitions` :

```json
"familyDefinitions": {
    "simple": [
        "code-simple",
        "debug-simple",
        "architect-simple",
        "ask-simple",
        "orchestrator-simple"
    ],
    "complex": [
        "code-complex",
        "debug-complex",
        "architect-complex",
        "ask-complex",
        "orchestrator-complex",
        "manager"
    ]
}
```

### Encodage UTF-8

L'encodage UTF-8 est essentiel pour préserver les caractères spéciaux comme les emojis (par exemple, "💻" pour le mode Code) et les caractères accentués (par exemple, "é" dans "complexité"). Sans un encodage correct, ces caractères sont mal affichés ou remplacés par des caractères de substitution.

Le script de déploiement utilise explicitement l'encodage UTF-8 sans BOM (Byte Order Mark) pour éviter les problèmes de compatibilité avec certains parseurs JSON.

```powershell
$utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($destinationFile, $jsonContent, $utf8NoBomEncoding)
```

## Conclusion

En suivant ces étapes et en utilisant les nouveaux scripts, les modes simple/complex devraient être correctement déployés et visibles dans VS Code, avec tous les emojis et caractères accentués correctement affichés.