# 🔧 Factorisation Massive - Architecture Validée Post-Investigation 3.2

**Version :** 2.0.0  
**Date :** 2 Octobre 2025  
**Architecture :** 3-Niveaux (Global → Family → Mode)  
**Statut :** ✅ **Validée par Investigation 3.2**  
**Objectif :** Éliminer 71% redondances (~37k caractères)

---

## 🎯 Objectif de la Factorisation

La factorisation massive permet de :
1. **Réduire duplication** : 85% instructions communes identifiées
2. **Faciliter maintenance** : Modifications uniques propagées automatiquement
3. **Garantir cohérence** : Mêmes règles appliquées uniformément
4. **Optimiser tokens** : Instructions compactes et efficaces

**Gains mesurables** :
- **Avant** : ~4.3k caractères par mode × 12 modes = ~52k caractères
- **Après** : ~15k caractères sources uniques (~71% économie)
- **Maintenance** : -83% temps modification (30min → 5min)

---

## 📊 Métriques Factorisation Attendues

### Économie Maintenance
- **Avant** : Modifier 12 fichiers JSON pour instruction commune (temps: ~30min)
- **Après** : Modifier 1 template → régénérer (temps: ~5min)
- **Gain** : -83% temps maintenance

### Réduction Redondances
- **custom_modes.json actuel** : ~52k caractères (85% redondance)
- **Templates factorisés** : ~15k caractères uniques
- **Économie** : -71% taille source (37k caractères)

### Cohérence Garantie
- **Risque incohérence** : ÉLEVÉ → NÉGLIGEABLE
- **Instructions communes** : 1 source de vérité
- **Propagation automatique** : 100% modes synchronisés

### Maintenance Annuelle Estimée
- **Avant** : ~20h/an modifications manuelles
- **Après** : ~4h/an templates + régénération
- **ROI** : -80% effort maintenance

---

## 🏗️ Architecture Finale Validée

**Investigation 3.2 complétée** : Structure et stratégie confirmées

### ✅ Option C : Script d'Assemblage (RETENUE)

**Raisons validation** :
- ✅ Compatible format JSON Roo-Code (string `customInstructions`)
- ✅ Maintenabilité maximale (templates séparés)
- ✅ Automatisable (CI/CD + pre-commit)
- ✅ Évolutif (ajout modes/familles simple)
- ✅ Sans risque (validation avant déploiement)

**Contrainte critique découverte** :  
`customInstructions` = STRING monolithique (~4-5k caractères)  
→ Factorisation DOIT être côté build, pas runtime

### ❌ Options Non Viables (Investigation 3.2)

**Option A : Références Markdown** ❌
- Format TypeScript Roo-Code : `customInstructions?: string` (STRING monolithique)
- Liens Markdown [`fichier.md`](path) : Documentation humaine uniquement
- **Conclusion** : Pas d'inclusion automatique côté Roo-Code

**Option B : Champs JSON Dédiés** ❌
- Schema TypeScript : Pas de champs `commonInstructions`, `familyInstructions`
- Structure figée : `slug`, `name`, `roleDefinition`, `customInstructions`, `groups`
- **Conclusion** : Incompatible avec architecture TypeScript Roo-Code

---

## 📂 Structure Fichiers Validée

**Basée sur investigation 3.2** (analyse [`roo-config/modes/standard-modes.json`](../modes/standard-modes.json))

```
roo-config/modes/
├── standard-modes.json              # ← GÉNÉRÉ (ne pas éditer)
│                                     # ← Commentaire en-tête avertissement
└── templates/                       # ← Sources de vérité
    ├── commons/
    │   ├── global-instructions.md   # 12/12 modes (~3k lignes)
    │   └── families/
    │       ├── code-family.md       # Template CODE (4 niveaux)
    │       ├── debug-family.md      # Template DEBUG
    │       ├── architect-family.md  # Template ARCHITECT
    │       ├── ask-family.md        # Template ASK
    │       └── orchestrator-family.md # Template ORCHESTRATOR
    └── modes/
        ├── code-micro-specific.md   # <5% contenu spécifique
        ├── code-mini-specific.md
        ├── code-medium-specific.md
        ├── code-oracle-specific.md
        ├── debug-micro-specific.md
        ├── debug-mini-specific.md
        ├── debug-medium-specific.md
        ├── debug-oracle-specific.md
        ├── architect-simple-specific.md
        ├── architect-complex-specific.md
        ├── ask-simple-specific.md
        └── ask-complex-specific.md

scripts/
└── generate-modes.js                # Script assemblage Node.js
```

