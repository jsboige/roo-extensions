> **Archived 2026-07-21** — W6 #2883 (Epic #2877 livrable #2).
>
> **Source:** `roo-code-customization/investigations/10-condensation-poc-design.md` · **Last commit:** `087e0a86` (2025-08-11) · **Theme:** condensation-poc
>
> **Preservation:** git history (`git show 087e0a86:roo-code-customization/investigations/10-condensation-poc-design.md`) + this archive copy. No content modified — move-only.
>
> **Incoming links:** 0 functional navigation links. Only audit inventories (#2876 doc-audit, #2886 broken-links, #2896 W6-investigations) and `docs/knowledge/WORKSPACE_KNOWLEDGE.md` arborescence cartography reference this file — all point-in-time mentions that remain valid post-archive.
>
> **Superseded by:** condensation POC design, superseded by the merged auto-condensation implementation.

# Design de Preuve de Concept : Personnalisation de la Condensation

**Date :** 8 janvier 2025  
**Objectif :** Concevoir une PoC pour personnaliser le mécanisme de condensation de contexte  
**Méthodologie :** Semantic Documentation Driven Design (SDDD)  
**Continuation de :** [09-context-condensation-analysis.md](./09-context-condensation-analysis.md)

## 🎯 Résumé Exécutif

Cette PoC vise à démontrer notre capacité à personnaliser le comportement du système de condensation de roo-code en rendant le prompt de résumé (`SUMMARY_PROMPT`) configurable par l'utilisateur via les Settings de VSCode. Cette approche respecte les bonnes pratiques d'extension VSCode et ouvre la voie à d'autres personnalisations futures.

## 📋 Point d'Interception Ciblé

**Cible :** Modification du prompt de résumé (`SUMMARY_PROMPT`) dans [`src/core/condense/index.ts`](../roo-code/src/core/condense/index.ts:14)

**Justification du choix :**
- ✅ **Sécurité maximale** : Modification isolée sans impact architectural
- ✅ **Impact visible** : L'utilisateur peut immédiatement constater les changements
- ✅ **Facilité d'implémentation** : Infrastructure de configuration VSCode déjà en place
- ✅ **Pas de breaking changes** : Compatibilité totale avec l'existant

## 🔍 Analyse de l'État Actuel

### Architecture Existante

**Fichier cible :** [`src/core/condense/index.ts`](../roo-code/src/core/condense/index.ts:14)

```typescript
const SUMMARY_PROMPT = `\
Your task is to create a detailed summary of the conversation so far, paying close attention to the user's explicit requests and your previous actions.
This summary should be thorough in capturing technical details, code patterns, and architectural decisions that would be essential for continuing with the conversation and supporting any continuing tasks.

Your summary should be structured as follows:
Context: The context to continue the conversation with. If applicable based on the current task, this should include:
  1. Previous Conversation: High level details about what was discussed throughout the entire conversation with the user. This should be written to allow someone to be able to follow the general overarching conversation flow.
  2. Current Work: Describe in detail what was being worked on prior to this request to summarize the conversation. Pay special attention to the more recent messages in the conversation.
  3. Key Technical Concepts: List all important technical concepts, technologies, coding conventions, and frameworks discussed, which might be relevant for continuing with this work.
  4. Relevant Files and Code: If applicable, enumerate specific files and code sections examined, modified, or created for the task continuation. Pay special attention to the most recent messages and changes.
  5. Problem Solving: Document problems solved thus far and any ongoing troubleshooting efforts.
  6. Pending Tasks and Next Steps: Outline all pending tasks that you have explicitly been asked to work on, as well as list the next steps you will take for all outstanding work, if applicable. Include code snippets where they add clarity. For any next steps, include direct quotes from the most recent conversation showing exactly what task you were working on and where you left off. This should be verbatim to ensure there's no information loss in context between tasks.

[... structure details ...]

Output only the summary of the conversation so far, without any additional commentary or explanation.
`
```

### Mécanisme d'Injection Existant

La fonction [`summarizeConversation()`](../roo-code/src/core/condense/index.ts:85) accepte déjà un paramètre optionnel `customCondensingPrompt` :

```typescript
// Ligne 133 - Logique actuelle
const promptToUse = customCondensingPrompt?.trim() ? customCondensingPrompt.trim() : SUMMARY_PROMPT
```

**Point d'ancrage parfait** : Cette infrastructure nous permet d'injecter facilement notre configuration.

## 🏗️ Design de la Solution

### 1. Configuration VSCode

**Ajout dans [`src/package.json`](../roo-code/src/package.json) Section `contributes.configuration.properties` :**

```json
{
  "roo-cline.customCondensationPrompt": {
    "type": "string",
    "default": "",
    "description": "%settings.customCondensationPrompt.description%",
    "editPresentation": "multilineText",
    "markdownDescription": "Personnalisez le prompt utilisé pour résumer les conversations lorsque le contexte atteint sa limite. Laissez vide pour utiliser le prompt par défaut. Ce prompt détermine la structure et le contenu des résumés générés automatiquement.\n\n**Variables disponibles :**\n- Le prompt reçoit l'historique de conversation à résumer\n- La structure de sortie doit permettre de continuer la conversation de manière cohérente\n\n**Exemple de personnalisation :**\n```\nRésumez cette conversation en français avec les sections suivantes :\n1. Contexte principal\n2. Travail en cours\n3. Concepts techniques clés\n4. Fichiers modifiés\n5. Problèmes résolus\n6. Tâches pendantes\n```"
  }
}
```

### 2. Ajout des Traductions

**Fichier [`src/package.nls.fr.json`](../roo-code/src/package.nls.fr.json) :**

```json
{
  "settings.customCondensationPrompt.description": "Prompt personnalisé pour la condensation de contexte"
}
```

**Autres langues** : Ajouter les traductions correspondantes dans tous les fichiers `.nls.*.json`

### 3. Modification du Code de Condensation

**Modification dans [`src/core/condense/index.ts`](../roo-code/src/core/condense/index.ts:133) :**

```typescript
import * as vscode from 'vscode'

// Dans la fonction summarizeConversation(), remplacer la ligne 133 :

// AVANT
const promptToUse = customCondensingPrompt?.trim() ? customCondensingPrompt.trim() : SUMMARY_PROMPT

// APRÈS
const getEffectivePrompt = (): string => {
  // 1. Priorité au paramètre de fonction (pour compatibilité API)
  if (customCondensingPrompt?.trim()) {
    return customCondensingPrompt.trim()
  }
  
  // 2. Lecture de la configuration VSCode
  const config = vscode.workspace.getConfiguration('roo-cline')
  const userCustomPrompt = config.get<string>('customCondensationPrompt')?.trim()
  
  if (userCustomPrompt) {
    return userCustomPrompt
  }
  
  // 3. Fallback sur le prompt par défaut
  return SUMMARY_PROMPT
}

const promptToUse = getEffectivePrompt()
```

## 🎯 Spécifications Techniques Détaillées

### A. Modifications dans `package.json`

**Emplacement :** [`src/package.json`](../roo-code/src/package.json:317) (après la propriété `"roo-cline.useAgentRules"`)

**Code exact à ajouter :**

```json
"roo-cline.customCondensationPrompt": {
  "type": "string",
  "default": "",
  "description": "%settings.customCondensationPrompt.description%",
  "editPresentation": "multilineText",
  "markdownDescription": "Personnalisez le prompt utilisé pour résumer les conversations lorsque le contexte atteint sa limite. Laissez vide pour utiliser le prompt par défaut.\n\n**Structure recommandée :**\n1. Instructions générales de résumé\n2. Sections spécifiques à inclure\n3. Format de sortie souhaité\n\n**Note :** Ce prompt influence directement la qualité des résumés automatiques et la continuité des conversations longues."
}
```

### B. Modifications dans les fichiers de traduction

**Fichiers à modifier :** Tous les `src/package.nls.*.json`

**Exemple pour `package.nls.fr.json` :**

```json
"settings.customCondensationPrompt.description": "Prompt personnalisé pour la condensation automatique du contexte"
```

### C. Code de récupération de configuration

**Emplacement :** [`src/core/condense/index.ts`](../roo-code/src/core/condense/index.ts:133)

**Fonction helper à ajouter (avant la fonction `summarizeConversation`) :**

```typescript
/**
 * Récupère le prompt effectif à utiliser pour la condensation
 * Ordre de priorité : customCondensingPrompt > configuration VSCode > SUMMARY_PROMPT
 */
function getEffectiveCondensationPrompt(customCondensingPrompt?: string): string {
  // 1. Priorité au paramètre de fonction (compatibilité API existante)
  if (customCondensingPrompt?.trim()) {
    return customCondensingPrompt.trim()
  }
  
  // 2. Configuration utilisateur via VSCode Settings
  try {
    const config = vscode.workspace.getConfiguration('roo-cline')
    const userCustomPrompt = config.get<string>('customCondensationPrompt')?.trim()
    
    if (userCustomPrompt) {
      return userCustomPrompt
    }
  } catch (error) {
    console.warn('Erreur lors de la lecture de la configuration customCondensationPrompt:', error)
  }
  
  // 3. Prompt par défaut
  return SUMMARY_PROMPT
}
```

**Modification de la ligne 133 :**

```typescript
// REMPLACER
const promptToUse = customCondensingPrompt?.trim() ? customCondensingPrompt.trim() : SUMMARY_PROMPT

// PAR
const promptToUse = getEffectiveCondensationPrompt(customCondensingPrompt)
```

**Import requis à ajouter en haut du fichier :**

```typescript
import * as vscode from 'vscode'
```

## 🧪 Plan de Validation Détaillé

### Phase 1 : Validation Technique

**1.1 Compilation et Build**
```bash
# Vérifier que le code compile
npm run check-types

# Vérifier le build complet
npm run build
```

**1.2 Test des Settings VSCode**
- Ouvrir VSCode Settings (`Ctrl+,`)
- Rechercher "roo-cline customCondensationPrompt"
- Vérifier l'affichage de la description
- Tester l'interface multiline

### Phase 2 : Validation Fonctionnelle

**2.1 Test du Prompt Par Défaut**
- S'assurer qu'avec une configuration vide, le comportement reste identique
- Déclencher une condensation et vérifier le format du résumé

**2.2 Test du Prompt Personnalisé**
- Configurer un prompt personnalisé simple :
```
Résume cette conversation en français avec :
1. Le contexte principal
2. Les actions effectuées
3. Les prochaines étapes
```
- Déclencher une condensation
- Vérifier que le résumé suit le format personnalisé

**2.3 Test de Priorité des Paramètres**
- Définir un prompt dans les settings
- Passer un `customCondensingPrompt` via l'API
- Vérifier que le paramètre API a priorité

### Phase 3 : Tests de Régression

**3.1 Compatibilité API**
- Vérifier que toutes les fonctions appelant `summarizeConversation()` continuent de fonctionner
- Tests avec et sans paramètre `customCondensingPrompt`

**3.2 Gestion d'Erreurs**
- Tester avec une configuration VSCode corrompue
- Vérifier le fallback au prompt par défaut

### Phase 4 : Tests d'Intégration

**4.1 Workflow Complet**
1. Créer une conversation longue nécessitant une condensation
2. Configurer un prompt personnalisé dans les settings
3. Déclencher la condensation automatique
4. Vérifier que la conversation continue de manière cohérente

**4.2 Performance**
- Mesurer l'impact sur les temps de condensation
- Vérifier l'absence de fuite mémoire

## 🎖️ Critères de Succès

### Succès Minimal (MVP)

✅ **Configuration accessible** : Le paramètre apparaît dans VSCode Settings  
✅ **Fonctionnalité opérationnelle** : Un prompt personnalisé modifie effectivement le résumé  
✅ **Compatibilité préservée** : Aucune régression sur le comportement existant  
✅ **Fallback robuste** : Le système fonctionne même avec une configuration invalide  

### Succès Étendu

🎯 **UX optimale** : Interface multiline avec description détaillée  
🎯 **Validation complète** : Tous les cas de test passent  
🎯 **Documentation** : Exemples d'utilisation clairs  
🎯 **Extensibilité** : Architecture prête pour d'autres personnalisations  

## 🚀 Avantages de cette Approche

### Bénéfices Immédiats

1. **Démonstration de faisabilité** : Preuve concrète de notre capacité d'interception
2. **Valeur utilisateur** : Personnalisation immédiatement utile
3. **Risque minimal** : Modification isolée et non-breaking
4. **Standard VSCode** : Utilise les patterns recommandés

### Fondations pour l'Avenir

1. **Pattern réutilisable** : Template pour d'autres configurations
2. **Architecture extensible** : Base pour des personnalisations plus complexes
3. **Expérience utilisateur** : Familiarisation avec les settings de roo-code
4. **Documentation pratique** : Exemple concret d'extension du système

## 🔄 Évolutions Futures Possibles

### Extensions Immédiates

- **Templates de prompts** : Presets pour différents domaines (code, documentation, etc.)
- **Variables dynamiques** : Injection de contexte dans les prompts (langue, type de projet, etc.)
- **Validation de prompts** : Vérification de la qualité des prompts personnalisés

### Extensions Avancées

- **Prompts adaptatifs** : Sélection automatique selon le contexte
- **A/B Testing** : Comparaison de différents prompts
- **Métriques de qualité** : Évaluation automatique des résumés

## 📝 Notes d'Implémentation

### Considérations Techniques

1. **Gestion des erreurs** : Wrapper try-catch autour de `vscode.workspace.getConfiguration()`
2. **Performance** : Cache de la configuration pour éviter les accès répétés
3. **Type safety** : Validation du type `string` pour la configuration
4. **Backward compatibility** : Maintien total de l'API existante

### Points d'Attention

1. **Import VSCode** : S'assurer que l'import `vscode` est disponible dans le contexte
2. **Configuration scope** : Utiliser le scope workspace approprié
3. **Réactivité** : La configuration est rechargée automatiquement par VSCode
4. **Sécurité** : Validation basique du contenu du prompt (non-vide, longueur raisonnable)

---

**Prêt pour implémentation** - Ce design fournit tous les éléments nécessaires pour qu'un agent `code` puisse implémenter cette PoC de manière autonome.