# Tests d'Encodage Multi-Langages - Windows 11

## Objectif

Investigation systémique des problèmes d'encodage sur Windows 11 pour identifier précisément où et pourquoi les échecs se produisent.

## Méthodologie

1. **Scripts de test minimaux** pour chaque langage
2. **Scénarios de test** couvrant tous les cas d'usage
3. **Diagnostics complets** pour identifier les points de défaillance
4. **Analyse comparative** des patterns d'échec

## Langages Testés

- PowerShell 5.1 (Windows Legacy)
- PowerShell 7+ (Cross-platform)
- Python 3.x
- Node.js
- TypeScript (via ts-node)

## Scénarios de Test

1. Affichage direct d'emojis dans la console
2. Écriture d'emojis dans un fichier
3. Lecture d'emojis depuis un fichier
4. Passage d'emojis entre processus (pipe/redirection)
5. Encodage des variables d'environnement
6. Test de caractères accentués simples
7. Test d'emojis complexes

## Structure des Tests

```
tests/encoding/multi-language-encoding-tests/
├── README.md                    # Ce fichier
├── test-powershell51.ps1       # Tests PowerShell 5.1
├── test-powershell7.ps1         # Tests PowerShell 7+
├── test-python.py                # Tests Python
├── test-node.js                  # Tests Node.js
├── test-typescript.ts             # Tests TypeScript
├── run-all-tests.ps1             # Script d'exécution automatisée
├── test-data/                    # Données de test
│   ├── sample-utf8.txt
│   ├── sample-emojis.txt
│   └── sample-accented.txt
└── results/                      # Résultats des tests
    ├── encoding-test-report.json
    └── diagnostic-logs/
```

## Critères de Succès

- ✅ Affichage correct des emojis dans la console
- ✅ Écriture/lecture fidèle des emojis dans les fichiers
- ✅ Transmission correcte entre processus
- ✅ Préservation des caractères accentués
- ✅ Compatibilité avec l'option "UTF-8 worldwide language support"

## Points de Diagnostic Collectés

- Code page actif (`chcp`)
- Encodage de la console PowerShell
- Variables d'environnement liées à l'encodage
- Version des interpréteurs
- Résultat de chaque test (succès/échec + détails)
- Patterns d'échec spécifiques à chaque langage