### Hiérarchie 3-Niveaux

```
┌─────────────────────────────────────────────────┐
│ NIVEAU 1 : INSTRUCTIONS GLOBALES               │
│ • Protocole SDDD complet                       │
│ • Règles système universelles                  │
│ • Intégrations MCP de base                     │
│ • Référencées par TOUS les modes (12/12)       │
│ Source : commons/global-instructions.md        │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ NIVEAU 2 : INSTRUCTIONS FAMILLE                │
│ • Mécaniques escalade spécifiques famille      │
│ • Focus areas par niveau (Micro/Mini/Medium)   │
│ • Critères spécifiques métier                  │
│ • Partagées par modes de même famille          │
│ Source : commons/families/{family}-family.md   │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ NIVEAU 3 : INSTRUCTIONS MODE                   │
│ • Spécificités uniques du mode                 │
│ • Exemples concrets propres au mode            │
│ • Edge cases particuliers                      │
│ • <5% du contenu total                         │
│ Source : modes/{mode-slug}-specific.md         │
└─────────────────────────────────────────────────┘
```

---

## ⚠️ Contraintes Techniques (Investigation 3.2)

### Point Critique : STRING Monolithique

**Découverte investigation 3.2** :
```typescript
// Format TypeScript Roo-Code (standard-modes.json)
customModes?: {
  slug: string
  name: string
  roleDefinition: string
  customInstructions?: string  // ← STRING monolithique (~4-5k caractères)
  groups: Array
  source?: "global" | "project"
}[]
```

**Implications** :
- ❌ Pas de références `{{INCLUDE}}` côté Roo-Code
- ❌ Pas de parser template côté runtime
- ❌ Pas de champs composables JSON
- ✅ **Solution** : Génération complète côté build (script Node.js)

### Format TypeScript Roo-Code

**Champs disponibles** :
- `slug` : Identifiant mode (ex: "code-micro")
- `name` : Nom affiché (ex: "💻 Code Micro")
- `roleDefinition` : Description courte mode
- `customInstructions` : STRING monolithique complet
- `groups` : Groupes de modes (ex: ["code"])
- `source` : "global" ou "project"

### Options Non Viables

- ❌ **Champs dédiés JSON** : Incompatibles schema TypeScript
- ❌ **Références `{{}}`** : Pas de parser côté Roo-Code
- ⚠️ **Liens Markdown** : Non inclus automatiquement (doc humaine)

### Option Viable Confirmée

- ✅ **Script assemblage** : Génération pre-déploiement
- ✅ **Format compatible** : STRING complet généré
- ✅ **Validation** : Tests avant commit

---

## 🔄 Script generate-modes.js

**Fichier** : [`scripts/generate-modes.js`](../../scripts/generate-modes.js)

### Configuration Modes

