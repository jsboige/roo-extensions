# Protocole d'Ajustement des Modes Simple/Complex

## Resultats Forensiques (200 taches, 20 jan - 8 fev 2026)

### Distribution de Complexite

| Categorie | Taches | % | Tokens out (avg) | Mode cible |
|-----------|--------|---|------------------|------------|
| Tiny (1-2 reqs) | 7 | 3.5% | 188 | simple |
| Small (3-10 reqs) | 135 | 67.5% | 2,870 | simple |
| Medium (11-50 reqs) | 45 | 22.5% | 10,364 | simple ou complex |
| Large (51-200 reqs) | 11 | 5.5% | 49,383 | complex |
| Huge (>200 reqs) | 2 | 1% | 441,135 | orchestrator-complex |

**Conclusion** : ~71% des taches sont parfaitement adaptees aux modes simples (GLM 4.7 Flash).

### Tokens Observes

| Metrique | Code mode | General |
|----------|-----------|---------|
| tok_out p50 | 3,718 | 2,605 |
| tok_out p90 | 16,617 | 12,826 |
| tok_out max | 107,327 | 630,862 |
| tok_in p50 | 350,494 | 207,778 |
| tok_in p90 | 1,474,878 | 2,450,316 |

### Patterns Observes

- **switch_mode** : JAMAIS utilise (0/200 taches) -> L'escalade par signal textuel est adaptee
- **new_task** : 552 usages dans seulement 5 taches (orchestrateur exclusivement)
- **Condensation contexte** : 22/200 taches (11%) atteignent la limite
- **Pire cas** : 21 condensations, 55M tok_in, 761 requetes API, 343 sous-taches
- **Outils principaux** : update_todo_list, read_file, execute_command, apply_diff, attempt_completion

### Validation des Seuils

| Seuil | Valeur | Justification forensique |
|-------|--------|--------------------------|
| Simple alert | 40K tok | p90 code = 16K, laisse de la marge |
| Simple escalade | 50K tok | Au-dela de p90 = complexite probable |
| Simple critique | 100K tok | Seules 2 taches depassent ce seuil |
| Complex checkpoint | 50K tok | Point de reflexion avant engagement |
| Complex alert | 80K tok | Depassement = orchestration necessaire |
| Complex escalade | 100K tok | Bascule orchestrateur |
| Complex critique | 150K tok | Division immediate |

**Verdict** : Les seuils sont bien calibres par rapport aux donnees reelles.

---

## Protocole d'Ajustement

### Etape 1 : Deploiement Initial (FAIT)

1. Generer les modes : `node roo-config/scripts/generate-modes.js`
2. Deployer : `.\roo-config\scripts\Deploy-Modes.ps1`
3. Recharger VS Code

### Etape 2 : Tests Manuels (A FAIRE)

Tester chaque famille dans les deux niveaux :

#### Test 1 : code-simple (tache triviale)
- **Prompt** : "Ajoute un commentaire JSDoc a la fonction X dans fichier Y"
- **Criteres** : Complete sans escalade, tok_out < 5K
- **Verifier** : Pas de tentative d'escalade sur tache simple

#### Test 2 : code-simple (tache depassant les limites)
- **Prompt** : "Refactorise le module Z pour utiliser le pattern Strategy"
- **Criteres** : Detecte la complexite, signale [ESCALADE REQUISE]
- **Verifier** : Message d'escalade clair et actionnable

#### Test 3 : code-complex (tache complexe)
- **Prompt** : "Implemente la consolidation du module X (multi-fichiers, archi)"
- **Criteres** : Gere la complexite, delegue sous-taches simples
- **Verifier** : Cree des new_task vers modes simples pour finalisation

#### Test 4 : code-complex (tache simple)
- **Prompt** : "Corrige le typo dans ce fichier"
- **Criteres** : Detecte la simplicite, suggere [DESESCALADE SUGGEREE]
- **Verifier** : Signal de desescalade present

#### Test 5 : orchestrator-simple
- **Prompt** : "Deploie la config sur toutes les machines"
- **Criteres** : Decompose en sous-taches simples (max 10)

#### Test 6 : orchestrator-complex (orchestration multi-etapes)
- **Prompt** : "Consolide tout le module RooSync"
- **Criteres** : Gere dependances, parallelise, delegue

### Etape 3 : Ajustements Post-Tests

#### Si escalade trop frequente (faux positifs)
- **Action** : Augmenter maxLines (100 -> 150) et maxFiles (5 -> 8) dans FAMILIES
- **Fichier** : `roo-config/scripts/generate-modes.js` (section FAMILIES)
- **Puis** : Regenerer et redeployer

#### Si escalade insuffisante (faux negatifs)
- **Action** : Reduire seuils ou ajouter criteres d'escalade
- **Fichier** : `roo-config/scripts/generate-modes.js` (escalationCriteria)
- **Puis** : Regenerer et redeployer

#### Si tokens depassent les seuils
- **Action** : Ajuster LEVEL_DEFAULTS dans le generateur
- **Fichier** : `roo-config/scripts/generate-modes.js` (LEVEL_DEFAULTS)
- **Puis** : Regenerer et redeployer

#### Si desescalade ignoree
- **Action** : Renforcer les criteres dans deescalationCriteria
- **Ou** : Ajouter rappel explicite dans les templates

### Etape 4 : Monitoring Continu

Relancer l'analyse forensique regulierement :
```bash
node roo-config/scripts/analyze-tasks.js 100
```

Metriques a surveiller :
- % taches simples vs complexes (cible : 70/30)
- Frequence des signaux d'escalade
- Frequence des condensations de contexte
- Cout moyen par famille/niveau

---

## Workflow de Modification

```
1. Editer roo-config/scripts/generate-modes.js
   - Modifier FAMILIES, LEVEL_DEFAULTS, ou templates
2. node roo-config/scripts/generate-modes.js
3. .\roo-config\scripts\Deploy-Modes.ps1
4. Recharger VS Code (Ctrl+Shift+P > Reload Window)
5. Tester le mode modifie
6. Si OK : commit + deployer aux autres machines
```

## Fichiers Cles

| Fichier | Role |
|---------|------|
| `roo-config/scripts/generate-modes.js` | Generateur (config + engine) |
| `roo-config/scripts/Deploy-Modes.ps1` | Deploiement local/global |
| `roo-config/scripts/analyze-tasks.js` | Analyse forensique |
| `roo-config/modes/generated/simple-complex.roomodes` | Sortie generee |
| `roo-config/modes/templates/commons/` | Templates partages |
| `roo-config/model-configs.json` | Routage API modeles |
| `.roomodes` | Fichier deploye (workspace root) |