```javascript
/**
 * Configuration des modes avec variables de templating
 * Basé sur investigation 3.2 : structure 4 niveaux CODE validée
 */
const MODES_CONFIG = [
  // Famille CODE - 4 niveaux
  {
    slug: 'code-micro',
    name: '💻 Code Micro',
    family: 'code',
    level: 'micro',
    variables: {
      LEVEL: 'micro',
      MAX_LINES: 10,
      MAX_FILES: 1,
      LEVEL_NEXT: 'mini',
      MODE_NEXT: 'code-mini',
      FOCUS_AREAS: [
        'Corrections bugs évidents (typos, imports)',
        'Modifications isolées < 10 lignes',
        'Formatting automatisé',
        'Documentation JSDoc simple'
      ]
    }
  },
  {
    slug: 'code-mini',
    name: '💻 Code Mini',
    family: 'code',
    level: 'mini',
    variables: {
      LEVEL: 'mini',
      MAX_LINES: 50,
      MAX_FILES: 3,
      LEVEL_NEXT: 'medium',
      MODE_NEXT: 'code-medium',
      FOCUS_AREAS: [
        'Modifications < 50 lignes',
        'Fonctions isolées',
        'Tests unitaires basiques',
        'Refactoring simple'
      ]
    }
  },
  {
    slug: 'code-medium',
    name: '💻 Code Medium',
    family: 'code',
    level: 'medium',
    variables: {
      LEVEL: 'medium',
      MAX_LINES: 200,
      MAX_FILES: 10,
      LEVEL_NEXT: 'oracle',
      MODE_NEXT: 'code-oracle',
      FOCUS_AREAS: [
        'Refactorisations architecture',
        'Modifications multi-fichiers (< 10 fichiers)',
        'Patterns avancés',
        'Optimisations performance'
      ]
    }
  },
  {
    slug: 'code-oracle',
    name: '🧙 Code Oracle',
    family: 'code',
    level: 'oracle',
    variables: {
      LEVEL: 'oracle',
      MAX_LINES: Infinity,
      MAX_FILES: Infinity,
      LEVEL_NEXT: null,
      MODE_NEXT: null,
      FOCUS_AREAS: [
        'Refactorisations majeures',
        'Conception architecture',
        'Systèmes interdépendants',
        'Algorithmes complexes'
      ]
    }
  },
  // ... autres familles (DEBUG, ARCHITECT, ASK)
];
```

### Génération Mode

```javascript
/**
 * Génère les instructions complètes pour un mode
 * @param {Object} modeConfig - Configuration du mode
 * @returns {Object} - Mode complet au format Roo-Code
 */
function generateMode(modeConfig) {
  // 1. Charger instructions globales (12/12 modes)
  const globalInstructions = loadTemplate('commons/global-instructions.md');
  
  // 2. Charger template famille
  const familyTemplate = loadTemplate(`commons/families/${modeConfig.family}-family.md`);
  
  // 3. Charger instructions spécifiques mode
  const specificInstructions = loadTemplate(`modes/${modeConfig.slug}-specific.md`);
  
  // 4. Rendre template famille avec variables
  const familyInstructions = renderTemplate(familyTemplate, modeConfig.variables);
  
  // 5. Assembler instructions complètes (STRING monolithique)
  const customInstructions = [
    '# INSTRUCTIONS GLOBALES\n',
    globalInstructions,
    '\n\n# INSTRUCTIONS FAMILLE\n',
    familyInstructions,
    '\n\n# INSTRUCTIONS SPÉCIFIQUES\n',
    specificInstructions
  ].join('');
  
  // 6. Retourner mode au format Roo-Code TypeScript
  return {
    slug: modeConfig.slug,
    name: modeConfig.name,
    roleDefinition: generateRoleDefinition(modeConfig),
    customInstructions: customInstructions.trim(), // STRING monolithique
    groups: [modeConfig.family],
    source: "project"
  };
}
```

### Rendu Templates avec Variables

```javascript
/**
 * Rend un template avec remplacement de variables
 * @param {string} template - Template source
 * @param {Object} variables - Variables à substituer
 * @returns {string} - Template rendu
 */
function renderTemplate(template, variables) {
  let result = template;
  
  // 1. Remplacement variables simples {{VAR}}
  Object.keys(variables).forEach(key => {
    const regex = new RegExp(`{{${key}}}`, 'g');
    const value = variables[key];
    
    // Gestion types (string, number, array)
    if (Array.isArray(value)) {
      result = result.replace(regex, value.map(v => `- ${v}`).join('\n'));
    } else {
      result = result.replace(regex, String(value));
    }
  });
  
  // 2. Traitement conditions {{#if LEVEL == "micro"}}
  result = processConditionals(result, variables);
  
  return result;
}

/**
 * Traite les conditions dans templates
 * @param {string} template - Template avec conditions
 * @param {Object} variables - Variables pour évaluation
 * @returns {string} - Template avec conditions résolues
 */
function processConditionals(template, variables) {
  // Pattern: {{#if CONDITION}} content {{else}} other {{/if}}
  const ifPattern = /{{#if\s+(.+?)}}([\s\S]*?)(?:{{else}}([\s\S]*?))?{{\/if}}/g;
  
  return template.replace(ifPattern, (match, condition, thenBlock, elseBlock) => {
    // Évaluation condition simple
    const result = evaluateCondition(condition, variables);
    return result ? thenBlock : (elseBlock || '');
  });
}
```

### Validation et Génération

```javascript
/**
 * Point d'entrée : génère tous les modes
 */
function generateAllModes() {
  console.log('🏗️ Génération modes à partir des templates...\n');
  
  const generatedModes = MODES_CONFIG.map(config => {
    console.log(`  ✓ Génération ${config.slug}...`);
    return generateMode(config);
  });
  
  // Validation format
  generatedModes.forEach(mode => {
    validateModeFormat(mode);
  });
  
  // Génération fichier final avec avertissement
  const output = {
    $schema: "./modes-schema.json",
    _warning: "⚠️ FICHIER GÉNÉRÉ - NE PAS ÉDITER MANUELLEMENT",
    _source: "Généré par scripts/generate-modes.js depuis templates/",
    _lastGenerated: new Date().toISOString(),
    customModes: generatedModes
  };
  
  // Écriture standard-modes.json
  fs.writeFileSync(
    'roo-config/modes/standard-modes.json',
    JSON.stringify(output, null, 2)
  );
  
  console.log('\n✅ Génération complète : 12 modes générés');
  console.log(`📊 Taille totale : ${JSON.stringify(output).length} caractères`);
}
```

---

## 📋 Contenu Sections Communes

### Section 1 : Protocole SDDD (12/12 modes)

**Localisation** : [`roo-config/modes/templates/commons/global-instructions.md`](../modes/templates/commons/global-instructions.md)

**Contenu factorisé** (extrait) :
```markdown
## PROTOCOLE SDDD OBLIGATOIRE

Référence complète : [`sddd-protocol-4-niveaux.md`](../../specifications/sddd-protocol-4-niveaux.md)

### Phase 1 : Grounding Initial
1. **Recherche sémantique OBLIGATOIRE** : `codebase_search` AVANT toute exploration
2. **Fallback quickfiles** : Si résultats insuffisants
3. **Contexte historique** : `roo-state-manager` pour reprises

### Phase 2 : Documentation Continue
- Checkpoint tous les 50k tokens avec résumé actions
- Mise à jour todo lists si mode orchestrateur
- Documentation décisions architecturales

### Phase 3 : Validation Finale
- Checkpoint sémantique final AVANT attempt_completion
- Création rapport si tâche complexe (>2h ou >10 fichiers)
```

### Section 2 : Mécaniques Escalade (10/12 modes)

**Localisation** : [`roo-config/modes/templates/commons/global-instructions.md`](../modes/templates/commons/global-instructions.md)

**Contenu factorisé** (extrait) :
```markdown
## MÉCANIQUES D'ESCALADE

Référence complète : [`escalade-mechanisms-revised.md`](../../specifications/escalade-mechanisms-revised.md)

### Seuils Universels
- Contexte > 50k tokens → Escalade externe OBLIGATOIRE
- Contexte > 100k tokens → Mode orchestration OBLIGATOIRE

### Format Standardisé Escalade Externe
```xml
<switch_mode>
<mode_slug>{{MODE_NEXT}}</mode_slug>
<reason>[ESCALADE EXTERNE] {{RAISON_DÉTAILLÉE}}</reason>
</switch_mode>
```
```

### Section 3 : Hiérarchie Numérotée (Modes orchestrateurs)

**Localisation** : [`roo-config/modes/templates/commons/global-instructions.md`](../modes/templates/commons/global-instructions.md)

**Contenu factorisé** (extrait) :
```markdown
## HIÉRARCHIE NUMÉROTÉE SYSTÉMATIQUE

Référence complète : [`hierarchie-numerotee-subtasks.md`](../../specifications/hierarchie-numerotee-subtasks.md)

### Format Standard
- Tâche principale : X
- Sous-tâches niveau 1 : X.1, X.2, X.3
- Sous-tâches niveau 2 : X.Y.1, X.Y.2

### Template new_task()
```xml
<new_task>
<mode>{{MODE_APPROPRIÉ}}</mode>
<message>🎯 **Sous-tâche {{NUMERO}} : {{TITRE}}**

**Contexte hérité** : {{CONTEXTE_PARENT}}
**Objectif spécifique** : {{OBJECTIF_PRÉCIS}}
**Livrables attendus** : {{LISTE_LIVRABLES}}
</message>
</new_task>
```
```

### Section 4 : Intégrations MCP (12/12 modes)

**Localisation** : [`roo-config/modes/templates/commons/global-instructions.md`](../modes/templates/commons/global-instructions.md)

**Contenu factorisé** (extrait) :
```markdown
## INTÉGRATIONS MCP PRIORITAIRES

Référence complète : [`mcp-integrations-priority.md`](../../specifications/mcp-integrations-priority.md)

### Tier 1 : Utilisation Systématique
- **roo-state-manager** : Grounding conversationnel obligatoire
- **quickfiles** : Privilégier pour batch (>2 fichiers)

### Tier 2 : Future Intégration
- **github-projects** : Synchronisation roadmap (Phase 2.2+)

### Tier 3 : Cas Spécifiques
- **jinavigator** : Documentation web
- **searxng** : Veille technique
- **playwright** : Tests UI
```

---

## 🎨 Template Famille CODE (Exemple)

**Fichier** : [`roo-config/modes/templates/commons/families/code-family.md`](../modes/templates/commons/families/code-family.md)

```markdown
# Template Famille CODE - Niveau {{LEVEL}}

## FOCUS AREAS NIVEAU {{LEVEL}}

### Capacités Principales
{{FOCUS_AREAS}}

### Limites Niveau
- Modifications maximales : {{MAX_LINES}} lignes
- Fichiers simultanés : {{MAX_FILES}} fichiers

## MÉCANISMES D'ESCALADE FAMILLE CODE

### Escalade vers Niveau Supérieur
**Critères obligatoires** :
- Modifications > {{MAX_LINES}} lignes
- Fichiers > {{MAX_FILES}}
- Refactorisations architecture
- Systèmes interdépendants

**Format** :
```xml
<switch_mode>
<mode_slug>{{MODE_NEXT}}</mode_slug>
<reason>[ESCALADE EXTERNE] Raison : {{DÉTAILS}}</reason>
</switch_mode>
```

{{#if LEVEL != "oracle"}}
### Niveau Supérieur Disponible
- Mode suivant : {{MODE_NEXT}}
- Capacités étendues : Oui
{{else}}
### Niveau Maximum
- Aucune escalade : Niveau Oracle (capacités illimitées)
{{/if}}

## PATTERNS SPÉCIFIQUES CODE

### Exploration Code
1. `codebase_search` : patterns architecture
2. `roo-state-manager search_tasks` : décisions historiques
3. `quickfiles read_multiple_files` : modules liés

### Refactoring
1. `quickfiles search_in_files` : identifier usages
2. Analyse impacts et conception
3. `quickfiles edit_multiple_files` : application coordonnée
4. Tests validation
```

---

## 🚀 Plan d'Implémentation Détaillé

### Phase 1 : Setup Infrastructure (1-2h)

**Objectif** : Créer l'infrastructure de génération

1. **Créer structure templates** :
   ```bash
   mkdir -p roo-config/modes/templates/commons/families
   mkdir -p roo-config/modes/templates/modes
   ```

2. **Développer script de base** :
   - Créer [`scripts/generate-modes.js`](../../scripts/generate-modes.js)
   - Implémenter chargement templates
   - Implémenter remplacement variables simples

3. **Point critique** : Gestion STRING monolithique `customInstructions`
   - Assemblage complet en mémoire
   - Validation format JSON final
   - Pas de références runtime

4. **Tester génération 1 mode pilote** (code-micro) :
   - Créer template minimal famille CODE
   - Créer instructions spécifiques code-micro
   - Générer et valider format JSON

5. **Valider format compatible Roo-Code TypeScript** :
   - Charger dans VS Code
   - Vérifier reconnaissance mode
   - Tester customInstructions effectifs

**Livrables Phase 1** :
- ✅ Structure templates créée
- ✅ Script génération basique fonctionnel
- ✅ 1 mode pilote généré et validé

### Phase 2 : Migration Templates (2-3h)

**Objectif** : Extraire et organiser contenu existant

1. **Extraire instructions communes** :
   - Analyser [`roo-config/modes/standard-modes.json`](../modes/standard-modes.json)
   - Identifier sections répétées 12/12 modes
   - Créer [`global-instructions.md`](../modes/templates/commons/global-instructions.md) (~3k lignes)

2. **Créer templates familles** (5 familles) :
   - CODE : 4 niveaux (Micro/Mini/Medium/Oracle)
   - DEBUG : 4 niveaux
   - ARCHITECT : 2 niveaux (Simple/Complex)
   - ASK : 2 niveaux (Simple/Complex)
   - ORCHESTRATOR : 1 niveau (unique)

3. **Extraire spécificités modes** :
   - Identifier contenu unique <5%
   - Créer fichiers `{slug}-specific.md`
   - Exemples concrets propres au mode

4. **Attention** : Références `{{INCLUDE}}` ne fonctionnent PAS
   - Génération complète côté build
   - Pas de parser runtime Roo-Code
   - Validation pre-commit obligatoire

**Livrables Phase 2** :
- ✅ global-instructions.md (~3k lignes communes)
- ✅ 5 templates familles
- ✅ 12 fichiers spécifiques modes (<5% contenu)

### Phase 3 : Génération & Validation (1h)

**Objectif** : Générer et valider tous modes

1. **Générer tous modes** (12 modes production) :
   ```bash
   node scripts/generate-modes.js
   ```

2. **Comparer vs standard-modes.json actuel** :
   - Validation format JSON
   - Vérification cohérence structure
   - Identification divergences

3. **Tester modes en local Roo** :
   - Charger modes générés dans VS Code
   - Vérifier reconnaissance et affichage
   - Tester customInstructions effectifs
   - Valider mécaniques escalade

4. **Ajuster templates si divergences** :
   - Corriger variables manquantes
   - Ajuster conditions templates
   - Re-générer et re-valider

**Livrables Phase 3** :
- ✅ 12 modes générés validés
- ✅ Format JSON conforme Roo-Code
- ✅ Tests fonctionnels réussis

### Phase 4 : Documentation & CI (1h)

**Objectif** : Automatiser et documenter

1. **Documenter workflow maintenance** :
   - README templates
   - Guide modification templates
   - Procédure génération

2. **Ajouter script pre-commit** :
   ```bash
   # .git/hooks/pre-commit
   node scripts/generate-modes.js
   git add roo-config/modes/standard-modes.json
   ```

3. **Mettre à jour README** :
   - Avertissement "fichier généré"
   - Instructions modification
   - Liens vers templates

4. **En-tête fichier généré** :
   ```json
   {
     "_warning": "⚠️ FICHIER GÉNÉRÉ - NE PAS ÉDITER MANUELLEMENT",
     "_source": "Généré par scripts/generate-modes.js depuis templates/",
     "_lastGenerated": "2025-10-02T17:00:00.000Z"
   }
   ```

**Livrables Phase 4** :
- ✅ Documentation complète workflow
- ✅ Hook pre-commit configuré
- ✅ README mis à jour

### Estimation Totale

**Total estimé** : **5-7h migration complète**

**Bloqueurs levés** :
- ✅ Structure validée (investigation 3.2)
- ✅ Contraintes identifiées (STRING monolithique)
- ✅ Solution confirmée (script assemblage)

---

## 📊 Analyse Redondances Identifiées

### Redondances par Catégorie

```
CATÉGORIE                  | PRÉSENCE | DUPLICATION | ÉCONOMIE
---------------------------|----------|-------------|----------
Protocole SDDD             |   12/12  |    100%     |  ~12k
Mécaniques Escalade        |   10/12  |     83%     |  ~10k
Hiérarchie Numérotée       |    8/12  |     67%     |   ~6k
Intégrations MCP           |   12/12  |    100%     |   ~8k
Gestion Tokens             |   10/12  |     83%     |   ~2k
────────────────────────────────────────────────────
TOTAL REDONDANCES          |          |     85%     |  ~38k
```

### Métriques Avant/Après par Mode

```
MODE             | AVANT  | APRÈS  | ÉCONOMIE | %
-----------------|--------|--------|----------|-----
code-micro       | 4.5k   | 1.2k   | 3.3k     | 73%
code-mini        | 4.6k   | 1.3k   | 3.3k     | 72%
code-medium      | 4.8k   | 1.5k   | 3.3k     | 69%
code-oracle      | 5.0k   | 1.8k   | 3.2k     | 64%
debug-micro      | 4.2k   | 1.1k   | 3.1k     | 74%
debug-mini       | 4.4k   | 1.2k   | 3.2k     | 73%
debug-medium     | 4.6k   | 1.4k   | 3.2k     | 70%
debug-oracle     | 4.9k   | 1.7k   | 3.2k     | 65%
architect-simple | 4.0k   | 1.0k   | 3.0k     | 75%
architect-complex| 4.9k   | 1.6k   | 3.3k     | 67%
ask-simple       | 3.8k   | 0.9k   | 2.9k     | 76%
ask-complex      | 4.7k   | 1.5k   | 3.2k     | 68%
-----------------|--------|--------|----------|-----
TOTAL            | 52k    | 15k    | 37k      | 71%
```

### Gain Maintenance

**Avant factorisation** :
- Modification commune : 12 fichiers JSON à éditer
- Risque incohérence : ÉLEVÉ
- Temps modification : ~30 min
- Erreurs potentielles : ~3-5 par cycle

**Après factorisation** :
- Modification commune : 1 fichier template
- Risque incohérence : NÉGLIGEABLE
- Temps modification : ~5 min (génération incluse)
- Erreurs potentielles : <1 par cycle

**Économie annuelle estimée** :
- ~50 modifications communes/an
- Temps économisé : ~20h/an
- Qualité améliorée : +40% cohérence

---

## ⚠️ Anti-Patterns à Éviter

### ❌ Duplication Instructions (AVANT)

```markdown
<!-- code-micro customInstructions -->
PROTOCOLE SDDD:
1. codebase_search obligatoire
2. Checkpoints 50k tokens
[...répété 12 fois...]

<!-- code-mini customInstructions -->
PROTOCOLE SDDD:
1. codebase_search obligatoire
2. Checkpoints 50k tokens
[...répété 12 fois...]
```

**Problème** :
- Modification commune = 12 éditions
- Incohérences fréquentes
- Maintenance lourde

### ✅ Factorisation Template (APRÈS)

```markdown
<!-- commons/global-instructions.md -->
PROTOCOLE SDDD:
1. codebase_search obligatoire
2. Checkpoints 50k tokens
[...défini 1 fois...]

<!-- Script génération -->
const instructions = [
  globalInstructions,  // ← Inclus automatiquement
  familyInstructions,
  specificInstructions
].join('\n\n');
```

**Avantages** :
- Modification unique → propagation auto
- Cohérence garantie
- Maintenance simplifiée

### ❌ Templates Complexes Illisibles

```markdown
<!-- Template avec logique alambiquée -->
{{#if ((LEVEL == "micro" AND FAMILY != "ask") OR (LEVEL == "mini" AND MODE_SLUG contains "debug"))}}
[Instructions complexes difficiles à maintenir]
{{/if}}
```

**Problème** : Logique difficile à comprendre et maintenir

### ✅ Templates Simples et Clairs

```markdown
<!-- Template avec conditions simples -->
{{#if LEVEL == "micro"}}
[Instructions micro]
{{else if LEVEL == "mini"}}
[Instructions mini]
{{else}}
[Instructions medium+]
{{/if}}
```

**Avantages** : Lisibilité et maintenabilité optimales

---

## 🚀 Bénéfices de la Factorisation

1. **Maintenance simplifiée** : -80% efforts mise à jour (30min → 5min)
2. **Cohérence garantie** : Mêmes règles partout, 1 source de vérité
3. **Économie tokens** : -71% caractères source (52k → 15k)
4. **Qualité améliorée** : Erreurs systémiques éliminées
5. **Évolutivité** : Ajout nouveaux modes simplifié
6. **Automatisation** : CI/CD avec génération pre-commit
7. **Documentation** : Templates auto-documentés

---

## 📚 Ressources Complémentaires

### Spécifications Liées

- [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md) : Instructions communes SDDD
- [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) : Mécaniques escalade factorisées
- [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md) : Système numérotation commun
- [`mcp-integrations-priority.md`](mcp-integrations-priority.md) : Patterns MCP factorisés
- [`context-economy-patterns.md`](context-economy-patterns.md) : Optimisations économie contexte

### Investigation 3.2

- **Rapport complet** : Analyse structure `custom_modes.json` et contraintes TypeScript
- **Découvertes clés** : FORMAT STRING monolithique, pas de composition native
- **Validation Option C** : Script assemblage externe confirmé viable

---

## 📋 Workflow Maintenance

### Modification Instructions Communes

1. **Identifier section** : Global / Famille / Mode
2. **Modifier template approprié** :
   - Global : [`commons/global-instructions.md`](../modes/templates/commons/global-instructions.md)
   - Famille : [`commons/families/{family}-family.md`](../modes/templates/commons/families/)
   - Mode : [`modes/{slug}-specific.md`](../modes/templates/modes/)

3. **Régénérer modes** :
   ```bash
   node scripts/generate-modes.js
   ```

4. **Valider génération** :
   - Vérifier format JSON
   - Tester modes en local
   - Comparer divergences

5. **Commiter changements** :
   ```bash
   git add roo-config/modes/templates/
   git add roo-config/modes/standard-modes.json
   git commit -m "feat: mise à jour instructions communes"
   ```

### Ajout Nouveau Mode

1. **Créer configuration** dans `scripts/generate-modes.js` :
   ```javascript
   {
     slug: 'code-expert',
     name: '🎓 Code Expert',
     family: 'code',
     level: 'expert',
     variables: { /* ... */ }
   }
   ```

2. **Créer instructions spécifiques** :
   - Fichier : [`modes/code-expert-specific.md`](../modes/templates/modes/)
   - Contenu : <5% spécificités uniques

3. **Régénérer et tester** :
   ```bash
   node scripts/generate-modes.js
   # Test en local Roo
   ```

4. **Documenter mode** :
   - Ajouter à README modes
   - Documenter cas d'usage

---

## ✅ Checklist Post-Implémentation

### Validation Technique

- [ ] Script génération fonctionnel
- [ ] Tous modes générés (12/12)
- [ ] Format JSON valide
- [ ] customInstructions STRING monolithique
- [ ] Pas de références runtime restantes
- [ ] Hook pre-commit configuré

### Validation Fonctionnelle

- [ ] Modes reconnus par Roo-Code
- [ ] Instructions effectives testées
- [ ] Mécaniques escalade validées
- [ ] Protocole SDDD appliqué
- [ ] Intégrations MCP fonctionnelles

### Documentation

- [ ] README templates créé
- [ ] Workflow maintenance documenté
- [ ] Avertissement fichier généré
- [ ] Références croisées mises à jour

### Métriques

- [ ] Réduction redondances confirmée (-71%)
- [ ] Gain maintenance mesuré (-83%)
- [ ] Cohérence améliorée validée
- [ ] ROI maintenance calculé (-80%)

---

**Note finale** : Cette architecture de factorisation est **validée par investigation 3.2** et prête à être implémentée. Le plan d'action détaillé (5-7h) permet une migration progressive avec validation à chaque étape. La contrainte critique du STRING monolithique `customInstructions` est adressée par le script d'assemblage externe, garantissant compatibilité avec le format TypeScript Roo-Code.